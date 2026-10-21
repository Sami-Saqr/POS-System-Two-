-- =============================================================================
-- 028_accounting_retention_and_enhancements.sql
-- تحسينات قسم الحسابات:
--   1) سياسة الاحتفاظ بالبيانات (Retention Policy) للمبيعات والمصروفات والمشتريات والإقفالات
--   2) تحديث المصروفات: إمكانية التسجيل بدون فرع، إضافة الحالة (قيد المراجعة / مقبولة / مرفوضة)، واعتماد/رفض مصروفات الفروع
--   3) تحديث الإقفالات: إرجاع اسم الوردية، إمكانية إضافة عجز لإقفال متزن، وإمكانية إلغاء العجز، وتعديل إحالة HR
-- =============================================================================

begin;

-- ─── § 1  جدول سجلات حذف فترات الاحتفاظ بالبيانات للحسابات ───────────────────

create table if not exists public.acc_retention_logs (
  id                  uuid primary key default gen_random_uuid(),
  purged_at           timestamptz not null default now(),
  cutoff_date         date not null,
  sales_deleted       int not null default 0,
  sale_items_deleted  int not null default 0,
  expenses_deleted    int not null default 0,
  supply_orders_del   int not null default 0,
  closings_deleted    int not null default 0,
  details             jsonb not null default '{}'::jsonb
);

create index if not exists idx_acc_retention_logs_date on public.acc_retention_logs(purged_at);
alter table public.acc_retention_logs enable row level security;
revoke all on table public.acc_retention_logs from public, anon;
grant select on table public.acc_retention_logs to authenticated;


