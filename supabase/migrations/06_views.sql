-- =============================================================================
-- 06_views.sql
-- Views للتقارير والربط المحاسبي المستقبلي
-- security_invoker = true حتى تعمل RLS بصلاحيات الـ caller
-- قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================

-- =============================================================================
-- § 1 — v_stock_valuation: قيمة المخزون (الكمية × avg_cost لكل صنف ومستودع)
-- =============================================================================

create or replace view public.v_stock_valuation
  with (security_invoker = true)
as
select
  w.id          as warehouse_id,
  w.name        as warehouse_name,
  w.kind        as warehouse_kind,
  i.id          as item_id,
  i.sku,
  i.name        as item_name,
  c.name        as category_name,
  c.kind        as category_kind,
  i.unit_code,
  s.quantity,
  i.avg_cost,
  round(s.quantity * i.avg_cost, 2) as total_value
from public.inventory_stock    s
join public.inventory_items    i on i.id = s.item_id
join public.warehouses         w on w.id = s.warehouse_id
join public.inventory_categories c on c.id = i.category_id
where s.quantity > 0
  and i.is_active = true;

comment on view public.v_stock_valuation is
  'قيمة المخزون الحالية: الكمية × متوسط التكلفة لكل صنف ومستودع.';

-- =============================================================================
-- § 2 — v_low_stock: الأصناف التي رصيدها دون الحد الأدنى في المستودع الرئيسي
-- =============================================================================

create or replace view public.v_low_stock
  with (security_invoker = true)
as
select
  i.id          as item_id,
  i.sku,
  i.name        as item_name,
  c.name        as category_name,
  i.unit_code,
  i.min_level,
  s.quantity    as current_qty,
  i.min_level - s.quantity as shortage,
  i.avg_cost,
  round((i.min_level - s.quantity) * i.avg_cost, 2) as shortage_value
from public.inventory_items       i
join public.inventory_categories  c on c.id = i.category_id
left join public.inventory_stock  s on s.item_id = i.id
  and s.warehouse_id = (select id from public.warehouses where kind = 'main')
where i.is_active = true
  and i.min_level > 0
  and coalesce(s.quantity, 0) <= i.min_level
order by (i.min_level - coalesce(s.quantity, 0)) desc;

comment on view public.v_low_stock is
  'الأصناف التي رصيدها في المستودع الرئيسي أقل من أو يساوي الحد الأدنى.';

-- =============================================================================
-- § 3 — v_kitchen_consumption_daily: الاستهلاك اليومي من المطبخ
-- =============================================================================

create or replace view public.v_kitchen_consumption_daily
  with (security_invoker = true)
as
select
  date_trunc('day', m.occurred_at at time zone
    (select value from public.app_settings where key = 'timezone'))::date as consumption_date,
  m.item_id,
  i.sku,
  i.name       as item_name,
  i.unit_code,
  sum(abs(m.qty_delta))               as total_qty,
  avg(m.unit_cost)                    as avg_unit_cost,
  round(sum(abs(m.qty_delta) * m.unit_cost), 2) as total_cost
from public.inventory_movements m
join public.inventory_items     i on i.id = m.item_id
where m.movement_type = 'kitchen_issue'
group by 1, 2, 3, 4, 5
order by 1 desc, total_cost desc;

comment on view public.v_kitchen_consumption_daily is
  'الاستهلاك اليومي للخامات في المطبخ: الكمية والتكلفة لكل صنف.';

-- =============================================================================
-- § 4 — v_supply_orders_summary: ملخص طلبات التوريد لكل مورد وشهر
-- =============================================================================

create or replace view public.v_supply_orders_summary
  with (security_invoker = true)
as
select
  date_trunc('month', o.created_at at time zone
    (select value from public.app_settings where key = 'timezone'))::date as order_month,
  s.id          as supplier_id,
  s.name        as supplier_name,
  count(o.id)   as order_count,
  sum(l.qty_requested * l.unit_cost)                as total_requested_value,
  sum(coalesce(l.qty_approved, 0) * l.unit_cost)    as total_approved_value,
  sum(coalesce(l.qty_received, 0) * l.unit_cost)    as total_received_value,
  count(case when o.status = 'received' then 1 end) as received_count,
  count(case when o.has_issues           then 1 end) as issues_count
