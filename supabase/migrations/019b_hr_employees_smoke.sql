-- 019b_hr_employees_smoke.sql
begin;

do $$
declare
  v_hr_uid uuid;
  v_cashier_uid uuid;
  v_branch_id uuid;
  v_client_id uuid := gen_random_uuid();
  v_res jsonb;
begin
  select id into v_hr_uid from auth.users where email = 'hr1@dietking.com';
  select id into v_cashier_uid from auth.users where email = 'cashier1@dietking.com';
  select id into v_branch_id from public.branches where is_active = true limit 1;

  if v_hr_uid is null or v_cashier_uid is null then
    raise notice 'Skipping test: Missing test users';
    return;
  end if;

  -- Test HR role
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', format('{"role":"authenticated", "sub":"%s"}', v_hr_uid), true);

  -- Create Employee (Cashier)
  v_res := public.hr_create_employee(jsonb_build_object(
    'client_id', v_client_id,
    'full_name', 'تجربة كاشير',
    'job_role', 'cashier',
    'branch_id', v_branch_id
  ));
  
  if v_res->>'id' is null then raise exception 'Failed to create employee'; end if;

  -- Idempotency Test
  v_res := public.hr_create_employee(jsonb_build_object(
    'client_id', v_client_id,
    'full_name', 'تجربة كاشير',
    'job_role', 'cashier',
    'branch_id', v_branch_id
  ));

  -- Test Cashier without branch
  begin
    perform public.hr_create_employee(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'full_name', 'تجربة كاشير 2',
      'job_role', 'cashier'
    ));
    raise exception 'Should fail without branch for cashier';
  exception when others then
    if sqlerrm not like '%يجب تحديد الفرع%' then raise exception 'Wrong error: %', sqlerrm; end if;
  end;

  -- Test Cashier user denied
  perform set_config('request.jwt.claims', format('{"role":"authenticated", "sub":"%s"}', v_cashier_uid), true);
  begin
    perform public.hr_list_employees();
    raise exception 'Should deny non-HR';
  exception when others then
    if sqlerrm not like '%غير مصرح%' then raise exception 'Wrong error: %', sqlerrm; end if;
  end;

  raise notice 'All HR tests passed successfully!';
end;
$$;

rollback;

-- Anon privilege check
select has_function_privilege('anon', 'public.hr_list_employees(text, text, text, uuid, boolean, int, int)', 'execute') as anon_has_hr_list_employees;
