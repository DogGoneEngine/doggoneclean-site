-- 0013_portal_change_cadence.sql
--
-- Client self-service: switch the recurring cadence between every 4 weeks
-- and every 2 weeks. SECURITY DEFINER, scoped to the caller's auth.uid(),
-- because bath_subscriptions has no direct write policy.
--
-- Price is deliberately untouched: 4wk and 2wk are the same price (2wk is a
-- freshness upgrade, not an upsell). That rule lives here, in the function,
-- so it cannot be lost by editing a button: base_price_cents is never
-- written by this path. A one-off plan is not a recurring cadence and
-- cannot be toggled (starting recurring is a new booking, not a toggle).
create or replace function public.bath_change_cadence(p_cadence text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub_id uuid;
  v_cur    text;
begin
  if p_cadence not in ('4wk', '2wk') then
    return jsonb_build_object('ok', false, 'error', 'invalid_cadence');
  end if;

  select s.id, s.cadence
    into v_sub_id, v_cur
  from public.bath_subscriptions s
  join public.bath_subscribers b on b.id = s.subscriber_id
  where b.auth_user_id = auth.uid()
    and s.status = 'active'
  order by s.started_at desc
  limit 1;

  if v_sub_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_active_subscription');
  end if;

  if v_cur = 'oneoff' then
    return jsonb_build_object('ok', false, 'error', 'not_recurring');
  end if;

  -- cadence only; base_price_cents is intentionally never touched here.
  update public.bath_subscriptions
     set cadence = p_cadence, updated_at = now()
   where id = v_sub_id;

  return jsonb_build_object('ok', true, 'cadence', p_cadence);
end;
$$;

revoke all on function public.bath_change_cadence(text) from public, anon;
grant execute on function public.bath_change_cadence(text) to authenticated;
