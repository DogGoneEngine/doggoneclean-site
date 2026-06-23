-- 0232_get_client_visit_departed_at.sql
--
-- Bug (found from a phone screenshot, 2026-06-22 ~8pm ET): a completed visit
-- with a Departed time stamped (Emily Cummings / Klaus, departed 7:01pm) stayed
-- pinned as "Today's visit" at the top of the client record on a fresh load,
-- instead of dropping into the Visit history.
--
-- Cause: the client sheet pins a visit when easternDay(visited_at) == today AND
-- NOT departed_at. But admin_get_client builds each visit object field by field
-- and never included departed_at, so v.departed_at was always undefined on the
-- sheet and the "unpin once departed" half of the rule could never fire. A
-- today's visit therefore only ever dropped off the top when the day rolled over.
--
-- Fix: include departed_at in each visit object. The pin rule now sees the stamp
-- and a wrapped visit drops to the history immediately. Rebuilt from the live
-- definition; departed_at is not money, so the operator-role redaction below is
-- left as is.

create or replace function public.admin_get_client(p_client_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public', 'pg_temp'
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
        'id', v.id, 'visited_at', v.visited_at, 'departed_at', v.departed_at, 'service_type', v.service_type,
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
revoke all on function public.admin_get_client(uuid) from public, anon;
grant execute on function public.admin_get_client(uuid) to authenticated, service_role;
