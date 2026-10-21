-- =============================================================================
-- 026_details_and_movements_rpc.sql
-- دوال استعلام تفاصيل الفواتير، بنود صرف المطبخ، وسجل حركات الصنف
-- =============================================================================

-- 1. دالة جلب تفاصيل الفاتورة وبنودها (الأصناف، الكميات، الأسعار)
CREATE OR REPLACE FUNCTION public.get_sale_details(p_sale_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_sale record;
  v_items jsonb;
BEGIN
  SELECT s.*, coalesce(s.branch_name, b.name, 'فرع') as b_name
  INTO v_sale
  FROM public.sales s
  LEFT JOIN public.branches b ON b.id = s.branch_id
  WHERE s.id = p_sale_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'الفاتورة غير موجودة');
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',            si.id,
    'product_name',  si.product_name,
    'variant_label', si.variant_label,
    'qty',           si.qty,
    'unit_price',    si.unit_price,
    'line_total',    si.line_total
  )), '[]'::jsonb)
  INTO v_items
  FROM public.sale_items si
  WHERE si.sale_id = p_sale_id;

  RETURN jsonb_build_object(
    'id',             v_sale.id,
    'invoice_number', v_sale.invoice_number,
    'branch_id',      v_sale.branch_id,
    'branch_name',    v_sale.b_name,
    'cashier_name',   v_sale.cashier_name,
    'payment_method', v_sale.payment_method,
    'subtotal',       v_sale.subtotal,
    'discount_amount',v_sale.discount_amount,
    'vat_amount',     v_sale.vat_amount,
    'total',          v_sale.total,
    'sold_at',        v_sale.sold_at,
    'status',         v_sale.status,
    'notes',          v_sale.notes,
    'items',          v_items
  );
END;
$$;

-- 2. دالة جلب بنود وتفاصيل إذن صرف المطبخ
CREATE OR REPLACE FUNCTION public.get_kitchen_issue_details(
  p_issue_number text DEFAULT NULL,
  p_issue_id     uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_issue record;
  v_lines jsonb;
BEGIN
  SELECT i.*
  INTO v_issue
  FROM public.kitchen_issues i
  WHERE (p_issue_id IS NOT NULL AND i.id = p_issue_id)
     OR (p_issue_number IS NOT NULL AND i.number = p_issue_number)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'إذن الصرف غير موجود');
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',                 l.id,
    'item_id',            l.item_id,
    'item_name',          coalesce(it.name, 'خامة #' || substring(l.item_id::text, 1, 6)),
    'sku',                it.sku,
    'unit_code',          coalesce(it.unit_code, 'وحدة'),
    'qty',                l.qty,
    'unit_cost_snapshot', l.unit_cost_snapshot,
    'total_cost',         round(l.qty * coalesce(l.unit_cost_snapshot, 0), 2)
  )), '[]'::jsonb)
  INTO v_lines
  FROM public.kitchen_issue_lines l
  LEFT JOIN public.inventory_items it ON it.id = l.item_id
  WHERE l.issue_id = v_issue.id;

  RETURN jsonb_build_object(
    'id',         v_issue.id,
    'number',     v_issue.number,
    'cook_plan',  v_issue.cook_plan,
    'notes',      v_issue.notes,
    'created_at', v_issue.created_at,
    'lines',      v_lines
  );
END;
$$;

-- 3. دالة جلب سجل حركات صنف المخزون (Inventory Movements)
CREATE OR REPLACE FUNCTION public.get_item_movements_history(
  p_item_id uuid,
  p_limit   int DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_item record;
  v_movements jsonb;
BEGIN
  SELECT id, sku, name, unit_code, min_level, avg_cost
  INTO v_item
  FROM public.inventory_items
  WHERE id = p_item_id;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',            m.id,
    'occurred_at',   m.occurred_at,
    'movement_type', m.movement_type,
    'type_label',    case m.movement_type
                       when 'opening' then 'رصيد افتتاحي'
                       when 'supply_receipt' then 'توريد مشتريات'
                       when 'kitchen_issue' then 'صرف للمطبخ'
                       when 'kitchen_output' then 'إنتاج مطبخ تام'
                       when 'branch_transfer_out' then 'تحويل لفرع'
                       when 'branch_transfer_in' then 'استلام من فرع'
                       when 'damage' then 'تالف / هالك'
                       when 'stocktake_adjust' then 'تسوية جرد'
                       else m.movement_type
                     end,
    'qty_delta',     m.qty_delta,
    'balance_after', m.balance_after,
    'unit_cost',     m.unit_cost,
    'warehouse_name',coalesce(w.name, 'المستودع الرئيسي'),
    'ref_type',      m.ref_type,
    'note',          m.note
  ) ORDER BY m.occurred_at DESC), '[]'::jsonb)
  INTO v_movements
  FROM public.inventory_movements m
  LEFT JOIN public.warehouses w ON w.id = m.warehouse_id
  WHERE m.item_id = p_item_id
  ORDER BY m.occurred_at DESC
  LIMIT coalesce(p_limit, 50);

  RETURN jsonb_build_object(
    'item', jsonb_build_object(
      'id',        v_item.id,
      'sku',       v_item.sku,
      'name',      v_item.name,
      'unit_code', v_item.unit_code,
      'avg_cost',  v_item.avg_cost
    ),
    'movements', v_movements
  );
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION public.get_sale_details(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_kitchen_issue_details(text, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_item_movements_history(uuid, int) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
