-- 0212_appointment_dogs_editable.sql
--
-- Which dogs are on THIS appointment, editable after booking (Paul, 2026-06-18:
-- "not all of the dogs at Kevin's are going to be groomed in this appointment").
-- Booking already records bath_appointments.dog_ids and prices by the dogs going
-- (price_by_dogs_going, migration 0181), but there was no way to CHANGE the set on
-- an appointment that already exists, like Kevin's today or Colleen's that just
-- happened. Two parts:
--   1. admin_set_appointment_dogs: set the dog list on an appointment, re-price to
--      the dogs going (the settled rule), and keep the linked visit's dog list in
--      step so photos and scores follow the same subset.
--   2. admin_get_client: expose appointment_id and dog_ids on each visit, and
--      dog_ids on each upcoming appointment, so the picker can pre-check the dogs
--      actually on the appointment.

-- 1. Set the dogs on an appointment (and its visit), re-priced to those dogs.
create or replace function public.admin_set_appointment_dogs(p_appointment uuid, p_dog_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  a record;
  v_dogs uuid[];
  v_amount int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select a2.id, a2.subscriber_id, a2.amount_cents, s.client_id
    into a
  from public.bath_appointments a2
  left join public.bath_subscribers s on s.id = a2.subscriber_id
  where a2.id = p_appointment;
  if not found then raise exception 'appointment not found'; end if;

  if p_dog_ids is null or array_length(p_dog_ids, 1) is null then
    raise exception 'pick at least one dog';
  end if;

  -- Only this client's dogs, deduped to the real rows.
  select array_agg(d.id) into v_dogs
    from public.dogs d
   where d.id = any(p_dog_ids) and d.client_id = a.client_id;
  if coalesce(array_length(v_dogs, 1), 0) <> (select count(distinct x) from unnest(p_dog_ids) x) then
    raise exception 'dogs not this client';
  end if;

  -- Price the dogs going (price_by_dogs_going). Keep the prior amount only if the
  -- selected dogs carry no price at all, so a missing price never zeroes a charge.
  select nullif(sum(coalesce(d.price_cents, 0)), 0)::int into v_amount
    from public.dogs d where d.id = any(v_dogs);
  v_amount := coalesce(v_amount, a.amount_cents);

  update public.bath_appointments
     set dog_ids = v_dogs,
         dog_count = array_length(v_dogs, 1),
         amount_cents = v_amount,
         updated_at = now()
   where id = p_appointment;

  -- Keep the linked visit's dog list in step (photos and scores follow it).
  update public.visits set dog_ids = v_dogs
   where appointment_id = p_appointment;

  return jsonb_build_object('ok', true, 'dog_ids', v_dogs, 'amount_cents', v_amount);
end;
$function$;
revoke all on function public.admin_set_appointment_dogs(uuid, uuid[]) from public, anon;
grant execute on function public.admin_set_appointment_dogs(uuid, uuid[]) to authenticated, service_role;

-- 2. Surface appointment_id + dog_ids on visits, and dog_ids on upcoming, so the
--    picker can pre-check. This recreates admin_get_client with those two adds and
--    every prior field and operator-role redaction preserved.
create or replace function public.admin_get_client(p_client_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'client', to_jsonb(c.*),
    'dogs', coalesce((select jsonb_agg(to_jsonb(d.*) order by d.name) from public.dogs d where d.client_id = c.id), '[]'::jsonb),
    'subscriber', (select to_jsonb(s.*) from public.bath_subscribers s where s.client_id = c.id limit 1),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'visited_at', v.visited_at, 'service_type', v.service_type,
        'appointment_id', v.appointment_id, 'dog_ids', v.dog_ids,
        'work_done', v.work_done, 'visit_notes', v.visit_notes,
        'actual_minutes', v.actual_minutes,
        'amount_collected_cents', v.amount_collected_cents, 'tip_cents', v.tip_cents,
        'payment_method', v.payment_method, 'condition_flags', v.condition_flags, 'source', v.source,
        'special_request', v.special_request,
        'dog_ratings', coalesce((
          select jsonb_agg(jsonb_build_object('dog_id', r.dog_id, 'name', d2.name, 'score', r.score, 'note', r.note) order by d2.name)
            from public.visit_dog_ratings r left join public.dogs d2 on d2.id = r.dog_id
           where r.visit_id = v.id), '[]'::jsonb),
        'photos', coalesce((
          select jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'path', p.storage_path, 'client_visible', p.client_visible,
                                              'answers_request', p.answers_request,
                                              'team_visible', p.team_visible, 'website_state', p.website_state,
                                              'worth_a_look', p.worth_a_look, 'field_flag', p.field_flag,
                                              'note', p.note, 'field_note', p.field_note,
                                              'dog_id', p.dog_id, 'dog_name', d3.name) order by p.created_at)
            from public.visit_photos p left join public.dogs d3 on d3.id = p.dog_id
           where p.visit_id = v.id), '[]'::jsonb)
      ) order by v.visited_at desc)
        from public.visits v where v.client_id = c.id), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'scheduled_start', a.scheduled_start, 'status', a.status,
        'service_type', a.service_type, 'amount_cents', a.amount_cents, 'dog_ids', a.dog_ids
      ) order by a.scheduled_start)
        from public.bath_appointments a
        join public.bath_subscribers s2 on s2.id = a.subscriber_id
       where s2.client_id = c.id and a.status in ('requested','confirmed','tentative')), '[]'::jsonb)
  ) into result
  from public.clients c where c.id = p_client_id;
  if result is null then raise exception 'client not found'; end if;

  if public._admin_role() = 'operator' then
    result := result || jsonb_build_object('contact_links',
      case when (result->'client'->>'phone_e164') is not null
           then jsonb_build_object('sms', 'sms:' || (result->'client'->>'phone_e164'))
           else '{}'::jsonb end);
    result := jsonb_set(result, '{client}',
      (result->'client') - 'phone_e164' - 'email' - 'message_thoughts' - 'note');
    if jsonb_typeof(result->'subscriber') = 'object' then
      result := jsonb_set(result, '{subscriber}', (result->'subscriber') - 'phone_e164' - 'email');
    end if;
    result := jsonb_set(result, '{visits}', coalesce((
      select jsonb_agg(v - 'amount_collected_cents' - 'tip_cents' - 'payment_method')
        from jsonb_array_elements(result->'visits') v), '[]'::jsonb));
    result := jsonb_set(result, '{upcoming}', coalesce((
      select jsonb_agg(v - 'amount_cents')
        from jsonb_array_elements(result->'upcoming') v), '[]'::jsonb));
  end if;
  return result;
end;
$function$;
