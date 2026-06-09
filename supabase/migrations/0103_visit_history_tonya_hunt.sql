-- 0103_visit_history_tonya_hunt.sql
-- Visit-history migration for Tonya Hunt's four dogs: Kai, Lydia, Koa (Australian
-- Shepherds) and Ruthie (Great Pyrenees). Tonya's sheet also logs a rotating cast
-- of relatives'/guest dogs (Andy, Charlie, Dash, Eula, Polly, Scrappy, Pebbles);
-- those are not her dogs and are skipped. Score + note attached to the existing
-- time_is_money visit by date (sheet 3/6/26 maps to the imported 2026-03-05).
-- Pre-June-2024 visits sit below the readable part of the sheet and are a known
-- gap. See visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Kai =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-05'::date, 5, null),
  ('2025-12-11'::date, 5, null),
  ('2025-11-13'::date, 5, null),
  ('2025-10-17'::date, 5, null),
  ('2025-09-17'::date, 5, null),
  ('2025-08-20'::date, 5, null),
  ('2025-07-21'::date, 5, null),
  ('2025-06-25'::date, 5, '22mm comb on body.'),
  ('2025-05-29'::date, 5, '22mm comb on body.'),
  ('2025-04-02'::date, 5, null),
  ('2025-02-05'::date, 5, null),
  ('2025-01-08'::date, 5, null),
  ('2024-11-27'::date, 5, null),
  ('2024-10-30'::date, 5, null),
  ('2024-10-02'::date, 4, null),
  ('2024-09-04'::date, 5, 'Left ear and back left toe looked bad. I told Tonya; she already knew about it.'),
  ('2024-08-07'::date, 5, null),
  ('2024-07-10'::date, 3, null),
  ('2024-06-07'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Kai'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Lydia =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-05'::date, 5, null),
  ('2025-12-11'::date, 5, null),
  ('2025-11-13'::date, 5, null),
  ('2025-10-17'::date, 5, null),
  ('2025-09-17'::date, 5, null),
  ('2025-08-20'::date, 5, 'Had rolled in horse manure. One bath to get the manure out, a second for good measure; after grooming her a while I noticed it still smelled, so I washed her again with the skunk kit. Got the smell out to where you can only smell it with your nose against her neck, not from across the room like before.'),
  ('2025-07-21'::date, 4, null),
  ('2025-06-25'::date, 5, '22mm comb on body.'),
  ('2025-05-29'::date, 5, '22mm comb on body.'),
  ('2025-04-02'::date, 5, null),
  ('2025-02-05'::date, 5, null),
  ('2025-01-08'::date, 5, null),
  ('2024-11-27'::date, 5, null),
  ('2024-10-30'::date, 5, null),
  ('2024-10-02'::date, 3, null),
  ('2024-09-04'::date, 4, null),
  ('2024-08-07'::date, 4, null),
  ('2024-07-10'::date, 4, null),
  ('2024-06-07'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Lydia'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Koa =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2025-12-11'::date, 5, null),
  ('2025-08-20'::date, 5, null),
  ('2025-04-02'::date, 5, null),
  ('2025-02-05'::date, 5, null),
  ('2025-01-08'::date, 5, null),
  ('2024-12-04'::date, 2, 'Mostly ok. Gets a little squirrelly when you handle her legs or feet.'),
  ('2024-08-07'::date, 2, null),
  ('2024-07-10'::date, 2, 'Good a lot of the time but frequently uncooperative, so it had to be a 2.')
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Koa'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Ruthie =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-05'::date, 5, null),
  ('2025-10-17'::date, 5, null),
  ('2025-06-25'::date, 5, null),
  ('2024-09-04'::date, 2, 'A 2 for the bath; a 5 after that.'),
  ('2024-06-07'::date, 2, 'Real bad in the bath tub. Decent with everything else.')
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Ruthie'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;
