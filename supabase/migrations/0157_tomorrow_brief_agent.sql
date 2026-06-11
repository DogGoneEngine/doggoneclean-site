-- 0157: the Day-before brief agent. Every evening it writes one card with
-- tomorrow's route in stop order: time, client, the dogs going, access notes
-- ("how to get in"), standing instructions per dog, and any open follow-ups.
-- Penciled (tentative) stops are included and labeled, because Paul plans
-- around them. Pure SQL, no LLM, effectively free. It supersedes its own
-- previous card so Today never stacks stale briefs.

create or replace function public._tomorrow_brief()
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_tz text := 'America/New_York';
  v_day date := (now() at time zone 'America/New_York')::date + 1;
  v_count int;
  v_body text;
begin
  select count(*), string_agg(stop_line, E'\n\n' order by sort_key)
    into v_count, v_body
  from (
    select a.scheduled_start as sort_key,
      to_char(a.scheduled_start at time zone v_tz, 'HH12:MI AM') || ' ' ||
      coalesce(c.name, 'Unmatched stop') ||
      case when a.status = 'tentative' then ' (penciled, not client-official)' else '' end ||
      coalesce(' · ' || (
        select string_agg(d.name, ', ' order by d.name)
          from public.dogs d
         where (a.dog_ids is not null and d.id = any(a.dog_ids))
            or (a.dog_ids is null and d.client_id = c.id
                and coalesce(d.roster_status, 'regular') in ('regular', 'occasional'))
      ), '') ||
      coalesce(E'\n  Get in: ' || nullif(btrim(c.access_notes), ''), '') ||
      coalesce(E'\n  Standing: ' || nullif((
        select string_agg(d.name || ': ' || btrim(d.standing_instructions), ' | ' order by d.name)
          from public.dogs d
         where d.client_id = c.id
           and nullif(btrim(coalesce(d.standing_instructions, '')), '') is not null
           and ((a.dog_ids is not null and d.id = any(a.dog_ids)) or a.dog_ids is null)
      ), ''), '') ||
      coalesce(E'\n  Follow up: ' || nullif((
        select string_agg(d.name || ': ' || f.body, ' | ' order by f.created_at)
          from public.dog_followups f
          join public.dogs d on d.id = f.dog_id
         where d.client_id = c.id and f.status = 'open'
      ), ''), '')
      as stop_line
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
   where (a.scheduled_start at time zone v_tz)::date = v_day
     and a.status not in ('cancelled', 'no_show', 'skipped')
  ) t;

  -- Yesterday's brief is history the moment a new evening arrives.
  update public.briefings set status = 'resolved', acted_at = now(),
         disposition = 'Superseded by the next day-before brief.'
   where agent_key = 'tomorrow' and status in ('new', 'read');

  if coalesce(v_count, 0) = 0 then
    return;
  end if;

  insert into public.briefings (agent_key, department, severity, title, body, status)
  values ('tomorrow', 'operations', 'info',
    format('Tomorrow: %s stop%s (%s)', v_count, case when v_count = 1 then '' else 's' end,
           to_char(v_day, 'FMDay, Mon FMDD')),
    v_body, 'new');
end;
$$;
revoke all on function public._tomorrow_brief() from public, anon, authenticated;
grant execute on function public._tomorrow_brief() to service_role;

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active)
values ('tomorrow', 'Day-before brief', 'operations',
        'Every evening, one card with tomorrow''s route in order: times, clients, dogs, how to get in, standing instructions, and open follow-ups. Zero-minute morning prep.',
        '30 22 * * *', true)
on conflict (agent_key) do nothing;
select cron.schedule('tomorrow-brief-daily', '30 22 * * *', 'select public._tomorrow_brief();');
