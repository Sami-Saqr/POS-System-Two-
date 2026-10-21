-- =============================================================================
-- 026_notifications_and_leave_enhancements.sql
-- 1) نظام الإشعارات: جدول notifications + indexes + RLS + Triggers + Realtime
-- 2) استلام فواتير التوريد (RPC receive_supply_order ذرية + مانعة للتكرار)
-- 3) منطق الإجازات في HR: إجازات مدفوعة وبخصم + تحديث حساب الرواتب وشيت الحضور
-- قابل لإعادة التنفيذ (Idempotent)
-- =============================================================================

-- ═════════════════════════════════════════════════════════════════════════════
-- § 1 — جدول الإشعارات (notifications) والفهارس وسياسات RLS
-- ═════════════════════════════════════════════════════════════════════════════

create table if not exists public.notifications (
  id                  uuid primary key default gen_random_uuid(),
  recipient_role      text,
  recipient_user_id   uuid references auth.users(id),
  recipient_branch_id uuid references public.branches(id),
  type                text not null,
  title               text not null,
  body                text not null,
  ref_table           text,
  ref_id              text,
  is_read             boolean not null default false,
  created_at          timestamptz not null default now(),
  read_at             timestamptz
);

-- ضمان وجود كافة الأعمدة في حال وجود جدول سابق
alter table public.notifications add column if not exists recipient_role text;
alter table public.notifications add column if not exists recipient_user_id uuid references auth.users(id);
alter table public.notifications add column if not exists recipient_branch_id uuid references public.branches(id);
alter table public.notifications add column if not exists type text;
alter table public.notifications add column if not exists ref_table text;
alter table public.notifications add column if not exists ref_id text;
alter table public.notifications add column if not exists is_read boolean not null default false;
alter table public.notifications add column if not exists read_at timestamptz;

-- في حال وجود أعمدة من مخطط قديم، إزالة قيود NOT NULL لضمان التوافق
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'notifications' and column_name = 'kind'
  ) then
    alter table public.notifications alter column kind drop not null;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'notifications' and column_name = 'audience'
  ) then
    alter table public.notifications alter column audience drop not null;
  end if;
end $$;

-- الفهارس
create index if not exists idx_notifications_recipient_role_unread
  on public.notifications (recipient_role, is_read);
create index if not exists idx_notifications_recipient_user
  on public.notifications (recipient_user_id);
create index if not exists idx_notifications_recipient_branch
  on public.notifications (recipient_branch_id);
create index if not exists idx_notifications_created_at_desc
  on public.notifications (created_at desc);

-- تفعيل RLS
alter table public.notifications enable row level security;

drop policy if exists notifications_select_policy on public.notifications;
create policy notifications_select_policy on public.notifications
  for select
  to authenticated
  using (
    -- موجه لمستخدم محدد
    recipient_user_id = auth.uid()
    or (
      recipient_user_id is null
      and exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and p.is_active = true
          and (
            p.role = 'owner'
            or (
              p.role = notifications.recipient_role
              and (
                notifications.recipient_branch_id is null
                or notifications.recipient_branch_id = p.branch_id
                or p.role in ('owner', 'accountant', 'storekeeper', 'hr')
              )
            )
          )
      )
    )
  );

drop policy if exists notifications_update_policy on public.notifications;
create policy notifications_update_policy on public.notifications
  for update
  to authenticated
  using (
    recipient_user_id = auth.uid()
    or (
      recipient_user_id is null
      and exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and p.is_active = true
          and (p.role = 'owner' or p.role = notifications.recipient_role)
      )
    )
  )
  with check (
    is_read = true
  );

