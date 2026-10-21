-- =============================================================================
-- 024_accounting_rpcs.sql
-- قسم الحسابات — RPCs وجداول الدعم
-- يُشغَّل على Supabase مرة واحدة (idempotent حيث أمكن)
-- =============================================================================

-- =============================================================================
-- § 1 — جداول الدعم الجديدة
-- =============================================================================

-- 1-أ) closing_reviews: سجل مراجعة الإقفالات من المحاسب
-- يُحفظ العجز الأصلي في shift_closings.difference دون تعديله
create table if not exists public.closing_reviews (
  id                    uuid        primary key default gen_random_uuid(),
  closing_id            uuid        not null references public.shift_closings(id),
  original_difference   numeric(12,2) not null,   -- نسخة من difference عند المراجعة
  reviewed_difference   numeric(12,2) not null,   -- العجز المعتمد بعد المراجعة
  review_reason         text,                     -- سبب التعديل (اختياري إذا لم يتغير)
  accountant_notes      text,                     -- ملاحظات المحاسب
  reviewed_by           uuid        not null references auth.users(id),
  reviewed_at           timestamptz not null default now(),
  deduction_request_id  uuid        references public.deduction_bonus_requests(id),
  constraint closing_reviews_reviewed_diff_check
    check (reviewed_difference >= 0)
);

comment on table public.closing_reviews is
  'مراجعات المحاسب للإقفالات — لا تُعدَّل shift_closings بل يُضاف سجل هنا';
comment on column public.closing_reviews.original_difference is
  'نسخة من difference وقت المراجعة — للمقارنة التاريخية';
comment on column public.closing_reviews.deduction_request_id is
  'FK إلى deduction_bonus_requests — يُملأ عند الإحالة إلى HR';

create unique index if not exists idx_closing_reviews_closing
  on public.closing_reviews (closing_id);   -- مراجعة واحدة لكل إقفال

create index if not exists idx_closing_reviews_deduction
  on public.closing_reviews (deduction_request_id)
  where deduction_request_id is not null;

alter table public.closing_reviews enable row level security;
revoke all on table public.closing_reviews from public, anon, authenticated;

-- 1-ب) salary_history: سجل تعديلات الرواتب
create table if not exists public.salary_history (
  id              uuid        primary key default gen_random_uuid(),
  employee_id     uuid        not null references public.employees(id),
  old_basic       numeric(12,2) not null,
  new_basic       numeric(12,2) not null,
  change_reason   text        not null check (btrim(change_reason) <> ''),
  effective_date  date        not null,
  changed_by      uuid        not null references auth.users(id),
  changed_at      timestamptz not null default now()
);

comment on table public.salary_history is
  'سجل تاريخي لتعديلات الرواتب — لا يؤثر على مسيرات الرواتب المغلقة';

create index if not exists idx_salary_history_employee
  on public.salary_history (employee_id, effective_date desc);

alter table public.salary_history enable row level security;
revoke all on table public.salary_history from public, anon, authenticated;

-- =============================================================================
-- § 2 — RPCs المبيعات
-- =============================================================================

