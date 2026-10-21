-- =============================================================================
-- 01_foundation.sql
-- الأساس: دوال مساعدة، بصمات البيانات، عدادات المستندات، تصاريح الإدارة
-- قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================

-- تأكد من وجود الامتدادات اللازمة
create extension if not exists "pgcrypto" schema extensions;

-- =============================================================================
-- § 1 — دوال مساعدة داخلية (تبدأ بـ _)
--       تُسمى security definer وتُخفى عن الـ API
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1-أ) _has_role: هل المستخدم الحالي له أحد الأدوار المحددة؟
--       owner يمر دائماً بدون فحص الأدوار الأخرى
-- -----------------------------------------------------------------------------
create or replace function _has_role(variadic p_roles text[])
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_role text;
begin
  -- اقرأ الدور من جدول profiles للمستخدم الحالي
  select role into v_role
  from public.profiles
  where id = auth.uid()
    and is_active = true;

  -- لو مفيش صف أو الدور فارغ: ارفض
  if v_role is null then
    return false;
  end if;

  -- owner يمر دائماً
  if v_role = 'owner' then
    return true;
  end if;

  -- تحقق من الأدوار المطلوبة
  return v_role = any(p_roles);
end;
$$;

-- أخفِ الدالة عن الـ API
revoke execute on function _has_role(text[]) from public, anon, authenticated;

comment on function _has_role(text[]) is
  'تحقق من دور المستخدم الحالي. owner يمر دائماً. تُستخدم داخلياً من كل RPC.';

-- -----------------------------------------------------------------------------
-- 1-ب) _can_act_for_branch: هل يحق للمستخدم التصرف لهذا الفرع؟
--       حالياً تقبل أي مستخدم مسجّل (الفرع يتحدد عند تسجيل الدخول)
--       تُعدَّل في مكان واحد عند ربط الحسابات بالفروع
-- -----------------------------------------------------------------------------
create or replace function _can_act_for_branch(p_branch_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  -- حالياً: أي مستخدم مسجّل يقدر يتصرف لأي فرع
  -- لأن الفرع بيتحدد عند تسجيل الدخول مش مربوط بالحساب
  return auth.uid() is not null;
end;
$$;

revoke execute on function _can_act_for_branch(uuid) from public, anon, authenticated;

comment on function _can_act_for_branch(uuid) is
  'حالياً تقبل أي مستخدم مسجّل. ستُعدَّل عند ربط الحسابات بالفروع.';

-- -----------------------------------------------------------------------------
-- 1-ج) _my_audiences: الجمهور الخاص بالمستخدم الحالي للإشعارات
-- -----------------------------------------------------------------------------
create or replace function _my_audiences()
returns text[]
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_role text;
begin
  select role into v_role
  from public.profiles
  where id = auth.uid()
    and is_active = true;

  if v_role is null then
    return array[]::text[];
  end if;

  return case v_role
    when 'owner'           then array['accounting', 'warehouse', 'branch']
    when 'accountant'      then array['accounting']
    when 'storekeeper'     then array['warehouse']
    when 'cashier'         then array['branch']
    when 'branch_manager'  then array['branch']
    else array[]::text[]
  end;
end;
$$;

revoke execute on function _my_audiences() from public, anon, authenticated;

comment on function _my_audiences() is
  'يرجع مصفوفة الجمهور الخاصة بالمستخدم الحالي. تُستخدم في RLS للإشعارات.';

