-- 0093_visit_history_lisa_irwin_mia.sql
-- Visit-history migration for Lisa Irwin / Mia (Miniature Schnauzer). Lisa's
-- contact sheet is filed under her account name "Lisa Midgett"; current dog Mia
-- runs biweekly, almost all 5s. Per-dog score + note attached to the existing
-- time_is_money visit by date. Two items deliberately LEFT for Paul rather than
-- guessed (real_data_only): (1) the second DB dog "Tao" is never broken out by
-- name on the sheet, so Tao's per-visit history is not migrated here; (2) the
-- "Lisa Irwin" vs "Lisa Midgett" name split. The deceased dogs on the sheet
-- (Mick, Scout, Stella) are not in the roster and are skipped. Aug-Nov 2023 Mia
-- entries below the snippet horizon are a known small gap. See
-- visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-31'::date, 5, null),
  ('2026-02-17'::date, 5, null),
  ('2026-02-03'::date, 5, null),
  ('2026-01-20'::date, 5, 'First time grooming Mia at Lisa''s office.'),
  ('2026-01-06'::date, 5, null),
  ('2025-12-23'::date, 5, null),
  ('2025-11-24'::date, 5, null),
  ('2025-11-11'::date, 5, null),
  ('2025-10-28'::date, 5, null),
  ('2025-10-14'::date, 5, null),
  ('2025-09-30'::date, 5, null),
  ('2025-09-16'::date, 5, null),
  ('2025-09-02'::date, 5, null),
  ('2025-08-19'::date, 5, null),
  ('2025-07-08'::date, 5, null),
  ('2025-06-10'::date, 5, 'Used 6mm comb on body again. Maybe this is the new summer length?'),
  ('2025-05-27'::date, 5, 'Lisa asked about clipping shorter; used 6mm comb on body. Her ears might need medical attention; ask next time if they still look irritated.'),
  ('2025-05-13'::date, 5, null),
  ('2025-04-15'::date, 5, null),
  ('2025-04-01'::date, 5, 'Very tangled.'),
  ('2025-03-04'::date, 5, null),
  ('2025-02-04'::date, 5, null),
  ('2025-01-21'::date, 5, null),
  ('2025-01-07'::date, 5, null),
  ('2024-12-10'::date, 5, null),
  ('2024-10-15'::date, 5, null),
  ('2024-09-17'::date, 5, 'Does not want to stand on her back legs. Belly appears bloated on the sides.'),
  ('2024-08-20'::date, 5, null),
  ('2024-07-09'::date, 5, null),
  ('2024-04-16'::date, 5, null),
  ('2023-12-26'::date, 5, null),
  ('2023-12-12'::date, 4, 'Not so dirty this time. Maybe smelly.'),
  ('2023-11-28'::date, 4, 'Very dirty and smelly. Maybe fleas. Red bumps on her belly.')
) as x(d, score, note)
join public.clients c on c.name = 'Lisa Irwin'
join public.dogs d on d.client_id = c.id and d.name = 'Mia'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;