-- 2-أ) ملخص المبيعات لكل الفروع (أو فرع محدد) خلال فترة
create or replace function public.acc_get_sales_summary(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'ليس لديك صلاحية للوصول لتقارير المبيعات';
  end if;
  if p_from is null or p_to is null then
    raise exception 'يجب تحديد نطاق التاريخ';
  end if;

  return coalesce((
    select jsonb_build_object(
      'total_sales',     coalesce(sum(s.total), 0),
      'total_discount',  coalesce(sum(s.discount_amount), 0),
      'total_vat',       coalesce(sum(s.vat_amount), 0),
      'invoices_count',  count(*),
      'by_branch', coalesce((
        select jsonb_agg(row_to_json(br.*) order by br.branch_name)
        from (
          select
            s2.branch_id,
            s2.branch_name,
            s2.branch_code,
            count(*)                            as invoices_count,
            coalesce(sum(s2.total), 0)          as total_sales,
            coalesce(sum(s2.discount_amount), 0) as total_discount,
            coalesce(sum(s2.vat_amount), 0)     as total_vat,
            coalesce(sum(s2.total) - sum(s2.discount_amount), 0) as net_sales
          from public.sales s2
          where s2.sold_at between p_from and p_to
            and s2.status = 'completed'
            and (p_branch_id is null or s2.branch_id = p_branch_id)
          group by s2.branch_id, s2.branch_name, s2.branch_code
        ) br
      ), '[]'::jsonb)
    )
    from public.sales s
    where s.sold_at between p_from and p_to
      and s.status = 'completed'
      and (p_branch_id is null or s.branch_id = p_branch_id)
  ), jsonb_build_object(
    'total_sales', 0, 'total_discount', 0, 'total_vat', 0,
    'invoices_count', 0, 'by_branch', '[]'::jsonb
  ));
end;
$$;

revoke all on function public.acc_get_sales_summary(timestamptz,timestamptz,uuid)
  from public, anon;
grant execute on function public.acc_get_sales_summary(timestamptz,timestamptz,uuid)
  to authenticated;

-- 2-ب) تفاصيل الفواتير (مع الأصناف) خلال فترة
create or replace function public.acc_get_sales_detail(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid    default null,
  p_limit     integer default 200,
  p_offset    integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'ليس لديك صلاحية للوصول لتفاصيل المبيعات';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',              s.id,
        'invoice_number',  s.invoice_number,
        'branch_id',       s.branch_id,
        'branch_name',     s.branch_name,
        'branch_code',     s.branch_code,
        'cashier_name',    s.cashier_name,
        'shift',           s.shift,
        'payment_method',  s.payment_method,
        'subtotal',        s.subtotal,
        'discount_amount', s.discount_amount,
        'vat_amount',      s.vat_amount,
        'total',           s.total,
        'notes',           s.notes,
        'status',          s.status,
        'sold_at',         s.sold_at,
        'items', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'product_name',  si.product_name,
            'variant_label', si.variant_label,
            'qty',           si.qty,
            'unit_price',    si.unit_price,
            'subtotal',      si.subtotal
          ) order by si.created_at), '[]'::jsonb)
          from public.sale_items si
          where si.sale_id = s.id
        )
      ) order by s.sold_at desc
    )
    from public.sales s
    where s.sold_at between p_from and p_to
      and s.status = 'completed'
      and (p_branch_id is null or s.branch_id = p_branch_id)
    limit p_limit offset p_offset
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_sales_detail(timestamptz,timestamptz,uuid,integer,integer)
  from public, anon;
grant execute on function public.acc_get_sales_detail(timestamptz,timestamptz,uuid,integer,integer)
  to authenticated;

-- =============================================================================
-- § 3 — RPCs الإقفالات
-- =============================================================================

