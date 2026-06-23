-- 0233_retention_respects_winback_suppression.sql
--
-- Mary Jane Hunt kept landing on the Today feed as a lapsed client to chase, even
-- though she has a confirmed August appointment on the books and is flagged as a
-- seasonal self-rebooker (suppress_winback = true, away roughly half the year,
-- books her own block when she returns). The win-back agent already honored both
-- guards (clients.suppress_winback and an upcoming booked appointment), so it left
-- her alone. The trouble is the RETENTION agent: it raises the very same
-- "Overdue: <name>, send a quick message to rebook" card for any standing client
-- past 1.5x cadence, and it never checked either guard. To Paul those are the same
-- "win-back card," so suppressing one and not the other meant she still got chased.
--
-- This brings _retention_scan in line with _winback_due_view: it now skips
--   * archived clients (already implied for win-back),
--   * clients with suppress_winback = true (the seasonal / self-managed lever), and
--   * clients who already have an upcoming requested/confirmed/tentative appointment
--     (they have not fallen through the cracks; they are on the books).
-- It already skipped exclude_from_everything and shadow-banned clients; those stay.
-- The future-appointment guard is the durable, general fix Paul asked for: a client
-- with an appointment in the schedule is never pursued as a fell-through-the-cracks
-- client. suppress_winback covers the gap between her August visit and her next
-- self-booked block, so she is never chased while away.
--
-- See client_no_winback_flag and shadow_ban_stops_the_chase in CLEAN_ORACLE.md.

create or replace function public._retention_scan()
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare v_created int := 0; r record;
begin
  for r in
    select c.id, c.name, c.cadence_days, max(v.visited_at)::date as last_visit,
           (current_date - max(v.visited_at)::date) as days_since
      from public.clients c join public.visits v on v.client_id = c.id
     where c.roster_group = 'standing' and c.cadence_days is not null
       and not c.exclude_from_everything
       and c.archived_at is null
       and coalesce(c.suppress_winback, false) = false
       and c.nofly_level is distinct from 'shadow'
       and not exists (
         select 1 from public.bath_appointments a
         join public.bath_subscribers s on s.id = a.subscriber_id
         where s.client_id = c.id and a.scheduled_start >= now()
           and a.status in ('requested','confirmed','tentative'))
     group by c.id, c.name, c.cadence_days
    having (current_date - max(v.visited_at)::date) > c.cadence_days * 1.5
  loop
    if not exists (select 1 from public.briefings where agent_key='retention'
        and (evidence->>'client_id')::uuid = r.id and status in ('new','read') and created_at > now() - interval '20 days')
       and not exists (select 1 from public.briefings where agent_key='retention'
        and (evidence->>'client_id')::uuid = r.id and disposition='intentional') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('retention','growth',
        case when r.days_since > r.cadence_days * 2 then 'alert' else 'signal' end,
        'Overdue: '||r.name,
        format('%s runs on an every-%s-day rhythm but has not been in for %s days (last visit %s). A standing client slipping past their cadence is an early churn signal; a quick message to rebook is worth it.',
          r.name, r.cadence_days, r.days_since, to_char(r.last_visit,'Mon DD')),
        jsonb_build_object('client_id', r.id, 'cadence_days', r.cadence_days, 'days_since', r.days_since, 'last_visit', r.last_visit));
      v_created := v_created + 1;
    end if;
  end loop;
  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='retention'; end if;
  return v_created;
end;
$function$;

-- Clear the stale card already sitting on Paul's Today feed for Mary Jane Hunt.
-- Resolve any open retention briefing for a client that the rescoped scan would now
-- skip (suppressed, archived, excluded, shadow, or already holding a future booking),
-- so the feed reflects the new rule immediately instead of waiting for a dismiss.
update public.briefings b
   set status = 'resolved', acted_at = now()
 where b.agent_key = 'retention'
   and b.status in ('new','read')
   and exists (
     select 1 from public.clients c
      where c.id = (b.evidence->>'client_id')::uuid
        and (
          coalesce(c.suppress_winback, false) = true
          or c.archived_at is not null
          or c.exclude_from_everything
          or c.nofly_level = 'shadow'
          or exists (
            select 1 from public.bath_appointments a
            join public.bath_subscribers s on s.id = a.subscriber_id
            where s.client_id = c.id and a.scheduled_start >= now()
              and a.status in ('requested','confirmed','tentative'))
        ));
