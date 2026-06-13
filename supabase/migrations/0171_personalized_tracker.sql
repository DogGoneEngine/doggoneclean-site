-- 0171_personalized_tracker.sql
-- The heard-and-delivered loop (tracker_heard_and_delivered): a per-visit special
-- request the client made at the door shows on their tracker as "you asked for",
-- and once the visit wraps it reads as done, with the photos that answer it shown
-- right beside it. Per-visit on purpose: a standing preference would be noise; the
-- ask belongs to this visit and ties to this visit's proof photos.

alter table public.visits add column if not exists special_request text;
alter table public.visit_photos add column if not exists answers_request boolean not null default false;

-- Capture the request at the door from the Today stop card. Find-or-create the
-- visit for the appointment (same pattern as admin_stamp_appointment_time), then
-- set or clear the request. Any active admin running the stop can do it.
create or replace function public.admin_set_visit_request(p_appointment_id uuid, p_text text)
returns uuid language plpgsql security definer set search_path to ''
as $$
declare a record; v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select a2.id, a2.subscriber_id, a2.service_type, a2.scheduled_start, s.client_id into a
    from public.bath_appointments a2
    left join public.bath_subscribers s on s.id = a2.subscriber_id
   where a2.id = p_appointment_id;
  if not found then raise exception 'appointment not found'; end if;
  select id into v_id from public.visits where appointment_id = p_appointment_id order by created_at limit 1;
  if v_id is null then
    insert into public.visits (appointment_id, subscriber_id, client_id, visited_at, service_type, source)
    values (p_appointment_id, a.subscriber_id, a.client_id, a.scheduled_start, a.service_type, 'appointment')
    returning id into v_id;
  end if;
  update public.visits set special_request = nullif(btrim(coalesce(p_text, '')), ''), updated_at = now()
   where id = v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_set_visit_request(uuid, text) from public, anon;
grant execute on function public.admin_set_visit_request(uuid, text) to authenticated, service_role;

-- Tag a photo as the answer to the request. Tagging also shares it
-- (client_visible), because the whole point is the client sees the proof.
create or replace function public.admin_set_photo_answers_request(p_id uuid, p_val boolean)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.visit_photos
     set answers_request = coalesce(p_val, false),
         client_visible = case when coalesce(p_val, false) then true else client_visible end
   where id = p_id;
  if not found then raise exception 'photo not found'; end if;
end;
$$;
revoke all on function public.admin_set_photo_answers_request(uuid, boolean) from public, anon;
grant execute on function public.admin_set_photo_answers_request(uuid, boolean) to authenticated, service_role;

-- tracker_status: now also returns the special request and whether it is
-- delivered (the work is finishing or done). Otherwise unchanged from 0141.
create or replace function public.tracker_status(p_token text)
returns jsonb language plpgsql security definer set search_path to ''
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
    'dogs', v_dogs,
    'special_request', v.special_request,
    'request_delivered', (v_stage in ('done', 'returning'))
  );
end;
$$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;

-- admin_today_appointments: carry the special request to the stop card so it
-- pre-fills and Paul sees what he captured. Operator masking unchanged (it only
-- strips amount_cents; the request is fine for whoever runs the stop).
CREATE OR REPLACE FUNCTION public.admin_today_appointments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  result := coalesce((
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
      'special_request', vt.special_request,
      'followups', coalesce((
        select jsonb_agg(jsonb_build_object('dog', dd.name, 'body', f.body) order by dd.name)
          from public.dog_followups f join public.dogs dd on dd.id = f.dog_id
         where dd.client_id = s.client_id and f.status = 'open'), '[]'::jsonb)
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    left join lateral (
      select inbound_at, arrived_at, departed_at, special_request
        from public.visits v
       where v.appointment_id = a.id
       order by v.created_at limit 1
    ) vt on true
    where (a.scheduled_start at time zone 'America/New_York')::date = (now() at time zone 'America/New_York')::date
      and a.status not in ('cancelled','no_show','skipped')
  ), '[]'::jsonb);
  if public._admin_role() = 'operator' then
    result := coalesce((select jsonb_agg(e - 'amount_cents') from jsonb_array_elements(result) e), '[]'::jsonb);
  end if;
  return result;
end;
$function$;
revoke all on function public.admin_today_appointments() from public, anon;
grant execute on function public.admin_today_appointments() to authenticated, service_role;

-- admin_get_client: carry special_request on each visit and answers_request on
-- each photo, so the client sheet shows what was asked and which photo answers
-- it. Otherwise identical to the 0150 definition (operator masking unchanged).
CREATE OR REPLACE FUNCTION public.admin_get_client(p_client_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
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
                                              'dog_id', p.dog_id, 'dog_name', d3.name) order by p.created_at)
            from public.visit_photos p left join public.dogs d3 on d3.id = p.dog_id
           where p.visit_id = v.id), '[]'::jsonb)
      ) order by v.visited_at desc)
        from public.visits v where v.client_id = c.id), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'scheduled_start', a.scheduled_start, 'status', a.status,
        'service_type', a.service_type, 'amount_cents', a.amount_cents
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
revoke all on function public.admin_get_client(uuid) from public, anon;
grant execute on function public.admin_get_client(uuid) to authenticated, service_role;
