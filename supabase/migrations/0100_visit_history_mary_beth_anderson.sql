-- 0100_visit_history_mary_beth_anderson.sql
-- Visit-history migration for Mary Beth Anderson / Toby (Shih Tzu) + Theo. Toby
-- runs 2022-present; Theo is new from Oct 2025 (he replaced Onyx, who died
-- 2025-06-20 and is not in the roster, so Onyx's lines are skipped; Benji was the
-- sister's visiting dog, also skipped). Score + note attached to the existing
-- time_is_money visit by date. Two sheet-date corrections per
-- time_is_money_is_source_of_truth: sheet "1/28/24" -> imported 2024-01-27, and
-- the sheet's "12/29/24" is a typo for 12/29/23 (its reverse-chron position and the
-- real DB date confirm it). Pre-import entries (before 2023-08-09) created as
-- source='contact_sheet'. See visit_history_migration.

-- ===== Toby: enrich existing visits =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-04-15'::date, 5, null),
  ('2026-02-17'::date, 5, null),
  ('2026-01-21'::date, 5, null),
  ('2025-12-22'::date, 5, null),
  ('2025-11-22'::date, 5, null),
  ('2025-10-29'::date, 5, null),
  ('2025-10-01'::date, 5, null),
  ('2025-07-09'::date, 5, null),
  ('2025-06-11'::date, 5, null),
  ('2025-05-12'::date, 5, null),
  ('2025-04-14'::date, 5, 'Touch-up. Both ears looked good this time; he did not have any lameness like he did a couple months ago.'),
  ('2025-03-17'::date, 5, 'Full groom. Right ear still a little bad. He did not do the thing he did last time where he had some kind of injury and wanted to sit constantly.'),
  ('2025-02-20'::date, 5, 'He just went to the vet. He has an issue with his back; he sits down every couple of steps while walking.'),
  ('2025-01-12'::date, 5, 'Full Groom. Ears look irritated and smelly. General irritation all over his body; skin looks red.'),
  ('2024-11-26'::date, 5, 'Full Groom. My clipper vacuum was broken.'),
  ('2024-10-18'::date, 5, null),
  ('2024-09-17'::date, 5, null),
  ('2024-08-19'::date, 5, null),
  ('2024-07-22'::date, 5, null),
  ('2024-06-24'::date, 3, null),
  ('2024-05-27'::date, 5, 'Full Groom. Very red pads of his feet; bad ears, maybe related to the same thing causing the bad feet.'),
  ('2024-04-29'::date, 4, null),
  ('2024-04-01'::date, 5, 'Full groom. One ear and pads of feet are red and irritated.'),
  ('2024-03-04'::date, 5, null),
  ('2024-01-27'::date, 5, 'Full Groom. The inside of one of Toby''s ears is red and irritated looking.'),
  ('2023-12-29'::date, 5, null),
  ('2023-12-01'::date, 5, null),
  ('2023-11-03'::date, 3, null),
  ('2023-10-06'::date, 3, null),
  ('2023-09-08'::date, 3, null),
  ('2023-08-09'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Mary Beth Anderson'
join public.dogs d on d.client_id = c.id and d.name = 'Toby'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Theo: enrich existing visits (new dog from Oct 2025) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-04-15'::date, 5, null),
  ('2026-02-17'::date, 4, null),
  ('2026-01-21'::date, 4, null),
  ('2025-12-22'::date, 4, null),
  ('2025-11-22'::date, 4, null),
  ('2025-10-29'::date, 4, null),
  ('2025-10-01'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name = 'Mary Beth Anderson'
join public.dogs d on d.client_id = c.id and d.name = 'Theo'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Toby pre-import orphans (before 2023-08-09) =====
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-07-11T12:00:00Z'::timestamptz, 'mba-2023-07-11'),
  ('2023-05-09T12:00:00Z'::timestamptz, 'mba-2023-05-09'),
  ('2023-02-15T12:00:00Z'::timestamptz, 'mba-2023-02-15'),
  ('2022-12-20T12:00:00Z'::timestamptz, 'mba-2022-12-20'),
  ('2022-11-22T12:00:00Z'::timestamptz, 'mba-2022-11-22'),
  ('2022-10-25T12:00:00Z'::timestamptz, 'mba-2022-10-25'),
  ('2022-09-27T12:00:00Z'::timestamptz, 'mba-2022-09-27'),
  ('2022-08-31T12:00:00Z'::timestamptz, 'mba-2022-08-31')
) as x(ts, ext)
join public.clients c on c.name = 'Mary Beth Anderson'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('mba-2023-07-11', 'Good.'),
  ('mba-2023-05-09', 'Full groom. Ok.'),
  ('mba-2023-02-15', 'Touch up. Last appointment was a long time ago; did a super tidy up.'),
  ('mba-2022-12-20', 'Full groom. Difficult.'),
  ('mba-2022-11-22', 'Touch up. Good dog.'),
  ('mba-2022-10-25', 'Full groom. Good.'),
  ('mba-2022-09-27', 'Touch up. Better this time. No urinating.'),
  ('mba-2022-08-31', 'Full groom. Urinating constantly. Uncooperative.')
) as x(ext, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Mary Beth Anderson'
join public.dogs d on d.client_id = c.id and d.name = 'Toby'
on conflict (visit_id, dog_id) do update set note = excluded.note;