-- دوال القراءة والتعليم كمقروء
create or replace function public.mark_notification_read(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  update public.notifications
  set is_read = true,
      read_at = now()
  where id = p_id;
end;
$$;
grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.mark_all_notifications_read(
  p_role text default null,
  p_branch_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
begin
  update public.notifications
  set is_read = true,
      read_at = now()
  where is_read = false
    and (
      recipient_user_id = v_uid
      or (
        recipient_user_id is null
        and (p_role is null or recipient_role = p_role)
        and (p_branch_id is null or recipient_branch_id is null or recipient_branch_id = p_branch_id)
      )
    );
end;
$$;
grant execute on function public.mark_all_notifications_read(text, uuid) to authenticated;

-- إضافة notifications إلى supabase_realtime
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename  = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- ═════════════════════════════════════════════════════════════════════════════
-- § 2 — مشغلات قاعدة البيانات (Database Triggers) لإنشاء الإشعارات تلقائياً
-- ═════════════════════════════════════════════════════════════════════════════

-- 2-أ) مشغل طلبات الفرع (branch_orders)
create or replace function public.trg_fn_notify_branch_orders()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_branch_name text;
begin
  select name into v_branch_name
  from public.branches
  where id = NEW.branch_id;

  -- 1. الكاشير يرسل الطلب -> إشعار لأمين المخزن
  if (TG_OP = 'INSERT' and NEW.status in ('submitted', 'pending'))
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'submitted') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'storekeeper', null, null,
      'branch_order_submitted',
      'طلب منتجات جديد',
      'طلب جديد من فرع ' || coalesce(v_branch_name, 'الفرع') || ' (رقم: ' || coalesce(NEW.number, '') || ')',
      'branch_orders', NEW.id::text
    );
  end if;

  -- 2. أمين المخزن يوافق -> إشعار لكاشير نفس الفرع فقط
  if (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status in ('approved', 'in_preparation')) then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'cashier', null, NEW.branch_id,
      'branch_order_approved',
      'الموافقة على طلب المنتجات',
      'تمت الموافقة على طلبك رقم ' || coalesce(NEW.number, '') || ' وجاري التحضير',
      'branch_orders', NEW.id::text
    );
  end if;

  -- 3. الكاشير يؤكد الاستلام -> إشعار لأمين المخزن
  if (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'received') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'storekeeper', null, null,
      'branch_order_received',
      'تأكيد استلام الطلب',
      'فرع ' || coalesce(v_branch_name, 'الفرع') || ' استلم الطلب رقم ' || coalesce(NEW.number, ''),
      'branch_orders', NEW.id::text
    );
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_notify_branch_orders on public.branch_orders;
create trigger trg_notify_branch_orders
  after insert or update of status on public.branch_orders
  for each row execute function public.trg_fn_notify_branch_orders();


-- 2-ب) مشغل طلبات التوريد والشراء (supply_orders)
create or replace function public.trg_fn_notify_supply_orders()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  -- 1. المخزون يرسل طلب شراء -> إشعار للمحاسب
  if (TG_OP = 'INSERT' and NEW.status = 'pending_review')
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'pending_review') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'accountant', null, null,
      'supply_order_submitted',
      'طلب شراء جديد',
      'طلب توريد جديد برقم ' || coalesce(NEW.number, '') || ' بانتظار المراجعة والاعتماد',
      'supply_orders', NEW.id::text
    );
  end if;

  -- 2. المحاسب يوافق -> إشعار للمخزون
  if (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'approved') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'storekeeper', NEW.created_by, null,
      'supply_order_approved',
      'الموافقة على طلب الشراء',
      'تمت الموافقة على طلب التوريد رقم ' || coalesce(NEW.number, '') || ' وجاهز للاستلام',
      'supply_orders', NEW.id::text
    );
  end if;

  -- 3. المحاسب يرفض -> إشعار للمخزون مع السبب
  if (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'rejected') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'storekeeper', NEW.created_by, null,
      'supply_order_rejected',
      'رفض طلب الشراء',
      'تم رفض طلب التوريد رقم ' || coalesce(NEW.number, '') || coalesce(' — السبب: ' || NEW.notes, ''),
      'supply_orders', NEW.id::text
    );
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_notify_supply_orders on public.supply_orders;
create trigger trg_notify_supply_orders
  after insert or update of status on public.supply_orders
  for each row execute function public.trg_fn_notify_supply_orders();


-- 2-ج) مشغل طلبات الإجازات (leave_requests)
create or replace function public.trg_fn_notify_leave_requests()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_emp_name    text;
  v_branch_id   uuid;
  v_job_role    text;
  v_target_role text;
