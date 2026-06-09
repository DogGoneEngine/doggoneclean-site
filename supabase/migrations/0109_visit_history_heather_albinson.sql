-- 0109_visit_history_heather_albinson.sql
-- Visit-history migration for Heather Albinson / Spero (Corgi; earlier called
-- "Sparrow", same dog) + Mirakel (Standard Poodle). Score + note attached to the
-- existing time_is_money visit by date; the sheet's "10/32/24" is a typo for
-- 10/31/24 (imported 2024-10-31). Pre-import entries (before 2023-09-06), including
-- the oldest 2021-2022 ones from the original Evernote note, are created as
-- source='contact_sheet' so Spero's full early arc (extremely tense -> improving)
-- is kept. See visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Spero =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-03'::date, 5, 'Jake groomed him solo, his first solo dog. Great job.'),
  ('2025-12-12'::date, 5, null),
  ('2025-10-30'::date, 5, null),
  ('2025-09-19'::date, 5, null),
  ('2025-08-06'::date, 5, null),
  ('2025-06-28'::date, 5, null),
  ('2025-05-16'::date, 5, null),
  ('2025-04-04'::date, 5, null),
  ('2025-02-21'::date, 5, null),
  ('2024-10-31'::date, 5, null),
  ('2024-09-20'::date, 2, null),
  ('2024-08-09'::date, 3, null),
  ('2024-06-28'::date, 5, null),
  ('2024-05-17'::date, 5, null),
  ('2024-04-05'::date, 4, null),
  ('2024-02-21'::date, 4, null),
  ('2024-01-10'::date, 2, null),
  ('2023-11-29'::date, 3, null),
  ('2023-10-18'::date, 3, null),
  ('2023-09-06'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Heather Albinson'
join public.dogs d on d.client_id=c.id and d.name='Spero'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- ===== Mirakel =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-03'::date, 5, null),
  ('2025-12-12'::date, 5, 'Used the green comb to leave her topknot longer; it looks good but was a lot more work. See what it looks like next time.'),
  ('2025-10-30'::date, 5, null),
  ('2025-09-19'::date, 5, null),
  ('2025-08-06'::date, 5, null),
  ('2025-06-28'::date, 5, null),
  ('2025-05-16'::date, 5, 'Right eye still has green discharge.'),
  ('2025-04-04'::date, 5, 'Gunk in her right eye, green, probably infection. I told Heather it may need medical attention.'),
  ('2025-02-21'::date, 5, null),
  ('2024-10-31'::date, 5, null),
  ('2024-09-20'::date, 5, null),
  ('2024-08-09'::date, 5, null),
  ('2024-06-28'::date, 5, null),
  ('2024-05-17'::date, 5, null),
  ('2024-04-05'::date, 5, null),
  ('2024-02-21'::date, 5, null),
  ('2024-01-10'::date, 5, 'Ears look way better than usual.'),
  ('2023-11-29'::date, 5, 'Ears look like they need medical attention.'),
  ('2023-10-18'::date, 5, null),
  ('2023-09-06'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Heather Albinson'
join public.dogs d on d.client_id=c.id and d.name='Mirakel'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

update public.visits set visit_notes='To the almost 10-year-old Kevin, he was just Gramps. Youngins by their nature just do not have the time or inclination to worry about old folks getting older.'
where client_id=(select id from public.clients where name='Heather Albinson') and visited_at::date='2025-06-28';

-- ===== Pre-import orphans (before 2023-09-06), back to 2021 =====
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-14T12:00:00Z'::timestamptz, 'heather-2023-06-14'),
  ('2023-05-03T12:00:00Z'::timestamptz, 'heather-2023-05-03'),
  ('2023-03-14T12:00:00Z'::timestamptz, 'heather-2023-03-14'),
  ('2023-02-03T12:00:00Z'::timestamptz, 'heather-2023-02-03'),
  ('2022-10-28T12:00:00Z'::timestamptz, 'heather-2022-10-28'),
  ('2022-09-21T12:00:00Z'::timestamptz, 'heather-2022-09-21'),
  ('2022-02-09T12:00:00Z'::timestamptz, 'heather-2022-02-09'),
  ('2022-01-06T12:00:00Z'::timestamptz, 'heather-2022-01-06'),
  ('2021-11-02T12:00:00Z'::timestamptz, 'heather-2021-11-02'),
  ('2021-09-29T12:00:00Z'::timestamptz, 'heather-2021-09-29')
) as x(ts, ext)
join public.clients c on c.name='Heather Albinson'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('heather-2023-06-14', 'Spero',   'Uncooperative.'),
  ('heather-2023-06-14', 'Mirakel', 'Ok. Short tail. Short ears.'),
  ('heather-2023-05-03', 'Spero',   'Ok.'),
  ('heather-2023-05-03', 'Mirakel', 'Good.'),
  ('heather-2023-03-14', 'Mirakel', 'Great dog. Ears better than before.'),
  ('heather-2023-03-14', 'Spero',   'Good dog.'),
  ('heather-2023-02-03', 'Spero',   'Good.'),
  ('heather-2023-02-03', 'Mirakel', 'Good dog. Ears had large chunks of wax; the left ear had wax that felt like a stone. I pulled the waxy hair out even though it hurt her, because it needed to come out or it would get worse.'),
  ('heather-2022-10-28', 'Spero',   'Growth on his back. Be careful.'),
  ('heather-2022-10-28', 'Mirakel', 'Ears full of wax and hair. Shaking her head before the appointment; a ball of wax in her ear she whimpers at when touched gently. The ears turned out fine, just had hair in them. Difficult to work with; if it were the first time I would not continue working with her. She was given medication before I groomed her.'),
  ('heather-2022-09-21', 'Mirakel', 'Used #7 blade on body, 13mm comb on head.'),
  ('heather-2022-09-21', 'Spero',   'Uncooperative.'),
  ('heather-2022-02-09', 'Mirakel', 'Used #10 blade on feet. She was good. Might have a problem in her ears.'),
  ('heather-2022-02-09', 'Spero',   'Constantly spinning and non compliant.'),
  ('heather-2022-01-06', 'Spero',   'Heavy shedding. Good dog. Saw a nasty growth on his back while drying; it sloughed off while combing. He was good today.'),
  ('heather-2022-01-06', 'Mirakel', 'Severe matting. Heather had pictures of what she wanted; I told her several times I would be clipping very short all over. The dog was good.'),
  ('heather-2021-11-02', 'Spero',   'Less tense this time.'),
  ('heather-2021-09-29', 'Spero',   'Extremely tense.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Heather Albinson'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
