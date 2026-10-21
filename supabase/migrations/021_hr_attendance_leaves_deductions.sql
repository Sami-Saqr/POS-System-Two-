-- 021_hr_attendance_leaves_deductions.sql
-- جداول وdالحضور + الإجازات + الخصومات/المكافآت مع دوال RPC كاملة
-- كل الوصول عبر RPC فقط

begin;

-- ─────────────────────── جدول الحضور ───────────────────────
create table if not exists public.attendance_records (
  id            uuid primary key default gen_random_uuid(),
  employee_id   uuid not null references public.employees(id),
  record_date   date not null,
  status        text not null check (status in ('present','absent','on_leave')),
  recorded_by   uuid references auth.users(id),
  recorded_from text check (recorded_from in ('cashier','inventory','hr')),
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (employee_id, record_date)
);

create index if not exists idx_attendance_employee on public.attendance_records(employee_id);
create index if not exists idx_attendance_date     on public.attendance_records(record_date);
alter table public.attendance_records enable row level security;
revoke all on table public.attendance_records from public, anon, authenticated;

-- ─────────────────────── جدول الإجازات ───────────────────────
create table if not exists public.leave_requests (
  id              uuid primary key default gen_random_uuid(),
  employee_id     uuid not null references public.employees(id),
  requested_from  text not null check (requested_from in ('cashier','inventory','hr')),
  start_date      date not null,
  end_date        date not null,
  reason          text not null check (btrim(reason) <> ''),
  status          text not null default 'pending' check (status in ('pending','approved','rejected')),
  decision_type   text check (decision_type in ('with_deduction','without_deduction')),
  decided_by      uuid references auth.users(id),
  decided_at      timestamptz,
  decision_notes  text,
  created_by      uuid references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_leave_employee on public.leave_requests(employee_id);
create index if not exists idx_leave_status   on public.leave_requests(status);
alter table public.leave_requests enable row level security;
revoke all on table public.leave_requests from public, anon, authenticated;

-- ─────────────────────── جدول الخصومات والمكافآت ───────────────────────
create table if not exists public.deduction_bonus_requests (
  id              uuid primary key default gen_random_uuid(),
  employee_id     uuid not null references public.employees(id),
  requested_from  text not null check (requested_from in ('cashier','inventory','hr')),
  type            text not null check (type in ('deduction','bonus')),
  amount_type     text not null check (amount_type in ('cash','days')),
  cash_amount     numeric(10,2),
  days_amount     numeric(4,2),   -- e.g. 0.25, 0.5, 1, 2
  notes           text not null check (btrim(notes) <> ''),
  status          text not null default 'pending' check (status in ('pending','approved','rejected')),
  decided_by      uuid references auth.users(id),
  decided_at      timestamptz,
  final_cash_amount numeric(10,2),  -- computed by HR at approval
  created_by      uuid references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_deduction_employee on public.deduction_bonus_requests(employee_id);
create index if not exists idx_deduction_status   on public.deduction_bonus_requests(status);
alter table public.deduction_bonus_requests enable row level security;
revoke all on table public.deduction_bonus_requests from public, anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════
--                       RPC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────── helper: get branch employees ───────────────────────
-- Returns employees for a given branch (for cashier), or inventory/kitchen (for inventory)
create or replace function public.hr_get_branch_employees(
  p_branch_id uuid default null,
  p_context   text default 'cashier'  -- 'cashier' | 'inventory'
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_roles text[];
begin
  if p_context = 'cashier' then
    -- موظفين الفرع: كاشير + عامل + مدير فرع (يشترط branch_id)
    return coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'code', e.code, 'full_name', e.full_name,
        'job_role', e.job_role, 'branch_id', e.branch_id,
        'branch_name', b.name, 'status', e.status
      ) order by e.full_name)
      from public.employees e
      left join public.branches b on b.id = e.branch_id
      where e.status = 'active'
        and e.job_role in ('cashier','worker','branch_manager')
        and e.branch_id = p_branch_id
    ), '[]'::jsonb);
  elsif p_context = 'inventory' then
    -- موظفين المخزون والمطبخ (بدون فرع)
    return coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'code', e.code, 'full_name', e.full_name,
        'job_role', e.job_role, 'branch_id', e.branch_id,
        'status', e.status
      ) order by e.full_name)
      from public.employees e
      where e.status = 'active'
        and e.job_role in ('storekeeper','chef','kitchen_worker')
        and e.branch_id is null
    ), '[]'::jsonb);
  else
    return '[]'::jsonb;
  end if;
