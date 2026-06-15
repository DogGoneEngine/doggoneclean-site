-- 0191_time_is_money_backup_status.sql
-- Reports needs to show where the Time is Money backups live and when the last one
-- was filed. The folder id is stored in app_secrets so the weekly producer and the
-- app read the same durable value (no hardcoded folder in a page).

insert into public.app_secrets (name, value) values
  ('time_is_money_backup_folder_id','115Q5cKvgZ0ic5RhPelzUbVK_o5gMUsWZ')
on conflict (name) do update set value = excluded.value;

create or replace function public.admin_time_is_money_backup_status()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_folder text; v_run jsonb; v_active boolean;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select value into v_folder from public.app_secrets where name='time_is_money_backup_folder_id';
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
    'is_active', coalesce(v_active, false),
    'last_run', v_run);
end;
$$;
revoke all on function public.admin_time_is_money_backup_status() from public, anon;
grant execute on function public.admin_time_is_money_backup_status() to authenticated;
