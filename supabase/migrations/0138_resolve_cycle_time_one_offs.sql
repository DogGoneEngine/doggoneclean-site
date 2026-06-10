-- 0138: resolve the five cycle-time one-off names (client_dispositions_are_migrations).
-- Shane Smith, Jane Henrich, Amanda Posner, Billye Mallory, Edely Abreu were
-- added 2026-06-07 from cycle-time data with explicit gaps. Resolved 2026-06-10
-- from Paul's direct account plus his Google Calendar booking forms (Acuity
-- intake answers carry address, contact, breeds, gate codes). Addresses and
-- contacts already on file matched the calendar exactly; what was missing was
-- service_type on all five and dog records for Posner, Mallory, and Abreu.
-- Paul confirmed there is NO Drive contact sheet for Abreu (searched by title
-- and full text), so the calendar form is the best source that exists.
-- Dog NAMES for the three were never recorded anywhere (real_data_only: the
-- name field is NOT NULL, so each carries a breed-based label that says so,
-- with the gap noted on the record). Keyed by name so a reseed replays it.

-- service_type: all five are grooming clients (Groom-N-Dogs bookings; long
-- on-site blocks). Jane and Shane double-coat full grooms per Paul.
update public.clients set service_type = 'full_groom'
 where name in ('Shane Smith', 'Jane Henrich', 'Amanda Posner', 'Billye Mallory', 'Edely Abreu')
   and service_type is null;

-- Amanda Posner: Boxer, one dog, $75; gate code 0155 from the booking form.
insert into public.dogs (client_id, name, breed, price_cents, notes)
select c.id, 'Boxer (name unknown)', 'Boxer', 7500,
       'Name never recorded; breed and gate code from the Acuity booking form (2025-10-08). Charged $75.'
  from public.clients c
 where c.name = 'Amanda Posner'
   and not exists (select 1 from public.dogs d where d.client_id = c.id);

update public.clients
   set access_notes = coalesce(nullif(access_notes, ''), 'Gate code 0155 (from the booking form).')
 where name = 'Amanda Posner';

-- Billye Mallory: three dogs, charged $180 as a bundle (2025-08-24). Names
-- never recorded; weights from the booking form kept on each record.
insert into public.dogs (client_id, name, breed, price_cents, notes)
select c.id, v.name, v.breed, null, v.note
  from public.clients c
  cross join (values
    ('Boykin Spaniel (name unknown)', 'Boykin Spaniel', 'Name never recorded; medium, about 40 lbs per the booking form. The 2025-08-24 visit charged $180 for all three dogs as a bundle.'),
    ('Cavalier Spaniel (name unknown)', 'Cavalier King Charles Spaniel', 'Name never recorded; small, about 13 lbs per the booking form. Priced in the $180 three-dog bundle.'),
    ('English Bulldog (name unknown)', 'English Bulldog', 'Name never recorded; medium but hefty, about 60 lbs per the booking form. Priced in the $180 three-dog bundle.')
  ) as v(name, breed, note)
 where c.name = 'Billye Mallory'
   and not exists (select 1 from public.dogs d where d.client_id = c.id);

-- Edely Abreu: one American Staffordshire Terrier (Paul remembers the pit
-- bull; the booking form names the breed). $75. No contact sheet exists.
insert into public.dogs (client_id, name, breed, price_cents, notes)
select c.id, 'Am Staff (name unknown)', 'American Staffordshire Terrier', 7500,
       'Name never recorded; breed from the Acuity booking form (2025-08-10). Charged $75. No Drive contact sheet exists for this client.'
  from public.clients c
 where c.name = 'Edely Abreu'
   and not exists (select 1 from public.dogs d where d.client_id = c.id);

-- Notes: mark the gaps resolved (and what stays a genuine gap).
update public.clients set note = note || ' RESOLVED 2026-06-10 from the calendar booking form + Paul: Boxer, 1 dog, gate code 0155. Dog name still a gap.'
 where name = 'Amanda Posner' and note not like '%RESOLVED 2026-06-10%';
update public.clients set note = note || ' RESOLVED 2026-06-10 from the calendar booking form: 3 dogs (Boykin Spaniel ~40lb, Cavalier ~13lb, English Bulldog ~60lb), $180 bundle. Dog names still a gap. May go inactive soon per Paul.'
 where name = 'Billye Mallory' and note not like '%RESOLVED 2026-06-10%';
update public.clients set note = note || ' RESOLVED 2026-06-10 from the calendar booking form + Paul: American Staffordshire Terrier, 1 dog, $75. Dog name still a gap; no Drive contact sheet exists. Likely going inactive per Paul.'
 where name = 'Edely Abreu' and note not like '%RESOLVED 2026-06-10%';
update public.clients set note = note || ' CONFIRMED 2026-06-10 by Paul + calendar: two Siberian Huskies (Ice, Luna) at $175 each; address and contact verified.'
 where name = 'Shane Smith' and note not like '%CONFIRMED 2026-06-10%';
update public.clients set note = note || ' CONFIRMED 2026-06-10 by Paul: Great Pyrenees Dory at $150; address, plus code, and contact verified.'
 where name = 'Jane Henrich' and note not like '%CONFIRMED 2026-06-10%';
