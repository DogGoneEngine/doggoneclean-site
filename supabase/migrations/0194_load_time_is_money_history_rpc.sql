-- 0194_load_time_is_money_history_rpc.sql
-- One-time loader for the frozen history table, called by the Apps Script (which reads the
-- master sheet directly, so no value is ever re-typed by a human or model). Each element of
-- p_rows is a 13-item array: the 12 sheet columns plus an ISO sort_date.
create or replace function public._load_time_is_money_history(p_rows jsonb)
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  truncate table public.time_is_money_history restart identity;
  insert into public.time_is_money_history
    (d, client, inbound, arrival, departure, charged, paid, method, duration, cycle_time, on_site_rate, cycle_rate, sort_date)
  select x->>0, x->>1, x->>2, x->>3, x->>4, x->>5, x->>6, x->>7, x->>8, x->>9, x->>10, x->>11, (x->>12)::date
  from jsonb_array_elements(p_rows) as x
  where coalesce(x->>0,'') <> '';
  return (select count(*) from public.time_is_money_history);
end;
$$;
revoke all on function public._load_time_is_money_history(jsonb) from public, anon, authenticated;
