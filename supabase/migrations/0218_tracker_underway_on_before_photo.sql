-- 0217_tracker_underway_on_before_photo.sql
--
-- Regression fix (Paul 2026-06-18, field): the tracker showed "arrived / in the
-- driveway" while Paul was already in the trailer with the first before photo
-- taken. The before photo is supposed to flip the stage arrived -> underway
-- (0148: "no photo, no auto-advance; a 10-minute timer would lie while he is still
-- on the client's couch"). My 0213 rewrite of tracker_status was based on the 0182
-- file, which carried the OLD 10-minute-timer branch, so it reverted the
-- before-photo behavior. This restores the before-photo check; every other part of
-- the current function (appointment dog_ids filter, active bath_dogs fallback,
-- legacy roster fallback, operator, photo_credits) is preserved exactly.

create or replace function public.tracker_status(p_token text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  a public.bath_appointments%rowtype;
  v public.visits%rowtype;
  v_first text;
  v_client uuid;
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

  select s.first_name, s.client_id into v_first, v_client
    from public.bath_subscribers s where s.id = a.subscriber_id;

  if a.dog_ids is not null and array_length(a.dog_ids, 1) > 0 then
    select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
      from public.dogs d where d.id = any(a.dog_ids);
  else
    select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
      from public.bath_dogs d where d.subscriber_id = a.subscriber_id and d.active is true;
    if (v_dogs is null or v_dogs = '[]'::jsonb) and v_client is not null then
      select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
        from public.dogs d
       where d.client_id = v_client
         and coalesce(d.roster_status, 'regular') in ('regular', 'occasional');
    end if;
  end if;

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
        when v.id is not null and exists (
          select 1 from public.visit_photos vp
           where vp.visit_id = v.id and vp.kind = 'before')
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
$function$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;
