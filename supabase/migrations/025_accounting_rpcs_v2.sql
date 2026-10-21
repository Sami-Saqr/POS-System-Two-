-- =============================================================================
-- 025_accounting_rpcs_v2.sql
-- قسم الحسابات — RPCs مصحّحة بناءً على الـ schema الفعلي وجداول الدعم
-- يُشغَّل على Supabase مرة واحدة (idempotent وآمن لإعادة التشغيل)
-- =============================================================================

-- =============================================================================
-- § 0 — إسقاط الدوال السابقة فقط (لتحديث التوقيعات دون لمس جداول البيانات)
-- =============================================================================

drop function if exists public.acc_get_sales_summary cascade;
drop function if exists public.acc_get_sales_detail cascade;
drop function if exists public.acc_get_closings_dashboard cascade;
drop function if exists public.acc_get_closings cascade;
drop function if exists public.acc_review_closing cascade;
drop function if exists public.acc_refer_closing_to_hr cascade;
drop function if exists public.acc_get_all_expenses cascade;
drop function if exists public.acc_get_supply_orders cascade;
drop function if exists public.acc_create_supply_order cascade;
drop function if exists public.acc_get_inventory_overview cascade;
drop function if exists public.acc_update_item_price cascade;
drop function if exists public.acc_update_min_stock cascade;
drop function if exists public.acc_get_employees_salaries cascade;
drop function if exists public.acc_update_salary cascade;
drop function if exists public.acc_get_salary_history cascade;
drop function if exists public.acc_get_dashboard_alerts cascade;
drop function if exists public.acc_list_branches cascade;
drop function if exists public.acc_list_suppliers cascade;
drop function if exists public.acc_get_branch_employees cascade;

-- =============================================================================
-- § 1 — جداول الدعم الجديدة (إنشاء آمن مع إضافة الأعمدة إن كانت موجودة مسبقاً)
-- =============================================================================

-- 1-أ) closing_reviews: مراجعات المحاسب للإقفالات مع ربط طلب الخصم
create table if not exists public.closing_reviews (
  id                    uuid          primary key default gen_random_uuid(),
  closing_id            uuid          not null references public.shift_closings(id),
  original_difference   numeric(12,2) not null,
  reviewed_difference   numeric(12,2) not null check (reviewed_difference >= 0),
  review_reason         text,
  accountant_notes      text,
  deduction_request_id  uuid          references public.deduction_bonus_requests(id),
  reviewed_by           uuid          not null references auth.users(id),
  reviewed_at           timestamptz   not null default now()
);

-- ضمان وجود العمود لو كان الجدول منشأً سابقاً بدون deduction_request_id
alter table public.closing_reviews
  add column if not exists deduction_request_id uuid references public.deduction_bonus_requests(id);

comment on table public.closing_reviews is
  'مراجعات المحاسب للإقفالات — لا تُعدَّل shift_closings بل يُضاف سجل هنا';

create unique index if not exists idx_closing_reviews_closing
  on public.closing_reviews (closing_id);

create index if not exists idx_closing_reviews_deduction
  on public.closing_reviews (deduction_request_id)
  where deduction_request_id is not null;

create index if not exists idx_closing_reviews_by_reviewer
  on public.closing_reviews (reviewed_by, reviewed_at desc);

alter table public.closing_reviews enable row level security;
revoke all on table public.closing_reviews from public, anon, authenticated;

-- 1-ب) salary_history: سجل تعديلات الرواتب
create table if not exists public.salary_history (
  id                  uuid          primary key default gen_random_uuid(),
  employee_id         uuid          not null references public.employees(id),
  old_basic           numeric(12,2) not null default 0 check (old_basic >= 0),
  new_basic           numeric(12,2) not null default 0 check (new_basic >= 0),
  allowances          numeric(12,2) not null default 0 check (allowances >= 0),
  transport_allowance numeric(12,2) not null default 0 check (transport_allowance >= 0),
  effective_date      date          not null default current_date,
  reason              text          not null,
  changed_by          uuid          not null references auth.users(id),
  changed_at          timestamptz   not null default now()
);

comment on table public.salary_history is
  'سجل تعديلات الرواتب التاريخي مع تتبع الراتب القديم والجديد';

create index if not exists idx_salary_history_employee
  on public.salary_history (employee_id, effective_date desc);

alter table public.salary_history enable row level security;
revoke all on table public.salary_history from public, anon, authenticated;

-- =============================================================================
-- § 2 — توسيع notifications.kind ديناميكياً وتحديث _my_audiences لدعم hr
-- =============================================================================

-- 2-أ) استخراج القائمة الحالية من القيد ديناميكياً وإضافة 'closing_referred' دون مساس بالأنواع السابقة
-- ملاحظة: هذا الكود يعمل فقط إذا كان جدول notifications لا يزال يستخدم قيد kind القديم.
-- في النظام الجديد (027_fix_all_issues) تم إزالة هذا القيد، لذلك نتحقق أولاً.
do $$
declare
  v_con   record;
  v_kinds text[];
