-- =============================================================================
-- 025_accounting_test.sql
-- اختبارات وحدة وتكامل لقسم الحسابات. لا يُبقي أي بيانات: begin ... rollback.
-- =============================================================================

begin;

do $$
declare
  v_accountant_user_id uuid;
  v_cashier_user_id    uuid;
  v_test_branch        public.branches%rowtype;
  v_summary            jsonb;
  v_inv_overview       jsonb;
  v_sales_total_calc   numeric;
  v_sales_total_rpc    numeric;
  v_stock_val_calc     numeric;
  v_stock_val_rpc      numeric;
  v_rejected           boolean := false;
  v_expenses_res       jsonb;
  v_alerts_res         jsonb;
  v_closings_res       jsonb;
begin
  -- ─────────────────────────────────────────────────────────────────────────
  -- 1. الإعداد قبل التحول إلى authenticated (بصلاحيات postgres الافتراضية)
  -- ─────────────────────────────────────────────────────────────────────────

  -- مستخدم حقيقي من auth.users بالإيميل samerashour@dietking.com
  select id into v_accountant_user_id
  from auth.users
  where email = 'samerashour@dietking.com'
  limit 1;

  assert v_accountant_user_id is not null,
    'يتطلب الاختبار وجود المستخدم samerashour@dietking.com في auth.users';

  -- مستخدم كاشير حقيقي للاختبار السلبي للصلاحيات
  select u.id into v_cashier_user_id
  from auth.users u
  join public.profiles p on p.id = u.id
  where p.role = 'cashier'
    and u.id <> v_accountant_user_id
  limit 1;

  if v_cashier_user_id is null then
    select id into v_cashier_user_id
    from auth.users
    where id <> v_accountant_user_id
    limit 1;
  end if;

  assert v_cashier_user_id is not null,
    'يتطلب الاختبار مستخدم ثانٍ لاختبار رفض الصلاحيات';

  -- فرع نشط
  select * into v_test_branch
  from public.branches
  where is_active = true and deleted_at is null
  limit 1;

  assert v_test_branch.id is not null,
    'يتطلب الاختبار وجود فرع نشط واحد على الأقل';

  -- ضمان الأدوار المطلوبة مؤقتاً داخل جلسة الاختبار الحالية
  update public.profiles
  set role = 'accountant', is_active = true
  where id = v_accountant_user_id;

  update public.profiles
  set role = 'cashier', is_active = true
  where id = v_cashier_user_id;

  -- ─────────────────────────────────────────────────────────────────────────
  -- 2. اختبار الصلاحيات: الكاشير مرفوض من دوال المحاسبة
  -- ─────────────────────────────────────────────────────────────────────────
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_cashier_user_id),
    true
  );
  set local role authenticated;

  begin
    perform public.acc_get_sales_summary(now() - interval '30 days', now());
    v_rejected := false;
  exception when others then
    v_rejected := true;
  end;

  assert v_rejected = true,
    format('فشل الأمان: استطاع الكاشير (%s) الوصول إلى acc_get_sales_summary', v_cashier_user_id);

  begin
    perform public.acc_get_all_expenses(now() - interval '30 days', now());
    v_rejected := false;
  exception when others then
    v_rejected := true;
  end;

  assert v_rejected = true,
    format('فشل الأمان: استطاع الكاشير (%s) الوصول إلى acc_get_all_expenses', v_cashier_user_id);

  -- ─────────────────────────────────────────────────────────────────────────
  -- 3. اختبار المحاسب: samerashour@dietking.com
  -- ─────────────────────────────────────────────────────────────────────────
  perform set_config(
    'request.jwt.claims',
    format('{"sub": "%s", "role": "authenticated"}', v_accountant_user_id),
    true
  );
  set local role authenticated;

  -- أ) مجموع المبيعات = مجموع الفواتير completed
  v_summary := public.acc_get_sales_summary(
    now() - interval '180 days',
    now() + interval '1 day'
  );

  assert v_summary is not null, 'acc_get_sales_summary أرجع null';

  v_sales_total_rpc := coalesce((v_summary->>'total_sales')::numeric, 0);

  select coalesce(sum(total), 0)
  into v_sales_total_calc
  from public.sales
  where status = 'completed'
    and sold_at >= (now() - interval '180 days')
    and sold_at <= (now() + interval '1 day');

  assert v_sales_total_rpc = v_sales_total_calc,
    format('عدم تطابق المبيعات: RPC=%s, حساب مباشر=%s', v_sales_total_rpc, v_sales_total_calc);

  -- ب) قيمة المخزون = quantity × avg_cost
  v_inv_overview := public.acc_get_inventory_overview(false, 100);
  assert v_inv_overview is not null, 'acc_get_inventory_overview أرجع null';

  v_stock_val_rpc := coalesce(((v_inv_overview->'summary')->>'total_value')::numeric, 0);

  select coalesce(sum(coalesce(s.quantity, 0) * coalesce(i.avg_cost, 0)), 0)
  into v_stock_val_calc
  from public.inventory_items i
  left join public.inventory_stock s on s.item_id = i.id and s.warehouse_id = (
    select id from public.warehouses where kind = 'main' limit 1
  )
  where i.is_active = true;

  assert round(v_stock_val_rpc, 2) = round(v_stock_val_calc, 2),
    format('عدم تطابق قيمة المخزون: RPC=%s, حساب مباشر=%s', v_stock_val_rpc, v_stock_val_calc);

  -- ج) قراءة المصروفات المعتمدة من expense_invoices
  v_expenses_res := public.acc_get_all_expenses(
    now() - interval '180 days',
    now() + interval '1 day'
  );
  assert v_expenses_res is not null and v_expenses_res ? 'items',
    format('فشل استدعاء acc_get_all_expenses: %s', v_expenses_res);

  -- د) تنبيهات الـ Dashboard وإقفالات الـ Dashboard (تحقق من سلامة البنية)
  v_alerts_res := public.acc_get_dashboard_alerts();
  assert jsonb_typeof(v_alerts_res) = 'array',
    format('acc_get_dashboard_alerts يجب أن يُعيد مصفوفة jsonb: %s', v_alerts_res);

  v_closings_res := public.acc_get_closings_dashboard(now() - interval '30 days', now());
  assert jsonb_typeof(v_closings_res) = 'array',
    format('acc_get_closings_dashboard يجب أن يُعيد مصفوفة jsonb: %s', v_closings_res);

  raise notice '✅ نجحت جميع اختبارات الحسابات 025_accounting_test.sql بنجاح!';
end;
$$;

rollback;
