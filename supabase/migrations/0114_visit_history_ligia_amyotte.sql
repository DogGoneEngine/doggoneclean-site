-- 0114_visit_history_ligia_amyotte.sql
-- Visit-history migration for Ligia Amyotte's outside livestock-guard pack: Daisy
-- (Great Pyrenees, the boss; bad/cauliflower ears, droopy eyes) and Sissy (Great
-- Pyrenees) -- two white Pyrenees Paul tells apart by "bad ears" (Daisy) vs "not bad
-- ears" (Sissy) -- plus the labs Tank and Lucy. Sheet labels are mapped on that
-- convention; where a note truly could not tell them apart it is attached to both.
-- Score + note attached to the existing time_is_money visit by date (sheet 6/13/25
-- maps to the imported 2025-06-12). Pre-import entries (before 2023-08-26), back to
-- 2021, are source='contact_sheet'. See visit_history_migration +
-- time_is_money_is_source_of_truth.

-- Distinguishing notes so the two Pyrenees are never a guess.
update public.dogs set notes = 'The boss. Bad/cauliflower ears, droopy eyes. Paul tells her from Sissy by the bad ears.'
where name='Daisy' and client_id=(select id from public.clients where name='Ligia Amyotte');
update public.dogs set notes = 'The "not bad ears" Great Pyrenees (tells her from Daisy, who has the bad ears).'
where name='Sissy' and client_id=(select id from public.clients where name='Ligia Amyotte');

-- ===== Daisy (bad ears) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-21'::date, 5, null),
  ('2025-11-29'::date, 5, null),
  ('2025-10-04'::date, 5, null),
  ('2025-06-12'::date, 5, null),
  ('2025-04-17'::date, 5, null),
  ('2025-02-17'::date, 5, 'Lots of irritated skin and sore spots.'),
  ('2024-11-02'::date, 5, null),
  ('2024-08-23'::date, 5, null),
  ('2024-06-29'::date, 5, null),
  ('2024-05-13'::date, 4, null),
  ('2023-12-30'::date, 4, null),
  ('2023-11-04'::date, 2, null),
  ('2023-08-26'::date, 4, 'Cauliflower ears.')
) as x(d, score, note)
join public.clients c on c.name='Ligia Amyotte'
join public.dogs d on d.client_id=c.id and d.name='Daisy'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- ===== Sissy (not bad ears) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-21'::date, 5, null),
  ('2025-11-29'::date, 5, null),
  ('2025-10-04'::date, 5, null),
  ('2025-06-12'::date, 5, null),
  ('2025-04-17'::date, 5, null),
  ('2025-02-17'::date, 5, 'Forechest was matted; I clipped a couple of lines down with the clippers.'),
  ('2024-11-02'::date, 5, null),
  ('2024-08-23'::date, 5, null),
  ('2024-06-29'::date, 5, null),
  ('2024-05-13'::date, 4, null),
  ('2023-12-30'::date, 4, null),
  ('2023-11-04'::date, 4, null),
  ('2023-08-26'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Ligia Amyotte'
join public.dogs d on d.client_id=c.id and d.name='Sissy'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- ===== Tank (lab) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-21'::date, 5, null),
  ('2025-11-29'::date, 5, null),
  ('2025-10-04'::date, 5, null),
  ('2025-06-12'::date, 5, null),
  ('2024-11-02'::date, 5, null),
  ('2024-08-23'::date, 5, null),
  ('2024-06-29'::date, 5, null),
  ('2024-05-13'::date, 4, null),
  ('2023-11-04'::date, 2, null),
  ('2023-08-26'::date, 3, 'Very dirty.')
) as x(d, score, note)
join public.clients c on c.name='Ligia Amyotte'
join public.dogs d on d.client_id=c.id and d.name='Tank'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- ===== Lucy (lab) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-01-21'::date, 5, null),
  ('2025-11-29'::date, 5, null),
  ('2025-10-04'::date, 5, null),
  ('2025-06-12'::date, 5, null),
  ('2024-11-02'::date, 5, null),
  ('2024-08-23'::date, 5, null),
  ('2024-06-29'::date, 5, null),
  ('2024-05-13'::date, 4, null),
  ('2023-11-04'::date, 2, null),
  ('2023-08-26'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Ligia Amyotte'
join public.dogs d on d.client_id=c.id and d.name='Lucy'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- ===== Pre-import orphans (before 2023-08-26), back to 2021 =====
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-30T12:00:00Z'::timestamptz, 'ligia-2023-06-30'),
  ('2023-02-10T12:00:00Z'::timestamptz, 'ligia-2023-02-10'),
  ('2022-10-14T12:00:00Z'::timestamptz, 'ligia-2022-10-14'),
  ('2022-05-07T12:00:00Z'::timestamptz, 'ligia-2022-05-07'),
  ('2021-10-29T12:00:00Z'::timestamptz, 'ligia-2021-10-29'),
  ('2021-09-04T12:00:00Z'::timestamptz, 'ligia-2021-09-04')
) as x(ts, ext)
join public.clients c on c.name='Ligia Amyotte'
on conflict (source, external_id) where external_id is not null do nothing;

update public.visits set visit_notes='Increased the Great Pyrenees to $120 each.'
where source='contact_sheet' and external_id='ligia-2023-06-30';
update public.visits set visit_notes='House sitter''s kids were throwing objects at my car and trailer.'
where source='contact_sheet' and external_id='ligia-2021-09-04';

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('ligia-2023-06-30', 'Daisy', 'Cauliflower ears. Heavy matting on the back of the back legs and tail; clipped away. Good.'),
  ('ligia-2023-06-30', 'Sissy', 'Good.'),
  ('ligia-2023-06-30', 'Tank',  'Good.'),
  ('ligia-2023-06-30', 'Lucy',  'Good.'),
  ('ligia-2023-02-10', 'Tank',  'Good dog in the trailer; outside not so much.'),
  ('ligia-2023-02-10', 'Lucy',  'Good.'),
  ('ligia-2023-02-10', 'Daisy', 'Both good (Sissy and Daisy; could not tell them apart).'),
  ('ligia-2023-02-10', 'Sissy', 'Both good (Sissy and Daisy; could not tell them apart).'),
  ('ligia-2022-10-14', 'Tank',  'Got very muddy where we arrived; clean when we left.'),
  ('ligia-2022-10-14', 'Sissy', 'Dew claw in the rear cracked right by the toe; started bleeding when I began filing it. Leaving it alone and hoping it grows out before it breaks.'),
  ('ligia-2022-05-07', 'Lucy',  'Face is torn up.'),
  ('ligia-2021-10-29', 'Lucy',  'Bad ears.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Ligia Amyotte'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