begin
  select c.conname, pg_get_constraintdef(c.oid) as def
    into v_con
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public' and t.relname = 'notifications'
    and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%branch_order_submitted%';

  -- إذا لم يوجد القيد القديم — نتجاوز بأمان
  if not found then
    return;
  end if;

  select array_agg(distinct m[1]) into v_kinds
  from regexp_matches(v_con.def, '''([^'']+)''', 'g') as m;

  -- إذا كان القيد موجوداً لكن regexp أعاد null — نهيئ المصفوفة بقيم افتراضية
  if v_kinds is null then
    v_kinds := array[
      'supply_submitted','supply_approved','supply_received_issues',
      'low_stock','branch_order_submitted','branch_order_updated','branch_order_decided'
    ];
  end if;

  if not ('closing_referred' = any (v_kinds)) then
    v_kinds := v_kinds || 'closing_referred'::text;
  end if;

  execute format('alter table public.notifications drop constraint %I', v_con.conname);
  execute format(
    'alter table public.notifications add constraint notifications_kind_check check (kind = any (%L::text[]))',
    v_kinds
  );
end;
$$;

-- 2-ب) تحديث دالة _my_audiences لتشمل جمهور 'hr' لـ HR والمالك
create or replace function public._my_audiences()
returns text[]
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_role text;
begin
  select role into v_role
  from public.profiles
  where id = auth.uid()
    and is_active = true;

  if v_role is null then
    return array[]::text[];
  end if;

  return case v_role
    when 'owner'           then array['accounting', 'warehouse', 'branch', 'hr']
    when 'accountant'      then array['accounting']
    when 'hr'              then array['hr']
    when 'storekeeper'     then array['warehouse']
    when 'cashier'         then array['branch']
    when 'branch_manager'  then array['branch']
    else array[]::text[]
  end;
end;
$$;

revoke execute on function public._my_audiences() from public, anon, authenticated;

-- =============================================================================
-- § 3 — acc_get_sales_summary
-- المصادر:
--   sales (status = 'completed')
--   expense_invoices (status = 'posted')
--   by_branch مجمّعة بـ subquery ثم jsonb_agg
-- =============================================================================
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
  v_uid         uuid := auth.uid();
  v_from        timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to          timestamptz := coalesce(p_to, now());
  v_total_sales numeric := 0;
  v_subtotal    numeric := 0;
  v_discount    numeric := 0;
  v_vat         numeric := 0;
  v_cash_sales  numeric := 0;
  v_card_sales  numeric := 0;
  v_inv_count   bigint  := 0;
  v_exp_total   numeric := 0;
  v_exp_cash    numeric := 0;
  v_by_branch   jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة: لا تملك دور محاسب أو مالك';
  end if;
  if _has_role('branch_manager') and not _has_role('accountant', 'owner') then
    if p_branch_id is null or not _can_act_for_branch(p_branch_id) then
      raise exception 'مدير الفرع يمكنه عرض مبيعات فرعه فقط';
    end if;
  end if;

  -- 1) تجميع المبيعات المكتملة
  select
    coalesce(sum(s.total), 0),
    coalesce(sum(s.subtotal), 0),
    coalesce(sum(s.discount_amount), 0),
    coalesce(sum(s.vat_amount), 0),
    coalesce(sum(s.total) filter (where coalesce(s.payment_method, '') ilike any (array['%cash%', '%كاش%', '%نقد%'])), 0),
    coalesce(sum(s.total) filter (where coalesce(s.payment_method, '') ilike any (array['%card%', '%visa%', '%pos%', '%network%', '%شبكة%', '%مدى%', '%فيزا%', '%بطاق%'])), 0),
    count(*)
  into
    v_total_sales, v_subtotal, v_discount, v_vat,
    v_cash_sales, v_card_sales, v_inv_count
  from public.sales s
  where s.status = 'completed'
    and s.sold_at >= v_from and s.sold_at <= v_to
    and (p_branch_id is null or s.branch_id = p_branch_id);

  -- 2) تجميع المصروفات من expense_invoices المعتمدة (status = 'posted')
  select
    coalesce(sum(ei.total), 0),
    coalesce(sum(ei.total) filter (where ei.payment_method = 'cash'), 0)
  into v_exp_total, v_exp_cash
  from public.expense_invoices ei
  where ei.status = 'posted'
    and ei.expense_date >= (v_from at time zone 'Africa/Cairo')::date
    and ei.expense_date <= (v_to at time zone 'Africa/Cairo')::date
    and (p_branch_id is null or ei.branch_id = p_branch_id);

  -- 3) المبيعات لكل فرع (Subquery مجمعة ثم jsonb_agg نظيف)
  select coalesce(jsonb_agg(row_data), '[]'::jsonb)
  into v_by_branch
  from (
    select jsonb_build_object(
      'branch_id',      s.branch_id,
      'branch_name',    coalesce(s.branch_name, b.name, '—'),
      'total_sales',    coalesce(sum(s.total), 0),
      'invoices_count', count(*)
    ) as row_data
    from public.sales s
    left join public.branches b on b.id = s.branch_id
    where s.status = 'completed'
      and s.sold_at >= v_from and s.sold_at <= v_to
      and (p_branch_id is null or s.branch_id = p_branch_id)
    group by s.branch_id, coalesce(s.branch_name, b.name, '—')
    order by coalesce(sum(s.total), 0) desc
  ) sub;

  return jsonb_build_object(
    'from',           v_from,
    'to',             v_to,
    'branch_id',      p_branch_id,
    'total_sales',    v_total_sales,
    'gross_sales',    v_subtotal,
    'net_sales',      v_total_sales,
    'total_discount', v_discount,
    'total_vat',      v_vat,
    'cash_sales',     v_cash_sales,
    'card_sales',     v_card_sales,
    'invoices_count', v_inv_count,
    'total_expenses', v_exp_total,
    'cash_expenses',  v_exp_cash,
    'net_revenue',    (v_total_sales - v_exp_total),
    'by_branch',      v_by_branch
  );
