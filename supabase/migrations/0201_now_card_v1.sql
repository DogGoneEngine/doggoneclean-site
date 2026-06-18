-- 0201: the operator "right now" card, v1 (Paul, 2026-06-18). Small and careful.
--
-- A focused card pinned above today's stops on the operator Today screen: just
-- what Paul needs in front of him for the stop he is on his way to / working,
-- everything else one tap into the record. Two moments: ARRIVING (how to get in,
-- who is at the door) then THE DOGS on this appointment (photo, name, breed, a
-- look-alike disambiguation line, standing instructions, a positive handling
-- note, the follow-up from last time, and the price so he can answer "how much
-- again?" at the door). All of it already lives in the schema except two short
-- per-dog fields this adds: appearance (tell look-alikes apart) and handling
-- (how to handle THIS dog, framed as reassurance, never a warning; muzzle dogs
-- are not eligible so that word never appears).
--
-- The card surfaces the in-progress stop, else the next not-yet-wrapped stop
-- today. Read-only payload; editing the new fields happens on the contact sheet.
--
-- Applied to dgc-prod 2026-06-18.

alter table public.dogs add column if not exists appearance text;
alter table public.dogs add column if not exists handling   text;

comment on column public.dogs.appearance is
  'Short tell-apart line for look-alike dogs in one household (e.g. "the brown one"). Shown only when set; doubles as friendly tracker copy.';
comment on column public.dogs.handling is
  'How to handle THIS dog: hold-this-way, hip/leg soreness, the reassuring "we have got this" note for the door. A care note, not a warning.';

create or replace function public.admin_set_dog_appearance(p_dog_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.dogs set appearance = nullif(btrim(p_text), ''), updated_at = now() where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_appearance(uuid, text) from public, anon;
grant execute on function public.admin_set_dog_appearance(uuid, text) to authenticated, service_role;

create or replace function public.admin_set_dog_handling(p_dog_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.dogs set handling = nullif(btrim(p_text), ''), updated_at = now() where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_handling(uuid, text) from public, anon;
grant execute on function public.admin_set_dog_handling(uuid, text) to authenticated, service_role;

-- The focus stop and everything to know for it.
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
  v_total int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  -- 1. A stop already in progress wins (the latest one, if more than one rolls).
  select * into a
    from public.bath_appointments x
   where (x.scheduled_start at time zone 'America/New_York')::date = v_today
     and x.status in ('on_the_way', 'on_site', 'in_service', 'returning')
   order by x.scheduled_start desc
   limit 1;

  -- 2. Otherwise the next not-yet-wrapped stop today, soonest first.
  if not found then
    select * into a
      from public.bath_appointments x
     where (x.scheduled_start at time zone 'America/New_York')::date = v_today
       and x.status in ('confirmed', 'requested', 'tentative')
     order by x.scheduled_start asc
     limit 1;
  end if;

  if not found then
    return jsonb_build_object('found', false);
  end if;

  select s.client_id into v_client
    from public.bath_subscribers s where s.id = a.subscriber_id;

  with dd as (
    select dg.*
      from public.dogs dg
     where (a.dog_ids is not null and array_length(a.dog_ids, 1) > 0 and dg.id = any(a.dog_ids))
        or ((a.dog_ids is null or array_length(a.dog_ids, 1) = 0)
            and dg.client_id = v_client
            and coalesce(dg.roster_status, 'regular') in ('regular', 'occasional'))
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', dd.id,
      'name', dd.name,
      'breed', dd.breed,
      'appearance', dd.appearance,
      'standing_instructions', dd.standing_instructions,
      'handling', dd.handling,
      'price_cents', dd.price_cents,
      'photo_path', (select vp.storage_path from public.visit_photos vp
                      where vp.dog_id = dd.id order by vp.created_at desc limit 1),
      'followups', coalesce((select jsonb_agg(f.body order by f.created_at desc)
                      from public.dog_followups f
                     where f.dog_id = dd.id and f.status = 'open'), '[]'::jsonb)
    ) order by dd.name), '[]'::jsonb),
    coalesce(sum(dd.price_cents)::int, 0)
  into v_dogs, v_total
  from dd;

  return jsonb_build_object(
    'found', true,
    'appointment_id', a.id,
    'client_id', v_client,
    'client', (select c.name from public.clients c where c.id = v_client),
    'status', a.status,
    'scheduled_start', a.scheduled_start,
    'service_type', a.service_type,
    'in_progress', a.status in ('on_the_way', 'on_site', 'in_service', 'returning'),
    'access_notes', (select c.access_notes from public.clients c where c.id = v_client),
    'onsite_people', (select c.onsite_people from public.clients c where c.id = v_client),
    'dogs', v_dogs,
    'total_price_cents', v_total
  );
end;
$$;
revoke all on function public.admin_now_card() from public, anon;
grant execute on function public.admin_now_card() to authenticated, service_role;
