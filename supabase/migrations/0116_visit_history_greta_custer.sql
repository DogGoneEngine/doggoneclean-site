-- 0116_visit_history_greta_custer.sql
-- Visit-history migration for Greta Custer / Stella (Golden Doodle) + Penny (Standard
-- Poodle). Her current contact sheet was started fresh in Jan 2026 and only carries
-- two scored visits; the older 2023-2025 history is not on it (an honest gap, sparse
-- record / older doc not located, not invented). An undated "Noah" template entry and
-- a long-gone 2021 dog "Joey" are left alone for lack of a date. Score attached to the
-- existing time_is_money visit by date. See visit_history_migration +
-- time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-02'::date, 5, null),
  ('2025-12-04'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Greta Custer'
join public.dogs d on d.client_id=c.id and d.name='Stella'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-02'::date, 5, null),
  ('2025-12-04'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Greta Custer'
join public.dogs d on d.client_id=c.id and d.name='Penny'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;
