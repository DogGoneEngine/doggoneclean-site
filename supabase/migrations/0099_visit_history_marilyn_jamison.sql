-- 0099_visit_history_marilyn_jamison.sql
-- Visit-history migration for Marilyn Jamison / Winnie (Shihpoo). Single dog,
-- q4wk. Score + note attached to the existing time_is_money visit by date. One
-- sheet date is off by a day from time_is_money (sheet 10/28/25 vs the imported
-- 2025-10-27); per time_is_money_is_source_of_truth the note is attached to the
-- 2025-10-27 visit. Pre-2023-08-07 history sits below the readable part of the
-- sheet and is a known small gap (matches the import's start). The bilirubin /
-- lethargy health thread is preserved. See visit_history_migration.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-04-01'::date, 5, 'Mark said to cut the eyelashes this time.'),
  ('2026-03-04'::date, 5, null),
  ('2026-02-04'::date, 5, null),
  ('2025-12-22'::date, 5, 'Marilyn said Winnie was not feeling well; she seemed fine, I did not notice anything out of line.'),
  ('2025-11-24'::date, 5, null),
  ('2025-10-27'::date, 5, null),
  ('2025-09-30'::date, 5, null),
  ('2025-08-22'::date, 5, null),
  ('2025-07-25'::date, 5, 'Acting normal. Not lethargic.'),
  ('2025-06-26'::date, 5, 'Marilyn said she was too long and that she cut the hair on Winnie''s head herself. I clipped shorter all around her head to even it out; 13mm comb on body. Sometimes Winnie is lethargic like she is not feeling well; today she was peppy and alert.'),
  ('2025-05-26'::date, 4, 'Was expecting Barbara; it was Mark instead.'),
  ('2025-05-01'::date, 5, 'Marilyn did not notice anything about Winnie''s ears after last time; ears look fine today, she is not shaking her head.'),
  ('2025-04-02'::date, 5, 'Acting normal. Possible issue with her ears; shaking her head.'),
  ('2025-03-06'::date, 5, 'She seemed like she was feeling fine, not lethargic like last time.'),
  ('2025-02-05'::date, 5, 'She has not been feeling well. She was just at the vet and her bilirubin was high. Started out lethargic with her chin on the tub, became more energetic as time went on. I worked fast in case I needed to stop early, but she did great and seemed to do better as time went on; I did a complete, thorough job.'),
  ('2025-01-09'::date, 5, null),
  ('2024-12-12'::date, 5, null),
  ('2024-11-14'::date, 5, 'Marilyn told the dog sitter to tell me to schedule at 4pm.'),
  ('2024-10-19'::date, 5, null),
  ('2024-09-19'::date, 5, null),
  ('2024-08-22'::date, 4, null),
  ('2024-06-26'::date, 2, 'Uncooperative. Marilyn asked to switch from 6 weeks to 4 weeks.'),
  ('2024-05-15'::date, 4, 'Mr Jamison said Marilyn instructed to dremel nails, do not cut eyelashes, and do not cut too short. Winnie is lightly matted all over and took extra time; her private area was matted and filthy. They usually specify not to clip her there because she gets itchy, but I did anyway because I could not leave her with the matted filth. Used 13mm comb on head and body.'),
  ('2024-04-04'::date, 2, null),
  ('2024-03-06'::date, 4, null),
  ('2024-01-25'::date, 4, null),
  ('2023-11-02'::date, 3, 'Uncooperative. Marilyn said she wanted her left long because it is winter. Used 13mm comb on head and 7/8in comb on body with 13mm comb on the edges to even it out. Said not to shave private area; said she was itchy after last grooming.'),
  ('2023-09-21'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Marilyn Jamison'
join public.dogs d on d.client_id = c.id and d.name = 'Winnie'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;
