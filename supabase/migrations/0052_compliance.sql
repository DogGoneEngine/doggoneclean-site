-- 0052_compliance.sql
-- Compliance department: insurance, licenses, registrations, A2P, processor
-- verifications, tax dates. A daily watchdog (compliance_dispatch via cron, or
-- admin_compliance_check on demand) flags anything due within 45 days or overdue
-- into the briefings feed. Pure date-watching: deterministic, no LLM.

create table if not exists public.compliance_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'other'
    check (category = any (array['insurance','license','registration','tax','a2p','processor_verification','permit','other'])),
  status text not null default 'pending'
    check (status = any (array['active','pending','expired','na'])),
  renewal_date date,
  provider text,
  reference text,
  amount_cents integer check (amount_cents is null or amount_cents >= 0),
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.compliance_items enable row level security;

create or replace function public.admin_list_compliance()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_items jsonb; v_due int; v_overdue int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'name', name, 'category', category, 'status', status,
      'renewal_date', renewal_date, 'days_until', (renewal_date - current_date),
      'provider', provider, 'reference', reference, 'amount_cents', amount_cents,
      'notes', notes, 'active', active
    ) order by (renewal_date is null), renewal_date, name), '[]'::jsonb)
    into v_items from public.compliance_items;
  select count(*) filter (where active and renewal_date is not null and renewal_date between current_date and current_date + 45),
         count(*) filter (where active and renewal_date is not null and renewal_date < current_date)
    into v_due, v_overdue from public.compliance_items;
  return jsonb_build_object('items', v_items, 'due_soon', v_due, 'overdue', v_overdue);
end;
$$;
revoke all on function public.admin_list_compliance() from public;
grant execute on function public.admin_list_compliance() to authenticated;

create or replace function public.admin_upsert_compliance_item(
  p_id uuid, p_name text, p_category text, p_status text, p_renewal_date date,
  p_provider text default null, p_reference text default null, p_amount_cents integer default null,
  p_notes text default null, p_active boolean default true
) returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_name),'')='' then raise exception 'name required'; end if;
  if p_id is null then
    insert into public.compliance_items (name, category, status, renewal_date, provider, reference, amount_cents, notes, active)
    values (p_name, coalesce(p_category,'other'), coalesce(p_status,'pending'), p_renewal_date, p_provider, p_reference, p_amount_cents, p_notes, coalesce(p_active,true))
    returning id into v_id;
  else
    update public.compliance_items set name=p_name, category=coalesce(p_category,'other'), status=coalesce(p_status,'pending'),
      renewal_date=p_renewal_date, provider=p_provider, reference=p_reference, amount_cents=p_amount_cents, notes=p_notes,
      active=coalesce(p_active,true), updated_at=now() where id=p_id returning id into v_id;
    if v_id is null then raise exception 'item not found'; end if;
  end if;
  return v_id;
end;
$$;
revoke all on function public.admin_upsert_compliance_item(uuid, text, text, text, date, text, text, integer, text, boolean) from public;
grant execute on function public.admin_upsert_compliance_item(uuid, text, text, text, date, text, text, integer, text, boolean) to authenticated;

create or replace function public.admin_delete_compliance_item(p_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.compliance_items where id = p_id;
  if not found then raise exception 'item not found'; end if;
end;
$$;
revoke all on function public.admin_delete_compliance_item(uuid) from public;
grant execute on function public.admin_delete_compliance_item(uuid) to authenticated;

create or replace function public._compliance_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; r record;
begin
  for r in select * from public.compliance_items
           where active and renewal_date is not null and renewal_date <= current_date + 45 loop
    if not exists (
      select 1 from public.briefings
       where agent_key='compliance' and (evidence->>'item_id')::uuid = r.id
         and status in ('new','read') and created_at > now() - interval '20 days') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('compliance','compliance',
        case when r.renewal_date <= current_date + 14 then 'alert' else 'signal' end,
        case when r.renewal_date < current_date then 'Overdue: '||r.name else 'Renewal due: '||r.name end,
        format('%s (%s) %s %s.', r.name, r.category,
          case when r.renewal_date < current_date then 'was due' else 'renews' end,
          to_char(r.renewal_date,'Mon DD, YYYY')),
        jsonb_build_object('item_id', r.id, 'renewal_date', r.renewal_date, 'days', r.renewal_date - current_date));
      v_created := v_created + 1;
    end if;
  end loop;
  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='compliance'; end if;
  return v_created;
end;
$$;

create or replace function public.compliance_dispatch()
returns void language plpgsql security definer set search_path = public, pg_temp
as $$ begin perform public._compliance_scan(); end; $$;
revoke all on function public.compliance_dispatch() from public, authenticated, anon;

create or replace function public.admin_compliance_check()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v := public._compliance_scan();
  return jsonb_build_object('alerts_created', v);
end;
$$;
revoke all on function public.admin_compliance_check() from public;
grant execute on function public.admin_compliance_check() to authenticated;

select cron.schedule('compliance-daily', '0 11 * * *', 'select public.compliance_dispatch();')
where not exists (select 1 from cron.job where jobname = 'compliance-daily');

insert into public.compliance_items (name, category, notes) values
  ('General liability insurance',     'insurance',              'Add the policy renewal date and carrier.'),
  ('Commercial auto / trailer insurance', 'insurance',          'The trailer and tow vehicle.'),
  ('Business license / registration', 'license',                'Local/state business license renewal.'),
  ('A2P 10DLC registration',          'a2p',                    'Required for SMS reminders. Add status and any renewal.'),
  ('Stripe account verification',     'processor_verification', 'Live-mode business verification status.'),
  ('Square account verification',     'processor_verification', 'In-person payments verification status.'),
  ('Sales / use tax registration',    'tax',                    'State tax registration and filing cadence.')
on conflict do nothing;
