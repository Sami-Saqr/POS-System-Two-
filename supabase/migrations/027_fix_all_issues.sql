-- =============================================================================
-- 027_fix_all_issues.sql
-- اشغّله مرة واحدة في Supabase SQL Editor
-- يُصلح:
--   1) جدول notifications (أعمدة جديدة + RLS)
--   2) تعارض hr_decide_leave_request (PGRST203)
--   3) permission denied لـ hr_submit_attendance
--   4) 4 triggers للإشعارات التلقائية
-- =============================================================================

-- ─── § 1  تحديث جدول notifications ─────────────────────────────────────────

alter table public.notifications add column if not exists recipient_role      text;
alter table public.notifications add column if not exists recipient_user_id   uuid references auth.users(id);
alter table public.notifications add column if not exists recipient_branch_id uuid references public.branches(id);
alter table public.notifications add column if not exists type                text;
alter table public.notifications add column if not exists ref_table           text;
alter table public.notifications add column if not exists ref_id              text;
alter table public.notifications add column if not exists is_read             boolean not null default false;
alter table public.notifications add column if not exists read_at             timestamptz;

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='notifications'
               and column_name='kind' and is_nullable='NO') then
    alter table public.notifications alter column kind drop not null;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='notifications'
               and column_name='audience' and is_nullable='NO') then
    alter table public.notifications alter column audience drop not null;
  end if;
end $$;

create index if not exists idx_notif_recip_role   on public.notifications (recipient_role, is_read);
create index if not exists idx_notif_recip_user   on public.notifications (recipient_user_id);
create index if not exists idx_notif_recip_branch on public.notifications (recipient_branch_id);

-- ─── § 2  RLS policies ──────────────────────────────────────────────────────

alter table public.notifications enable row level security;

drop policy if exists "notifications_read"        on public.notifications;
drop policy if exists notifications_select_policy on public.notifications;
drop policy if exists notifications_update_policy on public.notifications;

create policy notifications_select_policy on public.notifications
  for select to authenticated
  using (
    recipient_user_id = auth.uid()
    or (
      recipient_user_id is null and recipient_role is not null
      and exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.is_active = true
          and (
            p.role = 'owner'
            or (
              p.role = notifications.recipient_role
              and (
                notifications.recipient_branch_id is null
                or notifications.recipient_branch_id = p.branch_id
                or p.role in ('owner','accountant','storekeeper','hr')
              )
            )
          )
      )
    )
    or (
      recipient_role is null and recipient_user_id is null and audience is not null
      and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active = true)
    )
  );

create policy notifications_update_policy on public.notifications
  for update to authenticated
  using (
    recipient_user_id = auth.uid()
    or (
      recipient_user_id is null
      and exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.is_active = true
          and (p.role = 'owner' or p.role = notifications.recipient_role)
      )
    )
  )
  with check (is_read = true);

grant select, update on public.notifications to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- ─── § 3  دوال mark_notification_read ────────────────────────────────────────

