-- 0240_booking_context_regular_dogs_only.sql
--
-- Align the owner-booking dog-count fallback with appointment_counts_regular_dogs.
-- _client_booking_context.o_dogs (used by admin_book_appointment when the owner
-- books a client without hand-picking dogs) counted regular PLUS occasional dogs,
-- so it would assume 4 for Tonya Hunt when her recurring visit is 2 (Kai, Lydia);
-- the occasional dogs are on-demand extras, not part of the routine visit. Default
-- to the regular roster only; when an occasional dog actually comes that day it is
-- added to that specific appointment via admin_book_appointment's p_dog_ids.
-- Only o_dogs changes; duration (o_dur) and price are computed separately.

CREATE OR REPLACE FUNCTION public._client_booking_context(p_client_id uuid, OUT o_sub uuid, OUT o_city uuid, OUT o_dur integer, OUT o_subscription uuid, OUT o_price integer, OUT o_service text, OUT o_dogs integer)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  select s.id, s.city_id into o_sub, o_city
    from public.bath_subscribers s where s.client_id = p_client_id
    order by s.created_at limit 1;
  if o_sub is null then
    insert into public.bath_subscribers (client_id, city_id)
    values (p_client_id, (select id from public.cities where slug = 'ocala'))
    returning id, city_id into o_sub, o_city;
  end if;
  if o_city is null then
    select id into o_city from public.cities where slug = 'ocala';
    update public.bath_subscribers set city_id = o_city where id = o_sub;
  end if;
  o_dur := coalesce(public.clean_effective_duration_minutes(o_sub),
                    greatest(coalesce((select visit_minutes from public.clients where id = p_client_id), 60), 30));
  select b.id, b.base_price_cents, b.service_type
    into o_subscription, o_price, o_service
    from public.bath_subscriptions b
   where b.subscriber_id = o_sub and b.status = 'active'
   order by b.created_at desc limit 1;
  if o_service is null then
    select case when c.service_type in ('full_groom','bath','nails') then c.service_type else 'full_groom' end
      into o_service from public.clients c where c.id = p_client_id;
  end if;
  select greatest(1, count(*))::int into o_dogs
    from public.dogs d
   where d.client_id = p_client_id
     and coalesce(d.roster_status, 'regular') = 'regular';
end;
$function$;
