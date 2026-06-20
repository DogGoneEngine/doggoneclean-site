-- 0224_operator_pay_share.sql
--
-- Jake's paycheck. Jake starts on Clean as the Hurricane Bath Operator with his
-- own route, and he needs to open Laelaps and see what he has earned, not just
-- today's number. An operator is paid a percentage SHARE of each bath he runs,
-- once that bath is completed and the card is charged (Paul, 2026-06-20).
--
-- Two pieces of durable teeth, so the paycheck survives any redesign of the
-- console and so a future operator can be paid without a code change:
--   1. admins.commission_bps: the pay rate stored as basis points (5000 = 50%).
--      Jake = 5000. A flat default of 0 means a brand-new admin earns nothing
--      until a rate is set on purpose.
--   2. admin_my_pay(): computes the signed-in operator's OWN earnings, server
--      side, scoped to their own admins row by auth.uid(). It returns only this
--      person's pay (their share of their own completed-and-charged baths) and
--      no other money: not the bath price to anyone else, not another worker's
--      pay, not the business's books. This is the one deliberate carve-out to
--      orbit_roles_operator_masked (which strips ALL money from the operator
--      role): a worker may see their own paycheck, computed for them alone.
--
-- Earnings are an accumulated fact (this week, this month, all time, plus the
-- last eight weeks), never a daily goal or target: a goal bar would push the
-- operator to overextend, against the prime directive's grind-less aim.

-- 1. The stored pay rate. Basis points keep the money math integer-clean and
--    match the cents idiom used everywhere else in this schema.
alter table public.admins
  add column if not exists commission_bps integer not null default 0;
alter table public.admins
  drop constraint if exists admins_commission_bps_range;
alter table public.admins
  add constraint admins_commission_bps_range check (commission_bps between 0 and 10000);
comment on column public.admins.commission_bps is
  'Operator pay rate as basis points of each completed-and-charged bath (5000 = 50%). 0 = no commission (the owner takes all; a new operator earns nothing until set). Applied server-side by admin_my_pay; never hardcoded in a page.';

-- Jake Nickerson, the founding Hurricane Bath Operator: half of every bath he
-- runs, the same share he carries on the nails side (Paul, 2026-06-20).
update public.admins
   set commission_bps = 5000
 where lower(email) = 'jakewnickerson@gmail.com';

-- 2. The paycheck RPC: the calling operator's own earnings, and nothing else.
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
  v_week_start date := (date_trunc('week', (now() at time zone v_tz)))::date;  -- Monday
  v_month_start date := (date_trunc('month', (now() at time zone v_tz)))::date;
  v_core jsonb;
  v_weeks jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  -- Resolve to the caller's OWN admin row. Every number below is theirs alone;
  -- no parameter lets one person ask for another's pay.
  select a.id, coalesce(a.commission_bps, 0)
    into v_id, v_bps
    from public.admins a
   where a.auth_user_id = auth.uid() and a.is_active
   limit 1;
  if v_id is null then raise exception 'not authorized'; end if;

  -- The pay-bearing events: this operator's completed AND charged baths, each
  -- worth their share of what that bath collected, bucketed by the local date
  -- the money was captured.
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
    || jsonb_build_object('rate_bps', v_bps, 'week_start', v_week_start, 'weeks', v_weeks);
end;
$$;

revoke all on function public.admin_my_pay() from public, anon;
grant execute on function public.admin_my_pay() to authenticated, service_role;
