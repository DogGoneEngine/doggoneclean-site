-- 0226_calendar_masks_money_for_operators.sql
--
-- Close the calendar money leak. orbit_roles_operator_masked says an employee
-- never sees the business's money, and admin_today_appointments already strips
-- the per-stop dollar amount for the operator role. admin_calendar was never
-- given the same treatment, so an operator opening the Calendar floor could see
-- each booking's amount_cents and payment_status, i.e. what every client pays
-- and whether they have paid. That contradicts the rule.
--
-- Fix: after building the calendar, if the caller is an operator, strip
-- amount_cents and payment_status from every entry, server-side, so the boundary
-- survives a redesign of the Calendar screen. The Calendar UI already guards on
-- `amount_cents != null` and does not render payment_status, so the masked
-- payload renders cleanly. Recreated from the live definition.

create or replace function public.admin_calendar(p_days_back integer default 7, p_days_forward integer default 30)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
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
      'dog_count', a.dog_count, 'duration_minutes', a.duration_minutes, 'notes', a.notes
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    where a.scheduled_start >= now() - make_interval(days => p_days_back)
      and a.scheduled_start <= now() + make_interval(days => p_days_forward)
  ), '[]'::jsonb);
  -- Operators (Employees) never see the business's money: strip the price and
  -- the paid/unpaid status, the same way admin_today_appointments does.
  if public._admin_role() = 'operator' then
    result := coalesce((
      select jsonb_agg((e - 'amount_cents') - 'payment_status')
      from jsonb_array_elements(result) e
    ), '[]'::jsonb);
  end if;
  return result;
end;
$function$;

revoke all on function public.admin_calendar(integer, integer) from public, anon;
grant execute on function public.admin_calendar(integer, integer) to authenticated, service_role;
