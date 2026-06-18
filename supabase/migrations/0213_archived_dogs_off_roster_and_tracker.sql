-- 0213_archived_dogs_off_roster_and_tracker.sql
--
-- Dogs that are gone or come and go (Paul, 2026-06-18, Ace and Kage as the model
-- for every client): keep them OFF the everyday screen and OFF the live tracker
-- ("do not say we are grooming them today"), but let an appointment be made WITH
-- them when they are actually back.
--
-- Root cause found: a legacy client has the same dog in two places, public.dogs
-- (roster_status, the client-record roster) and public.bath_dogs (active, what the
-- tracker fallback reads), and they had drifted apart: Ace and Kage were 'moved' in
-- public.dogs but still active=true in bath_dogs, so a normal appointment's tracker
-- would announce them. Three fixes, plus the UI handles adding a returned dog.
--
--   1. admin_set_dog_status also syncs bath_dogs.active, so archiving a dog (moved/
--      former/deceased) drops it from the tracker fallback and reactivating it
--      (regular/occasional) brings it back. One archive action, both records.
--   2. tracker_status only announces ACTIVE bath_dogs in the fallback branch, so a
--      gone dog never appears as "being groomed today" unless it is explicitly on
--      the appointment's dog_ids (which means it really is back and on the stop).
--   3. Backfill: align every existing bath_dogs.active with its public.dogs
--      roster_status, fixing Ace, Kage, and any other drifted rows.

-- 1. Archive action keeps both dog records in step.
create or replace function public.admin_set_dog_status(p_dog_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  d_name text;
  d_client uuid;
  v_active boolean;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_status not in ('regular','occasional','moved','former','deceased') then
    raise exception 'invalid roster_status: %', p_status;
  end if;
  update public.dogs set roster_status = p_status, updated_at = now()
   where id = p_dog_id
   returning name, client_id into d_name, d_client;
  if not found then raise exception 'dog not found'; end if;

  -- Keep the funnel/tracker record (bath_dogs.active) in step with the roster
  -- archive. Matched by the client's subscriber and the dog name (the only link
  -- between the two tables for legacy-seeded dogs).
  v_active := p_status in ('regular','occasional');
  update public.bath_dogs bd
     set active = v_active, updated_at = now()
    from public.bath_subscribers s
   where s.id = bd.subscriber_id
     and s.client_id = d_client
     and lower(bd.name) = lower(d_name);
end;
$function$;

-- 2. Tracker fallback announces only ACTIVE funnel dogs. Recreated from 0182 with
--    that single guard added; every other branch and field is unchanged.
create or replace function public.tracker_status(p_token text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
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

  -- An appointment with an assigned dog list shows only those dogs (so a returned
  -- archived dog explicitly added to the stop DOES show); otherwise the active
  -- funnel dogs; otherwise the legacy client's regular/occasional roster. A dog
  -- that is gone never reaches the tracker through a fallback.
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

-- 3. Backfill: align every bath_dogs.active with its public.dogs roster_status,
--    fixing Ace, Kage, and any other rows that drifted.
update public.bath_dogs bd
   set active = (coalesce(d.roster_status, 'regular') in ('regular','occasional')),
       updated_at = now()
  from public.bath_subscribers s
  join public.dogs d on d.client_id = s.client_id
 where s.id = bd.subscriber_id
   and lower(bd.name) = lower(d.name)
   and bd.active <> (coalesce(d.roster_status, 'regular') in ('regular','occasional'));
