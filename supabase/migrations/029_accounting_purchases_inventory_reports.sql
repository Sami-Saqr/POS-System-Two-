-- =============================================================================
-- Migration 029: تحسينات المشتريات، تسعير وتكلفة المخزون والمنتجات، والتقارير الشاملة
-- =============================================================================

begin;

-- ─── 1. تحديث create_supply_order لدعم إنشاء طلب معتمد مباشرة من المحاسب ─────
-- إسقاط النسخة القديمة ذات الـ 7 وسائط لحل تعارض الـ Overloading (PGRST203)
drop function if exists public.create_supply_order(uuid, text, text, date, text, text, jsonb);

create or replace function public.create_supply_order(
  p_client_id      uuid,
  p_supplier_name  text,
  p_supplier_phone text     default null,
  p_expected_date  date     default null,
  p_priority       text     default 'normal',
  p_notes          text     default null,
  p_lines          jsonb    default null,
  p_auto_approve   boolean  default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id     uuid := auth.uid();
  v_existing    jsonb;
  v_supplier_id uuid;
  v_order_id    uuid;
  v_number      text;
  v_year        text;
  v_line        jsonb;
  v_is_acct     boolean := false;
  v_status      text := 'pending_review';
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  -- فحص الصلاحية: أمين المخزن أو المحاسب أو المالك
  if not _has_role('storekeeper', 'accountant', 'owner', 'manager') then
    raise exception 'إنشاء طلبات التوريد للمخزن أو الحسابات فقط';
  end if;

  v_is_acct := _has_role('accountant', 'owner');
  if v_is_acct or p_auto_approve then
    v_status := 'approved';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف لطلب التوريد';
  end if;

  -- تحقق من التكرار (idempotency)
  select jsonb_build_object('ok', true, 'doc', jsonb_build_object('id', id, 'number', number, 'status', status))
  into v_existing
  from public.supply_orders
  where client_id = p_client_id;

  if v_existing is not null then
    return v_existing;
  end if;

  -- المورد: ابحث أو أنشئ
  insert into public.suppliers (name, phone)
  values (trim(p_supplier_name), p_supplier_phone)
  on conflict (lower(trim(name))) do update
    set phone      = coalesce(p_supplier_phone, suppliers.phone),
        updated_at = now()
  returning id into v_supplier_id;

  -- توليد رقم الطلب
  v_year   := to_char(current_date, 'YYYY');
  v_number := _next_doc_number('po', v_year, 'PO-{scope}-{n:4}');

  -- إنشاء رأس الطلب
  insert into public.supply_orders (
    client_id, number, supplier_id,
    expected_date, priority, notes, status,
    reviewed_by, reviewed_at, created_by
  ) values (
    p_client_id, v_number, v_supplier_id,
    coalesce(p_expected_date, current_date + interval '3 days'),
    coalesce(p_priority, 'normal'),
    p_notes,
    v_status,
    case when v_status = 'approved' then v_user_id else null end,
    case when v_status = 'approved' then now() else null end,
    v_user_id
  )
  returning id into v_order_id;

  -- إدراج السطور
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.supply_order_lines (
      order_id, item_id, qty_requested, qty_approved, unit_cost
    ) values (
      v_order_id,
      (v_line->>'item_id')::uuid,
      (v_line->>'qty_requested')::numeric,
      case when v_status = 'approved' then (v_line->>'qty_requested')::numeric else null end,
      coalesce((v_line->>'unit_cost')::numeric, 0)
    );
  end loop;

  -- بصمات البيانات
  perform _bump_data_version('inv_supply');

  -- إشعارات
  if v_status = 'approved' then
    -- إشعار للمستودع: طلب معتمد جاهز للاستلام
    perform _notify(
      'supply_approved',
      array['warehouse', 'storekeeper'],
      null,
      'طلب شراء جديد معتمد: ' || v_number,
      'أنشأ المحاسب طلب شراء معتمد وجاهز للاستلام من المورد: ' || p_supplier_name,
      jsonb_build_object('ref_type', 'supply_order', 'ref_id', v_order_id, 'domains', array['inv_supply'])
    );
  else
    -- إشعار للمحاسب: طلب توريد جديد للمراجعة
    perform _notify(
      'supply_submitted',
      array['accounting'],
      null,
      'طلب توريد جديد: ' || v_number,
      'طلب توريد من المستودع بانتظار الاعتماد',
      jsonb_build_object('ref_type', 'supply_order', 'ref_id', v_order_id, 'domains', array['inv_supply'])
    );
  end if;

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', v_order_id, 'number', v_number, 'status', v_status),
    'stamps', jsonb_build_object('inv_supply',
                (select version from public.data_versions where key = 'inv_supply'))
  );
