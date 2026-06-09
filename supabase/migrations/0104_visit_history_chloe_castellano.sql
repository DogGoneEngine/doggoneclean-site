-- 0104_visit_history_chloe_castellano.sql
-- Visit-history migration for Chloe Castellano. The DB held only Louie (the cocker
-- who mostly gets nails), but Chloe's real grooming history is Whiskey (German
-- Shorthair Pointer, active) and Skout (Beagle mix, died October 2025), who were
-- missing from the dogs table. They are real, documented dogs, so this adds them
-- (Skout marked deceased in notes) and migrates all three by date. Pre-import
-- entries (before 2023-09-19) created as source='contact_sheet'. See
-- visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Add the two missing dogs (idempotent) =====
insert into public.dogs (client_id, name, breed, notes)
select c.id, 'Whiskey', 'German Shorthair Pointer', null
from public.clients c where c.name = 'Chloe Castellano'
and not exists (select 1 from public.dogs d where d.client_id = c.id and d.name = 'Whiskey');

insert into public.dogs (client_id, name, breed, notes)
select c.id, 'Skout', 'Beagle Mix', 'Deceased October 2025.'
from public.clients c where c.name = 'Chloe Castellano'
and not exists (select 1 from public.dogs d where d.client_id = c.id and d.name = 'Skout');

-- ===== Whiskey =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2025-08-05'::date, 5, null),
  ('2025-06-24'::date, 5, null),
  ('2025-05-13'::date, 5, null),
  ('2025-04-01'::date, 5, null),
  ('2025-02-18'::date, 5, null),
  ('2025-01-08'::date, 5, null),
  ('2024-11-26'::date, 5, null),
  ('2024-10-03'::date, 3, null),
  ('2024-07-23'::date, 5, null),
  ('2024-06-13'::date, 5, null),
  ('2024-04-02'::date, 4, null),
  ('2024-02-20'::date, 3, null),
  ('2024-01-09'::date, 4, null),
  ('2023-11-28'::date, 4, null),
  ('2023-10-17'::date, 3, null),
  ('2023-09-19'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Chloe Castellano'
join public.dogs d on d.client_id = c.id and d.name = 'Whiskey'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Skout =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2025-09-17'::date, 5, null),
  ('2025-08-05'::date, 5, 'Lump on the side of her throat.'),
  ('2025-06-24'::date, 5, null),
  ('2025-05-13'::date, 5, null),
  ('2025-04-01'::date, 5, null),
  ('2025-02-18'::date, 5, null),
  ('2025-01-08'::date, 5, null),
  ('2024-11-26'::date, 5, null),
  ('2024-10-03'::date, 5, null),
  ('2024-07-23'::date, 5, null),
  ('2024-06-13'::date, 5, null),
  ('2024-04-02'::date, 4, null),
  ('2024-02-20'::date, 5, null),
  ('2024-01-09'::date, 4, null),
  ('2023-11-28'::date, 4, null),
  ('2023-10-17'::date, 3, null),
  ('2023-09-19'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Chloe Castellano'
join public.dogs d on d.client_id = c.id and d.name = 'Skout'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Louie (occasional, mostly nails) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-01-20'::date, 4, 'Lays down while drying.'),
  ('2025-12-09'::date, 5, null),
  ('2025-10-28'::date, 5, null),
  ('2025-09-17'::date, 5, null),
  ('2025-06-24'::date, 5, 'Nails only.'),
  ('2024-06-13'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Chloe Castellano'
join public.dogs d on d.client_id = c.id and d.name = 'Louie'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Pre-import orphans (before 2023-09-19) =====
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-12T12:00:00Z'::timestamptz, 'chloe-2023-06-12'),
  ('2022-12-29T12:00:00Z'::timestamptz, 'chloe-2022-12-29'),
  ('2022-03-30T12:00:00Z'::timestamptz, 'chloe-2022-03-30')
) as x(ts, ext)
join public.clients c on c.name = 'Chloe Castellano'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('chloe-2023-06-12', 'Whiskey', 'Ok. Long nails.'),
  ('chloe-2023-06-12', 'Skout',   'Good dog.'),
  ('chloe-2022-12-29', 'Skout',   'Very good dog.'),
  ('chloe-2022-12-29', 'Whiskey', 'Friendly. A little bit busy.'),
  ('chloe-2022-03-30', 'Whiskey', 'Whines the whole time Skout is getting ground. Maybe try taking both of them in the trailer next time.')
) as x(ext, dogname, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Chloe Castellano'
join public.dogs d on d.client_id = c.id and d.name = x.dogname
on conflict (visit_id, dog_id) do update set note = excluded.note;