end;
$$;

revoke all on function public.acc_get_sales_summary(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.acc_get_sales_summary(timestamptz, timestamptz, uuid) to authenticated;

-- =============================================================================
-- § 4 — acc_get_sales_detail (Keyset Pagination مع status='completed' والأصناف)
-- =============================================================================
create or replace function public.acc_get_sales_detail(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid        default null,
  p_limit     int         default 50,
  p_cursor_ts timestamptz default null,
  p_cursor_id uuid        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_from  timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to    timestamptz := coalesce(p_to, now());
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة: لا تملك دور محاسب أو مالك';
  end if;
  if _has_role('branch_manager') and not _has_role('accountant', 'owner') then
    if p_branch_id is null or not _can_act_for_branch(p_branch_id) then
      raise exception 'مدير الفرع يمكنه عرض مبيعات فرعه فقط';
    end if;
  end if;

  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',              s.id,
      'invoice_number',  s.invoice_number,
      'branch_id',       s.branch_id,
      'branch_name',     coalesce(s.branch_name, b.name),
      'cashier_id',      s.cashier_id,
      'cashier_name',    s.cashier_name,
      'subtotal',        s.subtotal,
      'discount_amount', s.discount_amount,
      'vat_amount',      s.vat_amount,
      'total',           s.total,
      'status',          s.status,
      'payment_method',  s.payment_method,
      'sold_at',         s.sold_at,
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',           si.id,
          'product_id',   si.product_id,
          'product_name', si.product_name,
          'qty',          si.qty,
          'unit_price',   si.unit_price,
          'unit_cost',    si.unit_cost,
          'line_total',   si.line_total
        ))
        from public.sale_items si
        where si.sale_id = s.id
      ), '[]'::jsonb)
    ) as row_data
    from public.sales s
    left join public.branches b on b.id = s.branch_id
    where s.status = 'completed'
      and s.sold_at >= v_from and s.sold_at <= v_to
      and (p_branch_id is null or s.branch_id = p_branch_id)
      and (
        p_cursor_ts is null
        or (s.sold_at, s.id) < (p_cursor_ts, p_cursor_id)
      )
    order by s.sold_at desc, s.id desc
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
end;
$$;

revoke all on function public.acc_get_sales_detail(timestamptz, timestamptz, uuid, int, timestamptz, uuid) from public, anon;
grant execute on function public.acc_get_sales_detail(timestamptz, timestamptz, uuid, int, timestamptz, uuid) to authenticated;

