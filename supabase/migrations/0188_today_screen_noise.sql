-- 0188_today_screen_noise.sql
--
-- Three sources of noise Paul hit on the Laelaps Today screen (2026-06-15),
-- each fixed in the durable layer so a redesign cannot reintroduce them.
--
-- 1. RECEIVABLES that were not receivables. The CFO brief said "20 open
--    receivables totaling $275". It was not a hallucination: cfo_brief_data and
--    admin_finance_summary both counted EVERY past, still-pending appointment as
--    A/R (payment_status='pending' and scheduled_start < now()). On Clean that
--    swept in 16 gcal_sync calendar rows (Paul's pressure-test schedule, no card
--    on file, billed in person), a cancelled appointment ($115), and several $0
--    rows. None is money owed. A real receivable is a visit that actually
--    HAPPENED (status='completed'), is priced (amount_cents > 0), is still
--    unpaid (payment_status='pending'), is past, and is not a test subscriber.
--    Today that count is correctly 0; post-launch it flags genuinely
--    completed-but-uncharged visits.
--
-- 2. FUTURE reminders shown a month early. The "On your plate" panel listed
--    every open reminder regardless of date, so a Riker note dated to a client's
--    NEXT visit ("ask Lisa about Gypsy's foot", due 2026-07-11) sat near the top
--    today. Migration 0152's own intent was "surfaces on Today when due".
--    admin_list_reminders now returns only due/overdue items in `open` (what
--    belongs on Today) and moves not-yet-due items to a separate `upcoming`
--    list. A reminder dated to the visit day appears on the visit day.
--
-- 3. The "Update hours" card that would not leave. The standing hours-reminder
--    briefing was resolved only by the inline Save-hours button on the card
--    itself. When hours were updated by any OTHER path (Riker voice service,
--    admin_update_equipment_hours by id, a direct write), the card was orphaned.
--    A trigger on public.equipment now resolves the open hours-reminder card for
--    that unit whenever its hours move, no matter which path moved them.

-- 1a. CFO brief data: A/R is completed, priced, unpaid, past, non-test.
create or replace function public.cfo_brief_data(p_window_days integer default 90)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_visits int; v_priced int; v_timed int; v_revenue bigint; v_minutes bigint; v_clients int;
  v_rph numeric; v_prev_rph numeric; v_ar_count int; v_ar_cents bigint; v_top jsonb;
  v_expenses bigint; v_exp_count int;
begin
  select count(*), count(*) filter (where amount_collected_cents is not null),
         count(*) filter (where actual_minutes is not null),
         coalesce(sum(amount_collected_cents),0), coalesce(sum(actual_minutes),0), count(distinct client_id)
    into v_visits, v_priced, v_timed, v_revenue, v_minutes, v_clients
    from public.visits where visited_at >= now() - make_interval(days => p_window_days);
  if v_minutes>0 and v_revenue>0 then v_rph := round((v_revenue/100.0)/(v_minutes/60.0),2); end if;
  select case when sum(actual_minutes)>0 and sum(amount_collected_cents)>0
              then round((sum(amount_collected_cents)/100.0)/(sum(actual_minutes)/60.0),2) end
    into v_prev_rph from public.visits
   where visited_at >= now() - make_interval(days => p_window_days*2) and visited_at < now() - make_interval(days => p_window_days);
  select count(*), coalesce(sum(ba.amount_cents),0) into v_ar_count, v_ar_cents
    from public.bath_appointments ba
    join public.bath_subscribers s on s.id = ba.subscriber_id
   where ba.payment_status = 'pending'
     and ba.status = 'completed'
     and ba.amount_cents > 0
     and ba.scheduled_start < now()
     and coalesce(s.is_test, false) = false;
  select coalesce(sum(amount_cents),0), count(*) into v_expenses, v_exp_count
    from public.expenses where is_business and txn_date >= (now() - make_interval(days => p_window_days))::date;
  select coalesce(jsonb_agg(jsonb_build_object('name', name, 'visits', visits, 'collected_cents', cents) order by cents desc), '[]'::jsonb)
    into v_top from (
      select c.name, count(*) visits, coalesce(sum(v.amount_collected_cents),0) cents
        from public.visits v join public.clients c on c.id=v.client_id
       where v.visited_at >= now() - make_interval(days => p_window_days)
       group by c.name order by cents desc nulls last limit 5) t;
  return jsonb_build_object(
    'window_days', p_window_days, 'visits', v_visits, 'priced_visits', v_priced, 'timed_visits', v_timed,
    'clients', v_clients, 'revenue_cents', v_revenue, 'minutes', v_minutes,
    'revenue_per_hour', v_rph, 'prev_revenue_per_hour', v_prev_rph,
    'no_shows', 0, 'ar_count', v_ar_count, 'ar_cents', v_ar_cents,
    'expenses_cents', v_expenses, 'expense_count', v_exp_count, 'net_cents', v_revenue - v_expenses,
    'top_clients', v_top);
