-- 0177_photo_taken_by_and_tracker_operator.sql
--
-- From a real training run (Paul, 2026-06-13): Jake shot the after photo of
-- Barbara Lape's dog Manning while Paul was the pilot in command (operator on
-- record). On the client tracker the "who's coming to your door" card flipped
-- to that newest with-dog photo, so it showed Jake's face under Paul's name.
-- Two separate truths were tangled:
--
--   1. WHO IS COMING is the pilot in command. The card should be that one
--      person, named, with their own profile photo, never a scraped recent
--      visit photo that could be anyone. (The name was also hardcoded "Paul
--      Nickerson" in the page and never followed the assigned operator.)
--   2. WHO TOOK A PHOTO is whoever was logged in when they took it, not the
--      pilot in command. Jake logged in as Jake shooting Manning is "Jake and
--      Manning," even though Paul runs the appointment.
--
-- This migration carries the durable half:
--   a. visit_photos.taken_by_admin_id records the logged-in admin who took the
--      photo (stamped by admin_add_visit_photo from auth.uid()).
--   b. tracker_status returns the pilot-in-command operator (first, full name,
--      bio) so the page names the right person instead of a hardcoded string.
-- The page swaps the portrait to that operator's profile photo, and the photo
-- strip labels each shot by its photographer. See who_is_coming_is_pilot and
-- photo_attributed_to_logged_in_admin in the Oracle.

-- 1. Who took each photo. References admins; null for older rows until backfill.
alter table public.visit_photos
  add column if not exists taken_by_admin_id uuid references public.admins(id);

-- Backfill history with the best signal available: the appointment's operator
-- on record. Going forward the caller stamps the real logged-in admin, so this
-- only touches rows that predate the column.
update public.visit_photos vp
   set taken_by_admin_id = a.operator_admin_id
  from public.visits v
  join public.bath_appointments a on a.id = v.appointment_id
 where vp.visit_id = v.id
   and vp.taken_by_admin_id is null
   and a.operator_admin_id is not null;

-- 2. Stamp the logged-in admin as the photographer on every new photo.
drop function if exists public.admin_add_visit_photo(uuid, text, text, uuid);
create or replace function public.admin_add_visit_photo(p_visit_id uuid, p_kind text, p_path text, p_dog_id uuid default null)
returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid; v_client uuid; v_taker uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_kind not in ('before','after','with_dog','extra') then raise exception 'bad photo kind'; end if;
  select client_id into v_client from public.visits where id = p_visit_id;
  if not found then raise exception 'visit not found'; end if;
  if p_dog_id is not null and not exists (
    select 1 from public.dogs d where d.id = p_dog_id and d.client_id = v_client
  ) then raise exception 'dog does not belong to this client'; end if;
  -- The photographer is whoever is logged in, not the pilot in command.
  select id into v_taker from public.admins where auth_user_id = auth.uid();
  insert into public.visit_photos (visit_id, kind, storage_path, dog_id, client_visible, taken_by_admin_id)
  values (p_visit_id, p_kind, p_path, p_dog_id, p_kind in ('before','after','with_dog'), v_taker)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_visit_photo(uuid, text, text, uuid) from public, anon;
grant execute on function public.admin_add_visit_photo(uuid, text, text, uuid) to authenticated, service_role;

-- 3. tracker_status: name the pilot in command. Only the public-facing fields
-- (first name, full name, bio) leave; this is a SECURITY DEFINER anon RPC, so
-- it deliberately exposes nothing beyond what already shows on the tracker.
create or replace function public.tracker_status(p_token text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  a public.bath_appointments%rowtype;
  v public.visits%rowtype;
  v_first text;
  v_dogs jsonb;
  v_stage text;
  v_op record;
begin
  if p_token is null or length(p_token) < 16 then
    return jsonb_build_object('found', false);
  end if;

  select * into a from public.bath_appointments where tracker_token = p_token;
  if not found then
    return jsonb_build_object('found', false);
  end if;

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

  -- The pilot in command: the appointment's operator on record, or the owner
  -- when none is assigned. This is who shows up, so this is who the card names.
  select first_name, last_name, bio into v_op
    from public.admins
   where ((a.operator_admin_id is not null and id = a.operator_admin_id)
       or (a.operator_admin_id is null and role = 'owner'))
     and is_active
   order by case when id = a.operator_admin_id then 0 else 1 end
   limit 1;

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
    'dogs', v_dogs,
    'special_request', v.special_request,
    'request_delivered', (v_stage in ('done', 'returning')),
    'operator', case when v_op.first_name is not null then jsonb_build_object(
        'first', v_op.first_name,
        'name', btrim(coalesce(v_op.first_name, '') || ' ' || coalesce(v_op.last_name, '')),
        'bio', v_op.bio
      ) else null end
  );
end;
$$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;
