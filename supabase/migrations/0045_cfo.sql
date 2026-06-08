-- 0045_cfo.sql
-- The CFO department head, v1: a deterministic compute layer that reads the real
-- book (visits + bath_appointments) and writes a briefing with cited evidence
-- into the briefings feed. This is the "recommend, never act" loop end to end:
-- the CFO computes the numbers and leaves a memo; the human reads it on Today.
--
-- The LLM narration layer (a scheduled edge function that calls the Claude API
-- to write the briefing in the CFO's voice) layers on top of this exact data
-- once an anthropic_api_key secret is present; until then this rules engine
-- already surfaces real signal, including the most useful early CFO finding:
-- that visit prices and durations need to be captured before revenue-per-hour
-- (the metric Paul optimizes) can be measured.

create or replace function public.admin_compute_cfo_briefing(p_window_days integer default 90)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run uuid; v_brief uuid;
  v_visits int; v_priced int; v_timed int;
  v_revenue bigint; v_minutes bigint; v_clients int;
  v_noshow int; v_ar_count int; v_ar_cents bigint;
  v_rev_per_hour numeric; v_title text; v_body text; v_sev text; v_rec jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  insert into public.agent_runs (agent_key, status, model, input_summary)
  values ('cfo', 'ok', 'rules-v1', jsonb_build_object('window_days', p_window_days))
  returning id into v_run;

  select count(*),
         count(*) filter (where amount_collected_cents is not null),
         count(*) filter (where actual_minutes is not null),
         coalesce(sum(amount_collected_cents), 0),
         coalesce(sum(actual_minutes), 0),
         count(distinct client_id)
    into v_visits, v_priced, v_timed, v_revenue, v_minutes, v_clients
    from public.visits
   where visited_at >= now() - make_interval(days => p_window_days);

  select count(*) into v_noshow
    from public.bath_appointments
   where status = 'no_show' and scheduled_start >= now() - make_interval(days => p_window_days);

  select count(*), coalesce(sum(amount_cents), 0) into v_ar_count, v_ar_cents
    from public.bath_appointments
   where payment_status = 'pending' and scheduled_start < now();

  if v_minutes > 0 and v_revenue > 0 then
    v_rev_per_hour := round((v_revenue / 100.0) / (v_minutes / 60.0), 2);
  end if;

  -- The CFO leads with the binding constraint. Pre-launch, that is almost
  -- always that money and time per visit are not being captured yet.
  if v_priced < greatest(1, v_visits) * 0.5 then
    v_sev := 'signal';
    v_title := 'Capture what you collect to unlock revenue per hour';
    v_body := format(
      'Over the last %s days I see %s visits across %s clients, but only %s have a collected amount and %s have a recorded time. I cannot yet measure revenue per hour (the number you run the business on) until those are captured at the visit. Recommendation: log the collected amount and minutes on each visit going forward (the Log a visit form does this). Once a few weeks of priced visits exist I can trend revenue per hour by client, city, and service.',
      p_window_days, v_visits, v_clients, v_priced, v_timed);
    v_rec := jsonb_build_object('kind', 'capture_visit_money', 'note', 'Fill collected amount and minutes when logging visits.');
  else
    v_sev := 'info';
    v_title := format('Revenue per hour: %s', coalesce('$' || v_rev_per_hour::text, 'not yet measurable'));
    v_body := format(
      'Last %s days: %s visits, %s clients, %s collected on the %s priced visits.%s Accounts receivable: %s appointment(s) past their date still pending%s.',
      p_window_days, v_visits, v_clients, '$' || round(v_revenue/100.0, 2)::text, v_priced,
      case when v_rev_per_hour is not null then ' Revenue per hour is $' || v_rev_per_hour::text || ' on recorded time.' else '' end,
      v_ar_count, case when v_ar_cents > 0 then ' worth $' || round(v_ar_cents/100.0,2)::text else '' end);
    v_rec := null;
  end if;

  insert into public.briefings (agent_key, department, severity, title, body, evidence, recommended_action, run_id)
  values ('cfo', 'finance', v_sev, v_title, v_body,
    jsonb_build_object(
      'window_days', p_window_days,
      'visits', v_visits, 'priced_visits', v_priced, 'timed_visits', v_timed,
      'clients', v_clients, 'revenue_cents', v_revenue, 'minutes', v_minutes,
      'revenue_per_hour', v_rev_per_hour, 'no_shows', v_noshow,
      'ar_count', v_ar_count, 'ar_cents', v_ar_cents),
    v_rec, v_run)
  returning id into v_brief;

  update public.agent_runs set finished_at = now() where id = v_run;
  update public.agents set is_active = true, updated_at = now() where agent_key = 'cfo';
  return v_brief;
end;
$$;
revoke all on function public.admin_compute_cfo_briefing(integer) from public;
grant execute on function public.admin_compute_cfo_briefing(integer) to authenticated;
