-- =============================================================================
-- 07_security.sql
-- الأمان: RLS وسياسات القراءة و GRANT / REVOKE
-- يُشغَّل بعد كل الملفات الأخرى
-- قابل للتشغيل أكثر من مرة (idempotent — يُسقط السياسات ويُعيد إنشاءها)
-- =============================================================================

-- =============================================================================
-- § 1 — data_versions و doc_counters و admin_approvals
--       لا يقرأها التطبيق مباشرة — فقط عبر RPCs
-- =============================================================================

-- data_versions: قراءة فقط لأي مستخدم مسجّل (للـ stamps)
drop policy if exists "data_versions_read" on public.data_versions;
create policy "data_versions_read"
  on public.data_versions for select
  using (auth.uid() is not null);

-- doc_counters: ممنوع القراءة المباشرة
-- لا توجد سياسة select — كل الوصول عبر RPCs security definer

-- admin_approvals: ممنوع القراءة المباشرة
-- لا توجد سياسة select

-- =============================================================================
-- § 2 — inventory_units: قراءة لأي مستخدم مسجّل
-- =============================================================================

drop policy if exists "inventory_units_read" on public.inventory_units;
create policy "inventory_units_read"
  on public.inventory_units for select
  using (auth.uid() is not null);

-- =============================================================================
-- § 3 — inventory_categories: قراءة لأي مستخدم مسجّل
-- =============================================================================

drop policy if exists "inventory_categories_read" on public.inventory_categories;
create policy "inventory_categories_read"
  on public.inventory_categories for select
  using (auth.uid() is not null);

-- =============================================================================
-- § 4 — inventory_items: قراءة لأي مستخدم مسجّل
-- =============================================================================

drop policy if exists "inventory_items_read" on public.inventory_items;
create policy "inventory_items_read"
  on public.inventory_items for select
  using (auth.uid() is not null);

-- =============================================================================
-- § 5 — suppliers: قراءة لأمين المخزن والمحاسب والمالك
-- =============================================================================

drop policy if exists "suppliers_read" on public.suppliers;
create policy "suppliers_read"
  on public.suppliers for select
  using (_has_role('storekeeper', 'accountant'));

-- =============================================================================
-- § 6 — warehouses: قراءة لأمين المخزن والمحاسب والمالك
-- =============================================================================

drop policy if exists "warehouses_read" on public.warehouses;
create policy "warehouses_read"
  on public.warehouses for select
  using (_has_role('storekeeper', 'accountant'));

-- =============================================================================
-- § 7 — inventory_stock: قراءة حسب نوع المستودع
-- =============================================================================

drop policy if exists "inventory_stock_read_main" on public.inventory_stock;
create policy "inventory_stock_read_main"
  on public.inventory_stock for select
  using (
    -- المستودع الرئيسي: للأدوار الإدارية فقط
    (
      exists (select 1 from public.warehouses w where w.id = warehouse_id and w.kind = 'main')
      and _has_role('storekeeper', 'accountant')
    )
    or
    -- مستودع الفرع: لمن يحق له التصرف لهذا الفرع
    (
      exists (
        select 1 from public.warehouses w
        where w.id = warehouse_id
          and w.kind = 'branch'
          and _can_act_for_branch(w.branch_id)
      )
    )
  );

-- =============================================================================
-- § 8 — inventory_movements: قراءة للأدوار الإدارية فقط
-- =============================================================================

drop policy if exists "inventory_movements_read" on public.inventory_movements;
create policy "inventory_movements_read"
  on public.inventory_movements for select
  using (_has_role('storekeeper', 'accountant'));

-- =============================================================================
-- § 9 — supply_orders: قراءة للأدوار الإدارية
-- =============================================================================

drop policy if exists "supply_orders_read" on public.supply_orders;
create policy "supply_orders_read"
  on public.supply_orders for select
  using (_has_role('storekeeper', 'accountant'));

drop policy if exists "supply_order_lines_read" on public.supply_order_lines;
create policy "supply_order_lines_read"
  on public.supply_order_lines for select
  using (
    exists (
      select 1 from public.supply_orders o
      where o.id = order_id
        and _has_role('storekeeper', 'accountant')
    )
  );

-- =============================================================================
-- § 10 — kitchen_issues و kitchen_batches: قراءة للأدوار الإدارية
-- =============================================================================

drop policy if exists "kitchen_issues_read" on public.kitchen_issues;
create policy "kitchen_issues_read"
  on public.kitchen_issues for select
  using (_has_role('storekeeper', 'accountant'));

drop policy if exists "kitchen_issue_lines_read" on public.kitchen_issue_lines;
create policy "kitchen_issue_lines_read"
  on public.kitchen_issue_lines for select
  using (
    exists (
      select 1 from public.kitchen_issues ki
      where ki.id = issue_id
        and _has_role('storekeeper', 'accountant')
    )
  );

