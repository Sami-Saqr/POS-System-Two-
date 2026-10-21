begin;

-- ───────────────────────── hr_update_employee ─────────────────────────
create or replace function public.hr_update_employee(
  p_id uuid,
  p jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_name      text := btrim(coalesce(p->>'full_name', ''));
  v_role      text := nullif(btrim(coalesce(p->>'job_role', '')), '');
  v_branch_id uuid;
  v_birth     date;
  v_hire      date;
  v_basic     numeric;
  v_allow     numeric;
  v_trans     numeric;
  v_phone     text := nullif(btrim(coalesce(p->>'phone', '')), '');
  v_qual      text := nullif(btrim(coalesce(p->>'qualification', '')), '');
  v_rank      text := nullif(btrim(coalesce(p->>'job_rank', '')), '');
  v_notes     text := nullif(btrim(coalesce(p->>'notes', '')), '');
begin
  if not public._has_role('hr') then
    raise exception using errcode = '42501', message = 'غير مصرح لك بتعديل بيانات الموظفين';
  end if;

  begin
    v_branch_id := nullif(p->>'branch_id', '')::uuid;
    v_birth     := nullif(p->>'birth_date', '')::date;
    v_hire      := nullif(p->>'hire_date', '')::date;
    v_basic     := coalesce(nullif(p->>'basic_salary', '')::numeric, 0);
    v_allow     := coalesce(nullif(p->>'allowances', '')::numeric, 0);
    v_trans     := coalesce(nullif(p->>'transport_allowance', '')::numeric, 0);
  exception when others then
    raise exception 'بيانات غير صحيحة';
  end;

  if v_name = '' then raise exception 'اسم الموظف إلزامي'; end if;

  if v_role is not null and v_role not in (
    'cashier', 'accountant', 'hr', 'worker', 'driver',
    'storekeeper', 'chef', 'kitchen_worker', 'branch_manager'
  ) then
    raise exception 'الدور الوظيفي غير صحيح';
  end if;

  update public.employees
  set 
    full_name = coalesce(nullif(v_name, ''), full_name),
    job_role = coalesce(v_role, job_role),
    branch_id = v_branch_id,
    birth_date = v_birth,
    hire_date = v_hire,
    basic_salary = v_basic,
    allowances = v_allow,
    transport_allowance = v_trans,
    phone = v_phone,
    qualification = v_qual,
    job_rank = v_rank,
    notes = v_notes,
    updated_at = now()
  where id = p_id;

  return public._hr_employee_json(p_id);
end;
$$;

revoke all on function public.hr_update_employee(uuid, jsonb) from public, anon;
grant execute on function public.hr_update_employee(uuid, jsonb) to authenticated;

-- ───────────────────────── hr_delete_employee ─────────────────────────
create or replace function public.hr_delete_employee(
  p_id uuid
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public._has_role('hr') then
    raise exception using errcode = '42501', message = 'غير مصرح لك بحذف الموظفين';
  end if;

  -- Archive instead of hard delete to preserve history
  update public.employees
  set status = 'archived',
      updated_at = now()
  where id = p_id;

  return jsonb_build_object('ok', true, 'id', p_id);
end;
$$;

revoke all on function public.hr_delete_employee(uuid) from public, anon;
grant execute on function public.hr_delete_employee(uuid) to authenticated;

commit;
