-- 0051_finance_summary_net.sql
-- admin_finance_summary gains expenses_cents + net_cents so the Finance pane
-- shows Net after costs alongside revenue.

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
  select count(*), coalesce(sum(amount_cents),0) into v_ar_count, v_ar_cents
    from public.bath_appointments where payment_status='pending' and scheduled_start < now();
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