drop policy if exists "kitchen_batches_read" on public.kitchen_batches;
create policy "kitchen_batches_read"
  on public.kitchen_batches for select
  using (_has_role('storekeeper', 'accountant'));

-- =============================================================================
-- § 11 — stocktakes: قراءة للأدوار الإدارية
-- =============================================================================

drop policy if exists "stocktakes_read" on public.stocktakes;
create policy "stocktakes_read"
  on public.stocktakes for select
  using (_has_role('storekeeper', 'accountant'));

drop policy if exists "stocktake_lines_read" on public.stocktake_lines;
create policy "stocktake_lines_read"
  on public.stocktake_lines for select
  using (
    exists (
      select 1 from public.stocktakes st
      where st.id = stocktake_id
        and _has_role('storekeeper', 'accountant')
    )
  );

-- =============================================================================
-- § 12 — branch_orders: قراءة حسب الفرع والدور
-- =============================================================================

drop policy if exists "branch_orders_read" on public.branch_orders;
create policy "branch_orders_read"
  on public.branch_orders for select
  using (
    _has_role('storekeeper', 'accountant')
    or _can_act_for_branch(branch_id)
  );

drop policy if exists "branch_order_lines_read" on public.branch_order_lines;
create policy "branch_order_lines_read"
  on public.branch_order_lines for select
  using (
    exists (
      select 1 from public.branch_orders o
      where o.id = order_id
        and (
          _has_role('storekeeper', 'accountant')
          or _can_act_for_branch(o.branch_id)
        )
    )
  );

-- =============================================================================
-- § 13 — inventory_imports: قراءة للأدوار الإدارية
-- =============================================================================

drop policy if exists "inventory_imports_read" on public.inventory_imports;
create policy "inventory_imports_read"
  on public.inventory_imports for select
  using (_has_role('storekeeper', 'accountant'));

-- =============================================================================
-- § 14 — notifications: قراءة حسب الجمهور
-- =============================================================================

drop policy if exists "notifications_read" on public.notifications;
create policy "notifications_read"
  on public.notifications for select
  using (
    audience && _my_audiences()
    and (branch_id is null or _can_act_for_branch(branch_id))
    and created_at >= now() - interval '90 days'
  );

-- =============================================================================
-- § 15 — notification_reads: المستخدم يقرأ سجلات قراءته فقط
-- =============================================================================

drop policy if exists "notification_reads_read" on public.notification_reads;
create policy "notification_reads_read"
  on public.notification_reads for select
  using (user_id = auth.uid());

-- =============================================================================
-- § 16 — REVOKE الكتابة المباشرة لكل الجداول الجديدة
--         التطبيق ممنوع يكتب في أي جدول مباشرة — فقط عبر RPCs security definer
-- =============================================================================

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'inventory_units',
    'inventory_categories',
    'inventory_items',
    'warehouses',
    'inventory_stock',
    'inventory_movements',
    'suppliers',
    'supply_orders',
    'supply_order_lines',
    'kitchen_issues',
    'kitchen_issue_lines',
    'kitchen_batches',
    'stocktakes',
    'stocktake_lines',
    'branch_orders',
    'branch_order_lines',
    'inventory_imports',
    'notifications',
    'notification_reads',
    'data_versions',
    'doc_counters',
    'admin_approvals'
  ]
  loop
    execute format('revoke insert, update, delete on public.%I from anon, authenticated', tbl);
  end loop;
end;
$$;

-- =============================================================================
-- § 17 — GRANT SELECT لجداول القراءة المباشرة عبر PostgREST (الكتالوج)
--         باقي الجداول تُقرأ فقط عبر RPCs
-- =============================================================================

grant select on public.inventory_units      to authenticated;
grant select on public.inventory_categories to authenticated;
grant select on public.inventory_items      to authenticated;
grant select on public.data_versions        to authenticated;

-- الجداول الإدارية: تُقرأ عبر RLS المعرّفة أعلاه
grant select on public.suppliers            to authenticated;
grant select on public.warehouses           to authenticated;
grant select on public.inventory_stock      to authenticated;
grant select on public.inventory_movements  to authenticated;
grant select on public.supply_orders        to authenticated;
grant select on public.supply_order_lines   to authenticated;
grant select on public.kitchen_issues       to authenticated;
grant select on public.kitchen_issue_lines  to authenticated;
grant select on public.kitchen_batches      to authenticated;
grant select on public.stocktakes           to authenticated;
grant select on public.stocktake_lines      to authenticated;
grant select on public.branch_orders        to authenticated;
grant select on public.branch_order_lines   to authenticated;
grant select on public.inventory_imports    to authenticated;
grant select on public.notifications        to authenticated;
grant select on public.notification_reads   to authenticated;

-- =============================================================================
-- نهاية الملف
-- =============================================================================
