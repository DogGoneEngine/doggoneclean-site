-- 0166: Paul's 2026-06-12 afternoon batch, two pieces.
--
-- (1) The limits inventory (know_your_limits): everything the business pays
-- for that has a ceiling, in one table, with live usage attached where the
-- app can measure it. The infra watcher already covered Supabase database
-- and storage; this generalizes it to the whole stack (droplet, Resend,
-- Anthropic, Google Maps, GitHub Actions, the 50MB upload cap) so a limit
-- is never discovered by hitting it. Rows are data, not code: when a plan
-- changes, update the row.
--
-- (2) admin_prospectus v2: the hype pass. New live blocks for the fleet
-- (equipment + the maintenance program), the named AI department heads, the
-- tracker era, and average on-site minutes, so the Prospectus can sell the
-- String of Pearls scheduling, the Dog Gone Tracker, the Hurricane Bath
-- itself, the rolling plant, and the knowledge base, every claim still
-- carrying a receipt.
--
-- Applied to dgc-prod 2026-06-12.

create table if not exists public.infra_limits (
  id uuid primary key default gen_random_uuid(),
  service text not null,
  item text not null,
  limit_label text not null,
  limit_value numeric,
  unit text,
  period text,
  live_key text,
  note text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.infra_limits enable row level security;

insert into public.infra_limits (service, item, limit_label, limit_value, unit, period, live_key, note) values
  ('Supabase (free)', 'Database size', '500 MB', 500, 'mb', null, 'db', 'Also enforced by the daily infra watcher; limit mirrored in app_secrets infra_db_limit_mb.'),
  ('Supabase (free)', 'File storage', '1 GB', 1000, 'mb', null, 'storage', 'Visit photos and the Library bucket.'),
  ('Supabase (free)', 'Single file upload', '50 MB', 50, 'mb', null, null, 'Why big videos go to Google Drive instead of the Library.'),
  ('Supabase (free)', 'Egress bandwidth', '5 GB / month', 5000, 'mb', 'month', null, 'Not measurable from inside the app; the Supabase dashboard Usage page shows it.'),
  ('Supabase (free)', 'Edge function calls', '500,000 / month', 500000, 'count', 'month', null, 'Dashboard Usage page; we are nowhere near it.'),
  ('Supabase (free)', 'Monthly active users', '50,000 / month', 50000, 'count', 'month', 'auth_users', 'Live number shown is total accounts ever, which overcounts MAU; fine while tiny.'),
  ('DigitalOcean droplet', 'Disk', '50 GB (shared with DGN)', 50, 'gb', null, null, 'dog-gone-engine droplet. Check with df -h in a droplet session; the static site build is a few MB.'),
  ('DigitalOcean droplet', 'Memory', '2 GB (shared with DGN)', 2, 'gb', null, null, 'Caddy plus n8n run in Docker on it.'),
  ('DigitalOcean droplet', 'Transfer', '2 TB / month', 2000, 'gb', 'month', null, 'DigitalOcean dashboard shows usage; a static site will not approach it.'),
  ('Resend (email)', 'Emails', '3,000 / month', 3000, 'count', 'month', 'emails_month', 'Live count from notification_log.'),
  ('Resend (email)', 'Emails', '100 / day', 100, 'count', 'day', 'emails_today', 'The daily ceiling bites before the monthly one.'),
  ('Anthropic API', 'Spend', 'usage-billed, no hard cap', null, 'usd', 'month', 'anthropic_month', 'Every agent call logged in agent_costs; the HR floor shows per-agent cost.'),
  ('Google Maps', 'API calls', 'free tier per API, then usage-billed', null, 'count', 'month', null, 'Google Cloud console shows per-API usage; the key is domain-locked to our site.'),
  ('GitHub Actions', 'CI minutes', '2,000 / month if the repo is private', 2000, 'count', 'month', null, 'Public repos are unmetered. github.com Settings then Billing shows usage.');

create or replace function public.admin_infra_status()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_db bigint; v_st bigint; v_objs int; v_prev record;
  v_auth_users int; v_emails_month int; v_emails_today int; v_anthropic numeric;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select pg_database_size(current_database()) into v_db;
  select coalesce(sum((metadata->>'size')::bigint), 0), count(*) into v_st, v_objs from storage.objects;
  select db_bytes, storage_bytes into v_prev from public.infra_metrics
   where taken_at < now() - interval '25 days' order by taken_at desc limit 1;
  select count(*) into v_auth_users from auth.users;
  select count(*) into v_emails_month from public.notification_log
   where channel = 'email' and sent_at > date_trunc('month', now());
  select count(*) into v_emails_today from public.notification_log
   where channel = 'email' and sent_at > (now() at time zone 'America/New_York')::date;
  select coalesce(round(sum(public._agent_cost_usd(model, input_tokens, output_tokens))::numeric, 2), 0)
    into v_anthropic from public.agent_costs where created_at > date_trunc('month', now());

  return jsonb_build_object(
    'db_bytes', v_db,
    'storage_bytes', v_st,
    'storage_objects', v_objs,
    'db_limit_mb', coalesce((select value::numeric from public.app_secrets where name = 'infra_db_limit_mb'), 500),
    'storage_limit_mb', coalesce((select value::numeric from public.app_secrets where name = 'infra_storage_limit_mb'), 1000),
    'db_bytes_30d_ago', v_prev.db_bytes,
    'storage_bytes_30d_ago', v_prev.storage_bytes,
    'top_tables', coalesce((
      select jsonb_agg(jsonb_build_object('name', relname, 'bytes', sz) order by sz desc)
        from (select c.relname, pg_total_relation_size(c.oid) as sz
                from pg_class c join pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'public' and c.relkind = 'r'
               order by pg_total_relation_size(c.oid) desc limit 5) t), '[]'::jsonb),
    'inventory', coalesce((
      select jsonb_agg(jsonb_build_object(
        'service', l.service,
        'item', l.item,
        'limit_label', l.limit_label,
        'limit_value', l.limit_value,
        'unit', l.unit,
        'period', l.period,
        'note', l.note,
        'used', case l.live_key
          when 'db' then round(v_db / 1048576.0)
          when 'storage' then round(v_st / 1048576.0)
          when 'auth_users' then v_auth_users
          when 'emails_month' then v_emails_month
          when 'emails_today' then v_emails_today
          when 'anthropic_month' then v_anthropic
          else null end,
        'pct', case when l.limit_value is null or l.limit_value = 0 then null
          else case l.live_key
            when 'db' then round(v_db / 1048576.0 / l.limit_value * 100)
            when 'storage' then round(v_st / 1048576.0 / l.limit_value * 100)
            when 'auth_users' then round(v_auth_users / l.limit_value * 100)
            when 'emails_month' then round(v_emails_month / l.limit_value * 100)
            when 'emails_today' then round(v_emails_today / l.limit_value * 100)
            else null end
          end
      ) order by l.service, l.item, l.limit_label)
      from public.infra_limits l where l.active), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.admin_infra_status() from public, anon;
grant execute on function public.admin_infra_status() to authenticated, service_role;

create or replace function public.admin_prospectus()
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  v := public.admin_business_value();

  return jsonb_build_object(
    'value', v,
    'generated_at', now(),
    'book', (
      with tenure as (
        select client_id, min(visited_at) as first_v, max(visited_at) as last_v
          from public.visits where client_id is not null
         group by client_id having count(*) >= 3
      )
      select jsonb_build_object(
        'total_visits', (select count(*) from public.visits),
        'first_visit', (select min(visited_at)::date from public.visits),
        'standing_clients', (select count(*) from public.clients where status = 'standing'),
        'active_recurring_plans', (select count(*) from public.bath_subscriptions where status = 'active'),
        'repeat_clients', (select count(*) from tenure),
        'avg_tenure_years', (select round((avg(extract(epoch from (last_v - first_v)) / 31557600.0))::numeric, 1) from tenure),
        'max_tenure_years', (select round((max(extract(epoch from (last_v - first_v)) / 31557600.0))::numeric, 1) from tenure)
      )
    ),
    'money', (
      select jsonb_build_object(
        'median_visit_cents', (
          select round(percentile_cont(0.5) within group (order by amount_collected_cents))::bigint
            from public.visits
           where visited_at > now() - interval '365 days' and amount_collected_cents > 0),
        'earned_per_hour_cents', (
          select round(sum(amount_collected_cents)::numeric / nullif(sum(actual_minutes), 0) * 60)::bigint
            from public.visits
           where visited_at > now() - interval '365 days'
             and coalesce(actual_minutes, 0) > 0 and coalesce(amount_collected_cents, 0) > 0),
        'avg_on_site_min', (
          select round(avg(actual_minutes))::int from public.visits
           where visited_at > now() - interval '365 days' and coalesce(actual_minutes, 0) > 0),
        'tips_ttm_cents', (
          select coalesce(sum(tip_cents), 0) from public.visits
           where visited_at > now() - interval '365 days')
      )
    ),
    'machine', (
      select jsonb_build_object(
        'active_agents', (select count(*) from public.agents where is_active),
        'briefings_on_record', (select count(*) from public.briefings),
        'riker_parses', (select count(*) from public.riker_log),
        'wisdom_entries', (select count(*) from public.wisdom),
        'client_records', (select count(*) from public.clients where status not in ('banned', 'merged', 'test_account')),
        'dog_records', (select count(*) from public.dogs),
        'tracked_visits', (select count(*) from public.visits where arrived_at is not null),
        'notifications_sent', (select count(*) from public.notification_log where status = 'sent')
      )
    ),
    'agents_list', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'label', label, 'department', department, 'description', description) order by label), '[]'::jsonb)
      from public.agents where is_active
    ),
    'fleet', (
      select jsonb_build_object(
        'equipment_items', (select count(*) from public.equipment where active),
        'generators', (select count(*) from public.equipment where active and kind = 'generator'),
        'hour_tracked', (select count(*) from public.equipment where active and track_hours),
        'maintenance_tasks', (select count(*) from public.maintenance_tasks where active),
        'equipment_names', (select coalesce(jsonb_agg(name order by name), '[]'::jsonb) from public.equipment where active)
      )
    )
  );
end;
$$;
revoke all on function public.admin_prospectus() from public, anon;
grant execute on function public.admin_prospectus() to authenticated, service_role;
