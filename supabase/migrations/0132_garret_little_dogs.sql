-- 0132_garret_little_dogs.sql
-- Garret Little's two dogs, Blue and Zoey (per Paul, 2026-06-09). Garret is a nails-only
-- account (~20 quick visits in time_is_money) and his dogs were never loaded, so his visit
-- history could not attach to a dog until now. Amanda Batson shares the same household and
-- the same two dogs; she has no dogs of her own, so the dogs live on Garret's record and
-- Amanda's note points to it. Breed is a genuine data gap (never recorded), not invented.
-- See visit_history_migration + real_data_only.

insert into public.dogs (client_id, name, notes)
select c.id, x.name, 'Nails only. Shared household with Amanda Batson.'
from (values ('Blue'), ('Zoey')) as x(name)
join public.clients c on c.name='Garret Little'
where not exists (
  select 1 from public.dogs d where d.client_id=c.id and d.name=x.name
);

-- Amanda Batson is the same household as Garret Little with the same two dogs and none of
-- her own; record the link on both sides via the relationships array (idempotent).
update public.clients
set relationships = (select array_agg(distinct e) from unnest(coalesce(relationships,'{}') || array['Same household as Garret Little; shares his dogs Blue and Zoey, none of her own.']) e)
where name='Amanda Batson';

update public.clients
set relationships = (select array_agg(distinct e) from unnest(coalesce(relationships,'{}') || array['Same household as Amanda Batson.']) e)
where name='Garret Little';