end;
$$;
revoke all on function public.hr_get_branch_employees(uuid, text) from public, anon;
grant execute on function public.hr_get_branch_employees(uuid, text) to authenticated;

-- ─────────────────────── helper: get drivers ───────────────────────
create or replace function public.hr_get_drivers() returns jsonb
language sql security definer set search_path = public as $$
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', e.id, 'code', e.code, 'full_name', e.full_name,
      'job_role', e.job_role, 'status', e.status
    ) order by e.full_name)
    from public.employees e
    where e.status = 'active' and e.job_role = 'driver'
  ), '[]'::jsonb);
$$;
revoke all on function public.hr_get_drivers() from public, anon;
grant execute on function public.hr_get_drivers() to authenticated;

-- ─────────────────────── تسجيل حضور / غياب ───────────────────────
create or replace function public.hr_submit_attendance(
  p_employee_id uuid,
  p_record_date date,
  p_status      text,   -- 'present' | 'absent' | 'on_leave'
  p_context     text,   -- 'cashier' | 'inventory' | 'hr'
  p_notes       text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_existing text;
begin
  -- التحقق من الصلاحية: HR يقدر يسجل دائما، باقيهم بشرط السياق
  -- (نافترض ان كل مستخدم authenticated يقدر يسجل لكن نقيّد التعديل)

  if p_status not in ('present','absent','on_leave') then
    raise exception 'حالة الحضور غير صحيحة';
  end if;

  -- فترة السماح: يوم اليوم أو الأمس فقط (ما عدا HR)
  if not public._has_role('hr') and p_context <> 'hr' then
    if p_record_date < current_date - 1 or p_record_date > current_date then
      raise exception 'لا يمكن تسجيل الحضور إلا ليوم أمس أو اليوم';
    end if;
  end if;

  -- هل موجود سجل مسبق؟
  select id, status into v_id, v_existing
  from public.attendance_records
  where employee_id = p_employee_id and record_date = p_record_date;

  -- إذا كان السجل موجود و مش HR → لا يسمح بالتعديل
  if v_id is not null and not public._has_role('hr') then
    raise exception 'تم تسجيل الحضور مسبقاً ولا يمكن التعديل';
  end if;

  insert into public.attendance_records (
    employee_id, record_date, status, recorded_by, recorded_from, notes
  ) values (
    p_employee_id, p_record_date, p_status, auth.uid(), p_context, p_notes
  )
  on conflict (employee_id, record_date) do update
    set status = excluded.status,
        recorded_by = excluded.recorded_by,
        recorded_from = excluded.recorded_from,
        notes = excluded.notes,
        updated_at = now()
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'status', p_status, 'record_date', p_record_date);
end;
$$;
revoke all on function public.hr_submit_attendance(uuid, date, text, text, text) from public, anon;
grant execute on function public.hr_submit_attendance(uuid, date, text, text, text) to authenticated;

-- ─────────────────────── جلب حضور اليوم لقائمة موظفين ───────────────────────
create or replace function public.hr_get_today_attendance(
  p_employee_ids uuid[],
  p_date date default current_date
) returns jsonb
language sql security definer set search_path = public as $$
  select coalesce((
    select jsonb_object_agg(a.employee_id::text, jsonb_build_object(
      'id', a.id,
      'status', a.status,
      'recorded_from', a.recorded_from,
      'notes', a.notes
    ))
    from public.attendance_records a
    where a.employee_id = any(p_employee_ids)
      and a.record_date = p_date
  ), '{}'::jsonb);
$$;
revoke all on function public.hr_get_today_attendance(uuid[], date) from public, anon;
grant execute on function public.hr_get_today_attendance(uuid[], date) to authenticated;

-- ─────────────────────── سجل الحضور الشهري لموظف ───────────────────────
create or replace function public.hr_get_monthly_attendance(
  p_employee_id uuid,
  p_year  int,
  p_month int
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_start date := make_date(p_year, p_month, 1);
  v_end   date := (v_start + interval '1 month - 1 day')::date;
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',     a.id,
      'date',   a.record_date,
      'status', a.status,
      'notes',  a.notes,
      'recorded_from', a.recorded_from
    ) order by a.record_date)
    from public.attendance_records a
    where a.employee_id = p_employee_id
      and a.record_date between v_start and v_end
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.hr_get_monthly_attendance(uuid, int, int) from public, anon;
grant execute on function public.hr_get_monthly_attendance(uuid, int, int) to authenticated;

