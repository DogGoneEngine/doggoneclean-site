-- 0257_waitlist_owner_alert_and_list.sql
-- The waitlist was a one-way drop: anyone could join (the Ocala page and the
-- capacity fallback on /book both write to public.waitlist), but nothing read it
-- back and nothing told Paul, so a real lead landed in a table no one watched.
-- This closes that leak two ways, reusing the proven owner-alert machinery from
-- migration 0227:
--   1. The moment someone joins, a "Front desk" (Iris) card lands on the Today
--      feed, and an optional Telegram DM goes to Paul's phone when armed.
--   2. The whole list surfaces on the Growth floor, folded into the admin growth
--      summary the Growth view already loads.
-- No new agent, no new switch: the Telegram tail reuses owner_alerts_telegram +
-- telegram_bot_token + telegram_owner_chat_id (migration 0227), and the card home
-- is the same front_desk/Iris herald.

-- 1. Emit one alert per signup: always write the Today card; Telegram only when armed.
create or replace function public.waitlist_owner_alert_emit()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_city text; v_dogs int; v_title text; v_body text;
  v_token text; v_chat text; v_live text; v_msg text;
begin
  v_city := case new.city_slug
              when 'ocala' then 'Ocala'
              when 'the-villages' then 'The Villages'
              when 'fernandina-beach' then 'Fernandina Beach'
              when 'saint-simons-island' then 'Saint Simons Island'
              else coalesce(nullif(btrim(new.city_slug), ''), 'a city') end;
  v_dogs := coalesce(new.dog_count, 0);

  v_title := 'New waitlist signup: ' || v_city;
  v_body := coalesce(nullif(btrim(new.email), ''), 'no email')
            || case when nullif(btrim(coalesce(new.zip_code, '')), '') is not null
                    then ' - ' || new.zip_code else '' end
            || case when v_dogs > 0
                    then ' - ' || v_dogs || ' dog' || case when v_dogs = 1 then '' else 's' end
                    else '' end;

  -- The Today card is the permanent home (front_desk / Iris, seeded in 0227).
  insert into public.briefings (agent_key, department, severity, title, body, evidence, status)
  values ('front_desk', 'operations', 'info', v_title, v_body,
          jsonb_build_object('kind', 'waitlist_signup', 'waitlist_id', new.id,
                             'city_slug', new.city_slug, 'email', new.email), 'new');

  -- Telegram tail (dormant until armed): reuses Paul's phone DM channel.
  v_token := (select value from public.app_secrets where name = 'telegram_bot_token');
  v_chat  := (select value from public.app_secrets where name = 'telegram_owner_chat_id');
  v_live  := (select value from public.app_secrets where name = 'owner_alerts_telegram');
  if coalesce(v_live, 'false') = 'true'
     and nullif(btrim(coalesce(v_token, '')), '') is not null
     and nullif(btrim(coalesce(v_chat, '')), '') is not null then
    v_msg := v_title || E'\n' || v_body;
    perform net.http_post(
      url     => 'https://api.telegram.org/bot' || v_token || '/sendMessage',
      headers => jsonb_build_object('Content-Type', 'application/json'),
      body    => jsonb_build_object('chat_id', v_chat, 'text', v_msg),
      timeout_milliseconds => 8000);
  end if;
  return null;
end;
$function$;

-- Trigger-only; no web caller should reach it through /rest/v1/rpc.
revoke execute on function public.waitlist_owner_alert_emit() from public, anon, authenticated;

drop trigger if exists waitlist_owner_alert_trg on public.waitlist;
create trigger waitlist_owner_alert_trg
after insert on public.waitlist
for each row execute function public.waitlist_owner_alert_emit();

-- 2. Surface the whole list on the Growth floor. Recreate admin_growth_summary
--    exactly as it stood (migration 0065), with a 'waitlist' array added so the
--    Growth view shows every signup, newest first, without a second round-trip.
create or replace function public.admin_growth_summary()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_cap int; v_upcoming int; v_cand jsonb; v_ret int; v_wait jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_cap := coalesce((select value::int from public.app_secrets where name='winback_capacity_14d'), 40);
  select count(*) into v_upcoming from public.bath_appointments
   where status in ('requested','confirmed') and scheduled_start between now() and now() + interval '14 days';
  select coalesce(jsonb_agg(jsonb_build_object(
      'name', d.name, 'email', d.email, 'days_since', d.days_since, 'cadence_days', d.cadence_days,
      'kind', case when d.cadence_days is not null then 'recurring' else 'one-off' end) order by d.days_since asc), '[]'::jsonb)
    into v_cand from public._winback_due_view() d
    where not exists (select 1 from public.briefings where agent_key='winback' and (evidence->>'client_id')::uuid=d.id and disposition='intentional');
  select count(*) into v_ret from public.briefings where agent_key='retention' and status in ('new','read');
  select coalesce(jsonb_agg(jsonb_build_object(
      'email', w.email,
      'city', case w.city_slug
                when 'ocala' then 'Ocala'
                when 'the-villages' then 'The Villages'
                when 'fernandina-beach' then 'Fernandina Beach'
                when 'saint-simons-island' then 'Saint Simons Island'
                else w.city_slug end,
      'city_slug', w.city_slug,
      'zip_code', w.zip_code,
      'dog_count', w.dog_count,
      'joined', to_char(w.created_at at time zone 'America/New_York', 'Mon FMDD, FMHH12:MI am'),
      'created_at', w.created_at) order by w.created_at desc), '[]'::jsonb)
    into v_wait from public.waitlist w;
  return jsonb_build_object('upcoming_14d', v_upcoming, 'capacity_14d', v_cap, 'has_room', v_upcoming < v_cap,
    'candidates', v_cand, 'retention_open', v_ret,
    'waitlist', v_wait, 'waitlist_count', coalesce(jsonb_array_length(v_wait), 0));
end;
$$;
revoke all on function public.admin_growth_summary() from public;
grant execute on function public.admin_growth_summary() to authenticated;