begin
  select full_name, branch_id, job_role
  into v_emp_name, v_branch_id, v_job_role
  from public.employees
  where id = NEW.employee_id;

  -- 1. تقديم طلب إجازة -> إشعار لـ HR
  if (TG_OP = 'INSERT' and NEW.status = 'pending')
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'pending') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'hr', null, null,
      'leave_request_submitted',
      'طلب إجازة جديد',
      'طلب إجازة للموظف ' || coalesce(v_emp_name, 'موظف') || ' من ' || NEW.start_date || ' إلى ' || NEW.end_date,
      'leave_requests', NEW.id::text
    );
  end if;

  -- 2. موافقة أو رفض HR -> إشعار للطالب
  if (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status in ('approved', 'rejected')) then
    v_target_role := case
      when NEW.requested_from = 'cashier' then 'cashier'
      when NEW.requested_from = 'inventory' then 'storekeeper'
      else 'hr'
    end;

    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      v_target_role, NEW.created_by, case when v_target_role = 'cashier' then v_branch_id else null end,
      case when NEW.status = 'approved' then 'leave_request_approved' else 'leave_request_rejected' end,
      case when NEW.status = 'approved' then 'الموافقة على طلب الإجازة' else 'رفض طلب الإجازة' end,
      case
        when NEW.status = 'approved' then
          'تمت الموافقة على إجازة الموظف ' || coalesce(v_emp_name, '') ||
          case when coalesce(NEW.decision_type, '') = 'without_deduction' or coalesce(NEW.is_paid, true) then ' (مدفوعة)' else ' (بخصم)' end
        else
          'تم رفض إجازة الموظف ' || coalesce(v_emp_name, '') || coalesce(' — السبب: ' || NEW.decision_notes, '')
      end,
      'leave_requests', NEW.id::text
    );
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_notify_leave_requests on public.leave_requests;
create trigger trg_notify_leave_requests
  after insert or update of status on public.leave_requests
  for each row execute function public.trg_fn_notify_leave_requests();


-- 2-د) مشغل الخصومات والمكافآت (deduction_bonus_requests)
create or replace function public.trg_fn_notify_deduction_bonus()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_emp_name    text;
  v_branch_id   uuid;
  v_job_role    text;
  v_kind_label  text;
  v_target_role text;
begin
  select full_name, branch_id, job_role
  into v_emp_name, v_branch_id, v_job_role
  from public.employees
  where id = NEW.employee_id;

  v_kind_label := case when NEW.type = 'deduction' then 'خصم' else 'مكافأة' end;

  -- 1. طلب خصم/مكافأة من جهة أخرى -> إشعار لـ HR
  if (TG_OP = 'INSERT' and NEW.status = 'pending' and NEW.requested_from != 'hr')
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'pending' and NEW.requested_from != 'hr') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      'hr', null, null,
      'deduction_bonus_submitted',
      'طلب ' || v_kind_label || ' جديد',
      'طلب ' || v_kind_label || ' للموظف ' || coalesce(v_emp_name, '') || ' مقدم من ' || NEW.requested_from,
      'deduction_bonus_requests', NEW.id::text
    );
  end if;

  -- 2. رد HR على الطلب -> إشعار للطالب
  if (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status in ('approved', 'rejected') and NEW.requested_from != 'hr') then
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      NEW.requested_from, NEW.created_by, null,
      case when NEW.status = 'approved' then 'deduction_bonus_approved' else 'deduction_bonus_rejected' end,
      'قرار طلب ال' || v_kind_label,
      'تم ' || case when NEW.status = 'approved' then 'اعتماد' else 'رفض' end || ' طلب ال' || v_kind_label || ' للموظف ' || coalesce(v_emp_name, ''),
      'deduction_bonus_requests', NEW.id::text
    );
  end if;

  -- 3. تسجيل خصم أو مكافأة مباشرة من HR للموظف -> إشعار لجهة عمل الموظف
  if ((TG_OP = 'INSERT' and NEW.status = 'approved' and NEW.requested_from = 'hr')
      or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'approved' and NEW.requested_from = 'hr')) then
    v_target_role := case
      when v_job_role in ('cashier', 'worker', 'branch_manager') then 'cashier'
      else 'storekeeper'
    end;

    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      v_target_role, null, case when v_target_role = 'cashier' then v_branch_id else null end,
      'deduction_bonus_recorded',
      'تسجيل ' || v_kind_label || ' للموظف',
      'تم تسجيل ' || v_kind_label || ' للموظف ' || coalesce(v_emp_name, '') || ' — ' || coalesce(NEW.notes, ''),
      'deduction_bonus_requests', NEW.id::text
    );
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_notify_deduction_bonus on public.deduction_bonus_requests;
create trigger trg_notify_deduction_bonus
  after insert or update of status on public.deduction_bonus_requests
  for each row execute function public.trg_fn_notify_deduction_bonus();