-- ─────────────────────── جلب قائمة الموظفين مع حالة اليوم (HR) ───────────────────────
create or replace function public.hr_get_all_employees_attendance(
  p_date date default current_date
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',          e.id,
      'code',        e.code,
      'full_name',   e.full_name,
      'job_role',    e.job_role,
      'branch_id',   e.branch_id,
      'branch_name', b.name,
      'attendance_status', a.status,
      'attendance_id',     a.id
    ) order by e.full_name)
    from public.employees e
    left join public.branches b on b.id = e.branch_id
    left join public.attendance_records a
      on a.employee_id = e.id and a.record_date = p_date
    where e.status = 'active'
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.hr_get_all_employees_attendance(date) from public, anon;
grant execute on function public.hr_get_all_employees_attendance(date) to authenticated;

-- ═══ طلبات الإجازات ═══

create or replace function public.hr_create_leave_request(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_emp_id   uuid;
  v_start    date;
  v_end      date;
  v_reason   text;
  v_context  text;
  v_id       uuid;
begin
  begin
    v_emp_id  := (p->>'employee_id')::uuid;
    v_start   := (p->>'start_date')::date;
    v_end     := (p->>'end_date')::date;
  exception when others then
    raise exception 'بيانات غير صحيحة';
  end;

  v_reason  := btrim(coalesce(p->>'reason',''));
  v_context := coalesce(p->>'requested_from','cashier');

  if v_reason = '' then raise exception 'سبب الإجازة إلزامي'; end if;
  if v_start <= current_date then
    raise exception 'يجب تقديم طلب الإجازة قبل يوم واحد على الأقل';
  end if;
  if v_end < v_start then raise exception 'تاريخ انتهاء الإجازة قبل بدايتها'; end if;
  if v_context not in ('cashier','inventory','hr') then
    raise exception 'سياق غير صحيح';
  end if;

  insert into public.leave_requests (
    employee_id, requested_from, start_date, end_date, reason, created_by
  ) values (v_emp_id, v_context, v_start, v_end, v_reason, auth.uid())
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'status', 'pending');
end;
$$;
revoke all on function public.hr_create_leave_request(jsonb) from public, anon;
grant execute on function public.hr_create_leave_request(jsonb) to authenticated;

-- جلب طلبات الإجازات
create or replace function public.hr_list_leave_requests(
  p_status text default null,
  p_branch_id uuid default null,
  p_limit int default 50,
  p_offset int default 0
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',             lr.id,
      'employee_id',    lr.employee_id,
      'employee_name',  e.full_name,
      'employee_code',  e.code,
      'job_role',       e.job_role,
      'branch_name',    b.name,
      'requested_from', lr.requested_from,
      'start_date',     lr.start_date,
      'end_date',       lr.end_date,
      'reason',         lr.reason,
      'status',         lr.status,
      'decision_type',  lr.decision_type,
      'decision_notes', lr.decision_notes,
      'created_at',     lr.created_at
    ) order by lr.created_at desc)
    from public.leave_requests lr
    join public.employees e on e.id = lr.employee_id
    left join public.branches b on b.id = e.branch_id
    where (p_status is null or lr.status = p_status)
      and (p_branch_id is null or e.branch_id = p_branch_id)
    limit p_limit offset p_offset
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.hr_list_leave_requests(text, uuid, int, int) from public, anon;
grant execute on function public.hr_list_leave_requests(text, uuid, int, int) to authenticated;