-- ─── § 2  دالة حذف السجلات القديمة تلقائياً وفق سياسة الاحتفاظ ────────────────
-- قاعدة الحسابات المعتمدة:
-- - الاحتفاظ ببيانات الشهر الحالي وشهرين سابقين (3 أشهر إجمالاً).
-- - بيانات شهر M تبقى محفوظة حتى يوم 5 من شهر M+3.
-- - في يوم 5 من الشهر (وما بعده): أقدم تاريخ متاح هو أول يوم من (الشهر الحالي - شهرين).
--   مثال: في 2026-10-13، الحد الأدنى المحفوظ هو 2026-08-01 (شهور 8 و 9 و 10 محفوظة).
--   في 2026-11-05، يُحذف شهر 8، ويصبح الحد الأدنى 2026-09-01 (شهور 9 و 10 و 11 محفوظة).
create or replace function public.acc_purge_expired_retention_data(
  p_force boolean default false
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_today        date := current_date;
  v_day          int  := extract(day from v_today);
  v_cutoff       date;
  v_sales_cnt    int  := 0;
  v_items_cnt    int  := 0;
  v_exp_cnt      int  := 0;
  v_supply_cnt   int  := 0;
  v_closings_cnt int  := 0;
  v_log_id       uuid;
begin
  -- إذا لم يكن اليوم >= 5 ولم نحدد فرض التشغيل، نتجاوز الحذف
  if v_day < 5 and not p_force then
    return jsonb_build_object(
      'status', 'skipped',
      'reason', 'Retention purge executes on or after day 5 of the month',
      'current_day', v_day
    );
  end if;

  -- الحد الفاصل: أول يوم من (الشهر الحالي - شهرين)
  v_cutoff := date_trunc('month', v_today - interval '2 month')::date;

  -- 1. حذف بنود المبيعات ثم الفواتير القديمة
  with del_items as (
    delete from public.sale_items
    where sale_id in (select id from public.sales where sold_at::date < v_cutoff)
    returning id
  )
  select count(*) into v_items_cnt from del_items;

  with del_sales as (
    delete from public.sales
    where sold_at::date < v_cutoff
    returning id
  )
  select count(*) into v_sales_cnt from del_sales;

  -- 2. حذف المصروفات القديمة
  with del_exp as (
    delete from public.expenses
    where expense_date < v_cutoff
    returning id
  )
  select count(*) into v_exp_cnt from del_exp;

  -- 3. حذف بنود طلبات التوريد ثم أوامر التوريد القديمة
  with del_lines as (
    delete from public.supply_order_lines
    where order_id in (select id from public.supply_orders where created_at::date < v_cutoff)
    returning id
  )
  select count(*) into v_supply_cnt from del_lines;

  delete from public.supply_orders
  where created_at::date < v_cutoff;

  -- 4. حذف مراجعات الإقفالات ثم الإقفالات القديمة
  delete from public.closing_reviews
  where closing_id in (select id from public.shift_closings where closed_at::date < v_cutoff);

  with del_closings as (
    delete from public.shift_closings
    where closed_at::date < v_cutoff
    returning id
  )
  select count(*) into v_closings_cnt from del_closings;

  -- 5. تسجيل في سجلات الاحتفاظ
  insert into public.acc_retention_logs (
    cutoff_date, sales_deleted, sale_items_deleted,
    expenses_deleted, supply_orders_del, closings_deleted, details
  ) values (
    v_cutoff, v_sales_cnt, v_items_cnt,
    v_exp_cnt, v_supply_cnt, v_closings_cnt,
    jsonb_build_object(
      'executed_at', now(),
      'forced', p_force,
      'today', v_today
    )
  ) returning id into v_log_id;

  return jsonb_build_object(
    'status', 'success',
    'log_id', v_log_id,
    'cutoff_date', v_cutoff,
    'sales_deleted', v_sales_cnt,
    'expenses_deleted', v_exp_cnt,
    'closings_deleted', v_closings_cnt
  );
end;
$$;

revoke all on function public.acc_purge_expired_retention_data(boolean) from public, anon;
grant execute on function public.acc_purge_expired_retention_data(boolean) to authenticated;

-- جدولة المهمة شهرياً يوم 5 الساعة 00:20
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('acc-monthly-retention-purge')
      where exists (select 1 from cron.job where jobname = 'acc-monthly-retention-purge');

    perform cron.schedule(
      'acc-monthly-retention-purge',
      '20 0 5 * *',
      'select public.acc_purge_expired_retention_data(false);'
    );
  end if;
exception when others then
  raise notice 'pg_cron not available for accounting retention: %', sqlerrm;
end;
$$;


-- ─── § 3  تحديث جدول المصروفات (Expenses) ───────────────────────────────────

-- جعل branch_id و session_id اختيارية لتسجيل المصروفات العامة من المحاسب
alter table public.expenses alter column branch_id drop not null;
alter table public.expenses alter column session_id drop not null;

-- إضافة أعمدة الحالة والاعتماد
alter table public.expenses add column if not exists status text not null default 'approved';
alter table public.expenses add column if not exists decision_notes text;
alter table public.expenses add column if not exists decided_by uuid references auth.users(id);
alter table public.expenses add column if not exists decided_at timestamptz;

-- تحديث دالة تسجيل المصروف من الكاشير (لتكون حالته pending قيد المراجعة)
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
  v_existing public.expenses%rowtype;
  v_branch public.branches%rowtype;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat_amount numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_number text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('cashier', 'branch_manager', 'accountant', 'owner') then
    raise exception 'ليس لديك صلاحية تسجيل المصروفات';
  end if;
  if v_client_id is null then
    raise exception 'معرف المصروف العميل مفقود';
  end if;
  if v_branch_id is not null and not _can_act_for_branch(v_branch_id) and not _has_role('accountant', 'owner') then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;
  if coalesce(trim(p->>'category'), '') = '' then
    raise exception 'نوع المصروف مطلوب';
  end if;
  if v_amount is null or v_amount <= 0 or v_vat_amount < 0 then
    raise exception 'قيمة المصروف غير صحيحة';
  end if;

  select * into v_existing from public.expenses where client_id = v_client_id;
  if found then
    return jsonb_build_object(
      'id', v_existing.id,
      'number', v_existing.number,
      'already_exists', true
    );
  end if;

  if v_branch_id is not null then
    select * into v_branch from public.branches where id = v_branch_id;
  end if;

  v_number := _next_doc_number(
    'expense',
    coalesce(nullif(v_branch.code, ''), 'DK-001'),
    'EXP-{scope}-{n:6}'
  );

  insert into public.expenses (
    client_id, number, branch_id, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes, created_by,
    status
  ) values (
    v_client_id, v_number, v_branch_id, v_session_id, trim(p->>'category'),
    nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat_amount, 2), round(v_amount + v_vat_amount, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), ''), v_uid,
    case when _has_role('accountant', 'owner') then 'approved' else 'pending' end
  ) returning id into v_id;

  return jsonb_build_object('id', v_id, 'number', v_number, 'already_exists', false);
end;
$$;

