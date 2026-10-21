-- =============================================================================
-- 99_smoke_test.sql
-- سيناريو اختبار شامل داخل begin ... rollback
-- يحاكي مستخدماً حقيقياً ويختبر كل العمليات الأساسية
-- يتحقق بـ ASSERT أن الأرصدة تساوي مجموع الحركات
-- =============================================================================
-- تشغيل: انسخ كل هذا الملف في SQL Editor وشغّله
-- النتيجة المتوقعة: "ROLLBACK" في النهاية (لا يُغيَّر أي شيء في قاعدة البيانات)
-- =============================================================================

begin;

-- =============================================================================
-- § 0 — إعداد: محاكاة مستخدم مسجّل بدور storekeeper
-- =============================================================================

-- ملاحظة: في البيئة الحقيقية يُستبدل هذا بـ auth.uid() الفعلي
-- هنا نستخدم مستخدماً وهمياً لغرض الاختبار

do $$
declare
  -- ─── بيانات الاختبار ───────────────────────────────────────────────────────
  v_test_user_id    uuid := 'a6ed11e3-1bad-4976-999a-6ef6c3099af8'::uuid;
  v_test_branch_id  uuid;
  v_cat_prt_id      uuid;
  v_cat_crb_id      uuid;
  v_unit_kg         text := 'كجم';
  v_item1_id        uuid;
  v_item2_id        uuid;
  v_main_wh_id      uuid;
  v_br_wh_id        uuid;
  v_supply_order_id uuid;
  v_supply_number   text;
  v_supplier_id     uuid;
  v_issue_id        uuid;
  v_batch_id        uuid;
  v_branch_order_id uuid;
  v_stocktake_id    uuid;
  v_result          jsonb;
  v_stock_after_supply  numeric;
  v_stock_after_issue   numeric;
  v_stock_after_branch  numeric;
  v_movements_sum       numeric;
  v_stored_qty          numeric;

