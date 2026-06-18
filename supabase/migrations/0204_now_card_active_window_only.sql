-- 0204: the right-now card only lives during the active window (Paul, 2026-06-18).
--
-- It is called Right Now, so it should appear when Paul taps "I'm on my way" and
-- be gone the moment he taps "All done, rolling out," not linger showing the next
-- stop. So: show ONLY a stop that is actively in progress (on_the_way / on_site /
-- in_service / returning) AND not yet wrapped (no departed_at stamped on its
-- visit, which is the real "I have left" signal, since All-done stamps departed
-- without always flipping the status). No stop in that window -> no card. The
-- earlier "else the next stop today" preview is dropped on purpose; it was handy
-- to preview but is not what Right Now means. No date filter: an in-progress stop
-- is the truth regardless of clock-edge date math.
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
    'dogs', v_dogs, 'other_dogs', v_other, 'total_price_cents', v_total
  );
end;
$$;
revoke all on function public.admin_now_card() from public, anon;
grant execute on function public.admin_now_card() to authenticated, service_role;