-- دالة للمحاسب لإضافة مصروف مباشرة مع فرع اختياري
create or replace function public.acc_add_expense(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_client_id uuid := coalesce(nullif(p->>'client_id', '')::uuid, gen_random_uuid());
  v_branch_id uuid := nullif(p->>'branch_id', '')::uuid;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat_amount numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_branch_code text := 'HQ';
  v_number text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'إضافة المصروفات من صلاحية المحاسب أو المالك فقط';
  end if;
  if coalesce(trim(p->>'category'), '') = '' then
    raise exception 'نوع / تصنيف المصروف مطلوب';
  end if;
  if v_amount is null or v_amount <= 0 then
    raise exception 'قيمة المصروف يجب أن تكون أكبر من صفر';
  end if;

  if v_branch_id is not null then
    select code into v_branch_code from public.branches where id = v_branch_id;
  end if;

  v_number := _next_doc_number(
    'expense',
    coalesce(nullif(v_branch_code, ''), 'DK-001'),
    'EXP-{scope}-{n:6}'
  );

  insert into public.expenses (
    client_id, number, branch_id, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes, created_by,
    status, decided_by, decided_at
  ) values (
    v_client_id, v_number, v_branch_id, null, trim(p->>'category'),
    nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat_amount, 2), round(v_amount + v_vat_amount, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), ''), v_uid,
    'approved', v_uid, now()
  ) returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'number', v_number,
    'amount', v_amount
  );
end;
$$;

grant execute on function public.acc_add_expense(jsonb) to authenticated;

-- دالة للمحاسب لاعتماد أو رفض مصروف مسجل من فرع
create or replace function public.acc_decide_expense(
  p_expense_id uuid,
  p_status     text, -- 'approved' | 'rejected'
  p_notes      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_exp public.expenses%rowtype;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'اعتماد أو رفض المصروفات من صلاحية المحاسب أو المالك فقط';
  end if;
  if p_status not in ('approved', 'rejected') then
    raise exception 'الحالة يجب أن تكون إما مقبولة (approved) أو مرفوضة (rejected)';
  end if;

  select * into v_exp from public.expenses where id = p_expense_id;
  if not found then
    raise exception 'المصروف غير موجود';
  end if;

  update public.expenses
  set status = p_status,
      decision_notes = nullif(trim(p_notes), ''),
      decided_by = v_uid,
      decided_at = now()
  where id = p_expense_id;

  return jsonb_build_object(
    'ok', true,
    'id', p_expense_id,
    'status', p_status
  );
end;
$$;

grant execute on function public.acc_decide_expense(uuid, text, text) to authenticated;

-- تحديث get_branch_expenses لتعيد الحالة وتستثني المرفوضة من الكاشير
-- يجب حذف الدالة القديمة أولاً لأن نوع الإرجاع تغيّر (أُضيف عمود status)
drop function if exists public.get_branch_expenses(uuid) cascade;
create or replace function public.get_branch_expenses(p_branch_id uuid)
returns table (
  id uuid,
  client_id uuid,
  number text,
  category text,
  payee text,
  description text,
  amount numeric,
  vat_amount numeric,
  total numeric,
  payment_method text,
  expense_date date,
  notes text,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  return query
  select
    e.id, e.client_id, e.number, e.category, e.payee, e.description,
    e.amount, e.vat_amount, e.total, e.payment_method, e.expense_date,
    e.notes, e.status, e.created_at
  from public.expenses e
  where (e.branch_id = p_branch_id or (e.branch_id is null and p_branch_id is null))
    and e.status != 'rejected'
  order by e.created_at desc;
end;
$$;

grant execute on function public.get_branch_expenses(uuid) to authenticated;

-- تحديث acc_get_all_expenses لدعم الحالة والفلاتر
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
  v_summary   jsonb;
  v_rows      jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة: لا تملك دور محاسب أو مالك';
  end if;

  -- 1) الملخص
  select jsonb_build_object(
    'total_amount',      coalesce(sum(amount), 0),
    'total_vat',         coalesce(sum(vat_amount), 0),
    'grand_total',       coalesce(sum(total), 0),
    'expenses_count',    count(*),
    'pending_count',     count(*) filter (where coalesce(status, 'approved') = 'pending'),
    'by_category',       coalesce((
      select jsonb_agg(jsonb_build_object('category', category, 'total', cat_total))
      from (
        select category, sum(total) as cat_total
        from public.expenses
        where expense_date >= v_from::date and expense_date <= v_to::date
          and (p_branch_id is null or branch_id = p_branch_id)
        group by category
        order by cat_total desc
      ) sub
    ), '[]'::jsonb)
  )
  into v_summary
  from public.expenses
  where expense_date >= v_from::date and expense_date <= v_to::date
    and (p_branch_id is null or branch_id = p_branch_id);

  -- 2) القائمة
  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',             e.id,
      'number',         e.number,
      'category',       e.category,
      'payee',          e.payee,
      'description',    e.description,
      'amount',         e.amount,
      'vat_amount',     e.vat_amount,
      'total',          e.total,
      'payment_method', e.payment_method,
      'expense_date',   e.expense_date,
      'notes',          e.notes,
      'branch_id',      e.branch_id,
      'branch_name',    coalesce(b.name, 'مصروف عام (بدون فرع)'),
      'created_at',     e.created_at,
      'status',         coalesce(e.status, 'approved'),
      'decision_notes', e.decision_notes
    ) as row_data
    from public.expenses e
    left join public.branches b on b.id = e.branch_id
    where e.expense_date >= v_from::date and e.expense_date <= v_to::date
      and (p_branch_id is null or e.branch_id = p_branch_id)
      and (
        p_cursor_ts is null
        or (e.created_at, e.id) < (p_cursor_ts, p_cursor_id)
      )
    order by e.created_at desc, e.id desc
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'summary', coalesce(v_summary, '{}'::jsonb),
    'items',   coalesce(v_rows, '[]'::jsonb),
    'limit',   v_limit
  );
