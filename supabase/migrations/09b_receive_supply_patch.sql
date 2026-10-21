-- =============================================================================
-- 09b_receive_supply_patch.sql
-- إصلاح بق في receive_supply_order: v_line_rec.item_id غير معيَّن
-- السطر 386 في 04_documents.sql يستخدم v_line_rec.item_id لكن SELECT INTO
-- لا تُعيَّن record كاملاً — يتسبب في خطأ "record is not assigned yet"
-- =============================================================================

create or replace function receive_supply_order(
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
  v_line       jsonb;
  v_main_wh_id uuid;
  v_qty_recv   numeric;
  v_unit_cost  numeric;
  v_qty_appr   numeric;
  v_item_id    uuid;
  v_has_issues boolean := false;
  v_stock_rows jsonb   := '[]'::jsonb;
  v_new_qty    numeric;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'استلام التوريد لأمين المخزن فقط';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للاستلام';
  end if;

  perform 1 from public.supply_orders
  where id = p_order_id and status = 'received';
  if found then
    return jsonb_build_object('ok', true, 'doc',
      jsonb_build_object('id', p_order_id, 'status', 'received'));
  end if;

  select id, status, version into v_order
  from public.supply_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'طلب التوريد غير موجود';
  end if;

  if v_order.status != 'approved' then
    raise exception 'لا يمكن الاستلام — حالة الطلب الحالية: %', v_order.status;
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  select id into v_main_wh_id from public.warehouses where kind = 'main';

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select l.qty_approved, l.unit_cost, l.item_id
    into   v_qty_appr,     v_unit_cost,  v_item_id
    from public.supply_order_lines l
    where l.id = (v_line->>'line_id')::uuid
      and l.order_id = p_order_id;

    v_qty_recv := coalesce((v_line->>'qty_received')::numeric, v_qty_appr);

    if v_qty_recv != v_qty_appr
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
        v_main_wh_id, v_item_id, 'supply_receipt',
        v_qty_recv, v_unit_cost,
        'supply_order', p_order_id, 'استلام من طلب التوريد', v_user_id
      );

      v_stock_rows := v_stock_rows || jsonb_build_object(
        'item_id', v_item_id, 'quantity', v_new_qty
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

  if v_has_issues then
    perform _notify(
      'supply_received_issues', array['accounting'], null,
      'استلام توريد بملاحظات',
      'تم استلام الطلب مع وجود فروقات أو ملاحظات — يُنصح بالمراجعة',
      jsonb_build_object('ref_type', 'supply_order', 'ref_id', p_order_id, 'domains', array['inv_supply', 'inv_stock'])
    );
  end if;

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', p_order_id, 'status', 'received', 'has_issues', v_has_issues),
    'stock',  v_stock_rows,
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply'),
      'inv_stock',  (select version from public.data_versions where key = 'inv_stock'),
      'inv_catalog',(select version from public.data_versions where key = 'inv_catalog')
    )
  );
end;
$$;

grant execute on function receive_supply_order(uuid, uuid, bigint, text, jsonb) to authenticated;
