-- 0173_photo_destinations.sql
-- A visit photo can go to three audiences, independently (photo_destinations):
--   Client  - the client's portal + tracker (existing client_visible).
--   Team    - an internal Orbit gallery for the whole crew (team_visible).
--   Website - the public marketing gallery, but ONLY through an approval queue.
--
-- The website is the dangerous one (public, hard to take back), so it is the
-- only destination an employee cannot reach alone (website_is_owner_approved):
-- anyone can SUGGEST a photo for the website (website_state -> 'queued'), but
-- only the owner role can APPROVE it (-> 'live'). Built as a role power, not a
-- person, so the privilege can be granted to someone else later without a
-- rewrite. The public gallery (the page that renders 'live' photos) is a
-- separate follow-on; this migration is the private, safe pipeline.

alter table public.visit_photos add column if not exists team_visible boolean not null default false;
alter table public.visit_photos add column if not exists website_state text not null default 'none'
  check (website_state in ('none', 'queued', 'live'));
alter table public.visit_photos add column if not exists website_proposed_by uuid references public.admins(id) on delete set null;
alter table public.visit_photos add column if not exists website_approved_by uuid references public.admins(id) on delete set null;
alter table public.visit_photos add column if not exists website_live_at timestamptz;

-- How many photos the public gallery holds; oldest live rolls off when exceeded.
-- Lives here so the page and the cap enforcement read one number.
create or replace function public._website_gallery_cap() returns int language sql immutable as $$ select 24 $$;

-- Team: any active admin can toggle a photo into or out of the internal gallery.
create or replace function public.admin_set_photo_team(p_id uuid, p_val boolean)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.visit_photos set team_visible = coalesce(p_val, false) where id = p_id;
  if not found then raise exception 'photo not found'; end if;
end;
$$;
revoke all on function public.admin_set_photo_team(uuid, boolean) from public, anon;
grant execute on function public.admin_set_photo_team(uuid, boolean) to authenticated, service_role;

-- Website suggest: any active admin can put a photo in the queue. Never goes
-- live here; it waits for the owner. No-op if already queued or live.
create or replace function public.admin_suggest_photo_website(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  update public.visit_photos
     set website_state = 'queued', website_proposed_by = v_me
   where id = p_id and website_state = 'none';
  if not found and not exists (select 1 from public.visit_photos where id = p_id) then
    raise exception 'photo not found';
  end if;
end;
$$;
revoke all on function public.admin_suggest_photo_website(uuid) from public, anon;
grant execute on function public.admin_suggest_photo_website(uuid) to authenticated, service_role;

-- Withdraw a suggestion (only while queued; live photos are owner-only to pull).
create or replace function public.admin_withdraw_photo_website(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.visit_photos
     set website_state = 'none', website_proposed_by = null
   where id = p_id and website_state = 'queued';
  if not found then raise exception 'not a queued photo'; end if;
end;
$$;
revoke all on function public.admin_withdraw_photo_website(uuid) from public, anon;
grant execute on function public.admin_withdraw_photo_website(uuid) to authenticated, service_role;

-- Approve to live: OWNER ROLE ONLY. Marks live, stamps approver + time, and
-- enforces the FIFO cap: once over the cap, the oldest live photos roll off
-- back to 'none'. Sharing to the website also shares to the client is NOT
-- implied; website is its own destination.
create or replace function public.admin_approve_photo_website(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; v_cap int;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  update public.visit_photos
     set website_state = 'live', website_approved_by = v_me, website_live_at = now()
   where id = p_id and website_state in ('queued', 'none');
  if not found then raise exception 'photo not found or already live'; end if;

  v_cap := public._website_gallery_cap();
  update public.visit_photos
     set website_state = 'none'
   where id in (
     select id from public.visit_photos
      where website_state = 'live'
      order by website_live_at desc nulls last
      offset v_cap);
end;
$$;
revoke all on function public.admin_approve_photo_website(uuid) from public, anon;
grant execute on function public.admin_approve_photo_website(uuid) to authenticated, service_role;

-- Pull a live (or queued) photo off the website. Owner only.
create or replace function public.admin_unpublish_photo_website(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  update public.visit_photos
     set website_state = 'none', website_live_at = null
   where id = p_id and website_state in ('live', 'queued');
  if not found then raise exception 'not on the website track'; end if;
end;
$$;
revoke all on function public.admin_unpublish_photo_website(uuid) from public, anon;
grant execute on function public.admin_unpublish_photo_website(uuid) to authenticated, service_role;

-- The internal Team gallery, for everyone who logs in (owner, employees,
-- stakeholders). Photo path + light context; Orbit signs the URLs.
create or replace function public.admin_team_gallery()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'path', p.storage_path, 'kind', p.kind,
      'dog_name', d.name, 'client', c.name,
      'visited_at', v.visited_at,
      'website_state', p.website_state, 'client_visible', p.client_visible
    ) order by p.created_at desc)
    from public.visit_photos p
    left join public.dogs d on d.id = p.dog_id
    left join public.visits v on v.id = p.visit_id
    left join public.clients c on c.id = v.client_id
   where p.team_visible), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_team_gallery() from public, anon;
grant execute on function public.admin_team_gallery() to authenticated, service_role;

-- The owner's website review surface: the queue waiting on approval, and the
-- photos currently live. Owner only.
create or replace function public.admin_website_review()
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare q jsonb; l jsonb;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'path', p.storage_path, 'kind', p.kind,
      'dog_name', d.name, 'client', c.name, 'visited_at', v.visited_at,
      'proposed_by', btrim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, ''))
    ) order by p.created_at desc), '[]'::jsonb) into q
    from public.visit_photos p
    left join public.dogs d on d.id = p.dog_id
    left join public.visits v on v.id = p.visit_id
    left join public.clients c on c.id = v.client_id
    left join public.admins a on a.id = p.website_proposed_by
   where p.website_state = 'queued';
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'path', p.storage_path, 'kind', p.kind,
      'dog_name', d.name, 'client', c.name, 'live_at', p.website_live_at
    ) order by p.website_live_at desc nulls last), '[]'::jsonb) into l
    from public.visit_photos p
    left join public.dogs d on d.id = p.dog_id
    left join public.visits v on v.id = p.visit_id
    left join public.clients c on c.id = v.client_id
   where p.website_state = 'live';
  return jsonb_build_object('queued', q, 'live', l, 'cap', public._website_gallery_cap());
end;
$$;
revoke all on function public.admin_website_review() from public, anon;
grant execute on function public.admin_website_review() to authenticated, service_role;

-- admin_get_client: carry team_visible + website_state on each photo so the
-- per-photo destination chips reflect live state. Otherwise unchanged from 0171.
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
