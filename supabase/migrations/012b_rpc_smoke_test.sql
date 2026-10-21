-- =============================================================================
-- 99b_rpc_smoke_test.sql
-- اختبار تدفق جميع حركات المخزون عبر الـ RPCs بصفتك authenticated
-- =============================================================================

begin;

-- ===========================================================================
-- إعداد بيانات الاختبار (يعمل بصلاحيات postgres - بدون RLS)
-- ===========================================================================
do $$
declare
  v_user_id uuid;
begin
  select id into v_user_id from auth.users limit 1;
  if v_user_id is null then v_user_id := gen_random_uuid(); end if;

  insert into public.profiles (id, role, is_active)
  values (v_user_id, 'owner', true)
  on conflict (id) do update set role = 'owner', is_active = true;

  insert into public.app_settings (key, label, value)
  values ('cashier_admin_password', 'كلمة مرور الإدارة', extensions.crypt('123456', extensions.gen_salt('bf')))
  on conflict (key) do update set value = excluded.value;

  insert into public.suppliers (name) values ('مورد تجريبي') on conflict do nothing;
  insert into public.branches (name, phone, code, is_active)
  values ('الفرع التجريبي', '01000000000', 'TST', true)
  on conflict do nothing;
end;
$$;

-- ===========================================================================
-- الاختبار الفعلي (يعمل بدور authenticated)
-- ===========================================================================
do $$
declare
  v_user_id       uuid;
  v_token         uuid;
  v_cat_id        uuid;
  v_fin_cat_id    uuid;
  v_item_id       uuid;
  v_fin_item_id   uuid;
  v_branch_id     uuid;
  v_supplier_id   uuid;
  v_so_id         uuid;
  v_bo_id         uuid;
  v_res           jsonb;
  v_audit_count   int;
