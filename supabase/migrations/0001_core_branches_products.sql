BEGIN;

-- Types
DO $$ BEGIN
    CREATE TYPE app_role AS ENUM ('owner', 'branch_manager');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Branches Table
CREATE TABLE IF NOT EXISTS branches (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL CHECK (length(btrim(name)) > 0),
    code text,
    city text,
    address text,
    phone text CHECK (phone IS NULL OR phone = '' OR phone ~ '^[0-9+\- ]{5,20}$'),
    is_warehouse boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by uuid,
    deleted_at timestamptz,
    deleted_by uuid
);

-- Profiles Table
CREATE TABLE IF NOT EXISTS profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    role app_role DEFAULT 'branch_manager',
    branch_id uuid REFERENCES branches(id) ON DELETE RESTRICT,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

-- Categories Table
CREATE TABLE IF NOT EXISTS categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL CHECK (length(btrim(name)) > 0),
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by uuid,
    deleted_at timestamptz,
    deleted_by uuid
);

-- Products Table
CREATE TABLE IF NOT EXISTS products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id uuid NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name text NOT NULL CHECK (length(btrim(name)) > 0),
    sku text,
    description text,
    options text,
    tag text,
    has_variants boolean NOT NULL DEFAULT false,
    price numeric(12,2) CHECK (price IS NULL OR price >= 0),
    cost numeric(12,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    is_active boolean NOT NULL DEFAULT true,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by uuid,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT products_price_check CHECK (
        (has_variants = false AND price IS NOT NULL) OR
        (has_variants = true AND price IS NULL)
    )
);

-- Product Variants Table
CREATE TABLE IF NOT EXISTS product_variants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id uuid NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    label text NOT NULL CHECK (length(btrim(label)) > 0),
    price numeric(12,2) NOT NULL CHECK (price >= 0),
    cost numeric(12,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by uuid,
    deleted_at timestamptz,
    deleted_by uuid
);

-- Audit Log Table (append-only)
CREATE TABLE IF NOT EXISTS audit_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name text NOT NULL,
    record_id uuid NOT NULL,
    action text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'SOFT_DELETE', 'RESTORE')),
    old_data jsonb,
    new_data jsonb,
    changed_by uuid,
    changed_at timestamptz DEFAULT now()
);

-- Partial Unique Indexes
CREATE UNIQUE INDEX IF NOT EXISTS unq_branches_warehouse ON branches (is_warehouse) WHERE is_warehouse = true AND deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS unq_branches_name ON branches (lower(btrim(name))) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS unq_categories_name ON categories (lower(btrim(name))) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS unq_products_name_per_category ON products (category_id, lower(btrim(name))) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS unq_product_variants_label_per_product ON product_variants (product_id, lower(btrim(label))) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS unq_products_sku ON products (sku) WHERE sku IS NOT NULL AND deleted_at IS NULL;

