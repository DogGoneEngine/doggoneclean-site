-- 0144: the Availability watcher (capacity_watchdog_agent, Paul 2026-06-10).
--
-- The question it answers daily: if a client came looking for an appointment
-- today, how long until they could actually get one, measured against THEIR
-- real constraints (hard windows, not-days, their own visit length)? And the
-- same for a hypothetical brand-new client per city. When anyone's wait would
-- exceed the threshold (10 days, Paul's number), one card lands on Today, so
-- Paul can open days or add capacity BEFORE a client hits the wall, instead
-- of finding out from a frustrated booking attempt.
--
-- Scope: every active client (not archived, not excluded, not hard-banned)
-- with no upcoming appointment. suppress_winback clients are INCLUDED: this
-- is an internal capacity signal, never outreach, and Mary Jane hitting a
-- 3-week wall in October matters exactly as much as anyone else's.
--
-- Constraints come from the structured columns: availability_not_days is
-- exact; availability_hard is free text, parsed by _capacity_window for the
-- patterns that actually exist in the book (day names, weekday/weekend,
-- "after 5pm", "before 4pm" / "no later than 5pm", "5pm or 6pm",
-- "12:00-15:00", a bare "12pm"). Text it cannot read is treated as
-- unconstrained and flagged on the card (honest about its own blind spots,
-- real_data_only). Slots come from bath_open_slots, the same engine every
-- booking path uses, so the watcher and the booking surface can never
-- disagree.

create or replace function public._capacity_window(
  p_hard text,
  p_not_days text[],
  out o_dows int[],
  out o_start time,
  out o_end_start time,
  out o_parsed boolean
)
language plpgsql
immutable
set search_path to ''
as $$
declare
  v_t text := lower(coalesce(p_hard, ''));
  v_d text;
  v_x int;
  v_named int[] := array[]::int[];
  m text[];
  h1 int; h2 int;
begin
  o_dows := array[0,1,2,3,4,5,6];
  o_start := time '00:00';
  o_end_start := time '23:59';
  o_parsed := true;

  if p_not_days is not null then
    foreach v_d in array p_not_days loop
      v_x := case lower(left(v_d, 3))
        when 'sun' then 0 when 'mon' then 1 when 'tue' then 2 when 'wed' then 3
        when 'thu' then 4 when 'fri' then 5 when 'sat' then 6 else null end;
      if v_x is not null then
        o_dows := array_remove(o_dows, v_x);
      end if;
    end loop;
  end if;

  if v_t = '' then
    return;
  end if;
  o_parsed := false;

  -- Day-of-week language.
  if v_t like '%sunday%' then v_named := v_named || 0; end if;
  if v_t like '%monday%' then v_named := v_named || 1; end if;
  if v_t like '%tuesday%' then v_named := v_named || 2; end if;
  if v_t like '%wednesday%' then v_named := v_named || 3; end if;
  if v_t like '%thursday%' then v_named := v_named || 4; end if;
  if v_t like '%friday%' then v_named := v_named || 5; end if;
  if v_t like '%saturday%' then v_named := v_named || 6; end if;
  if v_t like '%weekend%' then v_named := v_named || array[0, 6]; end if;
  if v_t like '%weekday%' then v_named := v_named || array[1, 2, 3, 4, 5]; end if;
  if array_length(v_named, 1) is not null then
    select coalesce(array_agg(x), array[]::int[]) into o_dows
      from unnest(o_dows) x where x = any(v_named);
    o_parsed := true;
  end if;

  -- Time-of-day language, most specific first.
  m := regexp_match(v_t, '(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})');
  if m is not null then
    o_start := make_time(m[1]::int, m[2]::int, 0);
    o_end_start := make_time(m[3]::int, m[4]::int, 0);
    o_parsed := true;
  else
    m := regexp_match(v_t, '(\d{1,2})\s*pm\s+or\s+(\d{1,2})\s*pm');
    if m is not null then
      h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
      h2 := m[2]::int; if h2 < 12 then h2 := h2 + 12; end if;
      o_start := make_time(h1, 0, 0);
      o_end_start := make_time(least(h2 + 1, 23), 0, 0);
      o_parsed := true;
    else
      m := regexp_match(v_t, 'after\s+(\d{1,2})(:\d{2})?\s*pm');
      if m is not null then
        h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
        o_start := make_time(h1, 0, 0);
        o_parsed := true;
      end if;
      m := regexp_match(v_t, '(?:no later than|before|by)\s+(\d{1,2})(:\d{2})?\s*pm');
      if m is not null then
        h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
        o_end_start := make_time(h1, 0, 0);
        o_parsed := true;
      end if;
      if not o_parsed then
        m := regexp_match(v_t, '(\d{1,2})\s*pm');
        if m is not null then
          h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
          o_start := make_time(greatest(h1 - 1, 0), 0, 0);
          o_end_start := make_time(least(h1 + 1, 23), 0, 0);
          o_parsed := true;
        end if;
      end if;
    end if;
  end if;

  -- Never let a parse mishap zero the schedule out entirely.
  if array_length(o_dows, 1) is null then
    o_dows := array[0,1,2,3,4,5,6];
    o_parsed := false;
  end if;
end;
$$;
revoke all on function public._capacity_window(text, text[]) from public;
grant execute on function public._capacity_window(text, text[]) to service_role;

create or replace function public._capacity_scan()
returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  c_threshold constant int := 10;          -- alert when the wait exceeds this
  c_horizon constant int := 28;            -- matches the booking horizon
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
  -- A hypothetical NEW client per city with availability windows: the
  -- unconstrained lead time, sized at the city's default first-dog visit.
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

  -- Every active client with no upcoming appointment: their personal lead.
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
       and coalesce(c.nofly_level, '') <> 'banned'
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
    return 0;  -- nothing squeezed; silence is the correct report
  end if;

  -- One card, not one per client; re-card only after the last one is closed.
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
$$;
revoke all on function public._capacity_scan() from public;
grant execute on function public._capacity_scan() to service_role;

create or replace function public.admin_capacity_check()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare v int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v := public._capacity_scan();
  return jsonb_build_object('alerts_created', v);
end;
$$;
revoke all on function public.admin_capacity_check() from public;
grant execute on function public.admin_capacity_check() to authenticated;

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('capacity', 'Availability watcher', 'operations',
   'Watches booking lead time: how long each client without an upcoming appointment would wait for a slot that fits their real availability, plus a hypothetical new client per city. Cards Today when anyone''s wait passes 10 days.',
   '15 11 * * *', false)
on conflict (agent_key) do nothing;

select cron.schedule('capacity-daily', '15 11 * * *', 'select public._capacity_scan();');
