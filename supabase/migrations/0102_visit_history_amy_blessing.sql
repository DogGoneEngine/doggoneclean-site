-- 0102_visit_history_amy_blessing.sql
-- Visit-history migration for Amy Blessing / Maverick + Pax (both Australian
-- Shepherds), q4wk, both consistently 5s. Score + note attached to the existing
-- time_is_money visit by date. Pax carries the health thread (cyst/cone, the food
-- change that cleared his skin, the mystery smell). A small tail is a known gap:
-- Maverick's 10/5/23 score and the 8/25/23 visit sit below the readable part of the
-- sheet. See visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Maverick =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-04-01'::date, 5, null),
  ('2026-03-04'::date, 5, null),
  ('2026-02-04'::date, 5, null),
  ('2026-01-07'::date, 5, null),
  ('2025-12-10'::date, 5, null),
  ('2025-11-12'::date, 5, 'A tiny bit flaky; I think it is a lot better than last time.'),
  ('2025-10-15'::date, 5, null),
  ('2025-09-18'::date, 5, null),
  ('2025-08-21'::date, 5, null),
  ('2025-06-26'::date, 5, null),
  ('2025-04-30'::date, 5, null),
  ('2025-04-01'::date, 5, null),
  ('2025-03-05'::date, 5, null),
  ('2025-02-03'::date, 5, null),
  ('2025-01-06'::date, 5, null),
  ('2024-12-06'::date, 5, null),
  ('2024-11-04'::date, 5, 'Irritated spot on his foot visible when drying; maybe all of his feet but one in particular has a particularly visible spot.'),
  ('2024-09-19'::date, 5, null),
  ('2024-07-24'::date, 5, null),
  ('2024-06-12'::date, 5, null),
  ('2024-05-01'::date, 5, null),
  ('2024-03-20'::date, 5, null),
  ('2024-02-07'::date, 5, null),
  ('2023-12-29'::date, 5, null),
  ('2023-11-17'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name = 'Amy Blessing'
join public.dogs d on d.client_id = c.id and d.name = 'Maverick'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Pax =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-04-01'::date, 5, null),
  ('2026-03-04'::date, 5, null),
  ('2026-02-04'::date, 5, null),
  ('2026-01-07'::date, 5, 'Skin is better, not fiery red especially on the feet. The weird shell he has always had is either gone or almost gone. Amy switched to Loyal Life dog food after last month''s appointment.'),
  ('2025-12-10'::date, 5, null),
  ('2025-11-12'::date, 5, 'Just had a cyst removed from his back left leg; I was careful around the area.'),
  ('2025-10-15'::date, 5, 'Been wearing a cone because he had a cyst on his back leg.'),
  ('2025-09-18'::date, 5, null),
  ('2025-08-21'::date, 5, null),
  ('2025-06-26'::date, 5, null),
  ('2025-04-30'::date, 5, null),
  ('2025-04-01'::date, 5, null),
  ('2025-03-05'::date, 5, null),
  ('2025-02-03'::date, 5, null),
  ('2025-01-06'::date, 5, 'Left eye is squinty and pink and swollen looking around the eyelids.'),
  ('2024-12-06'::date, 5, null),
  ('2024-11-04'::date, 5, 'Amy said last time Pax had a rash on his privates a few days after the grooming and needed antibiotics, and asked if I used a different shampoo. Pax still has the mysterious smell before and after the bath and some parts of his skin might look irritated, but it is hard to tell because of his heavy coat.'),
  ('2024-09-19'::date, 5, null),
  ('2024-07-24'::date, 5, null),
  ('2024-06-12'::date, 5, 'Boo boo on his back.'),
  ('2024-05-01'::date, 5, null),
  ('2024-03-20'::date, 5, null),
  ('2024-02-07'::date, 5, 'Possibly a weird smell; next time smell him first to see if it is there.'),
  ('2023-12-29'::date, 5, null),
  ('2023-11-17'::date, 5, null),
  ('2023-10-05'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name = 'Amy Blessing'
join public.dogs d on d.client_id = c.id and d.name = 'Pax'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;
