-- 0098_visit_history_harriet_woolf.sql
-- Visit-history migration for Harriet Woolf / Beanie (Poodle mix). Single dog,
-- q4wk, consistently a 5. Score + note attached to the existing time_is_money
-- visit by date; pre-import entries (before 2023-08-11) created as
-- source='contact_sheet'. The sheet has a duplicate 12/1/23 entry (one detailed,
-- one bare); the detailed note is kept. See visit_history_migration +
-- time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-04'::date, 5, null),
  ('2026-02-04'::date, 5, null),
  ('2026-01-07'::date, 5, null),
  ('2025-12-10'::date, 5, 'She thought I put perfume on him last time that gave him bumps on his back. Told her I do not use any perfumes and my shampoo is mild; I will check with her about how he did this time.'),
  ('2025-11-12'::date, 5, null),
  ('2025-10-15'::date, 5, null),
  ('2025-09-18'::date, 5, null),
  ('2025-08-21'::date, 5, null),
  ('2025-06-27'::date, 5, null),
  ('2025-05-28'::date, 5, null),
  ('2025-04-30'::date, 5, 'Harriet asked me to shorten Beanie''s ears and eyelashes. When I arrived Beanie hid under a bed and it took a while to get him out.'),
  ('2025-03-31'::date, 5, null),
  ('2025-02-27'::date, 5, null),
  ('2025-01-27'::date, 5, null),
  ('2024-12-30'::date, 5, null),
  ('2024-12-06'::date, 5, null),
  ('2024-10-21'::date, 5, null),
  ('2024-08-21'::date, 5, null),
  ('2024-07-24'::date, 5, null),
  ('2024-06-12'::date, 5, null),
  ('2024-05-13'::date, 5, null),
  ('2024-03-20'::date, 5, 'Exaggerated sanitary clip under his tail because he gets a mess back there. Beanie had an allergic reaction to a vaccination yesterday and had to go to the emergency clinic; received a benadryl injection and is fine now.'),
  ('2024-02-25'::date, 5, null),
  ('2023-12-29'::date, 5, null),
  ('2023-12-01'::date, 5, 'Harriet asked for eyelashes and ears both shorter again.'),
  ('2023-10-03'::date, 4, 'Harriet requested ears shorter to keep them out of the water bowl, eyelashes still short.'),
  ('2023-08-11'::date, 4, 'Requested eyelashes to be trimmed.')
) as x(d, score, note)
join public.clients c on c.name = 'Harriet Woolf'
join public.dogs d on d.client_id = c.id and d.name = 'Beanie'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Pre-import orphans (before 2023-08-11)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-07-11T12:00:00Z'::timestamptz, 'harriet-2023-07-11'),
  ('2023-06-16T12:00:00Z'::timestamptz, 'harriet-2023-06-16'),
  ('2023-05-19T12:00:00Z'::timestamptz, 'harriet-2023-05-19'),
  ('2023-03-29T12:00:00Z'::timestamptz, 'harriet-2023-03-29'),
  ('2023-02-03T12:00:00Z'::timestamptz, 'harriet-2023-02-03'),
  ('2022-12-09T12:00:00Z'::timestamptz, 'harriet-2022-12-09'),
  ('2022-09-08T12:00:00Z'::timestamptz, 'harriet-2022-09-08'),
  ('2022-07-15T12:00:00Z'::timestamptz, 'harriet-2022-07-15')
) as x(ts, ext)
join public.clients c on c.name = 'Harriet Woolf'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('harriet-2023-07-11', 'Good.'),
  ('harriet-2023-06-16', 'Good. A little urine on the feet left over from last time; cleared it all the way out this time.'),
  ('harriet-2023-05-19', 'Good dog. Urine stains on his feet; clipped extra close to remove them. Harriet said Beanie''s back end was getting filthy, so I exaggerated the sanitary clip.'),
  ('harriet-2023-03-29', 'Very good.'),
  ('harriet-2023-02-03', 'Great dog.'),
  ('harriet-2022-12-09', 'Good dog. Coat seemed extra thick; took longer to clip.'),
  ('harriet-2022-09-08', 'Harriet requested eyelashes to be shortened. Beanie was uncooperative the whole time.'),
  ('harriet-2022-07-15', 'Harriet requested ears and eyelashes to be trimmed a little bit.')
) as x(ext, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Harriet Woolf'
join public.dogs d on d.client_id = c.id and d.name = 'Beanie'
on conflict (visit_id, dog_id) do update set note = excluded.note;
