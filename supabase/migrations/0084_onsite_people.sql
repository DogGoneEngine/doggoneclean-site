-- 0084_onsite_people.sql
-- "Who you'll meet on site": the people Paul might encounter at an appointment
-- (housekeepers, family, staff, who lets him in, who to ask for), transcribed
-- from the contact sheets. A dedicated field on clients, shown and editable on the
-- sheet, captured in the same Drive cross-reference pass. Populated for the route
-- clients from sheets already read; blank where the sheet had no one. Keyed by
-- name so it replays after a reseed. See client_onsite_people.

alter table public.clients add column if not exists onsite_people text;

create or replace function public.admin_set_client_onsite(p_client_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.clients set onsite_people = nullif(btrim(p_text), ''), updated_at = now() where id = p_client_id;
  if not found then raise exception 'client not found'; end if;
end;
$$;
revoke all on function public.admin_set_client_onsite(uuid, text) from public;
grant execute on function public.admin_set_client_onsite(uuid, text) to authenticated;

update public.clients set onsite_people =
  'Gloria is the housekeeper; her car may be in the driveway.', updated_at = now()
 where name = 'Cynthia Tieche';

update public.clients set onsite_people =
  'Lou is the chef. The man with the beard and shaved head is Isaiah. The granddaughter is Ila (uncertain on the name). Meg was Lisa''s assistant but has not been there since 9/2023. Lisa is moving to Micanopy.', updated_at = now()
 where name = 'Lisa Irwin';

update public.clients set onsite_people =
  'Jessie has helped get Fledge out of the house.', updated_at = now()
 where name = 'Donna DiPasqua';
