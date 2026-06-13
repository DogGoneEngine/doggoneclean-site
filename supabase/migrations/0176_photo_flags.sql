-- 0176_photo_flags.sql
-- Two "look at this" flags on a visit photo, each a photo + a short note:
--   Worth a look (worth_a_look_for_client): the operator shows the CLIENT
--     something they would not normally see (skin under the lifted coat, inside
--     the ears). Auto-shares to the client; renders on the tracker as a calm
--     "From <operator>" card with a fixed, non-medical framing. Not advice.
--     Its note (visit_photos.note) is client-facing.
--   From the field (field_flag): the operator shows the OWNER something (a lump,
--     odd behavior, an equipment issue). Lands on the owner's Today feed; the
--     owner marks it seen. Its note (visit_photos.field_note) is owner-private
--     and is kept in a SEPARATE column so a photo flagged both ways can never
--     leak the owner note to the client. Photo now; video parked.

alter table public.visit_photos add column if not exists note text;
alter table public.visit_photos add column if not exists field_note text;
alter table public.visit_photos add column if not exists worth_a_look boolean not null default false;
alter table public.visit_photos add column if not exists field_flag boolean not null default false;
alter table public.visit_photos add column if not exists field_seen_at timestamptz;
alter table public.visit_photos add column if not exists flagged_by uuid references public.admins(id) on delete set null;

-- Worth a look: any operator. Turning it on auto-shares to the client (the point
-- is they see it) and stamps who flagged it (the tracker byline).
create or replace function public.admin_set_worth_a_look(p_id uuid, p_on boolean, p_note text default null)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  if coalesce(p_on, false) then
    update public.visit_photos
       set worth_a_look = true, note = nullif(btrim(coalesce(p_note, '')), ''),
           flagged_by = v_me, client_visible = true
     where id = p_id;
  else
    update public.visit_photos set worth_a_look = false where id = p_id;
  end if;
  if not found then raise exception 'photo not found'; end if;
end;
$$;
revoke all on function public.admin_set_worth_a_look(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_worth_a_look(uuid, boolean, text) to authenticated, service_role;

-- From the field: any operator flags a photo to the owner with an owner-private
-- note. Resets seen so it surfaces as new on the owner's Today.
create or replace function public.admin_flag_for_owner(p_id uuid, p_note text default null)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  update public.visit_photos
     set field_flag = true, field_note = nullif(btrim(coalesce(p_note, '')), ''),
         flagged_by = v_me, field_seen_at = null
   where id = p_id;
  if not found then raise exception 'photo not found'; end if;
end;
$$;
revoke all on function public.admin_flag_for_owner(uuid, text) from public, anon;
grant execute on function public.admin_flag_for_owner(uuid, text) to authenticated, service_role;

-- The owner clears a field flag by marking it seen. Owner only (it is the
-- owner's inbox).
create or replace function public.admin_mark_field_seen(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  update public.visit_photos set field_seen_at = now() where id = p_id and field_flag;
  if not found then raise exception 'not a field flag'; end if;
end;
$$;
revoke all on function public.admin_mark_field_seen(uuid) from public, anon;
grant execute on function public.admin_mark_field_seen(uuid) to authenticated, service_role;

-- The owner's "From the field" feed: unseen first, then recently seen. Owner
-- only. Photo path + the owner-private note + who flagged + client/dog.
create or replace function public.admin_field_flags()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'path', p.storage_path, 'note', p.field_note,
      'by', btrim(coalesce(adm.first_name, '') || ' ' || coalesce(adm.last_name, '')),
      'client', c.name, 'dog_name', d.name,
      'client_id', v.client_id, 'visited_at', v.visited_at,
      'seen', (p.field_seen_at is not null)
    ) order by (p.field_seen_at is null) desc, p.created_at desc)
    from public.visit_photos p
    left join public.admins adm on adm.id = p.flagged_by
    left join public.visits v on v.id = p.visit_id
    left join public.clients c on c.id = v.client_id
    left join public.dogs d on d.id = p.dog_id
   where p.field_flag
     and (p.field_seen_at is null or p.field_seen_at > now() - interval '7 days')), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_field_flags() from public, anon;
grant execute on function public.admin_field_flags() to authenticated, service_role;

-- tracker_status: also return the worth-a-look items for this appointment
-- (photo id + the client-facing note + the operator's first name for the byline).
-- The page matches ids to the photo URLs it already gets from tracker-photos.
CREATE OR REPLACE FUNCTION public.tracker_status(p_token text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  a public.bath_appointments%rowtype; v public.visits%rowtype;
  v_first text; v_dogs jsonb; v_stage text; v_answer_ids jsonb; v_worth jsonb;
begin
  if p_token is null or length(p_token) < 16 then return jsonb_build_object('found', false); end if;
  select * into a from public.bath_appointments where tracker_token = p_token;
  if not found then return jsonb_build_object('found', false); end if;
  if a.scheduled_end is not null and now() > a.scheduled_end + interval '7 days' then
    return jsonb_build_object('found', true, 'stage', 'expired'); end if;
  select * into v from public.visits where appointment_id = a.id order by created_at desc limit 1;
  select s.first_name into v_first from public.bath_subscribers s where s.id = a.subscriber_id;
  select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
    from public.bath_dogs d where d.subscriber_id = a.subscriber_id;
  select coalesce(jsonb_agg(p.id), '[]'::jsonb) into v_answer_ids
    from public.visit_photos p join public.visits vv on vv.id = p.visit_id
   where vv.appointment_id = a.id and p.answers_request and p.client_visible;
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'note', p.note, 'by', adm.first_name) order by p.created_at), '[]'::jsonb)
    into v_worth
    from public.visit_photos p join public.visits vv on vv.id = p.visit_id
    left join public.admins adm on adm.id = p.flagged_by
   where vv.appointment_id = a.id and p.worth_a_look and p.client_visible;
  v_stage := case
    when a.status in ('cancelled', 'no_show', 'skipped') then 'inactive'
    when a.status = 'completed' or v.departed_at is not null then 'done'
    when a.status = 'returning' then 'returning'
    when a.status = 'in_service' then 'underway'
    when a.status = 'on_site' or v.arrived_at is not null then
      case when v.arrived_at is not null and v.arrived_at <= now() - interval '10 minutes' then 'underway' else 'arrived' end
    when a.status = 'on_the_way' or v.inbound_at is not null then 'on_the_way'
    else 'scheduled'
  end;
  return jsonb_build_object(
    'found', true, 'stage', v_stage,
    'scheduled_start', a.scheduled_start, 'scheduled_end', a.scheduled_end,
    'first_name', v_first, 'dogs', v_dogs,
    'special_request', v.special_request,
    'request_delivered', (v_stage in ('done', 'returning')),
    'answer_photo_ids', v_answer_ids,
    'worth_a_look', v_worth
  );
end;
$function$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;

-- admin_get_client: carry the photo flags + both notes so the per-photo controls
-- reflect live state (note = client-facing worth-a-look; field_note = owner-only).
CREATE OR REPLACE FUNCTION public.admin_get_client(p_client_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'client', to_jsonb(c.*),
    'dogs', coalesce((select jsonb_agg(to_jsonb(d.*) order by d.name) from public.dogs d where d.client_id = c.id), '[]'::jsonb),
    'subscriber', (select to_jsonb(s.*) from public.bath_subscribers s where s.client_id = c.id limit 1),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'visited_at', v.visited_at, 'service_type', v.service_type,
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
        'service_type', a.service_type, 'amount_cents', a.amount_cents
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
