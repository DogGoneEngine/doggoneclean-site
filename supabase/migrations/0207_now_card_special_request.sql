-- 0207: the right-now card carries the special request (Paul, 2026-06-18). The
-- whole reason the card exists is the door, and recording what the client asks
-- for at the door is a door action. It already lived only on the stop card down
-- in the list; surface it on the card Paul is actually looking at. admin_now_card
-- now returns the visit's current special_request so the box prefills; the card's
-- input writes it through the existing admin_set_visit_request. Per-visit, exactly
-- as the stop card and the tracker's heard-and-delivered loop already treat it.
--
-- Applied to dgc-prod 2026-06-18.

create or replace function public.admin_now_card()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
  v_client uuid;
  v_dogs jsonb;
  v_other jsonb;
  v_total int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select * into a from public.bath_appointments x
   where x.status in ('on_the_way', 'on_site', 'in_service', 'returning')
     and not exists (select 1 from public.visits v where v.appointment_id = x.id and v.departed_at is not null)
   order by x.scheduled_start desc limit 1;

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
    'in_progress', true,
    'access_notes', (select c.access_notes from public.clients c where c.id = v_client),
    'onsite_people', (select c.onsite_people from public.clients c where c.id = v_client),
    'special_request', (select v.special_request from public.visits v where v.appointment_id = a.id order by v.created_at limit 1),
    'dogs', v_dogs, 'other_dogs', v_other, 'total_price_cents', v_total
  );
end;
$$;
revoke all on function public.admin_now_card() from public, anon;
grant execute on function public.admin_now_card() to authenticated, service_role;
