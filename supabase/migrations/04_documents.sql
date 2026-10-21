-- =============================================================================
-- 04_documents.sql
-- المستندات: التوريد، المطبخ، الجرد، طلبات الفروع، الاستيراد
-- كل الجداول والـ RPC — قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================

-- =============================================================================
-- § 1 — طلبات التوريد (Supply Orders)
-- =============================================================================

-- 1-أ) رأس الطلب
create table if not exists public.supply_orders (
  id               uuid        primary key default gen_random_uuid(),
  number           text        not null unique,   -- PO-2026-0001
  client_id        uuid        not null unique,   -- للتكرار الآمن
  supplier_id      uuid        not null references public.suppliers(id),
  expected_date    date        not null,
  priority         text        not null default 'normal' check (priority in ('urgent', 'normal')),
  status           text        not null default 'pending_review'
                                 check (status in ('pending_review', 'approved', 'received', 'rejected', 'cancelled')),
  notes            text,
  rejection_reason text,       -- سبب الرفض (إجباري عند الرفض)
  has_issues       boolean     not null default false, -- استلام بملاحظات
  created_by       uuid        not null references auth.users(id),
  reviewed_by      uuid        references auth.users(id),  -- المحاسب
  received_by      uuid        references auth.users(id),  -- أمين المخزن
  reviewed_at      timestamptz,
  received_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  version          bigint      not null default 1
);

comment on table  public.supply_orders                  is 'رؤوس طلبات التوريد من الموردين إلى المستودع الرئيسي';
comment on column public.supply_orders.number           is 'رقم الطلب: PO-<السنة>-<تسلسلي 4 خانات>';
comment on column public.supply_orders.client_id        is 'UUID يُولَّد في التطبيق — يضمن الاستدعاء مرة واحدة';
comment on column public.supply_orders.has_issues       is 'true لو كانت الكميات المستلمة مختلفة أو فيها ملاحظات';

create index if not exists idx_supply_orders_status_created
  on public.supply_orders (status, created_at);
create index if not exists idx_supply_orders_supplier
  on public.supply_orders (supplier_id);

alter table public.supply_orders enable row level security;

create or replace trigger trg_supply_orders_updated_at
  before update on public.supply_orders
  for each row execute function public.set_updated_at();
create or replace trigger trg_supply_orders_version
  before update on public.supply_orders
  for each row execute function public.bump_version();

-- 1-ب) سطور الطلب
create table if not exists public.supply_order_lines (
  id             uuid           primary key default gen_random_uuid(),
  order_id       uuid           not null references public.supply_orders(id),
  item_id        uuid           not null references public.inventory_items(id),
  qty_requested  numeric(14,3)  not null check (qty_requested > 0),
  qty_approved   numeric(14,3),                    -- يُحدَّث عند المراجعة
  qty_received   numeric(14,3),                    -- يُحدَّث عند الاستلام
  unit_cost      numeric(12,2)  not null default 0 check (unit_cost >= 0),
  line_note      text,
  created_at     timestamptz    not null default now(),
  updated_at     timestamptz    not null default now()
);

comment on table  public.supply_order_lines              is 'سطور طلبات التوريد — صنف + كميات مطلوبة/معتمدة/مستلمة';
comment on column public.supply_order_lines.qty_approved is 'الكمية المعتمدة من المحاسب — قد تختلف عن المطلوبة';
comment on column public.supply_order_lines.qty_received is 'الكمية المستلمة فعلياً — قد تختلف عن المعتمدة';

create index if not exists idx_supply_order_lines_order
  on public.supply_order_lines (order_id);
create index if not exists idx_supply_order_lines_item
  on public.supply_order_lines (item_id);

alter table public.supply_order_lines enable row level security;

create or replace trigger trg_supply_order_lines_updated_at
  before update on public.supply_order_lines
  for each row execute function public.set_updated_at();

-- =============================================================================
-- § 2 — RPCs طلبات التوريد
-- =============================================================================

