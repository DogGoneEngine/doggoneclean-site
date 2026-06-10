-- 0136: the Dog Gone Tracker, v1 plumbing (pizza_tracker_client_loop).
-- Client-facing name locked by Paul 2026-06-10: the Dog Gone Tracker
-- ("pizza tracker" stays the internal inspiration shorthand).
--
-- 1. Every appointment carries an unguessable tracker_token; /track?t=<token>
--    is the client's view of the visit.
-- 2. tracker_status(p_token): anon-callable, token-scoped read returning only
--    what the recipient should see (stage, block, first name, dog names).
--    The stage derives from the appointment status AND the time_is_money
--    stamps Paul already taps (Left / Arrived / Done), so no new field
--    workflow is needed for the tracker to move.
-- 3. admin_on_my_way(p_appointment): one tap flips the appointment to
--    on_the_way (never downgrades a later status) and returns the token so
--    the Today sheet can hand Paul a ready-to-send message.
-- 4. visit_photos.client_visible: groundwork for sharing chosen photos to
--    the client (portal + tracker photo surfaces are the next slice).
-- 5. review_asks: the no-spam teeth for the post-visit review ask (ask once,
--    track the click, stop forever once reviewed). Schema now; the send
--    wires up with Twilio/Resend.
-- Grants are explicit per rpc_grants_explicit (functions are born locked).

alter table public.bath_appointments
  add column if not exists tracker_token text;

update public.bath_appointments
   set tracker_token = replace(gen_random_uuid()::text, '-', '')
 where tracker_token is null;

alter table public.bath_appointments
  alter column tracker_token set default replace(gen_random_uuid()::text, '-', ''),
  alter column tracker_token set not null;

create unique index if not exists bath_appointments_tracker_token_idx
  on public.bath_appointments (tracker_token);

alter table public.visit_photos
  add column if not exists client_visible boolean not null default false;

create table if not exists public.review_asks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  subscriber_id uuid references public.bath_subscribers(id) on delete cascade,
  appointment_id uuid references public.bath_appointments(id) on delete set null,
  asked_at timestamptz,
  channel text,
  clicked_at timestamptz,
  reviewed_at timestamptz,
  suppressed boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.review_asks enable row level security;
create index if not exists review_asks_client_idx on public.review_asks (client_id);
create index if not exists review_asks_subscriber_idx on public.review_asks (subscriber_id);

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
    when a.status in ('on_site', 'in_service') or v.arrived_at is not null then 'arrived'
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

create or replace function public.admin_on_my_way(p_appointment uuid)
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

  -- Flip to on_the_way only from a pre-departure state; never downgrade a
  -- visit that is already on site, underway, or completed.
  if a.status in ('requested', 'confirmed', 'tentative') then
    update public.bath_appointments
       set status = 'on_the_way'
     where id = p_appointment;
    a.status := 'on_the_way';
  end if;

  return jsonb_build_object(
    'tracker_token', a.tracker_token,
    'status', a.status
  );
end;
$$;

revoke all on function public.admin_on_my_way(uuid) from public;
grant execute on function public.admin_on_my_way(uuid) to authenticated, service_role;
