-- 0206: a departed time completes the stop no matter how it is entered (Paul,
-- 2026-06-18). The 0205 fix flipped status to completed on the "All done" button,
-- but the other way to reach Departed is the manual "fix times" entry: drive away,
-- forget to tap done, then type the time you actually left. That is just as much
-- "I left and finished" as the button is, so it should complete the stop too.
--
-- Put the rule at the source: admin_stamp_appointment_time (the one path behind
-- both the button's stamp and the manual entry) now, on the departed field,
-- completes the appointment when a time is set and reopens it (back to returning)
-- when the time is cleared. Symmetry keeps the StopCard's wrapped view, the
-- status, and the clocks in agreement however the time was entered or fixed.
-- Inbound and arrived stamps are left to the buttons; departed is the one with a
-- real consequence (closing the stop, leaving the Right Now window, counting as
-- done in reports).
--
-- Applied to dgc-prod 2026-06-18.

create or replace function public.admin_stamp_appointment_time(
  p_appointment_id uuid,
  p_field text,
  p_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_id uuid;
  a record;
  r record;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_field not in ('inbound', 'arrived', 'departed') then
    raise exception 'bad field: %', p_field;
  end if;

  select a2.id, a2.subscriber_id, a2.service_type, a2.scheduled_start, s.client_id
    into a
  from public.bath_appointments a2
  left join public.bath_subscribers s on s.id = a2.subscriber_id
  where a2.id = p_appointment_id;
  if not found then raise exception 'appointment not found'; end if;

  select id into v_id from public.visits
   where appointment_id = p_appointment_id order by created_at limit 1;
  if v_id is null then
    insert into public.visits (appointment_id, subscriber_id, client_id, visited_at, service_type, source)
    values (p_appointment_id, a.subscriber_id, a.client_id, a.scheduled_start, a.service_type, 'appointment')
    returning id into v_id;
  end if;

  update public.visits set
    inbound_at  = case when p_field = 'inbound'  then p_at else inbound_at  end,
    arrived_at  = case when p_field = 'arrived'  then p_at else arrived_at  end,
    departed_at = case when p_field = 'departed' then p_at else departed_at end
  where id = v_id;

  update public.visits set actual_minutes =
    case when arrived_at is not null and departed_at is not null
         then greatest(0, round(extract(epoch from (departed_at - arrived_at)) / 60.0)::int)
         else null end
  where id = v_id;

  -- A departed time means the stop is finished, whether tapped or typed in after
  -- the fact; clearing it reopens the stop. Only nudge across that one boundary,
  -- never regressing a stop that is mid-visit.
  if p_field = 'departed' then
    if p_at is not null then
      update public.bath_appointments set status = 'completed', updated_at = now()
       where id = p_appointment_id and status <> 'completed';
    else
      update public.bath_appointments set status = 'returning', updated_at = now()
       where id = p_appointment_id and status = 'completed';
    end if;
  end if;

  select inbound_at, arrived_at, departed_at, actual_minutes
    into r from public.visits where id = v_id;
  return jsonb_build_object(
    'visit_id', v_id,
    'inbound_at', r.inbound_at,
    'arrived_at', r.arrived_at,
    'departed_at', r.departed_at,
    'actual_minutes', r.actual_minutes
  );
end;
$function$;
