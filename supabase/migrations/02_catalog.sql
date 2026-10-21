-- =============================================================================
-- 02_catalog.sql
-- الكتالوج: الوحدات، التصنيفات، الأصناف، الموردين + بيانات أولية (seed)
-- قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================

-- =============================================================================
-- § 1 — جدول inventory_units: وحدات القياس
-- =============================================================================

create table if not exists public.inventory_units (
  code       text primary key, -- كجم / جرام / لتر / ...
  label      text not null,
  sort_order int  not null default 0
);

comment on table  public.inventory_units            is 'وحدات القياس المتاحة للأصناف';
comment on column public.inventory_units.code       is 'كود الوحدة — يُستخدم كـ FK من inventory_items';
comment on column public.inventory_units.label      is 'الاسم العربي للعرض';
comment on column public.inventory_units.sort_order is 'ترتيب العرض في القوائم';

alter table public.inventory_units enable row level security;

-- seed الوحدات (idempotent)
insert into public.inventory_units (code, label, sort_order) values
  ('كجم',     'كيلوجرام',  1),
  ('جرام',    'جرام',       2),
  ('لتر',     'لتر',        3),
  ('مل',      'ملليلتر',   4),
  ('عبوة',   'عبوة',       5),
  ('كرتونة',  'كرتونة',    6),
  ('قطعة',   'قطعة',       7),
  ('علبة',   'علبة',       8),
  ('كيس',    'كيس',        9),
  ('زجاجة',  'زجاجة',     10),
  ('دستة',   'دستة',      11),
  ('رول',    'رول',       12)
on conflict (code) do nothing;

-- =============================================================================
-- § 2 — جدول inventory_categories: تصنيفات المخزون
-- =============================================================================

