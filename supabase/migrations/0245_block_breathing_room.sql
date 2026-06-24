-- Breathing room in every visit block (Paul, 2026-06-24).
-- The block length was the operator's typical on-site time with NO cushion:
-- hb_buffer_minutes sat at 0, and even the non-zero buffer only ever applied on
-- the history-rich (median) path, never to the static estimate or city default.
-- So a block equalled the work time exactly and a late start ran past it.
-- Two changes:
--   1) The per-city buffer is now added to EVERY block (reality-median, static
--      estimate, and city default alike), then rounded up to 5 minutes and held
--      at or above the minimum stop.
--   2) hb_buffer_minutes is set to 30 for Ocala and The Villages.
-- Deliberately a flat 30 while Paul tightens his own schedule adherence (a
-- cushion tied to actual lateness would hide the lateness and remove the
-- pressure to improve). Later this may shrink toward a small honest margin with
-- adherence tracked as its own separate metric.

CREATE OR REPLACE FUNCTION public.clean_effective_duration_minutes(p_subscriber_id uuid, p_service_type text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_city       public.cities%rowtype;
  v_client     uuid;
  v_hist       integer;
  v_live       integer;
  v_median     numeric;
  v_n          integer;
  v_default    integer;
  v_min        integer;
  v_buffer     integer;
  v_base       integer;
  v_has_double boolean;
begin
  select c.* into v_city
    from public.cities c
    join public.bath_subscribers s on s.city_id = c.id
   where s.id = p_subscriber_id;
  if not found then
    return null;
  end if;

  select client_id into v_client from public.bath_subscribers where id = p_subscriber_id;
  if v_client is not null then
    select coalesce(
             case p_service_type
               when 'full_groom' then visit_minutes_groom
               when 'nails' then visit_minutes_nails
               else null
             end,
             visit_minutes)
      into v_hist
      from public.clients where id = v_client;

    -- Reality first: median of the last 5 completed visits for this service.
    select count(*), percentile_cont(0.5) within group (order by sub.actual_minutes)
      into v_n, v_median
      from (
        select v.actual_minutes
          from public.visits v
         where v.client_id = v_client
           and v.actual_minutes is not null and v.actual_minutes > 0
           and v.visited_at <= now()
           and (p_service_type is null
                or coalesce(v.service_type, 'full_groom') = p_service_type)
         order by v.visited_at desc
         limit 5
      ) sub;
    if coalesce(v_n, 0) >= 3 then
      v_live := round(v_median)::integer;
    end if;
  end if;

  select bool_or(coat_tier = 'doublecoat') into v_has_double
    from public.bath_dogs where subscriber_id = p_subscriber_id and active;

  v_default := case when coalesce(v_has_double, false)
                    then v_city.hb_doublecoat_minutes
                    else v_city.hb_smoothcoat_minutes end;
  v_min := coalesce(v_city.hb_min_stop_minutes, 30);
  v_buffer := coalesce(v_city.hb_buffer_minutes, 0);

  -- Base block from reality, else the static estimate, else the city default,
  -- else the floor. The breathing-room buffer is added to EVERY block, then
  -- rounded up to the nearest 5 minutes and held at or above the minimum stop.
  v_base := coalesce(v_live, v_hist, v_default, v_min);
  return greatest(v_min, (ceil((v_base + v_buffer) / 5.0) * 5)::integer);
end;
$function$;

update public.cities set hb_buffer_minutes = 30 where name in ('Ocala', 'The Villages');
