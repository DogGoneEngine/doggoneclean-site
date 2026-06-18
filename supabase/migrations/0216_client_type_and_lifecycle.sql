-- 0216_client_type_and_lifecycle.sql
--
-- Untangle client TYPE from LIFECYCLE (Paul 2026-06-18). The legacy `status` and
-- `roster_group` columns conflate three different things: the client TYPE
-- (recurring vs on-demand), the LIFECYCLE (active, moved away, deceased, inactive,
-- merged, test), and the BAN (which already lives cleanly in nofly_level +
-- exclude_from_everything). That conflation is why a client read "one off one off".
--
-- This adds two clean, single-purpose columns and backfills them. It deliberately
-- LEAVES the legacy columns in place: ~30 queries read roster_group ('standing'
-- for the legacy book / retention / win-back, 'banned' for the ban), so removing
-- them now would be a wide, risky change. The new columns are the truth going
-- forward and drive the UI; the legacy columns stay as compatibility until a later
-- pass migrates those readers. Ban stays orthogonal (nofly_level), never folded
-- into lifecycle.

alter table public.clients
  add column if not exists client_type text
    check (client_type is null or client_type in ('recurring','on_demand')),
  add column if not exists lifecycle text
    check (lifecycle is null or lifecycle in ('active','moved_away','deceased','inactive','merged','test'));

-- TYPE: an explicit type label in status/roster_group wins; otherwise a cadence
-- means recurring, no cadence means on-demand. (So a one_off that happens to carry
-- a cadence stays on-demand, honoring the explicit label Paul set.)
update public.clients set client_type = case
    when status = 'standing' or roster_group = 'standing' then 'recurring'
    when status in ('one_off','one_off_for_now','at_will','at_will_winddown')
         or roster_group in ('one_off','at_will') then 'on_demand'
    when cadence_days is not null then 'recurring'
    else 'on_demand'
  end
where client_type is null;

-- LIFECYCLE: the genuine lifecycle states; everything else (including banned, which
-- is the separate nofly dimension) is a current 'active' record.
update public.clients set lifecycle = case
    when status = 'moved_away' then 'moved_away'
    when status = 'deceased'   then 'deceased'
    when status = 'inactive'   then 'inactive'
    when status = 'merged'     then 'merged'
    when status = 'test_account' then 'test'
    else 'active'
  end
where lifecycle is null;

alter table public.clients alter column lifecycle set default 'active';

-- Setters so the type and lifecycle can be corrected from the record (the UI
-- control), keeping the data clean over time.
create or replace function public.admin_set_client_type(p_client_id uuid, p_type text)
returns void language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_type not in ('recurring','on_demand') then raise exception 'bad client_type: %', p_type; end if;
  update public.clients set client_type = p_type, updated_at = now() where id = p_client_id;
  if not found then raise exception 'client not found'; end if;
end;
$function$;
revoke all on function public.admin_set_client_type(uuid, text) from public, anon;
grant execute on function public.admin_set_client_type(uuid, text) to authenticated, service_role;

create or replace function public.admin_set_client_lifecycle(p_client_id uuid, p_state text)
returns void language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_state not in ('active','moved_away','deceased','inactive','merged','test') then
    raise exception 'bad lifecycle: %', p_state;
  end if;
  update public.clients set lifecycle = p_state, updated_at = now() where id = p_client_id;
  if not found then raise exception 'client not found'; end if;
end;
$function$;
revoke all on function public.admin_set_client_lifecycle(uuid, text) from public, anon;
grant execute on function public.admin_set_client_lifecycle(uuid, text) to authenticated, service_role;

-- Expose the clean fields on the list (admin_get_client already returns the whole
-- row, so it picks them up automatically).
create or replace function public.admin_list_clients()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'aka', c.aka, 'roster_group', c.roster_group, 'status', c.status,
      'client_type', c.client_type, 'lifecycle', c.lifecycle,
      'service_type', c.service_type, 'cadence_days', c.cadence_days, 'hardness', c.hardness,
      'location_zone', c.location_zone, 'flags', c.flags, 'data_gaps', c.data_gaps,
      'dog_count', (select count(*) from public.dogs d where d.client_id = c.id),
      'last_visit_at', (select max(v.visited_at) from public.visits v where v.client_id = c.id),
      'aliases', (select coalesce(jsonb_agg(a.alias order by a.alias), '[]'::jsonb) from public.client_aliases a where a.client_id = c.id)
    ) order by c.name)
    from public.clients c where c.exclude_from_everything = false and c.archived_at is null
  ), '[]'::jsonb);
end;
$function$;
