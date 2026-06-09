-- 0088_dog_followups_lifecycle.sql
-- A "ask next time" follow-up is an OPEN LOOP, not a permanent field. Paul's point:
-- it shows until the next visit, he asks, he records the answer, and then it
-- closes into history instead of living there forever. So the single
-- dogs.follow_up text field (0086) becomes a small per-dog follow-up record with
-- an open/resolved lifecycle. Open ones show highlighted on the sheet and surface
-- on the Today stop (so he is reminded before he walks up); resolving one records
-- what he found and moves it to the dog's past-follow-up history. See
-- dog_followup_lifecycle (supersedes the field-only dog_follow_up).

create table if not exists public.dog_followups (
  id uuid primary key default gen_random_uuid(),
  dog_id uuid not null references public.dogs(id) on delete cascade,
  body text not null,
  status text not null default 'open' check (status in ('open','resolved')),
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists dog_followups_dog_idx on public.dog_followups (dog_id, status, created_at desc);
alter table public.dog_followups enable row level security;

-- Migrate the existing single-field follow-ups into open records, then drop the field.
insert into public.dog_followups (dog_id, body, status)
select id, btrim(follow_up), 'open' from public.dogs where nullif(btrim(follow_up), '') is not null;
alter table public.dogs drop column if exists follow_up;

create or replace function public.admin_add_dog_followup(p_dog_id uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if nullif(btrim(p_body), '') is null then raise exception 'a follow-up needs text'; end if;
  insert into public.dog_followups (dog_id, body) values (p_dog_id, btrim(p_body)) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_dog_followup(uuid, text) from public;
grant execute on function public.admin_add_dog_followup(uuid, text) to authenticated;

create or replace function public.admin_resolve_dog_followup(p_id uuid, p_resolution text default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.dog_followups
     set status = 'resolved', resolution = nullif(btrim(p_resolution), ''), resolved_at = now()
   where id = p_id;
  if not found then raise exception 'follow-up not found'; end if;
end;
$$;
revoke all on function public.admin_resolve_dog_followup(uuid, text) from public;
grant execute on function public.admin_resolve_dog_followup(uuid, text) to authenticated;

create or replace function public.admin_drop_dog_followup(p_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.dog_followups where id = p_id;
end;
$$;
revoke all on function public.admin_drop_dog_followup(uuid) from public;
grant execute on function public.admin_drop_dog_followup(uuid) to authenticated;

create or replace function public.admin_list_dog_followups(p_dog_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', f.id, 'body', f.body, 'status', f.status, 'resolution', f.resolution,
      'created_at', f.created_at, 'resolved_at', f.resolved_at)
      order by (f.status = 'open') desc, coalesce(f.resolved_at, f.created_at) desc)
    from public.dog_followups f where f.dog_id = p_dog_id), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_dog_followups(uuid) from public;
grant execute on function public.admin_list_dog_followups(uuid) to authenticated;

-- Today's stops surface the client's open follow-ups (with the dog), so Paul is
-- reminded at the appointment.
create or replace function public.admin_today_appointments()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'client_id', s.client_id,
      'client', c.name,
      'fallback', nullif((select string_agg(bd.name, ', ') from public.bath_dogs bd where bd.subscriber_id = a.subscriber_id), ''),
      'scheduled_start', a.scheduled_start,
      'service_type', a.service_type,
      'status', a.status,
      'amount_cents', a.amount_cents,
      'dog_count', a.dog_count,
      'followups', coalesce((
        select jsonb_agg(jsonb_build_object('dog', dd.name, 'body', f.body) order by dd.name)
          from public.dog_followups f join public.dogs dd on dd.id = f.dog_id
         where dd.client_id = s.client_id and f.status = 'open'), '[]'::jsonb)
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    where (a.scheduled_start at time zone 'America/New_York')::date = (now() at time zone 'America/New_York')::date
      and a.status not in ('cancelled','no_show','skipped')
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_today_appointments() from public;
grant execute on function public.admin_today_appointments() to authenticated;
