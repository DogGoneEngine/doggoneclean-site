-- 0242_calendar_cycle_rate.sql
--
-- The Calendar floor (Laelaps) shows past appointments, and Paul wants each
-- past visit's CYCLE RATE on the right of its card: pay divided by door-to-door
-- time (inbound to departure), the dollars-per-hour figure that already lives in
-- the Time is Money ledger as "Cycle Rate". This adds that number to
-- admin_calendar so the card can render it, computed exactly the way the ledger
-- does (paid / ((departed_at - inbound_at) in hours)), null when the visit is
-- missing pay or the door-to-door stamps. Money-bearing, so it is stripped for
-- the operator role just like amount_cents and payment_status already are.
--
-- Applied to dgc-prod 2026-06-23.

CREATE OR REPLACE FUNCTION public.admin_calendar(p_days_back integer DEFAULT 7, p_days_forward integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  result := coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'scheduled_start', a.scheduled_start, 'scheduled_end', a.scheduled_end,
      'client', c.name,
      'unmatched', c.name is null,
      'fallback', nullif((select string_agg(bd.name, ', ') from public.bath_dogs bd where bd.subscriber_id = a.subscriber_id), ''),
      'service_type', a.service_type, 'status', a.status, 'source', a.source,
      'payment_status', a.payment_status, 'amount_cents', a.amount_cents,
      'dog_count', a.dog_count, 'duration_minutes', a.duration_minutes, 'notes', a.notes,
      'cycle_rate', v.cycle_rate
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    left join lateral (
      select case when vv.amount_collected_cents is not null
                   and vv.inbound_at is not null and vv.departed_at > vv.inbound_at
                  then round((vv.amount_collected_cents / 100.0)
                       / (extract(epoch from (vv.departed_at - vv.inbound_at)) / 3600.0))::int
                  end as cycle_rate
      from public.visits vv
      where vv.appointment_id = a.id
      order by (vv.departed_at is not null) desc, (vv.inbound_at is not null) desc, vv.created_at desc
      limit 1
    ) v on true
    where a.scheduled_start >= now() - make_interval(days => p_days_back)
      and a.scheduled_start <= now() + make_interval(days => p_days_forward)
  ), '[]'::jsonb);
  if public._admin_role() = 'operator' then
    result := coalesce((
      select jsonb_agg(((e - 'amount_cents') - 'payment_status') - 'cycle_rate')
      from jsonb_array_elements(result) e
    ), '[]'::jsonb);
  end if;
  return result;
end;
$function$;
