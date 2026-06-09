-- 0063_vendors_reorder.sql
-- Vendors floor: the supplies you buy and who you buy them from, with a reorder
-- watcher (daily) that flags anything marked low or due on its reorder cadence
-- before you run out on a route. Deterministic, no LLM; respects 'intentional'.

create table if not exists public.supplies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'other'
    check (category = any (array['shampoo','towels','blades','tools','cleaning','consumables','office','other'])),
  vendor text,
  reorder_url text,
  interval_days integer check (interval_days is null or interval_days > 0),
  last_ordered date,
  low boolean not null default false,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.supplies enable row level security;

create or replace function public.admin_list_supplies()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_items jsonb; v_due int; v_low int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'name', name, 'category', category, 'vendor', vendor, 'reorder_url', reorder_url,
      'interval_days', interval_days, 'last_ordered', last_ordered, 'low', low, 'notes', notes, 'active', active,
      'due_on', case when last_ordered is not null and interval_days is not null then last_ordered + interval_days end,
      'days_until', case when last_ordered is not null and interval_days is not null then (last_ordered + interval_days) - current_date end
    ) order by low desc, (last_ordered is null or interval_days is null),
      case when last_ordered is not null and interval_days is not null then last_ordered + interval_days end, name), '[]'::jsonb)
    into v_items from public.supplies;
  select count(*) filter (where active and (low or (last_ordered is not null and interval_days is not null and (last_ordered+interval_days) <= current_date+7))),
         count(*) filter (where active and low)
    into v_due, v_low from public.supplies;
  return jsonb_build_object('items', v_items, 'due', v_due, 'low', v_low);
end;
$$;
revoke all on function public.admin_list_supplies() from public;
grant execute on function public.admin_list_supplies() to authenticated;

create or replace function public.admin_upsert_supply(
  p_id uuid, p_name text, p_category text, p_vendor text, p_reorder_url text,
  p_interval_days integer, p_notes text default null, p_active boolean default true
) returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_name),'')='' then raise exception 'name required'; end if;
  if p_id is null then
    insert into public.supplies (name, category, vendor, reorder_url, interval_days, notes, active)
    values (p_name, coalesce(p_category,'other'), p_vendor, p_reorder_url, p_interval_days, p_notes, coalesce(p_active,true))
    returning id into v_id;
  else
    update public.supplies set name=p_name, category=coalesce(p_category,'other'), vendor=p_vendor,
      reorder_url=p_reorder_url, interval_days=p_interval_days, notes=p_notes, active=coalesce(p_active,true), updated_at=now()
     where id=p_id returning id into v_id;
    if v_id is null then raise exception 'supply not found'; end if;
  end if;
  return v_id;
end;
$$;
revoke all on function public.admin_upsert_supply(uuid, text, text, text, text, integer, text, boolean) from public;
grant execute on function public.admin_upsert_supply(uuid, text, text, text, text, integer, text, boolean) to authenticated;

create or replace function public.admin_supply_action(p_id uuid, p_action text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_action = 'ordered' then
    update public.supplies set last_ordered = current_date, low = false, updated_at = now() where id = p_id;
  elsif p_action = 'low' then
    update public.supplies set low = true, updated_at = now() where id = p_id;
  elsif p_action = 'not_low' then
    update public.supplies set low = false, updated_at = now() where id = p_id;
  elsif p_action = 'delete' then
    delete from public.supplies where id = p_id;
  else raise exception 'bad action'; end if;
end;
$$;
revoke all on function public.admin_supply_action(uuid, text) from public;
grant execute on function public.admin_supply_action(uuid, text) to authenticated;

create or replace function public._reorder_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; r record; v_due date;
begin
  for r in select * from public.supplies
           where active and (low or (last_ordered is not null and interval_days is not null and (last_ordered+interval_days) <= current_date+7)) loop
    if not exists (select 1 from public.briefings where agent_key='reorder'
        and (evidence->>'supply_id')::uuid = r.id and status in ('new','read') and created_at > now() - interval '14 days')
       and not exists (select 1 from public.briefings where agent_key='reorder'
        and (evidence->>'supply_id')::uuid = r.id and disposition='intentional') then
      v_due := case when r.last_ordered is not null and r.interval_days is not null then r.last_ordered + r.interval_days end;
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('reorder','vendors', case when r.low then 'alert' else 'signal' end,
        'Reorder: '||r.name,
        case when r.low then format('You marked %s low. Time to reorder%s.', r.name, case when r.vendor is not null then ' from '||r.vendor else '' end)
             else format('%s is due to reorder (every %s days, last ordered %s)%s.', r.name, r.interval_days, to_char(r.last_ordered,'Mon DD'), case when r.vendor is not null then ' from '||r.vendor else '' end) end,
        jsonb_build_object('supply_id', r.id, 'due_on', v_due, 'low', r.low));
      v_created := v_created + 1;
    end if;
  end loop;
  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='reorder'; end if;
  return v_created;
end;
$$;

create or replace function public.admin_reorder_check()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v := public._reorder_scan();
  return jsonb_build_object('alerts_created', v);
end;
$$;
revoke all on function public.admin_reorder_check() from public;
grant execute on function public.admin_reorder_check() to authenticated;

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('reorder','Reorder watcher','vendors','Flags supplies you marked low or that are due to reorder before you run out.','15 12 * * *', false)
on conflict (agent_key) do nothing;

select cron.schedule('reorder-daily', '15 12 * * *', 'select public._reorder_scan();')
  where not exists (select 1 from cron.job where jobname='reorder-daily');

insert into public.supplies (name, category, notes) values
  ('Bath shampoo',          'shampoo',     'The main wash shampoo.'),
  ('Conditioner / finishing', 'shampoo',   null),
  ('Towels',                'towels',      'Wear out and get lost; reorder in bulk.'),
  ('#7 blades',             'blades',      'Sharpen or replace as they dull.'),
  ('Clipper / rotary oil',  'tools',       null),
  ('Rotary drums / bands',  'tools',       'Knockoff rotary consumables.'),
  ('Sanitizer / disinfectant', 'cleaning', 'Between-dog cleaning.'),
  ('Finishing cologne',     'consumables', null)
on conflict do nothing;
