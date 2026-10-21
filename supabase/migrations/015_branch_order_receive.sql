-- =============================================================================
-- 015_branch_order_receive.sql
-- دعم حالة "مستلم" لطلبات الفروع
-- قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================
--
-- مصادر مراجعة الكود:
--  - branch_orders.status check  : 04_documents.sql:1157-1158 (inline، بدون اسم صريح)
--  - notifications.kind check    : 05_notifications.sql:13-21  (inline، بدون اسم صريح)
--  - trigger trg_branch_orders_version: 04_documents.sql:1181-1183 → bump_version()
--  - _notify توقيع              : 05_notifications.sql:69-76
--       _notify(p_kind text, p_audience text[], p_branch_id uuid,
--               p_title text, p_body text, p_payload jsonb) returns void
--  - RLS notifications_read      : 07_security.sql:209-215
--       on public.notifications for select
--       using (audience && _my_audiences()
--              and (branch_id is null or _can_act_for_branch(branch_id))
--              and created_at >= now() - interval '90 days')
-- =============================================================================

-- =============================================================================
-- § 1 — تعديل جدول branch_orders: إضافة حالة 'received' وعمودَي الاستلام
-- =============================================================================

-- أ) أعمدة الاستلام (idempotent)
alter table public.branch_orders
  add column if not exists received_at  timestamptz,
  add column if not exists received_by  uuid references auth.users(id);

-- ب) حذف جميع الـ check constraints على عمود status في branch_orders
--    نبحث عن كل constraint يحتوي النص 'submitted' (القيمة الأولى في الـ check القديم)
--    ونسقطها بحلقة for لضمان إزالة أي نسخة قديمة بأي اسم
do $$
declare
  v_con record;
  v_dropped int := 0;
begin
  for v_con in
    select c.conname
    from pg_constraint c
    join pg_class     t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'branch_orders'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) like '%submitted%'
  loop
    execute format('alter table public.branch_orders drop constraint %I', v_con.conname);
    v_dropped := v_dropped + 1;
    raise notice 'حُذف branch_orders constraint: %', v_con.conname;
  end loop;

  if v_dropped = 0 then
    raise notice 'لم يُعثر على check constraint لـ status — ربما حُذف مسبقاً';
  end if;
end;
$$;

-- ج) أعد تعريف الـ check باسم ثابت ليقبل 'received'
alter table public.branch_orders
  add constraint branch_orders_status_check
  check (status in ('submitted', 'approved', 'rejected', 'cancelled', 'received'));

-- د) تحقق: يجب أن يوجد قيد واحد بالضبط يحتوي 'submitted'
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from pg_constraint c
  join pg_class     t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'branch_orders'
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) like '%submitted%';

  assert v_count = 1,
    format('يجب أن يوجد قيد واحد فقط على status — وجدنا: %', v_count);
  raise notice '✓ branch_orders: قيد status واحد فقط موجود';
end;
$$;

comment on column public.branch_orders.status is
  'submitted → approved/rejected. approved → received. لا تراجع بعد القرار.';
comment on column public.branch_orders.received_at is 'وقت تأكيد الاستلام من الفرع';
comment on column public.branch_orders.received_by is
  'المستخدم الذي أكّد الاستلام (cashier/branch_manager/owner)';

-- =============================================================================
-- § 2 — تعديل notifications.kind ليقبل 'branch_order_received'
-- =============================================================================

-- حذف جميع الـ check constraints على عمود kind في notifications
-- نبحث عن كل constraint يحتوي 'branch_order_submitted' (قيمة فريدة في هذا الجدول)
do $$
declare
  v_con record;
  v_dropped int := 0;
begin
  for v_con in
    select c.conname
    from pg_constraint c
    join pg_class     t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'notifications'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) like '%branch_order_submitted%'
  loop
    execute format('alter table public.notifications drop constraint %I', v_con.conname);
    v_dropped := v_dropped + 1;
    raise notice 'حُذف notifications constraint: %', v_con.conname;
  end loop;

  if v_dropped = 0 then
    raise notice 'لم يُعثر على check constraint لـ kind — ربما حُذف مسبقاً';
  end if;
end;
$$;

-- أعد تعريف الـ check باسم ثابت
alter table public.notifications
  add constraint notifications_kind_check
  check (kind in (
    'supply_submitted',
    'supply_approved',
    'supply_received_issues',
    'low_stock',
    'branch_order_submitted',
    'branch_order_updated',
    'branch_order_decided',
    'branch_order_received'
  ));

