-- 0073_calendar_sync_recurring.sql
-- Recurring Google Calendar sync. The calendar-sync edge function reads Paul's
-- calendar with a Google service account on a 15-minute cron and mirrors it into
-- bath_appointments via _sync_appointments, then prunes anything cancelled or
-- moved out of the window. This adds the DB pieces: which calendar to read, the
-- prune, the dispatcher, and the cron. The edge function no-ops until the
-- google_service_account_json edge secret is set (Paul's Google setup).

insert into public.app_secrets (name, value) values ('gcal_calendar_id', 'nickerson.paul@gmail.com')
on conflict (name) do nothing;

create or replace function public._sync_prune(p_keep jsonb, p_from timestamptz, p_to timestamptz)
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_del int;
begin
  with d as (
    delete from public.bath_appointments
     where source='gcal_sync' and scheduled_start >= p_from and scheduled_start <= p_to
       and external_id is not null
       and external_id not in (select jsonb_array_elements_text(coalesce(p_keep,'[]'::jsonb)))
    returning 1)
  select count(*) into v_del from d;
  return v_del;
end;
$$;
revoke all on function public._sync_prune(jsonb, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public._sync_prune(jsonb, timestamptz, timestamptz) to service_role;
grant execute on function public._sync_appointments(jsonb) to service_role;

create or replace function public.calendar_sync_dispatch()
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_secret text; v_base text;
begin
  select value into v_secret from public.app_secrets where name='cfo_cron_secret';
  select value into v_base   from public.app_secrets where name='edge_base_url';
  if v_secret is null or v_base is null then return; end if;
  perform net.http_post(url => v_base || '/calendar-sync',
    headers => jsonb_build_object('Content-Type','application/json','x-cfo-secret', v_secret),
    body => jsonb_build_object('run', true), timeout_milliseconds => 30000);
end;
$$;
revoke all on function public.calendar_sync_dispatch() from public, authenticated, anon;

select cron.schedule('calendar-sync', '*/15 * * * *', 'select public.calendar_sync_dispatch();')
  where not exists (select 1 from cron.job where jobname='calendar-sync');