from public.supply_orders       o
join public.suppliers           s on s.id = o.supplier_id
join public.supply_order_lines  l on l.order_id = o.id
group by 1, 2, 3
order by 1 desc, total_received_value desc;

comment on view public.v_supply_orders_summary is
  'ملخص إجماليات طلبات التوريد (مطلوب/معتمد/مستلم/تكلفة) لكل مورد وشهر.';

-- =============================================================================
-- § 5 — v_branch_order_fulfillment: نسبة تلبية طلبات الفروع
-- =============================================================================

create or replace view public.v_branch_order_fulfillment
  with (security_invoker = true)
as
select
  date_trunc('month', o.created_at at time zone
    (select value from public.app_settings where key = 'timezone'))::date as order_month,
  b.id          as branch_id,
  b.name        as branch_name,
  i.id          as item_id,
  i.sku,
  i.name        as item_name,
  i.unit_code,
  sum(l.qty_requested)                 as total_requested,
  sum(coalesce(l.qty_approved, 0))     as total_approved,
  round(
    case when sum(l.qty_requested) > 0
    then sum(coalesce(l.qty_approved, 0)) * 100.0 / sum(l.qty_requested)
    else 0
    end, 1
  )                                    as fulfillment_pct
from public.branch_orders       o
join public.branches            b on b.id = o.branch_id
join public.branch_order_lines  l on l.order_id = o.id
join public.inventory_items     i on i.id = l.item_id
where o.status = 'approved'
group by 1, 2, 3, 4, 5, 6, 7
order by 1 desc, fulfillment_pct asc;

comment on view public.v_branch_order_fulfillment is
  'نسبة تلبية طلبيات الفروع: المطلوب مقابل المعتمد لكل فرع وصنف وشهر.';

-- =============================================================================
-- § 6 — v_stocktake_losses: التالف والعجز والفائض من الجرد
-- =============================================================================

create or replace view public.v_stocktake_losses
  with (security_invoker = true)
as
select
  st.id           as stocktake_id,
  st.number       as stocktake_number,
  st.created_at::date as stocktake_date,
  i.id            as item_id,
  i.sku,
  i.name          as item_name,
  i.unit_code,
  sl.system_qty,
  sl.counted_qty,
  sl.damaged_qty,
  sl.adjust_qty,
  sl.unit_cost,
  round(sl.damaged_qty * sl.unit_cost, 2) as damage_value,
  round(
    case when sl.adjust_qty < 0
    then abs(sl.adjust_qty) * sl.unit_cost
    else 0
    end, 2
  )                                       as shortage_value,
  round(
    case when sl.adjust_qty > 0
    then sl.adjust_qty * sl.unit_cost
    else 0
    end, 2
  )                                       as surplus_value
from public.stocktake_lines  sl
join public.stocktakes        st on st.id = sl.stocktake_id
join public.inventory_items   i  on i.id  = sl.item_id
where sl.damaged_qty > 0 or sl.adjust_qty != 0
order by st.created_at desc;

comment on view public.v_stocktake_losses is
  'التالف والعجز والفائض من الجرديات بقيمتها المالية.';

-- =============================================================================
-- § 7 — v_movements_daily: حركات المخزون اليومية ملخصة
-- =============================================================================

create or replace view public.v_movements_daily
  with (security_invoker = true)
as
select
  date_trunc('day', m.occurred_at at time zone
    (select value from public.app_settings where key = 'timezone'))::date as movement_date,
  w.id          as warehouse_id,
  w.name        as warehouse_name,
  m.movement_type,
  i.id          as item_id,
  i.sku,
  i.name        as item_name,
  c.name        as category_name,
  i.unit_code,
  sum(m.qty_delta)                       as net_qty_delta,
  sum(abs(m.qty_delta))                  as gross_qty,
  round(sum(abs(m.qty_delta) * m.unit_cost), 2) as total_cost
from public.inventory_movements   m
join public.inventory_items       i on i.id = m.item_id
join public.warehouses            w on w.id = m.warehouse_id
join public.inventory_categories  c on c.id = i.category_id
group by 1, 2, 3, 4, 5, 6, 7, 8, 9
order by 1 desc;

comment on view public.v_movements_daily is
  'الحركات اليومية مُلخَّصة لكل نوع حركة وصنف ومستودع.';

-- =============================================================================
-- نهاية الملف
-- =============================================================================