create or replace function public.mark_notification_read(p_id uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  update public.notifications set is_read = true, read_at = now() where id = p_id;
end; $$;
grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.mark_all_notifications_read(
  p_role text default null,
  p_branch_id uuid default null
) returns void language plpgsql security definer set search_path = public, extensions as $$
declare v_uid uuid := auth.uid();
begin
  update public.notifications
  set is_read = true, read_at = now()
  where is_read = false
    and (
      recipient_user_id = v_uid
      or (
        recipient_user_id is null
        and (p_role is null or recipient_role = p_role)
        and (p_branch_id is null or recipient_branch_id is null or recipient_branch_id = p_branch_id)
      )
    );
end; $$;
grant execute on function public.mark_all_notifications_read(text, uuid) to authenticated;

-- ─── § 4  Trigger branch_orders ──────────────────────────────────────────────

create or replace function public.trg_fn_notify_branch_orders()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare v_branch_name text;
begin
  select name into v_branch_name from public.branches where id = NEW.branch_id;

  if (TG_OP = 'INSERT' and NEW.status in ('submitted','pending'))
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'submitted') then
    insert into public.notifications (recipient_role,type,title,body,ref_table,ref_id)
    values ('storekeeper','branch_order_submitted','طلب منتجات جديد',
            'طلب جديد من فرع '||coalesce(v_branch_name,'الفرع')||' (رقم: '||coalesce(NEW.number,'')||')',
            'branch_orders', NEW.id::text);
  end if;

  if TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status in ('approved','in_preparation') then
    insert into public.notifications (recipient_role,recipient_branch_id,type,title,body,ref_table,ref_id)
    values ('cashier',NEW.branch_id,'branch_order_approved','الموافقة على طلب المنتجات',
            'تمت الموافقة على طلبك رقم '||coalesce(NEW.number,'')||' وجاري التحضير',
            'branch_orders', NEW.id::text);
  end if;

  if TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'received' then
    insert into public.notifications (recipient_role,type,title,body,ref_table,ref_id)
    values ('storekeeper','branch_order_received','تأكيد استلام الطلب',
            'فرع '||coalesce(v_branch_name,'الفرع')||' استلم الطلب رقم '||coalesce(NEW.number,''),
            'branch_orders', NEW.id::text);
  end if;

  return NEW;
end; $$;

drop trigger if exists trg_notify_branch_orders on public.branch_orders;
create trigger trg_notify_branch_orders
  after insert or update of status on public.branch_orders
  for each row execute function public.trg_fn_notify_branch_orders();

-- ─── § 5  Trigger supply_orders ──────────────────────────────────────────────

create or replace function public.trg_fn_notify_supply_orders()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin
  if (TG_OP = 'INSERT' and NEW.status = 'pending_review')
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'pending_review') then
    insert into public.notifications (recipient_role,type,title,body,ref_table,ref_id)
    values ('accountant','supply_order_submitted','طلب شراء جديد',
            'طلب توريد جديد برقم '||coalesce(NEW.number,'')||' بانتظار المراجعة والاعتماد',
            'supply_orders', NEW.id::text);
  end if;

  if TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'approved' then
    insert into public.notifications (recipient_role,recipient_user_id,type,title,body,ref_table,ref_id)
    values ('storekeeper',NEW.created_by,'supply_order_approved','الموافقة على طلب الشراء',
            'تمت الموافقة على طلب التوريد رقم '||coalesce(NEW.number,'')||' وجاهز للاستلام',
            'supply_orders', NEW.id::text);
  end if;

  if TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'rejected' then
    insert into public.notifications (recipient_role,recipient_user_id,type,title,body,ref_table,ref_id)
    values ('storekeeper',NEW.created_by,'supply_order_rejected','رفض طلب الشراء',
            'تم رفض طلب التوريد رقم '||coalesce(NEW.number,'')||coalesce(' — السبب: '||NEW.notes,''),
            'supply_orders', NEW.id::text);
  end if;

  return NEW;
end; $$;

drop trigger if exists trg_notify_supply_orders on public.supply_orders;
create trigger trg_notify_supply_orders
  after insert or update of status on public.supply_orders
  for each row execute function public.trg_fn_notify_supply_orders();

-- ─── § 6  Trigger leave_requests ─────────────────────────────────────────────

create or replace function public.trg_fn_notify_leave_requests()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare
  v_emp_name    text;
  v_branch_id   uuid;
  v_target_role text;
