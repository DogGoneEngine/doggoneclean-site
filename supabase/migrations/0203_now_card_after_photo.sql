-- 0203: the right-now card's dog photo is the AFTER photo, specifically (Paul,
-- 2026-06-18). The after photo is the clean full view of the dog freshly groomed,
-- the best shot for recognizing it at the door. Paul's standard: if he cannot
-- tell the dog's features from its after photo, he took a bad photo, so the card
-- should hold that bar and not fall back to a before / paw / incidental shot. No
-- after photo on record yet -> no photo (the paw placeholder), not a worse one.
-- Most-recent after photo = the after shot from the latest visit that has one.
--
-- Applied to dgc-prod 2026-06-18.

create or replace function public.admin_now_card()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_today date := (now() at time zone 'America/New_York')::date;
  a public.bath_appointments%rowtype;
  v_client uuid;
  v_dogs jsonb;
  v_other jsonb;
  v_total int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select * into a from public.bath_appointments x
   where (x.scheduled_start at time zone 'America/New_York')::date = v_today
     and x.status in ('on_the_way', 'on_site', 'in_service', 'returning')
   order by x.scheduled_start desc limit 1;

  if not found then
    select * into a from public.bath_appointments x
     where (x.scheduled_start at time zone 'America/New_York')::date = v_today
       and x.status in ('confirmed', 'requested', 'tentative')
     order by x.scheduled_start asc limit 1;
  end if;

  if not found then
    return jsonb_build_object('found', false);
  end if;

  select s.client_id into v_client from public.bath_subscribers s where s.id = a.subscriber_id;

  with dd as (
    select dg.* from public.dogs dg
     where (a.dog_ids is not null and array_length(a.dog_ids, 1) > 0 and dg.id = any(a.dog_ids))
        or ((a.dog_ids is null or array_length(a.dog_ids, 1) = 0)
            and dg.client_id = v_client
            and coalesce(dg.roster_status, 'regular') in ('regular', 'occasional'))
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', dd.id, 'name', dd.name, 'breed', dd.breed,
      'standing_instructions', dd.standing_instructions, 'handling', dd.handling, 'price_cents', dd.price_cents,
      'photo_path', (select vp.storage_path from public.visit_photos vp
                      where vp.dog_id = dd.id and vp.kind = 'after' order by vp.created_at desc limit 1),
      'followups', coalesce((select jsonb_agg(f.body order by f.created_at desc) from public.dog_followups f where f.dog_id = dd.id and f.status = 'open'), '[]'::jsonb)
    ) order by dd.name), '[]'::jsonb),
    coalesce(sum(dd.price_cents)::int, 0)
  into v_dogs, v_total from dd;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', og.id, 'name', og.name, 'breed', og.breed,
           'photo_path', (select vp.storage_path from public.visit_photos vp
                           where vp.dog_id = og.id and vp.kind = 'after' order by vp.created_at desc limit 1)
         ) order by og.name), '[]'::jsonb)
    into v_other
    from public.dogs og
   where og.client_id = v_client
     and coalesce(og.roster_status, 'regular') in ('regular', 'occasional')
     and a.dog_ids is not null and array_length(a.dog_ids, 1) > 0
     and not (og.id = any(a.dog_ids));

  return jsonb_build_object(
    'found', true, 'appointment_id', a.id, 'client_id', v_client,
    'client', (select c.name from public.clients c where c.id = v_client),
    'status', a.status, 'scheduled_start', a.scheduled_start, 'service_type', a.service_type,
    'in_progress', a.status in ('on_the_way', 'on_site', 'in_service', 'returning'),
    'access_notes', (select c.access_notes from public.clients c where c.id = v_client),
    'onsite_people', (select c.onsite_people from public.clients c where c.id = v_client),
    'dogs', v_dogs, 'other_dogs', v_other, 'total_price_cents', v_total
  );
end;
$$;
revoke all on function public.admin_now_card() from public, anon;
grant execute on function public.admin_now_card() to authenticated, service_role;
