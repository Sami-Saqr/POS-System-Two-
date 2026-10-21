-- 022_hr_lifecycle_retention_reports.sql
-- نظام إدارة الموارد البشرية (HR) - تحديث دورة حياة الموظف، الاحتفاظ بالبيانات، والتقارير المتقدمة

begin;

-- ═══════════════════════════════════════════════════════════════════
-- 1. جدول سجلات حذف فترات الاحتفاظ بالبيانات (Retention Logs)
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.hr_retention_logs (
  id                  uuid primary key default gen_random_uuid(),
  purged_at           timestamptz not null default now(),
  cutoff_date         date not null,
  attendance_deleted  int not null default 0,
  leaves_deleted      int not null default 0,
  deductions_deleted  int not null default 0,
  details             jsonb not null default '{}'::jsonb
);

create index if not exists idx_retention_logs_date on public.hr_retention_logs(purged_at);
alter table public.hr_retention_logs enable row level security;
revoke all on table public.hr_retention_logs from public, anon;
grant select on table public.hr_retention_logs to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 2. تحديث hr_get_branch_employees و hr_get_drivers
--    - إرجاع الموظفين النشطين فقط
--    - استبعاد أي موظف في إجازة معتمدة في التاريخ المحدد
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.hr_get_branch_employees(
  p_branch_id uuid default null,
  p_context   text default 'cashier',
  p_date      date default current_date
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if p_context = 'cashier' then
    return coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',          e.id,
        'code',        e.code,
        'full_name',   e.full_name,
        'job_role',    e.job_role,
        'branch_id',   e.branch_id,
        'branch_name', b.name,
        'status',      e.status,
        'notes',       e.notes,
        'hire_date',   e.hire_date,
        'created_at',  e.created_at
      ) order by e.full_name)
      from public.employees e
      left join public.branches b on b.id = e.branch_id
      where e.status = 'active'
        and e.job_role in ('cashier','worker','branch_manager')
        and e.branch_id = p_branch_id
        -- استبعاد من هم في إجازة معتمدة في هذا التاريخ
        and not exists (
          select 1 from public.leave_requests lr
          where lr.employee_id = e.id
            and lr.status = 'approved'
            and p_date between lr.start_date and lr.end_date
        )
        and not exists (
          select 1 from public.attendance_records ar
          where ar.employee_id = e.id
            and ar.record_date = p_date
            and ar.status = 'on_leave'
        )
    ), '[]'::jsonb);
  elsif p_context = 'inventory' then
    return coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',          e.id,
        'code',        e.code,
        'full_name',   e.full_name,
        'job_role',    e.job_role,
        'branch_id',   e.branch_id,
        'status',      e.status,
        'notes',       e.notes,
        'hire_date',   e.hire_date,
        'created_at',  e.created_at
      ) order by e.full_name)
      from public.employees e
      where e.status = 'active'
        and e.job_role in ('storekeeper','chef','kitchen_worker')
        and e.branch_id is null
        -- استبعاد من هم في إجازة معتمدة في هذا التاريخ
        and not exists (
          select 1 from public.leave_requests lr
          where lr.employee_id = e.id
            and lr.status = 'approved'
            and p_date between lr.start_date and lr.end_date
        )
        and not exists (
          select 1 from public.attendance_records ar
          where ar.employee_id = e.id
            and ar.record_date = p_date
            and ar.status = 'on_leave'
        )
    ), '[]'::jsonb);
  else
    return '[]'::jsonb;
  end if;
end;
$$;

revoke all on function public.hr_get_branch_employees(uuid, text, date) from public, anon;
grant execute on function public.hr_get_branch_employees(uuid, text, date) to authenticated;


