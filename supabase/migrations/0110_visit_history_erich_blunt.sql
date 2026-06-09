-- 0110_visit_history_erich_blunt.sql
-- Visit-history migration for Erich Blunt's poodles. Only Koby is left; Sophie,
-- Jethro, and the older Moxie all died, so this adds them as deceased dogs and
-- migrates their history (lose-nothing). Jethro is on the header but has no recorded
-- visit history, so he is added as a deceased dog with no ratings. Score + note
-- attached to the existing time_is_money visit by date; the sheet's "3/20/25" is a
-- typo for 3/20/26 (imported 2026-03-20). Pre-import entries (before 2023-08-12),
-- back to the 2021 Evernote era, are source='contact_sheet'. See
-- visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Add the deceased poodles =====
insert into public.dogs (client_id, name, breed, roster_status, notes)
select c.id, x.name, 'Standard Poodle', 'deceased', x.notes
from (values
  ('Sophie', 'Deceased. Standard poodle; declined with age (skin tags, growths, creaky hips) over 2021-2025.'),
  ('Jethro', 'Deceased. Standard poodle; on the contact sheet but no recorded visit history.'),
  ('Moxie',  'Deceased. The oldest poodle; "getting very old" by late 2021.')
) as x(name, notes)
join public.clients c on c.name='Erich Blunt'
where not exists (select 1 from public.dogs d where d.client_id=c.id and d.name=x.name);

-- ===== Koby (the one still groomed) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-05-29'::date, 5, null),
  ('2026-03-20'::date, 5, null),
  ('2026-01-23'::date, 5, null),
  ('2025-11-24'::date, 5, null),
  ('2025-09-23'::date, 5, null),
  ('2025-05-30'::date, 5, null),
  ('2025-03-31'::date, 5, null),
  ('2025-02-03'::date, 5, 'Joyful to be around.'),
  ('2024-12-09'::date, 5, null),
  ('2024-06-26'::date, 5, null),
  ('2024-04-24'::date, 5, null),
  ('2024-02-23'::date, 5, null),
  ('2023-12-13'::date, 5, null),
  ('2023-10-07'::date, 5, null),
  ('2023-08-12'::date, 3, 'Ears look red.')
) as x(d, score, note)
join public.clients c on c.name='Erich Blunt'
join public.dogs d on d.client_id=c.id and d.name='Koby'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- ===== Sophie =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-09-23'::date, 5, 'Getting extremely weak.'),
  ('2025-05-30'::date, 5, null),
  ('2025-03-31'::date, 5, null),
  ('2025-02-03'::date, 5, 'Skin tags everywhere.'),
  ('2024-12-09'::date, 5, null),
  ('2024-06-26'::date, 3, 'Her hips are really creaky. She puts all her weight on her front legs and leans over the edge of the table.'),
  ('2024-04-24'::date, 5, null),
  ('2024-02-23'::date, 5, 'Lots of skin tags. Cannot use the clippers to clip her smooth.'),
  ('2023-12-13'::date, null, 'Cannot give an accurate score. Very sweet and helpful but very difficult to groom because her body is all busted up.'),
  ('2023-10-07'::date, 3, 'Getting very weak. Lots of skin growths.'),
  ('2023-08-12'::date, 3, 'Getting very difficult for her to stand for grooming.')
) as x(d, score, note)
join public.clients c on c.name='Erich Blunt'
join public.dogs d on d.client_id=c.id and d.name='Sophie'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- ===== Pre-import orphans (before 2023-08-12), back to 2021 =====
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-16T12:00:00Z'::timestamptz, 'erich-2023-06-16'),
  ('2023-04-06T12:00:00Z'::timestamptz, 'erich-2023-04-06'),
  ('2023-01-25T12:00:00Z'::timestamptz, 'erich-2023-01-25'),
  ('2022-11-30T12:00:00Z'::timestamptz, 'erich-2022-11-30'),
  ('2022-10-12T12:00:00Z'::timestamptz, 'erich-2022-10-12'),
  ('2022-06-08T12:00:00Z'::timestamptz, 'erich-2022-06-08'),
  ('2021-12-29T12:00:00Z'::timestamptz, 'erich-2021-12-29'),
  ('2021-11-17T12:00:00Z'::timestamptz, 'erich-2021-11-17'),
  ('2021-10-07T12:00:00Z'::timestamptz, 'erich-2021-10-07'),
  ('2021-08-25T12:00:00Z'::timestamptz, 'erich-2021-08-25')
) as x(ts, ext)
join public.clients c on c.name='Erich Blunt'
on conflict (source, external_id) where external_id is not null do nothing;

update public.visits set visit_notes='Foster poodle Winston has people coming tomorrow to look at him.'
where source='contact_sheet' and external_id='erich-2023-04-06';

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('erich-2023-06-16', 'Sophie', 'Great dog. Growths all over. Draws blood under the long fur.'),
  ('erich-2023-06-16', 'Koby',   'Maybe my favorite dog I have ever worked with.'),
  ('erich-2023-04-06', 'Sophie', 'Good dog but she had a hard time; she is getting too old for grooming.'),
  ('erich-2023-04-06', 'Koby',   'Wonderful dog. A pleasure to be around.'),
  ('erich-2023-01-25', 'Sophie', 'Good at first; she had trouble standing still after a while. She tried to be good.'),
  ('erich-2022-11-30', 'Sophie', 'Lots of skin tags. Had to go gently over her with the clippers; not as smooth as if I could press down.'),
  ('erich-2022-11-30', 'Koby',   'Really good.'),
  ('erich-2022-10-12', 'Koby',   'A pleasure to work with. Wish I was not finished.'),
  ('erich-2022-06-08', 'Koby',   'Uncooperative. Miserable to work with.'),
  ('erich-2021-12-29', 'Koby',   'A little uncooperative, not a lot but enough to make everything take longer. Jumpy. Used #7 blade all the way to the bottom of his legs to get him done faster; maybe next time blend the bottom with a comb if he is more cooperative.'),
  ('erich-2021-12-29', 'Moxie',  'Bump on his belly. Getting very old.'),
  ('erich-2021-11-17', 'Sophie', 'Easier this time.'),
  ('erich-2021-11-17', 'Moxie',  'Excellent.'),
  ('erich-2021-10-07', 'Sophie', 'Very difficult to handle this time. Puts all her weight on her front feet and stands on the edge of the table; constantly pushing forward, unable to relax, never still.'),
  ('erich-2021-10-07', 'Moxie',  'Excellent.'),
  ('erich-2021-08-25', 'Moxie',  'Excellent dog.'),
  ('erich-2021-08-25', 'Sophie', 'Excellent dog.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Erich Blunt'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