-- 3-أ) قائمة الإقفالات مع بيانات المراجعة
create or replace function public.acc_get_closings(
  p_from      timestamptz  default null,
  p_to        timestamptz  default null,
  p_branch_id uuid         default null,
  p_filter    text         default 'all'
  -- all | with_diff | no_diff | surplus | not_reviewed | reviewed | hr_pending | hr_done
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'ليس لديك صلاحية للوصول لسجلات الإقفالات';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',               sc.id,
        'branch_id',        sc.branch_id,
        'branch_name',      sc.branch_name,
        'branch_code',      sc.branch_code,
        'cashier_id',       sc.cashier_id,
        'cashier_name',     sc.cashier_name,
        'shift',            sc.shift,
        'opened_at',        sc.opened_at,
        'closed_at',        sc.closed_at,
        'invoices_count',   sc.invoices_count,
        'cash_sales',       sc.cash_sales,
        'card_sales',       sc.card_sales,
        'total_sales',      sc.total_sales,
        'discounts_total',  sc.discounts_total,
        'opening_cash',     sc.opening_cash,
        'expected_cash',    sc.expected_cash,
        'counted_cash',     sc.counted_cash,
        'difference',       sc.difference,
        'has_mismatch',     sc.has_mismatch,
        'notes',            sc.notes,
        -- بيانات المراجعة
        'review', case when cr.id is not null then jsonb_build_object(
          'id',                  cr.id,
          'original_difference', cr.original_difference,
          'reviewed_difference', cr.reviewed_difference,
          'review_reason',       cr.review_reason,
          'accountant_notes',    cr.accountant_notes,
          'reviewed_at',         cr.reviewed_at,
          'deduction_request_id', cr.deduction_request_id,
          'deduction_status', dbr.status
        ) else null end
      ) order by sc.closed_at desc
    )
    from public.shift_closings sc
    left join public.closing_reviews cr on cr.closing_id = sc.id
    left join public.deduction_bonus_requests dbr on dbr.id = cr.deduction_request_id
    where (p_from is null or sc.closed_at >= p_from)
      and (p_to   is null or sc.closed_at <= p_to)
      and (p_branch_id is null or sc.branch_id = p_branch_id)
      and (
        p_filter = 'all'
        or (p_filter = 'with_diff'    and sc.difference < 0)
        or (p_filter = 'surplus'      and sc.difference > 0)
        or (p_filter = 'no_diff'      and sc.difference = 0)
        or (p_filter = 'not_reviewed' and cr.id is null)
        or (p_filter = 'reviewed'     and cr.id is not null)
        or (p_filter = 'hr_pending'   and dbr.status = 'pending')
        or (p_filter = 'hr_done'      and dbr.status in ('approved','rejected'))
      )
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_closings(timestamptz,timestamptz,uuid,text)
  from public, anon;
grant execute on function public.acc_get_closings(timestamptz,timestamptz,uuid,text)
  to authenticated;

-- 3-ب) تسجيل مراجعة إقفال (تعديل العجز المعتمد)
create or replace function public.acc_review_closing(
  p_closing_id          uuid,
  p_reviewed_difference numeric,   -- العجز المعتمد (موجب دائماً)
  p_review_reason       text       default null,
  p_accountant_notes    text       default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid     uuid := auth.uid();
  v_closing public.shift_closings%rowtype;
  v_review  public.closing_reviews%rowtype;
  v_id      uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية لمراجعة الإقفالات';
  end if;
  if p_reviewed_difference is null or p_reviewed_difference < 0 then
    raise exception 'قيمة العجز المعتمد يجب أن تكون صفراً أو أكثر';
  end if;

  select * into v_closing from public.shift_closings
  where id = p_closing_id;
  if not found then raise exception 'الإقفال غير موجود'; end if;

  -- تحقق من عدم وجود مراجعة سابقة مرتبطة بخصم معتمد
  select * into v_review from public.closing_reviews where closing_id = p_closing_id;
  if found and v_review.deduction_request_id is not null then
    -- تحقق من حالة طلب الخصم
    if exists (
      select 1 from public.deduction_bonus_requests
      where id = v_review.deduction_request_id and status = 'approved'
    ) then
      raise exception 'لا يمكن تعديل مراجعة إقفال تم اعتماد خصمه بالفعل';
    end if;
  end if;

  insert into public.closing_reviews (
    closing_id, original_difference, reviewed_difference,
    review_reason, accountant_notes, reviewed_by
  ) values (
    p_closing_id,
    abs(v_closing.difference),   -- نحفظ القيمة المطلقة للعجز الأصلي
    p_reviewed_difference,
    nullif(btrim(coalesce(p_review_reason, '')), ''),
    nullif(btrim(coalesce(p_accountant_notes, '')), ''),
    v_uid
  )
  on conflict (closing_id) do update set
    reviewed_difference = excluded.reviewed_difference,
    review_reason       = excluded.review_reason,
    accountant_notes    = excluded.accountant_notes,
    reviewed_by         = excluded.reviewed_by,
    reviewed_at         = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'review_id', v_id);
end;
$$;

