-- 0133_stamp_appointment_time.sql
-- Move the time_is_money clock capture onto the Today sheet. Each of today's
-- stops gets a tappable inbound / arrived / departed time. A tap stamps the
-- moment onto a visit linked to that appointment (created on first tap), so the
-- existing admin_export_time_is_money export still picks it up unchanged.
-- admin_today_appointments now also returns the three times so the row prefills.

-- Stamp one clock on an appointment's visit (idempotent on appointment_id).
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

  -- Minutes are the time on site: arrived -> departed when both are stamped.
  update public.visits set actual_minutes =
    case when arrived_at is not null and departed_at is not null
         then greatest(0, round(extract(epoch from (departed_at - arrived_at)) / 60.0)::int)
         else null end
  where id = v_id;

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

-- Today's stops, now carrying the linked visit's three clock times so the
-- Today row prefills with whatever has already been tapped.
create or replace function public.admin_today_appointments()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
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
      'inbound_at', vt.inbound_at,
      'arrived_at', vt.arrived_at,
      'departed_at', vt.departed_at,
      'followups', coalesce((
        select jsonb_agg(jsonb_build_object('dog', dd.name, 'body', f.body) order by dd.name)
          from public.dog_followups f join public.dogs dd on dd.id = f.dog_id
         where dd.client_id = s.client_id and f.status = 'open'), '[]'::jsonb)
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    left join lateral (
      select inbound_at, arrived_at, departed_at
        from public.visits v
       where v.appointment_id = a.id
       order by v.created_at limit 1
    ) vt on true
    where (a.scheduled_start at time zone 'America/New_York')::date = (now() at time zone 'America/New_York')::date
      and a.status not in ('cancelled','no_show','skipped')
  ), '[]'::jsonb);
end;
$function$;