begin
  select full_name, branch_id into v_emp_name, v_branch_id
  from public.employees where id = NEW.employee_id;

  if (TG_OP = 'INSERT' and NEW.status = 'pending')
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'pending') then
    insert into public.notifications (recipient_role,type,title,body,ref_table,ref_id)
    values ('hr','leave_request_submitted','طلب إجازة جديد',
            'طلب إجازة للموظف '||coalesce(v_emp_name,'موظف')||
            ' من '||NEW.start_date||' إلى '||NEW.end_date,
            'leave_requests', NEW.id::text);
  end if;

  if TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status in ('approved','rejected') then
    v_target_role := case
      when NEW.requested_from = 'cashier'   then 'cashier'
      when NEW.requested_from = 'inventory' then 'storekeeper'
      else 'hr'
    end;
    insert into public.notifications (
      recipient_role, recipient_user_id, recipient_branch_id,
      type, title, body, ref_table, ref_id
    ) values (
      v_target_role,
      NEW.created_by,
      case when v_target_role = 'cashier' then v_branch_id else null end,
      case when NEW.status = 'approved' then 'leave_request_approved' else 'leave_request_rejected' end,
      case when NEW.status = 'approved' then 'الموافقة على طلب الإجازة' else 'رفض طلب الإجازة' end,
      case
        when NEW.status = 'approved' then
          'تمت الموافقة على إجازة الموظف '||coalesce(v_emp_name,'')||
          case when coalesce(NEW.decision_type,'') = 'without_deduction'
                 or coalesce(NEW.is_paid, true)
               then ' (مدفوعة)' else ' (بخصم)' end
        else
          'تم رفض إجازة الموظف '||coalesce(v_emp_name,'')||
          coalesce(' — السبب: '||NEW.decision_notes,'')
      end,
      'leave_requests', NEW.id::text
    );
  end if;

  return NEW;
end; $$;

drop trigger if exists trg_notify_leave_requests on public.leave_requests;
create trigger trg_notify_leave_requests
  after insert or update of status on public.leave_requests
  for each row execute function public.trg_fn_notify_leave_requests();

-- ─── § 7  Trigger deduction_bonus_requests ───────────────────────────────────

create or replace function public.trg_fn_notify_deduction_bonus()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare
  v_emp_name    text;
  v_branch_id   uuid;
  v_job_role    text;
  v_kind_label  text;
  v_target_role text;
begin
  select full_name, branch_id, job_role
  into v_emp_name, v_branch_id, v_job_role
  from public.employees where id = NEW.employee_id;

  v_kind_label := case when NEW.type = 'deduction' then 'خصم' else 'مكافأة' end;

  if (TG_OP = 'INSERT' and NEW.status = 'pending' and NEW.requested_from != 'hr')
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'pending' and NEW.requested_from != 'hr') then
    insert into public.notifications (recipient_role,type,title,body,ref_table,ref_id)
    values ('hr','deduction_bonus_submitted','طلب '||v_kind_label||' جديد',
            'طلب '||v_kind_label||' للموظف '||coalesce(v_emp_name,'')||' مقدم من '||NEW.requested_from,
            'deduction_bonus_requests', NEW.id::text);
  end if;

  if TG_OP = 'UPDATE' and OLD.status != NEW.status
     and NEW.status in ('approved','rejected') and NEW.requested_from != 'hr' then
    insert into public.notifications (recipient_role,recipient_user_id,type,title,body,ref_table,ref_id)
    values (
      NEW.requested_from, NEW.created_by,
      case when NEW.status='approved' then 'deduction_bonus_approved' else 'deduction_bonus_rejected' end,
      'قرار طلب ال'||v_kind_label,
      'تم '||case when NEW.status='approved' then 'اعتماد' else 'رفض' end||
      ' طلب ال'||v_kind_label||' للموظف '||coalesce(v_emp_name,''),
      'deduction_bonus_requests', NEW.id::text
    );
  end if;

  if (TG_OP = 'INSERT' and NEW.status = 'approved' and NEW.requested_from = 'hr')
     or (TG_OP = 'UPDATE' and OLD.status != NEW.status and NEW.status = 'approved' and NEW.requested_from = 'hr') then
    v_target_role := case when v_job_role in ('cashier','worker','branch_manager') then 'cashier' else 'storekeeper' end;
    insert into public.notifications (
      recipient_role, recipient_branch_id, type, title, body, ref_table, ref_id
    ) values (
      v_target_role,
      case when v_target_role = 'cashier' then v_branch_id else null end,
      'deduction_bonus_recorded',
      'تسجيل '||v_kind_label||' للموظف',
      'تم تسجيل '||v_kind_label||' للموظف '||coalesce(v_emp_name,'')||' — '||coalesce(NEW.notes,''),
      'deduction_bonus_requests', NEW.id::text
    );
  end if;

  return NEW;