end;
$$;
revoke all on function public.cfo_brief_data(integer) from public, authenticated, anon;
grant execute on function public.cfo_brief_data(integer) to service_role;

-- 1b. Finance pane summary: same corrected A/R definition.
create or replace function public.admin_finance_summary(p_window_days integer default 90)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_visits int; v_priced int; v_timed int; v_revenue bigint; v_minutes bigint; v_clients int;
  v_rph numeric; v_prev_rph numeric; v_ar_count int; v_ar_cents bigint;
  v_paymix jsonb; v_byservice jsonb; v_monthly jsonb; v_top jsonb; v_expenses bigint;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select count(*), count(*) filter (where amount_collected_cents is not null),
         count(*) filter (where actual_minutes is not null),
         coalesce(sum(amount_collected_cents),0), coalesce(sum(actual_minutes),0), count(distinct client_id)
    into v_visits, v_priced, v_timed, v_revenue, v_minutes, v_clients
    from public.visits where visited_at >= now() - make_interval(days => p_window_days);
  if v_minutes>0 and v_revenue>0 then v_rph := round((v_revenue/100.0)/(v_minutes/60.0),2); end if;
  select case when sum(actual_minutes)>0 and sum(amount_collected_cents)>0
              then round((sum(amount_collected_cents)/100.0)/(sum(actual_minutes)/60.0),2) end
    into v_prev_rph from public.visits
   where visited_at >= now() - make_interval(days => p_window_days*2) and visited_at < now() - make_interval(days => p_window_days);
  select count(*), coalesce(sum(ba.amount_cents),0) into v_ar_count, v_ar_cents
    from public.bath_appointments ba
    join public.bath_subscribers s on s.id = ba.subscriber_id
   where ba.payment_status = 'pending'
     and ba.status = 'completed'
     and ba.amount_cents > 0
     and ba.scheduled_start < now()
     and coalesce(s.is_test, false) = false;
  select coalesce(sum(amount_cents),0) into v_expenses
    from public.expenses where is_business and txn_date >= (now() - make_interval(days => p_window_days))::date;

  select coalesce(jsonb_agg(jsonb_build_object('method', method, 'visits', n, 'cents', cents) order by cents desc), '[]'::jsonb)
    into v_paymix from (
      select coalesce(payment_method,'invoice_or_other') as method, count(*) n, coalesce(sum(amount_collected_cents),0) cents
        from public.visits where visited_at >= now() - make_interval(days => p_window_days)
        group by coalesce(payment_method,'invoice_or_other')) p;
  select coalesce(jsonb_agg(jsonb_build_object('service', service, 'visits', n, 'cents', cents, 'minutes', mins) order by cents desc), '[]'::jsonb)
    into v_byservice from (
      select coalesce(service_type,'unknown') as service, count(*) n, coalesce(sum(amount_collected_cents),0) cents, coalesce(sum(actual_minutes),0) mins
        from public.visits where visited_at >= now() - make_interval(days => p_window_days)
        group by coalesce(service_type,'unknown')) s;
  select coalesce(jsonb_agg(jsonb_build_object('month', to_char(mon,'Mon YYYY'), 'cents', cents,
           'rev_per_hour', case when mins>0 and cents>0 then round((cents/100.0)/(mins/60.0),2) end) order by mon), '[]'::jsonb)
    into v_monthly from (
      select date_trunc('month', visited_at) mon, coalesce(sum(amount_collected_cents),0) cents, coalesce(sum(actual_minutes),0) mins
        from public.visits where visited_at >= date_trunc('month', now()) - interval '5 months' group by 1) mth;
  select coalesce(jsonb_agg(jsonb_build_object('name', name, 'visits', visits, 'cents', cents) order by cents desc), '[]'::jsonb)
    into v_top from (
      select c.name, count(*) visits, coalesce(sum(v.amount_collected_cents),0) cents
        from public.visits v join public.clients c on c.id=v.client_id
       where v.visited_at >= now() - make_interval(days => p_window_days) group by c.name order by cents desc nulls last limit 8) t;

  return jsonb_build_object(
    'window_days', p_window_days, 'visits', v_visits, 'priced_visits', v_priced, 'timed_visits', v_timed,
    'clients', v_clients, 'revenue_cents', v_revenue, 'minutes', v_minutes,
    'revenue_per_hour', v_rph, 'prev_revenue_per_hour', v_prev_rph,
    'ar_count', v_ar_count, 'ar_cents', v_ar_cents,
    'expenses_cents', v_expenses, 'net_cents', v_revenue - v_expenses,
    'payment_mix', v_paymix, 'by_service', v_byservice, 'monthly', v_monthly, 'top_clients', v_top);
