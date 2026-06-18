-- 0214_shadow_ban_stops_the_chase.sql
--
-- Verified gap (Paul 2026-06-18, "I hope a ban is not just tagging the client"):
-- shadow ban promises "they stay a client and still get served, but you stop
-- chasing them: no win-back, no outreach." The live win-back view already honors
-- that (nofly_level is distinct from 'shadow'), but two other growth/chase agents
-- did not, so a shadow-banned client could still be chased:
--   * _retention_scan raised an "Overdue: <name>, send a quick message to rebook"
--     briefing for any standing client past cadence, filtering only
--     exclude_from_everything, never the shadow tier.
--   * _capacity_scan excluded 'banned' but not 'shadow', so a shadow client could
--     still be named as someone being squeezed for capacity.
-- Both now skip shadow (and banned). This is the difference between shadow ban
-- being real and being just a tag. Service-side views (the book, reports, sync,
-- Riker context) are deliberately left alone: a shadow client is still served and
-- still shows where you work, just never chased.

-- Retention nudge: do not chase a shadow-banned (or hard-banned) client.
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
       and c.nofly_level is distinct from 'shadow'
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

-- Capacity nudge: exclude shadow as well as banned, so a shadow client is not
-- named as someone to open capacity for.
create or replace function public._capacity_scan()
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  c_threshold constant int := 10;
  c_horizon constant int := 28;
  r record;
  city record;
  v_tz text;
  v_dur int;
  v_first timestamptz;
  v_lead int;
  v_win record;
  v_squeezed jsonb := '[]'::jsonb;
  v_unparsed jsonb := '[]'::jsonb;
  v_cities jsonb := '[]'::jsonb;
  v_city_alert boolean := false;
  v_worst int := 0;
  v_count int := 0;
  v_body text;
begin
  for city in
    select ct.id, ct.slug, ct.hb_timezone, coalesce(ct.hb_smoothcoat_minutes, 30) as dur
      from public.cities ct
     where exists (select 1 from public.bath_availability_windows w
                    where w.city_id = ct.id and w.active)
  loop
    select min(s.slot_start) into v_first
      from public.bath_open_slots(city.id, now(), now() + make_interval(days => c_horizon), city.dur) s;
    v_lead := case when v_first is null then null
                   else (v_first at time zone city.hb_timezone)::date - current_date end;
    v_cities := v_cities || jsonb_build_object(
      'city', city.slug, 'lead_days', v_lead);
    if v_lead is null or v_lead > c_threshold then
      v_city_alert := true;
      v_worst := greatest(v_worst, coalesce(v_lead, c_horizon + 1));
    end if;
  end loop;

  for r in
    select c.id, c.name, c.availability_hard, c.availability_not_days,
           c.visit_minutes, s.id as subscriber_id,
           coalesce(s.city_id, (select id from public.cities where slug = 'ocala')) as city_id
      from public.clients c
      left join lateral (
        select sb.id, sb.city_id from public.bath_subscribers sb
         where sb.client_id = c.id order by sb.created_at limit 1
      ) s on true
     where c.archived_at is null
       and not c.exclude_from_everything
       and coalesce(c.nofly_level, '') not in ('banned', 'shadow')
       and not exists (
         select 1 from public.bath_appointments a
           join public.bath_subscribers sb2 on sb2.id = a.subscriber_id
          where sb2.client_id = c.id
            and a.scheduled_start > now()
            and a.status not in ('cancelled', 'no_show', 'skipped', 'completed')
       )
  loop
    select hb_timezone into v_tz from public.cities where id = r.city_id;
    if v_tz is null then continue; end if;

    v_dur := case when r.subscriber_id is not null
                  then public.clean_effective_duration_minutes(r.subscriber_id)
                  else greatest(coalesce(r.visit_minutes, 60), 30) end;

    select * into v_win from public._capacity_window(r.availability_hard, r.availability_not_days);
    if not v_win.o_parsed and coalesce(r.availability_hard, '') <> '' then
      v_unparsed := v_unparsed || jsonb_build_object('name', r.name, 'hard', r.availability_hard);
    end if;

    select min(s.slot_start) into v_first
      from public.bath_open_slots(r.city_id, now(), now() + make_interval(days => c_horizon), v_dur) s
     where extract(dow from s.slot_start at time zone v_tz)::int = any(v_win.o_dows)
       and (s.slot_start at time zone v_tz)::time >= v_win.o_start
       and (s.slot_start at time zone v_tz)::time <= v_win.o_end_start;

    v_lead := case when v_first is null then null
                   else (v_first at time zone v_tz)::date - current_date end;

    if v_lead is null or v_lead > c_threshold then
      v_count := v_count + 1;
      v_worst := greatest(v_worst, coalesce(v_lead, c_horizon + 1));
      v_squeezed := v_squeezed || jsonb_build_object(
        'client_id', r.id, 'name', r.name, 'lead_days', v_lead,
        'constraint', coalesce(r.availability_hard,
          case when coalesce(array_length(r.availability_not_days, 1), 0) > 0
               then 'not ' || array_to_string(r.availability_not_days, '/') else null end),
        'minutes', v_dur);
    end if;
  end loop;

  if v_count = 0 and not v_city_alert then
    return 0;
  end if;

  if exists (select 1 from public.briefings
              where agent_key = 'capacity' and status in ('new', 'read')) then
    return 0;
  end if;

  v_body := case when v_count > 0 then
      format('%s client%s would wait more than %s days for a slot that fits their schedule: %s. ',
        v_count, case when v_count = 1 then '' else 's' end, c_threshold,
        (select string_agg(format('%s (%s)', e->>'name',
            coalesce((e->>'lead_days') || ' days', 'nothing in ' || c_horizon || ' days')), ', ')
           from jsonb_array_elements(v_squeezed) e))
    else '' end
    || (select string_agg(format('A new %s client''s first opening: %s.',
          e->>'city', coalesce((e->>'lead_days') || ' days out', 'none inside ' || c_horizon || ' days')), ' ')
          from jsonb_array_elements(v_cities) e)
    || ' Opening an extra day (an open exception on the Schedule floor) is the release valve.';

  insert into public.briefings (agent_key, department, severity, title, body, evidence)
  values ('capacity', 'operations',
    case when v_worst > 14 then 'alert' else 'signal' end,
    case when v_count > 0
      then format('Booking lead: %s client%s would wait over %s days', v_count,
                  case when v_count = 1 then '' else 's' end, c_threshold)
      else 'Booking lead: a new client would wait too long' end,
    v_body,
    jsonb_build_object('threshold_days', c_threshold, 'horizon_days', c_horizon,
      'squeezed', v_squeezed, 'new_client', v_cities, 'unparsed_constraints', v_unparsed));

  update public.agents set is_active = true, updated_at = now() where agent_key = 'capacity';
  return 1;
end;
$function$;