-- تحقق: يجب أن يوجد قيد واحد بالضبط يحتوي 'branch_order_submitted'
do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from pg_constraint c
  join pg_class     t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'notifications'
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) like '%branch_order_submitted%';

  assert v_count = 1,
    format('يجب أن يوجد قيد واحد فقط على kind — وجدنا: %', v_count);
  raise notice '✓ notifications: قيد kind واحد فقط موجود';
end;
$$;

-- =============================================================================
-- § 3 — دالة public.receive_branch_order
-- =============================================================================

create or replace function public.receive_branch_order(
  p_client_id        uuid,
  p_order_id         uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id  uuid := auth.uid();
  v_order    record;
  v_br_name  text;
  v_new_ver  bigint;
begin
  -- ── 1. التحقق من المستخدم ─────────────────────────────────────────────────
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  -- ── 2. قفل الطلب ──────────────────────────────────────────────────────────
  select id, number, status, version, branch_id
  into   v_order
  from   public.branch_orders
  where  id = p_order_id
  for update;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  -- ── 3. التحقق من صلاحية الفرع والدور ────────────────────────────────────
  if not _can_act_for_branch(v_order.branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if not _has_role('cashier', 'branch_manager', 'owner') then
    raise exception 'تأكيد الاستلام للكاشير ومدير الفرع فقط';
  end if;

  -- ── 4. idempotency: لو مستلم بالفعل ارجع نجاحاً بدون أي تغيير ──────────
  if v_order.status = 'received' then
    return jsonb_build_object(
      'ok',  true,
      'doc', jsonb_build_object(
        'id',      v_order.id,
        'number',  v_order.number,
        'status',  v_order.status,
        'version', v_order.version
      ),
      'stamps', jsonb_build_object(
        'branch_orders:' || v_order.branch_id::text,
        coalesce(
          (select version from public.data_versions
            where key = 'branch_orders:' || v_order.branch_id::text),
          0
        )
      )
    );
  end if;

  -- ── 5. يقبل فقط الحالة 'approved' ────────────────────────────────────────
  if v_order.status != 'approved' then
    raise exception 'لا يمكن تأكيد استلام طلب بحالة: %', v_order.status;
  end if;

  -- ── 6. التحقق من الإصدار ─────────────────────────────────────────────────
  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  -- ── 7. تحديث الحالة
  --    trigger trg_branch_orders_version (04_documents.sql:1181) يزيد version تلقائياً
  update public.branch_orders
  set    status      = 'received',
         received_at = now(),
         received_by = v_user_id
  where  id          = p_order_id;

  -- ── 8. بمب البصمة ─────────────────────────────────────────────────────────
  perform _bump_data_version('branch_orders:' || v_order.branch_id::text);

  -- ── 9. إشعار لجمهور warehouse ─────────────────────────────────────────────
  --    _notify: 05_notifications.sql:69
  select name into v_br_name from public.branches where id = v_order.branch_id;

  perform _notify(
    'branch_order_received',
    array['warehouse'],
    v_order.branch_id,
    'استلام طلبية فرع: ' || v_order.number,
    'الفرع: ' || coalesce(v_br_name, v_order.branch_id::text) || ' — تم تأكيد الاستلام',
    jsonb_build_object(
      'ref_type', 'branch_order',
      'ref_id',   p_order_id,
      'domains',  array['branch_orders:' || v_order.branch_id::text]
    )
  );

  -- ── 10. اقرأ الـ version الجديد (بعد trigger) ────────────────────────────
  select version into v_new_ver from public.branch_orders where id = p_order_id;

  -- ── 11. الرد ──────────────────────────────────────────────────────────────
  return jsonb_build_object(
    'ok',  true,
    'doc', jsonb_build_object(
      'id',      v_order.id,
      'number',  v_order.number,
      'status',  'received',
      'version', v_new_ver
    ),
    'stamps', jsonb_build_object(
      'branch_orders:' || v_order.branch_id::text,
      coalesce(
        (select version from public.data_versions
          where key = 'branch_orders:' || v_order.branch_id::text),
        0
      )
    )
  );
end;
$$;

revoke execute on function public.receive_branch_order(uuid, uuid, bigint)
  from public, anon;
grant  execute on function public.receive_branch_order(uuid, uuid, bigint)
  to   authenticated;

comment on function public.receive_branch_order(uuid, uuid, bigint) is
  'تأكيد استلام طلبية فرع معتمدة — cashier/branch_manager/owner فقط.
   Idempotent: لو الطلب received بالفعل يرجع نجاحاً بدون تغيير.
   يقبل فقط approved. يبمب branch_orders:<branch_id>. يُشعر warehouse.';

notify pgrst, 'reload schema';

-- =============================================================================
-- نهاية الملف
-- =============================================================================
