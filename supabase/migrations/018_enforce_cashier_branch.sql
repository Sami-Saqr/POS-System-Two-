-- =============================================================================
-- 018_enforce_cashier_branch.sql
-- يمنع الكاشير من العمل خارج الفرع المرتبط بحسابه.
-- هذا الملف لا يُشغّل تلقائياً من التطبيق.
-- =============================================================================

create or replace function public._assert_branch_allowed(p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_role text;
  v_profile_branch_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select role, branch_id
    into v_role, v_profile_branch_id
  from public.profiles
  where id = auth.uid()
    and is_active = true;

  if v_role is null then
    raise exception 'حسابك غير مفعّل';
  end if;

  if v_role in ('owner', 'branch_manager') then
    return;
  end if;

  if v_role = 'cashier' then
    if v_profile_branch_id is null then
      raise exception 'حسابك غير مرتبط بفرع';
    end if;

    if p_branch_id is distinct from v_profile_branch_id then
      raise exception 'هذا الحساب غير مصرح له بالعمل على هذا الفرع';
    end if;

    return;
  end if;

  if p_branch_id is not null then
    raise exception 'هذا الحساب غير مصرح له بالعمل على هذا الفرع';
  end if;
end;
$$;

revoke all on function public._assert_branch_allowed(uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_sale(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_client uuid := nullif(p->>'client_id','')::uuid;
  v_session uuid := nullif(p->>'session_id','')::uuid;
  v_branch_id uuid := nullif(p->>'branch_id','')::uuid;
  v_branch public.branches%rowtype;
  v_existing public.sales%rowtype;
  v_email text;
  v_cashier text;
  v_item jsonb;
  v_pid uuid;
  v_vid uuid;
  v_qty numeric;
  v_price numeric;
  v_pname text;
  v_vlabel text;
  v_cost numeric;
  v_subtotal numeric;
  v_discount numeric := coalesce(nullif(p->>'discount_amount','')::numeric, 0);
  v_vat numeric := coalesce(nullif(p->>'vat_amount','')::numeric, 0);
  v_total numeric;
  v_sent_total numeric := nullif(p->>'total','')::numeric;
  v_sold timestamptz := coalesce(nullif(p->>'sold_at','')::timestamptz, now());
  v_num integer;
  v_inv text;
  v_sale_id uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  perform public._assert_branch_allowed(v_branch_id);
  if v_client is null then raise exception 'معرّف الفاتورة مطلوب'; end if;
  if v_sold > now() + interval '5 minutes' then v_sold := now(); end if;

  select * into v_existing from public.sales where client_id = v_client;
  if found then
    if v_existing.cashier_id <> v_uid then raise exception 'معرّف الفاتورة مستخدم بالفعل'; end if;
    return jsonb_build_object('id', v_existing.id, 'invoice_number', v_existing.invoice_number, 'already_exists', true);
  end if;

  select * into v_branch from public.branches
   where id = v_branch_id and deleted_at is null and is_active;
  if not found then raise exception 'الفرع غير موجود أو غير نشط'; end if;

  select email into v_email from auth.users where id = v_uid;
  v_cashier := split_part(coalesce(v_email, ''), '@', 1);

  if jsonb_typeof(p->'items') is distinct from 'array' or jsonb_array_length(p->'items') = 0 then
    raise exception 'الفاتورة فارغة';
  end if;

  select coalesce(sum(round((i->>'qty')::numeric * (i->>'unit_price')::numeric, 2)), 0)
    into v_subtotal from jsonb_array_elements(p->'items') i;

  if v_discount < 0 or v_discount > v_subtotal then raise exception 'قيمة الخصم غير صحيحة'; end if;
  if v_vat < 0 then raise exception 'قيمة الضريبة غير صحيحة'; end if;

  v_total := round(v_subtotal - v_discount + v_vat, 2);
  if v_sent_total is not null and abs(v_sent_total - v_total) > 0.01 then
    raise exception 'إجمالي الفاتورة غير متطابق مع الأصناف';
  end if;

  insert into public.branch_invoice_counters (branch_id, last_number)
  values (v_branch.id, 1)
  on conflict (branch_id)
  do update set last_number = public.branch_invoice_counters.last_number + 1
  returning last_number into v_num;

  v_inv := coalesce(nullif(v_branch.code, ''), 'BR') || '-' || lpad(v_num::text, 6, '0');

  insert into public.sales (
    client_id, invoice_number, local_number, branch_id, branch_name, branch_code,
    cashier_id, cashier_name, shift, session_id, payment_method,
    subtotal, discount_amount, discount_percent, vat_rate, vat_amount, total, notes, sold_at
  ) values (
    v_client, v_inv, nullif(p->>'local_number',''), v_branch.id, v_branch.name, v_branch.code,
    v_uid, v_cashier, nullif(p->>'shift',''), v_session,
    coalesce(nullif(p->>'payment_method',''), 'cash'),
    v_subtotal, v_discount, nullif(p->>'discount_percent','')::numeric,
    coalesce(nullif(p->>'vat_rate','')::numeric, 0), v_vat, v_total, nullif(p->>'notes',''), v_sold
  )
  returning id into v_sale_id;

  for v_item in select value from jsonb_array_elements(p->'items')
  loop
    v_qty   := (v_item->>'qty')::numeric;
    v_price := (v_item->>'unit_price')::numeric;
    v_pid   := nullif(v_item->>'product_id','')::uuid;
    v_vid   := nullif(v_item->>'variant_id','')::uuid;

    if v_qty is null or v_qty <= 0 or v_price is null or v_price < 0 then
      raise exception 'كمية أو سعر غير صحيح في أحد الأصناف';
    end if;

    if v_vid is not null then
      select pr.id, pr.name, pv.label, pv.cost into v_pid, v_pname, v_vlabel, v_cost
        from public.product_variants pv join public.products pr on pr.id = pv.product_id
       where pv.id = v_vid;
    else
      select pr.name, null::text, pr.cost into v_pname, v_vlabel, v_cost
        from public.products pr where pr.id = v_pid;
    end if;

    if v_pname is null then raise exception 'أحد المنتجات غير موجود'; end if;

    insert into public.sale_items (sale_id, product_id, variant_id, product_name, variant_label, qty, unit_price, unit_cost, line_total)
    values (v_sale_id, v_pid, v_vid, v_pname, v_vlabel, v_qty, v_price, coalesce(v_cost, 0), round(v_qty * v_price, 2));
  end loop;

  return jsonb_build_object('id', v_sale_id, 'invoice_number', v_inv, 'already_exists', false);
end;
$function$;

revoke all on function public.create_sale(jsonb) from public, anon;
grant execute on function public.create_sale(jsonb) to authenticated;

CREATE OR REPLACE FUNCTION public.close_shift(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  perform public._assert_branch_allowed(nullif(p->>'branch_id','')::uuid);
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

revoke all on function public.close_shift(jsonb) from public, anon;
grant execute on function public.close_shift(jsonb) to authenticated;

CREATE OR REPLACE FUNCTION public.create_expense(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_client_id uuid := nullif(p->>'client_id', '')::uuid;
  v_branch_id uuid := nullif(p->>'branch_id', '')::uuid;
  v_session_id uuid := nullif(p->>'session_id', '')::uuid;
  v_existing public.expense_invoices%rowtype;
  v_branch public.branches%rowtype;
  v_email text;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_num integer;
  v_inv text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant') then
    perform public._assert_branch_allowed(v_branch_id);
  end if;
  if not _has_role('cashier', 'branch_manager', 'accountant') then
    raise exception 'ليس لديك صلاحية تسجيل المصروفات';
  end if;
  if v_client_id is null or v_branch_id is null or v_session_id is null then
    raise exception 'بيانات المصروف ناقصة';
  end if;
  if not _can_act_for_branch(v_branch_id) then
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
    if v_existing.cashier_id <> v_uid then
      raise exception 'معرّف المصروف مستخدم بالفعل';
    end if;
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

  select email into v_email from auth.users where id = v_uid;

  insert into public.branch_expense_counters (branch_id, last_number)
  values (v_branch.id, 1)
  on conflict (branch_id)
  do update set last_number = public.branch_expense_counters.last_number + 1
  returning last_number into v_num;

  v_inv := 'EXP-' || coalesce(nullif(v_branch.code, ''), 'BR') || '-' || lpad(v_num::text, 6, '0');

  insert into public.expense_invoices (
    client_id, invoice_number, branch_id, branch_name, branch_code,
    cashier_id, cashier_name, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes
  ) values (
    v_client_id, v_inv, v_branch.id, v_branch.name, v_branch.code,
    v_uid, split_part(coalesce(v_email, ''), '@', 1), v_session_id,
    trim(p->>'category'), nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat, 2), round(v_amount + v_vat, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), '')
  ) returning id into v_id;

  return jsonb_build_object(
    'id', v_id,
    'number', v_inv,
    'invoice_number', v_inv,
    'already_exists', false
  );
end;
$function$;

revoke all on function public.create_expense(jsonb) from public, anon;
grant execute on function public.create_expense(jsonb) to authenticated;

CREATE OR REPLACE FUNCTION public.create_branch_order(p_client_id uuid, p_branch_id uuid, p_notes text DEFAULT NULL::text, p_lines jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id  uuid := auth.uid();
  v_order_id uuid;
  v_number   text;
  v_branch_code text;
  v_line     jsonb;
  v_existing record;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  perform public._assert_branch_allowed(p_branch_id);

  if not _has_role('cashier', 'branch_manager') then
    raise exception 'إنشاء الطلبيات للكاشير ومدير الفرع فقط';
  end if;

  if not _can_act_for_branch(p_branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للطلبية';
  end if;

  -- idempotency
  select id, number into v_existing
  from public.branch_orders
  where client_id = p_client_id;

  if found then
    return jsonb_build_object('ok', true, 'doc',
      jsonb_build_object('id', v_existing.id, 'number', v_existing.number));
  end if;

  select code into v_branch_code from public.branches where id = p_branch_id;

  v_number := _next_doc_number('bo', v_branch_code,
    'BO-' || v_branch_code || '-{n:6}');

  insert into public.branch_orders (client_id, number, branch_id, notes, created_by)
  values (p_client_id, v_number, p_branch_id, p_notes, v_user_id)
  returning id into v_order_id;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.branch_order_lines (order_id, item_id, qty_requested)
    values (v_order_id, (v_line->>'item_id')::uuid, (v_line->>'qty_requested')::numeric);
  end loop;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('branch_orders:' || p_branch_id::text);

  perform _notify(
    'branch_order_submitted',
    array['accounting', 'warehouse'],
    p_branch_id,
    'طلبية فرع جديدة: ' || v_number,
    'فرع: ' || (select name from public.branches where id = p_branch_id),
    jsonb_build_object('ref_type', 'branch_order', 'ref_id', v_order_id, 'domains',
      array['inv_supply', 'branch_orders:' || p_branch_id::text])
  );

  return jsonb_build_object(
    'ok',    true,
    'doc',   jsonb_build_object('id', v_order_id, 'number', v_number),
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply'),
      'branch_orders:' || p_branch_id::text,
        (select version from public.data_versions where key = 'branch_orders:' || p_branch_id::text)
    )
  );
end;
$function$;

revoke all on function public.create_branch_order(uuid,uuid,text,jsonb) from public, anon;
grant execute on function public.create_branch_order(uuid,uuid,text,jsonb) to authenticated;

CREATE OR REPLACE FUNCTION public.receive_branch_order(p_client_id uuid, p_order_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id  uuid := auth.uid();
  v_order    record;
  v_br_name  text;
  v_new_ver  bigint;
begin
  -- ── 1. التحقق من المستخدم ─────────────────────────────────────────────────
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  -- ── 2. قفل الطلب ──────────────────────────────────────────────────────────
  select id, number, status, version, branch_id
  into   v_order
  from   public.branch_orders
  where  id = p_order_id
  for update;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  -- ── 3. التحقق من صلاحية الفرع والدور ────────────────────────────────────
  perform public._assert_branch_allowed(v_order.branch_id);

  if not _can_act_for_branch(v_order.branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if not _has_role('cashier', 'branch_manager', 'owner') then
    raise exception 'تأكيد الاستلام للكاشير ومدير الفرع فقط';
  end if;

  -- ── 4. idempotency: لو مستلم بالفعل ارجع نجاحاً بدون أي تغيير ──────────
  if v_order.status = 'received' then
    return jsonb_build_object(
      'ok',  true,
      'doc', jsonb_build_object(
        'id',      v_order.id,
        'number',  v_order.number,
        'status',  v_order.status,
        'version', v_order.version
      ),
      'stamps', jsonb_build_object(
        'branch_orders:' || v_order.branch_id::text,
        coalesce(
          (select version from public.data_versions
            where key = 'branch_orders:' || v_order.branch_id::text),
          0
        )
      )
    );
  end if;

  -- ── 5. يقبل فقط الحالة 'approved' ────────────────────────────────────────
  if v_order.status != 'approved' then
    raise exception 'لا يمكن تأكيد استلام طلب بحالة: %', v_order.status;
  end if;

  -- ── 6. التحقق من الإصدار ─────────────────────────────────────────────────
  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  -- ── 7. تحديث الحالة
  --    trigger trg_branch_orders_version (04_documents.sql:1181) يزيد version تلقائياً
  update public.branch_orders
  set    status      = 'received',
         received_at = now(),
         received_by = v_user_id
  where  id          = p_order_id;

  -- ── 8. بمب البصمة ─────────────────────────────────────────────────────────
  perform _bump_data_version('branch_orders:' || v_order.branch_id::text);

  -- ── 9. إشعار لجمهور warehouse ─────────────────────────────────────────────
  --    _notify: 05_notifications.sql:69
  select name into v_br_name from public.branches where id = v_order.branch_id;

  perform _notify(
    'branch_order_received',
    array['warehouse'],
    v_order.branch_id,
    'استلام طلبية فرع: ' || v_order.number,
    'الفرع: ' || coalesce(v_br_name, v_order.branch_id::text) || ' — تم تأكيد الاستلام',
    jsonb_build_object(
      'ref_type', 'branch_order',
      'ref_id',   p_order_id,
      'domains',  array['branch_orders:' || v_order.branch_id::text]
    )
  );

  -- ── 10. اقرأ الـ version الجديد (بعد trigger) ────────────────────────────
  select version into v_new_ver from public.branch_orders where id = p_order_id;

  -- ── 11. الرد ──────────────────────────────────────────────────────────────
  return jsonb_build_object(
    'ok',  true,
    'doc', jsonb_build_object(
      'id',      v_order.id,
      'number',  v_order.number,
      'status',  'received',
      'version', v_new_ver
    ),
    'stamps', jsonb_build_object(
      'branch_orders:' || v_order.branch_id::text,
      coalesce(
        (select version from public.data_versions
          where key = 'branch_orders:' || v_order.branch_id::text),
        0
      )
    )
  );
end;
$function$;

revoke all on function public.receive_branch_order(uuid,uuid,bigint) from public, anon;
grant execute on function public.receive_branch_order(uuid,uuid,bigint) to authenticated;

CREATE OR REPLACE FUNCTION public.update_branch_order(p_order_id uuid, p_expected_version bigint, p_notes text DEFAULT NULL::text, p_lines jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_user_id  uuid := auth.uid();
  v_order    record;
  v_line     jsonb;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id, status, version, branch_id into v_order
  from public.branch_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  perform public._assert_branch_allowed(v_order.branch_id);

  if not _can_act_for_branch(v_order.branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للطلبية';
  end if;

  if v_order.status != 'submitted' then
    raise exception 'لا يمكن تعديل الطلب بعد مراجعته';
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  -- استبدل السطور كاملاً
  delete from public.branch_order_lines where order_id = p_order_id;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.branch_order_lines (order_id, item_id, qty_requested)
    values (p_order_id, (v_line->>'item_id')::uuid, (v_line->>'qty_requested')::numeric);
  end loop;

  update public.branch_orders
  set notes = coalesce(p_notes, notes)
  where id = p_order_id;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('branch_orders:' || v_order.branch_id::text);

  perform _notify(
    'branch_order_updated',
    array['accounting', 'warehouse'],
    v_order.branch_id,
    'تعديل طلبية فرع',
    'تم تعديل الطلب من قِبل الفرع',
    jsonb_build_object('ref_type', 'branch_order', 'ref_id', p_order_id,
      'domains', array['inv_supply', 'branch_orders:' || v_order.branch_id::text])
  );

  return jsonb_build_object('ok', true,
    'doc', jsonb_build_object('id', p_order_id),
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply')
    )
  );
end;
$function$;

revoke all on function public.update_branch_order(uuid,bigint,text,jsonb) from public, anon;
grant execute on function public.update_branch_order(uuid,bigint,text,jsonb) to authenticated;

CREATE OR REPLACE FUNCTION public.cancel_branch_order(p_order_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_order record;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id, status, version, branch_id into v_order
  from public.branch_orders
  where id = p_order_id
  for update;

  if not found then raise exception 'الطلب غير موجود'; end if;

  perform public._assert_branch_allowed(v_order.branch_id);

  if not _can_act_for_branch(v_order.branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if v_order.status != 'submitted' then
    raise exception 'لا يمكن إلغاء الطلب بعد مراجعته';
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  update public.branch_orders set status = 'cancelled' where id = p_order_id;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('branch_orders:' || v_order.branch_id::text);

  return jsonb_build_object('ok', true,
    'doc', jsonb_build_object('id', p_order_id, 'status', 'cancelled'));
end;
$function$;

revoke all on function public.cancel_branch_order(uuid,bigint) from public, anon;
grant execute on function public.cancel_branch_order(uuid,bigint) to authenticated;

notify pgrst, 'reload schema';
