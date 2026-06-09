-- 0094_visit_history_barbara_lape.sql
-- Visit-history migration for Barbara Lape / Manning (Lab/Pit mix). Single dog,
-- q3wk, arc from word grades and 3s/4s in 2023 to a steady 5. Score + note
-- attached to the existing time_is_money visit by date; the sheet's "1/6/25" is a
-- typo for 2026-01-06 (its position and the real DB date confirm it). Pre-import
-- entries (before 2023-08-09) created as source='contact_sheet'. Blank-score
-- entries are skipped. See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-31'::date, 5, null),
  ('2026-02-21'::date, 5, null),
  ('2026-01-23'::date, 5, null),
  ('2026-01-06'::date, 5, null),
  ('2025-12-12'::date, 5, null),
  ('2025-11-21'::date, 5, null),
  ('2025-10-13'::date, 5, null),
  ('2025-09-05'::date, 5, null),
  ('2025-08-22'::date, 5, 'Feet still red. Skimmed very lightly to shave his pads.'),
  ('2025-07-11'::date, 5, null),
  ('2025-06-13'::date, 5, null),
  ('2025-05-26'::date, 5, null),
  ('2025-05-12'::date, 5, 'He got a rabies shot this morning.'),
  ('2025-04-18'::date, 5, null),
  ('2025-02-27'::date, 5, null),
  ('2025-02-07'::date, 5, null),
  ('2025-01-13'::date, 5, 'Used prescription shampoo from her vet in the bath. Manning looks more shiny and healthy than usual. He also has a new diet.'),
  ('2024-12-16'::date, 5, null),
  ('2024-11-25'::date, 5, null),
  ('2024-10-07'::date, 5, null),
  ('2024-09-20'::date, 4, null),
  ('2024-08-22'::date, 5, null),
  ('2024-07-29'::date, 5, null),
  ('2024-06-21'::date, 4, null),
  ('2024-04-05'::date, 4, null),
  ('2024-03-06'::date, 5, null),
  ('2024-02-09'::date, 5, null),
  ('2023-12-11'::date, 4, null),
  ('2023-11-01'::date, 3, null),
  ('2023-10-04'::date, 4, null),
  ('2023-09-06'::date, 4, null),
  ('2023-08-09'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name = 'Barbara Lape'
join public.dogs d on d.client_id = c.id and d.name = 'Manning'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Pre-import orphans (before 2023-08-09)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-13T12:00:00Z'::timestamptz, 'barbara-2023-06-13'),
  ('2023-05-18T12:00:00Z'::timestamptz, 'barbara-2023-05-18'),
  ('2023-05-04T12:00:00Z'::timestamptz, 'barbara-2023-05-04'),
  ('2023-01-26T12:00:00Z'::timestamptz, 'barbara-2023-01-26'),
  ('2022-12-15T12:00:00Z'::timestamptz, 'barbara-2022-12-15'),
  ('2022-05-12T12:00:00Z'::timestamptz, 'barbara-2022-05-12')
) as x(ts, ext)
join public.clients c on c.name = 'Barbara Lape'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('barbara-2023-06-13', 'Great dog. Feet red and irritated. Shaved pads gently.'),
  ('barbara-2023-05-18', 'Great dog.'),
  ('barbara-2023-05-04', 'Good.'),
  ('barbara-2023-01-26', 'Barbara asked about shampoo because Manning is itchy. He has raw feet and ear problems; the vet has given Prednisone shots before, and he is on a special diet for itching. I told her if she gives me her own shampoo I can use it, but I do not have any shampoo that solves itching problems.'),
  ('barbara-2022-12-15', 'Good dog.'),
  ('barbara-2022-05-12', 'Recently treated for ear problems. Feet are red and raw looking. Shaved pads very gently.')
) as x(ext, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Barbara Lape'
join public.dogs d on d.client_id = c.id and d.name = 'Manning'
on conflict (visit_id, dog_id) do update set note = excluded.note;
