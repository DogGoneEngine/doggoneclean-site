-- 0056_pricing_grid.sql
-- Pricing floor: a read-only view of the locked city price grid. Prices are a
-- settled decision (no_unilateral_deviation), so this surfaces them in one place
-- without making them casually editable from a dashboard.
create or replace function public.admin_pricing_grid()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', name, 'state', state, 'active', hb_active,
      'smoothcoat_recurring_cents', hb_smoothcoat_recurring_cents,
      'smoothcoat_single_cents', hb_smoothcoat_single_cents,
      'doublecoat_recurring_cents', hb_doublecoat_recurring_cents,
      'doublecoat_single_cents', hb_doublecoat_single_cents,
      'addon_decrement_cents', hb_addon_decrement_cents,
      'founders_smoothcoat_cents', hb_founders_smoothcoat_cents,
      'founders_doublecoat_cents', hb_founders_doublecoat_cents,
      'founders_cap', hb_founders_cap,
      'smoothcoat_minutes', hb_smoothcoat_minutes, 'doublecoat_minutes', hb_doublecoat_minutes,
      'slot_minutes', hb_slot_minutes, 'buffer_minutes', hb_buffer_minutes,
      'min_stop_minutes', hb_min_stop_minutes, 'booking_horizon_days', hb_booking_horizon_days,
      'timezone', hb_timezone
    ) order by hb_active desc, name)
    from public.cities), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_pricing_grid() from public;
grant execute on function public.admin_pricing_grid() to authenticated;
