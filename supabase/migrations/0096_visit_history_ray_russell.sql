-- 0096_visit_history_ray_russell.sql
-- Visit-history migration for Ray Russell / Bailey (Shihpoo). Single dog, q4wk,
-- arc from uncooperative 2s in 2023 to mostly 5s. Score + note attached to the
-- existing time_is_money visit by date; pre-import entries (before 2023-08-24)
-- created as source='contact_sheet'. One undated sheet entry (the saliva-stained
-- feet note, "Bailey. 3") sits between 7/12/24 and 4/19/24; its date is inferred
-- as 2024-06-14 (the q4wk step up from 7/12; the only other candidate, 2024-05-17,
-- has no sheet entry). See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-02-18'::date, 4, 'Acting a little bejigity. Unusual for him.'),
  ('2025-12-26'::date, 5, null),
  ('2025-10-31'::date, 5, null),
  ('2025-10-03'::date, 5, null),
  ('2025-09-05'::date, 5, null),
  ('2025-08-08'::date, 5, null),
  ('2025-07-11'::date, 5, null),
  ('2025-06-11'::date, 5, null),
  ('2025-05-16'::date, 5, null),
  ('2025-04-17'::date, 5, null),
  ('2025-03-21'::date, 5, 'Ray asking for ears to be raised up about an inch relative to the ground.'),
  ('2025-02-21'::date, 5, null),
  ('2025-01-24'::date, 3, null),
  ('2024-12-27'::date, 5, null),
  ('2024-11-29'::date, 3, null),
  ('2024-11-01'::date, 5, null),
  ('2024-10-04'::date, 5, null),
  ('2024-09-06'::date, 4, 'Ray does not want feet clipped shorter to get rid of brown stains.'),
  ('2024-07-12'::date, 3, null),
  ('2024-06-14'::date, 3, 'Feet were stained with saliva. I clipped them shorter than usual to clean it up as best I could.'),
  ('2024-04-19'::date, 4, null),
  ('2024-03-22'::date, 4, null),
  ('2024-02-23'::date, 4, null),
  ('2024-01-26'::date, 3, null),
  ('2023-12-27'::date, 2, 'Low key uncooperative.'),
  ('2023-11-29'::date, 2, 'Low level uncooperative. Ray asked me to shorten his ears to keep them out of the water bowl.'),
  ('2023-11-01'::date, 3, null),
  ('2023-09-21'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Ray Russell'
join public.dogs d on d.client_id = c.id and d.name = 'Bailey'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Pre-import orphans (before 2023-08-24)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-15T12:00:00Z'::timestamptz, 'ray-2023-06-15'),
  ('2023-05-19T12:00:00Z'::timestamptz, 'ray-2023-05-19'),
  ('2023-03-23T12:00:00Z'::timestamptz, 'ray-2023-03-23'),
  ('2023-02-23T12:00:00Z'::timestamptz, 'ray-2023-02-23'),
  ('2022-12-22T12:00:00Z'::timestamptz, 'ray-2022-12-22'),
  ('2022-09-30T12:00:00Z'::timestamptz, 'ray-2022-09-30')
) as x(ts, ext)
join public.clients c on c.name = 'Ray Russell'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('ray-2023-06-15', 'Ok. Uncooperative.'),
  ('ray-2023-05-19', 'Ok. Extra work because he missed his last appointment when he went to the dentist.'),
  ('ray-2023-03-23', 'Good. Ray asked me to shorten his ears.'),
  ('ray-2023-02-23', 'Uncharacteristically uncooperative.'),
  ('ray-2022-12-22', 'Good dog. Cooperative but ignores me the whole time I am grooming him; then after I put him down and knock on the front door, he is really excited for me to pay attention to him.'),
  ('ray-2022-09-30', 'Uncooperative.')
) as x(ext, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Ray Russell'
join public.dogs d on d.client_id = c.id and d.name = 'Bailey'
on conflict (visit_id, dog_id) do update set note = excluded.note;