-- =============================================================================
-- § 5 — acc_get_closings_dashboard
-- Subquery مرتبة ومحدودة بـ 20 ثم jsonb_agg
-- =============================================================================
create or replace function public.acc_get_closings_dashboard(
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
  v_uid   uuid := auth.uid();
  v_from  timestamptz := coalesce(p_from, now() - interval '30 days');
  v_to    timestamptz := coalesce(p_to, now());
  v_rows  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select coalesce(jsonb_agg(row_data), '[]'::jsonb)
  into v_rows
  from (
    select jsonb_build_object(
      'id',                  sc.id,
      'branch_id',           sc.branch_id,
      'branch_name',         coalesce(b.name, '—'),
      'cashier_id',          sc.cashier_id,
      'cashier_name',        coalesce(p.full_name, split_part(u.email, '@', 1), '—'),
      'opening_cash',        sc.opening_cash,
      'counted_cash',        sc.counted_cash,
      'expected_cash',       sc.expected_cash,
      'difference',          sc.difference,
      'closed_at',           sc.closed_at,
      'has_review',          cr.id is not null,
      'reviewed_difference', cr.reviewed_difference,
      'deduction_status',    dbr.status
    ) as row_data
    from public.shift_closings sc
    left join public.branches b on b.id = sc.branch_id
    left join auth.users u on u.id = sc.cashier_id
    left join public.profiles p on p.id = sc.cashier_id
    left join public.closing_reviews cr on cr.closing_id = sc.id
    left join public.deduction_bonus_requests dbr on dbr.id = cr.deduction_request_id
    where sc.closed_at >= v_from and sc.closed_at <= v_to
      and (p_branch_id is null or sc.branch_id = p_branch_id)
    order by sc.closed_at desc
    limit 20
  ) sub;

  return v_rows;
end;
$$;

revoke all on function public.acc_get_closings_dashboard(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.acc_get_closings_dashboard(timestamptz, timestamptz, uuid) to authenticated;

-- =============================================================================
-- § 6 — acc_get_closings (Keyset Pagination)
-- =============================================================================
create or replace function public.acc_get_closings(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid        default null,
  p_limit     int         default 50,
  p_cursor_ts timestamptz default null,
  p_cursor_id uuid        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_from  timestamptz := coalesce(p_from, now() - interval '60 days');
  v_to    timestamptz := coalesce(p_to, now());
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',                  sc.id,
      'branch_id',           sc.branch_id,
      'branch_name',         coalesce(b.name, '—'),
      'cashier_id',          sc.cashier_id,
      'cashier_name',        coalesce(p.full_name, split_part(u.email, '@', 1), '—'),
      'opening_cash',        sc.opening_cash,
      'counted_cash',        sc.counted_cash,
      'expected_cash',       sc.expected_cash,
      'difference',          sc.difference,
      'closed_at',           sc.closed_at,
      'review', case
        when cr.id is not null then jsonb_build_object(
          'id',                   cr.id,
          'original_difference',  cr.original_difference,
          'reviewed_difference',  cr.reviewed_difference,
          'review_reason',        cr.review_reason,
          'accountant_notes',     cr.accountant_notes,
          'reviewed_at',          cr.reviewed_at,
          'deduction_request_id', cr.deduction_request_id,
          'deduction_status',     dbr.status
        )
        else null
      end
    ) as row_data
    from public.shift_closings sc
    left join public.branches b on b.id = sc.branch_id
    left join auth.users u on u.id = sc.cashier_id
    left join public.profiles p on p.id = sc.cashier_id
    left join public.closing_reviews cr on cr.closing_id = sc.id
    left join public.deduction_bonus_requests dbr on dbr.id = cr.deduction_request_id
    where sc.closed_at >= v_from and sc.closed_at <= v_to
      and (p_branch_id is null or sc.branch_id = p_branch_id)
      and (
        p_cursor_ts is null
        or (sc.closed_at, sc.id) < (p_cursor_ts, p_cursor_id)
      )
    order by sc.closed_at desc, sc.id desc
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
end;
$$;

revoke all on function public.acc_get_closings(timestamptz, timestamptz, uuid, int, timestamptz, uuid) from public, anon;
grant execute on function public.acc_get_closings(timestamptz, timestamptz, uuid, int, timestamptz, uuid) to authenticated;

-- =============================================================================
-- § 7 — acc_review_closing
-- تعديل (Upsert) طالما لم يُعتمد طلب خصم، ورفض الإقفال بلا عجز
-- =============================================================================
create or replace function public.acc_review_closing(
  p_closing_id          uuid,
  p_reviewed_difference numeric,
  p_review_reason       text default null,
  p_accountant_notes    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid             uuid := auth.uid();
  v_closing         record;
  v_existing_review record;
  v_ded_status      text;
  v_review_id       uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'مراجعة الإقفالات للمحاسب أو المالك فقط';
  end if;
  if p_reviewed_difference < 0 then
    raise exception 'العجز المعتمد لا يمكن أن يكون سالباً';
  end if;

  select id, difference into v_closing
  from public.shift_closings
  where id = p_closing_id;

  if not found then
    raise exception 'الإقفال غير موجود';
  end if;

  -- 1) رفض مراجعة إقفال بلا عجز
  if v_closing.difference >= 0 then
    raise exception 'لا يوجد عجز في هذا الإقفال للمراجعة (الفارق: %)', v_closing.difference;
  end if;

  -- 2) فحص المراجعة الحالية
  select id, deduction_request_id into v_existing_review
  from public.closing_reviews
  where closing_id = p_closing_id
  for update;

  if found then
    -- التحقق إن كان هناك طلب خصم معتمد يمنع التعديل
    if v_existing_review.deduction_request_id is not null then
      select status into v_ded_status
      from public.deduction_bonus_requests
      where id = v_existing_review.deduction_request_id;

      if v_ded_status = 'approved' then
        raise exception 'لا يمكن تعديل المراجعة بعد اعتماد طلب الخصم من HR';
      end if;
    end if;

    update public.closing_reviews
    set reviewed_difference = p_reviewed_difference,
        review_reason       = p_review_reason,
        accountant_notes    = p_accountant_notes,
        reviewed_by         = v_uid,
        reviewed_at         = now()
    where id = v_existing_review.id
    returning id into v_review_id;
  else
    insert into public.closing_reviews (
      closing_id, original_difference, reviewed_difference,
      review_reason, accountant_notes, reviewed_by, reviewed_at
    ) values (
      p_closing_id, abs(v_closing.difference), p_reviewed_difference,
      p_review_reason, p_accountant_notes, v_uid, now()
    ) returning id into v_review_id;
  end if;

  return jsonb_build_object(
    'ok',                  true,
    'review_id',           v_review_id,
    'reviewed_difference', p_reviewed_difference
  );
end;
$$;

revoke all on function public.acc_review_closing(uuid, numeric, text, text) from public, anon;
grant execute on function public.acc_review_closing(uuid, numeric, text, text) to authenticated;

-- =============================================================================
-- § 8 — acc_refer_closing_to_hr
-- فحص p_amount <= reviewed_difference، والموظف النشط التابع للفرع، ومنع الإحالة المكررة
-- الجمهور = array['hr', 'accounting']
-- =============================================================================
create or replace function public.acc_refer_closing_to_hr(
  p_closing_id  uuid,
  p_employee_id uuid,
  p_amount      numeric,
  p_reason      text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_closing   record;
  v_review    record;
  v_emp       record;
  v_req_id    uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'إحالة العجز لـ HR للمحاسب أو المالك فقط';
  end if;
  if p_amount <= 0 then
    raise exception 'مبلغ الخصم يجب أن يكون أكبر من صفر';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'سبب الخصم مطلوب';
  end if;

  -- 1) فحص الإقفال
  select id, branch_id, difference into v_closing
  from public.shift_closings
  where id = p_closing_id;

  if not found then
    raise exception 'الإقفال غير موجود';
  end if;

  if v_closing.difference >= 0 then
    raise exception 'لا يوجد عجز في هذا الإقفال للإحالة إلى HR';
  end if;

  -- 2) فحص المراجعة الحالية ومقارنة المبلغ بالعجز المعتمد
  select id, reviewed_difference, deduction_request_id into v_review
  from public.closing_reviews
  where closing_id = p_closing_id
  for update;

  if not found then
    raise exception 'يجب مراجعة الإقفال واعتماد العجز أولاً قبل الإحالة إلى HR';
  end if;

  if v_review.deduction_request_id is not null then
    raise exception 'تمت إحالة هذا الإقفال إلى HR مسبقاً (معرّف الطلب: %)', v_review.deduction_request_id;
  end if;

  if p_amount > v_review.reviewed_difference then
    raise exception 'مبلغ الخصم (%) يتجاوز العجز المعتمد (%)', p_amount, v_review.reviewed_difference;
  end if;

  -- 3) التحقق من الموظف: نشط ويتبع نفس فرع الإقفال
  select id, full_name, status, branch_id into v_emp
  from public.employees
  where id = p_employee_id;

  if not found then
    raise exception 'الموظف غير موجود في سجلات الموارد البشرية';
  end if;

  if v_emp.status <> 'active' then
    raise exception 'الموظف غير نشط حالياً (الحالة: %)', v_emp.status;
  end if;

  if v_emp.branch_id is distinct from v_closing.branch_id then
    raise exception 'الموظف المحدد لا يتبع فرع الإقفال';
  end if;

  -- 4) إدراج طلب الخصم (requested_from = 'cashier')
  insert into public.deduction_bonus_requests (
    employee_id, requested_from, type, amount_type,
    cash_amount, notes, status, created_by
  ) values (
    p_employee_id, 'cashier', 'deduction', 'cash',
    p_amount, trim(p_reason), 'pending', v_uid
  ) returning id into v_req_id;

  -- 5) ربط الطلب بسجل المراجعة
  update public.closing_reviews
  set deduction_request_id = v_req_id
  where id = v_review.id;

  -- 6) إشعار HR والإدارة (جمهور hr و accounting عبر _my_audiences)
  perform public._notify(
    'closing_referred',
    array['hr', 'accounting']::text[],
    v_closing.branch_id,
    'إحالة عجز إقفال إلى HR',
    format('أحال المحاسب عجزاً بقيمة %s ر.س على الموظف %s', p_amount, v_emp.full_name),
    jsonb_build_object(
      'closing_id',           p_closing_id,
      'deduction_request_id', v_req_id,
      'employee_id',          p_employee_id,
      'amount',               p_amount,
      'branch_id',            v_closing.branch_id
    )
  );

  return jsonb_build_object(
    'ok',                   true,
    'deduction_request_id', v_req_id,
    'employee_name',        v_emp.full_name
  );