create table if not exists public.inventory_categories (
  id         uuid        primary key default gen_random_uuid(),
  code       text        not null unique,  -- PRT / VEG / FIN / ... (2-4 حروف لاتينية)
  name       text        not null unique,  -- بروتين / خضار / ...
  kind       text        not null check (kind in ('raw', 'supply', 'finished')),
  is_system  boolean     not null default false,  -- التصنيفات النظامية لا تُعدَّل ولا تُعطَّل
  is_active  boolean     not null default true,
  sort_order int         not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table  public.inventory_categories           is 'تصنيفات المخزون — خامة raw / مستلزمات supply / منتج تام finished';
comment on column public.inventory_categories.code      is 'كود مختصر 2-4 حروف لاتينية كبيرة — يستخدم في توليد SKU';
comment on column public.inventory_categories.is_system is 'التصنيفات النظامية لا تُعدَّل ولا تُعطَّل ولا يُنشأ فيها صنف إلا تلقائياً (FIN)';

alter table public.inventory_categories enable row level security;

-- trigger لتحديث updated_at
create or replace trigger trg_inventory_categories_updated_at
  before update on public.inventory_categories
  for each row execute function public.set_updated_at();

-- seed التصنيفات الأولية (idempotent)
insert into public.inventory_categories (code, name, kind, is_system, sort_order) values
  ('PRT', 'بروتينات ولحوم',         'raw',      false,  1),
  ('VEG', 'خضار وطازج',             'raw',      false,  2),
  ('BEV', 'مشروبات',                'raw',      false,  3),
  ('OIL', 'زيوت',                   'raw',      false,  4),
  ('SPY', 'بهارات وتوابل',          'raw',      false,  5),
  ('CRB', 'نشويات وحبوب',           'raw',      false,  6),
  ('DAI', 'ألبان وبيض',             'raw',      false,  7),
  ('CLN', 'مستلزمات نظافة',         'supply',   false,  8),
  ('BRN', 'مستلزمات الفروع',        'supply',   false,  9),
  ('PKG', 'تغليف وعبوات',           'supply',   false, 10),
  ('FIN', 'منتج تام',              'finished', true,  99)
on conflict (code) do nothing;

-- =============================================================================
-- § 3 — جدول inventory_items: الأصناف
-- =============================================================================

create table if not exists public.inventory_items (
  id                 uuid           primary key default gen_random_uuid(),
  sku                text           not null unique,
  name               text           not null,  -- فريد case-insensitive بين النشطة
  category_id        uuid           not null references public.inventory_categories(id),
  unit_code          text           not null references public.inventory_units(code),
  min_level          numeric(14,3)  not null default 0 check (min_level >= 0),
  avg_cost           numeric(14,4)  not null default 0 check (avg_cost >= 0),
  branch_orderable   boolean        not null default true,
  is_active          boolean        not null default true,
  low_stock_alerted  boolean        not null default false,
  linked_product_id  uuid           references public.products(id), -- ربط مستقبلي بالوصفات
  created_by         uuid           references auth.users(id),
  created_at         timestamptz    not null default now(),
  updated_at         timestamptz    not null default now(),
  version            bigint         not null default 1
);

comment on table  public.inventory_items                    is 'أصناف المخزون — خامات ومستلزمات ومنتجات تامة';
comment on column public.inventory_items.sku                is 'كود الصنف — فريد، حروف لاتينية وأرقام و- و_، 3-30 حرف';
comment on column public.inventory_items.name               is 'اسم الصنف — فريد case-insensitive بين الأصناف غير المعطلة';
comment on column public.inventory_items.min_level          is 'الحد الأدنى للرصيد في المستودع الرئيسي — عند العبور يُرسل إشعار';
comment on column public.inventory_items.avg_cost           is 'متوسط التكلفة المرجّح — يُحدَّث تلقائياً عند كل استلام';
comment on column public.inventory_items.branch_orderable   is 'هل يظهر الصنف في قائمة طلبيات الفروع؟';
comment on column public.inventory_items.low_stock_alerted  is 'true لو أُرسل إشعار نقص المخزون ولم يتعافَ الرصيد بعد';
comment on column public.inventory_items.linked_product_id  is 'ربط اختياري بجدول products للوصفات مستقبلاً';
comment on column public.inventory_items.version            is 'رقم النسخة للتحكم في التزامن — يزيد عند كل تحديث';

-- فهرس على category_id
create index if not exists idx_inv_items_category
  on public.inventory_items (category_id);

-- فهرس على (is_active, branch_orderable) لاستعلامات الكتالوج
create index if not exists idx_inv_items_active_orderable
  on public.inventory_items (is_active, branch_orderable);

-- فهرس على (unit_code) للفحص عند تغيير الوحدة
create index if not exists idx_inv_items_unit
  on public.inventory_items (unit_code);

-- فريد اسم الصنف case-insensitive بين النشطة فقط (partial unique index)
create unique index if not exists idx_inv_items_name_active
  on public.inventory_items (lower(trim(name)))
  where is_active = true;

alter table public.inventory_items enable row level security;

-- triggers
create or replace trigger trg_inventory_items_updated_at
  before update on public.inventory_items
  for each row execute function public.set_updated_at();

create or replace trigger trg_inventory_items_version
  before update on public.inventory_items
  for each row execute function public.bump_version();

-- =============================================================================
-- § 4 — جدول suppliers: الموردين
-- =============================================================================

create table if not exists public.suppliers (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null unique, -- فريد case-insensitive
  phone      text,
  is_active  boolean     not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table  public.suppliers           is 'الموردون — يُضافون تلقائياً عند إنشاء أول طلب توريد لهم';
comment on column public.suppliers.name      is 'اسم المورد — فريد case-insensitive';

-- فهرس على اسم المورد case-insensitive
create unique index if not exists idx_suppliers_name_lower
  on public.suppliers (lower(trim(name)));

alter table public.suppliers enable row level security;

create or replace trigger trg_suppliers_updated_at
  before update on public.suppliers
  for each row execute function public.set_updated_at();

-- =============================================================================
-- § 5 — RPC: inventory_get_catalog
--       يجلب دلتا الكتالوج (تصنيفات + وحدات + أصناف) منذ تاريخ محدد
--       مُحدَّد بأعمدة صريحة — ممنوع select *
-- =============================================================================

create or replace function inventory_get_catalog(
  p_since timestamptz default null  -- null = جلب كامل (جلسة أولى)
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_categories jsonb;
  v_units      jsonb;
  v_items      jsonb;
  v_since      timestamptz;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  -- هامش أمان 10 ثواني لتجنب فوات تحديثات متزامنة
  v_since := case
    when p_since is null then null
    else p_since - interval '10 seconds'
  end;

  -- التصنيفات
  select jsonb_agg(jsonb_build_object(
    'id',         c.id,
    'code',       c.code,
    'name',       c.name,
    'kind',       c.kind,
    'is_system',  c.is_system,
    'is_active',  c.is_active,
    'sort_order', c.sort_order,
    'updated_at', c.updated_at
  ))
  into v_categories
  from public.inventory_categories c
  where (v_since is null or c.updated_at >= v_since);

  -- الوحدات (نادراً تتغير — تُجلب دائماً لأنها صغيرة)
  select jsonb_agg(jsonb_build_object(
    'code',       u.code,
    'label',      u.label,
    'sort_order', u.sort_order
  ))
  into v_units
  from public.inventory_units u;

  -- الأصناف
  select jsonb_agg(jsonb_build_object(
    'id',               i.id,
    'sku',              i.sku,
    'name',             i.name,
    'category_id',      i.category_id,
    'unit_code',        i.unit_code,
    'min_level',        i.min_level,
    'avg_cost',         i.avg_cost,
    'branch_orderable', i.branch_orderable,
    'is_active',        i.is_active,
    'updated_at',       i.updated_at,
    'version',          i.version
  ))
  into v_items
  from public.inventory_items i
  where (v_since is null or i.updated_at >= v_since);

  return jsonb_build_object(
    'categories', coalesce(v_categories, '[]'::jsonb),
    'units',      coalesce(v_units,      '[]'::jsonb),
    'items',      coalesce(v_items,      '[]'::jsonb),
    'fetched_at', now()
  );
end;
$$;

comment on function inventory_get_catalog(timestamptz) is
  'يجلب دلتا الكتالوج منذ p_since (أو كاملاً لو null). يُستدعى مرة واحدة عند أول دخول للوحدة في الجلسة.';

grant execute on function inventory_get_catalog(timestamptz) to authenticated;

-- =============================================================================
-- نهاية الملف
-- =============================================================================
