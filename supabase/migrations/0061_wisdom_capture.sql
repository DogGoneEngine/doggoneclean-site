-- 0061_wisdom_capture.sql
-- The knowledge layer. Paul's talk-backs to agents (which should carry a because)
-- and his one-tap speed-dial ideas land here, scoped to a client or a department,
-- to be absorbed into the Oracle or a client record. Internal only (RLS-locked).
-- See talk_back_with_because in CLEAN_ORACLE.md.

create table if not exists public.wisdom (
  id uuid primary key default gen_random_uuid(),
  body text not null,
  scope text not null default 'business'
    check (scope = any (array['business','client','pricing','operations','growth','finance','compliance','other'])),
  client_id uuid references public.clients(id) on delete set null,
  source text not null default 'quick_capture'
    check (source = any (array['quick_capture','briefing','absorbed'])),
  status text not null default 'inbox' check (status = any (array['inbox','filed'])),
  created_at timestamptz not null default now()
);
alter table public.wisdom enable row level security;
create index if not exists wisdom_created_idx on public.wisdom (created_at desc);

create or replace function public.admin_capture_wisdom(p_body text, p_scope text default 'business', p_client_id uuid default null, p_source text default 'quick_capture')
returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_body),'')='' then raise exception 'empty'; end if;
  insert into public.wisdom (body, scope, client_id, source)
  values (p_body, coalesce(p_scope,'business'), p_client_id, coalesce(p_source,'quick_capture'))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_capture_wisdom(text, text, uuid, text) from public;
grant execute on function public.admin_capture_wisdom(text, text, uuid, text) to authenticated;

create or replace function public.admin_list_wisdom(p_status text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', w.id, 'body', w.body, 'scope', w.scope, 'source', w.source, 'status', w.status,
      'client', c.name, 'created_at', w.created_at) order by w.created_at desc)
    from public.wisdom w left join public.clients c on c.id = w.client_id
    where (p_status is null or w.status = p_status)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_wisdom(text) from public;
grant execute on function public.admin_list_wisdom(text) to authenticated;

create or replace function public.admin_set_wisdom_status(p_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.wisdom set status = p_status where id = p_id;
  if not found then raise exception 'not found'; end if;
end;
$$;
revoke all on function public.admin_set_wisdom_status(uuid, text) from public;
grant execute on function public.admin_set_wisdom_status(uuid, text) to authenticated;

-- Briefing replies and intentional resolutions also land in the wisdom inbox,
-- scoped to the client (if the briefing is about one) or the department.
create or replace function public._capture_briefing_wisdom(p_briefing_id uuid, p_body text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare b record; v_client uuid; v_scope text;
begin
  select * into b from public.briefings where id = p_briefing_id;
  if b is null then return; end if;
  begin v_client := (b.evidence->>'client_id')::uuid; exception when others then v_client := null; end;
  v_scope := case when v_client is not null then 'client'
                  when b.department in ('finance','growth','operations','compliance') then b.department
                  else 'business' end;
  insert into public.wisdom (body, scope, client_id, source) values (p_body, v_scope, v_client, 'briefing');
end;
$$;

create or replace function public.admin_add_briefing_note(p_briefing_id uuid, p_body text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_body),'')='' then raise exception 'empty note'; end if;
  insert into public.briefing_notes (briefing_id, author, body) values (p_briefing_id, 'paul', p_body);
  update public.briefings set status='read' where id=p_briefing_id and status='new';
  perform public._capture_briefing_wisdom(p_briefing_id, p_body);
end;
$$;

create or replace function public.admin_resolve_briefing(p_briefing_id uuid, p_disposition text, p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_ack text;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_disposition not in ('intentional','dismissed','done') then raise exception 'bad disposition'; end if;
  if coalesce(trim(p_note),'') <> '' then
    insert into public.briefing_notes (briefing_id, author, body) values (p_briefing_id, 'paul', p_note);
    perform public._capture_briefing_wisdom(p_briefing_id, p_note);
  end if;
  update public.briefings set disposition=p_disposition, status='resolved' where id=p_briefing_id;
  v_ack := case p_disposition
    when 'intentional' then 'Understood. I will leave this one alone and stop flagging it, and I have saved your reason. Tell me if that changes.'
    when 'done' then 'Got it, marked done.'
    else 'Cleared.' end;
  insert into public.briefing_notes (briefing_id, author, body) values (p_briefing_id, 'agent', v_ack);
end;
$$;