begin
  raise notice '=== بدء اختبار دورة المستندات الشامل ===';

  select id into v_user_id from auth.users limit 1;
  if v_user_id is null then v_user_id := gen_random_uuid(); end if;

  select id into v_supplier_id from public.suppliers where name = 'مورد تجريبي';
  select id into v_branch_id   from public.branches  where name = 'الفرع التجريبي';

  -- إعداد سياق المستخدم (JWT claims فقط — الـ security definer functions لا تحتاج role change)
  perform set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', v_user_id), true);

  -- إصدار تصريح الإدارة
  select (admin_issue_approval('123456', 'inventory_import')->>'token')::uuid into v_token;

  select id into v_cat_id     from public.inventory_categories where kind = 'raw' and is_active = true limit 1;
  select id into v_fin_cat_id from public.inventory_categories where code = 'FIN';

  -- إنشاء صنف تجريبي
  v_res := save_inventory_item(jsonb_build_object(
    'client_id', gen_random_uuid(),
    'approval_token', (admin_issue_approval('123456', 'inventory_item_edit')->>'token')::uuid,
    'name', 'صنف تجريبي خام',
    'category_id', v_cat_id,
    'unit_code', 'كجم',
    'opening_qty', 0
  ));
  v_item_id := (v_res->'item'->>'id')::uuid;

  -- ===========================================================================
  -- 1) دورة طلب التوريد (Supply Order)
  -- ===========================================================================
  v_res := create_supply_order(
    gen_random_uuid(), 'مورد تجريبي', '010', current_date, 'normal', null,
    jsonb_build_array(jsonb_build_object('item_id', v_item_id, 'qty_requested', 100, 'unit_cost', 50))
  );
  v_so_id := (v_res->'doc'->>'id')::uuid;

  -- مراجعة
  perform review_supply_order(v_so_id, (select version from public.supply_orders where id = v_so_id), 'approved', null);

  -- استلام
  perform receive_supply_order(
    gen_random_uuid(), v_so_id, (select version from public.supply_orders where id = v_so_id), null,
    jsonb_build_array(jsonb_build_object(
      'line_id', (select id from public.supply_order_lines where order_id = v_so_id limit 1),
      'qty_received', 100
    ))
  );
  raise notice '- دورة طلب التوريد نجحت.';

  -- ===========================================================================
  -- 2) صرف للمطبخ (Kitchen Issue)
  -- ===========================================================================
  perform create_kitchen_issue(
    gen_random_uuid(), null, 'شيف أحمد', 'morning', null,
    jsonb_build_array(jsonb_build_object('item_id', v_item_id, 'qty', 20))
  );
  raise notice '- صرف المطبخ نجح.';

  -- ===========================================================================
  -- 3) استلام إنتاج (Kitchen Batch)
  -- ===========================================================================
  v_res := create_kitchen_batch(
    gen_random_uuid(), null, 'وجبة تجريبية', 'عبوة', 50, null, now(), now(), null
  );
  v_fin_item_id := (v_res->'doc'->>'item_id')::uuid;
  raise notice '- استلام إنتاج المطبخ (وصنف جديد) نجح.';

  -- ===========================================================================
  -- 4) دورة طلب الفرع (Branch Order)
  -- ===========================================================================
  v_res := create_branch_order(
    gen_random_uuid(), v_branch_id, null,
    jsonb_build_array(
      jsonb_build_object('item_id', v_item_id, 'qty_requested', 10),
      jsonb_build_object('item_id', v_fin_item_id, 'qty_requested', 25)
    )
  );
  v_bo_id := (v_res->'doc'->>'id')::uuid;

  -- تعديل
  perform update_branch_order(
    v_bo_id, (select version from public.branch_orders where id = v_bo_id), 'تم التعديل',
    jsonb_build_array(
      jsonb_build_object('item_id', v_item_id, 'qty_requested', 15),
      jsonb_build_object('item_id', v_fin_item_id, 'qty_requested', 30)
    )
  );

  -- قرار
  perform decide_branch_order(
    v_bo_id, (select version from public.branch_orders where id = v_bo_id), 'approved', null,
    jsonb_build_array(
      jsonb_build_object('line_id', (select id from public.branch_order_lines where order_id = v_bo_id and item_id = v_item_id    limit 1), 'qty_approved', 15),
      jsonb_build_object('line_id', (select id from public.branch_order_lines where order_id = v_bo_id and item_id = v_fin_item_id limit 1), 'qty_approved', 30)
    )
  );
  raise notice '- دورة طلب الفرع نجحت.';

  -- ===========================================================================
  -- 5) الجرد (Stocktake)
  -- ===========================================================================
  select (admin_issue_approval('123456', 'inventory_stocktake')->>'token')::uuid into v_token;
  
  -- Dry Run
  perform apply_stocktake(
    gen_random_uuid(), null, true, null, null,
    jsonb_build_array(jsonb_build_object('sku', (select sku from public.inventory_items where id = v_item_id), 'counted_qty', 60, 'damaged_qty', 5))
  );
  
  -- Real
  perform apply_stocktake(
    gen_random_uuid(), v_token, false, null, null,
    jsonb_build_array(jsonb_build_object('sku', (select sku from public.inventory_items where id = v_item_id), 'counted_qty', 60, 'damaged_qty', 5))
  );
  raise notice '- الجرد نجح.';

  -- ===========================================================================
  -- 6) استيراد أصناف (Import Inventory Items)
  -- ===========================================================================
  select (admin_issue_approval('123456', 'inventory_import')->>'token')::uuid into v_token;

  -- Dry Run
  perform import_inventory_items(
    gen_random_uuid(), null, true,
    jsonb_build_array(jsonb_build_object(
      'name', 'صنف مستورد', 'category_name', (select name from public.inventory_categories where id = v_cat_id),
      'unit_code', 'كجم', 'opening_qty', 10, 'unit_cost', 5
    ))
  );

  -- Real
  perform import_inventory_items(
    gen_random_uuid(), v_token, false,
    jsonb_build_array(jsonb_build_object(
      'name', 'صنف مستورد', 'category_name', (select name from public.inventory_categories where id = v_cat_id),
      'unit_code', 'كجم', 'opening_qty', 10, 'unit_cost', 5
    ))
  );
  raise notice '- الاستيراد نجح.';

  -- ===========================================================================
  -- 7) تدقيق الأرصدة (Audit Stock)
  -- ===========================================================================
  select count(*) into v_audit_count from inventory_audit_stock();
  if v_audit_count > 0 then
    raise exception 'فشل تدقيق الأرصدة: يوجد % أخطاء حسابية في الحركات.', v_audit_count;
  end if;
  raise notice '- تدقيق الأرصدة (Audit) سليم تماماً.';

  raise notice '=== اكتمل اختبار دورة المستندات الشامل بنجاح! ===';
end;
$$;

rollback;
