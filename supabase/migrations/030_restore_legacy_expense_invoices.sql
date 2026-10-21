-- =============================================================================
-- 030_restore_legacy_expense_invoices.sql
-- توحيد المصروفات مع المسار القديم: expense_invoices / create_expense.
-- =============================================================================

begin;

-- المسار الذي أُضيف للحسابات كان يكتب في جدول مختلف عن سجل المصروفات والتقارير.
drop function if exists public.acc_add_expense(jsonb);
drop function if exists public.acc_decide_expense(uuid, text, text);

-- هذه السجلات تخص المسار الملغى فقط ولا تظهر في شاشة المصروفات القديمة.
delete from public.expenses;

create or replace function public.create_expense(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_client_id uuid := nullif(p->>'client_id', '')::uuid;
  v_branch_id uuid := nullif(p->>'branch_id', '')::uuid;
  v_session_id uuid := nullif(p->>'session_id', '')::uuid;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_existing public.expense_invoices%rowtype;
  v_branch public.branches%rowtype;
  v_number integer;
  v_invoice_number text;
  v_id uuid;
  v_email text;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('cashier', 'branch_manager', 'accountant', 'owner') then
    raise exception 'ليس لديك صلاحية تسجيل المصروفات';
  end if;
  if v_client_id is null or v_branch_id is null or v_session_id is null then
    raise exception 'بيانات المصروف ناقصة';
  end if;
  if not _has_role('accountant', 'owner') and not _can_act_for_branch(v_branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;
  if coalesce(trim(p->>'category'), '') = '' then
    raise exception 'نوع المصروف مطلوب';
  end if;
  if v_amount is null or v_amount <= 0 or v_vat < 0 then
    raise exception 'قيمة المصروف غير صحيحة';
  end if;

  select * into v_existing from public.expense_invoices where client_id = v_client_id;
  if found then
    return jsonb_build_object(
      'id', v_existing.id,
      'number', v_existing.invoice_number,
      'invoice_number', v_existing.invoice_number,
      'already_exists', true
    );
  end if;

  select * into v_branch
  from public.branches
  where id = v_branch_id and deleted_at is null and is_active;
  if not found then
    raise exception 'الفرع غير موجود أو غير نشط';
  end if;

  insert into public.branch_expense_counters (branch_id, last_number)
  values (v_branch.id, 1)
  on conflict (branch_id)
  do update set last_number = public.branch_expense_counters.last_number + 1
  returning last_number into v_number;

  v_invoice_number := 'EXP-' || coalesce(nullif(v_branch.code, ''), 'BR') || '-' || lpad(v_number::text, 6, '0');
  select email into v_email from auth.users where id = v_uid;

  insert into public.expense_invoices (
    client_id, invoice_number, branch_id, branch_name, branch_code,
    cashier_id, cashier_name, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes, status
  ) values (
    v_client_id, v_invoice_number, v_branch.id, v_branch.name, v_branch.code,
    v_uid, split_part(coalesce(v_email, ''), '@', 1), v_session_id,
    trim(p->>'category'), nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat, 2), round(v_amount + v_vat, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), ''), 'posted'
  ) returning id into v_id;

  return jsonb_build_object(
    'id', v_id,
    'number', v_invoice_number,
    'invoice_number', v_invoice_number,
    'already_exists', false
  );
end;
$$;

revoke all on function public.create_expense(jsonb) from public, anon;
grant execute on function public.create_expense(jsonb) to authenticated;