revoke all on function public.acc_review_closing(uuid,numeric,text,text)
  from public, anon;
grant execute on function public.acc_review_closing(uuid,numeric,text,text)
  to authenticated;

-- 3-ج) إحالة العجز إلى HR كطلب خصم
create or replace function public.acc_refer_closing_to_hr(
  p_closing_id  uuid,
  p_employee_id uuid,
  p_amount      numeric,   -- قيمة الخصم المقترحة (نقدية)
  p_reason      text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_closing   public.shift_closings%rowtype;
  v_review    public.closing_reviews%rowtype;
  v_employee  public.employees%rowtype;
  v_req_id    uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية لإحالة العجز إلى HR';
  end if;

  -- تحقق من الإقفال
  select * into v_closing from public.shift_closings where id = p_closing_id;
  if not found then raise exception 'الإقفال غير موجود'; end if;
  if v_closing.difference >= 0 then
    raise exception 'هذا الإقفال لا يحتوي على عجز';
  end if;

  -- تحقق من وجود مراجعة
  select * into v_review from public.closing_reviews where closing_id = p_closing_id;
  if not found then
    raise exception 'يجب مراجعة الإقفال وتحديد العجز المعتمد قبل الإحالة';
  end if;

  -- منع طلب خصم مكرر على نفس الإقفال
  if v_review.deduction_request_id is not null then
    if exists (
      select 1 from public.deduction_bonus_requests
      where id = v_review.deduction_request_id and status = 'pending'
    ) then
      raise exception 'يوجد طلب خصم معلق بالفعل لهذا الإقفال';
    end if;
  end if;

  -- تحقق من الموظف
  select * into v_employee from public.employees
  where id = p_employee_id and status = 'active';
  if not found then raise exception 'الموظف غير موجود أو غير نشط'; end if;

  -- تحقق من قيمة الخصم
  if p_amount is null or p_amount <= 0 then
    raise exception 'قيمة الخصم يجب أن تكون أكبر من صفر';
  end if;
  if p_amount > v_review.reviewed_difference then
    raise exception 'قيمة الخصم لا يمكن أن تتجاوز العجز المعتمد';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'سبب الخصم مطلوب';
  end if;

  -- إنشاء طلب الخصم
  insert into public.deduction_bonus_requests (
    employee_id, requested_from, type, amount_type,
    cash_amount, notes, created_by
  ) values (
    p_employee_id,
    'hr',           -- يظهر في قسم HR كطلب قادم من الحسابات
    'deduction',
    'cash',
    round(p_amount, 2),
    'عجز إقفال: ' || v_closing.branch_name || ' — ' ||
      to_char(v_closing.closed_at at time zone 'Africa/Cairo', 'YYYY-MM-DD') ||
      ' — ' || btrim(p_reason),
    v_uid
  ) returning id into v_req_id;

  -- ربط الطلب بسجل المراجعة
  update public.closing_reviews
  set deduction_request_id = v_req_id
  where closing_id = p_closing_id;

  -- إشعار HR
  perform _notify(
    'deduction_request',
    array['hr'],
    v_closing.branch_id,
    'طلب خصم عجز إقفال: ' || v_closing.branch_name,
    'كاشير: ' || coalesce(v_employee.full_name, '') ||
      ' — قيمة الخصم: ' || p_amount::text || ' ر.س',
    jsonb_build_object(
      'ref_type', 'closing_review',
      'ref_id',    v_review.id,
      'closing_id', p_closing_id
    )
  );

  return jsonb_build_object('ok', true, 'deduction_request_id', v_req_id);
end;
$$;

revoke all on function public.acc_refer_closing_to_hr(uuid,uuid,numeric,text)
  from public, anon;
grant execute on function public.acc_refer_closing_to_hr(uuid,uuid,numeric,text)
  to authenticated;

-- =============================================================================
-- § 4 — RPCs المصروفات
-- =============================================================================

-- 4-أ) كل المصروفات لجميع الفروع (أو فرع محدد)
create or replace function public.acc_get_all_expenses(
  p_from      timestamptz default null,
  p_to        timestamptz default null,
  p_branch_id uuid        default null,
  p_category  text        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'ليس لديك صلاحية للوصول لسجلات المصروفات';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',             ei.id,
        'invoice_number', ei.invoice_number,
        'branch_id',      ei.branch_id,
        'branch_name',    ei.branch_name,
        'branch_code',    ei.branch_code,
        'cashier_name',   ei.cashier_name,
        'category',       ei.category,
        'payee',          ei.payee,
        'description',    ei.description,
        'amount',         ei.amount,
        'vat_amount',     ei.vat_amount,
        'total',          ei.total,
        'payment_method', ei.payment_method,
        'expense_date',   ei.expense_date,
        'notes',          ei.notes,
        'created_at',     ei.created_at
      ) order by ei.created_at desc
    )
    from public.expense_invoices ei
    where (p_from is null or ei.created_at >= p_from)
      and (p_to   is null or ei.created_at <= p_to)
      and (p_branch_id is null or ei.branch_id = p_branch_id)
      and (p_category  is null or ei.category = p_category)
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_all_expenses(timestamptz,timestamptz,uuid,text)
  from public, anon;
