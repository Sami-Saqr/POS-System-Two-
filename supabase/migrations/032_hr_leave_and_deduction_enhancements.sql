-- =============================================================================
-- 032_hr_leave_and_deduction_enhancements.sql
-- 1) تحديث hr_create_leave_request لدعم تقديم الإجازات من HR والمدير واعتمادها المباشر
-- 2) تحديث hr_create_deduction_bonus لدعم طلبات وتطبيقات الخصم والإضافات من HR
-- 3) ضمان صلاحيات hr_add_direct_leave و hr_add_direct_deduction_bonus
-- =============================================================================

-- ─── § 1  تحديث دالة hr_create_leave_request ─────────────────────────────────

create or replace function public.hr_create_leave_request(p jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_emp_id        uuid;
  v_start         date;
  v_end           date;
  v_reason        text;
  v_context       text;
  v_id            uuid;
  v_dec_type      text;
  v_is_direct     boolean;
  v_is_paid       boolean;
  v_is_privileged boolean;
begin
  begin
    v_emp_id  := (p->>'employee_id')::uuid;
    v_start   := (p->>'start_date')::date;
    v_end     := (p->>'end_date')::date;
  exception when others then
    raise exception 'بيانات غير صحيحة';
  end;

  v_reason    := btrim(coalesce(p->>'reason',''));
  v_context   := coalesce(p->>'requested_from','cashier');
  v_dec_type  := p->>'decision_type';
  v_is_direct := coalesce((p->>'is_direct')::boolean, (p->>'status' = 'approved'), false);

  if v_reason = '' then
    raise exception 'سبب الإجازة إلزامي';
  end if;

  if v_end < v_start then
    raise exception 'تاريخ انتهاء الإجازة قبل بدايتها';
  end if;

  -- التحقق من صلاحيات HR / Owner
  v_is_privileged := (public._has_role('hr') or public._has_role('owner') or v_context in ('hr', 'admin'));

  -- للمستخدم العادي (كاشير/مخزون) فقط: الإجازة يجب أن تكون قبلها بيوم
  if not v_is_privileged then
    if v_start <= current_date then
      raise exception 'يجب تقديم طلب الإجازة قبل يوم واحد على الأقل';
    end if;
  end if;

  if v_context not in ('cashier','inventory','hr','admin') then
    raise exception 'سياق غير صحيح';
  end if;

  -- إذا طُلِب اعتماد مباشر وكان لدى المستخدم صلاحية HR أو المالك
  if v_is_direct and (public._has_role('hr') or public._has_role('owner')) then
    v_is_paid := coalesce(v_dec_type != 'with_deduction', true);

    insert into public.leave_requests (
      employee_id, requested_from, start_date, end_date, reason,
      status, decision_type, decided_by, decided_at, is_paid, leave_type, created_by
    ) values (
      v_emp_id, v_context, v_start, v_end, v_reason,
      'approved', coalesce(v_dec_type, 'without_deduction'), auth.uid(), now(),
      v_is_paid, case when v_is_paid then 'paid' else 'unpaid' end, auth.uid()
    ) returning id into v_id;

    -- تسجيل أيام الإجازة في attendance_records تلقائياً
    insert into public.attendance_records (
      employee_id, record_date, status, recorded_by, recorded_from, notes
    )
    select 
      v_emp_id, d::date, 'on_leave', auth.uid(), 'hr',
      case when v_is_paid then 'إجازة معتمدة مدفوعة: ' || v_reason else 'إجازة معتمدة بخصم: ' || v_reason end
    from generate_series(v_start, v_end, interval '1 day') as d
    on conflict (employee_id, record_date) do update
      set status = 'on_leave',
          notes = excluded.notes,
          recorded_by = excluded.recorded_by,
          recorded_from = excluded.recorded_from,
          updated_at = now();

    return jsonb_build_object('id', v_id, 'status', 'approved');
  else
    insert into public.leave_requests (
      employee_id, requested_from, start_date, end_date, reason,
      decision_type, created_by
    ) values (
      v_emp_id, v_context, v_start, v_end, v_reason,
      v_dec_type, auth.uid()
    ) returning id into v_id;

    return jsonb_build_object('id', v_id, 'status', 'pending');
  end if;
end;
$$;

revoke all on function public.hr_create_leave_request(jsonb) from public, anon;
grant execute on function public.hr_create_leave_request(jsonb) to authenticated;


-- ─── § 2  تحديث دالة hr_create_deduction_bonus ───────────────────────────────

create or replace function public.hr_create_deduction_bonus(p jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_emp_id     uuid;
  v_type       text;
  v_amt_type   text;
  v_cash       numeric;
  v_days       numeric;
  v_final_cash numeric;
  v_notes      text;
  v_context    text;
  v_id         uuid;
  v_salary     numeric;
  v_daily      numeric;
  v_is_direct  boolean;
begin
  begin
    v_emp_id     := (p->>'employee_id')::uuid;
    v_cash       := nullif(p->>'cash_amount','')::numeric;
    v_days       := nullif(p->>'days_amount','')::numeric;
    v_final_cash := nullif(p->>'final_cash_amount','')::numeric;
  exception when others then
    raise exception 'بيانات غير صحيحة';
  end;

  v_type      := p->>'type';
  v_amt_type  := p->>'amount_type';
  v_notes     := btrim(coalesce(p->>'notes',''));
  v_context   := coalesce(p->>'requested_from','cashier');
  v_is_direct := coalesce((p->>'is_direct')::boolean, (p->>'status' = 'approved'), false);

  if v_type not in ('deduction','bonus') then raise exception 'النوع غير صحيح'; end if;
  if v_amt_type not in ('cash','days') then raise exception 'نوع المبلغ غير صحيح'; end if;
  if v_notes = '' then raise exception 'الملاحظة إلزامية للخصم/المكافأة'; end if;
  if v_amt_type = 'cash' and (v_cash is null or v_cash <= 0) then
    raise exception 'أدخل مبلغاً صحيحاً';
  end if;
  if v_amt_type = 'days' and (v_days is null or v_days <= 0) then
    raise exception 'أدخل عدد أيام صحيحاً';
  end if;

  if v_context not in ('cashier','inventory','hr','admin') then
    raise exception 'سياق غير صحيح';
  end if;

  -- إذا طُلِب اعتماد مباشر وكان لدى المستخدم صلاحية HR أو المالك
  if v_is_direct and (public._has_role('hr') or public._has_role('owner')) then
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
      v_emp_id, v_context, v_type, v_amt_type, v_cash, v_days,
      v_notes, 'approved', auth.uid(), now(), v_final_cash, auth.uid()
    ) returning id into v_id;

    return jsonb_build_object('id', v_id, 'status', 'approved');
  else
    insert into public.deduction_bonus_requests (
      employee_id, requested_from, type, amount_type, cash_amount, days_amount, notes, created_by
    ) values (
      v_emp_id, v_context, v_type, v_amt_type, v_cash, v_days, v_notes, auth.uid()
    ) returning id into v_id;

    return jsonb_build_object('id', v_id, 'status', 'pending');
  end if;
end;
$$;

revoke all on function public.hr_create_deduction_bonus(jsonb) from public, anon;
grant execute on function public.hr_create_deduction_bonus(jsonb) to authenticated;


-- ─── § 3  منح الصلاحيات لدوال الإجازات والخصومات المباشرة ─────────────────────

grant execute on function public.hr_add_direct_leave(jsonb) to authenticated;
grant execute on function public.hr_add_direct_deduction_bonus(jsonb) to authenticated;
