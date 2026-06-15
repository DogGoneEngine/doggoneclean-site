-- 0190_time_is_money_weekly_backup.sql
-- The Ledger Keeper: a department head whose whole job is the weekly Time is Money
-- backup. Paul kept a manual Time is Money sheet for years as his source of truth;
-- he is retiring the parallel doc and trusting the app, but wants a full, portable
-- snapshot of the ENTIRE visit history filed every Sunday as insurance he controls.
--
-- The teeth live here so they survive any redesign and stay sellable:
--   * _time_is_money_ledger()        -- the full ledger as data (service role / agent)
--   * admin_export_time_is_money_full() -- the same, admin-gated, for the app
--   * time_is_money_snapshot_finish() -- logs the run and files a Today card with the
--                                        Drive link, so Paul gets nudged to glance at it
-- The producer (the thing that writes the Google Sheet into Drive) is the weekly agent
-- run, which already has the Drive connection; no edge function or service-account
-- credential is needed. See time_is_money_weekly_backup in CLEAN_ORACLE.md.
--
-- This is the FULL history (every visit on record, all sources), not the old
-- "append the new app rows onto the end of the sheet" export. That append-helper is
-- retired because the parallel sheet is being retired. A Source column rides along so
-- provenance stays honest: time_is_money is the ledger of record
-- (time_is_money_is_source_of_truth); google_calendar and contact_sheet rows are real
-- visits recovered from those books that the sheet never had.

-- Core: the entire ledger as an ordered array of plain rows. No admin gate so the
-- weekly agent (service role) can read it; granted only to service_role. All dates and
-- times render in America/New_York (Paul's local Eastern), matching his sheet.
create or replace function public._time_is_money_ledger()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare result jsonb;
begin
  select coalesce(jsonb_agg(row order by row_order), '[]'::jsonb) into result
  from (
    select
      v.visited_at as row_order,
      jsonb_build_object(
        'Date',      to_char(v.visited_at at time zone 'America/New_York', 'MM/DD/YYYY'),
        'Day',       to_char(v.visited_at at time zone 'America/New_York', 'Dy'),
        'Client',    coalesce(c.name, ''),
        'Dogs',      coalesce((
                        select string_agg(d.name, ', ' order by d.name)
                        from public.dogs d where d.id = any(v.dog_ids)
                      ), ''),
        'Service',   coalesce(v.service_type, ''),
        'Inbound',   coalesce(to_char(v.inbound_at  at time zone 'America/New_York', 'HH12:MI AM'), ''),
        'Arrival',   coalesce(to_char(v.arrived_at  at time zone 'America/New_York', 'HH12:MI AM'), ''),
        'Departure', coalesce(to_char(v.departed_at at time zone 'America/New_York', 'HH12:MI AM'), ''),
        'Minutes',   coalesce(v.actual_minutes::text, ''),
        'Charged',   coalesce(to_char(v.charged_cents / 100.0, 'FM999990.00'), ''),
        'Paid',      coalesce(to_char(v.amount_collected_cents / 100.0, 'FM999990.00'), ''),
        'Tip',       coalesce(to_char(v.tip_cents / 100.0, 'FM999990.00'), ''),
        'Method',    coalesce(v.payment_method, ''),
        'Notes',     btrim(coalesce(v.work_done, '') || case when v.work_done is not null and v.visit_notes is not null then ' | ' else '' end || coalesce(v.visit_notes, '')),
        'Source',    coalesce(v.source, '')
      ) as row
    from public.visits v
    left join public.clients c on c.id = v.client_id
  ) s;
  return result;
end;
$$;
revoke all on function public._time_is_money_ledger() from public, authenticated, anon;
grant execute on function public._time_is_money_ledger() to service_role;

-- Admin-facing twin so the app (Reports) can preview the same full ledger.
create or replace function public.admin_export_time_is_money_full()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return public._time_is_money_ledger();
end;
$$;
revoke all on function public.admin_export_time_is_money_full() from public, anon;
grant execute on function public.admin_export_time_is_money_full() to authenticated;

-- Register the department head. Dormant until its first run flips it active.
insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('ledger_keeper','Ledger Keeper','records',
   'Files a full Time is Money backup (the entire visit history) as a dated Google Sheet in Drive every Sunday, then posts a card here so you can glance at it.',
   '0 12 * * 0', false)
on conflict (agent_key) do update set
  label = excluded.label, department = excluded.department,
  description = excluded.description, schedule_cron = excluded.schedule_cron, updated_at = now();

-- Called by the weekly agent after it files the Sheet: logs the run and files a Today
-- card carrying the Drive link, so the backup announces itself and Paul is nudged to
-- confirm it. Replaces any prior unread Ledger Keeper card so Today never stacks them.
create or replace function public.time_is_money_snapshot_finish(
  p_file_name text,
  p_file_url  text,
  p_rows      integer,
  p_folder_url text default null
)
returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_run uuid;
begin
  insert into public.agent_runs (agent_key, status, finished_at, model, input_summary)
  values ('ledger_keeper','ok',now(),'agent',
          jsonb_build_object('rows', p_rows, 'file', p_file_name, 'url', p_file_url))
  returning id into v_run;

  update public.briefings set status='read' where agent_key='ledger_keeper' and status='new';

  insert into public.briefings (agent_key, department, severity, title, body, evidence, run_id)
  values ('ledger_keeper','records','info',
          format('Time is Money backup filed: %s', p_file_name),
          format('The full visit history (%s rows) is saved as a Google Sheet in your Time is Money backups folder. Worth a glance to confirm it looks right.', p_rows),
          jsonb_build_object('file_url', p_file_url, 'folder_url', p_folder_url, 'rows', p_rows),
          v_run);

  update public.agents set is_active=true, updated_at=now() where agent_key='ledger_keeper';
  return v_run;
end;
$$;
revoke all on function public.time_is_money_snapshot_finish(text, text, integer, text) from public, authenticated, anon;
grant execute on function public.time_is_money_snapshot_finish(text, text, integer, text) to service_role;