end;
$$;

grant execute on function public.create_supply_order(uuid, text, text, date, text, text, jsonb, boolean) to authenticated;


-- ─── 2. تحديث review_supply_order لاعتماد الكميات وإشعار المستودع ─────────────
create or replace function public.review_supply_order(
  p_order_id         uuid,
  p_expected_version bigint,
  p_decision         text,   -- 'approved' | 'rejected'
  p_rejection_reason text   default null,
  p_lines            jsonb  default null  -- [{line_id, qty_approved, unit_cost}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_order   record;
  v_line    jsonb;
  v_all_zero boolean;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('accountant', 'owner') then
    raise exception 'مراجعة طلبات التوريد للمحاسب فقط';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'قرار غير صالح: %', p_decision;
  end if;

  select id, number, status, version into v_order
  from public.supply_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'طلب التوريد غير موجود';
  end if;

  if v_order.status != 'pending_review' then
    raise exception 'لا يمكن مراجعة طلب حالته: %', v_order.status;
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  if p_decision = 'approved' then
    if p_lines is not null and jsonb_array_length(p_lines) > 0 then
      select bool_and((coalesce(l->>'qty_approved', '0'))::numeric = 0)
      into v_all_zero
      from jsonb_array_elements(p_lines) l;

      if v_all_zero then
        raise exception 'لا يمكن الموافقة على طلب بكميات معتمدة صفر لجميع السطور. استخدم خيار الرفض.';
      end if;

      for v_line in select * from jsonb_array_elements(p_lines)
      loop
        update public.supply_order_lines
        set qty_approved = coalesce((v_line->>'qty_approved')::numeric, qty_requested),
            unit_cost    = coalesce((v_line->>'unit_cost')::numeric, unit_cost),
            updated_at   = now()
        where id = (v_line->>'line_id')::uuid
          and order_id = p_order_id;
      end loop;
    else
      -- اعتماد كافة الكميات المطلوبة كما هي إذا لم يُحدد تفصيل
      update public.supply_order_lines
      set qty_approved = qty_requested,
          updated_at   = now()
      where order_id = p_order_id;
    end if;

    update public.supply_orders
    set status      = 'approved',
        reviewed_by = v_user_id,
        reviewed_at = now()
    where id = p_order_id;

    -- إشعار للمستودع
    perform _notify(
      'supply_approved',
      array['warehouse', 'storekeeper'],
      null,
      'تمت موافقة المحاسب على طلب التوريد: ' || v_order.number,
      'تم اعتماد الطلب وهو جاهز للاستلام وتحديث المخزون',
      jsonb_build_object('ref_type', 'supply_order', 'ref_id', p_order_id, 'domains', array['inv_supply'])
    );
  else
    if p_rejection_reason is null or trim(p_rejection_reason) = '' then
      raise exception 'سبب الرفض إجباري';
    end if;

    update public.supply_orders
    set status           = 'rejected',
        rejection_reason = p_rejection_reason,
        reviewed_by      = v_user_id,
        reviewed_at      = now()
    where id = p_order_id;

    -- إشعار للمستودع بالرفض
    perform _notify(
      'supply_rejected',
      array['warehouse', 'storekeeper'],
      null,
      'تم رفض طلب التوريد: ' || v_order.number,
      'رفض المحاسب طلب التوريد. السبب: ' || p_rejection_reason,
      jsonb_build_object('ref_type', 'supply_order', 'ref_id', p_order_id, 'domains', array['inv_supply'])
    );
  end if;

  perform _bump_data_version('inv_supply');

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', p_order_id, 'status', p_decision),
    'stamps', jsonb_build_object('inv_supply',
                (select version from public.data_versions where key = 'inv_supply'))
  );
end;
$$;

grant execute on function public.review_supply_order(uuid, bigint, text, text, jsonb) to authenticated;


-- ─── 3. تحديث receive_supply_order لإرسال إشعار للمحاسب دائماً عند الاستلام ──
create or replace function public.receive_supply_order(
  p_client_id        uuid,
  p_order_id         uuid,
  p_expected_version bigint,
  p_general_note     text  default null,
  p_lines            jsonb default null         -- [{line_id, qty_received, note?}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id    uuid := auth.uid();
  v_order      record;
  v_item_id    uuid;
  v_line       jsonb;
  v_main_wh_id uuid;
  v_qty_recv   numeric;
  v_unit_cost  numeric;
  v_qty_appr   numeric;
  v_has_issues boolean := false;
  v_stock_rows jsonb   := '[]'::jsonb;
  v_new_qty    numeric;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper', 'owner', 'manager') then
    raise exception 'استلام التوريد لأمين المخزن فقط';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للاستلام';
  end if;

  select id, number, status, version into v_order
  from public.supply_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'طلب التوريد غير موجود';
  end if;

  if v_order.status = 'received' then
    return jsonb_build_object('ok', true, 'doc', jsonb_build_object('id', p_order_id, 'status', 'received'));
  end if;

  if v_order.status != 'approved' then
    raise exception 'لا يمكن الاستلام — حالة الطلب الحالية: %', v_order.status;
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  select id into v_main_wh_id from public.warehouses where kind = 'main' limit 1;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select l.qty_approved, l.unit_cost, l.item_id
    into v_qty_appr, v_unit_cost, v_item_id
    from public.supply_order_lines l
    where l.id = (v_line->>'line_id')::uuid
      and l.order_id = p_order_id;

    v_qty_recv := coalesce((v_line->>'qty_received')::numeric, coalesce(v_qty_appr, 0));

    if v_qty_recv != coalesce(v_qty_appr, v_qty_recv)
       or (v_line->>'note' is not null and trim(v_line->>'note') != '') then
      v_has_issues := true;
    end if;

    update public.supply_order_lines
    set qty_received = v_qty_recv,
        line_note    = coalesce(v_line->>'note', line_note),
        updated_at   = now()
    where id = (v_line->>'line_id')::uuid;

    if v_qty_recv > 0 then
      v_new_qty := _post_movement(
        v_main_wh_id,
        v_item_id,
        'supply_receipt',
        v_qty_recv,
        v_unit_cost,
        'supply_order',
        p_order_id,
        'استلام من طلب التوريد: ' || v_order.number,
        v_user_id
      );

      v_stock_rows := v_stock_rows || jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_new_qty
      );
    end if;
  end loop;

  update public.supply_orders
  set status      = 'received',
      has_issues  = v_has_issues,
      notes       = coalesce(p_general_note, notes),
      received_by = v_user_id,
      received_at = now()
  where id = p_order_id;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('inv_stock');
  perform _bump_data_version('inv_catalog');

  -- إشعار للمحاسب دائماً عند الاستلام
  perform _notify(
    case when v_has_issues then 'supply_received_issues' else 'supply_received' end,
    array['accounting'],
    null,
    case when v_has_issues then 'تم استلام توريد بملاحظات: ' || v_order.number else 'تم استلام طلب التوريد في المخزن: ' || v_order.number end,
    case when v_has_issues then 'تم استلام أصناف التوريد مع وجود فروقات في الكميات أو ملاحظات' else 'تم استلام وتوريد كامل أصناف الطلب بنجاح إلى المستودع الرئيسي' end,
    jsonb_build_object('ref_type', 'supply_order', 'ref_id', p_order_id, 'has_issues', v_has_issues, 'domains', array['inv_supply', 'inv_stock'])
  );

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', p_order_id, 'number', v_order.number, 'status', 'received', 'has_issues', v_has_issues),
    'stock',  v_stock_rows,
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply'),
      'inv_stock',  (select version from public.data_versions where key = 'inv_stock'),
      'inv_catalog',(select version from public.data_versions where key = 'inv_catalog')
    )
  );
