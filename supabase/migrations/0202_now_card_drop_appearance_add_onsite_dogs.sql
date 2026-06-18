-- 0202: two corrections to the right-now card (Paul, 2026-06-18).
--
-- (1) Drop the dog "appearance" / tell-apart field. The photo of each dog with
--     its name already does the disambiguation, and it is premature anyway: a
--     dog Paul has not groomed yet (Colleen Smith's two German Shepherds) is one
--     he is not expected to know anything about beyond "there are two German
--     Shepherds" until the client tells him the name and he works the dog. The
--     handling note stays (that IS the post-grooming obligation to remember).
--     Column was added 0201 this same day and is empty, so dropping is clean.
--
-- (2) Show every dog ON SITE, not only the dogs on today's appointment. When a
--     household has dogs that are not being groomed today (Emily Walker's Golden
--     while the Cavaliers go), Paul still meets them at the door and should know
--     their name, the same way he wants the names of the people on site. So the
--     card adds other_dogs: the client's active dogs not on this appointment,
--     name + breed + photo only (no work detail, since they are not being done).
--
-- Applied to dgc-prod 2026-06-18.

drop function if exists public.admin_set_dog_appearance(uuid, text);
alter table public.dogs drop column if exists appearance;

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

  -- Dogs on today's appointment: the assigned list, else the whole active roster.
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
      'photo_path', (select vp.storage_path from public.visit_photos vp where vp.dog_id = dd.id order by vp.created_at desc limit 1),
      'followups', coalesce((select jsonb_agg(f.body order by f.created_at desc) from public.dog_followups f where f.dog_id = dd.id and f.status = 'open'), '[]'::jsonb)
    ) order by dd.name), '[]'::jsonb),
    coalesce(sum(dd.price_cents)::int, 0)
  into v_dogs, v_total from dd;

  -- Other dogs on site, not being groomed today: name + breed + photo only, so
  -- Paul can greet them at the door. Empty when the whole roster is on the appt.
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', og.id, 'name', og.name, 'breed', og.breed,
           'photo_path', (select vp.storage_path from public.visit_photos vp where vp.dog_id = og.id order by vp.created_at desc limit 1)
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