end;
$$;

revoke all on function public.acc_refer_closing_to_hr(uuid, uuid, numeric, text) from public, anon;
grant execute on function public.acc_refer_closing_to_hr(uuid, uuid, numeric, text) to authenticated;

-- =============================================================================
-- § 9 — acc_get_all_expenses
-- قراءة المصروفات المعتمدة من expense_invoices (status = 'posted')
-- =============================================================================
create or replace function public.acc_get_all_expenses(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid        default null,
  p_limit     int         default 50,
  p_cursor_ts timestamptz default null,
  p_cursor_id uuid        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_from      timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to        timestamptz := coalesce(p_to, now());
  v_limit     int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows      jsonb;
  v_tot       numeric := 0;
  v_count     bigint  := 0;
  v_by_cat    jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة';
  end if;

  -- 1) ملخص المصروفات
  select
    coalesce(sum(ei.total), 0),
    count(*)
  into v_tot, v_count
  from public.expense_invoices ei
  where ei.status = 'posted'
    and ei.expense_date >= (v_from at time zone 'Africa/Cairo')::date
    and ei.expense_date <= (v_to at time zone 'Africa/Cairo')::date
    and (p_branch_id is null or ei.branch_id = p_branch_id);

  -- 2) التوزيع حسب الفئة
  select coalesce(jsonb_object_agg(category, cat_total), '{}'::jsonb)
  into v_by_cat
  from (
    select ei.category, coalesce(sum(ei.total), 0) as cat_total
    from public.expense_invoices ei
    where ei.status = 'posted'
      and ei.expense_date >= (v_from at time zone 'Africa/Cairo')::date
      and ei.expense_date <= (v_to at time zone 'Africa/Cairo')::date
      and (p_branch_id is null or ei.branch_id = p_branch_id)
    group by ei.category
  ) sub;

  -- 3) صفحة النتائج (Keyset)
  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',             ei.id,
      'invoice_number', ei.invoice_number,
      'branch_id',      ei.branch_id,
      'branch_name',    ei.branch_name,
      'cashier_id',     ei.cashier_id,
      'cashier_name',   ei.cashier_name,
      'category',       ei.category,
      'payee',          ei.payee,
      'description',    ei.description,
      'amount',         ei.amount,
      'vat_amount',     ei.vat_amount,
      'total',          ei.total,
      'payment_method', ei.payment_method,
      'expense_date',   ei.expense_date,
      'status',         ei.status,
      'notes',          ei.notes,
      'created_at',     ei.created_at
    ) as row_data
    from public.expense_invoices ei
    where ei.status = 'posted'
      and ei.expense_date >= (v_from at time zone 'Africa/Cairo')::date
      and ei.expense_date <= (v_to at time zone 'Africa/Cairo')::date
      and (p_branch_id is null or ei.branch_id = p_branch_id)
      and (
        p_cursor_ts is null
        or (ei.created_at, ei.id) < (p_cursor_ts, p_cursor_id)
      )
    order by ei.created_at desc, ei.id desc
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'summary', jsonb_build_object(
      'total_amount', v_tot,
      'count',        v_count,
      'by_category',  v_by_cat
    ),
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
end;
$$;

