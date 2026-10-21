-- =============================================================================
-- 09_item_crud.sql
-- إضافة وتعديل الأصناف والتصنيفات من الواجهة
-- =============================================================================

-- =============================================================================
-- § 1 — جدول مساعد لحفظ نتيجة محاولات الحفظ (Idempotency)
-- =============================================================================
create table if not exists public.inventory_item_ops (
  client_id uuid primary key,  result jsonb not null,  created_at timestamptz not null default now()
);

alter table public.inventory_item_ops enable row level security;
revoke insert, update, delete on public.inventory_item_ops from anon, authenticated;

-- =============================================================================
-- § 2 — save_inventory_category: إنشاء وتعديل تصنيف
-- =============================================================================
create or replace function save_inventory_category(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id   uuid := auth.uid();
  v_client_id uuid   := nullif(trim(p->>'client_id'), '')::uuid;
  v_token     uuid   := nullif(trim(p->>'approval_token'), '')::uuid;
  v_id        uuid   := nullif(trim(p->>'id'), '')::uuid;
  v_name      text   := trim(p->>'name');
  v_kind      text   := trim(p->>'kind');
  v_code      text   := upper(trim(p->>'code'));
  v_sort      int    := coalesce((p->>'sort_order')::int, 0);
  v_cat       record;
  v_existing  record;
begin
  if v_user_id is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('storekeeper', 'owner') then raise exception 'ليس لديك صلاحية لإدارة التصنيفات'; end if;

  if v_client_id is null then raise exception 'client_id مطلوب'; end if;
  
  -- تحقق من التصريح (نفس تصريح إدارة الأصناف)
  if v_token is null then raise exception 'يتطلب هذا الإجراء باسورد الإدارة'; end if;
  perform 1 from public.admin_approvals
  where token = v_token and user_id = v_user_id and action = 'inventory_item_edit'
    and expires_at > now();
  if not found then raise exception 'تصريح الإدارة غير صالح أو منتهي الصلاحية'; end if;

  -- تحقق من التكرار (idempotency)
  select result into v_existing from public.inventory_item_ops where client_id = v_client_id;
  if found then return v_existing.result; end if;

  if v_name is null or length(v_name) < 2 then raise exception 'اسم التصنيف مطلوب (حرفين على الأقل)'; end if;
  if v_kind not in ('raw', 'supply') then raise exception 'نوع التصنيف يجب أن يكون خامة أو مستلزمات'; end if;
  if v_code is null or length(v_code) < 2 or length(v_code) > 4 or v_code !~ '^[A-Z]+$' then
    raise exception 'الكود المختصر يجب أن يكون 2 إلى 4 حروف لاتينية فقط';
  end if;

  -- فحص التكرار (اسم أو كود)
  if v_id is null then
    perform 1 from public.inventory_categories where name = v_name;
    if found then raise exception 'اسم التصنيف موجود مسبقاً'; end if;
    perform 1 from public.inventory_categories where code = v_code;
    if found then raise exception 'كود التصنيف موجود مسبقاً'; end if;

    insert into public.inventory_categories (name, kind, code, sort_order)
    values (v_name, v_kind, v_code, v_sort)
    returning * into v_cat;
  else
    select * into v_cat from public.inventory_categories where id = v_id for update;
    if not found then raise exception 'التصنيف غير موجود'; end if;
    if v_cat.is_system then raise exception 'لا يمكن تعديل التصنيفات النظامية'; end if;

    perform 1 from public.inventory_categories where name = v_name and id != v_id;
    if found then raise exception 'اسم التصنيف موجود مسبقاً'; end if;
    perform 1 from public.inventory_categories where code = v_code and id != v_id;
    if found then raise exception 'كود التصنيف موجود مسبقاً'; end if;

    if v_cat.kind != v_kind then
      perform 1 from public.inventory_items where category_id = v_id limit 1;
      if found then raise exception 'لا يمكن تغيير نوع التصنيف لوجود أصناف مرتبطة به'; end if;
    end if;

    update public.inventory_categories
    set name = v_name, kind = v_kind, code = v_code, sort_order = v_sort
    where id = v_id
    returning * into v_cat;
  end if;

  perform _bump_data_version('inv_catalog');

  declare
    v_ret jsonb;
  begin
    v_ret := jsonb_build_object(
      'ok', true,
      'category', jsonb_build_object(
        'id', v_cat.id, 'name', v_cat.name, 'kind', v_cat.kind,
        'code', v_cat.code, 'sort_order', v_cat.sort_order, 'is_system', v_cat.is_system,
        'is_active', true, 'updated_at', now()
      ),
      'stamps', jsonb_build_object(
        'inv_catalog', (select version from public.data_versions where key = 'inv_catalog')
      )
    );
    insert into public.inventory_item_ops (client_id, result) values (v_client_id, v_ret);
    return v_ret;
  end;
end;
$$;

revoke execute on function save_inventory_category(jsonb) from public, anon, authenticated;
grant execute on function save_inventory_category(jsonb) to authenticated;

-- =============================================================================
-- § 3 — save_inventory_item: إنشاء وتعديل صنف
-- =============================================================================
create or replace function save_inventory_item(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id      uuid := auth.uid();
  v_client_id    uuid := nullif(trim(p->>'client_id'), '')::uuid;
  v_token        uuid := nullif(trim(p->>'approval_token'), '')::uuid;
  v_id           uuid := nullif(trim(p->>'id'), '')::uuid;
  v_exp_version  bigint := (p->>'expected_version')::bigint;
  v_sku          text := upper(trim(coalesce(p->>'sku', '')));
  v_name         text := trim(p->>'name');
  v_cat_id       uuid := nullif(trim(p->>'category_id'), '')::uuid;
  v_unit_code    text := trim(p->>'unit_code');
  v_min_level    numeric := coalesce((p->>'min_level')::numeric, 0);
  v_branch_ord   boolean := coalesce((p->>'branch_orderable')::boolean, true);
  v_is_active    boolean := coalesce((p->>'is_active')::boolean, true);
  v_opening_qty  numeric := coalesce((p->>'opening_qty')::numeric, 0);
  v_opening_cost numeric := coalesce((p->>'opening_unit_cost')::numeric, 0);
  v_item         record;
  v_existing     record;
  v_cat          record;
  v_has_moves    boolean;
  v_main_wh_id   uuid;
  v_new_qty      numeric;
  v_stock_rows   jsonb := '[]'::jsonb;
  v_warnings     text[] := array[]::text[];
  v_ret          jsonb;
begin
  if v_user_id is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if not _has_role('storekeeper', 'owner') then raise exception 'ليس لديك صلاحية لإدارة الأصناف'; end if;

  if v_client_id is null then raise exception 'client_id مطلوب'; end if;

  if v_token is null then raise exception 'يتطلب هذا الإجراء باسورد الإدارة'; end if;
  perform 1 from public.admin_approvals
  where token = v_token and user_id = v_user_id and action = 'inventory_item_edit'
    and expires_at > now();
  if not found then raise exception 'تصريح الإدارة غير صالح أو منتهي الصلاحية'; end if;

  -- idempotency
  select result into v_existing from public.inventory_item_ops where client_id = v_client_id;
  if found then return v_existing.result; end if;

  -- التحقق الأساسي
  if v_name is null or length(v_name) < 2 or length(v_name) > 120 then
    raise exception 'الاسم مطلوب (2 إلى 120 حرف)';
  end if;
  if v_min_level < 0 then raise exception 'الحد الأدنى لا يمكن أن يكون سالباً'; end if;

  if v_cat_id is null then raise exception 'التصنيف مطلوب'; end if;
  select * into v_cat from public.inventory_categories where id = v_cat_id;
  if not found then raise exception 'التصنيف غير موجود'; end if;

  -- التأكد من الوحدة
  perform 1 from public.inventory_units where code = v_unit_code;
  if not found then raise exception 'وحدة القياس غير صالحة'; end if;

  if v_id is null then
    -- ================== إنشـــاء ==================
    if v_cat.code = 'FIN' then raise exception 'لا يمكن إنشاء منتج تام يدوياً'; end if;

    perform 1 from public.inventory_items where lower(trim(name)) = lower(v_name) and is_active = true;
    if found then raise exception 'يوجد صنف نشط بنفس الاسم مسبقاً'; end if;

    if v_sku != '' then
      if length(v_sku) < 3 or length(v_sku) > 30 or v_sku !~ '^[A-Z0-9\-_]+$' then
        raise exception 'SKU غير صالح: حروف لاتينية، أرقام، وشرطات فقط، من 3 إلى 30 حرف';
      end if;
      perform 1 from public.inventory_items where sku = v_sku;
      if found then raise exception 'رمز SKU مستخدم مسبقاً'; end if;
    else
      -- توليد SKU تلقائي
      v_sku := _next_doc_number('item_sku', v_cat.code, '{scope}-{n:4}');
    end if;

    insert into public.inventory_items (
      sku, name, category_id, unit_code, min_level, branch_orderable, is_active, created_by
    ) values (
      v_sku, v_name, v_cat_id, v_unit_code, v_min_level, v_branch_ord, v_is_active, v_user_id
    ) returning * into v_item;

    if v_opening_qty > 0 then
      select id into v_main_wh_id from public.warehouses where kind = 'main';
      v_new_qty := _post_movement(
        v_main_wh_id, v_item.id, 'opening', v_opening_qty, coalesce(v_opening_cost, 0),
        'manual_entry', null, 'رصيد افتتاحي يدوي', v_user_id
      );
      -- أعد قراءة الصنف بعد _post_movement لأنه يُحدّث avg_cost ويزيد الـ version
      select * into v_item from public.inventory_items where id = v_item.id;
      v_stock_rows := jsonb_build_array(jsonb_build_object('item_id', v_item.id, 'quantity', v_new_qty));
      perform _bump_data_version('inv_stock');
    end if;

  else
    -- ================== تعــديل ==================
    if v_exp_version is null then raise exception 'رقم النسخة (expected_version) مطلوب للتعديل'; end if;
    select * into v_item from public.inventory_items where id = v_id for update;
    if not found then raise exception 'الصنف غير موجود'; end if;
    if v_item.version != v_exp_version then
      raise exception 'تم تعديل الصنف من مستخدم آخر، حدّث الصفحة';
    end if;

    -- القيود على الصنف التام
    declare
      v_old_cat record;
    begin
      select * into v_old_cat from public.inventory_categories where id = v_item.category_id;
      if v_old_cat.code = 'FIN' then
        if v_name != v_item.name or v_cat_id != v_item.category_id or v_unit_code != v_item.unit_code or (v_sku != '' and v_sku != v_item.sku) then
          raise exception 'لا يمكن تغيير بيانات الصنف التام الأساسية باستثناء الحد الأدنى وحالة النشاط';
        end if;
      else
        if v_cat.code = 'FIN' then raise exception 'لا يمكن تغيير تصنيف صنف عادي إلى منتج تام'; end if;
      end if;
    end;

    perform 1 from public.inventory_items where lower(trim(name)) = lower(v_name) and is_active = true and id != v_id;
    if found then raise exception 'يوجد صنف نشط آخر بنفس الاسم مسبقاً'; end if;

    if v_sku != '' and v_sku != v_item.sku then
      if length(v_sku) < 3 or length(v_sku) > 30 or v_sku !~ '^[A-Z0-9\-_]+$' then
        raise exception 'SKU غير صالح: حروف لاتينية، أرقام، وشرطات فقط، من 3 إلى 30 حرف';
      end if;
      perform 1 from public.inventory_items where sku = v_sku and id != v_id;
      if found then raise exception 'رمز SKU مستخدم مسبقاً'; end if;
    end if;

    -- التحقق من الوحدة — ممنوع التغيير بعد الإنشاء (لسلامة البيانات التاريخية)
    if v_item.unit_code != v_unit_code then
      raise exception 'لا يمكن تغيير وحدة القياس لأن الصنف له حركات في المخزون';
    end if;

    -- التحقق من التعطيل
    if v_is_active = false and v_item.is_active = true then
      -- هل له طلب مفتوح؟
      perform 1 from public.supply_order_lines sl
      join public.supply_orders so on so.id = sl.order_id
      where sl.item_id = v_id and so.status in ('pending_review', 'approved');
      if found then raise exception 'لا يمكن تعطيل صنف وهو موجود في طلب توريد مفتوح'; end if;

      perform 1 from public.branch_order_lines bl
      join public.branch_orders bo on bo.id = bl.order_id
      where bl.item_id = v_id and bo.status = 'submitted';
      if found then raise exception 'لا يمكن تعطيل صنف وهو موجود في طلب فرع مفتوح'; end if;

      perform 1 from public.inventory_stock where item_id = v_id and quantity > 0 limit 1;
      if found then
        v_warnings := v_warnings || 'تم تعطيل الصنف ولكنه يمتلك رصيداً في أحد المستودعات.';
      end if;
    end if;

    update public.inventory_items
    set name = v_name,
        category_id = v_cat_id,
        unit_code = v_unit_code,
        sku = coalesce(nullif(v_sku, ''), sku),
        min_level = v_min_level,
        branch_orderable = v_branch_ord,
        is_active = v_is_active,
        updated_at = now()
    where id = v_id
    returning * into v_item;
  end if;

  perform _bump_data_version('inv_catalog');

  v_ret := jsonb_build_object(
    'ok', true,
    'item', jsonb_build_object(
      'id', v_item.id, 'sku', v_item.sku, 'name', v_item.name,
      'category_id', v_item.category_id, 'unit_code', v_item.unit_code,
      'min_level', v_item.min_level, 'avg_cost', v_item.avg_cost,
      'branch_orderable', v_item.branch_orderable, 'is_active', v_item.is_active,
      'created_at', v_item.created_at, 'updated_at', v_item.updated_at,
      'version', v_item.version
    ),
    'stock', v_stock_rows,
    'stamps', jsonb_build_object(
      'inv_catalog', (select version from public.data_versions where key = 'inv_catalog'),
      'inv_stock', (select version from public.data_versions where key = 'inv_stock')
    ),
    'warnings', to_jsonb(v_warnings)
  );

  insert into public.inventory_item_ops (client_id, result) values (v_client_id, v_ret);
  return v_ret;
end;
$$;

revoke execute on function save_inventory_item(jsonb) from public, anon, authenticated;
grant execute on function save_inventory_item(jsonb) to authenticated;

-- =============================================================================
-- نهاية الملف
-- =============================================================================
