-- 0121_visit_history_bradley_johnson.sql
-- Visit-history migration for Bradley Johnson / Bella (Cocker Spaniel). Arc from
-- 2s/3s in 2023 to steady 5s, with her tail-scab / skin-tag thread. His other dog
-- Gabby (Lab, nail-clip only) died March 2023 of cancer and is added as deceased
-- (lose-nothing). Score + note attached to the existing time_is_money visit by date;
-- the sheet's partial "/6/25" is 8/6/25 (imported 2025-08-06). Pre-import entries
-- (before 2023-09-06), back to the 2021 Evernote note, are source='contact_sheet'.
-- See visit_history_migration + time_is_money_is_source_of_truth.

-- Add the deceased dog Gabby.
insert into public.dogs (client_id, name, breed, roster_status, notes)
select c.id, 'Gabby', 'Lab', 'deceased', 'Deceased March 2023 (cancer). Was nail-clip only.'
from public.clients c where c.name='Bradley Johnson'
and not exists (select 1 from public.dogs d where d.client_id=c.id and d.name='Gabby');

-- Bella
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-04-04'::date, 5, null),
  ('2026-02-21'::date, 5, null),
  ('2025-12-26'::date, 5, null),
  ('2025-11-14'::date, 5, 'Growth on the front right paw where a dewclaw would be if she had one, with clumped matted hair around it. The clippers made it ooze; not dripping blood but it will get blood on you if you touch it. Nothing to worry about.'),
  ('2025-09-19'::date, 5, null),
  ('2025-08-06'::date, 5, null),
  ('2025-06-13'::date, 5, 'Just had all her skin tags removed a couple weeks ago.'),
  ('2025-05-02'::date, 5, null),
  ('2025-03-18'::date, 5, null),
  ('2025-01-24'::date, 5, 'There is still a swelling lump by her tail, but the scab cleaned away this time with the clippers.'),
  ('2024-12-13'::date, 5, 'Scab on the base of her tail. I trimmed around it but it still seems attached; observe next time if it is ready to shave off.'),
  ('2024-11-01'::date, 5, null),
  ('2024-09-16'::date, 4, null),
  ('2024-08-09'::date, 3, null),
  ('2024-06-21'::date, 4, null),
  ('2024-05-15'::date, 4, null),
  ('2024-01-10'::date, 3, null),
  ('2023-11-29'::date, 3, null),
  ('2023-10-18'::date, 3, 'Takes a very long time to groom her.'),
  ('2023-09-06'::date, 2, null)
) as x(d, score, note)
join public.clients c on c.name='Bradley Johnson'
join public.dogs d on d.client_id=c.id and d.name='Bella'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

update public.visits set visit_notes='Gave us rice crispy treats. He said to add $10 for a tip; said I did not last time. Hand him the phone in the future and let him do the tip.'
where client_id=(select id from public.clients where name='Bradley Johnson') and visited_at::date='2026-04-04';

-- Pre-import orphans (before 2023-09-06)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-05-04T12:00:00Z'::timestamptz, 'bradley-2023-05-04'),
  ('2023-03-22T12:00:00Z'::timestamptz, 'bradley-2023-03-22'),
  ('2023-02-08T12:00:00Z'::timestamptz, 'bradley-2023-02-08'),
  ('2023-01-13T12:00:00Z'::timestamptz, 'bradley-2023-01-13'),
  ('2022-12-28T12:00:00Z'::timestamptz, 'bradley-2022-12-28'),
  ('2022-10-06T12:00:00Z'::timestamptz, 'bradley-2022-10-06'),
  ('2022-05-11T12:00:00Z'::timestamptz, 'bradley-2022-05-11'),
  ('2021-11-18T12:00:00Z'::timestamptz, 'bradley-2021-11-18'),
  ('2021-10-14T12:00:00Z'::timestamptz, 'bradley-2021-10-14')
) as x(ts, ext)
join public.clients c on c.name='Bradley Johnson'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('bradley-2023-05-04', 'Better than usual. Bradley requested her left longer. Used #7 blade on the back, blended down with 1.5mm, 8mm and 13mm combs; #7 blade on feet.'),
  ('bradley-2023-03-22', 'Ok.'),
  ('bradley-2023-02-08', 'Went to the bathroom on the table, twice. A little uncooperative.'),
  ('bradley-2023-01-13', 'Good. Bradley requested shorter. Used 8mm comb on the under parts.'),
  ('bradley-2022-12-28', 'Good dog.'),
  ('bradley-2022-10-06', 'Just went to the vet for an infection around the private area.'),
  ('bradley-2022-05-11', 'Feet are looking raw. It might not make sense to use a 10 blade on them next time.'),
  ('bradley-2021-11-18', 'Bradley said to be careful about getting water in her ears, and to clip the feet short.'),
  ('bradley-2021-10-14', 'Bradley said to be careful about getting water in her ear because she has had an ear infection.')
) as x(ext, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Bradley Johnson'
join public.dogs d on d.client_id=c.id and d.name='Bella'
on conflict (visit_id, dog_id) do update set note=excluded.note;