end; $$;

drop trigger if exists trg_notify_deduction_bonus on public.deduction_bonus_requests;
create trigger trg_notify_deduction_bonus
  after insert or update of status on public.deduction_bonus_requests
  for each row execute function public.trg_fn_notify_deduction_bonus();

-- ─── § 8  إصلاح hr_decide_leave_request (حذف النسخة 4-params) ───────────────

drop function if exists public.hr_decide_leave_request(uuid, text, text, text);

alter table public.leave_requests add column if not exists is_paid       boolean not null default true;
alter table public.leave_requests add column if not exists leave_type    text default 'paid';
alter table public.leave_requests add column if not exists decision_notes text;

create or replace function public.hr_decide_leave_request(
  p_id            uuid,
  p_status        text,
  p_decision_type text    default null,
  p_notes         text    default null,
  p_is_paid       boolean default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_leave    leave_requests%rowtype;
  v_is_paid  boolean;
  v_dec_type text;
begin
  if not (public._has_role('hr') or public._has_role('owner')) then
    raise exception using errcode='42501', message='غير مصرح لك باتخاذ قرار الإجازات';
  end if;
  if p_status not in ('approved','rejected') then
    raise exception 'قرار غير صحيح';
  end if;

  select * into v_leave from public.leave_requests where id = p_id;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_leave.status <> 'pending' then raise exception 'الطلب تمت معالجته مسبقاً'; end if;

  if p_is_paid is not null then
    v_is_paid  := p_is_paid;
    v_dec_type := case when p_is_paid then 'without_deduction' else 'with_deduction' end;
  elsif p_decision_type is not null then
    v_dec_type := p_decision_type;
    v_is_paid  := (p_decision_type = 'without_deduction');
  else
    v_is_paid  := true;
    v_dec_type := 'without_deduction';
  end if;

  update public.leave_requests
  set status        = p_status,
      decision_type = v_dec_type,
      is_paid       = v_is_paid,
      leave_type    = case when v_is_paid then 'paid' else 'unpaid' end,
      decided_by    = auth.uid(),
      decided_at    = now(),
      decision_notes = p_notes,
      updated_at    = now()
  where id = p_id;

  if p_status = 'approved' then
    insert into public.attendance_records (employee_id, record_date, status, recorded_by, recorded_from, notes)
    select v_leave.employee_id, d::date, 'on_leave', auth.uid(), 'hr',
           case when v_is_paid then 'إجازة مدفوعة' else 'إجازة بخصم' end
    from generate_series(v_leave.start_date, v_leave.end_date, interval '1 day') as d
    on conflict (employee_id, record_date) do update
      set status        = excluded.status,
          recorded_by   = excluded.recorded_by,
          recorded_from = excluded.recorded_from,
          notes         = excluded.notes,
          updated_at    = now();
  end if;

  return jsonb_build_object('id', p_id, 'status', p_status, 'is_paid', v_is_paid);
end; $$;

revoke all on function public.hr_decide_leave_request(uuid,text,text,text,boolean) from public, anon;
grant execute on function public.hr_decide_leave_request(uuid,text,text,text,boolean) to authenticated;

-- ─── § 9  إصلاح الصلاحيات الناقصة ───────────────────────────────────────────

grant execute on function public.hr_submit_attendance(uuid,date,text,text,text)    to authenticated;
grant execute on function public.hr_get_branch_employees(uuid,text,date)           to authenticated;
grant execute on function public.hr_get_drivers(date)                              to authenticated;
grant execute on function public.hr_get_today_attendance(uuid[],date)              to authenticated;
grant execute on function public.hr_get_monthly_attendance(uuid,int,int)           to authenticated;
grant execute on function public.hr_get_all_employees_attendance(date)             to authenticated;
grant execute on function public.hr_list_leave_requests(text,uuid,int,int)         to authenticated;
grant execute on function public.hr_create_leave_request(jsonb)                    to authenticated;
grant execute on function public.receive_supply_order(uuid,uuid,bigint,text,jsonb) to authenticated;

grant select on public.notifications to authenticated;
grant select on public.branches      to authenticated;
grant select on public.profiles      to authenticated;

-- ─── § 10  إصلاح قيد التاريخ في hr_submit_attendance ────────────────────────
-- الهدف:
--   • الكاشير/المخزون: يسجل فقط لليوم الحالي (بتوقيت التطبيق من app_settings)
--   • HR/المالك:     يسجل لأي تاريخ ضمن فترة الاحتفاظ

create or replace function public.hr_submit_attendance(
  p_employee_id uuid,
  p_record_date date,
  p_status      text,   -- 'present' | 'absent' | 'on_leave'
  p_context     text,   -- 'cashier' | 'inventory' | 'hr'
  p_notes       text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id        uuid;
  v_emp       public.employees%rowtype;
  v_emp_start date;
  v_tz        text;
  v_today     date;
begin
  -- جلب المنطقة الزمنية للتطبيق من الإعدادات
  select coalesce(value, 'Africa/Cairo')
  into v_tz
  from public.app_settings
  where key = 'timezone';

  if v_tz is null then v_tz := 'Africa/Cairo'; end if;

  -- حساب تاريخ اليوم بتوقيت التطبيق
  v_today := (current_timestamp at time zone v_tz)::date;

  if p_status not in ('present','absent','on_leave') then
    raise exception 'حالة الحضور غير صحيحة';
  end if;

  select * into v_emp from public.employees where id = p_employee_id;
  if not found then
    raise exception 'الموظف غير موجود';
  end if;

  if v_emp.status <> 'active' then
    raise exception 'لا يمكن تسجيل حضور أو غياب لموظف غير نشط';
  end if;

  v_emp_start := coalesce(v_emp.hire_date, v_emp.created_at::date);
  if p_record_date < v_emp_start then
    raise exception 'لا يمكن تسجيل حضور لتاريخ يسبق تاريخ تعيين الموظف (%)', v_emp_start;
  end if;

  -- إذا الموظف في إجازة معتمدة في هذا التاريخ
  if exists (
    select 1 from public.leave_requests
    where employee_id = p_employee_id
      and status = 'approved'
      and p_record_date between start_date and end_date
  ) then
    raise exception 'الموظف في إجازة معتمدة في هذا التاريخ';
  end if;

  -- ─ قيد التاريخ:
  --   الكاشير والمخزون → اليوم الحالي فقط (بتوقيت التطبيق)
  --   HR والمالك       → أي تاريخ ضمن فترة الاحتفاظ
  if p_context <> 'hr' and not (public._has_role('hr') or public._has_role('owner')) then
    if p_record_date <> v_today then
      raise exception 'يمكن تسجيل الحضور لليوم الحالي فقط (%)  ', v_today;
    end if;
  end if;

  -- منع التعديل لغير HR إذا سُجّل مسبقاً
  if exists (
    select 1 from public.attendance_records
    where employee_id = p_employee_id and record_date = p_record_date
  )
  and p_context <> 'hr'
  and not (public._has_role('hr') or public._has_role('owner')) then
    raise exception 'تم تسجيل الحضور مسبقاً لهذا الموظف اليوم';
  end if;

  insert into public.attendance_records (
    employee_id, record_date, status, recorded_by, recorded_from, notes
  ) values (
    p_employee_id, p_record_date, p_status, auth.uid(), p_context, p_notes
  )
  on conflict (employee_id, record_date) do update
    set status        = excluded.status,
        recorded_by   = excluded.recorded_by,
        recorded_from = excluded.recorded_from,
        notes         = excluded.notes,
        updated_at    = now()
  returning id into v_id;

  return jsonb_build_object(
    'id',          v_id,
    'status',      p_status,
    'record_date', p_record_date,
    'today',       v_today,
    'timezone',    v_tz
  );
end; $$;

revoke all on function public.hr_submit_attendance(uuid,date,text,text,text) from public, anon;
grant execute on function public.hr_submit_attendance(uuid,date,text,text,text) to authenticated;

-- =============================================================================
-- انتهى 027_fix_all_issues.sql — شغّله في Supabase SQL Editor
-- =============================================================================

