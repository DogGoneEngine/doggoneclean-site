-- 0122_visit_history_linda_giza.sql
-- Visit-history migration for Linda Giza / Charlie (Soft Coated Wheaten Terrier,
-- born 7/1/2014), quarterly. His pattern: starts ok then falls apart after about 45
-- minutes. Score + note attached to the existing time_is_money visit by date. Also
-- sets his birth date from the sheet. Pre-import entries (before 2023-10-19), back to
-- the 2021 Evernote note, are source='contact_sheet'. A guest dog "Drake" (a
-- neighbor's, nails only, undated) is left out. See visit_history_migration +
-- time_is_money_is_source_of_truth.

update public.dogs set birth_date='2014-07-01', dob_approximate=false
where name='Charlie' and client_id=(select id from public.clients where name='Linda Giza');

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-03-30'::date, 3, null),
  ('2026-01-05'::date, 5, 'They wanted him left long. I was able to comb everything out and only needed to shave the places that already needed shaving for sanitary anyway. Used the long green comb on the head. Still charged the same; took about the same time.'),
  ('2025-10-14'::date, 5, null),
  ('2025-07-08'::date, 4, null),
  ('2025-04-15'::date, 5, null),
  ('2025-01-22'::date, 4, 'Hard mats between the pads of his feet.'),
  ('2024-10-01'::date, 3, 'Was pretty good, fell apart quickly at the end. Total time about an hour.'),
  ('2024-07-09'::date, 2, 'Starts out ok but falls apart after about 45 minutes.'),
  ('2024-04-18'::date, 4, null),
  ('2024-01-23'::date, 3, 'Two hotspots on the back left foot.'),
  ('2023-10-19'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Linda Giza'
join public.dogs d on d.client_id=c.id and d.name='Charlie'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-10-19)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-04-25T12:00:00Z'::timestamptz, 'linda-2023-04-25'),
  ('2022-11-09T12:00:00Z'::timestamptz, 'linda-2022-11-09'),
  ('2022-08-25T12:00:00Z'::timestamptz, 'linda-2022-08-25'),
  ('2022-02-23T12:00:00Z'::timestamptz, 'linda-2022-02-23'),
  ('2021-12-08T12:00:00Z'::timestamptz, 'linda-2021-12-08'),
  ('2021-09-02T12:00:00Z'::timestamptz, 'linda-2021-09-02')
) as x(ts, ext)
join public.clients c on c.name='Linda Giza'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('linda-2023-04-25', 'Better this time. Used #7 blade; worked much better.'),
  ('linda-2022-11-09', 'Uncooperative.'),
  ('linda-2022-08-25', 'Uncooperative. Unpleasant to work with.'),
  ('linda-2022-02-23', 'Good.'),
  ('linda-2021-12-08', 'Charlie was good. His front left leg was injured; had to be careful of it.'),
  ('linda-2021-09-02', 'Usual. Large volume of hair, constantly jamming the clipper vacuum; took extra time. Charlie got impatient after a while.')
) as x(ext, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Linda Giza'
join public.dogs d on d.client_id=c.id and d.name='Charlie'
on conflict (visit_id, dog_id) do update set note=excluded.note;