end;
$$;

grant execute on function public.receive_supply_order(uuid, uuid, bigint, text, jsonb) to authenticated;


-- ─── 4. تحديث acc_get_supply_orders لإرجاع qty_approved ──────────────────────
drop function if exists public.acc_get_supply_orders cascade;
create or replace function public.acc_get_supply_orders(
  p_status    text        default null,
  p_limit     int         default 50,
  p_cursor_ts timestamptz default null,
  p_cursor_id uuid        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'storekeeper') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select jsonb_agg(row_data)
  into   v_rows
  from (
    select jsonb_build_object(
      'id',               so.id,
      'number',           so.number,
      'supplier_id',      so.supplier_id,
      'supplier_name',    sup.name,
      'supplier_phone',   sup.phone,
      'expected_date',    so.expected_date,
      'priority',         so.priority,
      'status',           so.status,
      'notes',            so.notes,
      'rejection_reason', so.rejection_reason,
      'has_issues',       so.has_issues,
      'reviewed_at',      so.reviewed_at,
      'created_at',       so.created_at,
      'version',          so.version,
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',            l.id,
          'item_id',       l.item_id,
          'item_name',     i.name,
          'unit_code',     i.unit_code,
          'qty_requested', l.qty_requested,
          'qty_approved',  l.qty_approved,
          'qty_received',  l.qty_received,
          'unit_cost',     l.unit_cost,
          'line_note',     l.line_note,
          'notes',         l.line_note
        ))
        from public.supply_order_lines l
        join public.inventory_items i on i.id = l.item_id
        where l.order_id = so.id
      ), '[]'::jsonb)
    ) as row_data
    from public.supply_orders so
    left join public.suppliers sup on sup.id = so.supplier_id
    where (p_status is null or so.status = p_status)
      and (
        p_cursor_ts is null
        or (so.created_at, so.id) < (p_cursor_ts, p_cursor_id)
      )
    order by so.created_at desc, so.id desc
    limit v_limit
  ) sub;

  return jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
