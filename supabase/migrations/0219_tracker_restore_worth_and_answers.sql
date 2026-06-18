-- 0219_tracker_restore_worth_and_answers.sql
--
-- Second casualty of rebuilding tracker_status from the stale 0182 file (after the
-- before-photo stage in 0218): the function also stopped returning `worth_a_look`
-- and `answer_photo_ids`, which the /track page reads (data.worth_a_look,
-- data.answer_photo_ids). So a photo Paul flagged "show the client" with a comment
-- still rendered as a plain Moment instead of flipping to a "worth a look" card
-- with the note (Paul, 2026-06-18 field), and the heard-and-delivered answer photos
-- lost their tag. These rode tracker_status since 0176/0172; restore both.
--
-- This rebuilds tracker_status COMPLETE: every field the /track page consumes
-- (found, stage, scheduled_start/end, first_name, dogs, special_request,
-- request_delivered, answer_photo_ids, worth_a_look, operator, photo_credits),
-- keeping the before-photo underway stage (0218) and the appointment dog_ids /
-- active-bath_dogs / legacy-roster filtering (0213).

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
  v_answer_ids jsonb;
  v_worth jsonb;
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

  -- Photos that answer the client's special request (the heard-and-delivered loop).
  select coalesce(jsonb_agg(p.id), '[]'::jsonb) into v_answer_ids
    from public.visit_photos p join public.visits vv on vv.id = p.visit_id
   where vv.appointment_id = a.id and p.answers_request and p.client_visible;

  -- "Worth a look" photos: Paul showed the client something, with his note and the
  -- photographer's first name. The /track page renders these as worth-a-look cards.
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'note', p.note, 'by', adm.first_name) order by p.created_at), '[]'::jsonb)
    into v_worth
    from public.visit_photos p join public.visits vv on vv.id = p.visit_id
    left join public.admins adm on adm.id = p.flagged_by
   where vv.appointment_id = a.id and p.worth_a_look and p.client_visible;

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
    'answer_photo_ids', v_answer_ids,
    'worth_a_look', v_worth,
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
