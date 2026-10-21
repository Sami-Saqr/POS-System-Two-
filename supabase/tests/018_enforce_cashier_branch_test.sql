-- =============================================================================
-- 018_enforce_cashier_branch_test.sql
-- يتحقق من عزل فرع الكاشير. لا يُبقي أي بيانات: begin ... rollback.
-- =============================================================================

begin;

do $$
declare
  v_cashier_a uuid;
  v_accountant uuid;
  v_owner uuid;
  v_branch_a public.branches%rowtype;
  v_branch_b public.branches%rowtype;
  v_product_id uuid;
  v_item_id uuid;
  v_order_id uuid;
  v_order_version bigint;
  v_owner_order_id uuid;
  v_result jsonb;
  v_rejected boolean;
begin
  -- الإعداد يتم قبل التحول إلى authenticated، ولا ينشئ الاختبار مستخدمي auth.
  select id into v_cashier_a
  from auth.users
  order by id
  limit 1;

  select id into v_accountant
  from auth.users
  order by id
  offset 1
  limit 1;

  select id into v_owner
  from auth.users
  order by id
  offset 2
  limit 1;

  assert v_cashier_a is not null
     and v_accountant is not null
     and v_owner is not null,
    'يتطلب الاختبار ثلاثة مستخدمين على الأقل في auth.users';

  select * into v_branch_a
  from public.branches
  where deleted_at is null
    and is_active
  order by id
  limit 1;

  select * into v_branch_b
  from public.branches
  where deleted_at is null
    and is_active
  order by id
  offset 1
  limit 1;

  assert v_branch_a.id is not null and v_branch_b.id is not null,
    'يتطلب الاختبار فرعين نشطين غير محذوفين على الأقل';

  select id into v_product_id
  from public.products
  order by id
  limit 1;

  select id into v_item_id
  from public.inventory_items
  order by id
  limit 1;

  assert v_product_id is not null,
    'يتطلب اختبار create_sale منتجاً واحداً على الأقل';
  assert v_item_id is not null,
    'يتطلب اختبار create_branch_order صنف مخزون واحداً على الأقل';

  insert into public.profiles (id, role, branch_id, is_active)
  values
    (v_cashier_a, 'cashier', v_branch_a.id, true),
    (v_accountant, 'accountant', null, true),
    (v_owner, 'owner', null, true)
  on conflict (id) do update
  set role = excluded.role,
      branch_id = excluded.branch_id,
      is_active = excluded.is_active;

  -- الكاشير A يبيع على الفرع A بنجاح.
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_result := public.create_sale(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', gen_random_uuid(),
    'branch_id', v_branch_a.id,
    'payment_method', 'cash',
    'items', jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'qty', 1,
      'unit_price', 1
    ))
  ));
  assert coalesce((v_result->>'already_exists')::boolean, false) = false,
    format('يجب أن تنجح مبيعات الكاشير على فرعه؛ الرد: %s', v_result);

  -- لا يستطيع الكاشير A البيع على الفرع B.
  v_rejected := false;
  begin
    perform public.create_sale(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'session_id', gen_random_uuid(),
      'branch_id', v_branch_b.id,
      'items', jsonb_build_array(jsonb_build_object(
        'product_id', v_product_id,
        'qty', 1,
        'unit_price', 1
      ))
    ));
  exception
    when others then
      v_rejected := true;
      assert sqlerrm = 'هذا الحساب غير مصرح له بالعمل على هذا الفرع',
        format('رسالة رفض فرع B غير متوقعة: %s', sqlerrm);
  end;
  assert v_rejected, 'يجب رفض بيع الكاشير على فرع مختلف';

  reset role;

  -- كاشير بلا branch_id يُرفض قبل قبول أي بيع.
  update public.profiles
  set branch_id = null
  where id = v_cashier_a;

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_rejected := false;
  begin
    perform public.create_sale(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'session_id', gen_random_uuid(),
      'branch_id', v_branch_a.id,
      'items', jsonb_build_array(jsonb_build_object(
        'product_id', v_product_id,
        'qty', 1,
        'unit_price', 1
      ))
    ));
  exception
    when others then
      v_rejected := true;
      assert sqlerrm = 'حسابك غير مرتبط بفرع',
        format('رسالة الكاشير بلا فرع غير متوقعة: %s', sqlerrm);
  end;
  assert v_rejected, 'يجب رفض الكاشير الذي لا يرتبط بفرع';

  reset role;

  update public.profiles
  set branch_id = v_branch_a.id
  where id = v_cashier_a;

  -- المالك يعمل على الفرع B بنجاح.
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_owner),
    true
  );
  set local role authenticated;

  v_result := public.create_sale(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', gen_random_uuid(),
    'branch_id', v_branch_b.id,
    'payment_method', 'cash',
    'items', jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'qty', 1,
      'unit_price', 1
    ))
  ));
  assert coalesce((v_result->>'already_exists')::boolean, false) = false,
    format('يجب أن يبيع المالك على أي فرع؛ الرد: %s', v_result);

  reset role;

  -- create_expense: كاشير A ينجح على A ويُرفض على B، والمالك ينجح على B.
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_result := public.create_expense(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', gen_random_uuid(),
    'branch_id', v_branch_a.id,
    'category', 'اختبار',
    'amount', 1,
    'vat_amount', 0
  ));
  assert (v_result->>'id') is not null,
    format('يجب أن ينجح مصروف الكاشير على فرعه؛ الرد: %s', v_result);

  v_rejected := false;
  begin
    perform public.create_expense(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'session_id', gen_random_uuid(),
      'branch_id', v_branch_b.id,
      'category', 'اختبار',
      'amount', 1
    ));
  exception
    when others then
      v_rejected := true;
      assert sqlerrm = 'هذا الحساب غير مصرح له بالعمل على هذا الفرع',
        format('رسالة رفض مصروف الفرع B غير متوقعة: %s', sqlerrm);
  end;
  assert v_rejected, 'يجب رفض مصروف الكاشير على فرع مختلف';

  reset role;

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_owner),
    true
  );
  set local role authenticated;

  v_result := public.create_expense(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', gen_random_uuid(),
    'branch_id', v_branch_b.id,
    'category', 'اختبار',
    'amount', 1,
    'vat_amount', 0
  ));
  assert (v_result->>'id') is not null,
    format('يجب أن يسجل المالك مصروفاً على أي فرع؛ الرد: %s', v_result);

  reset role;

  -- المحاسب يسجل مصروفاً على فرع من دون ربط حسابه بفرع.
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_accountant),
    true
  );
  set local role authenticated;

  v_result := public.create_expense(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', gen_random_uuid(),
    'branch_id', v_branch_a.id,
    'category', 'اختبار محاسب',
    'amount', 1,
    'vat_amount', 0
  ));
  assert (v_result->>'id') is not null,
    format('يجب أن يسجل المحاسب مصروفاً على أي فرع؛ الرد: %s', v_result);

  reset role;

  -- close_shift: كاشير A ينجح على A ويُرفض على B، والمالك ينجح على B.
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_result := public.close_shift(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', gen_random_uuid(),
    'branch_id', v_branch_a.id,
    'shift', 'test-018-a',
    'opened_at', (now() - interval '1 hour')::text,
    'closed_at', now()::text,
    'counted_cash', 0,
    'opening_cash', 0,
    'client_invoices_count', 0
  ));
  assert (v_result->>'id') is not null,
    format('يجب أن ينجح إقفال وردية الكاشير على فرعه؛ الرد: %s', v_result);

  v_rejected := false;
  begin
    perform public.close_shift(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'session_id', gen_random_uuid(),
      'branch_id', v_branch_b.id,
      'shift', 'test-018-b',
      'opened_at', (now() - interval '1 hour')::text,
      'closed_at', now()::text,
      'counted_cash', 0,
      'opening_cash', 0,
      'client_invoices_count', 0
    ));
  exception
    when others then
      v_rejected := true;
      assert sqlerrm = 'هذا الحساب غير مصرح له بالعمل على هذا الفرع',
        format('رسالة رفض إقفال الفرع B غير متوقعة: %s', sqlerrm);
  end;
  assert v_rejected, 'يجب رفض إقفال الكاشير على فرع مختلف';

  reset role;

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_owner),
    true
  );
  set local role authenticated;

  v_result := public.close_shift(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'session_id', gen_random_uuid(),
    'branch_id', v_branch_b.id,
    'shift', 'test-018-owner',
    'opened_at', (now() - interval '1 hour')::text,
    'closed_at', now()::text,
    'counted_cash', 0,
    'opening_cash', 0,
    'client_invoices_count', 0
  ));
  assert (v_result->>'id') is not null,
    format('يجب أن يغلق المالك وردية على أي فرع؛ الرد: %s', v_result);

  reset role;

  -- create_branch_order: كاشير A ينجح على A ويُرفض على B، والمالك ينجح على B.
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_result := public.create_branch_order(
    gen_random_uuid(),
    v_branch_a.id,
    'اختبار 018',
    jsonb_build_array(jsonb_build_object(
      'item_id', v_item_id,
      'qty_requested', 1
    ))
  );
  assert (v_result->'doc'->>'id') is not null,
    format('يجب أن تنجح طلبية الكاشير على فرعه؛ الرد: %s', v_result);
  v_order_id := (v_result->'doc'->>'id')::uuid;

  v_rejected := false;
  begin
    perform public.create_branch_order(
      gen_random_uuid(),
      v_branch_b.id,
      'اختبار رفض 018',
      jsonb_build_array(jsonb_build_object(
        'item_id', v_item_id,
        'qty_requested', 1
      ))
    );
  exception
    when others then
      v_rejected := true;
      assert sqlerrm = 'هذا الحساب غير مصرح له بالعمل على هذا الفرع',
        format('رسالة رفض طلبية الفرع B غير متوقعة: %s', sqlerrm);
  end;
  assert v_rejected, 'يجب رفض طلبية الكاشير على فرع مختلف';

  reset role;

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_owner),
    true
  );
  set local role authenticated;

  v_result := public.create_branch_order(
    gen_random_uuid(),
    v_branch_b.id,
    'اختبار مالك 018',
    jsonb_build_array(jsonb_build_object(
      'item_id', v_item_id,
      'qty_requested', 1
    ))
  );
  assert (v_result->'doc'->>'id') is not null,
    format('يجب أن ينشئ المالك طلبية على أي فرع؛ الرد: %s', v_result);
  v_owner_order_id := (v_result->'doc'->>'id')::uuid;

  reset role;

  -- update_branch_order: الكاشير يعدل طلب فرعه بنجاح.
  select version into v_order_version
  from public.branch_orders
  where id = v_order_id;

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_result := public.update_branch_order(
    v_order_id,
    v_order_version,
    'تعديل اختبار 018',
    jsonb_build_array(jsonb_build_object(
      'item_id', v_item_id,
      'qty_requested', 1
    ))
  );
  assert (v_result->'doc'->>'id')::uuid = v_order_id,
    format('يجب أن يعدل الكاشير طلب فرعه؛ الرد: %s', v_result);

  reset role;

  -- receive_branch_order: الاستلام لطلب معتمد من فرع الكاشير ينجح.
  update public.branch_orders
  set status = 'approved'
  where id = v_order_id;

  select version into v_order_version
  from public.branch_orders
  where id = v_order_id;

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_result := public.receive_branch_order(
    gen_random_uuid(),
    v_order_id,
    v_order_version
  );
  assert v_result->'doc'->>'status' = 'received',
    format('يجب أن يستلم الكاشير طلب فرعه؛ الرد: %s', v_result);

  reset role;

  -- cancel_branch_order: لا يستطيع الكاشير إلغاء طلب فرع مختلف.
  select version into v_order_version
  from public.branch_orders
  where id = v_owner_order_id;

  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_a),
    true
  );
  set local role authenticated;

  v_rejected := false;
  begin
    perform public.cancel_branch_order(v_owner_order_id, v_order_version);
  exception
    when others then
      v_rejected := true;
      assert sqlerrm = 'هذا الحساب غير مصرح له بالعمل على هذا الفرع',
        format('رسالة رفض إلغاء طلب الفرع B غير متوقعة: %s', sqlerrm);
  end;
  assert v_rejected, 'يجب رفض إلغاء الكاشير لطلب فرع مختلف';

  reset role;
end;
$$;

rollback;
