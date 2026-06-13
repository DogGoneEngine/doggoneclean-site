-- 0172_tracker_answer_ids.sql
-- Carry the answer-photo signal in tracker_status (a database function we can
-- always deploy) instead of the tracker-photos edge function. tracker_status now
-- returns answer_photo_ids: the ids of this appointment's shared photos tagged as
-- the answer to the special request. The /track page already gets every shared
-- photo's signed URL from tracker-photos; it just needs to know WHICH ids are the
-- answer, and now it does, with no edge-function change. (tracker-photos may also
-- return answers_request once redeployed; the page accepts either.)
create or replace function public.tracker_status(p_token text)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
  v public.visits%rowtype;
  v_first text;
  v_dogs jsonb;
  v_stage text;
  v_answer_ids jsonb;
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

  -- The shared photos, across all of this appointment's visits, that Paul tagged
  -- as the answer to the request. Ids only; the page matches them to the URLs it
  -- already has from tracker-photos.
  select coalesce(jsonb_agg(p.id), '[]'::jsonb) into v_answer_ids
    from public.visit_photos p
    join public.visits vv on vv.id = p.visit_id
   where vv.appointment_id = a.id and p.answers_request and p.client_visible;

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
    'answer_photo_ids', v_answer_ids
  );
end;
$$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;
