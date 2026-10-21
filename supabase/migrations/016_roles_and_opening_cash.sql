-- =============================================================================
-- 016_roles_and_opening_cash.sql
-- صلاحيات الأدوار ورصيد افتتاح وردية الكاشير
-- قابل لإعادة التنفيذ
-- =============================================================================

-- أ) إضافة hr إلى قيم profiles.role. يُستبدل فقط قيد الدور الذي يحتوي
--    على قيمة storekeeper، مهما كان اسمه المنشور سابقاً.
do $$
declare
  v_constraint record;
  v_role_constraints integer;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%storekeeper%'
  loop
    execute format(
      'alter table public.profiles drop constraint if exists %I',
      v_constraint.conname
    );
  end loop;

  alter table public.profiles
    add constraint profiles_role_check
    check (role in (
      'owner', 'branch_manager', 'storekeeper', 'cashier', 'accountant', 'hr'
    ));

  select count(*)
  into v_role_constraints
  from pg_constraint
  where conrelid = 'public.profiles'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%storekeeper%';

  assert v_role_constraints = 1,
    format('يجب أن يوجد قيد دور واحد فقط؛ وُجد %s', v_role_constraints);
end;
$$;

-- ب) الاحتفاظ بالرصيد الافتتاحي مع إعادته إلى قيد ثابت عند إعادة التنفيذ.
alter table public.shift_closings
  add column if not exists opening_cash numeric(12, 2) not null default 0;

do $$
declare
  v_constraint record;
  v_opening_constraints integer;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.shift_closings'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%opening_cash%'
  loop
    execute format(
      'alter table public.shift_closings drop constraint if exists %I',
      v_constraint.conname
    );
  end loop;

  alter table public.shift_closings
    add constraint shift_closings_opening_cash_check
    check (opening_cash >= 0);

  select count(*)
  into v_opening_constraints
  from pg_constraint
  where conrelid = 'public.shift_closings'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%opening_cash%';

  assert v_opening_constraints = 1,
    format('يجب أن يوجد قيد رصيد افتتاحي واحد فقط؛ وُجد %s', v_opening_constraints);
end;
$$;

-- ج) منسوخة من الدالة المنشورة مع إضافة opening_cash فقط.
create or replace function public.close_shift(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_client uuid := nullif(p->>'client_id','')::uuid;
  v_session uuid := nullif(p->>'session_id','')::uuid;
  v_branch public.branches%rowtype;
  v_existing public.shift_closings%rowtype;
  v_email text;
  v_opened timestamptz := nullif(p->>'opened_at','')::timestamptz;
  v_closed timestamptz := nullif(p->>'closed_at','')::timestamptz;
  v_counted numeric := nullif(p->>'counted_cash','')::numeric;
  v_opening numeric := coalesce(nullif(p->>'opening_cash','')::numeric, 0);
  v_client_count integer := nullif(p->>'client_invoices_count','')::integer;
  v_count integer; v_cash numeric; v_card numeric; v_other numeric;
  v_total numeric; v_disc numeric; v_vat numeric; v_expected_cash numeric;
  v_diff numeric; v_id uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  if v_client is null or v_session is null or v_opened is null or v_closed is null then
    raise exception 'بيانات الوردية ناقصة';
  end if;
  if v_closed < v_opened then raise exception 'وقت الإقفال قبل وقت البداية'; end if;
  if v_counted is null or v_counted < 0 then raise exception 'مبلغ الكاش غير صحيح'; end if;
  if v_opening < 0 then raise exception 'الرصيد الافتتاحي غير صحيح'; end if;

  select * into v_existing from public.shift_closings where client_id = v_client or session_id = v_session;
  if found then
    if v_existing.cashier_id <> v_uid then raise exception 'هذه الوردية مسجلة بالفعل'; end if;
    return jsonb_build_object('id', v_existing.id, 'difference', v_existing.difference,
                              'has_mismatch', v_existing.has_mismatch, 'already_exists', true);
  end if;

  select * into v_branch from public.branches where id = nullif(p->>'branch_id','')::uuid and deleted_at is null;
  if not found then raise exception 'الفرع غير موجود'; end if;

  select email into v_email from auth.users where id = v_uid;

  select count(*),
         coalesce(sum(total) filter (where payment_method = 'cash'), 0),
         coalesce(sum(total) filter (where payment_method = 'card'), 0),
         coalesce(sum(total) filter (where payment_method not in ('cash','card')), 0),
         coalesce(sum(total), 0), coalesce(sum(discount_amount), 0), coalesce(sum(vat_amount), 0)
    into v_count, v_cash, v_card, v_other, v_total, v_disc, v_vat
    from public.sales
   where session_id = v_session and cashier_id = v_uid
     and branch_id = v_branch.id and status = 'completed';

  v_expected_cash := v_cash + v_opening;
  v_diff := round(v_counted - v_expected_cash, 2);

  insert into public.shift_closings (
    client_id, session_id, branch_id, branch_name, branch_code, cashier_id, cashier_name, shift,
    opened_at, closed_at, invoices_count, client_invoices_count,
    cash_sales, card_sales, other_sales, total_sales, discounts_total, vat_total,
    opening_cash, expected_cash, counted_cash, difference, has_mismatch, notes
  ) values (
    v_client, v_session, v_branch.id, v_branch.name, v_branch.code, v_uid,
    split_part(coalesce(v_email, ''), '@', 1), nullif(p->>'shift',''),
    v_opened, v_closed, v_count, v_client_count,
    v_cash, v_card, v_other, v_total, v_disc, v_vat,
    v_opening, v_expected_cash, v_counted, v_diff,
    (v_client_count is not null and v_client_count <> v_count),
    nullif(p->>'notes','')
  ) returning id into v_id;

  return jsonb_build_object('id', v_id, 'difference', v_diff,
                            'has_mismatch', (v_client_count is not null and v_client_count <> v_count),
                            'already_exists', false);
end;
$function$;

revoke execute on function public.close_shift(jsonb) from public, anon;
grant execute on function public.close_shift(jsonb) to authenticated;

notify pgrst, 'reload schema';