-- ═════════════════════════════════════════════════════════════════════════════
-- § 3 — استلام فاتورة التوريد في المخزون (RPC receive_supply_order ذرية ومانعة للتكرار)
-- ═════════════════════════════════════════════════════════════════════════════

create or replace function public.receive_supply_order(
  p_client_id        uuid,
  p_order_id         uuid,
  p_expected_version bigint,
  p_general_note     text  default null,
  p_lines            jsonb default null         -- [{line_id, qty_received, unit_cost?, note?}]
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

  if not (_has_role('storekeeper') or _has_role('owner')) then
    raise exception 'استلام التوريد لأمين المخزن أو المالك فقط';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للاستلام';
  end if;

  -- 1. منع الاستلام المكرر (Idempotent)
  perform 1 from public.supply_orders
  where id = p_order_id and status = 'received';
  if found then
    return jsonb_build_object('ok', true, 'already_received', true, 'doc',
      jsonb_build_object('id', p_order_id, 'status', 'received'));
  end if;

  -- 2. قفل الصف للتحقق من الحالة والنسخة
  select id, status, version, number into v_order
  from public.supply_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'طلب التوريد غير موجود';
  end if;

  if v_order.status != 'approved' then
    raise exception 'لا يمكن الاستلام — حالة الطلب الحالية: %', v_order.status;
  end if;

  if p_expected_version is not null and v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  -- 3. تحديد المستودع الرئيسي
  select id into v_main_wh_id from public.warehouses where kind = 'main' limit 1;
  if v_main_wh_id is null then
    raise exception 'المستودع الرئيسي غير معرّف';
  end if;

  -- 4. معالجة بنود الاستلام وإضافة الرصيد وحركة المخزون
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select l.qty_approved, coalesce(l.qty_approved, l.qty_requested), l.unit_cost, l.item_id
    into   v_qty_appr,     v_qty_appr,                                v_unit_cost,  v_item_id
    from public.supply_order_lines l
    where l.id = (v_line->>'line_id')::uuid
      and l.order_id = p_order_id;

    if not found then
      raise exception 'بند التوريد % غير موجود', v_line->>'line_id';
    end if;

    v_qty_recv := coalesce((v_line->>'qty_received')::numeric, v_qty_appr);
    if v_qty_recv < 0 then
      raise exception 'لا يمكن استلام كمية سالبة للصنف %', v_item_id;
    end if;

    if (v_line->>'unit_cost') is not null and (v_line->>'unit_cost')::numeric >= 0 then
      v_unit_cost := (v_line->>'unit_cost')::numeric;
    end if;

    -- إذا كانت الكمية المستلمة تختلف عن المطلوبة/المعتمدة أو يوجد ملاحظة -> تمييز الطلب بوجود فروقات
    if v_qty_recv != v_qty_appr
       or (v_line->>'note' is not null and trim(v_line->>'note') != '') then
      v_has_issues := true;
    end if;

    -- تحديث كمية البند
    update public.supply_order_lines
    set qty_received = v_qty_recv,
        unit_cost    = v_unit_cost,
        line_note    = coalesce(v_line->>'note', line_note),
        updated_at   = now()
    where id = (v_line->>'line_id')::uuid;

    -- إضافة الرصيد وتسجيل حركة المخزون بنوع 'توريد' (supply_receipt)
    if v_qty_recv > 0 then
      v_new_qty := _post_movement(
        v_main_wh_id, v_item_id, 'supply_receipt',
        v_qty_recv, v_unit_cost,
        'supply_order', p_order_id,
        'استلام توريد ' || coalesce(v_order.number, ''),
        v_user_id
      );

      v_stock_rows := v_stock_rows || jsonb_build_object(
        'item_id', v_item_id, 'quantity', v_new_qty
      );
    end if;
  end loop;

  -- 5. تحديث حالة الفاتورة إلى مستلمة مع وسوم الفروقات
  update public.supply_orders
  set status      = 'received',
      has_issues  = v_has_issues,
      notes       = coalesce(p_general_note, notes),
      received_by = v_user_id,
      received_at = now(),
      version     = version + 1,
      updated_at  = now()
  where id = p_order_id;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('inv_stock');
  perform _bump_data_version('inv_catalog');

  return jsonb_build_object(
    'ok',         true,
    'doc',        jsonb_build_object('id', p_order_id, 'status', 'received', 'has_issues', v_has_issues),
    'stock',      v_stock_rows,
    'stamps',     jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply'),
      'inv_stock',  (select version from public.data_versions where key = 'inv_stock'),
      'inv_catalog',(select version from public.data_versions where key = 'inv_catalog')
    )
  );