end;
$$;
revoke all on function public.admin_finance_summary(integer) from public;
grant execute on function public.admin_finance_summary(integer) to authenticated;

-- 2. Reminders surface on Today only when due. `open` = due/overdue;
-- `upcoming` = not yet due (available for a future peek, off the plate today).
create or replace function public.admin_list_reminders()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return jsonb_build_object(
    'open', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_id', r.client_id, 'client_name', c.name,
          'overdue', r.due_date < current_date,
          'due', r.due_date <= current_date)
        order by r.due_date, r.created_at)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'open' and r.due_date <= current_date), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_id', r.client_id, 'client_name', c.name)
        order by r.due_date, r.created_at)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'open' and r.due_date > current_date), '[]'::jsonb),
    'recently_done', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_name', c.name, 'done_at', r.done_at)
        order by r.done_at desc)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'done' and r.done_at > now() - interval '7 days'), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_list_reminders() from public, anon;
grant execute on function public.admin_list_reminders() to authenticated, service_role;

-- 3. Updating equipment hours by ANY path clears the standing hours-reminder
-- card for that unit. The card existed to get the reading entered; once the
-- reading moves, the card has done its job.
create or replace function public._resolve_hours_reminder_on_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (new.current_hours is distinct from old.current_hours)
     or (new.hours_updated_at is distinct from old.hours_updated_at) then
    update public.briefings
       set status = 'resolved',
           disposition = coalesce(disposition, 'auto: hours updated'),
           acted_at = now()
     where agent_key = 'maintenance'
       and evidence->>'kind' = 'hours_reminder'
       and (evidence->>'equipment_id')::uuid = new.id
       and status in ('new', 'read');
  end if;
  return new;
end;
$$;
-- Trigger-only: it fires as a trigger regardless of EXECUTE grants, so close
-- the direct RPC surface (no anon/authenticated should call it by hand).
revoke all on function public._resolve_hours_reminder_on_update() from public, anon, authenticated;

drop trigger if exists trg_resolve_hours_reminder on public.equipment;
create trigger trg_resolve_hours_reminder
  after update on public.equipment
  for each row execute function public._resolve_hours_reminder_on_update();
