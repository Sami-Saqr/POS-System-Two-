-- =============================================================================
-- 03_stock_core.sql
-- قلب المخزون: المخازن، الأرصدة، الحركات، _post_movement، تدقيق الأرصدة
-- قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================

-- =============================================================================
-- § 1 — جدول warehouses: المخازن
--       مستودع رئيسي واحد (kind = main) + مستودع لكل فرع (kind = branch)
-- =============================================================================

create table if not exists public.warehouses (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null,
  kind       text        not null check (kind in ('main', 'branch')),
  branch_id  uuid        references public.branches(id),
  is_active  boolean     not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table  public.warehouses           is 'المخازن — رئيسي واحد (main) + مستودع لكل فرع (branch)';
comment on column public.warehouses.kind      is 'main = المستودع الرئيسي | branch = مستودع فرع';
comment on column public.warehouses.branch_id is 'FK للفرع — null للمستودع الرئيسي';

-- قيد فريد جزئي: مستودع رئيسي واحد فقط في النظام
create unique index if not exists idx_warehouses_single_main
  on public.warehouses (kind)
  where kind = 'main';

-- قيد فريد: مستودع واحد لكل فرع
create unique index if not exists idx_warehouses_branch_unique
  on public.warehouses (branch_id)
  where kind = 'branch' and branch_id is not null;

alter table public.warehouses enable row level security;

create or replace trigger trg_warehouses_updated_at
  before update on public.warehouses
  for each row execute function public.set_updated_at();

-- أنشئ المستودع الرئيسي لو غير موجود
insert into public.warehouses (name, kind)
select 'المستودع الرئيسي', 'main'
where not exists (
  select 1 from public.warehouses where kind = 'main'
);

-- =============================================================================
-- § 2 — دالة داخلية _get_branch_warehouse
--       تجلب أو تنشئ مستودع الفرع تلقائياً
-- =============================================================================

create or replace function _get_branch_warehouse(p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_warehouse_id uuid;
  v_branch_name  text;
begin
  -- حاول الجلب أولاً
  select id into v_warehouse_id
  from public.warehouses
  where kind = 'branch' and branch_id = p_branch_id;

  -- لو غير موجود: أنشئه
  if v_warehouse_id is null then
    select name into v_branch_name
    from public.branches
    where id = p_branch_id;

    insert into public.warehouses (name, kind, branch_id)
    values (
      coalesce(v_branch_name, 'فرع ' || p_branch_id::text),
      'branch',
      p_branch_id
    )
    returning id into v_warehouse_id;
  end if;

  return v_warehouse_id;
end;
$$;

revoke execute on function _get_branch_warehouse(uuid) from public, anon, authenticated;

comment on function _get_branch_warehouse(uuid) is
  'يجلب مستودع الفرع أو ينشئه تلقائياً عند أول تحويل له.';

-- =============================================================================
-- § 3 — جدول inventory_stock: الأرصدة الحالية
--       PK مركّب (warehouse_id, item_id) — ممنوع الرصيد السالب
-- =============================================================================

create table if not exists public.inventory_stock (
  warehouse_id uuid           not null references public.warehouses(id),
  item_id      uuid           not null references public.inventory_items(id),
  quantity     numeric(14,3)  not null default 0 check (quantity >= 0),
  updated_at   timestamptz    not null default now(),
  primary key (warehouse_id, item_id)
);

comment on table  public.inventory_stock              is 'الأرصدة الحالية لكل صنف في كل مستودع — يُكتب فقط عبر _post_movement';
comment on column public.inventory_stock.quantity     is 'الرصيد الحالي — لا يقل عن صفر بأي حال';
comment on column public.inventory_stock.updated_at   is 'وقت آخر تغيير في الرصيد';

-- فهرس لاستعلامات جلب رصيد مستودع كامل
create index if not exists idx_inv_stock_warehouse
  on public.inventory_stock (warehouse_id);

-- فهرس لاستعلامات رصيد صنف عبر كل المخازن (لحساب avg_cost)
create index if not exists idx_inv_stock_item
  on public.inventory_stock (item_id);

alter table public.inventory_stock enable row level security;

-- =============================================================================
-- § 4 — جدول inventory_movements: دفتر الحركات (immutable)
-- =============================================================================

create table if not exists public.inventory_movements (
  id            bigint         generated always as identity primary key,
  occurred_at   timestamptz    not null default now(),
  warehouse_id  uuid           not null references public.warehouses(id),
  item_id       uuid           not null references public.inventory_items(id),
  movement_type text           not null check (movement_type in (
                                 'opening',
                                 'supply_receipt',
                                 'kitchen_issue',
                                 'kitchen_output',
                                 'branch_transfer_out',
                                 'branch_transfer_in',
                                 'damage',
                                 'stocktake_adjust'
                               )),
  qty_delta     numeric(14,3)  not null,          -- موجب أو سالب
  unit_cost     numeric(14,4)  not null default 0, -- لقطة التكلفة وقت الحركة
  balance_after numeric(14,3)  not null,           -- الرصيد بعد الحركة للتدقيق
  ref_type      text,                              -- نوع المستند المرجعي
  ref_id        uuid,                              -- معرّف المستند المرجعي
  note          text,
  created_by    uuid           references auth.users(id),
  created_at    timestamptz    not null default now()
);

comment on table  public.inventory_movements               is 'دفتر الحركات — immutable (لا يُعدَّل ولا يُحذف أبداً)';
comment on column public.inventory_movements.qty_delta     is 'موجب = إضافة للمخزون، سالب = خصم. الرصيد السالب مرفوض.';
comment on column public.inventory_movements.unit_cost     is 'لقطة من تكلفة الوحدة وقت الحركة — للتقارير التاريخية';
comment on column public.inventory_movements.balance_after is 'الرصيد الكلي بعد هذه الحركة — يُتحقق منه في تدقيق الأرصدة';
comment on column public.inventory_movements.ref_type      is 'نوع المستند: supply_order / kitchen_issue / kitchen_batch / branch_order / stocktake / import';
comment on column public.inventory_movements.ref_id        is 'معرّف UUID المستند المرجعي';

-- فهارس الاستعلام الأساسية
create index if not exists idx_inv_movements_warehouse_item
  on public.inventory_movements (warehouse_id, item_id);

create index if not exists idx_inv_movements_occurred_at
  on public.inventory_movements (occurred_at);

create index if not exists idx_inv_movements_item_occurred
  on public.inventory_movements (item_id, occurred_at);

create index if not exists idx_inv_movements_ref
  on public.inventory_movements (ref_type, ref_id)
  where ref_id is not null;

alter table public.inventory_movements enable row level security;

-- =============================================================================
-- § 5 — Trigger: يمنع UPDATE و DELETE على inventory_movements (immutable)
-- =============================================================================

create or replace function _prevent_movement_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  raise exception 'دفتر الحركات محمي — لا يُسمح بتعديل أو حذف الحركات المسجلة';
end;
$$;

revoke execute on function _prevent_movement_mutation() from public, anon, authenticated;

-- أزل الـ triggers القديمة لو موجودة ثم أنشئها
drop trigger if exists trg_movements_no_update on public.inventory_movements;
drop trigger if exists trg_movements_no_delete on public.inventory_movements;

create trigger trg_movements_no_update
  before update on public.inventory_movements
  for each row execute function _prevent_movement_mutation();

create trigger trg_movements_no_delete
  before delete on public.inventory_movements
  for each row execute function _prevent_movement_mutation();

-- =============================================================================
-- § 6 — دالة _post_movement: قلب النظام
--       تُدخل الحركة، تُحدِّث الرصيد، تتحقق من السالب،
--       تُحدِّث avg_cost، تفحص الحد الأدنى وترسل إشعار
-- =============================================================================

create or replace function _post_movement(
  p_warehouse_id  uuid,
  p_item_id       uuid,
  p_type          text,
  p_qty_delta     numeric,    -- موجب أو سالب
  p_unit_cost     numeric,    -- 0 لو غير معروف
  p_ref_type      text,
  p_ref_id        uuid,
  p_note          text,
  p_created_by    uuid
)
returns numeric  -- يرجع الرصيد الجديد
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_current_qty    numeric(14,3);
  v_new_qty        numeric(14,3);
  v_item_name      text;
  v_unit_code      text;
  v_old_avg_cost   numeric(14,4);
  v_new_avg_cost   numeric(14,4);
  v_total_qty_all  numeric;   -- مجموع الرصيد في كل المخازن (لحساب avg_cost)
  v_is_main        boolean;
  v_min_level      numeric(14,3);
  v_low_alerted    boolean;
begin
  -- § 6-أ — اقفل صف الرصيد بترتيب item_id الثابت لمنع الـ deadlock
  -- (المعاملة الخارجية تستدعي هذه الدالة بالترتيب نفسه دائماً)

  -- تأكد من وجود صف في inventory_stock (upsert) مع القفل
  insert into public.inventory_stock (warehouse_id, item_id, quantity)
  values (p_warehouse_id, p_item_id, 0)
  on conflict (warehouse_id, item_id) do nothing;

  -- اقرأ الرصيد الحالي مع قفل FOR UPDATE
  select quantity into v_current_qty
  from public.inventory_stock
  where warehouse_id = p_warehouse_id and item_id = p_item_id
  for update;

  -- § 6-ب — احسب الرصيد الجديد
  v_new_qty := v_current_qty + p_qty_delta;

  -- § 6-ج — رفض الرصيد السالب مع رسالة عربية واضحة
  if v_new_qty < 0 then
    select name, unit_code into v_item_name, v_unit_code
    from public.inventory_items
    where id = p_item_id;

    raise exception 'رصيد غير كافٍ — الصنف: % | المتاح: % % | المطلوب: % %',
      v_item_name,
      v_current_qty,
      v_unit_code,
      abs(p_qty_delta),
      v_unit_code;
  end if;

  -- § 6-د — تحديث الرصيد
  update public.inventory_stock
  set quantity   = v_new_qty,
      updated_at = now()
  where warehouse_id = p_warehouse_id and item_id = p_item_id;

  -- § 6-هـ — تسجيل الحركة في دفتر الحركات
  insert into public.inventory_movements (
    occurred_at, warehouse_id, item_id, movement_type,
    qty_delta, unit_cost, balance_after,
    ref_type, ref_id, note, created_by
  ) values (
    now(), p_warehouse_id, p_item_id, p_type,
    p_qty_delta, p_unit_cost, v_new_qty,
    p_ref_type, p_ref_id, p_note, p_created_by
  );

  -- § 6-و — تحديث avg_cost عند الاستلام أو الرصيد الافتتاحي
  --   المعادلة (متوسط مرجّح):
  --   avg_cost_جديد = (إجمالي_التكلفة_الحالي + qty_delta × unit_cost)
  --                   / (إجمالي_الرصيد_الجديد_في_كل_المخازن)
  --   حيث إجمالي_التكلفة_الحالي = avg_cost_حالي × إجمالي_الرصيد_القديم
  if p_type in ('supply_receipt', 'opening') and p_qty_delta > 0 and p_unit_cost > 0 then

    -- مجموع الرصيد في كل المخازن بعد التحديث
    select coalesce(sum(quantity), 0) into v_total_qty_all
    from public.inventory_stock
    where item_id = p_item_id;

    select avg_cost into v_old_avg_cost
    from public.inventory_items
    where id = p_item_id;

    -- إجمالي الرصيد قبل الإضافة الحالية = v_total_qty_all - p_qty_delta
    -- لو الرصيد الكلي الجديد صفر: لا نغيّر avg_cost
    if v_total_qty_all > 0 then
      v_new_avg_cost :=
        (v_old_avg_cost * (v_total_qty_all - p_qty_delta) + p_unit_cost * p_qty_delta)
        / v_total_qty_all;

      update public.inventory_items
      set avg_cost   = round(v_new_avg_cost, 4),
          updated_at = now()
      where id = p_item_id;
    end if;
  end if;

  -- § 6-ز — فحص الحد الأدنى (فقط للمستودع الرئيسي)
  select (kind = 'main') into v_is_main
  from public.warehouses
  where id = p_warehouse_id;

  if v_is_main then
    select min_level, low_stock_alerted
    into v_min_level, v_low_alerted
    from public.inventory_items
    where id = p_item_id;

    if v_new_qty <= v_min_level and v_min_level > 0 and not v_low_alerted then
      -- العبور نحو الأسفل: أرسل إشعاراً ومرّر الراية
      perform _notify(
        'low_stock',
        array['accounting', 'warehouse'],
        null,  -- ليس خاصاً بفرع
        'مخزون منخفض: ' || (select name from public.inventory_items where id = p_item_id),
        'الرصيد الحالي ' || v_new_qty::text || ' ' ||
          (select unit_code from public.inventory_items where id = p_item_id) ||
          ' — الحد الأدنى ' || v_min_level::text,
        jsonb_build_object(
          'ref_type', 'inventory_item',
          'ref_id',   p_item_id,
          'domains',  array['inv_stock', 'inv_catalog']
        )
      );

      update public.inventory_items
      set low_stock_alerted = true,
          updated_at        = now()
      where id = p_item_id;

    elsif v_new_qty > v_min_level and v_low_alerted then
      -- تعافى الرصيد: أعد الراية لـ false حتى نرسل إشعاراً مرة ثانية عند العبور التالي
      update public.inventory_items
      set low_stock_alerted = false,
          updated_at        = now()
      where id = p_item_id;
    end if;
  end if;

  return v_new_qty;
end;
$$;

revoke execute on function _post_movement(uuid, uuid, text, numeric, numeric, text, uuid, text, uuid)
  from public, anon, authenticated;

comment on function _post_movement(uuid, uuid, text, numeric, numeric, text, uuid, text, uuid) is
  'قلب النظام: يسجّل الحركة، يُحدِّث الرصيد، يرفض السالب، يُحدِّث avg_cost، يفحص الحد الأدنى.';

-- =============================================================================
-- § 7 — RPC: inventory_get_stock
--       يجلب أرصدة مستودع معين (أو الرئيسي) منذ تاريخ محدد
-- =============================================================================

create or replace function inventory_get_stock(
  p_warehouse_id uuid     default null,  -- null = المستودع الرئيسي
  p_since        timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_wh_id   uuid;
  v_result  jsonb;
  v_since   timestamptz;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper', 'accountant') then
    raise exception 'ليس لديك صلاحية الاطلاع على أرصدة المستودع';
  end if;

  -- تحديد المستودع
  if p_warehouse_id is null then
    select id into v_wh_id from public.warehouses where kind = 'main';
  else
    v_wh_id := p_warehouse_id;
  end if;

  -- هامش أمان 10 ثواني
  v_since := case
    when p_since is null then null
    else p_since - interval '10 seconds'
  end;

  select jsonb_agg(jsonb_build_object(
    'item_id',    s.item_id,
    'quantity',   s.quantity,
    'updated_at', s.updated_at
  ))
  into v_result
  from public.inventory_stock s
  where s.warehouse_id = v_wh_id
    and (v_since is null or s.updated_at >= v_since);

  return jsonb_build_object(
    'warehouse_id', v_wh_id,
    'stock',        coalesce(v_result, '[]'::jsonb),
    'fetched_at',   now()
  );
end;
$$;

comment on function inventory_get_stock(uuid, timestamptz) is
  'يجلب أرصدة مستودع (الرئيسي افتراضياً) منذ تاريخ محدد للـ delta sync.';

grant execute on function inventory_get_stock(uuid, timestamptz) to authenticated;

-- =============================================================================
-- § 8 — RPC: inventory_get_item_movements
--       حركات صنف واحد — لا تُحمَّل إلا عند طلب المستخدم الصريح (آخر 50)
-- =============================================================================

create or replace function inventory_get_item_movements(
  p_item_id      uuid,
  p_warehouse_id uuid    default null,  -- null = كل المخازن
  p_limit        int     default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper', 'accountant') then
    raise exception 'ليس لديك صلاحية الاطلاع على حركات المخزون';
  end if;

  select jsonb_agg(row_data order by row_data->>'occurred_at' desc)
  into v_result
  from (
    select jsonb_build_object(
      'id',            m.id,
      'occurred_at',   m.occurred_at,
      'warehouse_id',  m.warehouse_id,
      'movement_type', m.movement_type,
      'qty_delta',     m.qty_delta,
      'unit_cost',     m.unit_cost,
      'balance_after', m.balance_after,
      'ref_type',      m.ref_type,
      'ref_id',        m.ref_id,
      'note',          m.note
    ) as row_data
    from public.inventory_movements m
    where m.item_id = p_item_id
      and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
    order by m.occurred_at desc
    limit least(p_limit, 200)  -- حد أقصى 200 حركة
  ) sub;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

comment on function inventory_get_item_movements(uuid, uuid, int) is
  'حركات صنف واحد — تُجلب عند الطلب فقط، ليست مخزنة في الكاش.';

grant execute on function inventory_get_item_movements(uuid, uuid, int) to authenticated;

-- =============================================================================
-- § 9 — RPC: inventory_audit_stock
--       تدقيق: أي صنف رصيده لا يساوي مجموع حركاته
--       للمالك والمحاسب فقط
-- =============================================================================

create or replace function inventory_audit_stock()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('accountant') then
    raise exception 'هذه العملية للمحاسب والمالك فقط';
  end if;

  -- قارن الرصيد المحسوب من الحركات بالرصيد المخزن في inventory_stock
  select jsonb_agg(jsonb_build_object(
    'warehouse_id',     s.warehouse_id,
    'item_id',          s.item_id,
    'item_sku',         i.sku,
    'item_name',        i.name,
    'stored_qty',       s.quantity,
    'computed_qty',     coalesce(m.total_delta, 0),
    'discrepancy',      s.quantity - coalesce(m.total_delta, 0)
  ))
  into v_result
  from public.inventory_stock s
  join public.inventory_items i on i.id = s.item_id
  left join (
    select warehouse_id, item_id, sum(qty_delta) as total_delta
    from public.inventory_movements
    group by warehouse_id, item_id
  ) m on m.warehouse_id = s.warehouse_id and m.item_id = s.item_id
  where abs(s.quantity - coalesce(m.total_delta, 0)) > 0.001;  -- تساهل رقمي

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

comment on function inventory_audit_stock() is
  'تُرجع الأصناف التي يختلف رصيدها المخزن عن مجموع حركاتها. للمحاسب والمالك فقط.';

grant execute on function inventory_audit_stock() to authenticated;

-- =============================================================================
-- نهاية الملف
-- =============================================================================
