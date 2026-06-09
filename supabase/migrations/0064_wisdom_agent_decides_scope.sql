-- 0064_wisdom_agent_decides_scope.sql
-- The agent decides the category, not Paul. Quick-captures default to 'unsorted'
-- and the Archivist assigns both the home and the scope, removing the friction of
-- making Paul pick a category that often does not fit. See talk_back_with_because.

alter table public.wisdom drop constraint if exists wisdom_scope_check;
alter table public.wisdom add constraint wisdom_scope_check
  check (scope = any (array['unsorted','business','client','pricing','operations','growth','finance','compliance','other']));

create or replace function public.admin_capture_wisdom(p_body text, p_scope text default 'unsorted', p_client_id uuid default null, p_source text default 'quick_capture')
returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_body),'')='' then raise exception 'empty'; end if;
  insert into public.wisdom (body, scope, client_id, source)
  values (p_body, coalesce(p_scope,'unsorted'), p_client_id, coalesce(p_source,'quick_capture'))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_capture_wisdom(text, text, uuid, text) from public;
grant execute on function public.admin_capture_wisdom(text, text, uuid, text) to authenticated;

create or replace function public.wisdom_save_proposal(p_id uuid, p_home text, p_text text, p_scope text default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  update public.wisdom set
    proposed_home = p_home, proposed_text = p_text, scope = coalesce(p_scope, scope)
  where id = p_id;
end;
$$;
revoke all on function public.wisdom_save_proposal(uuid, text, text, text) from public, authenticated, anon;
grant execute on function public.wisdom_save_proposal(uuid, text, text, text) to service_role;

create or replace function public.admin_trigger_archivist()
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  perform public.wisdom_absorb_dispatch();
end;
$$;
revoke all on function public.admin_trigger_archivist() from public;
grant execute on function public.admin_trigger_archivist() to authenticated;
