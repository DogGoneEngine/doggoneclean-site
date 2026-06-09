-- 0092_visit_history_cynthia_tieche.sql
-- Visit-history migration for Cynthia Tieche (Satin + Luna). Per-dog vibe score
-- and note attached to the EXISTING time_is_money visit on that date (the join on
-- visited_at::date does the matching; a sheet date with no existing visit simply
-- enriches nothing). Pre-import entries (before the earliest imported visit,
-- 2023-08-10) are created as source='contact_sheet' so the early behavior history
-- is not lost. Stella (a guest dog that appears twice) is not in the roster and is
-- skipped. See visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Satin: enrich existing visits =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-02-17'::date, 5, null),
  ('2026-01-20'::date, 5, null),
  ('2026-01-06'::date, 5, null),
  ('2025-12-23'::date, 5, 'Skin looks irritated all over. She has a couple places with little knots where she has been chewing.'),
  ('2025-12-09'::date, 5, null),
  ('2025-11-25'::date, 5, null),
  ('2025-10-28'::date, 5, null),
  ('2025-09-30'::date, 5, null),
  ('2025-09-02'::date, 5, null),
  ('2025-08-19'::date, 5, null),
  ('2025-07-08'::date, 5, null),
  ('2025-06-24'::date, 5, null),
  ('2025-06-10'::date, 5, null),
  ('2025-05-27'::date, 5, null),
  ('2025-05-13'::date, 5, null),
  ('2025-04-29'::date, 5, null),
  ('2025-04-15'::date, 5, null),
  ('2025-04-01'::date, 5, null),
  ('2025-03-18'::date, 5, 'Bad spots on her skin where she has been chewing. I sent Cynthia the photo and she said she has been treating it.'),
  ('2025-03-04'::date, 5, null),
  ('2025-02-18'::date, 5, null),
  ('2025-02-04'::date, 5, null),
  ('2025-01-21'::date, 5, null),
  ('2025-01-07'::date, 5, null),
  ('2024-12-24'::date, 5, null),
  ('2024-12-10'::date, 5, null),
  ('2024-11-12'::date, 5, null),
  ('2024-10-29'::date, 5, null),
  ('2024-10-15'::date, 5, null),
  ('2024-10-01'::date, 5, null),
  ('2024-09-17'::date, 5, null),
  ('2024-08-06'::date, 5, null),
  ('2024-07-23'::date, 5, null),
  ('2024-07-09'::date, 5, null),
  ('2024-06-11'::date, 5, null),
  ('2024-05-28'::date, 5, null),
  ('2024-04-30'::date, 5, null),
  ('2024-04-16'::date, 5, null),
  ('2024-04-02'::date, 5, null),
  ('2024-03-19'::date, null, 'Not home.'),
  ('2024-03-05'::date, 5, null),
  ('2024-02-20'::date, 5, null),
  ('2024-01-09'::date, 4, null),
  ('2023-10-20'::date, 3, null),
  ('2023-09-07'::date, 4, null),
  ('2023-08-23'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name = 'Cynthia Tieche'
join public.dogs d on d.client_id = c.id and d.name = 'Satin'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Luna: enrich existing visits =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-02-17'::date, 5, 'Received a high dose of CBD right before the appointment and seemed extra mellow and just happy to be alive.'),
  ('2026-01-20'::date, 5, null),
  ('2026-01-06'::date, 5, null),
  ('2025-12-23'::date, 5, null),
  ('2025-12-09'::date, 5, null),
  ('2025-11-25'::date, 5, null),
  ('2025-11-11'::date, 5, null),
  ('2025-10-28'::date, 5, null),
  ('2025-09-30'::date, 5, null),
  ('2025-09-16'::date, 5, null),
  ('2025-09-02'::date, 5, null),
  ('2025-08-19'::date, 5, null),
  ('2025-07-22'::date, 5, null),
  ('2025-07-08'::date, 5, null),
  ('2025-06-24'::date, 5, null),
  ('2025-06-10'::date, 5, null),
  ('2025-05-27'::date, 5, null),
  ('2025-05-13'::date, 5, null),
  ('2025-04-29'::date, 5, null),
  ('2025-04-15'::date, 5, null),
  ('2025-04-01'::date, 5, null),
  ('2025-03-18'::date, 5, null),
  ('2025-03-04'::date, 5, null),
  ('2025-02-18'::date, 5, null),
  ('2025-02-04'::date, 5, null),
  ('2025-01-21'::date, 5, null),
  ('2025-01-07'::date, 5, null),
  ('2024-12-24'::date, 5, null),
  ('2024-12-10'::date, 5, null),
  ('2024-11-12'::date, 5, null),
  ('2024-10-29'::date, 5, null),
  ('2024-10-15'::date, 5, 'Took her at the same time as Satin. Even better than usual; she is extra calm when I take both of them together. Walk before grooming is not necessary; she is fine walking straight after the trailer now.'),
  ('2024-10-01'::date, 5, null),
  ('2024-09-17'::date, 5, null),
  ('2024-08-20'::date, 5, null),
  ('2024-08-06'::date, 5, null),
  ('2024-07-23'::date, 3, null),
  ('2024-07-09'::date, 4, null),
  ('2024-06-11'::date, 5, null),
  ('2024-05-14'::date, 5, null),
  ('2024-04-30'::date, 5, null),
  ('2024-04-16'::date, 5, null),
  ('2024-04-02'::date, 5, null),
  ('2024-03-19'::date, 5, null),
  ('2024-03-05'::date, 5, null),
  ('2024-02-20'::date, 5, null),
  ('2024-01-09'::date, 3, 'A solid 3. I wanted to give her a 4 but she was not quite there.'),
  ('2023-12-15'::date, 1, 'Made a very small aggressive move while I was filing her nails, so a 1 by default; if not for that, a 3.'),
  ('2023-11-04'::date, 1, null),
  ('2023-09-22'::date, 1, 'Threatens to bite. Non compliant.'),
  ('2023-09-07'::date, 1, 'Threatened multiple times to bite me while I dremeled her nails on both front legs.'),
  ('2023-08-23'::date, 3, 'Getting better.')
) as x(d, score, note)
join public.clients c on c.name = 'Cynthia Tieche'
join public.dogs d on d.client_id = c.id and d.name = 'Luna'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Pre-import orphans (before 2023-08-10): create contact_sheet visits =====
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-14T12:00:00Z'::timestamptz, 'cynthia-2023-06-14'),
  ('2023-05-30T12:00:00Z'::timestamptz, 'cynthia-2023-05-30'),
  ('2023-05-10T12:00:00Z'::timestamptz, 'cynthia-2023-05-10'),
  ('2023-03-28T12:00:00Z'::timestamptz, 'cynthia-2023-03-28'),
  ('2023-03-14T12:00:00Z'::timestamptz, 'cynthia-2023-03-14'),
  ('2023-03-02T12:00:00Z'::timestamptz, 'cynthia-2023-03-02'),
  ('2023-02-16T12:00:00Z'::timestamptz, 'cynthia-2023-02-16'),
  ('2023-01-19T12:00:00Z'::timestamptz, 'cynthia-2023-01-19'),
  ('2022-12-29T12:00:00Z'::timestamptz, 'cynthia-2022-12-29'),
  ('2022-11-22T12:00:00Z'::timestamptz, 'cynthia-2022-11-22'),
  ('2022-11-08T12:00:00Z'::timestamptz, 'cynthia-2022-11-08'),
  ('2022-10-11T12:00:00Z'::timestamptz, 'cynthia-2022-10-11')
) as x(ts, ext)
join public.clients c on c.name = 'Cynthia Tieche'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('cynthia-2023-06-14', 'Luna',  'Ok.'),
  ('cynthia-2023-05-30', 'Luna',  'Ok. Better than she has been in the past.'),
  ('cynthia-2023-05-10', 'Luna',  'A little better than usual.'),
  ('cynthia-2023-05-10', 'Satin', 'Good.'),
  ('cynthia-2023-03-28', 'Satin', 'Good.'),
  ('cynthia-2023-03-28', 'Luna',  'Difficult.'),
  ('cynthia-2023-03-14', 'Luna',  'Better than usual.'),
  ('cynthia-2023-03-14', 'Satin', 'Good dog. A lot of paint in her coat.'),
  ('cynthia-2023-03-02', 'Luna',  'Difficult.'),
  ('cynthia-2023-03-02', 'Satin', 'Ok.'),
  ('cynthia-2023-02-16', 'Satin', 'Skin irritated. Did not see fleas but it made me think of fleas.'),
  ('cynthia-2023-01-19', 'Luna',  'Uncooperative.'),
  ('cynthia-2023-01-19', 'Satin', 'Bald spot on her side. Small mats all over like she has been chewing on herself.'),
  ('cynthia-2022-12-29', 'Luna',  'Very difficult then was good.'),
  ('cynthia-2022-12-29', 'Satin', 'Good.'),
  ('cynthia-2022-11-22', 'Luna',  'Spot of goo on her back leg. Was not sure if it was a wound or something to scrub away; pretty sure it was just goo.'),
  ('cynthia-2022-11-22', 'Satin', 'Spots similar to what Luna had, but her fur is fluffy and I could tell it was not touching her skin. Washed away.'),
  ('cynthia-2022-11-08', 'Luna',  'Getting easier to work with.'),
  ('cynthia-2022-10-11', 'Luna',  'Has tantrums. Uncooperative.')
) as x(ext, dogname, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Cynthia Tieche'
join public.dogs d on d.client_id = c.id and d.name = x.dogname
on conflict (visit_id, dog_id) do update set note = excluded.note;