grant execute on function public.acc_get_all_expenses(timestamptz,timestamptz,uuid,text)
  to authenticated;

-- =============================================================================
-- § 5 — RPCs المشتريات (طلبات التوريد من المحاسب)
-- =============================================================================

-- 5-أ) قائمة طلبات التوريد للمحاسب
create or replace function public.acc_get_supply_orders(
  p_from   timestamptz default null,
  p_to     timestamptz default null,
  p_status text        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية للوصول لطلبات التوريد';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',            so.id,
        'number',        so.number,
        'supplier_id',   so.supplier_id,
        'supplier_name', sup.name,
        'expected_date', so.expected_date,
        'priority',      so.priority,
        'status',        so.status,
        'notes',         so.notes,
        'created_at',    so.created_at,
        'lines', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'item_id',       sol.item_id,
            'item_name',     ii.name,
            'unit',          ii.unit,
            'qty_requested', sol.qty_requested,
            'qty_approved',  sol.qty_approved,
            'qty_received',  sol.qty_received,
            'unit_cost',     sol.unit_cost
          )), '[]'::jsonb)
          from public.supply_order_lines sol
          join public.inventory_items ii on ii.id = sol.item_id
          where sol.order_id = so.id
        )
      ) order by so.created_at desc
    )
    from public.supply_orders so
    join public.suppliers sup on sup.id = so.supplier_id
    where (p_from   is null or so.created_at >= p_from)
      and (p_to     is null or so.created_at <= p_to)
      and (p_status is null or so.status = p_status)
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_supply_orders(timestamptz,timestamptz,text)
  from public, anon;
grant execute on function public.acc_get_supply_orders(timestamptz,timestamptz,text)
  to authenticated;