-- 2-أ) create_supply_order: إنشاء طلب توريد
create or replace function create_supply_order(
  p_client_id     uuid,
  p_supplier_name text,
  p_supplier_phone text default null,
  p_expected_date date default null,
  p_priority      text default 'normal',
  p_notes         text default null,
  p_lines         jsonb default null -- [{item_id, qty_requested, unit_cost?}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id    uuid := auth.uid();
  v_order_id   uuid;
  v_number     text;
  v_supplier_id uuid;
  v_year       text;
  v_line       jsonb;
  v_existing   jsonb;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'إنشاء طلبات التوريد لأمين المخزن فقط';
  end if;

  if p_expected_date is null then
    raise exception 'تاريخ التوريد المتوقع مطلوب';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف لطلب التوريد';
  end if;

  -- تحقق من التكرار (idempotency)
  select jsonb_build_object('ok', true, 'doc', jsonb_build_object('id', id, 'number', number))
  into v_existing
  from public.supply_orders
  where client_id = p_client_id;

  if v_existing is not null then
    return v_existing;
  end if;

  -- المورد: ابحث أو أنشئ (case-insensitive)
  insert into public.suppliers (name, phone)
  values (trim(p_supplier_name), p_supplier_phone)
  on conflict (lower(trim(name))) do update
    set phone      = coalesce(p_supplier_phone, suppliers.phone),
        updated_at = now()
  returning id into v_supplier_id;

  -- توليد رقم الطلب
  v_year   := to_char(current_date at time zone
                (select value from public.app_settings where key = 'timezone'),
              'YYYY');
  v_number := _next_doc_number('po', v_year, 'PO-{scope}-{n:4}');

  -- إنشاء رأس الطلب
  insert into public.supply_orders (
    client_id, number, supplier_id,
    expected_date, priority, notes, created_by
  ) values (
    p_client_id, v_number, v_supplier_id,
    p_expected_date, p_priority, p_notes, v_user_id
  )
  returning id into v_order_id;

  -- إدراج السطور
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.supply_order_lines (
      order_id, item_id, qty_requested, unit_cost
    ) values (
      v_order_id,
      (v_line->>'item_id')::uuid,
      (v_line->>'qty_requested')::numeric,
      coalesce((v_line->>'unit_cost')::numeric, 0)
    );
  end loop;

  -- بصمات البيانات
  perform _bump_data_version('inv_supply');

  -- إشعار للمحاسب
  perform _notify(
    'supply_submitted',
    array['accounting'],
    null,
    'طلب توريد جديد: ' || v_number,
    'من: ' || trim(p_supplier_name) || ' — الأولوية: ' ||
      case p_priority when 'urgent' then 'عاجل' else 'عادي' end,
    jsonb_build_object('ref_type', 'supply_order', 'ref_id', v_order_id, 'domains', array['inv_supply'])
  );

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', v_order_id, 'number', v_number),
    'stamps', jsonb_build_object('inv_supply',
                (select version from public.data_versions where key = 'inv_supply'))
  );
end;
$$;

grant execute on function create_supply_order(uuid, text, text, date, text, text, jsonb) to authenticated;
comment on function create_supply_order(uuid, text, text, date, text, text, jsonb) is
  'يُنشئ طلب توريد جديد مع سطوره. آمن من التكرار بـ client_id.';

-- 2-ب) review_supply_order: مراجعة طلب التوريد (موافقة/رفض)
create or replace function review_supply_order(
  p_order_id        uuid,
  p_expected_version bigint,
  p_decision        text,   -- 'approved' | 'rejected'
  p_rejection_reason text   default null,
  p_lines           jsonb   default null  -- [{line_id, qty_approved, unit_cost}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_order   record;
  v_line    jsonb;
  v_all_zero boolean;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('accountant') then
    raise exception 'مراجعة طلبات التوريد للمحاسب فقط';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'قرار غير صالح: %', p_decision;
  end if;

  -- اقرأ الطلب مع قفل
  select id, status, version into v_order
  from public.supply_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'طلب التوريد غير موجود';
  end if;

  -- تحقق من الحالة
  if v_order.status != 'pending_review' then
    raise exception 'لا يمكن مراجعة طلب حالته: %', v_order.status;
  end if;

  -- تحقق من نسخة التزامن
  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  if p_decision = 'approved' then
    -- تحقق أن ليست كل الكميات المعتمدة صفراً
    if p_lines is not null then
      select bool_and((l->>'qty_approved')::numeric = 0)
      into v_all_zero
      from jsonb_array_elements(p_lines) l;

      if v_all_zero then
        raise exception 'لا يمكن الموافقة على طلب بكميات معتمدة صفر لجميع السطور. استخدم خيار الرفض.';
      end if;

      -- تحديث سطور الطلب
      for v_line in select * from jsonb_array_elements(p_lines)
      loop
        update public.supply_order_lines
        set qty_approved = (v_line->>'qty_approved')::numeric,
            unit_cost    = coalesce((v_line->>'unit_cost')::numeric, unit_cost),
            updated_at   = now()
        where id = (v_line->>'line_id')::uuid
          and order_id = p_order_id;
      end loop;
    end if;

    update public.supply_orders
    set status      = 'approved',
        reviewed_by = v_user_id,
        reviewed_at = now()
    where id = p_order_id;

    -- إشعار لأمين المخزن
    perform _notify(
      'supply_approved',
      array['warehouse'],
      null,
      'تمت موافقة المحاسب على طلب التوريد',
      'الطلب جاهز للاستلام',
      jsonb_build_object('ref_type', 'supply_order', 'ref_id', p_order_id, 'domains', array['inv_supply'])
    );
  else
    if p_rejection_reason is null or trim(p_rejection_reason) = '' then
      raise exception 'سبب الرفض إجباري';
    end if;

    update public.supply_orders
    set status           = 'rejected',
        rejection_reason = p_rejection_reason,
        reviewed_by      = v_user_id,
        reviewed_at      = now()
    where id = p_order_id;
  end if;

  perform _bump_data_version('inv_supply');

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', p_order_id, 'status', p_decision),
    'stamps', jsonb_build_object('inv_supply',
                (select version from public.data_versions where key = 'inv_supply'))
  );
end;
$$;

grant execute on function review_supply_order(uuid, bigint, text, text, jsonb) to authenticated;

-- 2-ج) receive_supply_order: استلام طلب التوريد وإضافته للمخزون
create or replace function receive_supply_order(
  p_client_id        uuid,
  p_order_id         uuid,
  p_expected_version bigint,
  p_general_note     text  default null,
  p_lines            jsonb default null         -- [{line_id, qty_received, note?}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id    uuid := auth.uid();
  v_order      record;
  v_line_rec   record;
  v_line       jsonb;
  v_main_wh_id uuid;
  v_qty_recv   numeric;
  v_unit_cost  numeric;
  v_qty_appr   numeric;
  v_has_issues boolean := false;
  v_stock_rows jsonb   := '[]'::jsonb;
  v_new_qty    numeric;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'استلام التوريد لأمين المخزن فقط';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للاستلام';
  end if;

  -- تحقق من التكرار
  perform 1 from public.supply_orders
  where id = p_order_id and status = 'received';
  if found then
    -- أعد النتيجة المخزنة
    return jsonb_build_object('ok', true, 'doc',
      jsonb_build_object('id', p_order_id, 'status', 'received'));
  end if;

  -- اقرأ الطلب مع قفل
  select id, status, version into v_order
  from public.supply_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'طلب التوريد غير موجود';
  end if;

  if v_order.status != 'approved' then
    raise exception 'لا يمكن الاستلام — حالة الطلب الحالية: %', v_order.status;
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  -- المستودع الرئيسي
  select id into v_main_wh_id from public.warehouses where kind = 'main';

  -- معالجة كل سطر
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select l.qty_approved, l.unit_cost, l.item_id
    into v_qty_appr, v_unit_cost, v_line_rec.item_id
    from public.supply_order_lines l
    where l.id = (v_line->>'line_id')::uuid
      and l.order_id = p_order_id;

    v_qty_recv := coalesce((v_line->>'qty_received')::numeric, v_qty_appr);

    -- تحقق من وجود مشكلة (كمية مختلفة أو ملاحظة)
    if v_qty_recv != v_qty_appr
       or (v_line->>'note' is not null and trim(v_line->>'note') != '') then
      v_has_issues := true;
    end if;

    -- تحديث السطر
    update public.supply_order_lines
    set qty_received = v_qty_recv,
        line_note    = coalesce(v_line->>'note', line_note),
        updated_at   = now()
    where id = (v_line->>'line_id')::uuid;

    -- أضف للمخزون لو الكمية المستلمة > 0
    if v_qty_recv > 0 then
      v_new_qty := _post_movement(
        v_main_wh_id,
        v_line_rec.item_id,
        'supply_receipt',
        v_qty_recv,
        v_unit_cost,
        'supply_order',
        p_order_id,
        'استلام من طلب التوريد',
        v_user_id
      );

      v_stock_rows := v_stock_rows || jsonb_build_object(
        'item_id', v_line_rec.item_id,
        'quantity', v_new_qty
      );
    end if;
  end loop;

  -- تحديث حالة الطلب
  update public.supply_orders
  set status      = 'received',
      has_issues  = v_has_issues,
      notes       = coalesce(p_general_note, notes),
      received_by = v_user_id,
      received_at = now()
  where id = p_order_id;

  -- بصمات البيانات
  perform _bump_data_version('inv_supply');
  perform _bump_data_version('inv_stock');
  perform _bump_data_version('inv_catalog');  -- avg_cost قد تغيّر

  -- إشعار للمحاسب لو في ملاحظات
  if v_has_issues then
    perform _notify(
      'supply_received_issues',
      array['accounting'],
      null,
      'استلام توريد بملاحظات',
      'تم استلام الطلب مع وجود فروقات أو ملاحظات — يُنصح بالمراجعة',
      jsonb_build_object('ref_type', 'supply_order', 'ref_id', p_order_id, 'domains', array['inv_supply', 'inv_stock'])
    );
  end if;

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', p_order_id, 'status', 'received', 'has_issues', v_has_issues),
    'stock',  v_stock_rows,
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply'),
      'inv_stock',  (select version from public.data_versions where key = 'inv_stock'),
      'inv_catalog',(select version from public.data_versions where key = 'inv_catalog')
    )
  );
end;
$$;

grant execute on function receive_supply_order(uuid, uuid, bigint, text, jsonb) to authenticated;

-- =============================================================================
-- § 3 — صرف الخامات للمطبخ (Kitchen Issues)
-- =============================================================================

