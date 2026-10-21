-- 019_hr_employees.sql  (نسخة مراجعة، قابلة للتشغيل أكثر من مرة)
-- جدول الموظفين + hr_list_branches + hr_list_employees + hr_create_employee
-- كل الوصول عبر RPC فقط. الجدول نفسه مقفول عن anon و authenticated.

begin;

create sequence if not exists public.employee_code_seq start 1;
revoke all on sequence public.employee_code_seq from public, anon, authenticated;

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  full_name text not null check (btrim(full_name) <> ''),
  birth_date date,
  phone text,
  qualification text,
  job_role text not null check (job_role in (
    'cashier', 'accountant', 'hr', 'worker', 'driver',
    'storekeeper', 'chef', 'kitchen_worker', 'branch_manager'
  )),
  job_rank text,
  branch_id uuid references public.branches(id),
  hire_date date,
  basic_salary numeric(12,2) not null default 0 check (basic_salary >= 0),
  allowances numeric(12,2) not null default 0 check (allowances >= 0),
  transport_allowance numeric(12,2) not null default 0 check (transport_allowance >= 0),
  notes text,
  status text not null default 'active'
    check (status in ('active', 'suspended', 'terminated', 'archived')),
  status_reason text,
  status_changed_at timestamptz,
  status_changed_by uuid references auth.users(id),
  suspension_start date,
  suspension_end date,
  termination_date date,
  client_id uuid unique,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.employees is
  'الموظفون. job_role تصنيف وظيفي (مش دور حساب الدخول profiles.role). '
  'قاعدة الفرع: cashier/branch_manager فرع إلزامي؛ worker/driver فرع اختياري '
  '(null = المخزن/المطبخ الرئيسي)؛ باقي الأدوار بدون فرع.';

create index if not exists idx_employees_status   on public.employees(status);
create index if not exists idx_employees_job_role on public.employees(job_role);
create index if not exists idx_employees_branch   on public.employees(branch_id);

alter table public.employees enable row level security;
revoke all on table public.employees from public, anon, authenticated;

-- ───────────────────────── دالة داخلية: موظف واحد كـ jsonb ─────────────────────────
create or replace function public._hr_employee_json(p_id uuid)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'id', e.id,
    'code', e.code,
    'full_name', e.full_name,
    'birth_date', e.birth_date,
    'phone', e.phone,
    'qualification', e.qualification,
    'job_role', e.job_role,
    'job_rank', e.job_rank,
    'branch_id', e.branch_id,
    'branch_name', b.name,
    'branch_code', b.code,
    'hire_date', e.hire_date,
    'basic_salary', e.basic_salary,
    'allowances', e.allowances,
    'transport_allowance', e.transport_allowance,
    'notes', e.notes,
    'status', e.status,
    'status_reason', e.status_reason,
    'created_at', e.created_at
  )
  from public.employees e
  left join public.branches b on b.id = e.branch_id
  where e.id = p_id;
$$;

revoke all on function public._hr_employee_json(uuid) from public, anon, authenticated;

-- ───────────────────────── hr_list_branches ─────────────────────────
create or replace function public.hr_list_branches()
returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public._has_role('hr') then
    raise exception using errcode = '42501', message = 'غير مصرح لك بالوصول لبيانات الفروع';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'code', b.code)
                     order by b.code)
    from public.branches b
    where b.deleted_at is null and b.is_active = true
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.hr_list_branches() from public, anon;
grant execute on function public.hr_list_branches() to authenticated;

