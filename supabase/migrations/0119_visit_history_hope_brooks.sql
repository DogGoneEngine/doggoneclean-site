-- 0119_visit_history_hope_brooks.sql
-- Visit-history migration for Hope Brooks / Shelby (Toy Australian Shepherd). Single
-- dog, mostly 5s with recurring heavy-shedding episodes. Score + note attached to the
-- existing time_is_money visit by date; the sheet's "3/6/25" maps to the imported
-- 2025-03-08. Pre-import entries (before 2023-10-18) are source='contact_sheet'. See
-- visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-05-16'::date, 5, 'Had a dog visiting. She was out of sorts in the house, but grooming was an escape from the chaos and back to a familiar routine.'),
  ('2026-03-21'::date, 5, null),
  ('2026-01-24'::date, 5, 'Heavy shedding. I was nearly finished after only 20 minutes and the rest of the time was spent combing all the shedding hair out.'),
  ('2025-12-13'::date, 2, 'Uncooperative. Heavy shedding.'),
  ('2025-10-18'::date, 5, null),
  ('2025-09-06'::date, 5, null),
  ('2025-03-08'::date, 5, null),
  ('2024-12-23'::date, 5, 'Hope asked me to trim the feathers on Shelby''s back legs.'),
  ('2024-11-01'::date, 5, null),
  ('2024-09-07'::date, 5, null),
  ('2024-07-27'::date, 3, 'Been a long time since she was groomed. Shedding profusely.'),
  ('2024-03-29'::date, 4, null),
  ('2023-10-18'::date, 2, null)
) as x(d, score, note)
join public.clients c on c.name='Hope Brooks'
join public.dogs d on d.client_id=c.id and d.name='Shelby'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-10-18)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-28T12:00:00Z'::timestamptz, 'hope-2023-06-28'),
  ('2023-03-23T12:00:00Z'::timestamptz, 'hope-2023-03-23'),
  ('2023-01-11T12:00:00Z'::timestamptz, 'hope-2023-01-11'),
  ('2022-09-29T12:00:00Z'::timestamptz, 'hope-2022-09-29')
) as x(ts, ext)
join public.clients c on c.name='Hope Brooks'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('hope-2023-06-28', 'A little bit uncooperative. Ok.'),
  ('hope-2023-03-23', 'A bit uncooperative but ok.'),
  ('hope-2023-01-11', 'Good. Extra long nails.'),
  ('hope-2022-09-29', 'Started out okay but became uncooperative.')
) as x(ext, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Hope Brooks'
join public.dogs d on d.client_id=c.id and d.name='Shelby'
on conflict (visit_id, dog_id) do update set note=excluded.note;
