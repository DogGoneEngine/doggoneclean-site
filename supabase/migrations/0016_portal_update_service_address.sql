-- 0016_portal_update_service_address.sql
--
-- Client self-service for a service-address change, with the same in-area
-- gate the booking funnel enforces (require_verified_service_area). The new
-- coordinates must fall inside the subscriber's own city polygon or the
-- change is rejected; on success address_verified stays true. This is why
-- address could not be a free text field in the profile editor: moving the
-- service point is a verified operation, not a contact edit.
--
-- SECURITY DEFINER (it reads cities.polygon and calls the revoked
-- _bath_point_in_area helper), scoped to the caller's auth.uid(), anon
-- revoked. City is not changeable here: the address stays within the
-- subscriber's existing city.
create or replace function public.bath_update_service_address(
  p_address_line_1 text,
  p_address_city   text,
  p_address_state  text,
  p_address_zip    text,
  p_service_lat    numeric,
  p_service_lng    numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub_id  uuid;
  v_city_id uuid;
  v_polygon jsonb;
begin
  if p_service_lat is null or p_service_lng is null then
    return jsonb_build_object('ok', false, 'error', 'coords_required');
  end if;

  select s.id, s.city_id
    into v_sub_id, v_city_id
  from public.bath_subscribers s
  where s.auth_user_id = auth.uid();

  if v_sub_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_subscriber');
  end if;

  select polygon into v_polygon from public.cities where id = v_city_id;

  if not public._bath_point_in_area(
       p_service_lng::double precision, p_service_lat::double precision, v_polygon) then
    return jsonb_build_object('ok', false, 'error', 'out_of_area');
  end if;

  update public.bath_subscribers set
    address_line_1   = p_address_line_1,
    address_city     = p_address_city,
    address_state    = p_address_state,
    address_zip      = p_address_zip,
    service_lat      = p_service_lat,
    service_lng      = p_service_lng,
    address_verified = true,
    updated_at       = now()
  where id = v_sub_id;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.bath_update_service_address(text, text, text, text, numeric, numeric) from public, anon;
grant execute on function public.bath_update_service_address(text, text, text, text, numeric, numeric) to authenticated;