-- Foreign Key Indexes
CREATE INDEX IF NOT EXISTS idx_profiles_branch_id ON profiles(branch_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON product_variants(product_id);

-- Partial Indexes for active rows
CREATE INDEX IF NOT EXISTS idx_branches_active ON branches(id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_products_active ON products(id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_product_variants_active ON product_variants(id) WHERE deleted_at IS NULL;

-- Trigger Functions

-- Increment version and updated_at
CREATE OR REPLACE FUNCTION handle_updated_at_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_created_by()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_by = (select auth.uid());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
DECLARE
    v_action text;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_action := 'INSERT';
        INSERT INTO audit_log (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, v_action, to_jsonb(NEW), (select auth.uid()));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
            v_action := 'SOFT_DELETE';
        ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
            v_action := 'RESTORE';
        ELSE
            v_action := 'UPDATE';
        END IF;
        INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, v_action, to_jsonb(OLD), to_jsonb(NEW), (select auth.uid()));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Last owner check
CREATE OR REPLACE FUNCTION prevent_last_owner_removal()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.role = 'owner' AND (NEW.role != 'owner' OR NEW.is_active = false) THEN
        IF (SELECT count(*) FROM profiles WHERE role = 'owner' AND is_active = true AND id != OLD.id) = 0 THEN
            RAISE EXCEPTION 'CANNOT_REMOVE_LAST_OWNER';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Apply generic triggers (updated_at/version, created_by, audit)
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY['branches', 'categories', 'products', 'product_variants']) LOOP
        -- created_by
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_created_by ON %I;', t, t);
        EXECUTE format('CREATE TRIGGER trg_%I_created_by BEFORE INSERT ON %I FOR EACH ROW EXECUTE FUNCTION set_created_by();', t, t);
        -- updated_at / version
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_updated_at ON %I;', t, t);
        EXECUTE format('CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION handle_updated_at_version();', t, t);
        -- audit log
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_audit ON %I;', t, t);
        EXECUTE format('CREATE TRIGGER trg_%I_audit AFTER INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();', t, t);
    END LOOP;
END;
$$;

-- Apply last owner check
DROP TRIGGER IF EXISTS trg_prevent_last_owner_removal ON profiles;
CREATE TRIGGER trg_prevent_last_owner_removal BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION prevent_last_owner_removal();

-- Helper function: is_owner
CREATE OR REPLACE FUNCTION is_owner() RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles WHERE id = (select auth.uid()) AND role = 'owner' AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Helper function: my_branch_id
CREATE OR REPLACE FUNCTION my_branch_id() RETURNS uuid AS $$
DECLARE
    b_id uuid;
BEGIN
    SELECT branch_id INTO b_id FROM profiles WHERE id = (select auth.uid()) AND is_active = true;
    RETURN b_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Handle new user signup (create profile)
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, role, is_active)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', 'branch_manager', false)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Ensure auth.users trigger exists (don't drop it if we already have it, but idempotent create)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- RPC: save_product
CREATE OR REPLACE FUNCTION save_product(p jsonb)
RETURNS jsonb AS $$
DECLARE
    v_product_id uuid;
    v_has_variants boolean;
    v_price numeric;
    v_expected_version int;
    v_variant jsonb;
    v_variant_id uuid;
    v_existing_variant_ids uuid[];
    v_incoming_variant_ids uuid[] := ARRAY[]::uuid[];
    v_saved_product record;
    v_saved_variants jsonb;
