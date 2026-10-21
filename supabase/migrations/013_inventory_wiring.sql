-- =============================================================================
-- 013_inventory_wiring.sql
-- ربط الواجهة بالسيرفر: إلغاء التوريد، استلام بتكلفة السطر،
-- وجلب كل أنواع المستندات (مطبخ/جرد) بترتيب وحد صحيحين
-- =============================================================================

grant select on public.v_stock_valuation to authenticated;
grant select on public.v_low_stock to authenticated;

-- إلغاء طلب توريد — أمين المخزن، قبل المراجعة فقط
create or replace function cancel_supply_order(
  p_order_id         uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_order   record;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'إلغاء طلبات التوريد لأمين المخزن فقط';
  end if;

  select id, status, version into v_order
  from public.supply_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'طلب التوريد غير موجود';
  end if;

  if v_order.status != 'pending_review' then
    raise exception 'لا يمكن إلغاء طلب حالته: %', v_order.status;
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  update public.supply_orders
  set status = 'cancelled'
  where id = p_order_id;

  perform _bump_data_version('inv_supply');

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', p_order_id, 'status', 'cancelled'),
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply')
    )
  );
end;
$$;

grant execute on function cancel_supply_order(uuid, bigint) to authenticated;

-- استلام توريد: يطبّق unit_cost القادم من الواجهة إن وُجد
create or replace function receive_supply_order(
  p_client_id        uuid,
  p_order_id         uuid,
  p_expected_version bigint,
  p_general_note     text  default null,
  p_lines            jsonb default null
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
  v_line_note  text;
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

    if v_item_id is null then
      raise exception 'سطر استلام غير موجود في الطلب';
    end if;

    v_qty_recv  := coalesce((v_line->>'qty_received')::numeric, v_qty_appr);
    v_unit_cost := coalesce((v_line->>'unit_cost')::numeric, v_unit_cost);
    v_line_note := coalesce(nullif(trim(v_line->>'note'), ''), nullif(trim(v_line->>'line_note'), ''));

    if v_qty_recv != v_qty_appr or v_line_note is not null then
      v_has_issues := true;
    end if;

    update public.supply_order_lines
    set qty_received = v_qty_recv,
        unit_cost    = coalesce(v_unit_cost, unit_cost),
        line_note    = coalesce(v_line_note, line_note),
        updated_at   = now()
    where id = (v_line->>'line_id')::uuid;

    if v_qty_recv > 0 then
      v_new_qty := _post_movement(
        v_main_wh_id, v_item_id, 'supply_receipt',
        v_qty_recv, coalesce(v_unit_cost, 0),
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

-- جلب المستندات: كل الأنواع + subquery حتى يعمل ORDER BY / LIMIT
create or replace function inventory_get_documents(
  p_doc_type  text,
  p_branch_id uuid default null,
  p_limit     int  default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result jsonb;
  v_cutoff timestamptz := now() - interval '30 days';
  v_limit  int := least(coalesce(p_limit, 100), 100);
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  case p_doc_type
  when 'supply_orders' then
    if not _has_role('storekeeper', 'accountant') then
      raise exception 'ليس لديك صلاحية';
    end if;

    select coalesce(jsonb_agg(d.doc), '[]'::jsonb)
    into v_result
    from (
      select jsonb_build_object(
        'id',               o.id,
        'number',           o.number,
        'supplier_id',      o.supplier_id,
        'supplier_name',    s.name,
        'expected_date',    o.expected_date,
        'priority',         o.priority,
        'status',           o.status,
        'has_issues',       o.has_issues,
        'notes',            o.notes,
        'rejection_reason', o.rejection_reason,
        'created_at',       o.created_at,
        'updated_at',       o.updated_at,
        'version',          o.version,
        'lines', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id',            l.id,
            'item_id',       l.item_id,
            'qty_requested', l.qty_requested,
            'qty_approved',  l.qty_approved,
            'qty_received',  l.qty_received,
            'unit_cost',     l.unit_cost,
            'line_note',     l.line_note
          ) order by l.created_at), '[]'::jsonb)
          from public.supply_order_lines l where l.order_id = o.id
        )
      ) as doc
      from public.supply_orders o
      join public.suppliers s on s.id = o.supplier_id
      where o.status in ('pending_review', 'approved')
         or o.created_at >= v_cutoff
      order by o.created_at desc
      limit v_limit
    ) d;

  when 'branch_orders' then
    if p_branch_id is not null then
      if not _can_act_for_branch(p_branch_id) then
        raise exception 'ليس لديك صلاحية لهذا الفرع';
      end if;
    else
      if not _has_role('storekeeper', 'accountant') then
        raise exception 'ليس لديك صلاحية';
      end if;
    end if;

    select coalesce(jsonb_agg(d.doc), '[]'::jsonb)
    into v_result
    from (
      select jsonb_build_object(
        'id',               o.id,
        'number',           o.number,
        'branch_id',        o.branch_id,
        'branch_name',      b.name,
        'status',           o.status,
        'notes',            o.notes,
        'rejection_reason', o.rejection_reason,
        'created_at',       o.created_at,
        'updated_at',       o.updated_at,
        'version',          o.version,
        'lines', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id',            l.id,
            'item_id',       l.item_id,
            'qty_requested', l.qty_requested,
            'qty_approved',  l.qty_approved
          ) order by l.created_at), '[]'::jsonb)
          from public.branch_order_lines l where l.order_id = o.id
        )
      ) as doc
      from public.branch_orders o
      join public.branches b on b.id = o.branch_id
      where (p_branch_id is null or o.branch_id = p_branch_id)
        and (o.status = 'submitted' or o.created_at >= v_cutoff)
      order by
        case when o.status = 'submitted' then 0 else 1 end,
        o.created_at desc
      limit v_limit
    ) d;

  when 'kitchen_issues' then
    if not _has_role('storekeeper', 'accountant') then
      raise exception 'ليس لديك صلاحية';
    end if;

    select coalesce(jsonb_agg(d.doc), '[]'::jsonb)
    into v_result
    from (
      select jsonb_build_object(
        'id',         i.id,
        'number',     i.number,
        'cook_plan',  i.cook_plan,
        'chef_name',  i.chef_name,
        'shift',      i.shift,
        'notes',      i.notes,
        'created_at', i.created_at,
        'lines', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id',                 l.id,
            'item_id',            l.item_id,
            'qty',                l.qty,
            'unit_cost_snapshot', l.unit_cost_snapshot
          ) order by l.created_at), '[]'::jsonb)
          from public.kitchen_issue_lines l where l.issue_id = i.id
        )
      ) as doc
      from public.kitchen_issues i
      where i.created_at >= v_cutoff
      order by i.created_at desc
      limit v_limit
    ) d;

  when 'kitchen_batches' then
    if not _has_role('storekeeper', 'accountant') then
      raise exception 'ليس لديك صلاحية';
    end if;

    select coalesce(jsonb_agg(d.doc), '[]'::jsonb)
    into v_result
    from (
      select jsonb_build_object(
        'id',              b.id,
        'number',          b.number,
        'item_id',         b.item_id,
        'quantity',        b.quantity,
        'production_line', b.production_line,
        'produced_at',     b.produced_at,
        'finished_at',     b.finished_at,
        'quality_note',    b.quality_note,
        'created_at',      b.created_at
      ) as doc
      from public.kitchen_batches b
      where b.created_at >= v_cutoff
      order by b.created_at desc
      limit v_limit
    ) d;

  when 'stocktakes' then
    if not _has_role('storekeeper', 'accountant') then
      raise exception 'ليس لديك صلاحية';
    end if;

    select coalesce(jsonb_agg(d.doc), '[]'::jsonb)
    into v_result
    from (
      select jsonb_build_object(
        'id',           st.id,
        'number',       st.number,
        'created_at',   st.created_at,
        'total_items',  st.total_items,
        'total_adjust', st.total_adjust,
        'total_damage', st.total_damage
      ) as doc
      from public.stocktakes st
      order by st.created_at desc
      limit least(v_limit, 30)
    ) d;

  else
    raise exception 'نوع مستند غير معروف: %', p_doc_type;
  end case;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

grant execute on function inventory_get_documents(text, uuid, int) to authenticated;

revoke execute on function public.cancel_supply_order(uuid, bigint) from public, anon;
revoke execute on function public.receive_supply_order(uuid, uuid, bigint, text, jsonb) from public, anon;
revoke execute on function public.inventory_get_documents(text, uuid, integer) from public, anon;
notify pgrst, 'reload schema';