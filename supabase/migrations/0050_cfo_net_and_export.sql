-- 0050_cfo_net_and_export.sql
-- Net = revenue collected minus business expenses over the same window, fed to
-- the CFO's daily note. Plus an expense export for the accountant
-- (books_complement_not_replace).

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
  select count(*), coalesce(sum(amount_cents),0) into v_ar_count, v_ar_cents
    from public.bath_appointments where payment_status='pending' and scheduled_start < now();
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

create or replace function public.admin_export_expenses(p_from date default null, p_to date default null)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'txn_date', txn_date, 'description', description, 'amount', round(amount_cents/100.0,2),
      'category', category, 'is_business', is_business, 'source', source, 'notes', notes) order by txn_date)
    from public.expenses
    where (p_from is null or txn_date >= p_from) and (p_to is null or txn_date <= p_to)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_export_expenses(date, date) from public;
grant execute on function public.admin_export_expenses(date, date) to authenticated;

-- admin_finance_summary also gains expenses_cents + net_cents (full body in the
-- prod function; this comment marks where the Net figure on the Finance pane
-- comes from). See the applied migration finance_summary_net.
