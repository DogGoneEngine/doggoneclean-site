-- 0165: Paul's 2026-06-12 evening batch, three pieces.
--
-- (1) The media inbox grows into the asset library (Library floor in Orbit).
-- Paul wants a Squarespace-style home for every good photo or video he
-- comes across, even with no use for it yet, instead of losing it in the
-- Google Photos stream. New status 'shelf' = kept for later, no assigned
-- use. admin_set_inbox_status lets the panel (and Claude) move items
-- between new / shelf / used / dropped.
--
-- (2) Schedule adherence gets its historical baseline in the database.
-- legacy/data/adherence_history.json (1,224 Time is Money rows matched
-- against the calendar) seeds schedule_adherence_history, and
-- admin_schedule_adherence returns a 'baseline' block beside the live
-- tracker-era numbers. Two series, never blended: the history is the
-- benchmark to beat, the live series is the new operation's truth.
-- Seed data: supabase/seed_adherence.sql, regenerated from the JSON by
-- scripts/gen_adherence_seed.py.
--
-- (3) admin_prospectus: every number behind the living buyer prospectus
-- (living_prospectus), computed from the operating tables on every call so
-- the pitch can never go stale or drift from the truth.
--
-- Applied to dgc-prod 2026-06-12.

alter table public.site_inbox drop constraint if exists site_inbox_status_check;
alter table public.site_inbox add constraint site_inbox_status_check
  check (status in ('new', 'shelf', 'used', 'dropped'));