end;
$$;

grant execute on function public.acc_get_supply_orders(text, int, timestamptz, uuid) to authenticated;


-- ─── 5. دالة تحديث سعر / متوسط تكلفة صنف المخزون ─────────────────────────────
create or replace function public.acc_update_item_cost(
  p_item_id  uuid,
  p_avg_cost numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'storekeeper') then
    raise exception 'صلاحية مرفوضة';
  end if;

  if p_avg_cost is null or p_avg_cost < 0 then
    raise exception 'متوسط التكلفة يجب أن يكون رقماً موجباً أو صفراً';
  end if;

  update public.inventory_items
  set avg_cost   = round(p_avg_cost, 4),
      updated_at = now(),
      version    = version + 1
  where id = p_item_id;

  if not found then
    raise exception 'صنف المخزون غير موجود';
  end if;

  perform _bump_data_version('inv_catalog');

  return jsonb_build_object('ok', true, 'item_id', p_item_id, 'avg_cost', round(p_avg_cost, 4));
end;
$$;

grant execute on function public.acc_update_item_cost(uuid, numeric) to authenticated;


-- ─── 6. جلب قائمة المنتجات التامة مع أسعار البيع وتكلفة الوجبات ───────────────
create or replace function public.acc_get_products_with_costs()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid  uuid := auth.uid();
  v_rows jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select jsonb_agg(row_data)
  into v_rows
  from (
    select jsonb_build_object(
      'id',           p.id,
      'name',         p.name,
      'sku',          coalesce(p.sku, ''),
      'category_id',  p.category_id,
      'category_name',coalesce(c.name, '—'),
      'has_variants', p.has_variants,
      'price',        p.price,
      'cost',         p.cost,
      'is_active',    p.is_active,
      'variants', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',         pv.id,
          'label',      pv.label,
          'price',      pv.price,
          'cost',       pv.cost,
          'is_active',  pv.is_active
        ) order by pv.sort_order, pv.label)
        from public.product_variants pv
        where pv.product_id = p.id
          and pv.deleted_at is null
      ), '[]'::jsonb)
    ) as row_data
    from public.products p
    left join public.categories c on c.id = p.category_id
    where p.deleted_at is null
    order by c.name nulls last, p.name asc
  ) sub;

  return coalesce(v_rows, '[]'::jsonb);
