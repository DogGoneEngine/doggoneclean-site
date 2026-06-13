-- 0180_context_gap_nudge.sql
--
-- Moat agent v1, the just-in-time form (Paul, 2026-06-13). The day you are
-- scheduled to see a client, the Today stop surfaces the moat-knowledge their
-- record is still missing, one tap to open the contact sheet and fill it. It
-- self-clears: the gaps are computed live from the record, so the moment the
-- field is filled the nudge disappears, no state to manage.
--
-- WHY this is the most important agent, not a nice-to-have: Paul's 20 years of
-- per-client knowledge (how to handle this dog, what calms it, the gate trick)
-- lives in his head. Getting it into the records is simultaneously the deepest
-- moat a competitor or an AI cannot prompt past (proprietary context,
-- `dig_the_moat`), the thing that lets the business run without Paul, and what
-- a buyer would need (`clean_stays_saleable`). Scope chosen with Paul: pops up
-- before a visit; experiential knowledge PLUS the basics; highest-frequency
-- clients surface most simply because you see them most.
--
-- The gaps flagged (kept tight so it nudges, never nags):
--   experiential: how to handle the dog (no standing_instructions or notes on
--                 any active dog); gate or entry notes (no access_notes/access).
--   basics:       dog breed (any active dog missing it); visit rhythm (no
--                 cadence_days).
-- See context_gap_nudge in the Oracle.

create or replace function public._client_context_gaps(p_client_id uuid)
returns text[]
language sql stable security definer set search_path = public, pg_temp
as $$
  select array_remove(array[
    -- experiential first: the un-promptable knowledge that is the real moat
    case when p_client_id is not null
              and exists (select 1 from public.dogs d0 where d0.client_id = p_client_id)
              and not exists (
                select 1 from public.dogs d
                 where d.client_id = p_client_id
                   and coalesce(d.roster_status,'active') not in ('removed','rehomed','deceased','inactive')
                   and (coalesce(btrim(d.standing_instructions),'') <> '' or coalesce(btrim(d.notes),'') <> '')
              )
         then 'how to handle the dog' end,
    case when p_client_id is not null
              and coalesce(btrim((select access_notes from public.clients where id = p_client_id)),'') = ''
              and coalesce((select access from public.clients where id = p_client_id), '{}'::jsonb) = '{}'::jsonb
         then 'gate or entry notes' end,
    -- then the basics
    case when p_client_id is not null
              and exists (
                select 1 from public.dogs d
                 where d.client_id = p_client_id
                   and coalesce(d.roster_status,'active') not in ('removed','rehomed','deceased','inactive')
                   and coalesce(btrim(d.breed),'') = ''
              )
         then 'dog breed' end,
    case when p_client_id is not null
              and (select cadence_days from public.clients where id = p_client_id) is null
         then 'visit rhythm' end
  ], null);
$$;
revoke all on function public._client_context_gaps(uuid) from public, anon;
grant execute on function public._client_context_gaps(uuid) to authenticated, service_role;

-- admin_today_appointments: same as 0171, plus context_gaps per stop.
CREATE OR REPLACE FUNCTION public.admin_today_appointments()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  result := coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'client_id', s.client_id,
      'client', c.name,
      'fallback', nullif((select string_agg(bd.name, ', ') from public.bath_dogs bd where bd.subscriber_id = a.subscriber_id), ''),
      'scheduled_start', a.scheduled_start,
      'service_type', a.service_type,
      'status', a.status,
      'amount_cents', a.amount_cents,
      'dog_count', a.dog_count,
      'inbound_at', vt.inbound_at,
      'arrived_at', vt.arrived_at,
      'departed_at', vt.departed_at,
      'special_request', vt.special_request,
      'context_gaps', to_jsonb(public._client_context_gaps(s.client_id)),
      'followups', coalesce((
        select jsonb_agg(jsonb_build_object('dog', dd.name, 'body', f.body) order by dd.name)
          from public.dog_followups f join public.dogs dd on dd.id = f.dog_id
         where dd.client_id = s.client_id and f.status = 'open'), '[]'::jsonb)
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    left join lateral (
      select inbound_at, arrived_at, departed_at, special_request
        from public.visits v
       where v.appointment_id = a.id
       order by v.created_at limit 1
    ) vt on true
    where (a.scheduled_start at time zone 'America/New_York')::date = (now() at time zone 'America/New_York')::date
      and a.status not in ('cancelled','no_show','skipped')
  ), '[]'::jsonb);
  if public._admin_role() = 'operator' then
    result := coalesce((select jsonb_agg(e - 'amount_cents') from jsonb_array_elements(result) e), '[]'::jsonb);
  end if;
  return result;
end;
$function$;
revoke all on function public.admin_today_appointments() from public, anon;
grant execute on function public.admin_today_appointments() to authenticated, service_role;
