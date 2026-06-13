-- 0178_tracker_photo_credits.sql
--
-- Carry each shared photo's photographer to the tracker through the DB function
-- instead of the edge function, because edge-function deploys are gated in the
-- web session (same reason answer_photo_ids and worth_a_look already ride
-- tracker_status). tracker_status now returns photo_credits: a {photo_id ->
-- photographer first name} map built from visit_photos.taken_by_admin_id (0177).
-- The page labels each photo by this map, so a shot Jake took reads "Jake and
-- <dog>" without waiting on a tracker-photos redeploy.
--
-- FUTURE CLEANUP: the tracker-photos edge function was already updated (in the
-- repo, not yet deployed) to return the same `by` per photo. Once edge deploys
-- are ungated and that function ships, this photo_credits map is redundant and
-- can be dropped from tracker_status; the page prefers the map today and the two
-- always agree. Tracked in CLEAN_PARKING_LOT.md. See who_is_coming_is_pilot and
-- photo_attributed_to_logged_in_admin.

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
      ) else null end,
    'photo_credits', coalesce((
        select jsonb_object_agg(vp.id::text, ad.first_name)
          from public.visit_photos vp
          join public.visits vis on vis.id = vp.visit_id
          join public.admins ad on ad.id = vp.taken_by_admin_id
         where vis.appointment_id = a.id
           and vp.client_visible = true
           and vp.taken_by_admin_id is not null
      ), '{}'::jsonb)
  );
end;
$$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;