revoke all on function public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) from public, anon;
grant execute on function public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) to authenticated;

-- =============================================================================
-- § 10 — acc_get_supply_orders
-- قراءة l.line_note من supply_order_lines و so.reviewed_at
-- =============================================================================
create or replace function public.acc_get_supply_orders(
  p_status    text        default null,
  p_limit     int         default 50,
  p_cursor_ts timestamptz default null,
  p_cursor_id uuid        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'storekeeper') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',               so.id,
      'number',           so.number,
      'supplier_id',      so.supplier_id,
      'supplier_name',    sup.name,
      'supplier_phone',   sup.phone,
      'expected_date',    so.expected_date,
      'priority',         so.priority,
      'status',           so.status,
      'notes',            so.notes,
      'rejection_reason', so.rejection_reason,
      'has_issues',       so.has_issues,
      'reviewed_at',      so.reviewed_at,
      'created_at',       so.created_at,
      'version',          so.version,
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',            l.id,
          'item_id',       l.item_id,
          'item_name',     i.name,
          'unit_code',     i.unit_code,
          'qty_requested', l.qty_requested,
          'qty_received',  l.qty_received,
          'unit_cost',     l.unit_cost,
          'line_note',     l.line_note,
          'notes',         l.line_note
        ))
        from public.supply_order_lines l
        join public.inventory_items i on i.id = l.item_id
        where l.order_id = so.id
      ), '[]'::jsonb)
    ) as row_data
    from public.supply_orders so
    left join public.suppliers sup on sup.id = so.supplier_id
    where (p_status is null or so.status = p_status)
      and (
        p_cursor_ts is null
        or (so.created_at, so.id) < (p_cursor_ts, p_cursor_id)
      )
    order by so.created_at desc, so.id desc
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
end;
$$;

revoke all on function public.acc_get_supply_orders(text, int, timestamptz, uuid) from public, anon;
grant execute on function public.acc_get_supply_orders(text, int, timestamptz, uuid) to authenticated;

-- =============================================================================
-- § 11 — acc_get_inventory_overview
-- حساب القيمة = quantity * avg_cost للمستودع الرئيسي فقط
-- =============================================================================
create or replace function public.acc_get_inventory_overview(
  p_low_stock_only boolean default false,
  p_limit          int     default 100,
  p_cursor_name    text    default null,
  p_cursor_id      uuid    default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid     uuid := auth.uid();
  v_main_wh uuid;
  v_limit   int := least(greatest(coalesce(p_limit, 100), 1), 500);
  v_summ    jsonb;
  v_rows    jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'storekeeper') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select id into v_main_wh
  from public.warehouses
  where kind = 'main'
  limit 1;

  if v_main_wh is null then
    raise exception 'المستودع الرئيسي غير معرّف في النظام';
  end if;

  select jsonb_build_object(
    'total_items',     count(*),
    'low_stock_count', count(*) filter (
                         where coalesce(s.quantity, 0) <= i.min_level and i.min_level > 0),
    'total_value',     coalesce(sum(coalesce(s.quantity, 0) * i.avg_cost), 0)
  ) into v_summ
  from public.inventory_items i
  left join public.inventory_stock s
         on s.item_id = i.id and s.warehouse_id = v_main_wh
  where i.is_active = true;

  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',           i.id,
      'sku',          i.sku,
      'name',         i.name,
      'category',     cat.name,
      'unit_code',    i.unit_code,
      'quantity',     coalesce(s.quantity, 0),
      'min_level',    i.min_level,
      'avg_cost',     i.avg_cost,
      'total_value',  round(coalesce(s.quantity, 0) * i.avg_cost, 2),
      'is_low_stock', coalesce(s.quantity, 0) <= i.min_level and i.min_level > 0,
      'updated_at',   s.updated_at
    ) as row_data
    from public.inventory_items i
    join public.inventory_categories cat on cat.id = i.category_id
    left join public.inventory_stock s
           on s.item_id = i.id and s.warehouse_id = v_main_wh
    where i.is_active = true
      and (not p_low_stock_only
           or (coalesce(s.quantity, 0) <= i.min_level and i.min_level > 0))
      and (
        p_cursor_name is null
        or (i.name, i.id) > (p_cursor_name, p_cursor_id)
      )
    order by i.name, i.id
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'summary', v_summ,
    'items',   coalesce(v_rows, '[]'::jsonb),
    'limit',   v_limit
  );
