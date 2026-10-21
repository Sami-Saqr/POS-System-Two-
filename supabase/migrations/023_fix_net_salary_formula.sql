-- ═══════════════════════════════════════════════════════════════
-- تحديث معادلة صافي الراتب في دالتي التقارير
-- المعادلة الجديدة: (أيام الحضور × معدل اليوم) - الخصومات + المكافآت
-- الإجازة بدون خصم = تُعتبر حضوراً (present_days)
-- الإجازة بخصم   = خصم يوم واحد لليوم الواحد
-- الغياب         = خصم يومين لليوم الواحد
-- ═══════════════════════════════════════════════════════════════

-- ── 1) التقرير الشامل لجميع الموظفين ────────────────────────
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
      count(*) filter (where ar.status = 'present')  as present_days,
      count(*) filter (where ar.status = 'absent')   as absent_days,
      count(*) filter (where ar.status = 'on_leave') as leave_days
    from emp_ranges er
    left join public.attendance_records ar
      on ar.employee_id = er.id
     and ar.record_date between er.eff_start and er.eff_end
    where er.eff_start <= er.eff_end
    group by er.id
  ),
  leave_deductions as (
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
    select
      er.id as employee_id,
      coalesce(sum(case
        when dbr.type = 'deduction' and dbr.notes not like 'خصم إجازة:%'
        then dbr.final_cash_amount else 0
      end), 0) as manual_deductions,
      coalesce(sum(case
        when dbr.type = 'bonus'
        then dbr.final_cash_amount else 0
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
      'employee_id',               er.id,
      'code',                      er.code,
      'full_name',                 er.full_name,
      'job_role',                  er.job_role,
      'branch_name',               coalesce(er.branch_name, 'المركز الرئيسي'),
      'status',                    er.status,
      'basic_salary',              er.basic_salary,
      'allowances',                er.allowances,
      'transport_allowance',       er.transport_allowance,
      'effective_start',           er.eff_start,
      'effective_end',             er.eff_end,
      'is_in_range',               (er.eff_start <= er.eff_end),
      'present_days',              coalesce(att.present_days, 0),
      'absent_days',               coalesce(att.absent_days, 0),
      'leave_days',                coalesce(att.leave_days, 0),
      'leave_with_deduction_days', coalesce(ld.leave_with_deduction_days, 0),
      'daily_rate',                round((er.basic_salary / 30.0), 2),
      -- خصم الغياب: 2 يوم × معدل اليوم
      'absence_deduction',         round(coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0), 2),
      -- خصم الإجازة بخصم: 1 يوم × معدل اليوم
      'leave_deduction',           round(coalesce(ld.leave_with_deduction_days, 0) * (er.basic_salary / 30.0), 2),
      'manual_deductions',         round(coalesce(dbs.manual_deductions, 0), 2),
      'total_deductions',          round(
        (coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0)) +
        (coalesce(ld.leave_with_deduction_days, 0) * (er.basic_salary / 30.0)) +
        coalesce(dbs.manual_deductions, 0), 2
      ),
      'total_additions',           round(coalesce(dbs.total_additions, 0), 2),
      -- صافي الراتب = (أيام الحضور × معدل اليوم) - الخصومات + المكافآت
      -- ملاحظة: أيام الإجازة بدون خصم تُسجَّل present في attendance_records
      'net_salary',                round(
        (coalesce(att.present_days, 0) * (er.basic_salary / 30.0)) -
        ((coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0)) +
         (coalesce(ld.leave_with_deduction_days, 0) * (er.basic_salary / 30.0)) +
         coalesce(dbs.manual_deductions, 0)) +
        coalesce(dbs.total_additions, 0), 2
      )
    ) order by er.full_name
  ), '[]'::jsonb) into v_report_result
  from emp_ranges er
  left join att_stats att        on att.employee_id = er.id
  left join leave_deductions ld  on ld.employee_id  = er.id
  left join ded_bonus_stats dbs  on dbs.employee_id = er.id;

  return v_report_result;
end;
$$;

revoke all on function public.hr_get_comprehensive_report(date, date) from public, anon;
grant execute on function public.hr_get_comprehensive_report(date, date) to authenticated;


-- ── 2) تقرير موظف واحد تفصيلي ───────────────────────────────
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
  v_present_days     int     := 0;
  v_absent_days      int     := 0;
  v_leave_days       int     := 0;
  v_leave_ded_days   int     := 0;
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

  if extract(day from current_date) >= 5 then
    v_retention_cutoff := date_trunc('month', current_date - interval '1 month')::date;
  else
    v_retention_cutoff := date_trunc('month', current_date - interval '2 month')::date;
  end if;

  if p_start_date < v_retention_cutoff then
    raise exception 'التاريخ المختار خارج نطاق البيانات المحفوظة (أقدم تاريخ متاح هو %)', v_retention_cutoff;
  end if;

  v_eff_start := greatest(p_start_date, coalesce(v_emp.hire_date, v_emp.created_at::date));
  if v_emp.status in ('archived', 'terminated', 'suspended') then
    v_eff_end := least(p_end_date, coalesce(v_emp.termination_date, v_emp.suspension_start, v_emp.status_changed_at::date, v_emp.updated_at::date));
  else
    v_eff_end := p_end_date;
  end if;

  v_daily_rate := round(v_emp.basic_salary / 30.0, 2);

  if v_eff_start <= v_eff_end then
    select
      count(*) filter (where status = 'present'),
      count(*) filter (where status = 'absent'),
      count(*) filter (where status = 'on_leave')
    into v_present_days, v_absent_days, v_leave_days
    from public.attendance_records
    where employee_id = p_employee_id
      and record_date between v_eff_start and v_eff_end;

    select count(distinct d::date) into v_leave_ded_days
    from public.leave_requests lr
    cross join lateral generate_series(lr.start_date, lr.end_date, interval '1 day') as d
    where lr.employee_id = p_employee_id
      and lr.status = 'approved'
      and lr.decision_type = 'with_deduction'
      and d::date between v_eff_start and v_eff_end;

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

    select coalesce(jsonb_agg(
      jsonb_build_object(
        'date',            d::date,
        'status',          coalesce(ar.status, 'unrecorded'),
        'status_label',    case
          when ar.status = 'present'  then 'حاضر'
          when ar.status = 'absent'   then 'غائب'
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
  -- صافي الراتب = (أيام الحضور × معدل اليوم) - الخصومات + المكافآت
  -- الإجازة بدون خصم تُسجَّل حضوراً (present) | الإجازة بخصم = خصم 1 يوم | الغياب = خصم 2 يوم
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
      'requested_start', p_start_date,
      'requested_end',   p_end_date,
      'effective_start', v_eff_start,
      'effective_end',   v_eff_end,
      'is_in_range',     (v_eff_start <= v_eff_end)
    ),
    'summary', jsonb_build_object(
      'present_days',              v_present_days,
      'absent_days',               v_absent_days,
      'leave_days',                v_leave_days,
      'leave_with_deduction_days', v_leave_ded_days,
      'absence_deduction',         v_absence_ded,
      'leave_deduction',           v_leave_ded,
      'manual_deductions',         v_manual_ded,
      'total_deductions',          v_total_ded,
      'total_bonuses',             v_total_bonuses,
      'net_salary',                v_net_salary
    ),
    'daily_breakdown', v_daily_records,
    'extra_records',   v_extra_records
  );
end;
$$;

revoke all on function public.hr_get_employee_report(uuid, date, date) from public, anon;
grant execute on function public.hr_get_employee_report(uuid, date, date) to authenticated;
