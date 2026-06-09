-- 0062_wisdom_archivist.sql
-- The Archivist: an LLM agent (the wisdom-absorb edge function) that triages the
-- wisdom inbox and proposes where each captured note belongs (oracle rule, client
-- note, parking lot, field manual, or drop) in clean because-form. Recommend
-- only; Paul files from the Knowledge Base floor. Runs daily, self-healing
-- (re-queues anything it could not place this run).

alter table public.wisdom
  add column if not exists proposed_home text,
  add column if not exists proposed_text text;

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('archivist','Archivist','knowledge','Triages the wisdom inbox and proposes where each note belongs.','0 15 * * *', false)
on conflict (agent_key) do nothing;

create or replace function public.wisdom_absorb_data()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', w.id, 'body', w.body, 'scope', w.scope, 'client', c.name)
             order by w.created_at)
    from public.wisdom w left join public.clients c on c.id = w.client_id
    where w.status='inbox' and w.proposed_home is null), '[]'::jsonb);
end;
$$;
revoke all on function public.wisdom_absorb_data() from public, authenticated, anon;
grant execute on function public.wisdom_absorb_data() to service_role;

create or replace function public.wisdom_save_proposal(p_id uuid, p_home text, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  update public.wisdom set proposed_home = p_home, proposed_text = p_text where id = p_id;
end;
$$;
revoke all on function public.wisdom_save_proposal(uuid, text, text) from public, authenticated, anon;
grant execute on function public.wisdom_save_proposal(uuid, text, text) to service_role;

create or replace function public.wisdom_absorb_finish(p_count integer, p_summary text, p_model text default 'claude-sonnet-4-6', p_tokens integer default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_run uuid;
begin
  insert into public.agent_runs (agent_key, status, finished_at, model, tokens_used, input_summary)
  values ('archivist','ok',now(),p_model,p_tokens, jsonb_build_object('triaged', p_count)) returning id into v_run;
  if p_count > 0 then
    update public.briefings set status='read' where agent_key='archivist' and status='new';
    insert into public.briefings (agent_key, department, severity, title, body, run_id)
    values ('archivist','knowledge','info', format('%s note(s) triaged and ready to file', p_count), p_summary, v_run);
    update public.agents set is_active=true, updated_at=now() where agent_key='archivist';
  end if;
end;
$$;
revoke all on function public.wisdom_absorb_finish(integer, text, text, integer) from public, authenticated, anon;
grant execute on function public.wisdom_absorb_finish(integer, text, text, integer) to service_role;

create or replace function public.admin_list_wisdom(p_status text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', w.id, 'body', w.body, 'scope', w.scope, 'source', w.source, 'status', w.status,
      'client', c.name, 'created_at', w.created_at,
      'proposed_home', w.proposed_home, 'proposed_text', w.proposed_text) order by w.created_at desc)
    from public.wisdom w left join public.clients c on c.id = w.client_id
    where (p_status is null or w.status = p_status)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_wisdom(text) from public;
grant execute on function public.admin_list_wisdom(text) to authenticated;

create or replace function public.wisdom_absorb_dispatch()
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_secret text; v_base text;
begin
  select value into v_secret from public.app_secrets where name='cfo_cron_secret';
  select value into v_base   from public.app_secrets where name='edge_base_url';
  if v_secret is null or v_base is null then return; end if;
  perform net.http_post(url => v_base || '/wisdom-absorb',
    headers => jsonb_build_object('Content-Type','application/json','x-cfo-secret', v_secret),
    body => jsonb_build_object('run', true), timeout_milliseconds => 25000);
end;
$$;
revoke all on function public.wisdom_absorb_dispatch() from public, authenticated, anon;

select cron.schedule('wisdom-absorb', '0 15 * * *', 'select public.wisdom_absorb_dispatch();')
  where not exists (select 1 from cron.job where jobname='wisdom-absorb');
