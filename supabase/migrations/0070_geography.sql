-- 0070_geography.sql
-- Geography floor: the service cities and where the clients actually are, by
-- zone. Data view; the interactive Google Map (JS API + polygon overlay) is the
-- enhancement on top of this same data.
create or replace function public.admin_geography_summary()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_cities jsonb; v_zones jsonb; v_geocoded int; v_total int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'name', name, 'state', state, 'active', hb_active, 'has_perimeter', polygon is not null,
      'center_lat', center_lat, 'center_lng', center_lng) order by hb_active desc, name), '[]'::jsonb)
    into v_cities from public.cities;
  select coalesce(jsonb_agg(jsonb_build_object('zone', zone, 'count', n) order by n desc), '[]'::jsonb)
    into v_zones from (
      select location_zone zone, count(*) n from public.clients
       where not exclude_from_everything and nullif(trim(location_zone),'') is not null
       group by location_zone) z;
  select count(*) filter (where geo_lat is not null and geo_lng is not null), count(*)
    into v_geocoded, v_total from public.clients where not exclude_from_everything;
  return jsonb_build_object('cities', v_cities, 'zones', v_zones, 'geocoded', v_geocoded, 'total_clients', v_total);
end;
$$;
revoke all on function public.admin_geography_summary() from public;
grant execute on function public.admin_geography_summary() to authenticated;