BEGIN
    IF NOT is_owner() THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    v_product_id := (p->>'id')::uuid;
    v_expected_version := (p->>'version')::int;
    v_has_variants := COALESCE((p->>'has_variants')::boolean, false);
    
    IF v_has_variants THEN
        v_price := NULL;
    ELSE
        v_price := (p->>'price')::numeric;
    END IF;

    IF v_product_id IS NULL THEN
        INSERT INTO products (category_id, name, sku, description, options, tag, has_variants, price, cost, is_active)
        VALUES (
            (p->>'category_id')::uuid,
            p->>'name',
            p->>'sku',
            p->>'description',
            p->>'options',
            p->>'tag',
            v_has_variants,
            v_price,
            COALESCE((p->>'cost')::numeric, 0),
            COALESCE((p->>'is_active')::boolean, true)
        ) RETURNING id INTO v_product_id;
    ELSE
        UPDATE products SET
            category_id = (p->>'category_id')::uuid,
            name = p->>'name',
            sku = p->>'sku',
            description = p->>'description',
            options = p->>'options',
            tag = p->>'tag',
            has_variants = v_has_variants,
            price = v_price,
            cost = COALESCE((p->>'cost')::numeric, 0),
            is_active = COALESCE((p->>'is_active')::boolean, true)
        WHERE id = v_product_id AND version = v_expected_version AND deleted_at IS NULL;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'VERSION_CONFLICT';
        END IF;
    END IF;

    -- Handle variants
    IF v_has_variants THEN
        SELECT array_agg(id) INTO v_existing_variant_ids FROM product_variants WHERE product_id = v_product_id AND deleted_at IS NULL;
        IF v_existing_variant_ids IS NULL THEN v_existing_variant_ids := ARRAY[]::uuid[]; END IF;

        FOR v_variant IN SELECT * FROM jsonb_array_elements(p->'variants') LOOP
            v_variant_id := (v_variant->>'id')::uuid;
            IF v_variant_id IS NULL THEN
                INSERT INTO product_variants (product_id, label, price, cost, sort_order, is_active)
                VALUES (
                    v_product_id,
                    v_variant->>'label',
                    (v_variant->>'price')::numeric,
                    COALESCE((v_variant->>'cost')::numeric, 0),
                    COALESCE((v_variant->>'sort_order')::integer, 0),
                    COALESCE((v_variant->>'is_active')::boolean, true)
                ) RETURNING id INTO v_variant_id;
            ELSE
                UPDATE product_variants SET
                    label = v_variant->>'label',
                    price = (v_variant->>'price')::numeric,
                    cost = COALESCE((v_variant->>'cost')::numeric, 0),
                    sort_order = COALESCE((v_variant->>'sort_order')::integer, 0),
                    is_active = COALESCE((v_variant->>'is_active')::boolean, true)
                WHERE id = v_variant_id AND product_id = v_product_id AND deleted_at IS NULL;
            END IF;
            v_incoming_variant_ids := array_append(v_incoming_variant_ids, v_variant_id);
        END LOOP;

        -- Soft delete missing variants
        UPDATE product_variants SET 
            deleted_at = now(),
            deleted_by = (select auth.uid())
        WHERE product_id = v_product_id 
          AND id = ANY(v_existing_variant_ids) 
          AND NOT (id = ANY(v_incoming_variant_ids))
          AND deleted_at IS NULL;
    END IF;

    -- Build return object
    SELECT * INTO v_saved_product FROM products WHERE id = v_product_id;
    SELECT COALESCE(jsonb_agg(row_to_json(pv)), '[]'::jsonb) INTO v_saved_variants FROM product_variants pv WHERE product_id = v_product_id AND deleted_at IS NULL;
    
    RETURN (row_to_json(v_saved_product)::jsonb || jsonb_build_object('variants', v_saved_variants));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: soft_delete_variant
CREATE OR REPLACE FUNCTION soft_delete_variant(p_id uuid, p_version int)
RETURNS void AS $$
DECLARE
    v_product_id uuid;
    v_active_variants int;
BEGIN
    IF NOT is_owner() THEN RAISE EXCEPTION 'UNAUTHORIZED'; END IF;

    UPDATE product_variants SET 
        deleted_at = now(),
        deleted_by = (select auth.uid())
    WHERE id = p_id AND version = p_version AND deleted_at IS NULL
    RETURNING product_id INTO v_product_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;

    -- Check if last active variant for a product with has_variants = true
    SELECT count(*) INTO v_active_variants FROM product_variants WHERE product_id = v_product_id AND deleted_at IS NULL;
    IF v_active_variants = 0 THEN
        UPDATE products SET 
            deleted_at = now(),
            deleted_by = (select auth.uid())
        WHERE id = v_product_id AND deleted_at IS NULL;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: soft_delete_product
CREATE OR REPLACE FUNCTION soft_delete_product(p_id uuid, p_version int)
RETURNS void AS $$
BEGIN
    IF NOT is_owner() THEN RAISE EXCEPTION 'UNAUTHORIZED'; END IF;

    UPDATE products SET 
        deleted_at = now(),
        deleted_by = (select auth.uid())
    WHERE id = p_id AND version = p_version AND deleted_at IS NULL;

    IF NOT FOUND THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;

    UPDATE product_variants SET 
        deleted_at = now(),
        deleted_by = (select auth.uid())
    WHERE product_id = p_id AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: soft_delete_branch
CREATE OR REPLACE FUNCTION soft_delete_branch(p_id uuid, p_version int)
RETURNS void AS $$
BEGIN
    IF NOT is_owner() THEN RAISE EXCEPTION 'UNAUTHORIZED'; END IF;

    IF EXISTS (SELECT 1 FROM profiles WHERE branch_id = p_id AND is_active = true) THEN
        RAISE EXCEPTION 'BRANCH_HAS_ACTIVE_USERS';
    END IF;

    UPDATE branches SET 
        deleted_at = now(),
        deleted_by = (select auth.uid())
    WHERE id = p_id AND version = p_version AND deleted_at IS NULL;

    IF NOT FOUND THEN RAISE EXCEPTION 'VERSION_CONFLICT'; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: restore_record