create table if not exists public.kitchen_issues (
  id           uuid        primary key default gen_random_uuid(),
  number       text        not null unique,   -- ISSUE-2026-0001
  client_id    uuid        not null unique,
  cook_plan    text,
  chef_name    text        not null,
  shift        text        not null check (shift in ('morning', 'evening')),
  notes        text,
  created_by   uuid        not null references auth.users(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table  public.kitchen_issues          is 'صرف الخامات للمطبخ — يخصم من المستودع الرئيسي فوراً';
comment on column public.kitchen_issues.shift    is 'الوردية: morning صباح / evening مساء';
comment on column public.kitchen_issues.cook_plan is 'خطة الطهي — ماذا سيُطبخ من هذه الخامات';

create index if not exists idx_kitchen_issues_created
  on public.kitchen_issues (created_at desc);

alter table public.kitchen_issues enable row level security;

create or replace trigger trg_kitchen_issues_updated_at
  before update on public.kitchen_issues
  for each row execute function public.set_updated_at();

create table if not exists public.kitchen_issue_lines (
  id               uuid           primary key default gen_random_uuid(),
  issue_id         uuid           not null references public.kitchen_issues(id),
  item_id          uuid           not null references public.inventory_items(id),
  qty              numeric(14,3)  not null check (qty > 0),
  unit_cost_snapshot numeric(14,4) not null default 0,  -- avg_cost وقت الصرف
  created_at       timestamptz    not null default now()
);

comment on table  public.kitchen_issue_lines                    is 'سطور صرف الخامات للمطبخ';
comment on column public.kitchen_issue_lines.unit_cost_snapshot is 'لقطة من avg_cost وقت الصرف — لحسابات تكلفة الأكل';

create index if not exists idx_kitchen_issue_lines_issue
  on public.kitchen_issue_lines (issue_id);
create index if not exists idx_kitchen_issue_lines_item
  on public.kitchen_issue_lines (item_id);

alter table public.kitchen_issue_lines enable row level security;

-- RPC: create_kitchen_issue
create or replace function create_kitchen_issue(
  p_client_id uuid,
  p_cook_plan text    default null,
  p_chef_name text    default null,
  p_shift     text    default null,
  p_notes     text    default null,
  p_lines     jsonb   default null   -- [{item_id, qty}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id    uuid := auth.uid();
  v_issue_id   uuid;
  v_number     text;
  v_year       text;
  v_main_wh_id uuid;
  v_line       jsonb;
  v_avg_cost   numeric;
  v_new_qty    numeric;
  v_stock_rows jsonb := '[]'::jsonb;
  v_existing   record;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'صرف الخامات لأمين المخزن فقط';
  end if;

  if p_chef_name is null or trim(p_chef_name) = '' then
    raise exception 'اسم الشيف مطلوب';
  end if;
  if p_shift is null or trim(p_shift) = '' then
    raise exception 'الوردية مطلوبة';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للصرف';
  end if;

  -- idempotency
  select id, number into v_existing
  from public.kitchen_issues
  where client_id = p_client_id;

  if found then
    return jsonb_build_object('ok', true, 'doc',
      jsonb_build_object('id', v_existing.id, 'number', v_existing.number));
  end if;

  v_year   := to_char(current_date at time zone
                (select value from public.app_settings where key = 'timezone'), 'YYYY');
  v_number := _next_doc_number('issue', v_year, 'ISSUE-{scope}-{n:4}');

  insert into public.kitchen_issues (client_id, number, cook_plan, chef_name, shift, notes, created_by)
  values (p_client_id, v_number, p_cook_plan, p_chef_name, p_shift, p_notes, v_user_id)
  returning id into v_issue_id;

  select id into v_main_wh_id from public.warehouses where kind = 'main';

  -- صرف الخامات (كل السطور أو لا شيء — في نفس المعاملة)
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    -- التقط avg_cost حالياً لقطة للتقارير
    select avg_cost into v_avg_cost
    from public.inventory_items
    where id = (v_line->>'item_id')::uuid;

    insert into public.kitchen_issue_lines (issue_id, item_id, qty, unit_cost_snapshot)
    values (v_issue_id, (v_line->>'item_id')::uuid,
            (v_line->>'qty')::numeric, coalesce(v_avg_cost, 0));

    -- الخصم من المستودع (سيرفض لو الرصيد ما يكفي)
    v_new_qty := _post_movement(
      v_main_wh_id,
      (v_line->>'item_id')::uuid,
      'kitchen_issue',
      -((v_line->>'qty')::numeric),  -- سالب = خصم
      coalesce(v_avg_cost, 0),
      'kitchen_issue',
      v_issue_id,
      'صرف للمطبخ — ' || p_chef_name,
      v_user_id
    );

    v_stock_rows := v_stock_rows || jsonb_build_object(
      'item_id', (v_line->>'item_id')::uuid,
      'quantity', v_new_qty
    );
  end loop;

  perform _bump_data_version('inv_kitchen');
  perform _bump_data_version('inv_stock');

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', v_issue_id, 'number', v_number),
    'stock',  v_stock_rows,
    'stamps', jsonb_build_object(
      'inv_kitchen', (select version from public.data_versions where key = 'inv_kitchen'),
      'inv_stock',   (select version from public.data_versions where key = 'inv_stock')
    )
  );
end;
$$;

grant execute on function create_kitchen_issue(uuid, text, text, text, text, jsonb) to authenticated;

-- =============================================================================
-- § 4 — استلام إنتاج المطبخ (Kitchen Batches)
-- =============================================================================

create table if not exists public.kitchen_batches (
  id              uuid        primary key default gen_random_uuid(),
  number          text        not null unique,   -- BATCH-2026-1002-0001
  client_id       uuid        not null unique,
  item_id         uuid        not null references public.inventory_items(id),  -- الصنف التام
  quantity        numeric(14,3) not null check (quantity > 0),
  production_line text,
  produced_at     timestamptz not null,
  finished_at     timestamptz not null check (finished_at >= produced_at),
  quality_note    text,
  created_by      uuid        not null references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table  public.kitchen_batches              is 'دفعات إنتاج المطبخ — تُضيف منتجات تامة للمستودع الرئيسي';
comment on column public.kitchen_batches.item_id      is 'الصنف التام — في تصنيف FIN — يُنشأ تلقائياً لو جديد';
comment on column public.kitchen_batches.quantity     is 'عدد الوجبات / الوحدات المنتجة';

create index if not exists idx_kitchen_batches_item
  on public.kitchen_batches (item_id);
create index if not exists idx_kitchen_batches_produced
  on public.kitchen_batches (produced_at desc);

alter table public.kitchen_batches enable row level security;

create or replace trigger trg_kitchen_batches_updated_at
  before update on public.kitchen_batches
  for each row execute function public.set_updated_at();

-- RPC: create_kitchen_batch
create or replace function create_kitchen_batch(
  p_client_id       uuid,
  p_item_id         uuid    default null,  -- null = إنشاء صنف جديد
  p_new_item_name   text    default null,  -- اسم الصنف الجديد لو item_id null
  p_new_item_unit   text    default 'عبوة',
  p_quantity        numeric default null,
  p_production_line text    default null,
  p_produced_at     timestamptz default null,
  p_finished_at     timestamptz default null,
  p_quality_note    text    default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id    uuid := auth.uid();
  v_batch_id   uuid;
  v_number     text;
  v_year       text;
  v_mmdd       text;
  v_item_id    uuid;
  v_fin_cat_id uuid;
  v_main_wh_id uuid;
  v_new_qty    numeric;
  v_sku        text;
  v_existing   record;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'استلام إنتاج المطبخ لأمين المخزن فقط';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'الكمية المنتجة مطلوبة ويجب أن تكون أكبر من صفر';
  end if;
  if p_produced_at is null then
    raise exception 'تاريخ الإنتاج مطلوب';
  end if;
  if p_finished_at is null then
    raise exception 'تاريخ الانتهاء مطلوب';
  end if;

  -- idempotency
  select id, number into v_existing
  from public.kitchen_batches
  where client_id = p_client_id;

  if found then
    return jsonb_build_object('ok', true, 'doc',
      jsonb_build_object('id', v_existing.id, 'number', v_existing.number));
  end if;

  -- تحديد الصنف التام
  if p_item_id is not null then
    v_item_id := p_item_id;
    -- تأكد أنه في تصنيف FIN
    perform 1
    from public.inventory_items i
    join public.inventory_categories c on c.id = i.category_id
    where i.id = v_item_id and c.code = 'FIN';
    if not found then
      raise exception 'الصنف المحدد ليس من نوع منتج تام (FIN)';
    end if;
  else
    -- إنشاء صنف تام جديد
    if p_new_item_name is null or trim(p_new_item_name) = '' then
      raise exception 'يجب تحديد اسم الصنف الجديد';
    end if;

    select id into v_fin_cat_id
    from public.inventory_categories
    where code = 'FIN';

    -- توليد SKU تلقائي للمنتج التام
    v_sku := _next_doc_number('fin_sku', 'FIN', 'FIN-{n:4}');

    insert into public.inventory_items (
      sku, name, category_id, unit_code, branch_orderable, created_by
    ) values (
      v_sku, trim(p_new_item_name), v_fin_cat_id, p_new_item_unit, true, v_user_id
    )
    returning id into v_item_id;

    -- بصمة الكتالوج
    perform _bump_data_version('inv_catalog');
  end if;

  -- توليد رقم الدفعة BATCH-2026-1002-0001
  v_year := to_char(p_produced_at at time zone
              (select value from public.app_settings where key = 'timezone'), 'YYYY');
  v_mmdd := to_char(p_produced_at at time zone
              (select value from public.app_settings where key = 'timezone'), 'MMDD');
  v_number := _next_doc_number('batch', v_year || ':' || v_mmdd,
                'BATCH-' || v_year || '-' || v_mmdd || '-{n:4}');

  insert into public.kitchen_batches (
    client_id, number, item_id, quantity,
    production_line, produced_at, finished_at, quality_note, created_by
  ) values (
    p_client_id, v_number, v_item_id, p_quantity,
    p_production_line, p_produced_at, p_finished_at, p_quality_note, v_user_id
  )
  returning id into v_batch_id;

  -- أضف للمستودع الرئيسي
  select id into v_main_wh_id from public.warehouses where kind = 'main';

  v_new_qty := _post_movement(
    v_main_wh_id,
    v_item_id,
    'kitchen_output',
    p_quantity,
    0,  -- المنتج التام بدون تكلفة مباشرة من هنا (ترتبط بتكلفة الخامات)
    'kitchen_batch',
    v_batch_id,
    'إنتاج مطبخ — ' || v_number,
    v_user_id
  );

  perform _bump_data_version('inv_kitchen');
  perform _bump_data_version('inv_stock');

  return jsonb_build_object(
    'ok',      true,
    'doc',     jsonb_build_object('id', v_batch_id, 'number', v_number, 'item_id', v_item_id),
    'stock',   jsonb_build_array(jsonb_build_object('item_id', v_item_id, 'quantity', v_new_qty)),
    'stamps',  jsonb_build_object(
      'inv_kitchen', (select version from public.data_versions where key = 'inv_kitchen'),
      'inv_stock',   (select version from public.data_versions where key = 'inv_stock'),
      'inv_catalog', (select version from public.data_versions where key = 'inv_catalog')
    )
  );
end;
$$;

grant execute on function create_kitchen_batch(uuid, uuid, text, text, numeric, text, timestamptz, timestamptz, text) to authenticated;

-- =============================================================================
-- § 5 — الجرد (Stocktakes)
-- =============================================================================

create table if not exists public.stocktakes (
  id           uuid           primary key default gen_random_uuid(),
  number       text           not null unique,   -- STK-2026-0001
  client_id    uuid           not null unique,
  warehouse_id uuid           not null references public.warehouses(id),
  notes        text,
  total_items  int            not null default 0,
  total_adjust numeric(14,3)  not null default 0,  -- مجموع التعديلات
  total_damage numeric(14,3)  not null default 0,  -- مجموع التالف
  applied_by   uuid           not null references auth.users(id),
  created_at   timestamptz    not null default now(),
  updated_at   timestamptz    not null default now()
);

comment on table public.stocktakes is 'رؤوس الجرديات — تُطبَّق من ملف Excel بتصريح إدارة';

create index if not exists idx_stocktakes_created
  on public.stocktakes (created_at desc);

alter table public.stocktakes enable row level security;

create or replace trigger trg_stocktakes_updated_at
  before update on public.stocktakes
  for each row execute function public.set_updated_at();

create table if not exists public.stocktake_lines (
  id           uuid           primary key default gen_random_uuid(),
  stocktake_id uuid           not null references public.stocktakes(id),
  item_id      uuid           not null references public.inventory_items(id),
  system_qty   numeric(14,3)  not null,   -- الرصيد وقت التطبيق (بقفل)
  counted_qty  numeric(14,3)  not null check (counted_qty >= 0),
  damaged_qty  numeric(14,3)  not null default 0 check (damaged_qty >= 0),
  adjust_qty   numeric(14,3)  not null,   -- counted - (system - damaged)
  note         text,
  unit_cost    numeric(14,4)  not null default 0
);

comment on table  public.stocktake_lines            is 'سطور الجرد — نتيجة كل صنف';
comment on column public.stocktake_lines.system_qty is 'رصيد النظام وقت تطبيق الجرد (بقفل لضمان الدقة)';
comment on column public.stocktake_lines.adjust_qty is 'التعديل الصافي = counted - (system - damaged)';

create index if not exists idx_stocktake_lines_stocktake
  on public.stocktake_lines (stocktake_id);
create index if not exists idx_stocktake_lines_item
  on public.stocktake_lines (item_id);

alter table public.stocktake_lines enable row level security;

-- RPC: apply_stocktake
create or replace function apply_stocktake(
  p_client_id    uuid,
  p_token        uuid,    -- تصريح الإدارة (null للمعاينة dry_run)
  p_dry_run      boolean  default false,
  p_warehouse_id uuid     default null,  -- null = الرئيسي
  p_notes        text     default null,
  p_lines        jsonb    default null    -- [{sku, counted_qty, damaged_qty?, note?}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id    uuid := auth.uid();
  v_wh_id      uuid;
  v_stocktake_id uuid;
  v_number     text;
  v_year       text;
  v_line       jsonb;
  v_item       record;
  v_system_qty numeric;
  v_counted    numeric;
  v_damaged    numeric;
  v_adjust     numeric;
  v_results    jsonb := '[]'::jsonb;
  v_errors     jsonb := '[]'::jsonb;
  v_has_error  boolean := false;
  v_total_adj  numeric := 0;
  v_total_dmg  numeric := 0;
  v_total_cnt  int     := 0;
  v_stock_rows jsonb   := '[]'::jsonb;
  v_new_qty    numeric;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'تطبيق الجرد لأمين المخزن فقط';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب توفير أصناف للجرد';
  end if;

  -- التصريح إجباري للتطبيق الفعلي
  if not p_dry_run then
    if p_token is null then
      raise exception 'يجب تقديم تصريح الإدارة لتطبيق الجرد';
    end if;

    -- تحقق من التصريح
    perform 1 from public.admin_approvals
    where token    = p_token
      and user_id  = v_user_id
      and action   = 'inventory_stocktake'
      and expires_at > now()
      and used_at is null;
    if not found then
      raise exception 'تصريح الإدارة غير صالح أو منتهي الصلاحية';
    end if;

    -- idempotency
    perform 1 from public.stocktakes where client_id = p_client_id;
    if found then
      return jsonb_build_object('ok', true, 'dry_run', false, 'idempotent', true);
    end if;
  end if;

  -- المستودع
  if p_warehouse_id is null then
    select id into v_wh_id from public.warehouses where kind = 'main';
  else
    v_wh_id := p_warehouse_id;
  end if;

  -- معالجة كل سطر
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    v_counted := (v_line->>'counted_qty')::numeric;
    v_damaged := coalesce((v_line->>'damaged_qty')::numeric, 0);

    -- ابحث عن الصنف بالـ SKU
    select i.id, i.sku, i.name, i.unit_code, i.avg_cost
    into v_item
    from public.inventory_items i
    where upper(trim(i.sku)) = upper(trim(v_line->>'sku'))
      and i.is_active = true;

    if not found then
      v_has_error := true;
      v_errors := v_errors || jsonb_build_object(
        'sku',   v_line->>'sku',
        'error', 'الصنف غير موجود أو معطّل'
      );
      continue;
    end if;

    -- اقرأ رصيد النظام (بقفل في حالة التطبيق الفعلي)
    if p_dry_run then
      select coalesce(quantity, 0) into v_system_qty
      from public.inventory_stock
      where warehouse_id = v_wh_id and item_id = v_item.id;
    else
      select coalesce(s.quantity, 0) into v_system_qty
      from public.inventory_stock s
      where s.warehouse_id = v_wh_id and s.item_id = v_item.id
      for update;
    end if;

    v_system_qty := coalesce(v_system_qty, 0);

    -- تحقق: التالف لا يتجاوز الرصيد
    if v_damaged > v_system_qty then
      v_has_error := true;
      v_errors := v_errors || jsonb_build_object(
        'sku',   v_item.sku,
        'error', 'الكمية التالفة (' || v_damaged::text || ') تتجاوز رصيد النظام (' || v_system_qty::text || ')'
      );
      continue;
    end if;

    -- التالف يتطلب ملاحظة
    if v_damaged > 0 and (v_line->>'note' is null or trim(v_line->>'note') = '') then
      v_has_error := true;
      v_errors := v_errors || jsonb_build_object(
        'sku',   v_item.sku,
        'error', 'الملاحظة إجبارية عند إدخال كمية تالفة'
      );
      continue;
    end if;

    -- احسب التعديل: counted - (system - damaged)
    v_adjust := v_counted - (v_system_qty - v_damaged);

    v_results := v_results || jsonb_build_object(
      'sku',          v_item.sku,
      'name',         v_item.name,
      'unit',         v_item.unit_code,
      'system_qty',   v_system_qty,
      'counted_qty',  v_counted,
      'damaged_qty',  v_damaged,
      'adjust_qty',   v_adjust,
      'status',       case
        when v_damaged = 0 and v_adjust = 0 then 'no_change'
        when v_damaged > 0 and v_adjust = 0 then 'damage_only'
        else 'adjusted'
      end
    );

    v_total_cnt := v_total_cnt + 1;
    v_total_dmg := v_total_dmg + v_damaged;
    v_total_adj := v_total_adj + v_adjust;
  end loop;

  -- لو في أخطاء: ارفض كل العملية
  if v_has_error then
    return jsonb_build_object(
      'ok',      false,
      'dry_run', p_dry_run,
      'errors',  v_errors,
      'preview', v_results
    );
  end if;

  -- لو معاينة فقط: ارجع النتائج
  if p_dry_run then
    return jsonb_build_object(
      'ok',        true,
      'dry_run',   true,
      'preview',   v_results,
      'summary',   jsonb_build_object(
        'total_items',  v_total_cnt,
        'total_damage', v_total_dmg,
        'total_adjust', v_total_adj
      )
    );
  end if;

  -- تطبيق الجرد الفعلي
  v_year   := to_char(current_date at time zone
                (select value from public.app_settings where key = 'timezone'), 'YYYY');
  v_number := _next_doc_number('stk', v_year, 'STK-{scope}-{n:4}');

  insert into public.stocktakes (
    client_id, number, warehouse_id, notes,
    total_items, total_adjust, total_damage, applied_by
  ) values (
    p_client_id, v_number, v_wh_id, p_notes,
    v_total_cnt, v_total_adj, v_total_dmg, v_user_id
  )
  returning id into v_stocktake_id;

  -- طبّق الحركات
  for v_line in select * from jsonb_array_elements(p_results_internal(v_results))
  loop
    -- لا داعي لإعادة الحساب — استخدم النتائج المحسوبة
  end loop;

  -- طبّق الحركات بشكل مباشر
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select i.id, i.name, i.unit_code, i.avg_cost into v_item
    from public.inventory_items i
    where upper(trim(i.sku)) = upper(trim(v_line->>'sku'))
      and i.is_active = true;

    if not found then continue; end if;

    select coalesce(s.quantity, 0) into v_system_qty
    from public.inventory_stock s
    where s.warehouse_id = v_wh_id and s.item_id = v_item.id
    for update;

    v_system_qty := coalesce(v_system_qty, 0);
    v_counted    := (v_line->>'counted_qty')::numeric;
    v_damaged    := coalesce((v_line->>'damaged_qty')::numeric, 0);
    v_adjust     := v_counted - (v_system_qty - v_damaged);

    -- سجّل التالف أولاً لو > 0
    if v_damaged > 0 then
      v_new_qty := _post_movement(
        v_wh_id, v_item.id, 'damage',
        -v_damaged, v_item.avg_cost,
        'stocktake', v_stocktake_id,
        coalesce(v_line->>'note', 'تالف في الجرد'),
        v_user_id
      );
    end if;

    -- سجّل التعديل لو مختلف عن صفر
    if v_adjust != 0 then
      v_new_qty := _post_movement(
        v_wh_id, v_item.id, 'stocktake_adjust',
        v_adjust, v_item.avg_cost,
        'stocktake', v_stocktake_id,
        'تعديل جرد — ' || v_number,
        v_user_id
      );
    end if;

    insert into public.stocktake_lines (
      stocktake_id, item_id, system_qty, counted_qty,
      damaged_qty, adjust_qty, note, unit_cost
    ) values (
      v_stocktake_id, v_item.id, v_system_qty, v_counted,
      v_damaged, v_adjust,
      v_line->>'note', v_item.avg_cost
    );

    v_stock_rows := v_stock_rows || jsonb_build_object(
      'item_id', v_item.id,
      'quantity', coalesce(v_new_qty,
        (select quantity from public.inventory_stock
         where warehouse_id = v_wh_id and item_id = v_item.id))
    );
  end loop;

  -- استهلك التصريح
  update public.admin_approvals
  set used_at = now()
  where token = p_token;

  perform _bump_data_version('inv_stocktake');
  perform _bump_data_version('inv_stock');

  return jsonb_build_object(
    'ok',      true,
    'dry_run', false,
    'doc',     jsonb_build_object('id', v_stocktake_id, 'number', v_number),
    'preview', v_results,
    'stock',   v_stock_rows,
    'stamps',  jsonb_build_object(
      'inv_stocktake', (select version from public.data_versions where key = 'inv_stocktake'),
      'inv_stock',     (select version from public.data_versions where key = 'inv_stock')
    )
  );
end;
$$;

-- دالة مساعدة وهمية لتجنب خطأ compile (غير مستخدمة فعلياً — المنطق مضمّن)
create or replace function p_results_internal(p jsonb) returns jsonb language sql as $$ select p; $$;
revoke execute on function p_results_internal(jsonb) from public, anon, authenticated;

grant execute on function apply_stocktake(uuid, uuid, boolean, uuid, text, jsonb) to authenticated;
comment on function apply_stocktake(uuid, uuid, boolean, uuid, text, jsonb) is
  'يطبّق الجرد من ملف Excel. dry_run=true للمعاينة بدون تغيير. يتطلب تصريح إدارة للتطبيق الفعلي.';

-- =============================================================================
-- § 6 — طلبات الفروع (Branch Orders)
-- =============================================================================

create table if not exists public.branch_orders (
  id           uuid        primary key default gen_random_uuid(),
  number       text        not null unique,   -- BO-<كود_الفرع>-000001
  client_id    uuid        not null unique,
  branch_id    uuid        not null references public.branches(id),
  status       text        not null default 'submitted'
                             check (status in ('submitted', 'approved', 'rejected', 'cancelled')),
  notes        text,
  rejection_reason text,
  decided_by   uuid        references auth.users(id),
  decided_at   timestamptz,
  created_by   uuid        not null references auth.users(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  version      bigint      not null default 1
);

comment on table  public.branch_orders          is 'طلبات الفروع من المستودع الرئيسي';
comment on column public.branch_orders.number   is 'BO-<كود_الفرع>-<تسلسلي 6 خانات>';
comment on column public.branch_orders.status   is 'submitted → approved/rejected. لا تراجع بعد القرار.';

create index if not exists idx_branch_orders_branch_status_created
  on public.branch_orders (branch_id, status, created_at desc);

alter table public.branch_orders enable row level security;

create or replace trigger trg_branch_orders_updated_at
  before update on public.branch_orders
  for each row execute function public.set_updated_at();
create or replace trigger trg_branch_orders_version
  before update on public.branch_orders
  for each row execute function public.bump_version();

create table if not exists public.branch_order_lines (
  id           uuid           primary key default gen_random_uuid(),
  order_id     uuid           not null references public.branch_orders(id),
  item_id      uuid           not null references public.inventory_items(id),
  qty_requested numeric(14,3) not null check (qty_requested > 0),
  qty_approved  numeric(14,3),  -- يُحدَّث عند القرار
  created_at   timestamptz    not null default now(),
  updated_at   timestamptz    not null default now()
);

create index if not exists idx_branch_order_lines_order
  on public.branch_order_lines (order_id);
create index if not exists idx_branch_order_lines_item
  on public.branch_order_lines (item_id);

alter table public.branch_order_lines enable row level security;

create or replace trigger trg_branch_order_lines_updated_at
  before update on public.branch_order_lines
  for each row execute function public.set_updated_at();

-- RPC: create_branch_order
create or replace function create_branch_order(
  p_client_id uuid,
  p_branch_id uuid,
  p_notes     text  default null,
  p_lines     jsonb default null  -- [{item_id, qty_requested}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id  uuid := auth.uid();
  v_order_id uuid;
  v_number   text;
  v_branch_code text;
  v_line     jsonb;
  v_existing record;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('cashier', 'branch_manager') then
    raise exception 'إنشاء الطلبيات للكاشير ومدير الفرع فقط';
  end if;

  if not _can_act_for_branch(p_branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للطلبية';
  end if;

  -- idempotency
  select id, number into v_existing
  from public.branch_orders
  where client_id = p_client_id;

  if found then
    return jsonb_build_object('ok', true, 'doc',
      jsonb_build_object('id', v_existing.id, 'number', v_existing.number));
  end if;

  select code into v_branch_code from public.branches where id = p_branch_id;

  v_number := _next_doc_number('bo', v_branch_code,
    'BO-' || v_branch_code || '-{n:6}');

  insert into public.branch_orders (client_id, number, branch_id, notes, created_by)
  values (p_client_id, v_number, p_branch_id, p_notes, v_user_id)
  returning id into v_order_id;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.branch_order_lines (order_id, item_id, qty_requested)
    values (v_order_id, (v_line->>'item_id')::uuid, (v_line->>'qty_requested')::numeric);
  end loop;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('branch_orders:' || p_branch_id::text);

  perform _notify(
    'branch_order_submitted',
    array['accounting', 'warehouse'],
    p_branch_id,
    'طلبية فرع جديدة: ' || v_number,
    'فرع: ' || (select name from public.branches where id = p_branch_id),
    jsonb_build_object('ref_type', 'branch_order', 'ref_id', v_order_id, 'domains',
      array['inv_supply', 'branch_orders:' || p_branch_id::text])
  );

  return jsonb_build_object(
    'ok',    true,
    'doc',   jsonb_build_object('id', v_order_id, 'number', v_number),
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply'),
      'branch_orders:' || p_branch_id::text,
        (select version from public.data_versions where key = 'branch_orders:' || p_branch_id::text)
    )
  );
end;
$$;

grant execute on function create_branch_order(uuid, uuid, text, jsonb) to authenticated;

-- RPC: update_branch_order (تعديل الطلب — submitted فقط)
create or replace function update_branch_order(
  p_order_id        uuid,
  p_expected_version bigint,
  p_notes           text  default null,
  p_lines           jsonb default null  -- [{item_id, qty_requested}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id  uuid := auth.uid();
  v_order    record;
  v_line     jsonb;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id, status, version, branch_id into v_order
  from public.branch_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  if not _can_act_for_branch(v_order.branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) != 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'يجب إضافة أصناف للطلبية';
  end if;

  if v_order.status != 'submitted' then
    raise exception 'لا يمكن تعديل الطلب بعد مراجعته';
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  -- استبدل السطور كاملاً
  delete from public.branch_order_lines where order_id = p_order_id;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    insert into public.branch_order_lines (order_id, item_id, qty_requested)
    values (p_order_id, (v_line->>'item_id')::uuid, (v_line->>'qty_requested')::numeric);
  end loop;

  update public.branch_orders
  set notes = coalesce(p_notes, notes)
  where id = p_order_id;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('branch_orders:' || v_order.branch_id::text);

  perform _notify(
    'branch_order_updated',
    array['accounting', 'warehouse'],
    v_order.branch_id,
    'تعديل طلبية فرع',
    'تم تعديل الطلب من قِبل الفرع',
    jsonb_build_object('ref_type', 'branch_order', 'ref_id', p_order_id,
      'domains', array['inv_supply', 'branch_orders:' || v_order.branch_id::text])
  );

  return jsonb_build_object('ok', true,
    'doc', jsonb_build_object('id', p_order_id),
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply')
    )
  );
end;
$$;

grant execute on function update_branch_order(uuid, bigint, text, jsonb) to authenticated;

-- RPC: cancel_branch_order (إلغاء الطلب — submitted فقط)
create or replace function cancel_branch_order(
  p_order_id        uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_order record;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id, status, version, branch_id into v_order
  from public.branch_orders
  where id = p_order_id
  for update;

  if not found then raise exception 'الطلب غير موجود'; end if;

  if not _can_act_for_branch(v_order.branch_id) then
    raise exception 'ليس لديك صلاحية لهذا الفرع';
  end if;

  if v_order.status != 'submitted' then
    raise exception 'لا يمكن إلغاء الطلب بعد مراجعته';
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر، حدّث الصفحة';
  end if;

  update public.branch_orders set status = 'cancelled' where id = p_order_id;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('branch_orders:' || v_order.branch_id::text);

  return jsonb_build_object('ok', true,
    'doc', jsonb_build_object('id', p_order_id, 'status', 'cancelled'));
end;
$$;

grant execute on function cancel_branch_order(uuid, bigint) to authenticated;

-- RPC: decide_branch_order (قرار أمين المخزن: اعتماد أو رفض)
create or replace function decide_branch_order(
  p_order_id        uuid,
  p_expected_version bigint,
  p_decision        text,   -- 'approved' | 'rejected'
  p_rejection_reason text   default null,
  p_lines           jsonb   default null  -- [{line_id, qty_approved}]
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
  v_line_rec   record;
  v_main_wh_id uuid;
  v_br_wh_id   uuid;
  v_qty_appr   numeric;
  v_all_zero   boolean;
  v_new_qty_main numeric;
  v_new_qty_branch numeric;
  v_stock_rows   jsonb := '[]'::jsonb;
  v_summary_lines jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'قرار الطلبيات لأمين المخزن فقط';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'قرار غير صالح: %', p_decision;
  end if;

  select id, status, version, branch_id into v_order
  from public.branch_orders
  where id = p_order_id
  for update;

  if not found then raise exception 'الطلب غير موجود'; end if;

  if v_order.status != 'submitted' then
    raise exception 'لا يمكن اتخاذ قرار — حالة الطلب: % (ربما عدّله الفرع للتو)', v_order.status;
  end if;

  if v_order.version != p_expected_version then
    raise exception 'تم تعديل الطلب من مستخدم آخر (الفرع عدّل الطلب). حدّث الصفحة وراجع مجدداً';
  end if;

  if p_decision = 'rejected' then
    if p_rejection_reason is null or trim(p_rejection_reason) = '' then
      raise exception 'سبب الرفض إجباري';
    end if;

    update public.branch_orders
    set status = 'rejected', rejection_reason = p_rejection_reason,
        decided_by = v_user_id, decided_at = now()
    where id = p_order_id;

  else
    -- اعتماد — تحقق من الكميات
    if p_lines is null or jsonb_array_length(p_lines) = 0 then
      raise exception 'يجب تحديد الكميات المعتمدة لكل سطر';
    end if;

    select bool_and((l->>'qty_approved')::numeric = 0)
    into v_all_zero
    from jsonb_array_elements(p_lines) l;

    if v_all_zero then
      raise exception 'الكميات المعتمدة كلها صفر — استخدم خيار الرفض';
    end if;

    select id into v_main_wh_id from public.warehouses where kind = 'main';
    v_br_wh_id := _get_branch_warehouse(v_order.branch_id);

    -- تحديث كل سطر وإجراء التحويل
    for v_line in select * from jsonb_array_elements(p_lines)
    loop
      v_qty_appr := (v_line->>'qty_approved')::numeric;

      -- تأكد أن qty_approved <= qty_requested
      select l.item_id, l.qty_requested into v_line_rec
      from public.branch_order_lines l
      where l.id = (v_line->>'line_id')::uuid
        and l.order_id = p_order_id;

      if not found then
        raise exception 'سطر غير موجود في الطلب';
      end if;

      if v_qty_appr > v_line_rec.qty_requested then
        raise exception 'الكمية المعتمدة لا يمكن أن تتجاوز الكمية المطلوبة';
      end if;

      update public.branch_order_lines
      set qty_approved = v_qty_appr, updated_at = now()
      where id = (v_line->>'line_id')::uuid;

      -- التحويل لو الكمية > 0
      if v_qty_appr > 0 then
        -- خصم من الرئيسي (سيرفض لو ما يكفي)
        v_new_qty_main := _post_movement(
          v_main_wh_id, v_line_rec.item_id,
          'branch_transfer_out', -v_qty_appr,
          (select avg_cost from public.inventory_items where id = v_line_rec.item_id),
          'branch_order', p_order_id,
          'تحويل لفرع — ' || (select name from public.branches where id = v_order.branch_id),
          v_user_id
        );

        -- إضافة لمستودع الفرع
        v_new_qty_branch := _post_movement(
          v_br_wh_id, v_line_rec.item_id,
          'branch_transfer_in', v_qty_appr,
          (select avg_cost from public.inventory_items where id = v_line_rec.item_id),
          'branch_order', p_order_id,
          'استلام من المستودع الرئيسي',
          v_user_id
        );

        v_stock_rows := v_stock_rows || jsonb_build_object(
          'item_id',         v_line_rec.item_id,
          'main_quantity',   v_new_qty_main,
          'branch_quantity', v_new_qty_branch
        );
      end if;

      v_summary_lines := v_summary_lines || jsonb_build_object(
        'item_id',       v_line_rec.item_id,
        'qty_requested', v_line_rec.qty_requested,
        'qty_approved',  v_qty_appr
      );
    end loop;

    update public.branch_orders
    set status = 'approved', decided_by = v_user_id, decided_at = now()
    where id = p_order_id;

    perform _bump_data_version('inv_stock');
    perform _bump_data_version('branch_stock:' || v_order.branch_id::text);
  end if;

  perform _bump_data_version('inv_supply');
  perform _bump_data_version('branch_orders:' || v_order.branch_id::text);

  -- إشعار للفرع بالقرار (يحمل الكميات في payload)
  perform _notify(
    'branch_order_decided',
    array['branch'],
    v_order.branch_id,
    case p_decision when 'approved' then 'تمت الموافقة على طلبيتك' else 'تم رفض طلبيتك' end,
    case p_decision
      when 'approved' then 'تمت الموافقة — تحقق من الكميات المعتمدة'
      else 'السبب: ' || p_rejection_reason
    end,
    jsonb_build_object(
      'ref_type',  'branch_order',
      'ref_id',    p_order_id,
      'decision',  p_decision,
      'lines',     v_summary_lines,
      'domains',   array['branch_orders:' || v_order.branch_id::text]
    )
  );

  return jsonb_build_object(
    'ok',     true,
    'doc',    jsonb_build_object('id', p_order_id, 'status', p_decision),
    'stock',  v_stock_rows,
    'stamps', jsonb_build_object(
      'inv_supply', (select version from public.data_versions where key = 'inv_supply'),
      'inv_stock',  (select version from public.data_versions where key = 'inv_stock')
    )
  );
end;
$$;

grant execute on function decide_branch_order(uuid, bigint, text, text, jsonb) to authenticated;

-- =============================================================================
-- § 7 — جدول inventory_imports: سجل الاستيرادات
-- =============================================================================

create table if not exists public.inventory_imports (
  id          uuid        primary key default gen_random_uuid(),
  number      text        not null unique,   -- IMPORT-2026-0001
  client_id   uuid        not null unique,
  imported_by uuid        not null references auth.users(id),
  summary     jsonb,      -- {total_rows, new_items, updated_items, errors}
  result      text        not null check (result in ('success', 'failed')),
  created_at  timestamptz not null default now()
);

comment on table public.inventory_imports is 'سجل كل عمليات استيراد الأصناف من Excel';

alter table public.inventory_imports enable row level security;

-- RPC: import_inventory_items
create or replace function import_inventory_items(
  p_client_id uuid,
  p_token     uuid,    -- تصريح الإدارة
  p_dry_run   boolean  default false,
  p_rows      jsonb    default null    -- [{sku?, name, category_name, unit_code, min_level?, opening_qty?, unit_cost?, branch_orderable?, is_active?, note?}]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id     uuid := auth.uid();
  v_row         jsonb;
  v_results     jsonb := '[]'::jsonb;
  v_errors      jsonb := '[]'::jsonb;
  v_has_error   boolean := false;
  v_cat_id      uuid;
  v_item_id     uuid;
  v_sku         text;
  v_name        text;
  v_unit        text;
  v_existing    record;
  v_has_moves   boolean;
  v_new_cnt     int := 0;
  v_upd_cnt     int := 0;
  v_err_cnt     int := 0;
  v_import_id   uuid;
  v_number      text;
  v_year        text;
  v_main_wh_id  uuid;
  v_opening_qty numeric;
  v_unit_cost   numeric;
  v_new_qty     numeric;
  v_stock_rows  jsonb := '[]'::jsonb;
  v_seen_names  text[] := array[]::text[];
  v_seen_skus   text[] := array[]::text[];
begin
  if v_user_id is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not _has_role('storekeeper') then
    raise exception 'الاستيراد لأمين المخزن فقط';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) != 'array' or jsonb_array_length(p_rows) = 0 then
    raise exception 'يجب توفير أصناف للاستيراد';
  end if;

  -- التصريح إجباري للتطبيق
  if not p_dry_run then
    if p_token is null then
      raise exception 'يجب تقديم تصريح الإدارة للاستيراد';
    end if;

    perform 1 from public.admin_approvals
    where token   = p_token
      and user_id = v_user_id
      and action  = 'inventory_import'
      and expires_at > now()
      and used_at is null;

    if not found then
      raise exception 'تصريح الإدارة غير صالح أو منتهي الصلاحية';
    end if;

    -- idempotency
    perform 1 from public.inventory_imports where client_id = p_client_id;
    if found then
      return jsonb_build_object('ok', true, 'dry_run', false, 'idempotent', true);
    end if;
  end if;

  select id into v_main_wh_id from public.warehouses where kind = 'main';

  -- معالجة كل صف
  for v_row in select * from jsonb_array_elements(p_rows)
  loop
    v_name := trim(v_row->>'name');
    v_sku  := upper(trim(coalesce(v_row->>'sku', '')));
    v_unit := trim(v_row->>'unit_code');

    -- تحقق من الاسم
    if v_name is null or length(v_name) < 2 or length(v_name) > 120 then
      v_has_error := true;
      v_err_cnt := v_err_cnt + 1;
      v_errors := v_errors || jsonb_build_object('row', v_row, 'error', 'الاسم مطلوب (2-120 حرف)');
      continue;
    end if;

    -- تحقق من تكرار الاسم داخل الملف
    if lower(v_name) = any(array(select lower(x) from unnest(v_seen_names) x)) then
      v_has_error := true;
      v_err_cnt := v_err_cnt + 1;
      v_errors := v_errors || jsonb_build_object('row', v_row, 'error', 'اسم مكرر داخل الملف: ' || v_name);
      continue;
    end if;

    v_seen_names := v_seen_names || v_name;

    -- تحقق من SKU لو محدد
    if v_sku != '' then
      if v_sku != any(
        array(select x from regexp_split_to_table(
          v_sku, '') x where x !~ '^[A-Z0-9\-_]$')
      ) or length(v_sku) < 3 or length(v_sku) > 30 then
        v_has_error := true;
        v_err_cnt := v_err_cnt + 1;
        v_errors := v_errors || jsonb_build_object('row', v_row, 'error', 'SKU غير صالح: ' || v_sku);
        continue;
      end if;

      if v_sku = any(v_seen_skus) then
        v_has_error := true;
        v_err_cnt := v_err_cnt + 1;
        v_errors := v_errors || jsonb_build_object('row', v_row, 'error', 'SKU مكرر داخل الملف: ' || v_sku);
        continue;
      end if;

      v_seen_skus := v_seen_skus || v_sku;
    end if;

    -- تحقق من التصنيف
    select id into v_cat_id
    from public.inventory_categories
    where lower(trim(name)) = lower(trim(v_row->>'category_name'))
      and code != 'FIN';  -- ممنوع الإضافة لـ FIN

    if v_cat_id is null then
      v_has_error := true;
      v_err_cnt := v_err_cnt + 1;
      v_errors := v_errors || jsonb_build_object('row', v_row,
        'error', 'التصنيف غير موجود: ' || coalesce(v_row->>'category_name', '(فارغ)'));
      continue;
    end if;

    -- تحقق من الوحدة
    perform 1 from public.inventory_units where code = v_unit;
    if not found then
      v_has_error := true;
      v_err_cnt := v_err_cnt + 1;
      v_errors := v_errors || jsonb_build_object('row', v_row,
        'error', 'وحدة القياس غير موجودة: ' || coalesce(v_unit, '(فارغ)'));
      continue;
    end if;

    -- ابحث عن الصنف (بالـ SKU أو الاسم)
    if v_sku != '' then
      select id, unit_code into v_existing
      from public.inventory_items where sku = v_sku;
    else
      select id, unit_code into v_existing
      from public.inventory_items
      where lower(trim(name)) = lower(v_name) and is_active = true;
    end if;

    if v_existing.id is not null then
      -- تحديث صنف موجود
      v_has_moves := exists (
        select 1 from public.inventory_movements where item_id = v_existing.id limit 1
      );

      v_results := v_results || jsonb_build_object(
        'sku', coalesce(v_sku, v_existing.unit_code), 'name', v_name,
        'status', 'update',
        'unit_changed', (v_existing.unit_code != v_unit and not v_has_moves)
      );

      if not p_dry_run then
        update public.inventory_items
        set name             = v_name,
            category_id      = v_cat_id,
            unit_code        = case when v_has_moves then unit_code else v_unit end,
            min_level        = coalesce((v_row->>'min_level')::numeric, min_level),
            branch_orderable = coalesce((v_row->>'branch_orderable')::boolean, branch_orderable),
            is_active        = coalesce((v_row->>'is_active')::boolean, is_active),
            updated_at       = now()
        where id = v_existing.id;

        v_upd_cnt := v_upd_cnt + 1;
      end if;

    else
      -- صنف جديد
      if v_sku = '' then
        -- توليد SKU تلقائي
        v_sku := _next_doc_number('item_sku',
          (select code from public.inventory_categories where id = v_cat_id),
          '{scope}-{n:4}');
      end if;

      v_opening_qty := coalesce((v_row->>'opening_qty')::numeric, 0);
      v_unit_cost   := coalesce((v_row->>'unit_cost')::numeric,   0);

      v_results := v_results || jsonb_build_object(
        'sku', v_sku, 'name', v_name, 'status', 'new',
        'opening_qty', v_opening_qty
      );

      if not p_dry_run then
        insert into public.inventory_items (
          sku, name, category_id, unit_code, min_level,
          avg_cost, branch_orderable, is_active, created_by
        ) values (
          v_sku, v_name, v_cat_id, v_unit,
          coalesce((v_row->>'min_level')::numeric, 0),
          v_unit_cost,
          coalesce((v_row->>'branch_orderable')::boolean, true),
          coalesce((v_row->>'is_active')::boolean, true),
          v_user_id
        )
        returning id into v_item_id;

        -- رصيد افتتاحي لو > 0
        if v_opening_qty > 0 then
          v_new_qty := _post_movement(
            v_main_wh_id, v_item_id, 'opening',
            v_opening_qty, v_unit_cost,
            'inventory_import', null,
            'رصيد افتتاحي من الاستيراد', v_user_id
          );

          v_stock_rows := v_stock_rows || jsonb_build_object(
            'item_id', v_item_id, 'quantity', v_new_qty
          );
        end if;

        v_new_cnt := v_new_cnt + 1;
      end if;
    end if;
  end loop;

  -- لو معاينة
  if p_dry_run then
    return jsonb_build_object(
      'ok',      not v_has_error,
      'dry_run', true,
      'errors',  v_errors,
      'preview', v_results,
      'summary', jsonb_build_object(
        'new', v_new_cnt, 'update', v_upd_cnt, 'error', v_err_cnt
      )
    );
  end if;

  -- لو في أخطاء: rollback
  if v_has_error then
    raise exception 'فشل الاستيراد — يوجد % خطأ. لا تم تطبيق أي تغيير.', v_err_cnt;
  end if;

  -- سجّل الاستيراد
  v_year   := to_char(current_date at time zone
                (select value from public.app_settings where key = 'timezone'), 'YYYY');
  v_number := _next_doc_number('import', v_year, 'IMPORT-{scope}-{n:4}');

  insert into public.inventory_imports (
    number, client_id, imported_by, summary, result
  ) values (
    v_number, p_client_id, v_user_id,
    jsonb_build_object('new', v_new_cnt, 'updated', v_upd_cnt),
    'success'
  )
  returning id into v_import_id;

  -- استهلك التصريح
  update public.admin_approvals set used_at = now() where token = p_token;

  perform _bump_data_version('inv_catalog');
  perform _bump_data_version('inv_stock');

  return jsonb_build_object(
    'ok',      true,
    'dry_run', false,
    'doc',     jsonb_build_object('id', v_import_id, 'number', v_number),
    'stock',   v_stock_rows,
    'summary', jsonb_build_object('new', v_new_cnt, 'updated', v_upd_cnt),
    'stamps',  jsonb_build_object(
      'inv_catalog', (select version from public.data_versions where key = 'inv_catalog'),
      'inv_stock',   (select version from public.data_versions where key = 'inv_stock')
    )
  );
end;
$$;

grant execute on function import_inventory_items(uuid, uuid, boolean, jsonb) to authenticated;
comment on function import_inventory_items(uuid, uuid, boolean, jsonb) is
  'استيراد الأصناف من Excel. dry_run للمعاينة. all-or-nothing. يستهلك التصريح.';

-- =============================================================================
-- § 8 — RPCs جلب المستندات
-- =============================================================================

-- جلب المستندات عند أول فتح القسم في الجلسة
create or replace function inventory_get_documents(
  p_doc_type text,   -- 'supply_orders' | 'kitchen_issues' | 'kitchen_batches' | 'branch_orders' | 'stocktakes'
  p_branch_id uuid   default null,
  p_limit     int    default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result  jsonb;
  v_cutoff  timestamptz := now() - interval '30 days';
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  case p_doc_type
  when 'supply_orders' then
    if not _has_role('storekeeper', 'accountant') then
      raise exception 'ليس لديك صلاحية';
    end if;

    select jsonb_agg(jsonb_build_object(
      'id',              o.id,
      'number',          o.number,
      'supplier_id',     o.supplier_id,
      'supplier_name',   s.name,
      'expected_date',   o.expected_date,
      'priority',        o.priority,
      'status',          o.status,
      'has_issues',      o.has_issues,
      'notes',           o.notes,
      'rejection_reason',o.rejection_reason,
      'created_at',      o.created_at,
      'updated_at',      o.updated_at,
      'version',         o.version,
      'lines', (
        select jsonb_agg(jsonb_build_object(
          'id',           l.id,
          'item_id',      l.item_id,
          'qty_requested',l.qty_requested,
          'qty_approved', l.qty_approved,
          'qty_received', l.qty_received,
          'unit_cost',    l.unit_cost,
          'line_note',    l.line_note
        ))
        from public.supply_order_lines l where l.order_id = o.id
      )
    ))
    into v_result
    from public.supply_orders o
    join public.suppliers s on s.id = o.supplier_id
    where o.status in ('pending_review', 'approved')
       or o.created_at >= v_cutoff
    order by o.created_at desc
    limit least(p_limit, 100);

  when 'branch_orders' then
    if p_branch_id is not null then
      if not _can_act_for_branch(p_branch_id) then
        raise exception 'ليس لديك صلاحية لهذا الفرع';
      end if;
    else
      if not _has_role('storekeeper', 'accountant') then
        raise exception 'ليس لديك صلاحية';
      end if;
    end if;

    select jsonb_agg(jsonb_build_object(
      'id',               o.id,
      'number',           o.number,
      'branch_id',        o.branch_id,
      'branch_name',      b.name,
      'status',           o.status,
      'notes',            o.notes,
      'rejection_reason', o.rejection_reason,
      'created_at',       o.created_at,
      'updated_at',       o.updated_at,
      'version',          o.version,
      'lines', (
        select jsonb_agg(jsonb_build_object(
          'id',            l.id,
          'item_id',       l.item_id,
          'qty_requested', l.qty_requested,
          'qty_approved',  l.qty_approved
        ))
        from public.branch_order_lines l where l.order_id = o.id
      )
    ))
    into v_result
    from public.branch_orders o
    join public.branches b on b.id = o.branch_id
    where (p_branch_id is null or o.branch_id = p_branch_id)
      and (o.status = 'submitted' or o.created_at >= v_cutoff)
    order by
      case when o.status = 'submitted' then 0 else 1 end,
      o.created_at desc
    limit least(p_limit, 100);

  else
    raise exception 'نوع مستند غير معروف: %', p_doc_type;
  end case;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

grant execute on function inventory_get_documents(text, uuid, int) to authenticated;

-- =============================================================================
-- نهاية الملف
-- =============================================================================
