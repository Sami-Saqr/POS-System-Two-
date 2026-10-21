-- =============================================================================
-- 017_expenses.sql
-- مصروفات الفروع: حفظ ذري، آمن من التكرار، وسجل مركزي للكاشير.
-- =============================================================================

create table if not exists public.expenses (
  id             uuid primary key default gen_random_uuid(),
  client_id      uuid not null unique,
  number         text not null unique,
  branch_id      uuid not null references public.branches(id),
  session_id     uuid not null,
  category       text not null,
  payee          text,
  description    text,
  amount         numeric(12, 2) not null check (amount > 0),
  vat_amount     numeric(12, 2) not null default 0 check (vat_amount >= 0),
  total          numeric(12, 2) not null check (total > 0),
  payment_method text not null check (payment_method in ('cash', 'other')),
  expense_date   date not null,
  notes          text,
  created_by     uuid not null references auth.users(id),
  created_at     timestamptz not null default now()
);

create index if not exists idx_expenses_branch_created
  on public.expenses (branch_id, created_at desc);
create index if not exists idx_expenses_session
  on public.expenses (session_id);

alter table public.expenses enable row level security;

create or replace function public.create_expense(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_client_id uuid := nullif(p->>'client_id', '')::uuid;
  v_branch_id uuid := nullif(p->>'branch_id', '')::uuid;
  v_session_id uuid := nullif(p->>'session_id', '')::uuid;
  v_existing public.expenses%rowtype;
  v_branch public.branches%rowtype;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat_amount numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_number text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _has_role('cashier', 'branch_manager', 'accountant') then
    raise exception 'ليس لديك صلاحية تسجيل المصروفات';
  end if;
  if v_client_id is null or v_branch_id is null or v_session_id is null then
    raise exception 'بيانات المصروف ناقصة';
  end if;
  if not _can_act_for_branch(v_branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;
  if coalesce(trim(p->>'category'), '') = '' then
    raise exception 'نوع المصروف مطلوب';
  end if;
  if v_amount is null or v_amount <= 0 or v_vat_amount < 0 then
    raise exception 'قيمة المصروف غير صحيحة';
  end if;

  select * into v_existing from public.expenses where client_id = v_client_id;
  if found then
    if v_existing.created_by <> v_uid then
      raise exception 'معرّف المصروف مستخدم بالفعل';
    end if;
    return jsonb_build_object(
      'id', v_existing.id,
      'number', v_existing.number,
      'already_exists', true
    );
  end if;

  select * into v_branch
  from public.branches
  where id = v_branch_id and deleted_at is null;
  if not found then
    raise exception 'الفرع غير موجود';
  end if;

  v_number := _next_doc_number(
    'expense',
    coalesce(nullif(v_branch.code, ''), 'DK-001'),
    'EXP-{scope}-{n:6}'
  );

  insert into public.expenses (
    client_id, number, branch_id, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes, created_by
  ) values (
    v_client_id, v_number, v_branch_id, v_session_id, trim(p->>'category'),
    nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat_amount, 2), round(v_amount + v_vat_amount, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), ''), v_uid
  ) returning id into v_id;

  return jsonb_build_object('id', v_id, 'number', v_number, 'already_exists', false);
end;
$$;

create or replace function public.get_branch_expenses(p_branch_id uuid)
returns table (
  id uuid,
  client_id uuid,
  number text,
  category text,
  payee text,
  description text,
  amount numeric,
  vat_amount numeric,
  total numeric,
  payment_method text,
  expense_date date,
  notes text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not _can_act_for_branch(p_branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  return query
  select
    e.id, e.client_id, e.number, e.category, e.payee, e.description,
    e.amount, e.vat_amount, e.total, e.payment_method, e.expense_date,
    e.notes, e.created_at
  from public.expenses e
  where e.branch_id = p_branch_id
  order by e.created_at desc;
end;
$$;

revoke all on function public.create_expense(jsonb) from public, anon;
grant execute on function public.create_expense(jsonb) to authenticated;
revoke all on function public.get_branch_expenses(uuid) from public, anon;
grant execute on function public.get_branch_expenses(uuid) to authenticated;

notify pgrst, 'reload schema';
