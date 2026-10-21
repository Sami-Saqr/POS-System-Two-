-- =============================================================================
-- 011_branch_orders_main_only.sql
-- تعديل دورة طلبات الفروع لتعمل بالخصم من المستودع الرئيسي فقط
-- الاستغناء عن مستودعات الفروع تماماً وحذف حركاتها
-- قابل للتشغيل أكثر من مرة (idempotent)
-- =============================================================================

-- =============================================================================
-- § 1 — تحديث دالة decide_branch_order
-- =============================================================================

create or replace function public.decide_branch_order(
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
  v_qty_appr   numeric;
  v_all_zero   boolean;
  v_new_qty_main numeric;
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

    -- تحديث كل سطر وإجراء التحويل (الخصم من الرئيسي فقط)
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
        -- خصم من الرئيسي فقط (سيرفض لو ما يكفي)
        v_new_qty_main := _post_movement(
          v_main_wh_id, v_line_rec.item_id,
          'branch_transfer_out', -v_qty_appr,
          (select avg_cost from public.inventory_items where id = v_line_rec.item_id),
          'branch_order', p_order_id,
          'تحويل لفرع — ' || (select name from public.branches where id = v_order.branch_id),
          v_user_id
        );

        v_stock_rows := v_stock_rows || jsonb_build_object(
          'item_id',  v_line_rec.item_id,
          'quantity', v_new_qty_main
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

revoke execute on function public.decide_branch_order(uuid, bigint, text, text, jsonb) from public, anon;
grant  execute on function public.decide_branch_order(uuid, bigint, text, text, jsonb) to   authenticated;

notify pgrst, 'reload schema';

-- =============================================================================
-- نهاية الملف
-- =============================================================================
