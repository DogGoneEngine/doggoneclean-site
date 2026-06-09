-- 0083_client_access_notes.sql
-- Client-level "how to get in" notes (gate / door / lock codes, location and
-- parking instructions, plus codes) transcribed from the Drive contact sheets, so
-- they are on Paul's phone at the stop. A dedicated human-readable field on
-- clients, distinct from the jsonb `access` and the general `note`. Populated for
-- the same first batch (the 2026-06-09 route clients) from sheets already read;
-- real data only, blank sheets left null (Mary Beth Anderson had none). Keyed by
-- name so it replays after a reseed. See client_access_notes.

alter table public.clients add column if not exists access_notes text;

create or replace function public.admin_set_client_access(p_client_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.clients set access_notes = nullif(btrim(p_text), ''), updated_at = now() where id = p_client_id;
  if not found then raise exception 'client not found'; end if;
end;
$$;
revoke all on function public.admin_set_client_access(uuid, text) from public;
grant execute on function public.admin_set_client_access(uuid, text) to authenticated;

update public.clients set access_notes =
  'Dog is sometimes at home, sometimes at the Recharge Clinic. Bottom-lock code on the front door at the house: 1206 (locks automatically).', updated_at = now()
 where name = 'Cynthia Tieche';

update public.clients set access_notes =
  'House is all the way at the end of the driveway.', updated_at = now()
 where name = 'Donna DiPasqua';

update public.clients set access_notes =
  'Garage door code 0223 to enter. Gate code 1105#. Door code 4119. New house door code 3489. Driveway plus code FQH7+5RX Evinston (new house). Park at Isaiah''s house, plus code FQG6+XX5 Evinston.', updated_at = now()
 where name = 'Lisa Irwin';