end;
$$;

revoke all on function public.acc_get_inventory_overview(boolean, int, text, uuid) from public, anon;
grant execute on function public.acc_get_inventory_overview(boolean, int, text, uuid) to authenticated;

-- =============================================================================
-- § 12 — acc_get_employees_salaries
-- =============================================================================
create or replace function public.acc_get_employees_salaries(
  p_branch_id   uuid   default null,
  p_status      text   default 'active',
  p_limit       int    default 50,
  p_cursor_name text   default null,
  p_cursor_id   uuid   default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'hr') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',                  e.id,
      'code',                e.code,
      'full_name',           e.full_name,
      'job_role',            e.job_role,
      'branch_id',           e.branch_id,
      'branch_name',         coalesce(b.name, 'المستودع الرئيسي'),
      'basic_salary',        e.basic_salary,
      'allowances',          e.allowances,
      'transport_allowance', e.transport_allowance,
      'total_fixed',         round(e.basic_salary + e.allowances + e.transport_allowance, 2),
      'status',              e.status,
      'hire_date',           e.hire_date
    ) as row_data
    from public.employees e
    left join public.branches b on b.id = e.branch_id
    where (p_branch_id is null or e.branch_id = p_branch_id)
      and (p_status is null or e.status = p_status)
      and (
        p_cursor_name is null
        or (e.full_name, e.id) > (p_cursor_name, p_cursor_id)
      )
    order by e.full_name, e.id
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
end;
$$;

revoke all on function public.acc_get_employees_salaries(uuid, text, int, text, uuid) from public, anon;
grant execute on function public.acc_get_employees_salaries(uuid, text, int, text, uuid) to authenticated;

-- =============================================================================
-- § 13 — acc_update_salary
-- مع قفل الصف select ... for update وتسجيل السجل التاريخي
-- =============================================================================
create or replace function public.acc_update_salary(
  p_employee_id         uuid,
  p_basic_salary        numeric,
  p_allowances          numeric default null,
  p_transport_allowance numeric default null,
  p_reason              text    default null,
  p_effective_date      date    default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_emp       record;
  v_new_allow numeric;
  v_new_trans numeric;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'hr') then
    raise exception 'صلاحية مرفوضة';
  end if;
  if p_basic_salary < 0 then
    raise exception 'الراتب الأساسي لا يمكن أن يكون سالباً';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'سبب تعديل الراتب مطلوب للتوثيق';
  end if;

  -- 1) قفل صف الموظف لمنع التضارب
  select id, basic_salary, allowances, transport_allowance
  into v_emp
  from public.employees
  where id = p_employee_id
  for update;

  if not found then
    raise exception 'الموظف غير موجود';
  end if;

  v_new_allow := coalesce(p_allowances, v_emp.allowances);
  v_new_trans := coalesce(p_transport_allowance, v_emp.transport_allowance);

  -- 2) توثيق التعديل في السجل التاريخي
  insert into public.salary_history (
    employee_id, old_basic, new_basic, allowances, transport_allowance,
    effective_date, reason, changed_by, changed_at
  ) values (
    p_employee_id, v_emp.basic_salary, p_basic_salary,
    v_new_allow, v_new_trans,
    coalesce(p_effective_date, current_date),
    trim(p_reason), v_uid, now()
  );

  -- 3) تحديث الموظف
  update public.employees
  set basic_salary        = p_basic_salary,
      allowances          = v_new_allow,
      transport_allowance = v_new_trans,
      updated_at          = now()
  where id = p_employee_id;

  return jsonb_build_object(
    'ok',                  true,
    'employee_id',         p_employee_id,
    'old_basic',           v_emp.basic_salary,
    'new_basic',           p_basic_salary,
    'allowances',          v_new_allow,
    'transport_allowance', v_new_trans
  );
end;
$$;

revoke all on function public.acc_update_salary(uuid, numeric, numeric, numeric, text, date) from public, anon;
grant execute on function public.acc_update_salary(uuid, numeric, numeric, numeric, text, date) to authenticated;