-- 5-ب) إنشاء طلب توريد من المحاسب (مسار مختلف عن storekeeper)
create or replace function public.acc_create_supply_order(
  p_client_id     uuid,
  p_supplier_name text,
  p_supplier_phone text   default null,
  p_expected_date  date   default null,
  p_priority       text   default 'normal',
  p_notes          text   default null,
  p_lines          jsonb  default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid         uuid := auth.uid();
  v_order_id    uuid;
  v_number      text;
  v_supplier_id uuid;
  v_year        text;
  v_line        jsonb;
  v_existing    jsonb;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'إنشاء طلبات التوريد من الحسابات يتطلب صلاحية accountant';
  end if;
  if p_expected_date is null then
    raise exception 'تاريخ التوريد المتوقع مطلوب';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للطلب';
  end if;
  if coalesce(btrim(p_supplier_name), '') = '' then
    raise exception 'اسم المورد مطلوب';
  end if;

  -- idempotency
  select jsonb_build_object('id', so.id, 'number', so.number, 'already_exists', true)
    into v_existing
  from public.supply_orders so
  where so.client_id = p_client_id;
  if found then return v_existing; end if;

  -- المورد: جلب أو إنشاء
  select id into v_supplier_id from public.suppliers
  where lower(btrim(name)) = lower(btrim(p_supplier_name))
  limit 1;

  if v_supplier_id is null then
    insert into public.suppliers (name, phone)
    values (btrim(p_supplier_name), p_supplier_phone)
    returning id into v_supplier_id;
  end if;

  -- رقم الطلب
  v_year := to_char(now(), 'YYYY');
  v_number := _next_doc_number('supply_order', v_year, 'PO-' || v_year || '-{n:4}');

  -- إنشاء الطلب
  insert into public.supply_orders (
    client_id, number, supplier_id, expected_date, priority, notes, created_by
  ) values (
    p_client_id, v_number, v_supplier_id, p_expected_date,
    coalesce(p_priority, 'normal'), nullif(btrim(coalesce(p_notes,'')), ''), v_uid
  ) returning id into v_order_id;

  -- السطور
  for v_line in select value from jsonb_array_elements(p_lines) loop
    insert into public.supply_order_lines (order_id, item_id, qty_requested, unit_cost)
    values (
      v_order_id,
      (v_line->>'item_id')::uuid,
      (v_line->>'qty_requested')::numeric,
      coalesce(nullif(v_line->>'unit_cost','')::numeric, 0)
    );
  end loop;

  -- إشعار المستودع
  perform _notify(
    'supply_order_created',
    array['warehouse'],
    null,
    'طلب توريد جديد من الحسابات: ' || v_number,
    'بانتظار المراجعة والاستلام',
    jsonb_build_object('ref_type', 'supply_order', 'ref_id', v_order_id)
  );

  return jsonb_build_object(
    'id', v_order_id, 'number', v_number, 'already_exists', false
  );
end;
$$;

revoke all on function public.acc_create_supply_order(uuid,text,text,date,text,text,jsonb)
  from public, anon;
grant execute on function public.acc_create_supply_order(uuid,text,text,date,text,text,jsonb)
  to authenticated;

-- =============================================================================
-- § 6 — RPCs المخزون (نظرة رقابية)
-- =============================================================================

-- 6-أ) نظرة عامة على المخزون للمحاسب
create or replace function public.acc_get_inventory_overview(
  p_warehouse_id uuid   default null,
  p_category     text   default null,
  p_status       text   default null  -- available | low | out
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية للوصول لبيانات المخزون';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'item_id',       ii.id,
        'code',          ii.code,
        'name',          ii.name,
        'category',      ii.category,
        'unit',          ii.unit,
        'warehouse_id',  sb.warehouse_id,
        'warehouse_name', w.name,
        'warehouse_kind', w.kind,
        'qty',           coalesce(sb.qty, 0),
        'min_qty',       ii.min_qty,
        'unit_cost',     ii.unit_cost,
        'sale_price',    ii.sale_price,
        'stock_value',   round(coalesce(sb.qty, 0) * coalesce(ii.unit_cost, 0), 2),
        'status',
          case
            when coalesce(sb.qty, 0) <= 0 then 'out'
            when ii.min_qty is not null and coalesce(sb.qty, 0) <= ii.min_qty then 'low'
            else 'available'
          end
      ) order by ii.category, ii.name
    )
    from public.inventory_items ii
    left join public.stock_balances sb on sb.item_id = ii.id
      and (p_warehouse_id is null or sb.warehouse_id = p_warehouse_id)
    left join public.warehouses w on w.id = sb.warehouse_id
    where ii.is_active = true
      and (p_category is null or ii.category = p_category)
      and (
        p_status is null
        or (p_status = 'out'       and coalesce(sb.qty, 0) <= 0)
        or (p_status = 'low'       and ii.min_qty is not null
                                    and coalesce(sb.qty, 0) > 0
                                    and coalesce(sb.qty, 0) <= ii.min_qty)
        or (p_status = 'available' and coalesce(sb.qty, 0) > coalesce(ii.min_qty, 0))
      )
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_inventory_overview(uuid,text,text) from public, anon;
grant execute on function public.acc_get_inventory_overview(uuid,text,text) to authenticated;

