-- 0141: the Dog Gone Tracker grows up (pizza_tracker_client_loop, refined by
-- Paul 2026-06-10): an arrival step, a bringing-them-back step, live location
-- with ETA plumbing, and a link lifetime.
--
-- 1. Stage model is now six client-visible stages:
--      scheduled -> on_the_way -> arrived -> underway -> returning -> done
--    arrived ("We're here, getting set up, with you shortly") fires on the
--    "I'm here" tap and auto-advances to underway 10 minutes after the
--    Arrived stamp (no extra tap; by then the dog is in the trailer).
--    returning ("We're walking them back to your door") is a deliberate
--    one-tap stage per Paul: the client should know to look for the door.
--    A new 'returning' appointment status carries it.
-- 2. tracker_locations: one row per appointment, the operator's latest fix
--    while rolling. Written by admin_tracker_location from the Today sheet's
--    geolocation watch; read only by the tracker-eta edge function (service
--    role), which also caches the last Google-computed ETA on the row so
--    polling clients do not re-bill Distance Matrix every refresh.
-- 3. Link lifetime: a tracker link answers for its visit and for 7 days after
--    the scheduled end (long enough for "show someone" photo traffic), then
--    reports stage 'expired' so the page can point at the portal instead.
--    Tokens stay on the row (history is never deleted); only the public
--    answer goes quiet.
-- Grants are explicit per rpc_grants_explicit (functions are born locked).

alter table public.bath_appointments
  drop constraint if exists bath_appointments_status_check;
alter table public.bath_appointments
  add constraint bath_appointments_status_check
  check (status = any (array['requested','confirmed','tentative','on_the_way','on_site','returning','in_service','completed','no_show','cancelled','skipped']));

create table if not exists public.tracker_locations (
  appointment_id uuid primary key references public.bath_appointments(id) on delete cascade,
  lat numeric not null,
  lng numeric not null,
  recorded_at timestamptz not null default now(),
  eta_seconds integer,
  eta_computed_at timestamptz,
  eta_lat numeric,
  eta_lng numeric
);
alter table public.tracker_locations enable row level security;
-- No policies on purpose: the writer is an admin-gated SECURITY DEFINER RPC
-- and the reader is the tracker-eta edge function on the service role. The
-- operator's position never reaches a client except as the edge function's
-- token-scoped answer for the one stop they are waiting on.

create or replace function public.admin_tracker_location(
  p_appointment uuid,
  p_lat numeric,
  p_lng numeric
) returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then
    raise exception 'not authorized';
  end if;
  if p_lat is null or p_lng is null then
    raise exception 'bad coordinates';
  end if;
  insert into public.tracker_locations (appointment_id, lat, lng, recorded_at)
  values (p_appointment, p_lat, p_lng, now())
  on conflict (appointment_id) do update
    set lat = excluded.lat,
        lng = excluded.lng,
        recorded_at = excluded.recorded_at;
end;
$$;
revoke all on function public.admin_tracker_location(uuid, numeric, numeric) from public;
grant execute on function public.admin_tracker_location(uuid, numeric, numeric) to authenticated, service_role;

create or replace function public.admin_arrived(p_appointment uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
  v_arrived timestamptz;
begin
  if not public._is_admin() then
    raise exception 'not authorized';
  end if;

  select * into a from public.bath_appointments where id = p_appointment;
  if not found then
    raise exception 'appointment not found';
  end if;

  -- Move to on_site from any pre-arrival state; never downgrade a visit
  -- that is already underway, returning, or completed.
  if a.status in ('requested', 'confirmed', 'tentative', 'on_the_way') then
    update public.bath_appointments
       set status = 'on_site'
     where id = p_appointment;
    a.status := 'on_site';
  end if;

  -- Stamp the Arrived clock server-side if it is still empty, so the
  -- tracker stage (and the 10-minute auto-advance) move off this one tap.
  select arrived_at into v_arrived
    from public.visits
   where appointment_id = p_appointment
   order by created_at desc
   limit 1;
  if v_arrived is null then
    perform public.admin_stamp_appointment_time(p_appointment, 'arrived', now());
  end if;

  -- Parked in the driveway: stop broadcasting the truck's position.
  delete from public.tracker_locations where appointment_id = p_appointment;

  return jsonb_build_object(
    'tracker_token', a.tracker_token,
    'status', a.status
  );
end;
$$;
revoke all on function public.admin_arrived(uuid) from public;
grant execute on function public.admin_arrived(uuid) to authenticated, service_role;

-- The "bringing them back to your door" tap (Paul 2026-06-10): deliberately
-- manual, never automatic, because only Paul knows the moment the dogs are
-- done and headed for the door, and that is exactly when the client should
-- start watching for him.
create or replace function public.admin_returning(p_appointment uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
begin
  if not public._is_admin() then
    raise exception 'not authorized';
  end if;

  select * into a from public.bath_appointments where id = p_appointment;
  if not found then
    raise exception 'appointment not found';
  end if;

  if a.status in ('requested', 'confirmed', 'tentative', 'on_the_way', 'on_site', 'in_service') then
    update public.bath_appointments
       set status = 'returning'
     where id = p_appointment;
    a.status := 'returning';
  end if;

  return jsonb_build_object(
    'tracker_token', a.tracker_token,
    'status', a.status
  );
end;
$$;
revoke all on function public.admin_returning(uuid) from public;
grant execute on function public.admin_returning(uuid) to authenticated, service_role;

-- Six stages plus inactive and expired. Order of precedence: a terminal
-- status wins, then the explicit taps (returning, on_site), then the
-- time_is_money stamps Paul already taps, so the tracker moves with his
-- existing workflow even when a tap is missed.
create or replace function public.tracker_status(p_token text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
  v public.visits%rowtype;
  v_first text;
  v_dogs jsonb;
  v_stage text;
begin
  if p_token is null or length(p_token) < 16 then
    return jsonb_build_object('found', false);
  end if;

  select * into a from public.bath_appointments where tracker_token = p_token;
  if not found then
    return jsonb_build_object('found', false);
  end if;

  -- Link lifetime: 7 days past the scheduled end the link goes quiet and
  -- points the client at the portal (their photos and history live there).
  if a.scheduled_end is not null and now() > a.scheduled_end + interval '7 days' then
    return jsonb_build_object('found', true, 'stage', 'expired');
  end if;

  select * into v from public.visits
   where appointment_id = a.id
   order by created_at desc
   limit 1;

  select s.first_name into v_first
    from public.bath_subscribers s where s.id = a.subscriber_id;

  select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
    from public.bath_dogs d where d.subscriber_id = a.subscriber_id;

  v_stage := case
    when a.status in ('cancelled', 'no_show', 'skipped') then 'inactive'
    when a.status = 'completed' or v.departed_at is not null then 'done'
    when a.status = 'returning' then 'returning'
    when a.status = 'in_service' then 'underway'
    when a.status = 'on_site' or v.arrived_at is not null then
      case
        when v.arrived_at is not null and v.arrived_at <= now() - interval '10 minutes'
          then 'underway'
        else 'arrived'
      end
    when a.status = 'on_the_way' or v.inbound_at is not null then 'on_the_way'
    else 'scheduled'
  end;

  return jsonb_build_object(
    'found', true,
    'stage', v_stage,
    'scheduled_start', a.scheduled_start,
    'scheduled_end', a.scheduled_end,
    'first_name', v_first,
    'dogs', v_dogs
  );
end;
$$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;
