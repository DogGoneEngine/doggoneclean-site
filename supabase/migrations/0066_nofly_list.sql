-- 0066_nofly_list.sql
-- The no-fly (banned) list Paul manages himself, on the Clients floor. A
-- dedicated `nofly` flag + reason, distinct from `exclude_from_everything`
-- (which also covers merged-alias records like a former name or a household
-- duplicate). Both keep a client out of every agent and all outreach; nofly is
-- the human-managed ban with a reason. See no_fly_list in CLEAN_ORACLE.md.

alter table public.clients
  add column if not exists nofly boolean not null default false,
  add column if not exists nofly_reason text;

update public.clients set nofly=true, exclude_from_everything=true,
  nofly_reason = coalesce(nofly_reason, 'Banned client (do not serve or contact).')
  where name = 'Bonnie DiGraziano';

create or replace function public.admin_set_client_nofly(p_client_id uuid, p_banned boolean, p_reason text default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_banned then
    update public.clients set nofly=true, exclude_from_everything=true,
      nofly_reason = coalesce(nullif(trim(p_reason),''), nofly_reason, 'No-fly list.'),
      roster_group='banned', updated_at=now()
     where id = p_client_id;
  else
    update public.clients set nofly=false, exclude_from_everything=false,
      nofly_reason=null, roster_group = case when roster_group='banned' then 'active' else roster_group end, updated_at=now()
     where id = p_client_id;
  end if;
  if not found then raise exception 'client not found'; end if;
end;
$$;
revoke all on function public.admin_set_client_nofly(uuid, boolean, text) from public;
grant execute on function public.admin_set_client_nofly(uuid, boolean, text) to authenticated;

create or replace function public.admin_list_nofly()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'aka', c.aka, 'reason', c.nofly_reason,
             'last_visit', (select max(v.visited_at)::date from public.visits v where v.client_id=c.id)) order by c.name)
    from public.clients c where c.nofly), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_nofly() from public;
grant execute on function public.admin_list_nofly() to authenticated;