-- موافقة / رفض الإجازة (HR فقط)
create or replace function public.hr_decide_leave_request(
  p_id            uuid,
  p_status        text,   -- 'approved' | 'rejected'
  p_decision_type text default null,  -- 'with_deduction' | 'without_deduction'
  p_notes         text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_leave leave_requests%rowtype;
  v_days  int;
  v_salary numeric;
  v_daily numeric;
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;
  if p_status not in ('approved','rejected') then
    raise exception 'قرار غير صحيح';
  end if;

  select * into v_leave from public.leave_requests where id = p_id;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_leave.status <> 'pending' then raise exception 'الطلب تمت معالجته مسبقاً'; end if;

  update public.leave_requests
  set status = p_status,
      decision_type = p_decision_type,
      decided_by = auth.uid(),
      decided_at = now(),
      decision_notes = p_notes,
      updated_at = now()
  where id = p_id;

  -- إذا موافقة بخصم → نضيف خصم تلقائي
  if p_status = 'approved' and p_decision_type = 'with_deduction' then
    v_days := (v_leave.end_date - v_leave.start_date + 1);
    select basic_salary into v_salary from public.employees where id = v_leave.employee_id;
    v_daily := coalesce(v_salary, 0) / 30.0;

    insert into public.deduction_bonus_requests (
      employee_id, requested_from, type, amount_type, days_amount,
      cash_amount, notes, status, decided_by, decided_at, final_cash_amount, created_by
    ) values (
      v_leave.employee_id, 'hr', 'deduction', 'days', v_days,
      null, 'خصم إجازة: ' || v_leave.reason,
      'approved', auth.uid(), now(), v_daily * v_days, auth.uid()
    );
  end if;

  return jsonb_build_object('id', p_id, 'status', p_status);
end;
$$;
revoke all on function public.hr_decide_leave_request(uuid, text, text, text) from public, anon;
grant execute on function public.hr_decide_leave_request(uuid, text, text, text) to authenticated;

-- ═══ الخصومات والمكافآت ═══

create or replace function public.hr_create_deduction_bonus(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_emp_id    uuid;
  v_type      text;
  v_amt_type  text;
  v_cash      numeric;
  v_days      numeric;
  v_notes     text;
  v_context   text;
  v_id        uuid;
begin
  begin
    v_emp_id   := (p->>'employee_id')::uuid;
    v_cash     := nullif(p->>'cash_amount','')::numeric;
    v_days     := nullif(p->>'days_amount','')::numeric;
  exception when others then
    raise exception 'بيانات غير صحيحة';
  end;

  v_type     := p->>'type';
  v_amt_type := p->>'amount_type';
  v_notes    := btrim(coalesce(p->>'notes',''));
  v_context  := coalesce(p->>'requested_from','cashier');

  if v_type not in ('deduction','bonus') then raise exception 'النوع غير صحيح'; end if;
  if v_amt_type not in ('cash','days') then raise exception 'نوع المبلغ غير صحيح'; end if;
  if v_notes = '' then raise exception 'الملاحظة إلزامية للخصم/المكافأة'; end if;
  if v_amt_type = 'cash' and (v_cash is null or v_cash <= 0) then
    raise exception 'أدخل مبلغاً صحيحاً';
  end if;
  if v_amt_type = 'days' and (v_days is null or v_days <= 0) then
    raise exception 'أدخل عدد أيام صحيحاً';
  end if;

  insert into public.deduction_bonus_requests (
    employee_id, requested_from, type, amount_type, cash_amount, days_amount, notes, created_by
  ) values (v_emp_id, v_context, v_type, v_amt_type, v_cash, v_days, v_notes, auth.uid())
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'status', 'pending');
end;
$$;
revoke all on function public.hr_create_deduction_bonus(jsonb) from public, anon;
grant execute on function public.hr_create_deduction_bonus(jsonb) to authenticated;

-- جلب الخصومات والمكافآت (HR)
create or replace function public.hr_list_deduction_bonuses(
  p_status text default null,
  p_limit int default 50,
  p_offset int default 0
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',               d.id,
      'employee_id',      d.employee_id,
      'employee_name',    e.full_name,
      'employee_code',    e.code,
      'job_role',         e.job_role,
      'branch_name',      b.name,
      'type',             d.type,
      'amount_type',      d.amount_type,
      'cash_amount',      d.cash_amount,
      'days_amount',      d.days_amount,
      'notes',            d.notes,
      'status',           d.status,
      'final_cash_amount',d.final_cash_amount,
      'basic_salary',     e.basic_salary,
      'requested_from',   d.requested_from,
      'created_at',       d.created_at
    ) order by d.created_at desc)
    from public.deduction_bonus_requests d
    join public.employees e on e.id = d.employee_id
    left join public.branches b on b.id = e.branch_id
    where (p_status is null or d.status = p_status)
    limit p_limit offset p_offset
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.hr_list_deduction_bonuses(text, int, int) from public, anon;
grant execute on function public.hr_list_deduction_bonuses(text, int, int) to authenticated;

