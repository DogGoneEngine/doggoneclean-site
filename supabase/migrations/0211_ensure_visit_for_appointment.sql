-- 0211_ensure_visit_for_appointment.sql
--
-- Why: photos and visit notes hang off a STARTED visit row. Until now a visit
-- was only created by the Today-sheet arrival stamp ("I'm here"), so when Paul
-- opened a client record for an appointment that floats to the top, the card was
-- read-only: nowhere to add a photo (Paul, 2026-06-18, field test on Kevin's
-- record). The float is settled and correct; an appointment being TODAY is reason
-- enough to work it, no "underway" gate. So the record itself ensures the visit
-- exists, and the working card with the photo grid simply shows.
--
-- This creates a BARE visit (no inbound/arrived/departed stamp) for an
-- appointment if one does not already exist, and returns the visit id. It mirrors
-- the visit-insert inside admin_stamp_appointment_time but stamps no time, so it
-- never marks Paul as arrived or moves the appointment status. It is idempotent:
-- it reuses the existing visit (the same one admin_stamp_appointment_time later
-- finds and stamps), so there is exactly one visit per appointment and no clash
-- with one-visit-per-day.

create or replace function public.admin_ensure_visit(p_appointment uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_id uuid;
  a record;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select a2.id, a2.subscriber_id, a2.service_type, a2.scheduled_start, s.client_id
    into a
  from public.bath_appointments a2
  left join public.bath_subscribers s on s.id = a2.subscriber_id
  where a2.id = p_appointment;
  if not found then raise exception 'appointment not found'; end if;

  select id into v_id from public.visits
   where appointment_id = p_appointment order by created_at limit 1;
  if v_id is null then
    insert into public.visits (appointment_id, subscriber_id, client_id, visited_at, service_type, source)
    values (p_appointment, a.subscriber_id, a.client_id, a.scheduled_start, a.service_type, 'appointment')
    returning id into v_id;
  end if;

  return jsonb_build_object('visit_id', v_id);
end;
$function$;
