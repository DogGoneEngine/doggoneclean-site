-- 0117_visit_history_jeanne_leuenberger.sql
-- Visit-history migration for Jeanne Leuenberger / Bella (micro mini labradoodle).
-- A clear arc from "completely uncooperative, I do not like working with her" (1s and
-- 2s in 2023) up to steady 4s and 5s. Score + note attached to the existing
-- time_is_money visit by date; the sheet's "6/14/25" is a typo for 6/14/24 (its
-- reverse-chron position and the imported 2024-06-14 confirm it). Pre-import entries
-- (before 2023-08-23), back to the 2022 Evernote note, are source='contact_sheet'.
-- See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-12-26'::date, 4, null),
  ('2025-10-31'::date, 5, null),
  ('2025-09-05'::date, 4, null),
  ('2025-07-11'::date, 5, 'Jeanne''s daughter asked me to put her shorter; I clipped her shorter last time so even shorter this time. Used 7f on body.'),
  ('2025-05-16'::date, 5, 'Jeanne asked me to clip Bella shorter than last time; used 6mm comb on body.'),
  ('2025-01-22'::date, 4, null),
  ('2024-11-15'::date, 4, null),
  ('2024-06-14'::date, 4, null),
  ('2024-04-19'::date, 4, null),
  ('2024-02-21'::date, 4, null),
  ('2023-12-27'::date, 2, null),
  ('2023-10-18'::date, 2, 'Security hassling about getting in.'),
  ('2023-08-23'::date, 1, null)
) as x(d, score, note)
join public.clients c on c.name='Jeanne Leuenberger'
join public.dogs d on d.client_id=c.id and d.name='Bella'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-08-23)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-28T12:00:00Z'::timestamptz, 'jeanne-2023-06-28'),
  ('2023-04-20T12:00:00Z'::timestamptz, 'jeanne-2023-04-20'),
  ('2023-02-09T12:00:00Z'::timestamptz, 'jeanne-2023-02-09'),
  ('2022-11-30T12:00:00Z'::timestamptz, 'jeanne-2022-11-30'),
  ('2022-07-07T12:00:00Z'::timestamptz, 'jeanne-2022-07-07'),
  ('2022-03-15T12:00:00Z'::timestamptz, 'jeanne-2022-03-15'),
  ('2022-01-20T12:00:00Z'::timestamptz, 'jeanne-2022-01-20')
) as x(ts, ext)
join public.clients c on c.name='Jeanne Leuenberger'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('jeanne-2023-06-28', 'Uncooperative. I do not like working with this dog.'),
  ('jeanne-2023-04-20', 'Completely uncooperative. I do not like working with her. Jeanne is very nice.'),
  ('jeanne-2023-02-09', 'Last time she asked for Bella a little longer than usual; today she wants it a little shorter. Going back to standing instructions. Moderate matting; was able to use the 8mm comb but it took extra time, a #7 blade would have been more appropriate. Bella is a little uncooperative.'),
  ('jeanne-2022-11-30', 'Jeanne asked me to leave her longer because she gets cold. Used 13mm comb on body, 8mm comb on feet, hand scissored head.'),
  ('jeanne-2022-07-07', 'Dewclaw bled after she went in the house and ran around.'),
  ('jeanne-2022-03-15', 'Still waiting for some parts to grow back out from last time; ears and tail are still short and choppy.'),
  ('jeanne-2022-01-20', 'Heavily matted. Shaved her down and made her look as good as possible with what was left.')
) as x(ext, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Jeanne Leuenberger'
join public.dogs d on d.client_id=c.id and d.name='Bella'
on conflict (visit_id, dog_id) do update set note=excluded.note;