end;
$$;

grant execute on function public.receive_supply_order(uuid, uuid, bigint, text, jsonb) to authenticated;


-- ═════════════════════════════════════════════════════════════════════════════
-- § 4 — منطق الإجازات وحساب الرواتب في HR (مدفوعة وبخصم)
-- ═════════════════════════════════════════════════════════════════════════════

-- 4-أ) إضافة حقول نوع الإجازة لجدول leave_requests
alter table public.leave_requests add column if not exists is_paid boolean not null default true;
alter table public.leave_requests add column if not exists leave_type text default 'paid';

-- تحديث دالة موافقة/رفض الإجازة لدعم تحديد النوع (مدفوعة / بخصم)
create or replace function public.hr_decide_leave_request(
  p_id            uuid,
  p_status        text,   -- 'approved' | 'rejected'
  p_decision_type text default null,  -- 'with_deduction' | 'without_deduction'
  p_notes         text default null,
  p_is_paid       boolean default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_leave leave_requests%rowtype;
  v_is_paid boolean;
  v_dec_type text;
begin
  if not (public._has_role('hr') or public._has_role('owner')) then
    raise exception using errcode='42501', message='غير مصرح لك باتخاذ قرار الإجازات';
  end if;

  if p_status not in ('approved','rejected') then
    raise exception 'قرار غير صحيح';
  end if;

  select * into v_leave from public.leave_requests where id = p_id;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_leave.status <> 'pending' then raise exception 'الطلب تمت معالجته مسبقاً'; end if;

  -- تحديد هل الإجازة مدفوعة أم بخصم
  if p_is_paid is not null then
    v_is_paid := p_is_paid;
    v_dec_type := case when p_is_paid then 'without_deduction' else 'with_deduction' end;
  elsif p_decision_type is not null then
    v_dec_type := p_decision_type;
    v_is_paid := (p_decision_type = 'without_deduction');
  else
    v_is_paid := true;
    v_dec_type := 'without_deduction';
  end if;

  update public.leave_requests
  set status         = p_status,
      decision_type  = v_dec_type,
      is_paid        = v_is_paid,
      leave_type     = case when v_is_paid then 'paid' else 'unpaid' end,
      decided_by     = auth.uid(),
      decided_at     = now(),
      decision_notes = p_notes,
      updated_at     = now()
  where id = p_id;

  return jsonb_build_object('id', p_id, 'status', p_status, 'is_paid', v_is_paid);
end;
$$;
grant execute on function public.hr_decide_leave_request(uuid, text, text, text, boolean) to authenticated;


-- 4-ب) تحديث دالة التقرير الشامل لحساب الرواتب بدقة:
-- الإجازة المدفوعة = تُحتسب كيوم حضور (معدل اليوم كامل بدون أي خصم)
-- الإجازة بخصم   = خصم يوم واحد من الراتب
create or replace function public.hr_get_comprehensive_report(
  p_start_date date,
  p_end_date   date
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_retention_cutoff date;
  v_report_result    jsonb;
begin
  if not (public._has_role('hr') or public._has_role('owner')) then
    raise exception using errcode='42501', message='غير مصرح لك بالوصول لتقارير الموارد البشرية';
  end if;

  if p_end_date < p_start_date then
    raise exception 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
  end if;

  if extract(day from current_date) >= 5 then
    v_retention_cutoff := date_trunc('month', current_date - interval '1 month')::date;
  else
    v_retention_cutoff := date_trunc('month', current_date - interval '2 month')::date;
  end if;

  if p_start_date < v_retention_cutoff then
    raise exception 'التاريخ المختار خارج نطاق البيانات المحفوظة (أقدم تاريخ متاح هو %)', v_retention_cutoff;
  end if;

  with emp_ranges as (
    select
      e.id,
      e.code,
      e.full_name,
      e.job_role,
      e.branch_id,
      b.name as branch_name,
      e.basic_salary,
      e.allowances,
      e.transport_allowance,
      e.status,
      e.hire_date,
      e.created_at,
      greatest(p_start_date, coalesce(e.hire_date, e.created_at::date)) as eff_start,
      case
        when e.status in ('archived', 'terminated', 'suspended') then
          least(p_end_date, coalesce(e.termination_date, e.suspension_start, e.status_changed_at::date, e.updated_at::date))
        else p_end_date
      end as eff_end
    from public.employees e
    left join public.branches b on b.id = e.branch_id
  ),
  att_stats as (
    select
      er.id as employee_id,
      count(*) filter (where ar.status = 'present')  as present_days,
      count(*) filter (where ar.status = 'absent')   as absent_days,
      count(*) filter (where ar.status = 'on_leave') as total_leave_days
    from emp_ranges er
    left join public.attendance_records ar
      on ar.employee_id = er.id
     and ar.record_date between er.eff_start and er.eff_end
    where er.eff_start <= er.eff_end
    group by er.id
  ),
  leave_split as (
    select
      er.id as employee_id,
      -- إجازات مدفوعة (بدون خصم)
      count(distinct d::date) filter (where lr.is_paid = true or lr.decision_type = 'without_deduction') as paid_leave_days,
      -- إجازات بخصم
      count(distinct d::date) filter (where lr.is_paid = false or lr.decision_type = 'with_deduction') as unpaid_leave_days
    from emp_ranges er
    join public.leave_requests lr on lr.employee_id = er.id
    cross join lateral generate_series(lr.start_date, lr.end_date, interval '1 day') as d
    where lr.status = 'approved'
      and d::date between er.eff_start and er.eff_end
      and er.eff_start <= er.eff_end
    group by er.id
  ),
  ded_bonus_stats as (
    select
      er.id as employee_id,
      coalesce(sum(case
        when dbr.type = 'deduction' and dbr.notes not like 'خصم إجازة:%'
        then dbr.final_cash_amount else 0
      end), 0) as manual_deductions,
      coalesce(sum(case
        when dbr.type = 'bonus'
        then dbr.final_cash_amount else 0
      end), 0) as total_additions
    from emp_ranges er
    left join public.deduction_bonus_requests dbr
      on dbr.employee_id = er.id
     and dbr.status = 'approved'
     and dbr.created_at::date between er.eff_start and er.eff_end
    where er.eff_start <= er.eff_end
    group by er.id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'employee_id',               er.id,
      'code',                      er.code,
      'full_name',                 er.full_name,
      'job_role',                  er.job_role,
      'branch_name',               coalesce(er.branch_name, 'المركز الرئيسي'),
      'status',                    er.status,
      'basic_salary',              er.basic_salary,
      'allowances',                er.allowances,
      'transport_allowance',       er.transport_allowance,
      'effective_start',           er.eff_start,
      'effective_end',             er.eff_end,
      'is_in_range',               (er.eff_start <= er.eff_end),
      'present_days',              coalesce(att.present_days, 0),
      'absent_days',               coalesce(att.absent_days, 0),
      'leave_days',                coalesce(att.total_leave_days, 0),
      'paid_leave_days',           coalesce(ls.paid_leave_days, 0),
      'leave_with_deduction_days', coalesce(ls.unpaid_leave_days, 0),
      'daily_rate',                round((er.basic_salary / 30.0), 2),
      -- خصم الغياب: 2 يوم × معدل اليوم
      'absence_deduction',         round(coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0), 2),
      -- خصم الإجازة بخصم: 1 يوم × معدل اليوم
      'leave_deduction',           round(coalesce(ls.unpaid_leave_days, 0) * (er.basic_salary / 30.0), 2),
      'manual_deductions',         round(coalesce(dbs.manual_deductions, 0), 2),
      'total_deductions',          round(
        (coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0)) +
        (coalesce(ls.unpaid_leave_days, 0) * (er.basic_salary / 30.0)) +
        coalesce(dbs.manual_deductions, 0), 2
      ),
      'total_additions',           round(coalesce(dbs.total_additions, 0), 2),
      -- صافي الراتب = ((أيام الحضور الفعلية + أيام الإجازة المدفوعة) × معدل اليوم) - الخصومات + المكافآت
      'net_salary',                round(
        ((coalesce(att.present_days, 0) + coalesce(ls.paid_leave_days, 0)) * (er.basic_salary / 30.0)) -
        ((coalesce(att.absent_days, 0) * 2 * (er.basic_salary / 30.0)) +
         (coalesce(ls.unpaid_leave_days, 0) * (er.basic_salary / 30.0)) +
         coalesce(dbs.manual_deductions, 0)) +
        coalesce(dbs.total_additions, 0), 2
      )
    ) order by er.full_name
  ), '[]'::jsonb) into v_report_result
  from emp_ranges er
  left join att_stats att        on att.employee_id = er.id
  left join leave_split ls       on ls.employee_id  = er.id
  left join ded_bonus_stats dbs  on dbs.employee_id = er.id;

  return v_report_result;
