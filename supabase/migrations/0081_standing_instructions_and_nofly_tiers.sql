-- 0081_standing_instructions_and_nofly_tiers.sql
-- Three things from Paul:
--   1. Per-dog standing instructions (the semi-permanent "how to handle this dog"
--      from the Drive contact sheets) get a home of their own on dogs, separate
--      from the freeform visit-condition notes.
--   2. Two tiers of no-fly, not one:
--        banned  = a hard ban (do not serve, do not contact, hidden everywhere);
--        shadow  = a shadow ban (still a real client, still served if they come,
--                  but never solicited: excluded from win-back and outreach).
--      nofly_level carries the tier; the existing nofly boolean stays true only
--      for a hard ban (back-compat with the no_fly_list teeth).
--   3. The set-status control moves out of the prominent header in the UI; the
--      data layer just exposes a single status setter.
-- See dog_standing_instructions + nofly_two_tiers.

alter table public.dogs add column if not exists standing_instructions text;

alter table public.clients add column if not exists nofly_level text
  check (nofly_level is null or nofly_level in ('shadow','banned'));
-- Existing hard bans become the 'banned' tier.
update public.clients set nofly_level = 'banned' where nofly = true and nofly_level is null;

-- One status setter for both tiers. p_level: 'banned' | 'shadow' | null (clear).
create or replace function public.admin_set_client_status(p_client_id uuid, p_level text, p_reason text default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_level is not null and p_level not in ('shadow','banned') then raise exception 'bad status level'; end if;
  if p_level = 'banned' then
    update public.clients set nofly = true, nofly_level = 'banned', exclude_from_everything = true,
      nofly_reason = coalesce(nullif(trim(p_reason),''), nofly_reason, 'Banned.'),
      roster_group = 'banned', updated_at = now()
     where id = p_client_id;
  elsif p_level = 'shadow' then
    -- Still a client (stays in the book, still serveable), just never solicited.
    update public.clients set nofly = false, nofly_level = 'shadow', exclude_from_everything = false,
      nofly_reason = coalesce(nullif(trim(p_reason),''), nofly_reason, 'Shadow ban: do not solicit.'),
      roster_group = case when roster_group = 'banned' then 'active' else roster_group end, updated_at = now()
     where id = p_client_id;
  else
    update public.clients set nofly = false, nofly_level = null, exclude_from_everything = false,
      nofly_reason = null,
      roster_group = case when roster_group = 'banned' then 'active' else roster_group end, updated_at = now()
     where id = p_client_id;
  end if;
  if not found then raise exception 'client not found'; end if;
end;
$$;
revoke all on function public.admin_set_client_status(uuid, text, text) from public;
grant execute on function public.admin_set_client_status(uuid, text, text) to authenticated;

-- Set a dog's standing instructions.
create or replace function public.admin_set_dog_standing(p_dog_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.dogs set standing_instructions = nullif(btrim(p_text), ''), updated_at = now() where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_standing(uuid, text) from public;
grant execute on function public.admin_set_dog_standing(uuid, text) to authenticated;

-- The no-fly panel lists both tiers, with the tier on each row.
create or replace function public.admin_list_nofly()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'aka', c.aka,
             'level', coalesce(c.nofly_level, case when c.nofly then 'banned' end),
             'reason', c.nofly_reason,
             'last_visit', (select max(v.visited_at)::date from public.visits v where v.client_id=c.id)) order by c.name)
    from public.clients c where c.nofly_level is not null or c.nofly), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_nofly() from public;
grant execute on function public.admin_list_nofly() to authenticated;

-- Win-back never solicits a shadow-banned client (a hard ban is already excluded
-- via exclude_from_everything; the explicit clause makes the intent plain).
create or replace function public._winback_due_view()
returns table(id uuid, name text, email text, roster_group text, cadence_days int, last_visit date, days_since int)
language sql security definer set search_path = public, pg_temp
as $$
  select c.id, c.name, c.email, c.roster_group, c.cadence_days,
         max(v.visited_at)::date, (current_date - max(v.visited_at)::date)
    from public.clients c join public.visits v on v.client_id = c.id
   where not c.exclude_from_everything
     and c.archived_at is null
     and coalesce(c.suppress_winback, false) = false
     and c.nofly_level is distinct from 'shadow'
     and not exists (
       select 1 from public.bath_appointments a
       join public.bath_subscribers s on s.id = a.subscriber_id
       where s.client_id = c.id and a.scheduled_start >= now() and a.status in ('requested','confirmed','tentative'))
   group by c.id, c.name, c.email, c.roster_group, c.cadence_days
  having (current_date - max(v.visited_at)::date) >= (case when c.cadence_days is not null then c.cadence_days + 14 else 90 end)
     and (current_date - max(v.visited_at)::date) <= coalesce((select value::int from public.app_secrets where name='winback_max_days'), 540);
$$;
