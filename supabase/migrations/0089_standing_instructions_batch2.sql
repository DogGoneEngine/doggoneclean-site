-- 0089_standing_instructions_batch2.sql
-- Drive cross-reference batch 2: the 2026-06-10 route clients (Michelle Reiners,
-- Jane Henrich, Ginger Fink, Chester Weber). Standing instructions transcribed
-- from each dog's "Standing Instructions" field (faithful to the sheet; blank
-- left null), plus access notes, plus codes, who's on site, a hard availability
-- window where the header gave one, a birthday where the sheet stated one, and
-- one billing note. Keyed by name; real data only. See dog_standing_instructions
-- + client_access_notes + client_onsite_people.

-- Michelle Reiners
update public.dogs d set standing_instructions = 'A couple years younger than Bruno; had him since a puppy.', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Michelle Reiners' and d.name = 'Bandit';
update public.dogs d set standing_instructions = '9 years old in 2023; had him since a puppy.', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Michelle Reiners' and d.name = 'Bruno';
update public.clients set onsite_people = 'Son is Joe.', availability_hard = 'Weekdays, after 5:15pm, not Tuesdays.', updated_at = now()
 where name = 'Michelle Reiners';

-- Jane Henrich
update public.dogs d set standing_instructions = '#7 blade on feet and hocks.', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Jane Henrich' and d.name = 'Dory';
update public.clients set
    location_plus = '6VV4+X9J Ocala, FL',
    access_notes = 'Gate code 2005#. Dory likes to go in and out the back door: go to the front door first, then meet them around back. Parking plus code 6VW4+JG2 Ocala.',
    onsite_people = 'Joe Henrich (husband). Mary has been on site.',
    updated_at = now()
 where name = 'Jane Henrich';

-- Ginger Fink (Bruce has no standing-instructions text on the sheet; left null)
update public.clients set
    onsite_people = 'James (husband); they have a farm nearby (horse farm near the house). Ginger is a realtor.',
    availability_hard = 'After 5pm (gets home at 4:30). Weekends. Can arrange to have someone home during the day on weekdays if needed.',
    updated_at = now()
 where name = 'Ginger Fink';

-- Chester Weber
update public.dogs d set standing_instructions = 'Schnauzer pattern. #7 blade on body. #7 reverse on head. #10 blade on both sides of the ears. 13mm comb on legs.', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Chester Weber' and d.name = 'Ula';
update public.dogs d set birth_date = '2021-10-31', dob_approximate = false, updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Chester Weber' and d.name = 'Windsor';
update public.clients set
    location_plus = '5PCC+68V Ocala, FL',
    access_notes = 'Text Lillian to let her know you are there: 352-426-5626. Driveway plus code 5PCC+68V, parking plus code 5PG7+H6F (Ocala).',
    onsite_people = 'Lillian (text on arrival). Adina helps with Windsor. Bill, Chester''s childhood friend, watches Windsor when Chester is in Europe; Bill has 5 dogs (golden retriever, pit bull).',
    note = coalesce(note || ' ; ', '') || 'Billing: invoice Stacy Amerson in Chester''s office (samerson@liveoakproperties.com); she runs checks on the 14th and 28th and mails them.',
    updated_at = now()
 where name = 'Chester Weber';