-- موافقة / رفض الخصم (HR)
create or replace function public.hr_decide_deduction_bonus(
  p_id               uuid,
  p_status           text,  -- 'approved' | 'rejected'
  p_final_cash_amount numeric default null,
  p_notes            text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare 
  v_rec deduction_bonus_requests%rowtype;
  v_emp employees%rowtype;
  v_calculated_cash numeric;
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;
  if p_status not in ('approved','rejected') then
    raise exception 'قرار غير صحيح';
  end if;

  select * into v_rec from public.deduction_bonus_requests where id = p_id;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_rec.status <> 'pending' then raise exception 'الطلب تمت معالجته مسبقاً'; end if;

  select * into v_emp from public.employees where id = v_rec.employee_id;

  -- حساب المبلغ نقداً إذا لم يتم توفيره
  if p_status = 'approved' then
    if p_final_cash_amount is not null then
      v_calculated_cash := p_final_cash_amount;
    elsif v_rec.amount_type = 'days' then
      v_calculated_cash := (v_emp.basic_salary / 30.0) * v_rec.days_amount;
    else
      v_calculated_cash := v_rec.cash_amount;
    end if;
  end if;

  update public.deduction_bonus_requests
  set status            = p_status,
      decided_by        = auth.uid(),
      decided_at        = now(),
      final_cash_amount = v_calculated_cash,
      notes             = coalesce(p_notes, notes),
      updated_at        = now()
  where id = p_id;

  return jsonb_build_object('id', p_id, 'status', p_status);
end;
$$;
revoke all on function public.hr_decide_deduction_bonus(uuid, text, numeric, text) from public, anon;
grant execute on function public.hr_decide_deduction_bonus(uuid, text, numeric, text) to authenticated;

-- جلب طلبات الإجازة/الخصومات من الكاشير أو المخزون (للموظف المسجّل)
create or replace function public.hr_list_my_branch_requests(
  p_branch_id     uuid default null,
  p_context       text default 'cashier',  -- 'cashier' | 'inventory'
  p_request_type  text default 'leave'     -- 'leave' | 'deduction'
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if p_request_type = 'leave' then
    return coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',            lr.id,
        'employee_name', e.full_name,
        'start_date',    lr.start_date,
        'end_date',      lr.end_date,
        'reason',        lr.reason,
        'status',        lr.status,
        'decision_type', lr.decision_type,
        'created_at',    lr.created_at
      ) order by lr.created_at desc)
      from public.leave_requests lr
      join public.employees e on e.id = lr.employee_id
      where lr.requested_from = p_context
        and (p_branch_id is null or e.branch_id = p_branch_id)
      limit 100
    ), '[]'::jsonb);
  else
    return coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',            d.id,
        'employee_name', e.full_name,
        'type',          d.type,
        'amount_type',   d.amount_type,
        'cash_amount',   d.cash_amount,
        'days_amount',   d.days_amount,
        'notes',         d.notes,
        'status',        d.status,
        'created_at',    d.created_at
      ) order by d.created_at desc)
      from public.deduction_bonus_requests d
      join public.employees e on e.id = d.employee_id
      where d.requested_from = p_context
        and (p_branch_id is null or e.branch_id = p_branch_id)
      limit 100
    ), '[]'::jsonb);
  end if;
end;
$$;
revoke all on function public.hr_list_my_branch_requests(uuid, text, text) from public, anon;
grant execute on function public.hr_list_my_branch_requests(uuid, text, text) to authenticated;