end;
$$;

grant execute on function public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) to authenticated;


-- ─── § 4  تحديث الإقفالات (Closings) ─────────────────────────────────────────

-- تحديث acc_get_closings لإرجاع الوردية shift
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
  v_from  timestamptz := coalesce(p_from, date_trunc('month', now()));
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
      'shift',               coalesce(sc.shift, 'الوردية الأولى'),
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

grant execute on function public.acc_get_closings(timestamptz, timestamptz, uuid, int, timestamptz, uuid) to authenticated;

-- تحديث acc_get_closings_dashboard لإرجاع shift أيضاً
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
  v_uid  uuid := auth.uid();
  v_from timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to   timestamptz := coalesce(p_to, now());
  v_rows jsonb;
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
      'branch_name',         coalesce(b.name, '—'),
      'cashier_name',        coalesce(p.full_name, split_part(u.email, '@', 1), '—'),
      'shift',               coalesce(sc.shift, 'الوردية الأولى'),
      'difference',          sc.difference,
      'closed_at',           sc.closed_at,
      'has_mismatch',        sc.has_mismatch,
      'is_reviewed',         (cr.id is not null)
    ) as row_data
    from public.shift_closings sc
    left join public.branches b on b.id = sc.branch_id
    left join auth.users u on u.id = sc.cashier_id
    left join public.profiles p on p.id = sc.cashier_id
    left join public.closing_reviews cr on cr.closing_id = sc.id
    where sc.closed_at >= v_from and sc.closed_at <= v_to
      and (p_branch_id is null or sc.branch_id = p_branch_id)
    order by sc.closed_at desc
    limit 20
  ) sub;

  return coalesce(v_rows, '[]'::jsonb);
end;
$$;

grant execute on function public.acc_get_closings_dashboard(timestamptz, timestamptz, uuid) to authenticated;

-- تحديث acc_review_closing للسماح بإضافة عجز حتى لو كان الإقفال متزناً بالأصل
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

  -- فحص المراجعة الحالية
  select id, deduction_request_id into v_existing_review
  from public.closing_reviews
  where closing_id = p_closing_id
  for update;

  if found then
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

grant execute on function public.acc_review_closing(uuid, numeric, text, text) to authenticated;

