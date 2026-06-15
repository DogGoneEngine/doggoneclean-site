-- 0193_time_is_money_history_and_ledger.sql
-- Laelaps becomes the system of record for Time is Money (Paul retires the manual master).
-- A frozen verbatim import of the master's history (loaded once via _load_time_is_money_history,
-- migration 0194), unioned with live Laelaps visits after the 2026-06-13 cutover, in the
-- master's exact 12-column format. The weekly backup is generated from this, not copied.

create table if not exists public.time_is_money_history (
  id bigint generated always as identity primary key,
  d text, client text, inbound text, arrival text, departure text,
  charged text, paid text, method text, duration text, cycle_time text,
  on_site_rate text, cycle_rate text, sort_date date not null
);
alter table public.time_is_money_history enable row level security;
comment on table public.time_is_money_history is
  'Frozen verbatim import of the Time is Money master sheet (history through 2026-06-13). Immutable past; live visits append via _time_is_money_ledger().';

-- H:MM:SS from a number of seconds (matches the master's duration style).
create or replace function public._fmt_hms(secs double precision)
returns text language sql immutable as $$
  select case
    when secs is null or secs < 0 then ''
    else floor(secs/3600)::int::text || ':' ||
         lpad(floor(mod((secs/60)::numeric, 60))::int::text, 2, '0') || ':' ||
         lpad(floor(mod(secs::numeric, 60))::int::text, 2, '0')
  end;
$$;

create or replace function public._time_is_money_ledger()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare result jsonb;
begin
  select coalesce(jsonb_agg(obj order by sort_date, ord, cli), '[]'::jsonb) into result
  from (
    select h.sort_date, 0 as ord, h.client as cli,
      jsonb_build_object(
        'Date', h.d, 'Client', h.client, 'Inbound', h.inbound, 'Arrival', h.arrival,
        'Departure', h.departure, 'Charged', h.charged, 'Paid', h.paid, 'Method', h.method,
        'Appointment Duration', h.duration, 'Cycle Time', h.cycle_time,
        'On Site Rate', h.on_site_rate, 'Cycle Rate', h.cycle_rate) as obj
    from public.time_is_money_history h
    union all
    select (v.visited_at at time zone 'America/New_York')::date as sort_date, 1 as ord,
           coalesce(c.name,'') as cli,
      jsonb_build_object(
        'Date',      to_char(v.visited_at at time zone 'America/New_York', 'FMMM/FMDD/YYYY'),
        'Client',    coalesce(c.name,''),
        'Inbound',   coalesce(to_char(v.inbound_at  at time zone 'America/New_York', 'FMHH12:MI:SS AM'), ''),
        'Arrival',   coalesce(to_char(v.arrived_at  at time zone 'America/New_York', 'FMHH12:MI:SS AM'), ''),
        'Departure', coalesce(to_char(v.departed_at at time zone 'America/New_York', 'FMHH12:MI:SS AM'), ''),
        'Charged',   case when v.charged_cents is not null then '$' || (v.charged_cents/100)::int else '' end,
        'Paid',      case when v.amount_collected_cents is not null then '$' || (v.amount_collected_cents/100)::int else '' end,
        'Method',    coalesce(v.payment_method, ''),
        'Appointment Duration', case when v.departed_at > v.arrived_at then public._fmt_hms(extract(epoch from (v.departed_at - v.arrived_at))) else '' end,
        'Cycle Time',           case when v.inbound_at is not null and v.departed_at > v.inbound_at then public._fmt_hms(extract(epoch from (v.departed_at - v.inbound_at))) else '' end,
        'On Site Rate', case when v.amount_collected_cents is not null and v.departed_at > v.arrived_at
                             then '$' || round((v.amount_collected_cents/100.0) / (extract(epoch from (v.departed_at - v.arrived_at))/3600.0))::int else '' end,
        'Cycle Rate',   case when v.amount_collected_cents is not null and v.inbound_at is not null and v.departed_at > v.inbound_at
                             then '$' || round((v.amount_collected_cents/100.0) / (extract(epoch from (v.departed_at - v.inbound_at))/3600.0))::int else '' end
      ) as obj
    from public.visits v
    left join public.clients c on c.id = v.client_id
    where v.arrived_at is not null
      and (v.visited_at at time zone 'America/New_York')::date > date '2026-06-13'
  ) s;
  return result;
end;
$$;
