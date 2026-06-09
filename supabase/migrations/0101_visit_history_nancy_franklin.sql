-- 0101_visit_history_nancy_franklin.sql
-- Visit-history migration for Nancy Franklin / Ben (Labrador). Nancy is a Saturday
-- nails-only client ($25, occasionally a $50 full); her newest contact sheet is a
-- near-empty template with exactly one scored visit recorded (4/5/25 Ben. 5). The
-- other ~35 imported visits are quick nail appointments that were never
-- individually scored, so they remain an honest data gap (real_data_only) rather
-- than invented numbers. See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2025-04-05'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name = 'Nancy Franklin'
join public.dogs d on d.client_id = c.id and d.name = 'Ben'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;