end;
$$;
grant execute on function public.hr_get_comprehensive_report(date, date) to authenticated;


-- 4-ج) تقرير موظف واحد تفصيلي
create or replace function public.hr_get_employee_report(
  p_employee_id uuid,
  p_start_date  date,
  p_end_date    date
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_retention_cutoff date;
  v_emp              public.employees%rowtype;
  v_branch_name      text;
  v_eff_start        date;
  v_eff_end          date;
  v_present_days     int     := 0;
  v_absent_days      int     := 0;
  v_leave_days       int     := 0;
  v_paid_leave_days  int     := 0;
  v_leave_ded_days   int     := 0;
  v_manual_ded       numeric := 0;
  v_total_bonuses    numeric := 0;
  v_daily_rate       numeric := 0;
  v_absence_ded      numeric := 0;
  v_leave_ded        numeric := 0;
  v_total_ded        numeric := 0;
  v_net_salary       numeric := 0;
  v_daily_records    jsonb;
begin
  if not (public._has_role('hr') or public._has_role('owner')) then
    raise exception using errcode='42501', message='غير مصرح لك بالوصول لتقارير الموارد البشرية';
  end if;

  select e.*, b.name into v_emp
  from public.employees e
  left join public.branches b on b.id = e.branch_id
  where e.id = p_employee_id;

  if v_emp.id is null then
    raise exception 'الموظف غير موجود';
  end if;

  if extract(day from current_date) >= 5 then
    v_retention_cutoff := date_trunc('month', current_date - interval '1 month')::date;
  else
    v_retention_cutoff := date_trunc('month', current_date - interval '2 month')::date;
  end if;

  if p_start_date < v_retention_cutoff then
    raise exception 'التاريخ المختار خارج نطاق البيانات المحفوظة (أقدم تاريخ متاح هو %)', v_retention_cutoff;
  end if;

  v_eff_start := greatest(p_start_date, coalesce(v_emp.hire_date, v_emp.created_at::date));
  if v_emp.status in ('archived', 'terminated', 'suspended') then
    v_eff_end := least(p_end_date, coalesce(v_emp.termination_date, v_emp.suspension_start, v_emp.status_changed_at::date, v_emp.updated_at::date));
  else
    v_eff_end := p_end_date;
  end if;

  v_daily_rate := round(v_emp.basic_salary / 30.0, 2);

  if v_eff_start <= v_eff_end then
    select
      count(*) filter (where status = 'present'),
      count(*) filter (where status = 'absent'),
      count(*) filter (where status = 'on_leave')
    into v_present_days, v_absent_days, v_leave_days
    from public.attendance_records
    where employee_id = p_employee_id
      and record_date between v_eff_start and v_eff_end;

    -- أيام الإجازة المدفوعة
    select count(distinct d::date) into v_paid_leave_days
    from public.leave_requests lr
    cross join lateral generate_series(lr.start_date, lr.end_date, interval '1 day') as d
    where lr.employee_id = p_employee_id
      and lr.status = 'approved'
      and (lr.is_paid = true or lr.decision_type = 'without_deduction')
      and d::date between v_eff_start and v_eff_end;

    -- أيام الإجازة بخصم
    select count(distinct d::date) into v_leave_ded_days
    from public.leave_requests lr
    cross join lateral generate_series(lr.start_date, lr.end_date, interval '1 day') as d
    where lr.employee_id = p_employee_id
      and lr.status = 'approved'
      and (lr.is_paid = false or lr.decision_type = 'with_deduction')
      and d::date between v_eff_start and v_eff_end;

    select
      coalesce(sum(case
        when type = 'deduction' and notes not like 'خصم إجازة:%'
        then final_cash_amount else 0
      end), 0),
      coalesce(sum(case
        when type = 'bonus'
        then final_cash_amount else 0
      end), 0)
    into v_manual_ded, v_total_bonuses
    from public.deduction_bonus_requests
    where employee_id = p_employee_id
      and status = 'approved'
      and created_at::date between v_eff_start and v_eff_end;

    -- تفاصيل الأيام
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'date',            d::date,
        'status',          coalesce(ar.status, 'unrecorded'),
        'status_label',    case
          when ar.status = 'present'  then 'حاضر'
          when ar.status = 'absent'   then 'غائب'
          when ar.status = 'on_leave' then 'إجازة'
          else 'غير مسجل'
        end,
        'is_paid_leave',   case
          when ar.status = 'on_leave' and exists (
            select 1 from public.leave_requests lr
            where lr.employee_id = p_employee_id
              and lr.status = 'approved'
              and (lr.is_paid = true or lr.decision_type = 'without_deduction')
              and d::date between lr.start_date and lr.end_date
          ) then true
          else false
        end,
        'notes',           ar.notes,
        'deduction_days',  case
          when ar.status = 'absent' then 2.0
          when ar.status = 'on_leave' and exists (
            select 1 from public.leave_requests lr
            where lr.employee_id = p_employee_id
              and lr.status = 'approved'
              and (lr.is_paid = false or lr.decision_type = 'with_deduction')
              and d::date between lr.start_date and lr.end_date
          ) then 1.0
          else 0.0
        end,
        'deduction_amount', case
          when ar.status = 'absent' then round(2 * v_daily_rate, 2)
          when ar.status = 'on_leave' and exists (
            select 1 from public.leave_requests lr
            where lr.employee_id = p_employee_id
              and lr.status = 'approved'
              and (lr.is_paid = false or lr.decision_type = 'with_deduction')
              and d::date between lr.start_date and lr.end_date
          ) then round(1 * v_daily_rate, 2)
          else 0.0
        end
      ) order by d::date
    ), '[]'::jsonb) into v_daily_records
    from generate_series(v_eff_start, v_eff_end, interval '1 day') as d
    left join public.attendance_records ar
      on ar.employee_id = p_employee_id
     and ar.record_date = d::date;

    v_absence_ded := round(v_absent_days * 2 * v_daily_rate, 2);
    v_leave_ded   := round(v_leave_ded_days * 1 * v_daily_rate, 2);
    v_total_ded   := round(v_absence_ded + v_leave_ded + v_manual_ded, 2);
    -- صافي الراتب: (أيام الحضور + أيام الإجازة المدفوعة) × اليومية - الخصومات + المكافآت
    v_net_salary  := round(
      ((v_present_days + v_paid_leave_days) * v_daily_rate) - v_total_ded + v_total_bonuses, 2
    );
  end if;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id',                   v_emp.id,
      'code',                 v_emp.code,
      'full_name',            v_emp.full_name,
      'job_role',             v_emp.job_role,
      'branch_name',          coalesce(v_branch_name, 'المركز الرئيسي'),
      'basic_salary',         v_emp.basic_salary,
      'daily_rate',           v_daily_rate,
      'status',               v_emp.status
    ),
    'summary', jsonb_build_object(
      'present_days',         v_present_days,
      'absent_days',          v_absent_days,
      'leave_days',           v_leave_days,
      'paid_leave_days',      v_paid_leave_days,
      'leave_ded_days',       v_leave_ded_days,
      'absence_deduction',    v_absence_ded,
      'leave_deduction',      v_leave_ded,
      'manual_deductions',    v_manual_ded,
      'total_deductions',     v_total_ded,
      'total_bonuses',        v_total_bonuses,
      'net_salary',           v_net_salary
    ),
    'daily_records',          coalesce(v_daily_records, '[]'::jsonb)
  );
end;
$$;
grant execute on function public.hr_get_employee_report(uuid, date, date) to authenticated;
