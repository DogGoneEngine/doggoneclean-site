-- 0120_visit_history_lisa_prater.sql
-- Visit-history migration for Lisa Prater / Gypsy (Boxer). Recently added client,
-- mostly quick nail-file visits ($30) with the occasional full groom; the sheet
-- carries only two recorded entries. Migrates Gypsy's full-groom 5 (Aug 2025) and the
-- Oct 4 nail-file, preserving the note that Lisa's husband Larry passed away that
-- morning as the visit note. The other nail-only visits were not individually scored
-- (an honest gap). See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-08-23'::date, 5, null),
  ('2025-10-04'::date, null, 'Filed her nails.')
) as x(d, score, note)
join public.clients c on c.name='Lisa Prater'
join public.dogs d on d.client_id=c.id and d.name='Gypsy'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

update public.visits set visit_notes='Lisa''s husband Larry passed away this morning. I filed Gypsy''s nails after I finished Ben at Nancy''s.'
where client_id=(select id from public.clients where name='Lisa Prater') and visited_at::date='2025-10-04';