create or replace function public.acc_get_comprehensive_financial_report(
  p_from timestamptz,
  p_to timestamptz,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_from timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to timestamptz := coalesce(p_to, now());
  v_branch_name text := 'الشركة كاملة — جميع الفروع';
  v_sales_count int := 0; v_sales_subtot numeric := 0; v_sales_tax numeric := 0;
  v_sales_total numeric := 0; v_cash_sales numeric := 0; v_card_sales numeric := 0;
  v_exp_count int := 0; v_exp_total numeric := 0; v_exp_by_cat jsonb := '[]'::jsonb;
  v_pur_count int := 0; v_pur_total numeric := 0; v_bo_count int := 0; v_bo_total numeric := 0;
  v_surplus_total numeric := 0; v_shortage_total numeric := 0; v_closings_count int := 0;
begin
  if v_uid is null or not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة';
  end if;
  if p_branch_id is not null then
    select name into v_branch_name from public.branches where id = p_branch_id;
  end if;

  select count(*), coalesce(sum(subtotal), 0), coalesce(sum(vat_amount), 0), coalesce(sum(total), 0),
    coalesce(sum(case when coalesce(payment_method, '') ilike any (array['%cash%', '%كاش%', '%نقد%']) then total else 0 end), 0),
    coalesce(sum(case when coalesce(payment_method, '') ilike any (array['%card%', '%visa%', '%pos%', '%network%', '%شبكة%', '%مدى%', '%فيزا%', '%بطاق%']) then total else 0 end), 0)
  into v_sales_count, v_sales_subtot, v_sales_tax, v_sales_total, v_cash_sales, v_card_sales
  from public.sales
  where sold_at >= v_from and sold_at <= v_to and (p_branch_id is null or branch_id = p_branch_id) and status = 'completed';

  select count(*), coalesce(sum(total), 0) into v_exp_count, v_exp_total
  from public.expense_invoices
  where status = 'posted'
    and expense_date >= (v_from at time zone 'Africa/Cairo')::date
    and expense_date <= (v_to at time zone 'Africa/Cairo')::date
    and (p_branch_id is null or branch_id = p_branch_id);

  select coalesce(jsonb_agg(jsonb_build_object('category', category, 'total', category_total)), '[]'::jsonb)
  into v_exp_by_cat
  from (
    select category, sum(total) as category_total
    from public.expense_invoices
    where status = 'posted'
      and expense_date >= (v_from at time zone 'Africa/Cairo')::date
      and expense_date <= (v_to at time zone 'Africa/Cairo')::date
      and (p_branch_id is null or branch_id = p_branch_id)
    group by category order by category_total desc
  ) categories;

  select count(distinct so.id), coalesce(sum(coalesce(sol.qty_approved, sol.qty_received, sol.qty_requested, 0) * coalesce(sol.unit_cost, 0)), 0)
  into v_pur_count, v_pur_total
  from public.supply_orders so join public.supply_order_lines sol on sol.order_id = so.id
  where so.created_at >= v_from and so.created_at <= v_to and so.status in ('approved', 'received');

  select count(distinct bo.id), coalesce(sum(coalesce(bol.qty_approved, bol.qty_requested, 0) * coalesce(ii.avg_cost, 0)), 0)
  into v_bo_count, v_bo_total
  from public.branch_orders bo join public.branch_order_lines bol on bol.order_id = bo.id
  left join public.inventory_items ii on ii.id = bol.item_id
  where bo.created_at >= v_from and bo.created_at <= v_to
    and (p_branch_id is null or bo.branch_id = p_branch_id)
    and bo.status in ('approved', 'delivered', 'received', 'closed');

  select count(*), coalesce(sum(case when difference > 0 then difference else 0 end), 0),
    coalesce(sum(case when difference < 0 then abs(difference) else 0 end), 0)
  into v_closings_count, v_surplus_total, v_shortage_total
  from public.shift_closings
  where closed_at >= v_from and closed_at <= v_to and (p_branch_id is null or branch_id = p_branch_id);

  return jsonb_build_object(
    'branch_id', p_branch_id, 'branch_name', v_branch_name, 'from_date', v_from, 'to_date', v_to,
    'sales', jsonb_build_object('count', v_sales_count, 'subtotal', round(v_sales_subtot, 2), 'tax', round(v_sales_tax, 2), 'total', round(v_sales_total, 2), 'cash', round(v_cash_sales, 2), 'card', round(v_card_sales, 2)),
    'expenses', jsonb_build_object('count', v_exp_count, 'total', round(v_exp_total, 2), 'by_category', v_exp_by_cat),
    'purchases', jsonb_build_object('count', v_pur_count, 'total', round(v_pur_total, 2)),
    'branch_warehouse_orders', jsonb_build_object('count', v_bo_count, 'total', round(v_bo_total, 2)),
    'closings', jsonb_build_object('count', v_closings_count, 'surplus', round(v_surplus_total, 2), 'shortage', round(v_shortage_total, 2), 'net_diff', round(v_surplus_total - v_shortage_total, 2))
  );
end;
$$;

grant execute on function public.acc_get_comprehensive_financial_report(timestamptz, timestamptz, uuid) to authenticated;

commit;
