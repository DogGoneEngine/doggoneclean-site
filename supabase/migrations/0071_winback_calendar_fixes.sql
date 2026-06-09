-- 0071_winback_calendar_fixes.sql
-- Two fixes from Paul testing the live console:
-- (1) win-back must not flag a client who already has an upcoming appointment in
--     bath_appointments (they are coming back). Limited by what is actually
--     imported into bath_appointments; the real fix is a complete calendar sync.
-- (2) the calendar shows the dogs + an unmatched flag instead of a bare "Unknown"
--     when an imported appointment never matched to a client record.

create or replace function public._winback_due_view()
returns table(id uuid, name text, email text, roster_group text, cadence_days int, last_visit date, days_since int)
language sql security definer set search_path = public, pg_temp
as $$
  select c.id, c.name, c.email, c.roster_group, c.cadence_days,
         max(v.visited_at)::date, (current_date - max(v.visited_at)::date)
    from public.clients c join public.visits v on v.client_id = c.id
   where not c.exclude_from_everything
     and not exists (
       select 1 from public.bath_appointments a
       join public.bath_subscribers s on s.id = a.subscriber_id
       where s.client_id = c.id and a.scheduled_start >= now() and a.status in ('requested','confirmed'))
   group by c.id, c.name, c.email, c.roster_group, c.cadence_days
  having (current_date - max(v.visited_at)::date) >= (case when c.cadence_days is not null then c.cadence_days + 14 else 90 end)
     and (current_date - max(v.visited_at)::date) <= coalesce((select value::int from public.app_secrets where name='winback_max_days'), 540);
$$;

create or replace function public.admin_calendar(p_days_back integer default 7, p_days_forward integer default 30)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
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
end;
$$;
revoke all on function public.admin_calendar(integer, integer) from public;
grant execute on function public.admin_calendar(integer, integer) to authenticated;
