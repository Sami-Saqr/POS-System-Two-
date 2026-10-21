-- =============================================================================
-- 09a_approval_patch.sql
-- إضافة أكشن 'inventory_item_edit' لدالة admin_issue_approval
-- مع الاحتفاظ بنفس سلوكها وبصمتها من ملف 01_foundation.sql
-- =============================================================================

alter table public.admin_approvals drop constraint if exists admin_approvals_action_check;
alter table public.admin_approvals add constraint admin_approvals_action_check
  check (action in ('inventory_import', 'inventory_stocktake', 'inventory_item_edit'));

create or replace function admin_issue_approval(
  p_password text,
  p_action   text  -- 'inventory_import' | 'inventory_stocktake' | 'inventory_item_edit'
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
  if p_action not in ('inventory_import', 'inventory_stocktake', 'inventory_item_edit') then
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

revoke execute on function admin_issue_approval(text, text) from public, anon, authenticated;
grant execute on function admin_issue_approval(text, text) to authenticated;

comment on function admin_issue_approval(text, text) is
  'يتحقق من باسورد الإدارة ويُصدر تصريحاً مؤقتاً صالحاً 10 دقائق لاستخدام واحد.';
