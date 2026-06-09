-- 0090_visit_history_migration_home.sql
-- Course correction: the prior import grabbed visit DATES and dollar amounts but
-- dropped the real history (per-dog scores and Paul's notes). Paul's intent was to
-- MIGRATE the old contact-sheet data, not abandon it. This prepares the home for
-- that history migration and proves it on one client.
--   1. visit_dog_ratings gets a per-dog `note` (the observation Paul wrote for that
--      dog that visit), and `score` becomes NULLABLE: the old pre-1-to-5 entries
--      recorded a word ("Ok", "good dog"), not a number, and those must migrate
--      faithfully as a note with no score rather than be forced to a made-up number.
--   2. admin_get_client returns the rating note so migrated history shows on the sheet.
--   3. Proof: Jane Henrich's recent visits enriched with Dory's real scores + notes
--      (keyed by name + date so it replays). The full per-client history migration
--      is the main remaining work. See visit_history_migration.

alter table public.visit_dog_ratings add column if not exists note text;
alter table public.visit_dog_ratings alter column score drop not null;
alter table public.visit_dog_ratings drop constraint if exists visit_dog_ratings_score_check;
alter table public.visit_dog_ratings add constraint visit_dog_ratings_score_check
  check (score is null or (score between 1 and 5));

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
          select jsonb_agg(jsonb_build_object('dog_id', r.dog_id, 'name', d2.name, 'score', r.score, 'note', r.note) order by d2.name)
            from public.visit_dog_ratings r left join public.dogs d2 on d2.id = r.dog_id
           where r.visit_id = v.id), '[]'::jsonb),
        'photos', coalesce((
          select jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'path', p.storage_path) order by p.created_at)
            from public.visit_photos p where p.visit_id = v.id), '[]'::jsonb)
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

-- Proof: Jane Henrich / Dory, enrich the visits whose dates match the sheet.
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2025-12-27'::date, 5, 'Able to stand a lot better this time.'),
  ('2025-05-14'::date, 5, 'She laid down 90% of the time. Did the best I could and she did the best she could to be helpful.'),
  ('2024-12-05'::date, 5, 'Very dirty and matted. Getting weak.'),
  ('2024-07-25'::date, 5, 'Very weak. Sweet. Cooperative. Lost a lot of weight and energy since last time.'),
  ('2024-01-14'::date, 5, 'Took over 4 hours.')
) as x(d, score, note)
join public.clients c on c.name = 'Jane Henrich'
join public.dogs d on d.client_id = c.id and d.name = 'Dory'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;