end;
$$;

grant execute on function public.acc_get_products_with_costs() to authenticated;


-- ─── 7. تحديث أسعار المنتجات التامة وتكلفة الوجبات بدون مكسب ────────────────
create or replace function public.acc_update_product_pricing(
  p_product_id uuid,
  p_price      numeric default null,
  p_cost       numeric default 0,
  p_variants   jsonb   default null  -- [{variant_id, price, cost}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid      uuid := auth.uid();
  v_variant  jsonb;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'تعديل أسعار المنتجات للمحاسب أو المالك فقط';
  end if;

  update public.products
  set price      = case when has_variants = false then p_price else null end,
      cost       = coalesce(p_cost, 0),
      updated_at = now(),
      version    = version + 1
  where id = p_product_id;

  if not found then
    raise exception 'المنتج غير موجود';
  end if;

  if p_variants is not null and jsonb_array_length(p_variants) > 0 then
    for v_variant in select * from jsonb_array_elements(p_variants)
    loop
      update public.product_variants
      set price      = (v_variant->>'price')::numeric,
          cost       = coalesce((v_variant->>'cost')::numeric, 0),
          updated_at = now(),
          version    = version + 1
      where id = (v_variant->>'variant_id')::uuid
        and product_id = p_product_id;
    end loop;
  end if;

  perform _bump_data_version('pos_catalog');

  return jsonb_build_object('ok', true, 'product_id', p_product_id);
end;
$$;

grant execute on function public.acc_update_product_pricing(uuid, numeric, numeric, jsonb) to authenticated;


-- ─── 8. احتساب طلبيات الفرع من المخزن الرئيسي وتحويلها لقيمة مالية ────────────
create or replace function public.acc_get_branch_warehouse_orders(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid  uuid := auth.uid();
  v_from timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to   timestamptz := coalesce(p_to, now());
  v_rows jsonb;
  v_total numeric;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة';
  end if;

  select coalesce(sum(sub.order_total_cost), 0)
  into v_total
  from (
    select bo.id,
           coalesce(sum(coalesce(bol.qty_approved, bol.qty_requested, 0) * coalesce(ii.avg_cost, 0)), 0) as order_total_cost
    from public.branch_orders bo
    join public.branch_order_lines bol on bol.order_id = bo.id
    left join public.inventory_items ii on ii.id = bol.item_id
    where bo.created_at >= v_from and bo.created_at <= v_to
      and (p_branch_id is null or bo.branch_id = p_branch_id)
      and bo.status in ('approved', 'delivered', 'received', 'closed')
    group by bo.id
  ) sub;

  select jsonb_agg(row_data)
  into v_rows
  from (
    select jsonb_build_object(
      'id',          bo.id,
      'number',      bo.number,
      'branch_id',   bo.branch_id,
      'branch_name', coalesce(b.name, '—'),
      'status',      bo.status,
      'created_at',  bo.created_at,
      'total_cost',  round(coalesce(sum(coalesce(bol.qty_approved, bol.qty_requested, 0) * coalesce(ii.avg_cost, 0)), 0), 2),
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
          'item_name',     ii.name,
          'unit',          ii.unit_code,
          'qty_approved',  coalesce(bol.qty_approved, bol.qty_requested, 0),
          'avg_cost',      ii.avg_cost,
          'line_cost',     round(coalesce(bol.qty_approved, bol.qty_requested, 0) * coalesce(ii.avg_cost, 0), 2)
        ))
        from public.branch_order_lines bol
        left join public.inventory_items ii on ii.id = bol.item_id
        where bol.order_id = bo.id
      ), '[]'::jsonb)
    ) as row_data
    from public.branch_orders bo
    left join public.branches b on b.id = bo.branch_id
    join public.branch_order_lines bol on bol.order_id = bo.id
    left join public.inventory_items ii on ii.id = bol.item_id
    where bo.created_at >= v_from and bo.created_at <= v_to
      and (p_branch_id is null or bo.branch_id = p_branch_id)
      and bo.status in ('approved', 'delivered', 'received', 'closed')
    group by bo.id, bo.number, bo.branch_id, b.name, bo.status, bo.created_at
    order by bo.created_at desc
  ) sub_rows;

  return jsonb_build_object(
    'orders',     coalesce(v_rows, '[]'::jsonb),
    'total_cost', round(coalesce(v_total, 0), 2)
  );