CREATE OR REPLACE FUNCTION restore_record(p_table text, p_id uuid)
RETURNS void AS $$
BEGIN
    IF NOT is_owner() THEN RAISE EXCEPTION 'UNAUTHORIZED'; END IF;
    
    IF p_table NOT IN ('branches', 'categories', 'products', 'product_variants') THEN
        RAISE EXCEPTION 'INVALID_TABLE';
    END IF;

    EXECUTE format('UPDATE %I SET deleted_at = NULL, deleted_by = NULL WHERE id = $1', p_table) USING p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ENABLE RLS & POLICIES
DO $$ 
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY['branches', 'categories', 'products', 'product_variants', 'profiles', 'audit_log']) LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
        -- Drop policies to be idempotent
        EXECUTE format('DROP POLICY IF EXISTS "policy_%I_all" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "policy_%I_owner_all" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "policy_%I_manager_select" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "policy_%I_manager_read" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "policy_%I_select" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "policy_%I_insert" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "policy_%I_update" ON %I;', t, t);
        
        EXECUTE format('DROP POLICY IF EXISTS "owner_all_%I" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "manager_select_%I" ON %I;', t, t);
        EXECUTE format('DROP POLICY IF EXISTS "active_users_select_%I" ON %I;', t, t);
    END LOOP;
END $$;

-- branches
CREATE POLICY "owner_all_branches" ON branches AS PERMISSIVE FOR ALL TO authenticated USING (is_owner());
CREATE POLICY "manager_select_branch" ON branches AS PERMISSIVE FOR SELECT TO authenticated USING (NOT is_owner() AND deleted_at IS NULL AND id = my_branch_id());

-- categories, products, product_variants
CREATE POLICY "active_users_select_categories" ON categories FOR SELECT TO authenticated USING (deleted_at IS NULL OR is_owner());
CREATE POLICY "owner_all_categories" ON categories AS PERMISSIVE FOR ALL TO authenticated USING (is_owner());

CREATE POLICY "active_users_select_products" ON products FOR SELECT TO authenticated USING (deleted_at IS NULL OR is_owner());
CREATE POLICY "owner_all_products" ON products AS PERMISSIVE FOR ALL TO authenticated USING (is_owner());

CREATE POLICY "active_users_select_product_variants" ON product_variants FOR SELECT TO authenticated USING (deleted_at IS NULL OR is_owner());
CREATE POLICY "owner_all_product_variants" ON product_variants AS PERMISSIVE FOR ALL TO authenticated USING (is_owner());

-- profiles
CREATE POLICY "user_select_self" ON profiles FOR SELECT TO authenticated USING (id = (select auth.uid()) OR is_owner());
CREATE POLICY "owner_all_profiles" ON profiles AS PERMISSIVE FOR ALL TO authenticated USING (is_owner());

-- audit_log
CREATE POLICY "owner_select_audit_log" ON audit_log FOR SELECT TO authenticated USING (is_owner());

-- REVOKES (Prevent DELETE entirely for business tables)
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY['branches', 'categories', 'products', 'product_variants']) LOOP
        EXECUTE format('REVOKE DELETE ON %I FROM public, authenticated, anon;', t);
    END LOOP;
    
    EXECUTE 'REVOKE UPDATE, DELETE, TRUNCATE ON audit_log FROM public, authenticated, anon;';
END $$;

-- SEED DATA (Categories)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM categories WHERE name = 'الوجبات' AND deleted_at IS NULL) THEN
        INSERT INTO categories (name, sort_order) VALUES ('الوجبات', 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categories WHERE name = 'الإضافات' AND deleted_at IS NULL) THEN
        INSERT INTO categories (name, sort_order) VALUES ('الإضافات', 2);
    END IF;
END $$;

COMMIT;
