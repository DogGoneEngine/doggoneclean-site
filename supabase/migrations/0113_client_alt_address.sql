-- 0113_client_alt_address.sql
-- A second, alternate address for clients who alternate between two locations (Lisa
-- Irwin grooms at home and at her office, the LILAC Foundation). Stored as a labeled
-- address on the client; shown clickable on the contact sheet alongside the primary
-- location. Flows to the UI via admin_get_client's to_jsonb(c.*). See
-- client_address_maps_link.

alter table public.clients
  add column if not exists alt_label   text,
  add column if not exists alt_address text;

create or replace function public.admin_set_client_alt(p_client_id uuid, p_label text, p_address text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.clients
     set alt_label = nullif(btrim(p_label), ''),
         alt_address = nullif(btrim(p_address), ''),
         updated_at = now()
   where id = p_client_id;
  if not found then raise exception 'client not found'; end if;
end;
$$;
revoke all on function public.admin_set_client_alt(uuid, text, text) from public;
grant execute on function public.admin_set_client_alt(uuid, text, text) to authenticated;

-- Lisa Irwin's office (alternate to her home).
update public.clients
   set alt_label = 'Office (LILAC Foundation)',
       alt_address = '2322 NE 8th Rd, Ocala, FL 34470'
 where name = 'Lisa Irwin';