end;
$$;

grant execute on function public.acc_get_branch_warehouse_orders(timestamptz, timestamptz, uuid) to authenticated;


-- ─── 9. التقرير المالي الشامل للشركة والفرع (مبيعات، مشتريات، مصروفات، طلبيات، فائض كاشير) ─
create or replace function public.acc_get_comprehensive_financial_report(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid          uuid := auth.uid();
  v_from         timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to           timestamptz := coalesce(p_to, now());
  v_branch_name  text := 'الشركة كاملة — جميع الفروع';

  -- مبيعات
  v_sales_count   int := 0;
  v_sales_subtot  numeric := 0;
  v_sales_tax     numeric := 0;
  v_sales_total   numeric := 0;
  v_cash_sales    numeric := 0;
  v_card_sales    numeric := 0;

  -- مصروفات
  v_exp_count     int := 0;
  v_exp_total     numeric := 0;
  v_exp_by_cat    jsonb := '[]'::jsonb;

  -- مشتريات المخزن للشركة
  v_pur_count     int := 0;
  v_pur_total     numeric := 0;

  -- طلبيات الفرع من المخزن
  v_bo_count      int := 0;
  v_bo_total      numeric := 0;

  -- إقفالات وفائض / عجز الكاشير
  v_surplus_total  numeric := 0;
  v_shortage_total numeric := 0;
  v_closings_count int := 0;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة';
  end if;

  if p_branch_id is not null then
    select name into v_branch_name from public.branches where id = p_branch_id;
  end if;

  -- 1. المبيعات
  select
    coalesce(count(*), 0),
    coalesce(sum(subtotal), 0),
    coalesce(sum(vat_amount), 0),
    coalesce(sum(total), 0),
    coalesce(sum(case when coalesce(payment_method, '') ilike any (array['%cash%', '%كاش%', '%نقد%']) then total else 0 end), 0),
    coalesce(sum(case when coalesce(payment_method, '') ilike any (array['%card%', '%visa%', '%pos%', '%network%', '%شبكة%', '%مدى%', '%فيزا%', '%بطاق%']) then total else 0 end), 0)
  into
    v_sales_count, v_sales_subtot, v_sales_tax, v_sales_total, v_cash_sales, v_card_sales
  from public.sales
  where sold_at >= v_from and sold_at <= v_to
    and (p_branch_id is null or branch_id = p_branch_id)
    and status = 'completed';

  -- 2. المصروفات المعتمدة (المقبولة)
  select
    coalesce(count(*), 0),
    coalesce(sum(total), 0)
  into
    v_exp_count, v_exp_total
  from public.expenses
  where created_at >= v_from and created_at <= v_to
    and (p_branch_id is null or branch_id = p_branch_id)
    and coalesce(status, 'approved') != 'rejected';

  -- تفصيل المصروفات حسب التصنيف
  select coalesce(jsonb_agg(jsonb_build_object('category', category, 'total', cat_total)), '[]'::jsonb)
  into v_exp_by_cat
  from (
    select category, sum(total) as cat_total
    from public.expenses
    where created_at >= v_from and created_at <= v_to
      and (p_branch_id is null or branch_id = p_branch_id)
      and coalesce(status, 'approved') != 'rejected'
    group by category
    order by cat_total desc
  ) c;

  -- 3. المشتريات (توريدات المخزن) — خاصة بالشركة أو كإجمالي مشتريات
  select
    coalesce(count(distinct so.id), 0),
    coalesce(sum(coalesce(sol.qty_approved, sol.qty_received, sol.qty_requested, 0) * coalesce(sol.unit_cost, 0)), 0)
  into
    v_pur_count, v_pur_total
  from public.supply_orders so
  join public.supply_order_lines sol on sol.order_id = so.id
  where so.created_at >= v_from and so.created_at <= v_to
    and so.status in ('approved', 'received');

  -- 4. طلبيات الفرع من المخزن الرئيسي
  select
    coalesce(count(distinct bo.id), 0),
    coalesce(sum(coalesce(bol.qty_approved, bol.qty_requested, 0) * coalesce(ii.avg_cost, 0)), 0)
  into
    v_bo_count, v_bo_total
  from public.branch_orders bo
  join public.branch_order_lines bol on bol.order_id = bo.id
  left join public.inventory_items ii on ii.id = bol.item_id
  where bo.created_at >= v_from and bo.created_at <= v_to
    and (p_branch_id is null or bo.branch_id = p_branch_id)
    and bo.status in ('approved', 'delivered', 'received', 'closed');

  -- 5. إقفالات الكاشير (فائض وعجز الكاشير)
  select
    coalesce(count(*), 0),
    coalesce(sum(case when difference > 0 then difference else 0 end), 0),
    coalesce(sum(case when difference < 0 then abs(difference) else 0 end), 0)
  into
    v_closings_count, v_surplus_total, v_shortage_total
  from public.shift_closings
  where closed_at >= v_from and closed_at <= v_to
    and (p_branch_id is null or branch_id = p_branch_id);

  return jsonb_build_object(
    'branch_id',                     p_branch_id,
    'branch_name',                   v_branch_name,
    'from_date',                     v_from,
    'to_date',                       v_to,
    'sales', jsonb_build_object(
      'count',     v_sales_count,
      'subtotal',  round(v_sales_subtot, 2),
      'tax',       round(v_sales_tax, 2),
      'total',     round(v_sales_total, 2),
      'cash',      round(v_cash_sales, 2),
      'card',      round(v_card_sales, 2)
    ),
    'expenses', jsonb_build_object(
      'count',       v_exp_count,
      'total',       round(v_exp_total, 2),
      'by_category', v_exp_by_cat
    ),
    'purchases', jsonb_build_object(
      'count', v_pur_count,
      'total', round(v_pur_total, 2)
    ),
    'branch_warehouse_orders', jsonb_build_object(
      'count', v_bo_count,
      'total', round(v_bo_total, 2)
    ),
    'closings', jsonb_build_object(
      'count',    v_closings_count,
      'surplus',  round(v_surplus_total, 2),
      'shortage', round(v_shortage_total, 2),
      'net_diff', round(v_surplus_total - v_shortage_total, 2)
    )
  );
end;
$$;

grant execute on function public.acc_get_comprehensive_financial_report(timestamptz, timestamptz, uuid) to authenticated;

-- ─── 10. دعم الإحالة من المحاسبة إلى قسم HR ──────────────────────────────────
alter table public.deduction_bonus_requests
  drop constraint if exists deduction_bonus_requests_requested_from_check;

alter table public.deduction_bonus_requests
  add constraint deduction_bonus_requests_requested_from_check
  check (requested_from in ('cashier', 'inventory', 'hr', 'accounting'));

-- ─── 11. ترقيم المصروفات بصيغة EXP-DK-001-000001 (6 خانات) ──────────────────
create or replace function public.create_expense(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_client_id uuid := nullif(p->>'client_id', '')::uuid;
  v_branch_id uuid := nullif(p->>'branch_id', '')::uuid;
  v_session_id uuid := nullif(p->>'session_id', '')::uuid;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat_amount numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_branch public.branches%rowtype;
  v_existing public.expenses%rowtype;
  v_number text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if v_client_id is null then
    raise exception 'معرّف العميل (client_id) مطلوب';
  end if;

  select * into v_existing from public.expenses where client_id = v_client_id;
  if found then
    return jsonb_build_object('id', v_existing.id, 'number', v_existing.number, 'already_exists', true);
  end if;

  if coalesce(trim(p->>'category'), '') = '' then
    raise exception 'نوع / تصنيف المصروف مطلوب';
  end if;

  if v_amount is null or v_amount <= 0 or v_vat_amount < 0 then
    raise exception 'مبلغ المصروف غير صحيح';
  end if;

  if v_branch_id is not null then
    select * into v_branch from public.branches where id = v_branch_id;
  end if;

  v_number := _next_doc_number(
    'expense',
    coalesce(nullif(v_branch.code, ''), 'DK-001'),
    'EXP-{scope}-{n:6}'
  );

  insert into public.expenses (
    client_id, number, branch_id, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes, created_by,
    status
  ) values (
    v_client_id, v_number, v_branch_id, v_session_id, trim(p->>'category'),
    nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat_amount, 2), round(v_amount + v_vat_amount, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), ''), v_uid,
    case when _has_role('accountant', 'owner') then 'approved' else 'pending' end
  ) returning id into v_id;

  return jsonb_build_object('id', v_id, 'number', v_number, 'already_exists', false);
