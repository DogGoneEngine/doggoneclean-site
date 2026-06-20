-- 0225_my_pay_today_total.sql
--
-- Add a whole-day total to the operator's My pay floor. The pay floor already
-- shows accumulated earnings (this week, this month, all time) from completed-
-- and-charged baths; Jake also wants to open it and see, at a glance, what the
-- whole day's work pays him (Paul, 2026-06-20).
--
-- today_cents is a FORECAST, not a charged actual: the operator's share of every
-- bath assigned to them (operator_admin_id = the caller) scheduled for today and
-- not cancelled, whether or not the card has been charged yet. It answers "how
-- much will I make today?" while the day is still running. Those dollars roll
-- into this_week / all_time once each bath is completed and charged.
--
-- Still scoped to the caller's OWN admins row by auth.uid(): an operator sees
-- only their own day total, never anyone else's (operator_sees_own_pay).
-- Recreated from the live definition (migration 0224), adding the today fields.

create or replace function public.admin_my_pay()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_bps integer;
  v_tz text := 'America/New_York';
  v_today date := (now() at time zone v_tz)::date;
  v_week_start date := (date_trunc('week', (now() at time zone v_tz)))::date;  -- Monday
  v_month_start date := (date_trunc('month', (now() at time zone v_tz)))::date;
  v_core jsonb;
  v_day jsonb;
  v_weeks jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select a.id, coalesce(a.commission_bps, 0)
    into v_id, v_bps
    from public.admins a
   where a.auth_user_id = auth.uid() and a.is_active
   limit 1;
  if v_id is null then raise exception 'not authorized'; end if;

  -- Accumulated, charged earnings: completed AND charged baths, bucketed by the
  -- local date the money was captured.
  with paid as (
    select round(ba.amount_cents::numeric * v_bps / 10000)::bigint as earned,
           (coalesce(ba.charged_at, ba.scheduled_start) at time zone v_tz)::date as d
      from public.bath_appointments ba
     where ba.operator_admin_id = v_id
       and ba.status = 'completed'
       and ba.payment_status = 'charged'
       and ba.amount_cents is not null
  )
  select jsonb_build_object(
    'all_time_cents',  coalesce(sum(earned), 0),
    'all_time_count',  count(*),
    'this_week_cents', coalesce(sum(earned) filter (where d >= v_week_start), 0),
    'last_week_cents', coalesce(sum(earned) filter (where d >= v_week_start - 7 and d < v_week_start), 0),
    'this_month_cents',coalesce(sum(earned) filter (where d >= v_month_start), 0)
  ) into v_core
  from paid;

  -- Today's forecast: the operator's share of every bath assigned to them today
  -- that is not cancelled, charged or not. "What the day pays me."
  select jsonb_build_object(
    'today_cents', coalesce(sum(round(ba.amount_cents::numeric * v_bps / 10000))::bigint, 0),
    'today_count', count(*)
  ) into v_day
  from public.bath_appointments ba
  where ba.operator_admin_id = v_id
    and (ba.scheduled_start at time zone v_tz)::date = v_today
    and ba.status not in ('cancelled', 'no_show', 'skipped')
    and ba.amount_cents is not null;

  -- The last eight Monday-to-Sunday weeks, oldest first, for a simple trend.
  select coalesce(jsonb_agg(jsonb_build_object(
            'week_start',   g.wk,
            'earned_cents', coalesce(e.earned, 0),
            'baths',        coalesce(e.baths, 0)
          ) order by g.wk), '[]'::jsonb)
    into v_weeks
    from (select generate_series(v_week_start::timestamp - interval '49 days',
                                 v_week_start::timestamp, interval '7 days')::date as wk) g
    left join lateral (
      select sum(round(ba.amount_cents::numeric * v_bps / 10000))::bigint as earned,
             count(*) as baths
        from public.bath_appointments ba
       where ba.operator_admin_id = v_id
         and ba.status = 'completed'
         and ba.payment_status = 'charged'
         and ba.amount_cents is not null
         and (coalesce(ba.charged_at, ba.scheduled_start) at time zone v_tz)::date >= g.wk
         and (coalesce(ba.charged_at, ba.scheduled_start) at time zone v_tz)::date <  g.wk + 7
    ) e on true;

  return v_core
    || v_day
    || jsonb_build_object('rate_bps', v_bps, 'week_start', v_week_start, 'weeks', v_weeks);
end;
$$;

revoke all on function public.admin_my_pay() from public, anon;
grant execute on function public.admin_my_pay() to authenticated, service_role;
