-- 0124_visit_history_peter_moran.sql
-- Visit-history migration for Peter Moran / Buddy (Shih Tzu/Poodle mix, looks like a
-- Lhasa apso). A sparse, occasional client (only a few visits). Migrates Buddy's
-- scored entries; the undated "Buddy. 1. Uncooperative" sheet entry is the oldest on
-- the sheet and maps to his earliest imported visit (2023-08-23). The 10/13/25 visit
-- was logged with no score (an honest gap). See visit_history_migration +
-- time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-09'::date, 3, null),
  ('2023-08-23'::date, 1, 'Uncooperative. Took more than twice as long as it should have.')
) as x(d, score, note)
join public.clients c on c.name='Peter Moran'
join public.dogs d on d.client_id=c.id and d.name='Buddy'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;
