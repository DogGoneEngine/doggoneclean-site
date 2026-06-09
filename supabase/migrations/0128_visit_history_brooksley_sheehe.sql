-- 0128_visit_history_brooksley_sheehe.sql
-- Visit-history migration for Brooksley Sheehe / Arya (Husky), Wesson (Akbash/
-- Anatolian Shepherd), Roxie (Great Pyrenees). Roxie's aging and skin-irritation arc
-- is preserved, as is the time Wesson killed a coyote and got covered in brambles.
-- Score + note attached to the existing time_is_money visit by date; the imported
-- history starts 2024-06-06, so the 2021-2023 entries are source='contact_sheet'.
-- See visit_history_migration + time_is_money_is_source_of_truth.

-- Arya
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-24'::date, 5, null),
  ('2025-12-13'::date, 5, null),
  ('2025-11-01'::date, 5, 'Heavy shedding.'),
  ('2025-09-15'::date, 5, null),
  ('2025-05-24'::date, 5, null),
  ('2025-03-22'::date, 5, null),
  ('2025-02-08'::date, 5, null),
  ('2024-12-22'::date, 5, null),
  ('2024-11-16'::date, 5, null),
  ('2024-10-05'::date, 2, null),
  ('2024-08-24'::date, 5, null),
  ('2024-07-13'::date, 5, null),
  ('2024-06-06'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Brooksley Sheehe'
join public.dogs d on d.client_id=c.id and d.name='Arya'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Wesson
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-24'::date, 5, 'His back right foot, leg, or hip is bothering him.'),
  ('2025-12-13'::date, 5, 'Ridiculously cooperative.'),
  ('2025-11-01'::date, 5, null),
  ('2025-09-15'::date, 5, null),
  ('2025-05-24'::date, 5, null),
  ('2025-03-22'::date, 5, null),
  ('2025-02-08'::date, 5, null),
  ('2024-12-22'::date, 5, null),
  ('2024-11-16'::date, 5, 'Very dirty. Ears extra dirty looking.'),
  ('2024-10-05'::date, 2, null),
  ('2024-08-24'::date, 5, null),
  ('2024-07-13'::date, 5, null),
  ('2024-06-06'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Brooksley Sheehe'
join public.dogs d on d.client_id=c.id and d.name='Wesson'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Roxie
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-24'::date, 5, null),
  ('2025-12-13'::date, 5, null),
  ('2025-11-01'::date, 5, 'Lots of tangles and matting and shedding.'),
  ('2025-09-15'::date, 5, null),
  ('2025-05-24'::date, 3, 'Getting old. Having trouble standing and cooperating.'),
  ('2025-03-22'::date, 5, null),
  ('2025-02-08'::date, 5, 'Had trouble standing for extended periods. Wants to sit.'),
  ('2024-12-22'::date, 5, 'Skin still irritated all over.'),
  ('2024-11-16'::date, 5, 'Skin very red and flaky.'),
  ('2024-10-05'::date, 5, null),
  ('2024-08-24'::date, 5, null),
  ('2024-07-13'::date, 2, null),
  ('2024-06-06'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Brooksley Sheehe'
join public.dogs d on d.client_id=c.id and d.name='Roxie'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2024-06-06), back to 2021
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-05-17T12:00:00Z'::timestamptz, 'brooksley-2023-05-17'),
  ('2023-01-23T12:00:00Z'::timestamptz, 'brooksley-2023-01-23'),
  ('2022-11-18T12:00:00Z'::timestamptz, 'brooksley-2022-11-18'),
  ('2022-10-20T12:00:00Z'::timestamptz, 'brooksley-2022-10-20'),
  ('2022-09-02T12:00:00Z'::timestamptz, 'brooksley-2022-09-02'),
  ('2022-04-29T12:00:00Z'::timestamptz, 'brooksley-2022-04-29'),
  ('2021-09-10T12:00:00Z'::timestamptz, 'brooksley-2021-09-10')
) as x(ts, ext)
join public.clients c on c.name='Brooksley Sheehe'
on conflict (source, external_id) where external_id is not null do nothing;

update public.visits set visit_notes='Wesson killed a coyote and got himself covered in brambles. Brooksley asked me this morning if I could groom him, so I added him to the end of my day.'
where source='contact_sheet' and external_id='brooksley-2022-10-20';

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('brooksley-2023-05-17', 'Wesson', 'Great dog. Lots of work.'),
  ('brooksley-2023-05-17', 'Arya',   'Ok.'),
  ('brooksley-2023-05-17', 'Roxie',  'Ok. Lots of work.'),
  ('brooksley-2023-01-23', 'Roxie',  'Good dog. A lot of labor; she was patient.'),
  ('brooksley-2023-01-23', 'Arya',   'Good. Lots of shedding.'),
  ('brooksley-2023-01-23', 'Wesson', 'Took a long time. Good dog.'),
  ('brooksley-2022-11-18', 'Arya',   'Difficult.'),
  ('brooksley-2022-10-20', 'Wesson', 'Groomed at the end of the day after he killed a coyote and got covered in brambles.'),
  ('brooksley-2022-09-02', 'Roxie',  'Lots of ticks. Growth on the underside of her chest.'),
  ('brooksley-2022-04-29', 'Roxie',  'Lots of labor. Charged $125 this time; she was more work than Wesson.'),
  ('brooksley-2021-09-10', 'Arya',   'Would not hold still for the Dremel; used nail clippers.'),
  ('brooksley-2021-09-10', 'Wesson', 'Had a tick, I removed it. Brooksley''s mom said they have been finding ticks on him.'),
  ('brooksley-2021-09-10', 'Roxie',  'Brooksley brought prescription shampoo for her; her skin looks quite irritated.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Brooksley Sheehe'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