-- إضافة إجازة مباشرة معتمدة من قبل HR
create or replace function public.hr_add_direct_leave(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_emp_id   uuid;
  v_start    date;
  v_end      date;
  v_reason   text;
  v_decision_type text;
  v_notes    text;
  v_id       uuid;
  v_days     int;
  v_salary   numeric;
  v_daily    numeric;
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;

  begin
    v_emp_id        := (p->>'employee_id')::uuid;
    v_start         := (p->>'start_date')::date;
    v_end           := (p->>'end_date')::date;
    v_decision_type := p->>'decision_type'; -- 'with_deduction' | 'without_deduction'
  exception when others then
    raise exception 'بيانات غير صحيحة';
  end;

  v_reason := btrim(coalesce(p->>'reason',''));
  v_notes  := btrim(coalesce(p->>'decision_notes',''));

  if v_reason = '' then raise exception 'سبب الإجازة إلزامي'; end if;
  if v_end < v_start then raise exception 'تاريخ انتهاء الإجازة قبل بدايتها'; end if;

  insert into public.leave_requests (
    employee_id, requested_from, start_date, end_date, reason, 
    status, decision_type, decided_by, decided_at, decision_notes, created_by
  ) values (
    v_emp_id, 'hr', v_start, v_end, v_reason, 
    'approved', v_decision_type, auth.uid(), now(), v_notes, auth.uid()
  ) returning id into v_id;

  -- إذا كان بخصم، يتم إدراج خصم تلقائي
  if v_decision_type = 'with_deduction' then
    v_days := (v_end - v_start + 1);
    select basic_salary into v_salary from public.employees where id = v_emp_id;
    v_daily := coalesce(v_salary, 0) / 30.0;

    insert into public.deduction_bonus_requests (
      employee_id, requested_from, type, amount_type, days_amount,
      cash_amount, notes, status, decided_by, decided_at, final_cash_amount, created_by
    ) values (
      v_emp_id, 'hr', 'deduction', 'days', v_days,
      null, 'خصم إجازة: ' || v_reason,
      'approved', auth.uid(), now(), v_daily * v_days, auth.uid()
    );
  end if;

  return jsonb_build_object('id', v_id, 'status', 'approved');
end;
$$;
revoke all on function public.hr_add_direct_leave(jsonb) from public, anon;
grant execute on function public.hr_add_direct_leave(jsonb) to authenticated;

-- إضافة خصم / مكافأة مباشرة ومعتمدة من قبل HR
create or replace function public.hr_add_direct_deduction_bonus(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_emp_id    uuid;
  v_type      text;
  v_amt_type  text;
  v_cash      numeric;
  v_days      numeric;
  v_final_cash numeric;
  v_notes     text;
  v_id        uuid;
  v_salary    numeric;
  v_daily     numeric;
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح';
  end if;

  begin
    v_emp_id   := (p->>'employee_id')::uuid;
    v_cash     := nullif(p->>'cash_amount','')::numeric;
    v_days     := nullif(p->>'days_amount','')::numeric;
    v_final_cash := nullif(p->>'final_cash_amount','')::numeric;
  exception when others then
    raise exception 'بيانات غير صحيحة';
  end;

  v_type     := p->>'type';
  v_amt_type := p->>'amount_type';
  v_notes    := btrim(coalesce(p->>'notes',''));

  if v_type not in ('deduction','bonus') then raise exception 'النوع غير صحيح'; end if;
  if v_amt_type not in ('cash','days') then raise exception 'نوع المبلغ غير صحيح'; end if;
  if v_notes = '' then raise exception 'الملاحظة إلزامية'; end if;
  if v_amt_type = 'cash' and (v_cash is null or v_cash <= 0) then
    raise exception 'أدخل مبلغاً صحيحاً';
  end if;
  if v_amt_type = 'days' and (v_days is null or v_days <= 0) then
    raise exception 'أدخل عدد أيام صحيحاً';
  end if;

  -- حساب القيمة النقدية النهائية إذا لم تكن مرسلة
  if v_final_cash is null then
    if v_amt_type = 'cash' then
      v_final_cash := v_cash;
    else
      select basic_salary into v_salary from public.employees where id = v_emp_id;
      v_daily := coalesce(v_salary, 0) / 30.0;
      v_final_cash := v_daily * v_days;
    end if;
  end if;

  insert into public.deduction_bonus_requests (
    employee_id, requested_from, type, amount_type, cash_amount, days_amount, 
    notes, status, decided_by, decided_at, final_cash_amount, created_by
  ) values (
    v_emp_id, 'hr', v_type, v_amt_type, v_cash, v_days, 
    v_notes, 'approved', auth.uid(), now(), v_final_cash, auth.uid()
  ) returning id into v_id;

  return jsonb_build_object('id', v_id, 'status', 'approved');
end;
$$;
revoke all on function public.hr_add_direct_deduction_bonus(jsonb) from public, anon;
grant execute on function public.hr_add_direct_deduction_bonus(jsonb) to authenticated;

commit;