-- =============================================================================
-- § 14 — acc_get_salary_history
-- =============================================================================
create or replace function public.acc_get_salary_history(
  p_employee_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid  uuid := auth.uid();
  v_rows jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'hr') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'id',                  sh.id,
      'old_basic',           sh.old_basic,
      'new_basic',           sh.new_basic,
      'allowances',          sh.allowances,
      'transport_allowance', sh.transport_allowance,
      'effective_date',      sh.effective_date,
      'change_reason',       sh.reason,
      'changed_at',          sh.changed_at,
      'changed_by_name',     coalesce(p.full_name, split_part(u.email, '@', 1), '—')
    ) order by sh.changed_at desc
  )
  into v_rows
  from public.salary_history sh
  left join auth.users u on u.id = sh.changed_by
  left join public.profiles p on p.id = sh.changed_by
  where sh.employee_id = p_employee_id;

  return coalesce(v_rows, '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_salary_history(uuid) from public, anon;
grant execute on function public.acc_get_salary_history(uuid) to authenticated;

-- =============================================================================
-- § 15 — acc_get_dashboard_alerts
-- Subquery مرتبة ومحدودة بـ 20 ثم jsonb_agg
-- =============================================================================
create or replace function public.acc_get_dashboard_alerts()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid     uuid := auth.uid();
  v_main_wh uuid;
  v_alerts  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select id into v_main_wh
  from public.warehouses
  where kind = 'main'
  limit 1;

  select coalesce(jsonb_agg(alert_row), '[]'::jsonb)
  into v_alerts
  from (
    select jsonb_build_object(
      'id',         'closing_' || sc.id::text,
      'type',       'closing_shortage',
      'severity',   'warning',
      'title',      'عجز إقفال غير مراجع',
      'message',    format('عجز بقيمة %s ر.س في %s', abs(sc.difference), coalesce(b.name, 'الفرع')),
      'created_at', sc.closed_at,
      'ref_id',     sc.id
    ) as alert_row
    from public.shift_closings sc
    left join public.branches b on b.id = sc.branch_id
    left join public.closing_reviews cr on cr.closing_id = sc.id
    where sc.difference < 0
      and cr.id is null
      and sc.closed_at >= now() - interval '14 days'

    union all

    select jsonb_build_object(
      'id',         'supply_' || so.id::text,
      'type',       'pending_supply_order',
      'severity',   'info',
      'title',      'طلب توريد بانتظار المراجعة',
      'message',    format('طلب رقم %s من %s', so.number, coalesce(sup.name, 'مورد')),
      'created_at', so.created_at,
      'ref_id',     so.id
    ) as alert_row
    from public.supply_orders so
    left join public.suppliers sup on sup.id = so.supplier_id
    where so.status = 'pending_review'

    union all

    select jsonb_build_object(
      'id',         'stock_' || i.id::text,
      'type',       'low_stock',
      'severity',   'error',
      'title',      'مخزون منخفض بالمستودع الرئيسي',
      'message',    format('صنف %s: الرصيد الحالي %s أقل من الحد الأدنى %s', i.name, coalesce(s.quantity, 0), i.min_level),
      'created_at', now(),
      'ref_id',     i.id
    ) as alert_row
    from public.inventory_items i
    left join public.inventory_stock s on s.item_id = i.id and s.warehouse_id = v_main_wh
    where i.is_active = true
      and i.min_level > 0
      and coalesce(s.quantity, 0) <= i.min_level

    limit 20
  ) sub;

  return v_alerts;
end;
$$;

revoke all on function public.acc_get_dashboard_alerts() from public, anon;
grant execute on function public.acc_get_dashboard_alerts() to authenticated;

-- =============================================================================
-- § 16 — acc_list_branches
-- =============================================================================
create or replace function public.acc_list_branches()
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
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',   b.id,
        'code', b.code,
        'name', b.name
      ) order by b.name
    )
    from public.branches b
    where b.is_active = true and b.deleted_at is null
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_list_branches() from public, anon;
grant execute on function public.acc_list_branches() to authenticated;

-- =============================================================================
-- § 17 — acc_list_suppliers (بدون deleted_at لعدم وجود العمود)
-- =============================================================================
create or replace function public.acc_list_suppliers()
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
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',    s.id,
        'name',  s.name,
        'phone', s.phone
      ) order by s.name
    )
    from public.suppliers s
    where s.is_active = true
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_list_suppliers() from public, anon;
grant execute on function public.acc_list_suppliers() to authenticated;

-- =============================================================================
-- § 18 — acc_get_branch_employees
-- موظفو فرع محدد للإحالة إلى HR (فقط الموظفون النشطون في هذا الفرع)
-- =============================================================================
create or replace function public.acc_get_branch_employees(
  p_branch_id uuid
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
  if not _has_role('accountant', 'owner') then
    raise exception 'صلاحية مرفوضة';
  end if;
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',        e.id,
        'code',      e.code,
        'full_name', e.full_name,
        'job_role',  e.job_role
      ) order by e.full_name
    )
    from public.employees e
    where e.branch_id = p_branch_id
      and e.status = 'active'
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.acc_get_branch_employees(uuid) from public, anon;
grant execute on function public.acc_get_branch_employees(uuid) to authenticated;
