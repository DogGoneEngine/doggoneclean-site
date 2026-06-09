-- 0078_visit_scores_and_cleanup.sql
-- Two things from Paul reviewing the visit history:
--   1. Scrub the imported Acuity payment-status label out of the behavior-notes
--      field. The visit import wrote visit_notes='paid: Invoice' (and similar) on
--      hundreds of visits. That is the online-payment status ("billed, not paid
--      online"), not a note, and it reads as "paid by invoice" for everyone
--      whether they paid that way or not. The real method already lives in
--      visits.payment_method; the notes field is for observations only.
--   2. The 1-to-5 "vibe score" Paul gives every dog at every appointment: how the
--      dog was to work with. 1 = aggression or unsafe to groom (not eligible for
--      future service), 2 = poor/conditional, 3 = average, 4 = cooperative,
--      5 = a joy that anticipates him. One row per dog per visit.
-- See visit_notes_are_observations_only + vibe_score.

-- 1. Scrub the payment-status label (only when the note is nothing but that label).
update public.visits set visit_notes = null, updated_at = now()
 where visit_notes ~* '^paid:\s*[a-z0-9 ./_-]+$';

-- 2. Per-dog, per-visit score.
create table if not exists public.visit_dog_ratings (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  dog_id uuid references public.dogs(id) on delete set null,
  score int not null check (score between 1 and 5),
  created_at timestamptz not null default now(),
  unique (visit_id, dog_id)
);
create index if not exists visit_dog_ratings_visit_idx on public.visit_dog_ratings (visit_id);
create index if not exists visit_dog_ratings_dog_idx on public.visit_dog_ratings (dog_id, created_at desc);
alter table public.visit_dog_ratings enable row level security;

-- Upsert per-dog scores for a visit from [{"dog_id":"...","score":1-5}, ...].
create or replace function public._apply_visit_dog_scores(p_visit_id uuid, p_scores jsonb)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if p_scores is null then return; end if;
  insert into public.visit_dog_ratings (visit_id, dog_id, score)
  select p_visit_id, nullif(e->>'dog_id','')::uuid, (e->>'score')::int
    from jsonb_array_elements(p_scores) e
   where nullif(e->>'score','') is not null and (e->>'score')::int between 1 and 5
  on conflict (visit_id, dog_id) do update set score = excluded.score;
end $$;

-- Re-create the two visit writers with a trailing p_dog_scores arg (drop first so
-- there is no overload ambiguity for PostgREST).
drop function if exists public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text);
create or replace function public.admin_log_visit(
  p_client_id uuid default null,
  p_subscriber_id uuid default null,
  p_appointment_id uuid default null,
  p_visited_at timestamptz default now(),
  p_service_type text default null,
  p_dog_ids uuid[] default null,
  p_work_done text default null,
  p_visit_notes text default null,
  p_condition_flags text[] default null,
  p_actual_minutes integer default null,
  p_amount_collected_cents integer default null,
  p_tip_cents integer default null,
  p_payment_method text default null,
  p_source text default 'manual',
  p_dog_scores jsonb default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid; v_admin uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is null and p_subscriber_id is null then
    raise exception 'a visit needs a client or a subscriber';
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  insert into public.visits (
    client_id, subscriber_id, appointment_id, visited_at, service_type,
    dog_ids, work_done, visit_notes, condition_flags, actual_minutes,
    amount_collected_cents, tip_cents, payment_method, source, completed_by
  ) values (
    p_client_id, p_subscriber_id, p_appointment_id, coalesce(p_visited_at, now()), p_service_type,
    coalesce(p_dog_ids, '{}'), p_work_done, p_visit_notes, coalesce(p_condition_flags, '{}'), p_actual_minutes,
    p_amount_collected_cents, p_tip_cents, p_payment_method, coalesce(p_source, 'manual'), v_admin
  ) returning id into v_id;
  perform public._apply_visit_dog_scores(v_id, p_dog_scores);
  return v_id;
end;
$$;
revoke all on function public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text, jsonb) from public;
grant execute on function public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text, jsonb) to authenticated;

drop function if exists public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[]);
create or replace function public.admin_complete_appointment(
  p_appointment_id uuid,
  p_work_done text default null,
  p_visit_notes text default null,
  p_actual_minutes integer default null,
  p_amount_collected_cents integer default null,
  p_tip_cents integer default null,
  p_payment_method text default null,
  p_condition_flags text[] default null,
  p_dog_ids uuid[] default null,
  p_dog_scores jsonb default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid; v_admin uuid; v_sub uuid; v_client uuid; v_stype text; v_amt integer;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select subscriber_id, service_type, amount_cents into v_sub, v_stype, v_amt
    from public.bath_appointments where id = p_appointment_id;
  if not found then raise exception 'appointment not found'; end if;
  select client_id into v_client from public.bath_subscribers where id = v_sub;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  update public.bath_appointments
     set status = 'completed', duration_minutes = coalesce(p_actual_minutes, duration_minutes), updated_at = now()
   where id = p_appointment_id;
  insert into public.visits (
    client_id, subscriber_id, appointment_id, visited_at, service_type,
    dog_ids, work_done, visit_notes, condition_flags, actual_minutes,
    amount_collected_cents, tip_cents, payment_method, source, completed_by
  ) values (
    v_client, v_sub, p_appointment_id, now(), v_stype,
    coalesce(p_dog_ids, '{}'), p_work_done, p_visit_notes, coalesce(p_condition_flags, '{}'), p_actual_minutes,
    coalesce(p_amount_collected_cents, v_amt), p_tip_cents, p_payment_method, 'appointment', v_admin
  ) returning id into v_id;
  perform public._apply_visit_dog_scores(v_id, p_dog_scores);
  return v_id;
end;
$$;
revoke all on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[], jsonb) from public;
grant execute on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[], jsonb) to authenticated;

-- admin_get_client: return the per-dog scores alongside each visit.
create or replace function public.admin_get_client(p_client_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
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
        'dog_ratings', coalesce((
          select jsonb_agg(jsonb_build_object('dog_id', r.dog_id, 'name', d2.name, 'score', r.score) order by d2.name)
            from public.visit_dog_ratings r left join public.dogs d2 on d2.id = r.dog_id
           where r.visit_id = v.id), '[]'::jsonb)
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
  return result;
end;
$$;
revoke all on function public.admin_get_client(uuid) from public;
grant execute on function public.admin_get_client(uuid) to authenticated;
