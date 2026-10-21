-- 020_hr_employee_actions.sql
-- إضافة وظيفة لتحديث حالة الموظفين (أرشفة، إيقاف، فصل، تنشيط)

begin;

create or replace function public.hr_update_employee_status(
  p_id uuid,
  p_status text,
  p_reason text default null,
  p_suspension_end date default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_emp_id uuid;
begin
  if not public._has_role('hr') then
    raise exception using errcode = '42501', message = 'غير مصرح لك بتعديل حالة الموظفين';
  end if;

  if p_status not in ('active', 'suspended', 'terminated', 'archived') then
    raise exception 'حالة غير صالحة';
  end if;

  select id into v_emp_id from public.employees where id = p_id;
  if v_emp_id is null then
    raise exception 'الموظف غير موجود';
  end if;

  update public.employees
  set 
    status = p_status,
    status_reason = coalesce(p_reason, status_reason),
    status_changed_at = now(),
    status_changed_by = auth.uid(),
    suspension_start = case when p_status = 'suspended' then current_date else null end,
    suspension_end = case when p_status = 'suspended' then p_suspension_end else null end,
    termination_date = case when p_status = 'terminated' then current_date else null end,
    updated_at = now()
  where id = p_id;

  return public._hr_employee_json(p_id);
end;
$$;

revoke all on function public.hr_update_employee_status(uuid, text, text, date) from public, anon;
grant execute on function public.hr_update_employee_status(uuid, text, text, date) to authenticated;

commit;