-- 6-ب) تعديل سعر صنف (sale_price أو unit_cost)
create or replace function public.acc_update_item_price(
  p_item_id  uuid,
  p_field    text,     -- 'sale_price' | 'unit_cost'
  p_value    numeric,
  p_reason   text      default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid      uuid := auth.uid();
  v_item     public.inventory_items%rowtype;
  v_old_val  numeric;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية لتعديل أسعار الأصناف';
  end if;
  if p_field not in ('sale_price', 'unit_cost') then
    raise exception 'الحقل غير مسموح به: %', p_field;
  end if;
  if p_value is null or p_value < 0 then
    raise exception 'القيمة يجب أن تكون صفراً أو أكثر';
  end if;

  select * into v_item from public.inventory_items where id = p_item_id;
  if not found then raise exception 'الصنف غير موجود'; end if;

  v_old_val := case p_field when 'sale_price' then v_item.sale_price
                             else v_item.unit_cost end;

  if p_field = 'sale_price' then
    update public.inventory_items set sale_price = p_value where id = p_item_id;
  else
    update public.inventory_items set unit_cost = p_value where id = p_item_id;
  end if;

  -- سجل التدقيق في notes أو يمكن إضافة جدول audit مستقل لاحقاً
  -- هنا نستخدم RAISE NOTICE كسجل في logs الخادم
  raise notice 'PRICE_CHANGE: item=% field=% old=% new=% by=% reason=%',
    p_item_id, p_field, v_old_val, p_value, v_uid, coalesce(p_reason, '');

  return jsonb_build_object(
    'ok', true,
    'item_id', p_item_id,
    'field', p_field,
    'old_value', v_old_val,
    'new_value', p_value
  );
end;
$$;

revoke all on function public.acc_update_item_price(uuid,text,numeric,text) from public, anon;
grant execute on function public.acc_update_item_price(uuid,text,numeric,text) to authenticated;

-- 6-ج) تعديل الحد الأدنى للمخزون
create or replace function public.acc_update_min_stock(
  p_item_id  uuid,
  p_min_qty  numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner', 'storekeeper') then
    raise exception 'ليس لديك صلاحية لتعديل الحد الأدنى';
  end if;
  if p_min_qty is null or p_min_qty < 0 then
    raise exception 'الحد الأدنى يجب أن يكون صفراً أو أكثر';
  end if;
  if not exists (select 1 from public.inventory_items where id = p_item_id) then
    raise exception 'الصنف غير موجود';
  end if;

  update public.inventory_items set min_qty = p_min_qty where id = p_item_id;

  return jsonb_build_object('ok', true, 'item_id', p_item_id, 'min_qty', p_min_qty);
end;
$$;

revoke all on function public.acc_update_min_stock(uuid,numeric) from public, anon;
grant execute on function public.acc_update_min_stock(uuid,numeric) to authenticated;

-- =============================================================================
-- § 7 — RPCs الرواتب
-- =============================================================================

-- 7-أ) قائمة الموظفين مع الرواتب للمحاسب
create or replace function public.acc_get_employees_salaries(
  p_branch_id uuid   default null,
  p_status    text   default 'active'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية للوصول لبيانات الرواتب';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',                  e.id,
        'code',                e.code,
        'full_name',           e.full_name,
        'job_role',            e.job_role,
        'job_rank',            e.job_rank,
        'branch_id',           e.branch_id,
        'branch_name',         b.name,
        'basic_salary',        e.basic_salary,
        'allowances',          e.allowances,
        'transport_allowance', e.transport_allowance,
        'total_fixed',         e.basic_salary + e.allowances + e.transport_allowance,
        'status',              e.status,
        'hire_date',           e.hire_date,
        'last_salary_change', (
          select sh.changed_at
          from public.salary_history sh
          where sh.employee_id = e.id
          order by sh.changed_at desc limit 1
        )
      ) order by b.name nulls last, e.full_name
    )
    from public.employees e
    left join public.branches b on b.id = e.branch_id
    where (p_status is null or e.status = p_status)
      and (p_branch_id is null or e.branch_id = p_branch_id)
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_employees_salaries(uuid,text) from public, anon;
grant execute on function public.acc_get_employees_salaries(uuid,text) to authenticated;

