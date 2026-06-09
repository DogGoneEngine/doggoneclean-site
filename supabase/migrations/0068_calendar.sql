-- 0068_calendar.sql
-- Calendar floor: the appointment schedule, joined through the subscriber to the
-- client name. Read-only agenda over a window around today (the booking surface
-- is the /book funnel).
create or replace function public.admin_calendar(p_days_back integer default 7, p_days_forward integer default 30)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'scheduled_start', a.scheduled_start, 'scheduled_end', a.scheduled_end,
      'client', c.name, 'service_type', a.service_type, 'status', a.status,
      'payment_status', a.payment_status, 'amount_cents', a.amount_cents,
      'dog_count', a.dog_count, 'duration_minutes', a.duration_minutes, 'notes', a.notes
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    where a.scheduled_start >= now() - make_interval(days => p_days_back)
      and a.scheduled_start <= now() + make_interval(days => p_days_forward)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_calendar(integer, integer) from public;
grant execute on function public.admin_calendar(integer, integer) to authenticated;