begin
  raise notice '=== بداية اختبار الدخان (Smoke Test) ===';

  -- ─── إنشاء فرع اختباري ───────────────────────────────────────────────────
  insert into public.branches (name, phone, code, is_active)
  values ('فرع الاختبار', '0500000000', 'TST', true)
  returning id into v_test_branch_id;

  raise notice 'تم إنشاء فرع الاختبار: %', v_test_branch_id;

  -- ─── إنشاء مستخدم اختباري في profiles ───────────────────────────────────
  -- (في الاختبار الفعلي يجب أن يكون موجوداً في auth.users)
  -- نتجاوز هذا لأن الجداول تعتمد على auth.uid()
  -- الاختبار يُقيّم منطق الدوال بافتراض وجود المستخدم

  -- ─── قراءة البيانات الأساسية ─────────────────────────────────────────────
  select id into v_cat_prt_id from public.inventory_categories where code = 'PRT';
  select id into v_cat_crb_id from public.inventory_categories where code = 'CRB';
  select id into v_main_wh_id from public.warehouses where kind = 'main';

  assert v_cat_prt_id is not null, 'تصنيف PRT يجب أن يكون موجوداً';
  assert v_cat_crb_id is not null, 'تصنيف CRB يجب أن يكون موجوداً';
  assert v_main_wh_id is not null, 'المستودع الرئيسي يجب أن يكون موجوداً';

  raise notice 'تصنيفات الاختبار: PRT=%, CRB=%', v_cat_prt_id, v_cat_crb_id;
  raise notice 'المستودع الرئيسي: %', v_main_wh_id;

  -- ─── إنشاء أصناف اختبارية ────────────────────────────────────────────────
    insert into public.inventory_items (sku, name, category_id, unit_code, min_level, avg_cost, created_by)
  values ('TST-PRT-0001', 'صنف اختبار بروتين', v_cat_prt_id, v_unit_kg, 50, 45.00, v_test_user_id)
  returning id into v_item1_id;

  insert into public.inventory_items (sku, name, category_id, unit_code, min_level, avg_cost, created_by)
  values ('TST-CRB-0001', 'صنف اختبار نشويات', v_cat_crb_id, v_unit_kg, 100, 12.00, v_test_user_id)
  returning id into v_item2_id;
  raise notice 'الأصناف: item1=%, item2=%', v_item1_id, v_item2_id;

  -- ─── اختبار _post_movement مباشرة: رصيد افتتاحي ─────────────────────────
  perform _post_movement(
    v_main_wh_id, v_item1_id, 'opening', 200, 45.00,
    'test', null, 'رصيد افتتاحي للاختبار', v_test_user_id
  );
  perform _post_movement(
    v_main_wh_id, v_item2_id, 'opening', 500, 12.00,
    'test', null, 'رصيد افتتاحي للاختبار', v_test_user_id
  );

  -- تحقق من الرصيد
  select quantity into v_stock_after_supply
  from public.inventory_stock
  where warehouse_id = v_main_wh_id and item_id = v_item1_id;

  assert v_stock_after_supply = 200, 'الرصيد الافتتاحي للصنف 1 يجب أن يكون 200';
  raise notice '✓ الرصيد الافتتاحي: item1=%, item2=تم', v_stock_after_supply;

  -- ─── اختبار الرصيد السالب ────────────────────────────────────────────────
  begin
    perform _post_movement(
      v_main_wh_id, v_item1_id, 'kitchen_issue', -300, 45.00,
      'test', null, 'اختبار الرفض', v_test_user_id
    );
    raise exception 'FAIL: كان يجب رفض الرصيد السالب';
  exception when others then
    assert sqlerrm like '%رصيد غير كافٍ%', 'رسالة الخطأ يجب أن تحتوي على "رصيد غير كافٍ"';
    raise notice '✓ رُفض الرصيد السالب بشكل صحيح';
  end;

  -- ─── إنشاء مورد وطلب توريد ───────────────────────────────────────────────
  insert into public.suppliers (name, phone)
  values ('مورد الاختبار للحوم', '0511111111')
  returning id into v_supplier_id;

  insert into public.supply_orders (
    client_id, number, supplier_id, expected_date, priority, created_by
  ) values (
    gen_random_uuid(),
    'PO-TEST-0001',
    v_supplier_id,
    current_date + interval '3 days',
    'normal',
    v_test_user_id
  )
  returning id into v_supply_order_id;

  insert into public.supply_order_lines (order_id, item_id, qty_requested, unit_cost)
  values
    (v_supply_order_id, v_item1_id, 100, 48.00),
    (v_supply_order_id, v_item2_id, 200, 13.00);

  raise notice '✓ طلب التوريد: %', v_supply_order_id;

  -- محاكاة الموافقة
  update public.supply_orders
  set status = 'approved', reviewed_by = v_test_user_id, reviewed_at = now()
  where id = v_supply_order_id;

  -- استلام مع إضافة للمخزون
  perform _post_movement(
    v_main_wh_id, v_item1_id, 'supply_receipt', 100, 48.00,
    'supply_order', v_supply_order_id, 'استلام اختبار', v_test_user_id
  );
  perform _post_movement(
    v_main_wh_id, v_item2_id, 'supply_receipt', 200, 13.00,
    'supply_order', v_supply_order_id, 'استلام اختبار', v_test_user_id
  );

  update public.supply_orders set status = 'received' where id = v_supply_order_id;

  -- تحقق من avg_cost المحدّث
  select avg_cost into v_stock_after_supply
  from public.inventory_items where id = v_item1_id;

  -- avg_cost = (45×200 + 48×100) / 300 = (9000 + 4800) / 300 = 46
  assert abs(v_stock_after_supply - 46.00) < 0.01,
    'avg_cost يجب أن يكون قريباً من 46.00 — وجد: ' || v_stock_after_supply::text;
  raise notice '✓ avg_cost محدّث: %', v_stock_after_supply;

  -- ─── اختبار صرف المطبخ ───────────────────────────────────────────────────
  insert into public.kitchen_issues (
    client_id, number, chef_name, shift, created_by
  ) values (
    gen_random_uuid(), 'ISSUE-TEST-0001', 'الشيف الاختباري', 'morning', v_test_user_id
  )
  returning id into v_issue_id;

  insert into public.kitchen_issue_lines (issue_id, item_id, qty, unit_cost_snapshot)
  values (v_issue_id, v_item1_id, 50, 46.00);

  perform _post_movement(
    v_main_wh_id, v_item1_id, 'kitchen_issue', -50, 46.00,
    'kitchen_issue', v_issue_id, 'اختبار الصرف', v_test_user_id
  );

  select quantity into v_stock_after_issue
  from public.inventory_stock
  where warehouse_id = v_main_wh_id and item_id = v_item1_id;

  assert v_stock_after_issue = 250, 'الرصيد بعد الصرف يجب أن يكون 250 (200+100-50) — وجد: ' || v_stock_after_issue::text;
  raise notice '✓ الصرف للمطبخ: الرصيد بعد الصرف=%', v_stock_after_issue;

  -- ─── اختبار إنتاج المطبخ ─────────────────────────────────────────────────
  declare
    v_fin_cat_id uuid;
    v_fin_item_id uuid;
    v_fin_sku text;
  begin
    select id into v_fin_cat_id from public.inventory_categories where code = 'FIN';
    v_fin_sku := 'FIN-TST-0001';

    insert into public.inventory_items (sku, name, category_id, unit_code, created_by)
    values (v_fin_sku, 'وجبة اختبار', v_fin_cat_id, 'عبوة', v_test_user_id)
    returning id into v_fin_item_id;

    insert into public.kitchen_batches (
      client_id, number, item_id, quantity, produced_at, finished_at, created_by
    ) values (
      gen_random_uuid(), 'BATCH-TEST-0001', v_fin_item_id, 80,
      now(), now() + interval '2 hours', v_test_user_id
    )
    returning id into v_batch_id;

    perform _post_movement(
      v_main_wh_id, v_fin_item_id, 'kitchen_output', 80, 0,
      'kitchen_batch', v_batch_id, 'إنتاج اختبار', v_test_user_id
    );

    select quantity into v_stock_after_supply
    from public.inventory_stock
    where warehouse_id = v_main_wh_id and item_id = v_fin_item_id;

    assert v_stock_after_supply = 80, 'رصيد المنتج التام يجب أن يكون 80';
    raise notice '✓ إنتاج المطبخ: المنتج التام رصيده=%', v_stock_after_supply;
  end;

  -- ─── اختبار طلب الفرع ────────────────────────────────────────────────────
  v_br_wh_id := _get_branch_warehouse(v_test_branch_id);
  assert v_br_wh_id is not null, 'مستودع الفرع يجب أن يُنشأ تلقائياً';
  raise notice '✓ مستودع الفرع: %', v_br_wh_id;

  insert into public.branch_orders (
    client_id, number, branch_id, created_by
  ) values (
    gen_random_uuid(), 'BO-TST-000001', v_test_branch_id, v_test_user_id
  )
  returning id into v_branch_order_id;

  insert into public.branch_order_lines (order_id, item_id, qty_requested)
  values (v_branch_order_id, v_item1_id, 30);

  -- اعتماد + تحويل
  update public.branch_order_lines
  set qty_approved = 30
  where order_id = v_branch_order_id;

  perform _post_movement(
    v_main_wh_id, v_item1_id, 'branch_transfer_out', -30, 46.00,
    'branch_order', v_branch_order_id, 'تحويل للفرع', v_test_user_id
  );

  perform _post_movement(
    v_br_wh_id, v_item1_id, 'branch_transfer_in', 30, 46.00,
    'branch_order', v_branch_order_id, 'استلام من الرئيسي', v_test_user_id
  );

  update public.branch_orders
  set status = 'approved', decided_by = v_test_user_id, decided_at = now()
  where id = v_branch_order_id;

  -- تحقق من أرصدة الفرع
  select quantity into v_stock_after_branch
  from public.inventory_stock
  where warehouse_id = v_br_wh_id and item_id = v_item1_id;

  assert v_stock_after_branch = 30, 'رصيد الفرع يجب أن يكون 30';

  -- تحقق من الرئيسي بعد التحويل
  select quantity into v_stock_after_branch
  from public.inventory_stock
  where warehouse_id = v_main_wh_id and item_id = v_item1_id;

  assert v_stock_after_branch = 220, 'الرصيد الرئيسي بعد التحويل يجب أن يكون 220 (200+100-50-30)';
  raise notice '✓ طلب الفرع: الرصيد الرئيسي=%, الفرع=30', v_stock_after_branch;

  -- ─── اختبار الجرد ────────────────────────────────────────────────────────
  -- تطبيق جرد يدوي: صنف item2 رصيده 700 (500+200)، المعدود 680، التالف 10
  -- damage حركة: -10 → الرصيد 690
  -- adjust  حركة: 680 - (700 - 10) = 680 - 690 = -10 → الرصيد 680

  insert into public.stocktakes (
    client_id, number, warehouse_id, total_items,
    total_adjust, total_damage, applied_by
  ) values (
    gen_random_uuid(), 'STK-TEST-0001', v_main_wh_id, 1, -10, 10, v_test_user_id
  )
  returning id into v_stocktake_id;

  perform _post_movement(
    v_main_wh_id, v_item2_id, 'damage', -10, 12.00,
    'stocktake', v_stocktake_id, 'تالف في الجرد', v_test_user_id
  );

  perform _post_movement(
    v_main_wh_id, v_item2_id, 'stocktake_adjust', -10, 12.00,
    'stocktake', v_stocktake_id, 'تعديل جرد', v_test_user_id
  );

  insert into public.stocktake_lines (
    stocktake_id, item_id, system_qty, counted_qty, damaged_qty, adjust_qty, unit_cost
  ) values (
    v_stocktake_id, v_item2_id, 700, 680, 10, -10, 12.00
  );

  select quantity into v_stored_qty
  from public.inventory_stock
  where warehouse_id = v_main_wh_id and item_id = v_item2_id;

  assert v_stored_qty = 680, 'رصيد item2 بعد الجرد يجب أن يكون 680';
  raise notice '✓ الجرد: الرصيد بعد التعديل=%', v_stored_qty;

  -- ─── تحقق التدقيق: الأرصدة = مجموع الحركات ──────────────────────────────
  -- item1 في الرئيسي: opening=200 + supply_receipt=100 - kitchen_issue=50 - branch_transfer_out=30 = 220
  select coalesce(sum(qty_delta), 0) into v_movements_sum
  from public.inventory_movements
  where warehouse_id = v_main_wh_id and item_id = v_item1_id;

  select quantity into v_stored_qty
  from public.inventory_stock
  where warehouse_id = v_main_wh_id and item_id = v_item1_id;

  assert abs(v_movements_sum - v_stored_qty) < 0.001,
    format('مجموع حركات item1 (%s) يجب أن يساوي الرصيد المخزن (%s)',
           v_movements_sum, v_stored_qty);
  raise notice '✓ تدقيق item1: مجموع_الحركات=%, الرصيد=%', v_movements_sum, v_stored_qty;

  -- item2 في الرئيسي: opening=500 + supply_receipt=200 - damage=10 - adjust=10 = 680
  select coalesce(sum(qty_delta), 0) into v_movements_sum
  from public.inventory_movements
  where warehouse_id = v_main_wh_id and item_id = v_item2_id;

  select quantity into v_stored_qty
  from public.inventory_stock
  where warehouse_id = v_main_wh_id and item_id = v_item2_id;

  assert abs(v_movements_sum - v_stored_qty) < 0.001,
    format('مجموع حركات item2 (%s) يجب أن يساوي الرصيد المخزن (%s)',
           v_movements_sum, v_stored_qty);
  raise notice '✓ تدقيق item2: مجموع_الحركات=%, الرصيد=%', v_movements_sum, v_stored_qty;

  -- ─── اختبار الإشعارات ────────────────────────────────────────────────────
  perform _notify(
    'low_stock',
    array['accounting', 'warehouse'],
    null,
    'اختبار إشعار نقص المخزون',
    'هذا إشعار تجريبي',
    jsonb_build_object('ref_type', 'inventory_item', 'ref_id', v_item1_id)
  );

  assert exists (
    select 1 from public.notifications
    where kind = 'low_stock' and title like 'اختبار%'
  ), 'الإشعار يجب أن يُسجَّل في جدول notifications';
  raise notice '✓ الإشعارات تعمل بشكل صحيح';

  -- ─── اختبار إدارة إشعار الحد الأدنى ─────────────────────────────────────
  -- item1 الحد الأدنى = 50، الرصيد الحالي = 220 (فوق الحد)
  -- سنخفضه تحت الحد ونتحقق من الإشعار
  perform _post_movement(
    v_main_wh_id, v_item1_id, 'kitchen_issue', -175, 46.00,
    'test', null, 'اختبار عبور الحد الأدنى', v_test_user_id
  );
  -- الرصيد الآن = 220 - 175 = 45 (< 50 = min_level)

  assert exists (
    select 1 from public.inventory_items
    where id = v_item1_id and low_stock_alerted = true
  ), 'يجب أن يكون low_stock_alerted = true';

  assert exists (
    select 1 from public.notifications
    where kind = 'low_stock' and (payload->>'ref_id')::uuid = v_item1_id
  ), 'يجب أن يُرسل إشعار نقص المخزون';
  raise notice '✓ إشعار الحد الأدنى يعمل بشكل صحيح';

  -- ─── اختبار data_versions ────────────────────────────────────────────────
  perform _bump_data_version('inv_catalog');
  perform _bump_data_version('inv_stock');

  assert exists (
    select 1 from public.data_versions where key = 'inv_catalog' and version > 0
  ), 'بصمة inv_catalog يجب أن تكون موجودة';
  raise notice '✓ data_versions تعمل بشكل صحيح';

  raise notice '=== اكتمل اختبار الدخان بنجاح — جميع التأكيدات نجحت ✓ ===';

end;
$$;

-- =============================================================================
-- ROLLBACK — لا يُطبَّق أي تغيير على قاعدة البيانات الحقيقية
-- =============================================================================

rollback;

-- يجب أن ترى "ROLLBACK" هنا — هذا يعني أن الاختبار نجح
-- لو ظهر "ERROR": راجع رسائل الخطأ للمشكلة المحددة
