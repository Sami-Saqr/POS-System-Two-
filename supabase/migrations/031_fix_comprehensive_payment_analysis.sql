-- يعالج القيم العربية والإنجليزية التي كانت ولا تزال محفوظة في payment_method.
-- هذا ترحيل مستقل حتى يصلح قاعدة البيانات حتى لو كان 030 قد طُبّق مسبقاً.

create or replace function public.acc_get_comprehensive_financial_report(
  p_from timestamptz,
  p_to timestamptz,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_from timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to timestamptz := coalesce(p_to, now());
  v_branch_name text := 'الشركة كاملة — جميع الفروع';
  v_sales_count int := 0; v_sales_subtot numeric := 0; v_sales_tax numeric := 0;
  v_sales_total numeric := 0; v_cash_sales numeric := 0; v_card_sales numeric := 0;
  v_exp_count int := 0; v_exp_total numeric := 0; v_exp_by_cat jsonb := '[]'::jsonb;
  v_pur_count int := 0; v_pur_total numeric := 0; v_bo_count int := 0; v_bo_total numeric := 0;
  v_surplus_total numeric := 0; v_shortage_total numeric := 0; v_closings_count int := 0;
begin
  if v_uid is null or not _has_role('accountant', 'owner', 'branch_manager') then
    raise exception 'صلاحية مرفوضة';
  end if;
  if p_branch_id is not null then
    select name into v_branch_name from public.branches where id = p_branch_id;
  end if;

  select count(*), coalesce(sum(subtotal), 0), coalesce(sum(vat_amount), 0), coalesce(sum(total), 0),
    coalesce(sum(total) filter (where coalesce(payment_method, '') ilike any (array['%cash%', '%كاش%', '%نقد%'])), 0),
    coalesce(sum(total) filter (where coalesce(payment_method, '') ilike any (array['%card%', '%visa%', '%pos%', '%network%', '%شبكة%', '%مدى%', '%فيزا%', '%بطاق%'])), 0)
  into v_sales_count, v_sales_subtot, v_sales_tax, v_sales_total, v_cash_sales, v_card_sales
  from public.sales
  where sold_at >= v_from and sold_at <= v_to
    and (p_branch_id is null or branch_id = p_branch_id)
    and status = 'completed';

  select count(*), coalesce(sum(total), 0) into v_exp_count, v_exp_total
  from public.expense_invoices
  where status = 'posted'
    and expense_date >= (v_from at time zone 'Africa/Cairo')::date
    and expense_date <= (v_to at time zone 'Africa/Cairo')::date
    and (p_branch_id is null or branch_id = p_branch_id);

  select coalesce(jsonb_agg(jsonb_build_object('category', category, 'total', category_total)), '[]'::jsonb)
  into v_exp_by_cat
  from (
    select category, sum(total) as category_total
    from public.expense_invoices
    where status = 'posted'
      and expense_date >= (v_from at time zone 'Africa/Cairo')::date
      and expense_date <= (v_to at time zone 'Africa/Cairo')::date
      and (p_branch_id is null or branch_id = p_branch_id)
    group by category order by category_total desc
  ) categories;

  select count(distinct so.id), coalesce(sum(coalesce(sol.qty_approved, sol.qty_received, sol.qty_requested, 0) * coalesce(sol.unit_cost, 0)), 0)
  into v_pur_count, v_pur_total
  from public.supply_orders so join public.supply_order_lines sol on sol.order_id = so.id
  where so.created_at >= v_from and so.created_at <= v_to and so.status in ('approved', 'received');

  select count(distinct bo.id), coalesce(sum(coalesce(bol.qty_approved, bol.qty_requested, 0) * coalesce(ii.avg_cost, 0)), 0)
  into v_bo_count, v_bo_total
  from public.branch_orders bo join public.branch_order_lines bol on bol.order_id = bo.id
  left join public.inventory_items ii on ii.id = bol.item_id
  where bo.created_at >= v_from and bo.created_at <= v_to
    and (p_branch_id is null or bo.branch_id = p_branch_id)
    and bo.status in ('approved', 'delivered', 'received', 'closed');

  select count(*), coalesce(sum(case when difference > 0 then difference else 0 end), 0),
    coalesce(sum(case when difference < 0 then abs(difference) else 0 end), 0)
  into v_closings_count, v_surplus_total, v_shortage_total
  from public.shift_closings
  where closed_at >= v_from and closed_at <= v_to
    and (p_branch_id is null or branch_id = p_branch_id);

  return jsonb_build_object(
    'branch_id', p_branch_id, 'branch_name', v_branch_name, 'from_date', v_from, 'to_date', v_to,
    'sales', jsonb_build_object('count', v_sales_count, 'subtotal', round(v_sales_subtot, 2), 'tax', round(v_sales_tax, 2), 'total', round(v_sales_total, 2), 'cash', round(v_cash_sales, 2), 'card', round(v_card_sales, 2)),
    'expenses', jsonb_build_object('count', v_exp_count, 'total', round(v_exp_total, 2), 'by_category', v_exp_by_cat),
    'purchases', jsonb_build_object('count', v_pur_count, 'total', round(v_pur_total, 2)),
    'branch_warehouse_orders', jsonb_build_object('count', v_bo_count, 'total', v_bo_total),
    'closings', jsonb_build_object('count', v_closings_count, 'surplus', round(v_surplus_total, 2), 'shortage', round(v_shortage_total, 2), 'net_diff', round(v_surplus_total - v_shortage_total, 2))
  );
end;
$$;

grant execute on function public.acc_get_comprehensive_financial_report(timestamptz, timestamptz, uuid) to authenticated;
