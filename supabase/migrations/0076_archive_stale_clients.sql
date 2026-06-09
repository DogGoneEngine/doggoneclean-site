-- 0076_archive_stale_clients.sql
-- Paul has 3 years of history in the book; he only wants clients seen within the
-- past year showing in his view. Archive (not delete) anyone whose last visit is
-- older than a year with no future appointment. Archived clients stay in the
-- database with full history; they are just hidden from the default Clients list
-- and from the win-back agent. If anyone comes back, they un-archive themselves:
-- a trigger clears archived_at the moment a new appointment or visit lands for
-- them, no matter how it was created (calendar sync, manual log, booking funnel).
-- There is also a manual un-archive and an archived-list for the Clients floor,
-- and a monthly cron so the view stays current without Paul. Real records are
-- never destroyed; archive is reversible. See client_archive_after_a_year.

alter table public.clients add column if not exists archived_at timestamptz;
create index if not exists clients_archived_at_idx on public.clients (archived_at);

-- Auto un-archive: any new appointment or visit for an archived client restores
-- them. A trigger is the durable home (survives any future write path).
create or replace function public._unarchive_on_appt() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.clients c set archived_at = null, updated_at = now()
    from public.bath_subscribers s
   where s.id = NEW.subscriber_id and c.id = s.client_id and c.archived_at is not null;
  return NEW;
end $$;
drop trigger if exists trg_unarchive_on_appt on public.bath_appointments;
create trigger trg_unarchive_on_appt after insert on public.bath_appointments
  for each row execute function public._unarchive_on_appt();

create or replace function public._unarchive_on_visit() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.clients c set archived_at = null, updated_at = now()
   where c.archived_at is not null and (
     c.id = NEW.client_id
     or c.id = (select s.client_id from public.bath_subscribers s where s.id = NEW.subscriber_id));
  return NEW;
end $$;
drop trigger if exists trg_unarchive_on_visit on public.visits;
create trigger trg_unarchive_on_visit after insert on public.visits
  for each row execute function public._unarchive_on_visit();

-- The archive sweep: archive non-excluded, not-already-archived clients whose
-- newest visit is older than p_days and who have no upcoming appointment. Never
-- archives a never-visited client (could be freshly added). Returns the count.
create or replace function public._archive_stale_clients(p_days int default 365)
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_n int;
begin
  with stale as (
    select c.id
      from public.clients c
      join public.visits v on v.client_id = c.id
     where not c.exclude_from_everything
       and c.archived_at is null
       and not exists (
         select 1 from public.bath_appointments a
         join public.bath_subscribers s on s.id = a.subscriber_id
         where s.client_id = c.id and a.scheduled_start >= now()
           and a.status in ('requested','confirmed','tentative'))
     group by c.id
    having max(v.visited_at)::date < current_date - p_days
  )
  update public.clients c set archived_at = now(), updated_at = now()
   from stale where c.id = stale.id;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

create or replace function public.admin_archive_stale_clients(p_days int default 365)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v := public._archive_stale_clients(p_days);
  return jsonb_build_object('archived', v);
end $$;
revoke all on function public.admin_archive_stale_clients(int) from public;
grant execute on function public.admin_archive_stale_clients(int) to authenticated;

create or replace function public.admin_unarchive_client(p_client_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.clients set archived_at = null, updated_at = now() where id = p_client_id;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.admin_unarchive_client(uuid) from public;
grant execute on function public.admin_unarchive_client(uuid) to authenticated;

create or replace function public.admin_list_archived_clients()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'aka', c.aka, 'service_type', c.service_type,
      'location_zone', c.location_zone, 'archived_at', c.archived_at,
      'last_visit_at', (select max(v.visited_at) from public.visits v where v.client_id = c.id)
    ) order by c.name)
    from public.clients c
   where c.exclude_from_everything = false and c.archived_at is not null
  ), '[]'::jsonb);
end $$;
revoke all on function public.admin_list_archived_clients() from public;
grant execute on function public.admin_list_archived_clients() to authenticated;

-- The default book hides archived clients (zero-arg signature kept so the front
-- end call is unchanged).
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
    from public.clients c where c.exclude_from_everything = false and c.archived_at is null
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_clients() from public;
grant execute on function public.admin_list_clients() to authenticated;

-- Win-back never surfaces an archived (dormant past a year) client.
create or replace function public._winback_due_view()
returns table(id uuid, name text, email text, roster_group text, cadence_days int, last_visit date, days_since int)
language sql security definer set search_path = public, pg_temp
as $$
  select c.id, c.name, c.email, c.roster_group, c.cadence_days,
         max(v.visited_at)::date, (current_date - max(v.visited_at)::date)
    from public.clients c join public.visits v on v.client_id = c.id
   where not c.exclude_from_everything
     and c.archived_at is null
     and not exists (
       select 1 from public.bath_appointments a
       join public.bath_subscribers s on s.id = a.subscriber_id
       where s.client_id = c.id and a.scheduled_start >= now() and a.status in ('requested','confirmed','tentative'))
   group by c.id, c.name, c.email, c.roster_group, c.cadence_days
  having (current_date - max(v.visited_at)::date) >= (case when c.cadence_days is not null then c.cadence_days + 14 else 90 end)
     and (current_date - max(v.visited_at)::date) <= coalesce((select value::int from public.app_secrets where name='winback_max_days'), 540);
$$;

-- Keep the view current without Paul: re-archive monthly anyone who has drifted
-- past a year (auto un-archive already handles anyone who comes back).
select cron.schedule('archive-stale-monthly', '0 9 1 * *', 'select public._archive_stale_clients();')
  where not exists (select 1 from cron.job where jobname='archive-stale-monthly');
