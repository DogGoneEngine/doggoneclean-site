-- 0228_admin_reschedule_cancel.sql
-- Owner-side reschedule and cancel for a single visit, the piece that did not carry
-- over when Acuity left (the app could book and complete, but not reshuffle). These
-- are admin-authority: unlike the client-facing bath_reschedule_appointment /
-- bath_skip_appointment (locked to the subscriber, blocked inside 24h, slot-engine
-- gated), the owner can move a visit to ANY time and cancel ANY upcoming visit. Both
-- are plain UPDATEs, so the existing notify triggers (client reschedule/cancel on
-- app-native visits, and the owner schedule-alert card/ping) fire exactly as they
-- already do. Purely additive: no existing function, trigger, or row is changed.

create or replace function public.admin_reschedule_appointment(p_appointment_id uuid, p_new_start timestamptz)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_appt record;
  v_dur  int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_new_start is null then return jsonb_build_object('ok', false, 'error', 'no_time'); end if;

  select * into v_appt from public.bath_appointments where id = p_appointment_id;
  if v_appt.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_appt.status not in ('requested', 'confirmed', 'tentative') then
    return jsonb_build_object('ok', false, 'error', 'not_reschedulable');
  end if;

  -- Keep the visit's existing length; fall back to its stored duration, then 60 min.
  v_dur := coalesce(
    nullif(round(extract(epoch from (v_appt.scheduled_end - v_appt.scheduled_start)) / 60)::int, 0),
    v_appt.duration_minutes, 60);

  begin
    update public.bath_appointments
       set original_scheduled_start = coalesce(original_scheduled_start, scheduled_start),
           scheduled_start = p_new_start,
           scheduled_end   = p_new_start + make_interval(mins => v_dur),
           duration_minutes = v_dur,
           updated_at = now()
     where id = p_appointment_id;
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'error', 'overlap');
  end;

  return jsonb_build_object('ok', true, 'new_start', p_new_start);
end;
$function$;

create or replace function public.admin_cancel_appointment(p_appointment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_appt record;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select * into v_appt from public.bath_appointments where id = p_appointment_id;
  if v_appt.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_appt.status in ('cancelled', 'completed', 'no_show', 'skipped') then
    return jsonb_build_object('ok', false, 'error', 'already_' || v_appt.status);
  end if;

  update public.bath_appointments
     set status = 'cancelled', updated_at = now()
   where id = p_appointment_id;

  return jsonb_build_object('ok', true, 'status', 'cancelled');
end;
$function$;
