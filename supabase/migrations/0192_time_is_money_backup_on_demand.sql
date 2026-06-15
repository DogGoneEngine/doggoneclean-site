-- 0192_time_is_money_backup_on_demand.sql
-- Reports gets a "Back up now" button that triggers the Apps Script web app
-- (only Paul's Google identity can write his Drive). The web app /exec URL is
-- stored in app_secrets so the button reads a durable value, never a hardcoded URL.

insert into public.app_secrets (name, value) values
  ('time_is_money_webapp_url','')
on conflict (name) do nothing;

create or replace function public.admin_time_is_money_backup_status()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_folder text; v_webapp text; v_run jsonb; v_active boolean;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select value into v_folder from public.app_secrets where name='time_is_money_backup_folder_id';
  select nullif(value,'') into v_webapp from public.app_secrets where name='time_is_money_webapp_url';
  select is_active into v_active from public.agents where agent_key='ledger_keeper';
  select jsonb_build_object(
           'finished_at', finished_at,
           'file', input_summary->>'file',
           'url',  input_summary->>'url',
           'rows', input_summary->>'rows')
    into v_run
  from public.agent_runs
  where agent_key='ledger_keeper' and status='ok'
  order by finished_at desc nulls last limit 1;
  return jsonb_build_object(
    'folder_id', v_folder,
    'folder_url', case when v_folder is null then null else 'https://drive.google.com/drive/folders/' || v_folder end,
    'webapp_url', v_webapp,
    'is_active', coalesce(v_active, false),
    'last_run', v_run);
end;
$$;
revoke all on function public.admin_time_is_money_backup_status() from public, anon;
grant execute on function public.admin_time_is_money_backup_status() to authenticated;