-- تحديث acc_refer_closing_to_hr لكتابة ملاحظة 'عجز كاشير' وإتاحة الإحالة طالما تم اعتماد عجز
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
  v_note      text;
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

  select id, branch_id, difference into v_closing
  from public.shift_closings
  where id = p_closing_id;

  if not found then
    raise exception 'الإقفال غير موجود';
  end if;

  select id, reviewed_difference, deduction_request_id into v_review
  from public.closing_reviews
  where closing_id = p_closing_id
  for update;

  if not found then
    raise exception 'يجب مراجعة الإقفال واعتماد العجز أولاً قبل الإحالة إلى HR';
  end if;

  if v_review.deduction_request_id is not null then
    raise exception 'تمت إحالة هذا الإقفال إلى HR مسبقاً';
  end if;

  if p_amount > v_review.reviewed_difference then
    raise exception 'مبلغ الخصم (%) يتجاوز العجز المعتمد (%)', p_amount, v_review.reviewed_difference;
  end if;

  select id, full_name, status, branch_id into v_emp
  from public.employees
  where id = p_employee_id;

  if not found then
    raise exception 'الموظف غير موجود في سجلات الموارد البشرية';
  end if;

  if v_emp.status <> 'active' then
    raise exception 'الموظف غير نشط حالياً (الحالة: %)', v_emp.status;
  end if;

  -- ملاحظة الإحالة كما طلب المستخدم بالضبط: عجز كاشير
  v_note := 'عجز كاشير: ' || trim(p_reason);

  -- إدراج طلب الخصم في قسم HR
  insert into public.deduction_bonus_requests (
    employee_id, requested_from, type, amount_type,
    cash_amount, final_cash_amount, notes, status, created_by
  ) values (
    p_employee_id, 'accounting', 'deduction', 'cash',
    p_amount, p_amount, v_note, 'pending', v_uid
  ) returning id into v_req_id;

  -- ربط الطلب بسجل المراجعة
  update public.closing_reviews
  set deduction_request_id = v_req_id
  where id = v_review.id;

  -- إشعار HR
  insert into public.notifications (
    recipient_role, type, title, body, ref_table, ref_id
  ) values (
    'hr', 'deduction_bonus_submitted', 'طلب خصم عجز كاشير',
    'تم تسجيل عجز كاشير بقيمة ' || p_amount || ' ر.س للموظف ' || v_emp.full_name,
    'deduction_bonus_requests', v_req_id::text
  );

  return jsonb_build_object(
    'ok',                   true,
    'deduction_request_id', v_req_id,
    'amount',               p_amount
  );
end;
$$;

grant execute on function public.acc_refer_closing_to_hr(uuid, uuid, numeric, text) to authenticated;

-- دالة إلغاء العجز من الحسابات (إلغاء المراجعة أو إلغاء طلب الخصم المحال إن كان معلقاً)
create or replace function public.acc_cancel_closing_shortage(
  p_closing_id uuid,
  p_reason     text default 'إلغاء العجز بناءً على مراجعة المحاسب'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_review    public.closing_reviews%rowtype;
  v_ded_id    uuid;
  v_ded_stat  text;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'إلغاء العجز للمحاسب أو المالك فقط';
  end if;

  select * into v_review
  from public.closing_reviews
  where closing_id = p_closing_id
  for update;

  if not found then
    -- لم تكن هناك مراجعة مسجلة، نسجل مراجعة بعجز 0
    insert into public.closing_reviews (
      closing_id, original_difference, reviewed_difference,
      review_reason, accountant_notes, reviewed_by, reviewed_at
    ) values (
      p_closing_id, 0, 0,
      'تم إلغاء وتصفير العجز', p_reason, v_uid, now()
    );
    return jsonb_build_object('ok', true, 'message', 'تم إلغاء العجز وتصفيره بنجاح');
  end if;

  v_ded_id := v_review.deduction_request_id;
  if v_ded_id is not null then
    select status into v_ded_stat
    from public.deduction_bonus_requests
    where id = v_ded_id;

    if v_ded_stat = 'approved' then
      raise exception 'لا يمكن إلغاء العجز لأن طلب الخصم تم اعتماده بالفعل من قسم الـ HR';
    end if;

    -- إذا كان معلقاً، يتم إلغاؤه
    update public.deduction_bonus_requests
    set status = 'rejected',
        notes = coalesce(notes, '') || ' [ملغى من الحسابات: ' || coalesce(p_reason, '') || ']'
    where id = v_ded_id;
  end if;

  -- تصفير العجز المعتمد
  update public.closing_reviews
  set reviewed_difference = 0,
      review_reason       = 'تم إلغاء العجز',
      accountant_notes    = p_reason,
      deduction_request_id = null,
      reviewed_by         = v_uid,
      reviewed_at         = now()
  where id = v_review.id;

  return jsonb_build_object(
    'ok', true,
    'message', 'تم إلغاء العجز وإلغاء طلب الخصم المرتبط به بنجاح'
  );
end;
$$;

grant execute on function public.acc_cancel_closing_shortage(uuid, text) to authenticated;

commit;
