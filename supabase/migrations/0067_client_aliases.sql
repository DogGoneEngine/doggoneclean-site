-- 0067_client_aliases.sql
-- Household aliases: any number of names (spouse, former name, spelling variant,
-- household member) attached to one client record, all searchable, so any name
-- brings up the same household. See households_search_by_any_name in the Oracle.

create table if not exists public.client_aliases (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  alias text not null,
  created_at timestamptz not null default now()
);
create unique index if not exists client_aliases_uidx on public.client_aliases (client_id, lower(alias));
alter table public.client_aliases enable row level security;

create or replace function public.admin_add_alias(p_client_id uuid, p_alias text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_alias),'')='' then raise exception 'empty alias'; end if;
  insert into public.client_aliases (client_id, alias) values (p_client_id, trim(p_alias)) on conflict do nothing;
end;
$$;
revoke all on function public.admin_add_alias(uuid, text) from public;
grant execute on function public.admin_add_alias(uuid, text) to authenticated;

create or replace function public.admin_remove_alias(p_alias_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.client_aliases where id = p_alias_id;
end;
$$;
revoke all on function public.admin_remove_alias(uuid) from public;
grant execute on function public.admin_remove_alias(uuid) to authenticated;

create or replace function public.admin_list_aliases(p_client_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'alias', alias) order by alias)
                   from public.client_aliases where client_id = p_client_id), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_aliases(uuid) from public;
grant execute on function public.admin_list_aliases(uuid) to authenticated;

create or replace function public.admin_list_clients()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'aka', c.aka, 'roster_group', c.roster_group, 'status', c.status,
      'service_type', c.service_type, 'cadence_days', c.cadence_days, 'hardness', c.hardness,
      'location_zone', c.location_zone, 'flags', c.flags, 'data_gaps', c.data_gaps,
      'dog_count', (select count(*) from public.dogs d where d.client_id = c.id),
      'last_visit_at', (select max(v.visited_at) from public.visits v where v.client_id = c.id),
      'aliases', (select coalesce(jsonb_agg(a.alias order by a.alias), '[]'::jsonb) from public.client_aliases a where a.client_id = c.id)
    ) order by c.name)
    from public.clients c where c.exclude_from_everything = false
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_clients() from public;
grant execute on function public.admin_list_clients() to authenticated;
