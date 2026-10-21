-- =============================================================================
-- 027_admin_and_settings.sql
-- دوال قراءة وتعديل مستخدمي النظام وإعدادات الإدارة والضريبة القائمة
-- يدعم تشفير bcrypt للأمان وفي نفس الوقت يعرض كلمة المرور للمالك
-- =============================================================================

-- إضافة عمود اختياري آمن في profiles لتخزين كلمة المرور الواضحة للعرض في لوحة المالك
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS current_password text;

-- 1. دالة جلب المستخدمين الحقيقيين من جدول profiles مع إيميلاتهم وباسورداتهم وأسماء فروعهم
CREATE OR REPLACE FUNCTION public.get_admin_users()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id',               p.id,
      'full_name',        coalesce(p.full_name, 'مستخدم'),
      'email',            coalesce(u.email, '—'),
      'password',         coalesce(p.current_password, case when p.role = 'owner' then 'Samer@2026' else '••••••••' end),
      'role',             p.role,
      'branch_id',        p.branch_id,
      'branch_name',      coalesce(b.name, 'الإدارة العامة'),
      'is_active',        p.is_active,
      'created_at',       p.created_at
    ) ORDER BY (p.role = 'owner') DESC, p.created_at DESC), '[]'::jsonb)
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    LEFT JOIN public.branches b ON b.id = p.branch_id
  );
END;
$$;

-- 2. دالة تعديل كلمة مرور أي مستخدم (تشفيرها لـ auth.users وحفظ نسختها في profiles للعرض)
CREATE OR REPLACE FUNCTION public.admin_set_user_password(
  p_user_id      uuid,
  p_new_password text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
  IF p_user_id IS NULL OR p_new_password IS NULL OR length(p_new_password) < 6 THEN
    RAISE EXCEPTION 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
  END IF;

  -- أ) تشفير كلمة المرور في auth.users ليعمل تسجيل الدخول بدقة
  UPDATE auth.users
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
      updated_at = now()
  WHERE id = p_user_id;

  -- ب) حفظ كلمة المرور في profiles ليراها المالك في الشاشة
  UPDATE public.profiles
  SET current_password = p_new_password
  WHERE id = p_user_id;

  RETURN FOUND;
END;
$$;

-- 3. دالة تعديل بيانات المستخدم في profiles
CREATE OR REPLACE FUNCTION public.admin_update_profile(
  p_user_id   uuid,
  p_full_name text,
  p_role      text,
  p_branch_id uuid,
  p_is_active boolean DEFAULT true
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET full_name  = coalesce(p_full_name, full_name),
      role       = p_role::public.app_role,
      branch_id  = p_branch_id,
      is_active  = coalesce(p_is_active, is_active)
  WHERE id = p_user_id;

  RETURN FOUND;
END;
$$;

-- 4. دوال قراءة وتعديل السجلات في جدول app_settings
CREATE OR REPLACE FUNCTION public.get_system_settings()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'key',       s.key,
      'label',     s.label,
      'value',     s.value,
      'is_secret', s.is_secret
    )), '[]'::jsonb)
    FROM public.app_settings s
  );
END;
$$;

-- 5. تحديث إعدادات النظام (مع تشفير باسورد الكاشير بـ crypt ليعمل مع نقاط البيع)
CREATE OR REPLACE FUNCTION public.update_app_setting(
  p_identifier text,
  p_new_value  text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF p_identifier ILIKE '%باسورد%' OR p_identifier = 'cashier_admin_password' THEN
    -- تشفير الباسورد بالـ bcrypt المطلوب للـ POS
    UPDATE public.app_settings
    SET value = extensions.crypt(p_new_value, extensions.gen_salt('bf')),
        updated_at = now()
    WHERE key = 'cashier_admin_password'
       OR label ILIKE '%باسورد%';
  ELSE
    -- تحديث القيمة العادية (مثل نسبة الضريبة)
    UPDATE public.app_settings
    SET value = p_new_value,
        updated_at = now()
    WHERE key = p_identifier
       OR label ILIKE '%' || p_identifier || '%';
  END IF;

  RETURN FOUND;
END;
$$;

-- صلاحيات التنفيذ للواجهة
GRANT EXECUTE ON FUNCTION public.get_admin_users() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_password(uuid, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_profile(uuid, text, text, uuid, boolean) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_system_settings() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.update_app_setting(text, text) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
