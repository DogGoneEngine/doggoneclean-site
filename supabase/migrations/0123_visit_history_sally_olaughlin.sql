-- 0123_visit_history_sally_olaughlin.sql
-- Visit-history migration for Sally O'Laughlin / Mindie (Shih Tzu). Single dog, with
-- the recurring ear / skin-tag care and urine-stain notes; the upcoming move to
-- assisted living in Lake Wales is kept as a visit note. Score + note attached to the
-- existing time_is_money visit by date; the sheet's "1/10/24" maps to the imported
-- 2024-01-11. Pre-import entries (before 2023-09-07), back to the 2022 Evernote note,
-- are source='contact_sheet'. See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-04-03'::date, 5, null),
  ('2026-02-18'::date, 5, null),
  ('2025-12-29'::date, 5, null),
  ('2025-10-29'::date, 5, null),
  ('2025-09-03'::date, 5, null),
  ('2025-07-09'::date, 3, null),
  ('2025-05-01'::date, 5, null),
  ('2025-03-06'::date, 5, null),
  ('2025-01-09'::date, 5, 'Noticed a very small streak of blood inside her right ear. It was not worth mentioning so I said nothing; it appears to have been a thing last time also.'),
  ('2024-11-14'::date, 4, 'Nicked a skin tag on the inside of her ear flap that was wadded up in a clump of hair. Oozed blood but did not drip. I let Sally know to make sure Mindie did not rub it against anything in the house.'),
  ('2024-09-16'::date, 4, null),
  ('2024-05-03'::date, 4, null),
  ('2024-01-11'::date, 3, null),
  ('2023-10-19'::date, 3, 'Best she has ever been, almost a 4. Tested the nails on my arm, they are smooth.'),
  ('2023-09-07'::date, 2, 'Urine stains on feet. Used #7 blade on feet and hocks to remove the stains. Pads get bloody when you shave them; be gentle.')
) as x(d, score, note)
join public.clients c on c.name=$$Sally O'Laughlin$$
join public.dogs d on d.client_id=c.id and d.name='Mindie'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

update public.visits set visit_notes='Sally and Mindie are moving to assisted living in Lake Wales soon.'
where client_id=(select id from public.clients where name=$$Sally O'Laughlin$$) and visited_at::date='2026-02-18';

-- Pre-import orphans (before 2023-09-07)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-14T12:00:00Z'::timestamptz, 'sally-2023-06-14'),
  ('2023-04-27T12:00:00Z'::timestamptz, 'sally-2023-04-27'),
  ('2023-03-08T12:00:00Z'::timestamptz, 'sally-2023-03-08'),
  ('2023-01-18T12:00:00Z'::timestamptz, 'sally-2023-01-18'),
  ('2022-08-31T12:00:00Z'::timestamptz, 'sally-2022-08-31'),
  ('2022-07-15T12:00:00Z'::timestamptz, 'sally-2022-07-15'),
  ('2022-02-16T12:00:00Z'::timestamptz, 'sally-2022-02-16')
) as x(ts, ext)
join public.clients c on c.name=$$Sally O'Laughlin$$
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('sally-2023-06-14', 'Uncooperative. Urine stains on feet; used #7 blade on feet and hocks to remove the stains.'),
  ('sally-2023-04-27', 'Ok.'),
  ('sally-2023-03-08', 'Sally asked for the ears to be shortened so they would not get in the water bowl. Mindie was much calmer than usual.'),
  ('sally-2023-01-18', 'Sally requested the ears raised because they are getting in the water bowl.'),
  ('sally-2022-08-31', 'Sally asked for the ears to be shortened. Urine stains on feet, so used #7 blade on feet and hocks.'),
  ('sally-2022-07-15', 'Filth all down the backs of her legs and feet.'),
  ('sally-2022-02-16', 'Difficult.')
) as x(ext, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name=$$Sally O'Laughlin$$
join public.dogs d on d.client_id=c.id and d.name='Mindie'
on conflict (visit_id, dog_id) do update set note=excluded.note;
