-- =============================================================================
-- 025_activate_owner_and_sales_rpc.sql
-- تفعيل حساب المالك (سمير عاشور) ودعم وسائل الدفع بالعربي (كاش / شبكة)
-- =============================================================================

-- 1. تفعيل حساب samerashour@dietking.com كمالك (Owner)
DO $$
DECLARE
  v_uid uuid;
  v_branch_id uuid;
BEGIN
  SELECT id INTO v_uid FROM auth.users WHERE email = 'samerashour@dietking.com' LIMIT 1;
  SELECT id INTO v_branch_id FROM public.branches WHERE deleted_at IS NULL LIMIT 1;

  IF v_uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, full_name, role, branch_id, is_active)
    VALUES (v_uid, 'سمير عاشور', 'owner', v_branch_id, true)
    ON CONFLICT (id) DO UPDATE
    SET 
      role = 'owner',
      is_active = true,
      full_name = 'سمير عاشور';
  END IF;
END $$;

-- 2. دالة تقارير المبيعات مع دعم وسائل الدفع العربية (كاش، شبكة، مدى)
CREATE OR REPLACE FUNCTION public.get_branch_sales_summary(
  p_branch_id uuid DEFAULT NULL,
  p_from      date  DEFAULT NULL,
  p_to        date  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_result   jsonb;
  v_rows     jsonb;
  v_branches jsonb;
BEGIN
  -- ملخص إجمالي المبيعات
  SELECT jsonb_build_object(
    'total_sales',    COALESCE(SUM(s.total), 0),
    'count',          COUNT(*),
    'cash_total',     COALESCE(SUM(s.total) FILTER (WHERE s.payment_method ILIKE '%كاش%' OR s.payment_method ILIKE '%cash%'), 0),
    'card_total',     COALESCE(SUM(s.total) FILTER (WHERE s.payment_method ILIKE '%شبكة%' OR s.payment_method ILIKE '%مدى%' OR s.payment_method ILIKE '%card%' OR s.payment_method ILIKE '%visa%' OR s.payment_method ILIKE '%pos%'), 0),
    'delivery_total', COALESCE(SUM(s.total) FILTER (WHERE s.payment_method NOT ILIKE '%كاش%' AND s.payment_method NOT ILIKE '%cash%' AND s.payment_method NOT ILIKE '%شبكة%' AND s.payment_method NOT ILIKE '%مدى%' AND s.payment_method NOT ILIKE '%card%' AND s.payment_method NOT ILIKE '%visa%' AND s.payment_method NOT ILIKE '%pos%'), 0),
    'avg_basket',     ROUND(COALESCE(AVG(s.total), 0), 2),
    'vat_total',      COALESCE(SUM(s.vat_amount), 0),
    'discount_total', COALESCE(SUM(s.discount_amount), 0)
  )
  INTO v_result
  FROM public.sales s
  WHERE (s.status IS NULL OR s.status IN ('completed', 'paid'))
    AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
    AND (p_from IS NULL OR s.sold_at::date >= p_from)
    AND (p_to   IS NULL OR s.sold_at::date <= p_to);

  -- آخر 50 فاتورة
  SELECT COALESCE(jsonb_agg(row_data ORDER BY (row_data->>'sold_at') DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT jsonb_build_object(
      'id',             s.id,
      'invoice_number', s.invoice_number,
      'branch_id',      s.branch_id,
      'branch_name',    COALESCE(s.branch_name, b.name, 'فرع رئيسي'),
      'cashier_name',   COALESCE(s.cashier_name, 'كاشير'),
      'payment_method', s.payment_method,
      'total',          s.total,
      'sold_at',        s.sold_at
    ) AS row_data
    FROM public.sales s
    LEFT JOIN public.branches b ON b.id = s.branch_id
    WHERE (s.status IS NULL OR s.status IN ('completed', 'paid'))
      AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
      AND (p_from IS NULL OR s.sold_at::date >= p_from)
      AND (p_to   IS NULL OR s.sold_at::date <= p_to)
    ORDER BY s.sold_at DESC
    LIMIT 50
  ) sub;

  -- مبيعات كل فرع للجدول والرسم البياني
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'branch_id',      sub.branch_id,
    'branch_name',    sub.branch_name,
    'total_sales',    sub.total_sales,
    'count',          sub.order_count,
    'cash_total',     sub.cash_total,
    'card_total',     sub.card_total,
    'delivery_total', sub.delivery_total
  ) ORDER BY sub.total_sales DESC), '[]'::jsonb)
  INTO v_branches
  FROM (
    SELECT 
      s.branch_id,
      COALESCE(s.branch_name, b.name, 'فرع') AS branch_name,
      COALESCE(SUM(s.total), 0) AS total_sales,
      COUNT(*) AS order_count,
      COALESCE(SUM(s.total) FILTER (WHERE s.payment_method ILIKE '%كاش%' OR s.payment_method ILIKE '%cash%'), 0) AS cash_total,
      COALESCE(SUM(s.total) FILTER (WHERE s.payment_method ILIKE '%شبكة%' OR s.payment_method ILIKE '%مدى%' OR s.payment_method ILIKE '%card%' OR s.payment_method ILIKE '%visa%' OR s.payment_method ILIKE '%pos%'), 0) AS card_total,
      COALESCE(SUM(s.total) FILTER (WHERE s.payment_method NOT ILIKE '%كاش%' AND s.payment_method NOT ILIKE '%cash%' AND s.payment_method NOT ILIKE '%شبكة%' AND s.payment_method NOT ILIKE '%مدى%' AND s.payment_method NOT ILIKE '%card%' AND s.payment_method NOT ILIKE '%visa%' AND s.payment_method NOT ILIKE '%pos%'), 0) AS delivery_total
    FROM public.sales s
    LEFT JOIN public.branches b ON b.id = s.branch_id
    WHERE (s.status IS NULL OR s.status IN ('completed', 'paid'))
      AND (p_from IS NULL OR s.sold_at::date >= p_from)
      AND (p_to   IS NULL OR s.sold_at::date <= p_to)
    GROUP BY s.branch_id, COALESCE(s.branch_name, b.name, 'فرع')
  ) sub;

  RETURN jsonb_build_object(
    'summary',   COALESCE(v_result, '{}'::jsonb),
    'recent',    COALESCE(v_rows, '[]'::jsonb),
    'by_branch', COALESCE(v_branches, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_branch_sales_summary(uuid, date, date) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.inventory_get_stock(uuid, timestamptz) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.inventory_get_documents(text, uuid, integer) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