create or replace function public.hr_get_drivers(
  p_date date default current_date
) returns jsonb
language sql security definer set search_path = public as $$
  select coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',         e.id,
      'code',       e.code,
      'full_name',  e.full_name,
      'job_role',   e.job_role,
      'status',     e.status,
      'notes',      e.notes,
      'hire_date',  e.hire_date,
      'created_at', e.created_at
    ) order by e.full_name)
    from public.employees e
    where e.status = 'active'
      and e.job_role = 'driver'
      and not exists (
        select 1 from public.leave_requests lr
        where lr.employee_id = e.id
          and lr.status = 'approved'
          and p_date between lr.start_date and lr.end_date
      )
      and not exists (
        select 1 from public.attendance_records ar
        where ar.employee_id = e.id
          and ar.record_date = p_date
          and ar.status = 'on_leave'
      )
  ), '[]'::jsonb);
$$;

revoke all on function public.hr_get_drivers(date) from public, anon;
grant execute on function public.hr_get_drivers(date) to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 3. تحديث hr_submit_attendance للتحقق الصارم من حالة الموظف والإجازات
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.hr_submit_attendance(
  p_employee_id uuid,
  p_record_date date,
  p_status      text,   -- 'present' | 'absent' | 'on_leave'
  p_context     text,   -- 'cashier' | 'inventory' | 'hr'
  p_notes       text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id            uuid;
  v_existing      text;
  v_emp           public.employees%rowtype;
  v_emp_start     date;
  v_emp_cutoff    date;
begin
  if p_status not in ('present','absent','on_leave') then
    raise exception 'حالة الحضور غير صحيحة';
  end if;

  -- جلب بيانات الموظف والتحقق من حالته
  select * into v_emp from public.employees where id = p_employee_id;
  if not found then
    raise exception 'الموظف غير موجود';
  end if;

  -- الموظف غير النشط لا يسجل له حضور أو غياب نهائياً
  if v_emp.status <> 'active' then
    raise exception 'لا يمكن تسجيل حضور أو غياب لموظف غير نشط (مؤرشف أو مفصول أو موقوف)';
  end if;

  -- التحقق من تاريخ تعيين / إنشاء الموظف
  v_emp_start := coalesce(v_emp.hire_date, v_emp.created_at::date);
  if p_record_date < v_emp_start then
    raise exception 'لا يمكن تسجيل حضور لتاريخ يسبق تاريخ تعيين أو إنشاء الموظف (%)', v_emp_start;
  end if;

  -- التحقق مما إذا كان الموظف في إجازة معتمدة في هذا التاريخ
  if exists (
    select 1 from public.leave_requests
    where employee_id = p_employee_id
      and status = 'approved'
      and p_record_date between start_date and end_date
  ) then
    raise exception 'الموظف في إجازة معتمدة في هذا التاريخ ولا يمكن تسجيل حضور أو غياب له';
  end if;

  -- فترة الاحتفاظ بالبيانات للتحقق من التاريخ
  v_emp_cutoff := coalesce(v_emp.hire_date, v_emp.created_at::date);

  -- فترة السماح: غير HR لا يسجل إلا اليوم أو أمس
  if p_context <> 'hr' and not (public._has_role('hr') or public._has_role('owner')) then
    if p_record_date < current_date - 1 or p_record_date > current_date then
      raise exception 'لا يمكن تسجيل الحضور إلا ليوم أمس أو اليوم';
    end if;
  end if;

  -- هل يوجد سجل مسبق؟
  select id, status into v_id, v_existing
  from public.attendance_records
  where employee_id = p_employee_id and record_date = p_record_date;

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


-- ═══════════════════════════════════════════════════════════════════
-- 4. تسجيل أيام الإجازة تلقائياً في attendance_records عند الموافقة
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.hr_decide_leave_request(
  p_id            uuid,
  p_status        text,   -- 'approved' | 'rejected'
  p_decision_type text default null,  -- 'with_deduction' | 'without_deduction'
  p_notes         text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_leave   public.leave_requests%rowtype;
  v_days    int;
  v_salary  numeric;
  v_daily   numeric;
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

  if p_status = 'approved' then
    v_days := (v_leave.end_date - v_leave.start_date + 1);

    -- 1. تسجيل كل أيام الإجازة تلقائياً كـ on_leave في attendance_records
    insert into public.attendance_records (
      employee_id, record_date, status, recorded_by, recorded_from, notes
    )
    select 
      v_leave.employee_id,
      d::date,
      'on_leave',
      auth.uid(),
      'hr',
      'إجازة معتمدة: ' || v_leave.reason
    from generate_series(v_leave.start_date, v_leave.end_date, interval '1 day') as d
    on conflict (employee_id, record_date) do update
      set status = 'on_leave',
          notes = excluded.notes,
          recorded_by = excluded.recorded_by,
          recorded_from = excluded.recorded_from,
          updated_at = now();

    -- 2. إذا كانت إجازة بخصم، يتم تسجيل خصم بقيمة الأيام (عدد الأيام * الراتب / 30)
    if p_decision_type = 'with_deduction' then
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
  end if;

  return jsonb_build_object('id', p_id, 'status', p_status);
end;
$$;

revoke all on function public.hr_decide_leave_request(uuid, text, text, text) from public, anon;
grant execute on function public.hr_decide_leave_request(uuid, text, text, text) to authenticated;


create or replace function public.hr_add_direct_leave(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_emp_id        uuid;
  v_start         date;
  v_end           date;
  v_reason        text;
  v_decision_type text;
  v_notes         text;
  v_id            uuid;
  v_days          int;
  v_salary        numeric;
  v_daily         numeric;
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

  v_days := (v_end - v_start + 1);

  -- 1. تسجيل كل أيام الإجازة تلقائياً كـ on_leave في attendance_records
  insert into public.attendance_records (
    employee_id, record_date, status, recorded_by, recorded_from, notes
  )
  select 
    v_emp_id,
    d::date,
    'on_leave',
    auth.uid(),
    'hr',
    'إجازة معتمدة: ' || v_reason
  from generate_series(v_start, v_end, interval '1 day') as d
  on conflict (employee_id, record_date) do update
    set status = 'on_leave',
        notes = excluded.notes,
        recorded_by = excluded.recorded_by,
        recorded_from = excluded.recorded_from,
        updated_at = now();

  -- 2. إذا كانت إجازة بخصم، يتم تسجيل الخصم
  if v_decision_type = 'with_deduction' then
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


-- ═══════════════════════════════════════════════════════════════════
-- 5. وظيفة الغياب التلقائي (Auto-Mark Absent)
--    - تعمل يومياً بعد منتصف الليل
--    - للموظفين النشطين فقط
--    - تتجاهل من هم في إجازة معتمدة ومن تم تسجيلهم بالفعل
--    - idempotent بالكامل
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.hr_auto_mark_absent(
  p_target_date date default current_date - 1
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_count int := 0;
begin
  with inserted as (
    insert into public.attendance_records (
      employee_id, record_date, status, recorded_by, recorded_from, notes
    )
    select 
      e.id,
      p_target_date,
      'absent',
      null,
      'system',
      'غياب تلقائي (بدون إذن)'
    from public.employees e
    where e.status = 'active'
      and coalesce(e.hire_date, e.created_at::date) <= p_target_date
      and not exists (
        select 1 from public.attendance_records a
        where a.employee_id = e.id and a.record_date = p_target_date
      )
      and not exists (
        select 1 from public.leave_requests lr
        where lr.employee_id = e.id
          and lr.status = 'approved'
          and p_target_date between lr.start_date and lr.end_date
      )
    on conflict (employee_id, record_date) do nothing
    returning id
  )
  select count(*) into v_count from inserted;

  return jsonb_build_object(
    'target_date', p_target_date,
    'marked_absent_count', v_count
  );
end;
$$;

revoke all on function public.hr_auto_mark_absent(date) from public, anon;
grant execute on function public.hr_auto_mark_absent(date) to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 6. سياسة الاحتفاظ بالبيانات وحذف السجلات القديمة (Data Retention Purge)
--    - قاعدة: بيانات الشهر M تبقى محفوظة حتى يوم 5 من الشهر M+2
--    - في يوم 5 من الشهر، تُحذف كل السجلات التي تسبق الشهر السابق (شهر M)
--    - لا يتم حذف جدول الموظفين نهائياً
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.hr_purge_expired_retention_data(
  p_force boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_today       date := current_date;
  v_day         int  := extract(day from v_today);
  v_cutoff      date;
  v_att_count   int  := 0;
  v_leave_count int  := 0;
  v_ded_count   int  := 0;
  v_log_id      uuid;
begin
  -- إذا لم يكن اليوم >= 5 ولم نحدد فرض التشغيل، نتجاوز الحذف
  if v_day < 5 and not p_force then
    return jsonb_build_object(
      'status', 'skipped',
      'reason', 'Retention purge executes on or after day 5 of the month',
      'current_day', v_day
    );
  end if;

  -- الحد الفاصل: أول يوم من الشهر السابق
  -- على سبيل المثال في 2026-10-05: الحد هو 2026-09-01
  -- كل ما هو قبل 2026-09-01 (شهر 8 وما قبله) يتم حذفه نهائياً
  v_cutoff := date_trunc('month', v_today - interval '1 month')::date;

  -- 1. حذف سجلات الحضور
  with del_att as (
    delete from public.attendance_records
    where record_date < v_cutoff
    returning id
  )
  select count(*) into v_att_count from del_att;

  -- 2. حذف سجلات الإجازات
  with del_leave as (
    delete from public.leave_requests
    where end_date < v_cutoff
    returning id
  )
  select count(*) into v_leave_count from del_leave;

  -- 3. حذف سجلات الخصومات والمكافآت
  with del_ded as (
    delete from public.deduction_bonus_requests
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_ded_count from del_ded;

  -- 4. تسجيل في سجلات الاحتفاظ
  insert into public.hr_retention_logs (
    cutoff_date, attendance_deleted, leaves_deleted, deductions_deleted, details
  ) values (
    v_cutoff, v_att_count, v_leave_count, v_ded_count,
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
    'attendance_deleted', v_att_count,
    'leaves_deleted', v_leave_count,
    'deductions_deleted', v_ded_count
  );
end;
$$;

revoke all on function public.hr_purge_expired_retention_data(boolean) from public, anon;
grant execute on function public.hr_purge_expired_retention_data(boolean) to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 7. جدولة مهام pg_cron (Cron Scheduled Jobs)
-- ═══════════════════════════════════════════════════════════════════
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- إزالة المهام السابقة إن وُجدت
    perform cron.unschedule('hr-daily-auto-absent')
      where exists (select 1 from cron.job where jobname = 'hr-daily-auto-absent');
    perform cron.unschedule('hr-monthly-retention-purge')
      where exists (select 1 from cron.job where jobname = 'hr-monthly-retention-purge');

    -- الغياب التلقائي: يومياً الساعة 00:05 بعد منتصف الليل
    perform cron.schedule(
      'hr-daily-auto-absent',
      '5 0 * * *',
      'select public.hr_auto_mark_absent();'
    );

    -- حذف السجلات القديمة: يومياً الساعة 00:15 (تتحقق الدالة إن كان اليوم >= 5)
    perform cron.schedule(
      'hr-monthly-retention-purge',
      '15 0 5 * *',
      'select public.hr_purge_expired_retention_data(false);'
    );
  end if;
exception when others then
  raise notice 'pg_cron not available: %', sqlerrm;
end;
$$;


-- ═══════════════════════════════════════════════════════════════════
-- 8. دوال التقارير (HR Reports RPCs)
--    - حساب خصم الغياب: 2 × (الراتب ÷ 30)
--    - حساب خصم الإجازة بخصم: عدد الأيام × (الراتب ÷ 30)
--    - الإجازة بدون خصم: 0
--    - للموظفين المؤرشفين/المفصولين/الموقوفين: احتساب الأيام حتى تاريخ الإجراء فقط
--    - لا يتم احتساب أي أيام تسبق تاريخ تعيين الموظف
-- ═══════════════════════════════════════════════════════════════════

-- التقرير الأول: تقرير شامل لكل العاملين
create or replace function public.hr_get_comprehensive_report(
  p_start_date date,
  p_end_date   date
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_retention_cutoff date;
  v_report_result    jsonb;
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح لك بالوصول لتقارير الموارد البشرية';
  end if;

  if p_end_date < p_start_date then
    raise exception 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
  end if;

  -- حساب تاريخ الحد الأدنى المحفوظ وفق سياسة الاحتفاظ
  if extract(day from current_date) >= 5 then
    v_retention_cutoff := date_trunc('month', current_date - interval '1 month')::date;
  else
    v_retention_cutoff := date_trunc('month', current_date - interval '2 month')::date;
  end if;

  if p_start_date < v_retention_cutoff then
    raise exception 'التاريخ المختار خارج نطاق البيانات المحفوظة (أقدم تاريخ متاح هو %)', v_retention_cutoff;
  end if;

  with emp_ranges as (
    select 
      e.id,
      e.code,
      e.full_name,
      e.job_role,
      e.branch_id,
      b.name as branch_name,
      e.basic_salary,
      e.allowances,
      e.transport_allowance,
      e.status,
      e.hire_date,
      e.created_at,
      greatest(p_start_date, coalesce(e.hire_date, e.created_at::date)) as eff_start,
      case 
        when e.status in ('archived', 'terminated', 'suspended') then
          least(p_end_date, coalesce(e.termination_date, e.suspension_start, e.status_changed_at::date, e.updated_at::date))
        else p_end_date
      end as eff_end
    from public.employees e
    left join public.branches b on b.id = e.branch_id
  ),
  att_stats as (
    select 
      er.id as employee_id,
      count(*) filter (where ar.status = 'present') as present_days,
      count(*) filter (where ar.status = 'absent')  as absent_days,
      count(*) filter (where ar.status = 'on_leave') as leave_days
    from emp_ranges er
    left join public.attendance_records ar
      on ar.employee_id = er.id
     and ar.record_date between er.eff_start and er.eff_end
    where er.eff_start <= er.eff_end
    group by er.id
  ),
  leave_deductions as (
    -- حساب أيام الإجازة التي تقرر خصمها
    select 
      er.id as employee_id,
      count(distinct d::date) as leave_with_deduction_days
    from emp_ranges er
    join public.leave_requests lr on lr.employee_id = er.id
    cross join lateral generate_series(lr.start_date, lr.end_date, interval '1 day') as d
    where lr.status = 'approved'
      and lr.decision_type = 'with_deduction'
      and d::date between er.eff_start and er.eff_end
      and er.eff_start <= er.eff_end
    group by er.id
  ),
  ded_bonus_stats as (
    -- الخصومات والمكافآت اليدوية المعتمدة (مع استبعاد خصومات الإجازات لتفادي التكرار)
    select 
      er.id as employee_id,
      coalesce(sum(case 
        when dbr.type = 'deduction' and dbr.notes not like 'خصم إجازة:%' 
        then dbr.final_cash_amount 
        else 0 
      end), 0) as manual_deductions,
      coalesce(sum(case 
        when dbr.type = 'bonus' 
        then dbr.final_cash_amount 
        else 0 
      end), 0) as total_additions
    from emp_ranges er
    left join public.deduction_bonus_requests dbr
      on dbr.employee_id = er.id
     and dbr.status = 'approved'
     and dbr.created_at::date between er.eff_start and er.eff_end
    where er.eff_start <= er.eff_end
    group by er.id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'employee_id',         er.id,
      'code',                er.code,
      'full_name',           er.full_name,
      'job_role',            er.job_role,
      'branch_name',         coalesce(er.branch_name, 'المركز الرئيسي'),
      'status',              er.status,
      'basic_salary',        er.basic_salary,
      'allowances',          er.allowances,
      'transport_allowance', er.transport_allowance,
      'effective_start',     er.eff_start,
      'effective_end',       er.eff_end,
      'is_in_range',         (er.eff_start <= er.eff_end),
      'present_days',        coalesce(att.present_days, 0),
      'absent_days',         coalesce(att.absent_days, 0),
      'leave_days',          coalesce(att.leave_days, 0),
      'leave_with_deduction_days', coalesce(ld.leave_with_deduction_days, 0),
      'daily_rate',          round((er.basic_salary / 30.0), 2),
      -- خصم الغياب: 2 × (الراتب ÷ 30) × عدد أيام الغياب
      'absence_deduction',   round(coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0), 2),
      -- خصم الإجازة بخصم: 1 × (الراتب ÷ 30) × عدد الأيام
      'leave_deduction',     round(coalesce(ld.leave_with_deduction_days, 0) * (er.basic_salary / 30.0), 2),
      'manual_deductions',   round(coalesce(dbs.manual_deductions, 0), 2),
      -- إجمالي الخصومات
      'total_deductions',    round(
        (coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0)) +
        (coalesce(ld.leave_with_deduction_days, 0) * (er.basic_salary / 30.0)) +
        coalesce(dbs.manual_deductions, 0), 2
      ),
      -- إجمالي الإضافات / المكافآت
      'total_additions',     round(coalesce(dbs.total_additions, 0), 2),
      -- صافي الراتب المستحق: (أيام الحضور × معدل اليوم) - خصومات + مكافآت
      -- الإجازة بدون خصم تحتسب حضوراً | الإجازة بخصم = خصم 1 يوم | الغياب = خصم 2 يوم
      'net_salary',          round(
        (coalesce(att.present_days, 0) * (er.basic_salary / 30.0)) -
        ((coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0)) +
         (coalesce(ld.leave_with_deduction_days, 0) * (er.basic_salary / 30.0)) +
         coalesce(dbs.manual_deductions, 0)) +
        coalesce(dbs.total_additions, 0), 2
      )
    ) order by er.full_name
  ), '[]'::jsonb) into v_report_result
  from emp_ranges er
  left join att_stats att on att.employee_id = er.id
  left join leave_deductions ld on ld.employee_id = er.id
  left join ded_bonus_stats dbs on dbs.employee_id = er.id;

  return v_report_result;
end;
$$;

revoke all on function public.hr_get_comprehensive_report(date, date) from public, anon;
grant execute on function public.hr_get_comprehensive_report(date, date) to authenticated;


-- التقرير الثاني: تقرير موظف واحد تفصيلي
create or replace function public.hr_get_employee_report(
  p_employee_id uuid,
  p_start_date  date,
  p_end_date    date
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_retention_cutoff date;
  v_emp              public.employees%rowtype;
  v_branch_name      text;
  v_eff_start        date;
  v_eff_end          date;
  v_present_days     int := 0;
  v_absent_days      int := 0;
  v_leave_days       int := 0;
  v_leave_ded_days   int := 0;
  v_manual_ded       numeric := 0;
  v_total_bonuses    numeric := 0;
  v_daily_rate       numeric := 0;
  v_absence_ded      numeric := 0;
  v_leave_ded        numeric := 0;
  v_total_ded        numeric := 0;
  v_net_salary       numeric := 0;
  v_daily_records    jsonb;
  v_extra_records    jsonb;
begin
  if not public._has_role('hr') then
    raise exception using errcode='42501', message='غير مصرح لك بالوصول لتقارير الموارد البشرية';
  end if;

  select e.*, b.name into v_emp
  from public.employees e
  left join public.branches b on b.id = e.branch_id
  where e.id = p_employee_id;

  if v_emp.id is null then
    raise exception 'الموظف غير موجود';
  end if;

  select b.name into v_branch_name
  from public.branches b
  where b.id = v_emp.branch_id;

  -- التحقق من النطاق المحفوظ
  if extract(day from current_date) >= 5 then
    v_retention_cutoff := date_trunc('month', current_date - interval '1 month')::date;
  else
    v_retention_cutoff := date_trunc('month', current_date - interval '2 month')::date;
  end if;

  if p_start_date < v_retention_cutoff then
    raise exception 'التاريخ المختار خارج نطاق البيانات المحفوظة (أقدم تاريخ متاح هو %)', v_retention_cutoff;
  end if;

  -- تحديد بداية ونهاية النطاق الفعلي للموظف
  v_eff_start := greatest(p_start_date, coalesce(v_emp.hire_date, v_emp.created_at::date));
  if v_emp.status in ('archived', 'terminated', 'suspended') then
    v_eff_end := least(p_end_date, coalesce(v_emp.termination_date, v_emp.suspension_start, v_emp.status_changed_at::date, v_emp.updated_at::date));
  else
    v_eff_end := p_end_date;
  end if;

  v_daily_rate := round(v_emp.basic_salary / 30.0, 2);

  if v_eff_start <= v_eff_end then
    -- إحصائيات الحضور
    select 
      count(*) filter (where status = 'present'),
      count(*) filter (where status = 'absent'),
      count(*) filter (where status = 'on_leave')
    into v_present_days, v_absent_days, v_leave_days
    from public.attendance_records
    where employee_id = p_employee_id
      and record_date between v_eff_start and v_eff_end;

    -- أيام الإجازة بخصم
    select count(distinct d::date) into v_leave_ded_days
    from public.leave_requests lr
    cross join lateral generate_series(lr.start_date, lr.end_date, interval '1 day') as d
    where lr.employee_id = p_employee_id
      and lr.status = 'approved'
      and lr.decision_type = 'with_deduction'
      and d::date between v_eff_start and v_eff_end;

    -- الخصومات والإضافات اليدوية
    select 
      coalesce(sum(case 
        when type = 'deduction' and notes not like 'خصم إجازة:%' 
        then final_cash_amount else 0 
      end), 0),
      coalesce(sum(case 
        when type = 'bonus' 
        then final_cash_amount else 0 
      end), 0)
    into v_manual_ded, v_total_bonuses
    from public.deduction_bonus_requests
    where employee_id = p_employee_id
      and status = 'approved'
      and created_at::date between v_eff_start and v_eff_end;

    -- تفصيل يوم بيوم لكل يوم في النطاق الفعلي
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'date',            d::date,
        'status',          coalesce(ar.status, 'unrecorded'),
        'status_label',    case 
          when ar.status = 'present' then 'حاضر'
          when ar.status = 'absent' then 'غائب'
          when ar.status = 'on_leave' then 'إجازة'
          else 'غير مسجل'
        end,
        'notes',           ar.notes,
        'recorded_from',   ar.recorded_from,
        'deduction_days',  case 
          when ar.status = 'absent' then 2.0
          when ar.status = 'on_leave' and exists (
            select 1 from public.leave_requests lr 
            where lr.employee_id = p_employee_id 
              and lr.status = 'approved' 
              and lr.decision_type = 'with_deduction' 
              and d::date between lr.start_date and lr.end_date
          ) then 1.0
          else 0.0
        end,
        'deduction_amount', case 
          when ar.status = 'absent' then round(2 * v_daily_rate, 2)
          when ar.status = 'on_leave' and exists (
            select 1 from public.leave_requests lr 
            where lr.employee_id = p_employee_id 
              and lr.status = 'approved' 
              and lr.decision_type = 'with_deduction' 
              and d::date between lr.start_date and lr.end_date
          ) then round(1 * v_daily_rate, 2)
          else 0.0
        end
      ) order by d::date
    ), '[]'::jsonb) into v_daily_records
    from generate_series(v_eff_start, v_eff_end, interval '1 day') as d
    left join public.attendance_records ar
      on ar.employee_id = p_employee_id
     and ar.record_date = d::date;

    -- تفاصيل الخصومات والمكافآت الإضافية في الفترة
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'id',          dbr.id,
        'type',        dbr.type,
        'amount_type', dbr.amount_type,
        'amount',      dbr.final_cash_amount,
        'days_amount', dbr.days_amount,
        'notes',       dbr.notes,
        'date',        dbr.created_at::date
      ) order by dbr.created_at
    ), '[]'::jsonb) into v_extra_records
    from public.deduction_bonus_requests dbr
    where dbr.employee_id = p_employee_id
      and dbr.status = 'approved'
      and dbr.created_at::date between v_eff_start and v_eff_end;
  else
    v_daily_records := '[]'::jsonb;
    v_extra_records := '[]'::jsonb;
  end if;

  v_absence_ded := round(v_absent_days * 2 * v_daily_rate, 2);
  v_leave_ded   := round(v_leave_ded_days * v_daily_rate, 2);
  v_total_ded   := round(v_absence_ded + v_leave_ded + v_manual_ded, 2);
  -- صافي الراتب: (أيام الحضور × معدل اليوم) - خصومات + مكافآت
  -- الإجازة بدون خصم تحتسب حضوراً | الإجازة بخصم = خصم 1 يوم | الغياب = خصم 2 يوم
  v_net_salary  := round(
    (v_present_days * v_daily_rate) -
    v_total_ded + v_total_bonuses, 2
  );

  return jsonb_build_object(
    'employee', jsonb_build_object(
      'id',                  v_emp.id,
      'code',                v_emp.code,
      'full_name',           v_emp.full_name,
      'job_role',            v_emp.job_role,
      'branch_name',         coalesce(v_branch_name, 'المركز الرئيسي'),
      'status',              v_emp.status,
      'hire_date',           v_emp.hire_date,
      'created_at',          v_emp.created_at,
      'basic_salary',        v_emp.basic_salary,
      'allowances',          v_emp.allowances,
      'transport_allowance', v_emp.transport_allowance,
      'daily_rate',          v_daily_rate
    ),
    'range', jsonb_build_object(
      'requested_start',     p_start_date,
      'requested_end',       p_end_date,
      'effective_start',     v_eff_start,
      'effective_end',       v_eff_end,
      'is_in_range',         (v_eff_start <= v_eff_end)
    ),
    'summary', jsonb_build_object(
      'present_days',             v_present_days,
      'absent_days',              v_absent_days,
      'leave_days',               v_leave_days,
      'leave_with_deduction_days',v_leave_ded_days,
      'absence_deduction',        v_absence_ded,
      'leave_deduction',          v_leave_ded,
      'manual_deductions',        v_manual_ded,
      'total_deductions',         v_total_ded,
      'total_bonuses',            v_total_bonuses,
      'net_salary',               v_net_salary
    ),
    'daily_breakdown',  v_daily_records,
    'extra_records',    v_extra_records
  );
end;
$$;

revoke all on function public.hr_get_employee_report(uuid, date, date) from public, anon;
grant execute on function public.hr_get_employee_report(uuid, date, date) to authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 9. تحديث hr_get_all_employees_attendance لتضمين التواريخ والحالة
-- ═══════════════════════════════════════════════════════════════════
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
      'id',                e.id,
      'code',              e.code,
      'full_name',         e.full_name,
      'job_role',          e.job_role,
      'branch_id',         e.branch_id,
      'branch_name',       b.name,
      'attendance_status', a.status,
      'attendance_id',     a.id,
      'status',            e.status,
      'hire_date',         e.hire_date,
      'created_at',        e.created_at,
      'status_changed_at', e.status_changed_at,
      'notes',             e.notes
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

commit;
