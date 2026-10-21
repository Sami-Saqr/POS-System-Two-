-- =============================================================================
-- 015_branch_order_receive_test.sql
-- اختبار دورة: create_branch_order ← decide_branch_order ← receive_branch_order
-- يعمل كـ begin ... rollback — لا يغيّر أي بيانات حقيقية
-- النمط مأخوذ من 012b_rpc_smoke_test.sql مع تعديلات الصلاحيات والمستخدمين
-- =============================================================================

begin;

-- =============================================================================
-- § 0 — إعداد بيانات ثابتة (يعمل بصلاحيات postgres / service_role)
-- =============================================================================
do $$
declare
  v_user_id uuid;
begin
  -- استخدم حساب samerashour@dietking.com
  select id into v_user_id from auth.users where email = 'samerashour@dietking.com' limit 1;
  if v_user_id is null then
    -- محاولة ثانية: أي مستخدم موجود في حال لم يتم العثور على الإيميل
    select id into v_user_id from auth.users limit 1;
    if v_user_id is null then
      raise exception 'لا يوجد مستخدم في auth.users — شغّل الاختبار بعد إنشاء مستخدم واحد على الأقل';
    end if;
  end if;

  -- تأكد أن المستخدم له دور owner
  insert into public.profiles (id, role, is_active)
  values (v_user_id, 'owner', true)
  on conflict (id) do update set role = 'owner', is_active = true;

    -- فرع الاختبار (بدون on conflict لأن code مش unique)
  if not exists (select 1 from public.branches where code = '015') then
    insert into public.branches (name, phone, code, is_active)
    values ('فرع اختبار 015', '01000000015', '015', true);
  end if;

  -- تأكد من وجود وحدة 'كجم'
  insert into public.inventory_units (code, label, sort_order)
  values ('كجم', 'كيلوجرام', 1)
  on conflict (code) do nothing;
end;
$$;

-- =============================================================================
-- § 1 — الاختبار الفعلي
-- =============================================================================
do $$
declare
  -- ─── كيانات ──────────────────────────────────────────────────────────────
  v_user_id      uuid;
  v_branch_id    uuid;
  v_cat_id       uuid;
  v_item_id      uuid;    -- طماطم 015
  v_item2_id     uuid;    -- بطاطس 015
  v_main_wh_id   uuid;
  v_bo_id        uuid;
  v_line1_id     uuid;
  v_line2_id     uuid;

  -- ─── نتائج وأرقام ─────────────────────────────────────────────────────────
  v_res          jsonb;
  v_version      bigint;
  v_status       text;
  v_stock_main   numeric;
  v_movements    numeric;
  v_audit_count  int;
  v_branch_whs   int;

  -- ─── client_ids ───────────────────────────────────────────────────────────
  v_cl_create    uuid := gen_random_uuid();
  v_cl_receive   uuid := gen_random_uuid();