-- -----------------------------------------------------------------------------
-- 1-د) _bump_data_version: يزوّد بصمة نسخة مفتاح بيانات محدد (ذري)
-- -----------------------------------------------------------------------------
create or replace function _bump_data_version(p_key text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.data_versions (key, version, updated_at)
  values (p_key, 1, now())
  on conflict (key) do update
    set version    = data_versions.version + 1,
        updated_at = now();
end;
$$;

revoke execute on function _bump_data_version(text) from public, anon, authenticated;

comment on function _bump_data_version(text) is
  'يزوّد رقم نسخة مفتاح البيانات بشكل ذري. تُستدعى من داخل كل RPC تكتابة.';

-- -----------------------------------------------------------------------------
-- 1-هـ) _next_doc_number: يولّد رقم مستند تسلسلي ذري
--        p_type  : نوع المستند (po, bo, issue, batch, stk, import)
--        p_scope : النطاق (السنة، أو 'السنة:كود الفرع'، إلخ)
--        p_format: قالب النص — {n} يُستبدل برقم التسلسل، {scope} بالنطاق
-- -----------------------------------------------------------------------------
create or replace function _next_doc_number(
  p_type  text,
  p_scope text,
  p_format text  -- مثال: 'PO-{scope}-{n:4}'
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_last int;
  v_next int;
  v_width int;
  v_result text;
begin
  -- احجز الرقم التالي بشكل ذري (upsert مع FOR UPDATE)
  insert into public.doc_counters (doc_type, scope, last_number)
  values (p_type, p_scope, 1)
  on conflict (doc_type, scope) do update
    set last_number = doc_counters.last_number + 1
  returning last_number into v_next;

  -- استخرج عرض الأرقام من القالب: {n:4} = 4 خانات
  v_result := p_format;
  v_width  := 4; -- الافتراضي

  if p_format like '%{n:%}%' then
    v_width := (regexp_match(p_format, '\{n:(\d+)\}'))[1]::int;
    v_result := regexp_replace(v_result, '\{n:\d+\}',
                  lpad(v_next::text, v_width, '0'));
  else
    v_result := replace(v_result, '{n}', lpad(v_next::text, v_width, '0'));
  end if;

  v_result := replace(v_result, '{scope}', p_scope);

  return v_result;
end;
$$;

revoke execute on function _next_doc_number(text, text, text) from public, anon, authenticated;

comment on function _next_doc_number(text, text, text) is
  'يولّد رقم مستند تسلسلي ذري من جدول doc_counters. آمن للتزامن.';

-- -----------------------------------------------------------------------------
-- 1-و) _check_admin_password: تحقق من باسورد الإدارة مع الحماية من التخمين
--       يُعيد استخدام منطق verify_cashier_admin_password الحالية
--       لكن كدالة داخلية مخفية عن API
-- -----------------------------------------------------------------------------
create or replace function _check_admin_password(p_password text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_stored_hash text;
  v_recent_fails int;
  v_user_id uuid := auth.uid();
begin
  -- ممنوع بدون مستخدم
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  -- عدّ محاولات الفشل في آخر 10 دقائق لهذا المستخدم
  select count(*) into v_recent_fails
  from public.cashier_admin_attempts
  where user_id = v_user_id
    and success = false
    and created_at >= now() - interval '10 minutes';

  if v_recent_fails >= 5 then
    raise exception 'تم تجاوز الحد الأقصى للمحاولات. حاول مرة أخرى بعد 10 دقائق.';
  end if;

  -- اقرأ الهاش المخزن من app_settings
  select value into v_stored_hash
  from public.app_settings
  where key = 'cashier_admin_password';

  if v_stored_hash is null then
    raise exception 'لم يتم تكوين باسورد الإدارة بعد. تواصل مع المالك.';
  end if;

  -- تحقق من الباسورد باستخدام crypt (bcrypt في pgcrypto)
  if extensions.crypt(p_password, v_stored_hash) = v_stored_hash then
    -- سجّل محاولة ناجحة
    insert into public.cashier_admin_attempts (user_id, success, created_at)
    values (v_user_id, true, now());
    return true;
  else
    -- سجّل محاولة فاشلة
    insert into public.cashier_admin_attempts (user_id, success, created_at)
    values (v_user_id, false, now());
    return false;
  end if;
end;
$$;

revoke execute on function _check_admin_password(text) from public, anon, authenticated;

comment on function _check_admin_password(text) is
  'تحقق داخلي من باسورد الإدارة مع حماية من التخمين (5 محاولات/10د). مخفية عن API.';

-- =============================================================================
-- § 2 — جدول data_versions: بصمات نسخ البيانات للـ delta sync
-- =============================================================================

create table if not exists public.data_versions (
  key        text        primary key,
  version    bigint      not null default 1,
  updated_at timestamptz not null default now()
);

comment on table  public.data_versions            is 'بصمات نسخ البيانات — كل RPC تكتابة تزوّد المفاتيح المتأثرة';
comment on column public.data_versions.key        is 'مفتاح الدومين: inv_catalog / inv_stock / inv_supply / inv_kitchen / inv_stocktake / branch_orders:<branch_id> / branch_stock:<branch_id>';
comment on column public.data_versions.version    is 'رقم النسخة — يزداد بشكل ذري عند كل تغيير';
comment on column public.data_versions.updated_at is 'وقت آخر تحديث';

-- سطر row-level security
alter table public.data_versions enable row level security;

-- =============================================================================
-- § 3 — جدول doc_counters: عدادات المستندات الذرية
-- =============================================================================

create table if not exists public.doc_counters (
  doc_type    text   not null,
  scope       text   not null, -- السنة أو 'السنة:كود_الفرع'
  last_number int    not null default 0,
  primary key (doc_type, scope)
);

comment on table  public.doc_counters             is 'عدادات تسلسلية ذرية لأرقام المستندات';
comment on column public.doc_counters.doc_type    is 'نوع المستند: po / bo / issue / batch / stk / import';
comment on column public.doc_counters.scope       is 'النطاق: السنة، أو السنة:كود_الفرع';
comment on column public.doc_counters.last_number is 'آخر رقم صدر';

alter table public.doc_counters enable row level security;

-- =============================================================================
-- § 4 — جدول admin_approvals: تصاريح الإدارة لعمليات الاستيراد والجرد
-- =============================================================================

create table if not exists public.admin_approvals (
  id         uuid        primary key default gen_random_uuid(),
  token      uuid        not null unique default gen_random_uuid(),
  user_id    uuid        not null references auth.users(id),
  action     text        not null
               check (action in ('inventory_import', 'inventory_stocktake')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at    timestamptz
);

comment on table  public.admin_approvals            is 'تصاريح مؤقتة تُصدر بعد التحقق من باسورد الإدارة';
comment on column public.admin_approvals.token      is 'UUID فريد يُرسل للتطبيق كتصريح استخدام واحد';
comment on column public.admin_approvals.action     is 'العملية المصرّح بها: inventory_import أو inventory_stocktake';
comment on column public.admin_approvals.expires_at is 'ينتهي بعد 10 دقائق من الإصدار';
comment on column public.admin_approvals.used_at    is 'وقت الاستخدام — بعد الاستخدام لا يُقبل مرة ثانية';

create index if not exists idx_admin_approvals_user_action
  on public.admin_approvals (user_id, action, expires_at)
  where used_at is null;

alter table public.admin_approvals enable row level security;

-- =============================================================================
-- § 5 — RPC: admin_issue_approval
--       يتحقق من الباسورد ويُصدر تصريحاً مؤقتاً (10 دقائق، استخدام واحد)
-- =============================================================================

create or replace function admin_issue_approval(
  p_password text,
  p_action   text  -- 'inventory_import' | 'inventory_stocktake'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token uuid;
  v_user_id uuid := auth.uid();
begin
  -- تحقق من صلاحية الأكشن
  if p_action not in ('inventory_import', 'inventory_stocktake') then
    raise exception 'إجراء غير معروف: %', p_action;
  end if;

  -- تحقق من الصلاحية
  if not _has_role('storekeeper', 'accountant') then
    raise exception 'ليس لديك صلاحية طلب تصريح إدارة المخزون';
  end if;

  -- تحقق من الباسورد
  if not _check_admin_password(p_password) then
    raise exception 'باسورد الإدارة غير صحيح';
  end if;

  -- أنشئ التصريح
  insert into public.admin_approvals (user_id, action, expires_at)
  values (v_user_id, p_action, now() + interval '10 minutes')
  returning token into v_token;

  return jsonb_build_object(
    'token',      v_token,
    'action',     p_action,
    'expires_at', (now() + interval '10 minutes')
  );
end;
$$;

comment on function admin_issue_approval(text, text) is
  'يتحقق من باسورد الإدارة ويُصدر تصريحاً مؤقتاً صالحاً 10 دقائق لاستخدام واحد.';

-- =============================================================================
-- § 6 — RPC: inventory_get_stamps
--       يرجّع بصمات نسخ المفاتيح المطلوبة (حجمها < 300 بايت)
--       لا تتطلب صلاحيات خاصة — أي مستخدم مسجّل
-- =============================================================================

create or replace function inventory_get_stamps(p_keys text[])
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  return (
    select jsonb_object_agg(key, version)
    from public.data_versions
    where key = any(p_keys)
  );
end;
$$;

comment on function inventory_get_stamps(text[]) is
  'يرجّع بصمات نسخ البيانات للمفاتيح المطلوبة. حجم الرد < 300 بايت.';

-- =============================================================================
-- § 7 — إضافة المفتاح timezone في app_settings لو غير موجود
-- =============================================================================

insert into public.app_settings (key, label, value, is_secret, updated_at)
values ('timezone', 'المنطقة الزمنية للتطبيق', 'Africa/Cairo', false, now())
on conflict (key) do nothing;

-- =============================================================================
-- § 8 — GRANT للدوال العامة
-- =============================================================================

grant execute on function admin_issue_approval(text, text) to authenticated;
grant execute on function inventory_get_stamps(text[])     to authenticated;

-- =============================================================================
-- نهاية الملف
-- =============================================================================
