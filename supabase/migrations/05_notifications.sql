-- =============================================================================
-- 05_notifications.sql
-- الإشعارات: الجداول، الدوال، الـ Realtime publication، RPCs القراءة
-- قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================

-- =============================================================================
-- § 1 — جدول notifications
-- =============================================================================

create table if not exists public.notifications (
  id         uuid        primary key default gen_random_uuid(),
  kind       text        not null check (kind in (
               'supply_submitted',
               'supply_approved',
               'supply_received_issues',
               'low_stock',
               'branch_order_submitted',
               'branch_order_updated',
               'branch_order_decided'
             )),
  audience   text[]      not null,  -- ['accounting', 'warehouse', 'branch']
  branch_id  uuid        references public.branches(id),  -- للجمهور branch فقط
  title      text        not null,
  body       text        not null,
  payload    jsonb       not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table  public.notifications           is 'الإشعارات — تُنشأ من داخل معاملات الأحداث عبر _notify()';
comment on column public.notifications.kind      is 'نوع الإشعار — يُستخدم في فلتر الواجهة';
comment on column public.notifications.audience  is 'الجمهور: accounting / warehouse / branch';
comment on column public.notifications.branch_id is 'للإشعارات الخاصة بفرع معين (branch_order_decided مثلاً)';
comment on column public.notifications.payload   is 'ref_type و ref_id و domains المتأثرة وأي بيانات إضافية للإشعار';

-- فهارس الاستعلام
create index if not exists idx_notifications_created_at
  on public.notifications (created_at desc);
create index if not exists idx_notifications_audience_created
  on public.notifications using gin(audience);
create index if not exists idx_notifications_branch_id
  on public.notifications (branch_id)
  where branch_id is not null;

alter table public.notifications enable row level security;

-- =============================================================================
-- § 2 — جدول notification_reads: تتبع الإشعارات المقروءة
-- =============================================================================

create table if not exists public.notification_reads (
  user_id         uuid        not null references auth.users(id),
  notification_id uuid        not null references public.notifications(id),
  read_at         timestamptz not null default now(),
  primary key (user_id, notification_id)
);

comment on table public.notification_reads is 'يتتبع الإشعارات التي قرأها كل مستخدم';

create index if not exists idx_notification_reads_user
  on public.notification_reads (user_id, read_at desc);

alter table public.notification_reads enable row level security;

-- =============================================================================
-- § 3 — دالة _notify: تُنشئ إشعاراً من داخل المعاملة
-- =============================================================================

create or replace function _notify(
  p_kind      text,
  p_audience  text[],
  p_branch_id uuid,
  p_title     text,
  p_body      text,
  p_payload   jsonb
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.notifications (kind, audience, branch_id, title, body, payload)
  values (p_kind, p_audience, p_branch_id, p_title, p_body, p_payload);
end;
$$;

revoke execute on function _notify(text, text[], uuid, text, text, jsonb)
  from public, anon, authenticated;

comment on function _notify(text, text[], uuid, text, text, jsonb) is
  'تُنشئ إشعاراً داخل نفس معاملة الحدث. مخفية عن الـ API.';

-- =============================================================================
-- § 4 — Realtime: أضف notifications للـ publication بشكل آمن ومتكرر
-- =============================================================================

do $$
begin
  -- تحقق من عدم وجود الجدول في Publication قبل إضافته
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename  = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

-- =============================================================================
-- § 5 — RPCs: الإشعارات
-- =============================================================================

-- 5-أ) notifications_summary: ملخص الإشعارات (آخر 90 يوم)
create or replace function notifications_summary(p_limit int default 50)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id   uuid := auth.uid();
  v_audiences text[];
  v_cutoff    timestamptz := now() - interval '90 days';
  v_items     jsonb;
  v_unread    int;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  v_audiences := _my_audiences();

  -- عدد غير المقروءة
  select count(*) into v_unread
  from public.notifications n
  where n.audience && v_audiences
    and (n.branch_id is null or _can_act_for_branch(n.branch_id))
    and n.created_at >= v_cutoff
    and not exists (
      select 1 from public.notification_reads r
      where r.notification_id = n.id and r.user_id = v_user_id
    );

  -- آخر p_limit إشعار
  select jsonb_agg(jsonb_build_object(
    'id',        n.id,
    'kind',      n.kind,
    'title',     n.title,
    'body',      n.body,
    'payload',   n.payload,
    'is_read',   (r.notification_id is not null),
    'created_at',n.created_at
  ) order by n.created_at desc)
  into v_items
  from public.notifications n
  left join public.notification_reads r
    on r.notification_id = n.id and r.user_id = v_user_id
  where n.audience && v_audiences
    and (n.branch_id is null or _can_act_for_branch(n.branch_id))
    and n.created_at >= v_cutoff
  order by n.created_at desc
  limit least(p_limit, 200);

  return jsonb_build_object(
    'unread_count', v_unread,
    'items',        coalesce(v_items, '[]'::jsonb)
  );
end;
$$;

comment on function notifications_summary(int) is
  'ملخص إشعارات المستخدم الحالي — آخر 90 يوم، مُرشَّح حسب الجمهور والفرع.';

grant execute on function notifications_summary(int) to authenticated;

-- 5-ب) notifications_mark_read: تحديد إشعارات كمقروءة
create or replace function notifications_mark_read(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_id      uuid;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  foreach v_id in array p_ids
  loop
    insert into public.notification_reads (user_id, notification_id)
    values (v_user_id, v_id)
    on conflict (user_id, notification_id) do nothing;
  end loop;
end;
$$;

grant execute on function notifications_mark_read(uuid[]) to authenticated;

-- 5-ج) notifications_mark_all_read: تحديد كل الإشعارات المرئية كمقروءة
create or replace function notifications_mark_all_read()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id   uuid := auth.uid();
  v_audiences text[];
  v_cutoff    timestamptz := now() - interval '90 days';
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  v_audiences := _my_audiences();

  insert into public.notification_reads (user_id, notification_id)
  select v_user_id, n.id
  from public.notifications n
  where n.audience && v_audiences
    and (n.branch_id is null or _can_act_for_branch(n.branch_id))
    and n.created_at >= v_cutoff
  on conflict (user_id, notification_id) do nothing;
end;
$$;

grant execute on function notifications_mark_all_read() to authenticated;

-- =============================================================================
-- نهاية الملف
-- =============================================================================