create or replace function public.admin_set_inbox_status(p_id uuid, p_status text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_status not in ('new', 'shelf', 'used', 'dropped') then
    raise exception 'bad status';
  end if;
  update public.site_inbox set status = p_status where id = p_id;
  if not found then raise exception 'inbox item not found'; end if;
end;
$$;
revoke all on function public.admin_set_inbox_status(uuid, text) from public, anon;
grant execute on function public.admin_set_inbox_status(uuid, text) to authenticated, service_role;

create table if not exists public.schedule_adherence_history (
  id bigint generated always as identity primary key,
  day date not null,
  client text not null,
  delta_min int not null,
  left_delta_min int,
  on_site_min int,
  stop_index int
);
comment on table public.schedule_adherence_history is
  'Plan-vs-reality baseline from the Time is Money sheet matched against the calendar (2023-2026). Source of truth: legacy/data/adherence_history.json; matched rows with a usable arrival delta only.';
alter table public.schedule_adherence_history enable row level security;

create or replace function public.admin_schedule_adherence(p_days int default 90)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  with base as (
    select vi.id,
           vi.arrived_at,
           vi.departed_at,
           a.scheduled_start,
           coalesce(c.name, nullif(btrim(coalesce(s.first_name, '') || ' ' || coalesce(s.last_name, '')), '')) as client_name,
           (vi.arrived_at at time zone 'America/New_York')::date as day_local,
           round(extract(epoch from (vi.arrived_at - a.scheduled_start)) / 60.0)::int as delta_min
      from public.visits vi
      join public.bath_appointments a on a.id = vi.appointment_id
      left join public.clients c on c.id = vi.client_id
      left join public.bath_subscribers s on s.id = vi.subscriber_id
     where vi.arrived_at is not null
       and a.scheduled_start is not null
       and vi.arrived_at >= now() - make_interval(days => p_days)
  ), ordered as (
    select b.*, row_number() over (partition by b.day_local order by b.scheduled_start) as stop_order
      from base b
  )
  select jsonb_build_object(
    'days', p_days,
    'n', (select count(*) from ordered),
    'mean_delta_min', (select round(avg(delta_min))::int from ordered),
    'median_delta_min', (select round(percentile_cont(0.5) within group (order by delta_min))::int from ordered),
    'p90_delta_min', (select round(percentile_cont(0.9) within group (order by delta_min))::int from ordered),
    'on_time_5_pct', (select round(100.0 * count(*) filter (where delta_min <= 5) / nullif(count(*), 0))::int from ordered),
    'on_time_15_pct', (select round(100.0 * count(*) filter (where delta_min <= 15) / nullif(count(*), 0))::int from ordered),
    'late_30_pct', (select round(100.0 * count(*) filter (where delta_min > 30) / nullif(count(*), 0))::int from ordered),
    'early_15_pct', (select round(100.0 * count(*) filter (where delta_min < -15) / nullif(count(*), 0))::int from ordered),
    'drift_by_stop', (
      select coalesce(jsonb_agg(d order by d->>'stop'), '[]'::jsonb) from (
        select jsonb_build_object(
          'stop', case when least(stop_order, 4) = 4 then '4+' else least(stop_order, 4)::text end,
          'n', count(*),
          'mean_delta_min', round(avg(delta_min))::int
        ) as d
        from ordered
        group by least(stop_order, 4)
      ) drift
    ),
    'recent', (
      select coalesce(jsonb_agg(r), '[]'::jsonb) from (
        select jsonb_build_object(
          'day', day_local,
          'client', client_name,
          'scheduled_start', scheduled_start,
          'arrived_at', arrived_at,
          'delta_min', delta_min,
          'stop_order', stop_order
        ) as r
        from ordered
        order by arrived_at desc
        limit 30
      ) recents
    ),
    'baseline', (
      select case when count(*) = 0 then null else jsonb_build_object(
        'n', count(*),
        'first_day', min(day),
        'last_day', max(day),
        'mean_delta_min', round(avg(delta_min))::int,
        'median_delta_min', round(percentile_cont(0.5) within group (order by delta_min))::int,
        'on_time_15_pct', round(100.0 * count(*) filter (where delta_min <= 15) / count(*))::int,
        'by_year', (
          select jsonb_agg(y order by y->>'year') from (
            select jsonb_build_object(
              'year', extract(year from day)::int,
              'n', count(*),
              'median_delta_min', round(percentile_cont(0.5) within group (order by delta_min))::int
            ) as y
            from public.schedule_adherence_history
            group by extract(year from day)
          ) years
        )
      ) end
      from public.schedule_adherence_history
    )
  ) into result;

  return result;
end;
$$;
revoke all on function public.admin_schedule_adherence(int) from public, anon;
grant execute on function public.admin_schedule_adherence(int) to authenticated, service_role;

create or replace function public.admin_prospectus()
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  v := public.admin_business_value();

  return jsonb_build_object(
    'value', v,
    'generated_at', now(),
    'book', (
      with tenure as (
        select client_id, min(visited_at) as first_v, max(visited_at) as last_v
          from public.visits where client_id is not null
         group by client_id having count(*) >= 3
      )
      select jsonb_build_object(
        'total_visits', (select count(*) from public.visits),
        'first_visit', (select min(visited_at)::date from public.visits),
        'standing_clients', (select count(*) from public.clients where status = 'standing'),
        'active_recurring_plans', (select count(*) from public.bath_subscriptions where status = 'active'),
        'repeat_clients', (select count(*) from tenure),
        'avg_tenure_years', (select round((avg(extract(epoch from (last_v - first_v)) / 31557600.0))::numeric, 1) from tenure),
        'max_tenure_years', (select round((max(extract(epoch from (last_v - first_v)) / 31557600.0))::numeric, 1) from tenure)
      )
    ),
    'money', (
      select jsonb_build_object(
        'median_visit_cents', (
          select round(percentile_cont(0.5) within group (order by amount_collected_cents))::bigint
            from public.visits
           where visited_at > now() - interval '365 days' and amount_collected_cents > 0),
        'earned_per_hour_cents', (
          select round(sum(amount_collected_cents)::numeric / nullif(sum(actual_minutes), 0) * 60)::bigint
            from public.visits
           where visited_at > now() - interval '365 days'
             and coalesce(actual_minutes, 0) > 0 and coalesce(amount_collected_cents, 0) > 0),
        'tips_ttm_cents', (
          select coalesce(sum(tip_cents), 0) from public.visits
           where visited_at > now() - interval '365 days')
      )
    ),
    'machine', (
      select jsonb_build_object(
        'active_agents', (select count(*) from public.agents where is_active),
        'briefings_on_record', (select count(*) from public.briefings),
        'riker_parses', (select count(*) from public.riker_log),
        'wisdom_entries', (select count(*) from public.wisdom),
        'client_records', (select count(*) from public.clients where status not in ('banned', 'merged', 'test_account')),
        'dog_records', (select count(*) from public.dogs)
      )
    )
  );
end;
$$;
revoke all on function public.admin_prospectus() from public, anon;
grant execute on function public.admin_prospectus() to authenticated, service_role;
