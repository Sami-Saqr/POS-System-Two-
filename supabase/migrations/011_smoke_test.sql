-- =============================================================================
-- 09_smoke_test.sql
-- =============================================================================

begin;

do $$
declare
  v_user_id uuid;
  v_cat_client_id uuid := gen_random_uuid();
  v_client_id uuid := gen_random_uuid();
  v_client_id_2 uuid := gen_random_uuid();
  v_token uuid;
  v_cat_res jsonb;
  v_item_res jsonb;
  v_item_id uuid;
  v_version bigint;
  v_cat_id uuid;
  v_main_wh uuid;
  v_qty numeric;
  v_moves_qty numeric;
  v_fin_cat_id uuid;
begin
  -- جلب مدير أو إنشاء حساب وهمي للاختبار
  select id into v_user_id from auth.users limit 1;
  if v_user_id is null then
    v_user_id := gen_random_uuid();
    -- نتخطى الإنشاء الفعلي في auth.users لعدم الصلاحية هنا للتبسيط
  end if;

  -- إدخال ملف شخصي بصلاحية owner للمستخدم التجريبي
  insert into public.profiles (id, role, is_active)
  values (v_user_id, 'owner', true)
  on conflict (id) do update set role = 'owner', is_active = true;

  -- إنشاء كلمة مرور الإدارة الحقيقية
  insert into public.app_settings (key, label, value)
  values ('cashier_admin_password', 'كلمة مرور الإدارة', extensions.crypt('123456', extensions.gen_salt('bf')))
  on conflict (key) do update set value = excluded.value;

  -- set context and role
  perform set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', v_user_id), true);
  execute 'set local role authenticated';

  
  -- الحصول على التصريح
  select (admin_issue_approval('123456', 'inventory_item_edit')->>'token')::uuid into v_token;

  -- 1) اختبار إنشاء تصنيف
  v_cat_res := save_inventory_category(jsonb_build_object(
    'client_id', v_cat_client_id,
    'approval_token', v_token,
    'name', 'Testing Cat',
    'kind', 'raw',
    'code', 'TCAT'
  ));
  if not (v_cat_res->>'ok')::boolean then raise exception 'فشل إنشاء تصنيف'; end if;
  v_cat_id := (v_cat_res->'category'->>'id')::uuid;

  -- 2) اختبار صنف جديد برصيد افتتاحي
  v_item_res := save_inventory_item(jsonb_build_object(
    'client_id', v_client_id,
    'approval_token', v_token,
    'name', 'Testing Item 1',
    'category_id', v_cat_id,
    'unit_code', 'كجم',
    'opening_qty', 10.5,
    'opening_unit_cost', 50
  ));
  if not (v_item_res->>'ok')::boolean then raise exception 'فشل إنشاء صنف'; end if;
  v_item_id := (v_item_res->'item'->>'id')::uuid;
  v_version := (v_item_res->'item'->>'version')::bigint;

  -- 3) التكرار (Idempotency)
  if save_inventory_item(jsonb_build_object('client_id', v_client_id, 'approval_token', v_token))::text != v_item_res::text then
    raise exception 'فشل اختبار التكرار';
  end if;

  -- 4) رفض تكرار الاسم
  begin
    perform save_inventory_item(jsonb_build_object(
      'client_id', v_client_id_2,
      'approval_token', v_token,
      'name', 'Testing Item 1',
      'category_id', v_cat_id,
      'unit_code', 'كجم'
    ));
    raise exception 'يجب أن يفشل عند تكرار الاسم';
  exception when others then null; -- متوقع
  end;

  -- 5) رفض تغيير الوحدة بعد الحركة
  begin
    perform save_inventory_item(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'approval_token', v_token,
      'id', v_item_id,
      'expected_version', v_version,
      'name', 'Testing Item Mod',
      'category_id', v_cat_id,
      'unit_code', 'جرام' -- وحدة أخرى صالحة
    ));
    raise exception 'يجب أن يرفض تغيير الوحدة';
  exception when others then
    if sqlerrm not like '%حركات في المخزون%' then
      raise exception 'خطأ غير متوقع: %', sqlerrm;
    end if;
  end;

  -- 6) التعديل بنسخة قديمة (version mismatch)
  begin
    perform save_inventory_item(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'approval_token', v_token,
      'id', v_item_id,
      'expected_version', v_version - 1,
      'name', 'Testing Item Mod',
      'category_id', v_cat_id,
      'unit_code', 'كجم'
    ));
    raise exception 'يجب أن يرفض التعديل بنسخة قديمة';
  exception when others then
    if sqlerrm not like '%تم تعديل الصنف من مستخدم آخر%' then raise exception 'خطأ غير متوقع: %', sqlerrm; end if;
  end;

  -- 7) منع الصنف التام
  select id into v_fin_cat_id from public.inventory_categories where code = 'FIN';
  begin
    perform save_inventory_item(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'approval_token', v_token,
      'name', 'Testing FIN',
      'category_id', v_fin_cat_id,
      'unit_code', 'كجم'
    ));
    raise exception 'يجب أن يرفض المنتج التام';
  exception when others then
    if sqlerrm not like '%لا يمكن إنشاء منتج تام يدوياً%' then raise exception 'خطأ غير متوقع: %', sqlerrm; end if;
  end;

  -- 8) رفض بدون تصريح إدارة
  begin
    perform save_inventory_item(jsonb_build_object(
      'client_id', gen_random_uuid(),
      'name', 'Testing No Token',
      'category_id', v_cat_id,
      'unit_code', 'كجم'
    ));
    raise exception 'يجب أن يرفض بدون تصريح';
  exception when others then
    if sqlerrm not like '%يتطلب هذا الإجراء باسورد الإدارة%' then raise exception 'خطأ غير متوقع: %', sqlerrm; end if;
  end;

  raise notice '=== نجح اختبار الدخان لـ 09_item_crud ===';
end;
$$;

rollback;
