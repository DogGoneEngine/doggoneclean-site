-- 0042_agents.sql
-- The AI department-head layer. Scheduled edge functions (one per agent) read
-- scoped real data, call the Claude API, and write recommendations into
-- briefings. Agents NEVER write business tables: a briefing carries an optional
-- recommended_action, and a human Approve click is the only thing that calls the
-- named admin RPC. The AI proposes; the owner's click mutates the business.
--
-- v1 brings the CFO alive first; the other heads ship as registry rows with
-- is_active = false and an empty feed, so every department already has its
-- briefing surface and the structure is the roadmap.

create table if not exists public.agents (
  agent_key text primary key,
  label text not null,
  department text not null,
  description text,
  schedule_cron text,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agent_runs (
  id uuid primary key default gen_random_uuid(),
  agent_key text not null references public.agents(agent_key) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status = any (array['running','ok','error'])),
  input_summary jsonb,
  model text,
  tokens_used integer,
  error text
);
create index if not exists agent_runs_agent_idx on public.agent_runs (agent_key, started_at desc);

create table if not exists public.briefings (
  id uuid primary key default gen_random_uuid(),
  agent_key text not null references public.agents(agent_key) on delete cascade,
  department text not null,
  severity text not null default 'info' check (severity = any (array['info','signal','alert'])),
  title text not null,
  body text,
  evidence jsonb,
  recommended_action jsonb,
  status text not null default 'new' check (status = any (array['new','read','approved','dismissed','acted'])),
  acted_by uuid references public.admins(id) on delete set null,
  acted_at timestamptz,
  run_id uuid references public.agent_runs(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists briefings_feed_idx on public.briefings (department, status, created_at desc);

-- All three tables: RLS on, no policy. The edge functions write as the service
-- role; admins read through the SECURITY DEFINER RPCs below.
alter table public.agents enable row level security;
alter table public.agent_runs enable row level security;
alter table public.briefings enable row level security;

-- Seed the department heads. CFO is the one slated to come alive first; the rest
-- are dormant slots so each department already has a head and a feed.
insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('cfo',        'CFO',                'finance',    'Watches revenue per visit and per hour, accounts receivable, payment mix, and the no-show trend.', '0 6 * * *', false),
  ('coo',        'Operations head',    'operations', 'Watches route efficiency, drive time between stops, capacity, and per-client cycle stability.', null, false),
  ('hr',         'HR head',            'hr',         'Watches operator utilization, hours, and when the business is ready to hire.', null, false),
  ('growth',     'Growth head',        'growth',     'Watches the lead funnel, founders-spot count, referrals, retention, and churn risk.', null, false),
  ('compliance', 'Compliance head',    'compliance', 'Watches insurance and license renewals, A2P registration, and payment-processor verification dates.', null, false)
on conflict (agent_key) do nothing;

-- Briefing feed read + status update ----------------------------------------

create or replace function public.admin_list_briefings(p_department text default null, p_status text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'agent_key', b.agent_key, 'department', b.department,
      'severity', b.severity, 'title', b.title, 'body', b.body,
      'evidence', b.evidence, 'recommended_action', b.recommended_action,
      'status', b.status, 'created_at', b.created_at
    ) order by b.created_at desc)
    from public.briefings b
    where (p_department is null or b.department = p_department)
      and (p_status is null or b.status = p_status)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_briefings(text, text) from public;
grant execute on function public.admin_list_briefings(text, text) to authenticated;

create or replace function public.admin_set_briefing_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_admin uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_status not in ('new','read','approved','dismissed','acted') then
    raise exception 'invalid status: %', p_status;
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  update public.briefings
     set status = p_status,
         acted_by = case when p_status in ('approved','dismissed','acted') then v_admin else acted_by end,
         acted_at = case when p_status in ('approved','dismissed','acted') then now() else acted_at end
   where id = p_id;
  if not found then raise exception 'briefing not found'; end if;
end;
$$;
revoke all on function public.admin_set_briefing_status(uuid, text) from public;
grant execute on function public.admin_set_briefing_status(uuid, text) to authenticated;

create or replace function public.admin_list_agents()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'agent_key', a.agent_key, 'label', a.label, 'department', a.department,
      'description', a.description, 'is_active', a.is_active,
      'last_run_at', (select max(r.started_at) from public.agent_runs r where r.agent_key = a.agent_key)
    ) order by a.label)
    from public.agents a
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_agents() from public;
grant execute on function public.admin_list_agents() to authenticated;
