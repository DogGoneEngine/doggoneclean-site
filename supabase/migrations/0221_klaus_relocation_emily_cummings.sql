-- 0221_klaus_relocation_emily_cummings.sql
-- Klaus (German Shepherd) moved out of Kevin & Erin Cummings' home to their
-- daughter Emily Cummings' house (8946 SW 69th Terr, Ocala 34476, Pioneer Ranch,
-- by Publix), still inside the SW Ocala service area. Paul booked the first
-- appointment in Acuity (in-app reminders are not live yet). This is a household
-- relocation, not a move out of service like Kevin's Ace and Kage (0107): Klaus
-- stays a client, so he gets a live record at the home he now lives in.
--
-- Model (location lives at the client level, plus the lose-nothing rule):
--  1. New standing client Emily Cummings at the new address (daughter; the family
--     link to Kevin & Erin is kept in relationships on both records).
--  2. Reparent Klaus's public.dogs row to Emily. Reparenting keeps his dog_id, so
--     all 23 rows of visit and behavior history (visit_dog_ratings, keyed by
--     dog_id) follow him to the active record. Kevin's past visits stay under
--     Kevin (visits.client_id unchanged), so that history is intact too; Kevin
--     simply no longer carries Klaus on his working roster.
--  3. Deactivate Klaus on Kevin's bath_dogs (he is off Kevin's plan now), so the
--     tracker and roster for Kevin stop listing him. Done AFTER the reparent so the
--     _sync_dogs_roster_from_bath trigger (0215) is a no-op (there is no Kevin/Klaus
--     row left in public.dogs to flip to 'former').
--
-- Deferred on purpose: Emily's bath_subscribers / portal / reminders account.
-- Booking is arranged by her mother Erin and runs through Acuity for now; we have
-- no phone or email for Emily yet, and in-app reminders are not live. is_anchor is
-- false so this record does not shift the service-area anchor math; her address
-- already sits inside the existing SW Ocala anchor cluster (Koerner and Lape are
-- the same 34476). See dog_roster_status + visit_history_migration + the Ace/Kage
-- precedent in 0107.

-- 1. Emily Cummings (new standing client at the new home).
insert into public.clients
  (name, roster_group, status, service_type, cadence_days, cadence_confidence,
   cadence_note, hardness, client_type, lifecycle, location_address, location_zip,
   location_zone, location_geo_notes, relationships, data_gaps, routed, is_anchor,
   source, note)
select
  'Emily Cummings', 'standing', 'standing', 'full_groom', 42, 'low',
  'Carried ~6wk from the Kevin & Erin Cummings household; unconfirmed at Emily''s home.',
  'FLEX', 'recurring', 'active', '8946 SW 69th Terr, Ocala', '34476',
  'Ocala-SW', 'Pioneer Ranch, near Publix.',
  array['Daughter of Kevin & Erin Cummings (5312 SW 115th Street Rd, Ocala 34476). Klaus (German Shepherd) moved to her home June 2026.'],
  array['Emily phone and email not captured (mother Erin arranges; portal and in-app reminders account deferred until reminders are live)',
        'cadence at the new home unconfirmed (carried ~6wk from the Cummings household)'],
  true, false, 'manual',
  'Created 2026-06-19: Klaus moved from Kevin & Erin Cummings'' home to their daughter Emily''s. First appointment booked in Acuity (in-app reminders not yet live).'
where not exists (select 1 from public.clients where name = 'Emily Cummings');

-- 2. Reparent Klaus to Emily, keeping his dog_id (and therefore all his history).
update public.dogs d
   set client_id = (select id from public.clients where name = 'Emily Cummings'),
       roster_status = 'regular',
       notes = 'Moved to daughter Emily Cummings'' home (8946 SW 69th Terr, Ocala 34476) June 2026; previously on Kevin & Erin Cummings'' multi-dog account. Full visit and behavior history retained.',
       updated_at = now()
 where d.name = 'Klaus'
   and d.client_id = (select id from public.clients where name = 'Kevin Cummings');

-- 3. Record the family link on Kevin's side too.
update public.clients
   set relationships = array['Daughter Emily Cummings (8946 SW 69th Terr, Ocala 34476) took Klaus (German Shepherd); he moved to her home June 2026.'],
       updated_at = now()
 where name = 'Kevin Cummings';

-- 4. Klaus off Kevin's bath plan (the roster-sync trigger is a no-op after step 2).
update public.bath_dogs bd
   set active = false, updated_at = now()
  from public.bath_subscribers s
 where bd.subscriber_id = s.id
   and s.client_id = (select id from public.clients where name = 'Kevin Cummings')
   and lower(bd.name) = 'klaus';