-- 7-ب) تعديل الراتب الأساسي مع سجل تاريخي
create or replace function public.acc_update_salary(
  p_employee_id   uuid,
  p_new_basic     numeric,
  p_change_reason text,
  p_effective_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid      uuid := auth.uid();
  v_employee public.employees%rowtype;
  v_hist_id  uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية لتعديل الرواتب';
  end if;
  if p_new_basic is null or p_new_basic < 0 then
    raise exception 'قيمة الراتب يجب أن تكون صفراً أو أكثر';
  end if;
  if coalesce(btrim(p_change_reason), '') = '' then
    raise exception 'سبب التعديل مطلوب';
  end if;

  select * into v_employee from public.employees where id = p_employee_id;
  if not found then raise exception 'الموظف غير موجود'; end if;
  if v_employee.basic_salary = p_new_basic then
    raise exception 'الراتب الجديد مطابق للراتب الحالي';
  end if;

  -- سجل التاريخ
  insert into public.salary_history (
    employee_id, old_basic, new_basic, change_reason, effective_date, changed_by
  ) values (
    p_employee_id, v_employee.basic_salary, p_new_basic,
    btrim(p_change_reason), coalesce(p_effective_date, current_date), v_uid
  ) returning id into v_hist_id;

  -- تحديث الراتب
  update public.employees
  set basic_salary = p_new_basic, updated_at = now()
  where id = p_employee_id;

  return jsonb_build_object(
    'ok', true,
    'history_id', v_hist_id,
    'old_basic', v_employee.basic_salary,
    'new_basic', p_new_basic,
    'effective_date', coalesce(p_effective_date, current_date)
  );
end;
$$;

revoke all on function public.acc_update_salary(uuid,numeric,text,date) from public, anon;
grant execute on function public.acc_update_salary(uuid,numeric,text,date) to authenticated;

-- 7-ج) سجل تغييرات راتب موظف
create or replace function public.acc_get_salary_history(p_employee_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية لعرض سجل الرواتب';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',             sh.id,
      'old_basic',      sh.old_basic,
      'new_basic',      sh.new_basic,
      'change_reason',  sh.change_reason,
      'effective_date', sh.effective_date,
      'changed_at',     sh.changed_at
    ) order by sh.changed_at desc)
    from public.salary_history sh
    where sh.employee_id = p_employee_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_salary_history(uuid) from public, anon;
grant execute on function public.acc_get_salary_history(uuid) to authenticated;

-- =============================================================================
-- § 8 — قائمة الفروع للمحاسب
-- =============================================================================
create or replace function public.acc_list_branches()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'ليس لديك صلاحية';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name', b.name, 'code', b.code
    ) order by b.code)
    from public.branches b
    where b.deleted_at is null and b.is_active = true
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_list_branches() from public, anon;
grant execute on function public.acc_list_branches() to authenticated;

-- =============================================================================
-- § 9 — قائمة الموردين للمحاسب
-- =============================================================================
create or replace function public.acc_list_suppliers()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'name', s.name, 'phone', s.phone
    ) order by s.name)
    from public.suppliers s
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_list_suppliers() from public, anon;
grant execute on function public.acc_list_suppliers() to authenticated;

-- =============================================================================
-- § 10 — تحديث app_modules (accounting = implemented)
-- =============================================================================
-- لا يوجد جدول app_modules — المعلومة موجودة في Flutter فقط في app_modules.dart

notify pgrst, 'reload schema';
