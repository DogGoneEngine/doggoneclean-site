-- 0111_fix_jethro_not_deceased.sql
-- Correction: Erich Blunt's Jethro did NOT die (0110 wrongly marked him deceased).
-- He is alive and lives at the house; Paul simply does not groom him. He stays off
-- the working roster (so he is not offered for visit logging) but is not deceased.
-- Sophie is the poodle who died. Uses 'former' to keep him in the collapsed
-- "Past and other dogs" bucket, with a note that carries the real situation.
update public.dogs
set roster_status = 'former',
    notes = 'Alive; lives at the house. Paul does not groom him (he is just there).'
where name = 'Jethro'
  and client_id = (select id from public.clients where name = 'Erich Blunt');
