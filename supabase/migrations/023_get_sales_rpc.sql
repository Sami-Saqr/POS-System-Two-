-- =============================================================================
-- 023_get_sales_rpc.sql
-- RPC لقراءة ملخص المبيعات من جدول sales وshift_closings وexpense_invoices
-- =============================================================================

-- ملخص مبيعات فرع واحد (owner/accountant يجلبون أي فرع، cashier/branch_manager فرعهم فقط)
CREATE OR REPLACE FUNCTION public.get_branch_sales_summary(
  p_branch_id uuid DEFAULT NULL,
  p_from      date  DEFAULT NULL,
  p_to        date  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_role     text;
  v_my_branch uuid;
  v_result   jsonb;
  v_rows     jsonb;
  v_branches jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;

  SELECT role, branch_id INTO v_role, v_my_branch
    FROM public.profiles WHERE id = v_uid AND is_active = true;

  IF v_role IS NULL THEN RAISE EXCEPTION 'حسابك غير مفعّل'; END IF;

  -- cashier / branch_manager: فرعهم فقط
  IF v_role IN ('cashier', 'branch_manager') THEN
    p_branch_id := v_my_branch;
  END IF;

  -- إجمالي المبيعات والعمليات
  SELECT jsonb_build_object(
    'total_sales',    COALESCE(SUM(s.total), 0),
    'count',          COUNT(*),
    'cash_total',     COALESCE(SUM(s.total) FILTER (WHERE s.payment_method = 'cash'), 0),
    'card_total',     COALESCE(SUM(s.total) FILTER (WHERE s.payment_method = 'card'), 0),
    'delivery_total', COALESCE(SUM(s.total) FILTER (WHERE s.payment_method NOT IN ('cash','card')), 0),
    'avg_basket',     ROUND(COALESCE(AVG(s.total), 0), 2),
    'vat_total',      COALESCE(SUM(s.vat_amount), 0),
    'discount_total', COALESCE(SUM(s.discount_amount), 0)
  )
  INTO v_result
  FROM public.sales s
  WHERE s.status = 'completed'
    AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
    AND (p_from IS NULL OR s.sold_at::date >= p_from)
    AND (p_to   IS NULL OR s.sold_at::date <= p_to);

  -- آخر 20 فاتورة
  SELECT jsonb_agg(row_data ORDER BY (row_data->>'sold_at') DESC)
  INTO v_rows
  FROM (
    SELECT jsonb_build_object(
      'id',             s.id,
      'invoice_number', s.invoice_number,
      'branch_id',      s.branch_id,
      'branch_name',    s.branch_name,
      'cashier_name',   s.cashier_name,
      'payment_method', s.payment_method,
      'total',          s.total,
      'sold_at',        s.sold_at
    ) AS row_data
    FROM public.sales s
    WHERE s.status = 'completed'
      AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
      AND (p_from IS NULL OR s.sold_at::date >= p_from)
      AND (p_to   IS NULL OR s.sold_at::date <= p_to)
    ORDER BY s.sold_at DESC
    LIMIT 20
  ) sub;

  -- مبيعات لكل فرع (للـ owner/accountant فقط)
  IF v_role IN ('owner', 'accountant') AND p_branch_id IS NULL THEN
    SELECT jsonb_agg(jsonb_build_object(
      'branch_id',   s.branch_id,
      'branch_name', s.branch_name,
      'total_sales', COALESCE(SUM(s.total), 0),
      'count',       COUNT(*)
    ) ORDER BY SUM(s.total) DESC)
    INTO v_branches
    FROM public.sales s
    WHERE s.status = 'completed'
      AND (p_from IS NULL OR s.sold_at::date >= p_from)
      AND (p_to   IS NULL OR s.sold_at::date <= p_to)
    GROUP BY s.branch_id, s.branch_name;
  END IF;

  RETURN jsonb_build_object(
    'summary',  COALESCE(v_result, '{}'::jsonb),
    'recent',   COALESCE(v_rows, '[]'::jsonb),
    'by_branch', COALESCE(v_branches, '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_branch_sales_summary(uuid, date, date) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_branch_sales_summary(uuid, date, date) TO authenticated;

-- ملخص المصروفات لفرع
CREATE OR REPLACE FUNCTION public.get_branch_expenses_summary(
  p_branch_id uuid DEFAULT NULL,
  p_from      date  DEFAULT NULL,
  p_to        date  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_role     text;
  v_my_branch uuid;
  v_result   jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;

  SELECT role, branch_id INTO v_role, v_my_branch
    FROM public.profiles WHERE id = v_uid AND is_active = true;

  IF v_role IN ('cashier', 'branch_manager') THEN
    p_branch_id := v_my_branch;
  END IF;

  SELECT jsonb_build_object(
    'total_expenses', COALESCE(SUM(e.total), 0),
    'count',          COUNT(*),
    'cash_total',     COALESCE(SUM(e.total) FILTER (WHERE e.payment_method = 'cash'), 0),
    'other_total',    COALESCE(SUM(e.total) FILTER (WHERE e.payment_method != 'cash'), 0)
  )
  INTO v_result
  FROM public.expense_invoices e
  WHERE (p_branch_id IS NULL OR e.branch_id = p_branch_id)
    AND (p_from IS NULL OR e.expense_date >= p_from)
    AND (p_to   IS NULL OR e.expense_date <= p_to);

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_branch_expenses_summary(uuid, date, date) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_branch_expenses_summary(uuid, date, date) TO authenticated;

NOTIFY pgrst, 'reload schema';