begin
  raise notice '=== بدء اختبارات 015_branch_order_receive ===';

  -- ─── 0-أ. قراءة معرّف المستخدم ──────────────────────────────────────────
  select id into v_user_id from auth.users where email = 'samerashour@dietking.com' limit 1;
  if v_user_id is null then select id into v_user_id from auth.users limit 1; end if;

  -- ─── 0-ب. جلب البيانات الأساسية (بصلاحيات postgres قبل set local role) ───
  select id into v_branch_id  from public.branches   where code = '015';
  select id into v_main_wh_id from public.warehouses where kind = 'main';
  select id into v_cat_id
  from   public.inventory_categories
  where  kind = 'raw' and is_active = true
  limit 1;

  assert v_branch_id  is not null, 'فرع 015 يجب أن يكون موجوداً';
  assert v_main_wh_id is not null, 'المستودع الرئيسي يجب أن يكون موجوداً';
  assert v_cat_id     is not null, 'تصنيف raw يجب أن يكون موجوداً';

  -- ─── 0-ج. إنشاء أصناف اختبارية ──────────────────────────────────────────
  insert into public.inventory_items
    (sku, name, category_id, unit_code, min_level, avg_cost,
     branch_orderable, is_active, created_by)
  values
    ('TST015-TOM', 'طماطم اختبار 015', v_cat_id, 'كجم', 10, 5.0,
     true, true, v_user_id)
  returning id into v_item_id;

  insert into public.inventory_items
    (sku, name, category_id, unit_code, min_level, avg_cost,
     branch_orderable, is_active, created_by)
  values
    ('TST015-POT', 'بطاطس اختبار 015', v_cat_id, 'كجم', 5, 3.0,
     true, true, v_user_id)
  returning id into v_item2_id;

  raise notice '✓ الأصناف: طماطم=%, بطاطس=%', v_item_id, v_item2_id;

  -- ─── 0-د. رصيد افتتاحي عبر _post_movement ─────────────────────────────
  -- يجب تفعيل JWT claims حتى يتمكن auth.uid() من قراءة المعرّف
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_user_id),
    true
  );

  -- يتم استدعاء _post_movement بدور postgres (الافتراضي قبل set local role)
  perform _post_movement(
    v_main_wh_id, v_item_id,
    'opening', 200, 5.0,
    'test', null, 'رصيد افتتاحي طماطم 015', v_user_id
  );
  perform _post_movement(
    v_main_wh_id, v_item2_id,
    'opening', 150, 3.0,
    'test', null, 'رصيد افتتاحي بطاطس 015', v_user_id
  );

  -- التحقق (بدون role authenticated، لأن الاستعلام المباشر عن المخزون محمي)
  select quantity into v_stock_main
  from   public.inventory_stock
  where  warehouse_id = v_main_wh_id and item_id = v_item_id;
  assert v_stock_main = 200, format('الرصيد الافتتاحي للطماطم يجب 200 — وجدنا: %', v_stock_main);
  raise notice '✓ الرصيد الافتتاحي: طماطم=200، بطاطس=150';

  -- الانتقال لدور authenticated لتنفيذ دوال الـ API
  set local role authenticated;

  -- =========================================================================
  -- 1. create_branch_order
  -- =========================================================================
  v_res := create_branch_order(
    v_cl_create,
    v_branch_id,
    'طلب اختبار 015',
    jsonb_build_array(
      jsonb_build_object('item_id', v_item_id,  'qty_requested', 100),
      jsonb_build_object('item_id', v_item2_id, 'qty_requested', 50)
    )
  );

  assert (v_res->>'ok')::boolean = true, 'create_branch_order يجب أن يرجع ok=true';
  v_bo_id := (v_res->'doc'->>'id')::uuid;

  reset role;
  select version into v_version from public.branch_orders where id = v_bo_id;
  select id into v_line1_id from public.branch_order_lines where order_id = v_bo_id and item_id = v_item_id;
  select id into v_line2_id from public.branch_order_lines where order_id = v_bo_id and item_id = v_item2_id;
  assert v_bo_id is not null, 'معرّف الطلب يجب ألا يكون null';
  assert v_line1_id is not null and v_line2_id is not null, 'السطور يجب أن تُنشأ';
  raise notice '✓ الطلب منشأ: order=%, version=%', v_bo_id, v_version;
  set local role authenticated;

  -- =========================================================================
  -- 2. decide_branch_order — اعتماد بكميات أقل من المطلوبة
  -- =========================================================================
  v_res := decide_branch_order(
    v_bo_id,
    v_version,
    'approved',
    null,
    jsonb_build_array(
      jsonb_build_object('line_id', v_line1_id, 'qty_approved', 10),
      jsonb_build_object('line_id', v_line2_id, 'qty_approved', 30)
    )
  );

  assert (v_res->>'ok')::boolean = true, 'decide_branch_order يجب أن يرجع ok=true';

  reset role;
  select status, version into v_status, v_version
  from   public.branch_orders where id = v_bo_id;
  assert v_status = 'approved', format('الحالة بعد القرار يجب approved — وجدنا: %', v_status);

  assert exists (
    select 1 from public.branch_order_lines
    where id = v_line1_id and qty_approved = 10
  ), 'qty_approved للطماطم يجب أن يكون 10';

  select quantity into v_stock_main
  from   public.inventory_stock
  where  warehouse_id = v_main_wh_id and item_id = v_item_id;
  assert v_stock_main = 190,
    format('رصيد الطماطم بعد الاعتماد يجب 190 — وجدنا: %', v_stock_main);

  -- التحقق من عدم إنشاء أي مستودع فروع (تأكيد 011)
  select count(*) into v_branch_whs from public.warehouses where kind = 'branch';
  assert v_branch_whs = 0, format('يجب أن يكون عدد مستودعات الفروع 0، وجدنا: %', v_branch_whs);

  raise notice '✓ الاعتماد تم (بدون مستودعات فرعية): status=%, version=%, رصيد طماطم=%', v_status, v_version, v_stock_main;
  set local role authenticated;

  -- =========================================================================
  -- 3. محاولة الاستلام قبل الاعتماد تفشل
  -- =========================================================================
  declare
    v_bo2_id  uuid;
    v_ver2    bigint;
    v_caught  boolean := false;
  begin
    v_res := create_branch_order(
      gen_random_uuid(), v_branch_id, null,
      jsonb_build_array(jsonb_build_object('item_id', v_item_id, 'qty_requested', 5))
    );
    v_bo2_id := (v_res->'doc'->>'id')::uuid;
    
    reset role;
    select version into v_ver2 from public.branch_orders where id = v_bo2_id;
    set local role authenticated;

    begin
      perform receive_branch_order(gen_random_uuid(), v_bo2_id, v_ver2);
    exception
      when others then
        v_caught := true;
        assert sqlerrm like '%لا يمكن تأكيد استلام طلب بحالة: submitted%',
          format('رسالة الخطأ غير متوقعة: %', sqlerrm);
        raise notice '✓ الاستلام قبل الاعتماد رُفض — "%"', sqlerrm;
    end;

    assert v_caught, 'الاستلام على طلب submitted يجب أن يفشل';
  end;

  -- =========================================================================
  -- 4. تعارض الإصدار على طلب approved يفشل
  -- =========================================================================
  declare
    v_caught2 boolean := false;
  begin
    begin
      perform receive_branch_order(gen_random_uuid(), v_bo_id, 1);
    exception
      when others then
        v_caught2 := true;
        assert sqlerrm like '%تم تعديل الطلب من مستخدم آخر، حدّث الصفحة%',
          format('رسالة الخطأ غير متوقعة: %', sqlerrm);
        raise notice '✓ تعارض الإصدار رُفض — "%"', sqlerrm;
    end;
    assert v_caught2, 'الإصدار القديم على طلب approved يجب أن يفشل';
  end;

  -- =========================================================================
  -- 5. receive_branch_order الحالة السعيدة
  -- =========================================================================
  v_res := receive_branch_order(v_cl_receive, v_bo_id, v_version);

  assert (v_res->>'ok')::boolean = true, 'receive_branch_order يجب أن يرجع ok=true';

  reset role;
  select status into v_status from public.branch_orders where id = v_bo_id;
  assert v_status = 'received', format('الحالة بعد الاستلام يجب received — وجدنا: %', v_status);
  assert (v_res->'doc'->>'status') = 'received', 'doc.status في الرد يجب أن يكون received';
  raise notice '✓ الاستلام تم — status=%', v_status;
  set local role authenticated;

  -- =========================================================================
  -- 6. idempotency: إعادة الاستلام ترجع ok=true ولا تغيّر شيئاً
  -- =========================================================================
  reset role;
  select version into v_version from public.branch_orders where id = v_bo_id;
  set local role authenticated;

  v_res := receive_branch_order(gen_random_uuid(), v_bo_id, v_version);

  assert (v_res->>'ok')::boolean = true, 'idempotency — إعادة الاستلام يجب أن ترجع ok=true';

  reset role;
  select status into v_status from public.branch_orders where id = v_bo_id;
  assert v_status = 'received', 'idempotency — الحالة يجب أن تبقى received';
  raise notice '✓ idempotency — الطلب لا يزال received';
  set local role authenticated;
  -- 7. الرصيد = مجموع الحركات لصنفي الاختبار
  select count(*) into v_audit_count
  from public.inventory_stock s
  where s.warehouse_id = v_main_wh_id
    and s.item_id in (v_item_id, v_item2_id)
    and s.quantity <> (
      select coalesce(sum(m.qty_delta), 0)
      from public.inventory_movements m
      where m.warehouse_id = s.warehouse_id and m.item_id = s.item_id
    );
  assert v_audit_count = 0,
    format('رصيد/حركات غير متطابقة لصنفي الاختبار: %s', v_audit_count);
  raise notice '✓ رصيد صنفي الاختبار = مجموع حركاتهما';
  -- =========================================================================
  -- 8. تحقق من وجود الإشعار في notifications
  -- =========================================================================
  assert exists (
    select 1 from public.notifications
    where kind = 'branch_order_received'
      and 'warehouse' = any(audience)
  ), 'إشعار branch_order_received يجب أن يُسجَّل';

  raise notice '✓ إشعار branch_order_received موجود في notifications';
  raise notice '=== جميع اختبارات 015 نجحت ✓ ===';

end;
$$;

rollback;
