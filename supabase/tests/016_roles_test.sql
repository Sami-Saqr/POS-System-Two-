-- =============================================================================
-- 016_roles_test.sql
-- اختبار الدور hr ورصيد افتتاح وردية الكاشير
-- لا يُبقي أي بيانات: begin ... rollback
-- =============================================================================

begin;

do $$
declare
  v_user_id uuid;
  v_branch public.branches%rowtype;
  v_client_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_result jsonb;
  v_opening_cash numeric;
  v_cash_sales numeric;
  v_expected_cash numeric;
  v_counted_cash numeric;
  v_difference numeric;
  v_invoices_count integer;
  v_negative_rejected boolean := false;
begin
  -- الإعداد يتم بدور postgres، قبل التحول إلى authenticated.
  select id
  into v_user_id
  from auth.users
  where email = 'samerashour@dietking.com';

  assert v_user_id is not null,
    'يتطلب الاختبار حساب samerashour@dietking.com في auth.users';

  select *
  into v_branch
  from public.branches
  where deleted_at is null
  limit 1;

  assert v_branch.id is not null,
    'يتطلب الاختبار فرعاً غير محذوف واحداً على الأقل';

  insert into public.profiles (id, full_name, role, branch_id, is_active)
  values (v_user_id, 'مستخدم اختبار 016', 'owner', v_branch.id, true)
  on conflict (id) do update
    set full_name = excluded.full_name,
        role = excluded.role,
        branch_id = excluded.branch_id,
        is_active = excluded.is_active;

  insert into public.sales (
    client_id, invoice_number, branch_id, branch_name, branch_code,
    cashier_id, cashier_name, payment_method, subtotal, total,
    status, session_id
  ) values (
    v_client_id,
    format('TST016-%s', replace(v_client_id::text, '-', '')),
    v_branch.id, v_branch.name, v_branch.code,
    v_user_id, 'مستخدم اختبار 016', 'cash', 50, 50,
    'completed', v_session_id
  );

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_user_id),
    true
  );
  set local role authenticated;

  v_result := public.close_shift(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', v_session_id,
    'branch_id', v_branch.id,
    'shift', 'test-016',
    'opened_at', (now() - interval '1 hour')::text,
    'closed_at', now()::text,
    'counted_cash', 150,
    'opening_cash', 100,
    'client_invoices_count', 1
  ));

  reset role;

  select opening_cash, cash_sales, expected_cash, counted_cash, difference,
         invoices_count
  into v_opening_cash, v_cash_sales, v_expected_cash, v_counted_cash,
       v_difference, v_invoices_count
  from public.shift_closings
  where session_id = v_session_id;

  assert v_opening_cash = 100,
    format('opening_cash يجب أن يساوي 100؛ وُجد %s', v_opening_cash);
  assert v_cash_sales = 50,
    format('cash_sales يجب أن يساوي 50؛ وُجد %s', v_cash_sales);
  assert v_expected_cash = 150,
    format('expected_cash يجب أن يساوي 150؛ وُجد %s', v_expected_cash);
  assert v_counted_cash = 150,
    format('counted_cash يجب أن يساوي 150؛ وُجد %s', v_counted_cash);
  assert v_difference = 0,
    format('difference يجب أن يساوي 0؛ وُجد %s', v_difference);
  assert v_invoices_count = 1,
    format('invoices_count يجب أن يساوي 1؛ وُجد %s', v_invoices_count);
  assert (v_result->>'difference')::numeric = 0,
    format('رد close_shift يجب أن يعيد difference = 0؛ وُجد %s', v_result->>'difference');

  set local role authenticated;
  begin
    perform public.close_shift(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'session_id', gen_random_uuid(),
      'branch_id', v_branch.id,
      'shift', 'test-016-negative',
      'opened_at', (now() - interval '1 hour')::text,
      'closed_at', now()::text,
      'counted_cash', 0,
      'opening_cash', -1,
      'client_invoices_count', 0
    ));
  exception
    when others then
      v_negative_rejected := true;
      assert sqlerrm = 'الرصيد الافتتاحي غير صحيح',
        format('رسالة الرصيد السالب غير متوقعة: %s', sqlerrm);
  end;
  reset role;

  assert v_negative_rejected,
    'يجب أن يفشل close_shift عند إرسال opening_cash سالب';

  -- اختبار مستقل لقبول الدور الجديد بعد اختبارات الإقفال.
  update public.profiles
  set role = 'hr'
  where id = v_user_id;

  assert exists (
    select 1
    from public.profiles
    where id = v_user_id
      and role = 'hr'
  ), 'يجب قبول الدور hr في profiles';
end;
$$;

rollback;