end;
$$;

create or replace function public.acc_add_expense(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_client_id uuid := coalesce(nullif(p->>'client_id', '')::uuid, gen_random_uuid());
  v_branch_id uuid := nullif(p->>'branch_id', '')::uuid;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat_amount numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_branch_code text := 'DK-001';
  v_number text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('accountant', 'owner') then
    raise exception 'إضافة المصروفات من صلاحية المحاسب أو المالك فقط';
  end if;
  if coalesce(trim(p->>'category'), '') = '' then
    raise exception 'نوع / تصنيف المصروف مطلوب';
  end if;
  if v_amount is null or v_amount <= 0 then
    raise exception 'قيمة المصروف يجب أن تكون أكبر من صفر';
  end if;

  if v_branch_id is not null then
    select code into v_branch_code from public.branches where id = v_branch_id;
  end if;

  v_number := _next_doc_number(
    'expense',
    coalesce(nullif(v_branch_code, ''), 'DK-001'),
    'EXP-{scope}-{n:6}'
  );

  insert into public.expenses (
    client_id, number, branch_id, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes, created_by,
    status
  ) values (
    v_client_id, v_number, v_branch_id, null, trim(p->>'category'),
    nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat_amount, 2), round(v_amount + v_vat_amount, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), ''), v_uid,
    'approved'
  ) returning id into v_id;

  return jsonb_build_object('id', v_id, 'number', v_number, 'already_exists', false);
end;
$$;

commit;