-- ───────────────────────── hr_list_employees ─────────────────────────
create or replace function public.hr_list_employees(
  p_search text default null,
  p_job_role text default null,
  p_status text default null,
  p_branch_id uuid default null,
  p_no_branch boolean default false,
  p_limit int default 50,
  p_offset int default 0
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_limit  int  := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset int  := greatest(0, coalesce(p_offset, 0));
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_pat    text;
  v_total  int;
  v_items  jsonb;
  v_counts jsonb;
begin
  if not public._has_role('hr') then
    raise exception using errcode = '42501', message = 'غير مصرح لك باستعراض الموظفين';
  end if;

  if v_search is not null then
    -- تعطيل أحرف الـ wildcard اللي المستخدم يكتبها
    v_pat := '%' || replace(replace(replace(v_search, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;

  with f as (
    select e.id, e.full_name
    from public.employees e
    where (v_pat is null or e.full_name ilike v_pat or e.code ilike v_pat)
      and (p_job_role is null or p_job_role = 'all' or e.job_role = p_job_role)
      and (case
             when p_status is null  then e.status in ('active', 'suspended')
             when p_status = 'all'  then true
             else e.status = p_status
           end)
      and (p_branch_id is null or e.branch_id = p_branch_id)
      and (not coalesce(p_no_branch, false) or e.branch_id is null)
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(public._hr_employee_json(x.id) order by x.full_name, x.id)
      from (select id, full_name from f order by full_name, id
            limit v_limit offset v_offset) x
    ), '[]'::jsonb)
  into v_total, v_items;

  select jsonb_build_object(
    'active',     count(*) filter (where status = 'active'),
    'suspended',  count(*) filter (where status = 'suspended'),
    'terminated', count(*) filter (where status = 'terminated'),
    'archived',   count(*) filter (where status = 'archived')
  ) into v_counts
  from public.employees;

  return jsonb_build_object('total', v_total, 'counts', v_counts, 'items', v_items);
end;
$$;

revoke all on function public.hr_list_employees(text, text, text, uuid, boolean, int, int)
  from public, anon;
grant execute on function public.hr_list_employees(text, text, text, uuid, boolean, int, int)
  to authenticated;

-- ───────────────────────── hr_create_employee ─────────────────────────
create or replace function public.hr_create_employee(p jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_client_id uuid;
  v_id        uuid;
  v_code      text;
  v_name      text := btrim(coalesce(p->>'full_name', ''));
  v_role      text := nullif(btrim(coalesce(p->>'job_role', '')), '');
  v_branch_id uuid;
  v_birth     date;
  v_hire      date;
  v_basic     numeric;
  v_allow     numeric;
  v_trans     numeric;
  v_phone     text := nullif(btrim(coalesce(p->>'phone', '')), '');
  v_qual      text := nullif(btrim(coalesce(p->>'qualification', '')), '');
  v_rank      text := nullif(btrim(coalesce(p->>'job_rank', '')), '');
  v_notes     text := nullif(btrim(coalesce(p->>'notes', '')), '');
begin
  if not public._has_role('hr') then
    raise exception using errcode = '42501', message = 'غير مصرح لك بإضافة موظفين';
  end if;

  -- تحويل القيم مع رسالة عربية بدل أخطاء الـ cast الإنجليزية
  begin
    v_client_id := nullif(p->>'client_id', '')::uuid;
    v_branch_id := nullif(p->>'branch_id', '')::uuid;
    v_birth     := nullif(p->>'birth_date', '')::date;
    v_hire      := nullif(p->>'hire_date', '')::date;
    v_basic     := coalesce(nullif(p->>'basic_salary', '')::numeric, 0);
    v_allow     := coalesce(nullif(p->>'allowances', '')::numeric, 0);
    v_trans     := coalesce(nullif(p->>'transport_allowance', '')::numeric, 0);
  exception when others then
    raise exception 'بيانات غير صحيحة: تحقق من التواريخ والمبالغ والفرع';
  end;

  if v_client_id is null then
    raise exception 'client_id مطلوب';
  end if;

  -- إعادة المحاولة بنفس client_id ترجع نفس الموظف
  select id into v_id from public.employees where client_id = v_client_id;
  if v_id is not null then
    return public._hr_employee_json(v_id);
  end if;

  if v_name = '' then
    raise exception 'اسم الموظف إلزامي';
  end if;
  if length(v_name) > 100 then
    raise exception 'اسم الموظف طويل جداً';
  end if;

  if v_role is null or v_role not in (
    'cashier', 'accountant', 'hr', 'worker', 'driver',
    'storekeeper', 'chef', 'kitchen_worker', 'branch_manager'
  ) then
    raise exception 'الدور الوظيفي غير صحيح';
  end if;

  if length(coalesce(v_phone, '')) > 30
     or length(coalesce(v_qual, '')) > 200
     or length(coalesce(v_rank, '')) > 100
     or length(coalesce(v_notes, '')) > 2000 then
    raise exception 'أحد الحقول النصية أطول من المسموح';
  end if;

  if v_birth is not null then
    if v_birth > current_date then
      raise exception 'تاريخ الميلاد لا يمكن أن يكون في المستقبل';
    end if;
    if exists (
      select 1 from public.employees
      where lower(full_name) = lower(v_name) and birth_date = v_birth
    ) then
      raise exception 'يوجد موظف بنفس الاسم وتاريخ الميلاد مسجل مسبقاً';
    end if;
  end if;

  if v_branch_id is not null and not exists (
    select 1 from public.branches
    where id = v_branch_id and deleted_at is null and is_active = true
  ) then
    raise exception 'الفرع المحدد غير موجود أو موقوف';
  end if;

  if v_role in ('cashier', 'branch_manager') and v_branch_id is null then
    raise exception 'يجب تحديد الفرع لوظيفة الكاشير أو مدير الفرع';
  end if;

  if v_role in ('storekeeper', 'chef', 'kitchen_worker', 'accountant', 'hr')
     and v_branch_id is not null then
    raise exception 'هذه الوظيفة لا ترتبط بفرع، يرجى إزالة اختيار الفرع';
  end if;

  if least(v_basic, v_allow, v_trans) < 0 then
    raise exception 'المبالغ لا يمكن أن تكون سالبة';
  end if;
  if greatest(v_basic, v_allow, v_trans) > 99999999 then
    raise exception 'أحد المبالغ كبير جداً';
  end if;

  v_code := 'EMP-' || lpad(nextval('public.employee_code_seq')::text, 4, '0');

  insert into public.employees (
    code, full_name, birth_date, phone, qualification, job_role, job_rank,
    branch_id, hire_date, basic_salary, allowances, transport_allowance,
    notes, client_id, created_by
  ) values (
    v_code, v_name, v_birth, v_phone, v_qual, v_role, v_rank,
    v_branch_id, v_hire, v_basic, v_allow, v_trans,
    v_notes, v_client_id, auth.uid()
  )
  on conflict (client_id) do nothing
  returning id into v_id;

  -- ضغطتين متزامنتين بنفس client_id: التانية ترجع الموظف الأول
  if v_id is null then
    select id into v_id from public.employees where client_id = v_client_id;
  end if;

  return public._hr_employee_json(v_id);
end;
$$;

revoke all on function public.hr_create_employee(jsonb) from public, anon;
grant execute on function public.hr_create_employee(jsonb) to authenticated;

commit;