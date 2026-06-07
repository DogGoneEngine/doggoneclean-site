-- 0012_portal_visit_actions.sql
--
-- Per-visit self-service: a client reschedules or skips their own upcoming
-- bath without anyone in the loop. bath_appointments exposes no direct
-- write policy, so both actions live in SECURITY DEFINER functions scoped
-- to the caller's auth.uid().
--
-- Reschedule lands only on a genuinely free slot: the new time is validated
-- against bath_open_slots (the same grid the booking funnel uses), so a
-- client can never double-book the trailer or pick a closed day. No operator
-- confirmation step: a valid open slot is the confirmation.
--
-- The 24-hour lock mirrors the charge window (auto_charge_at_24h): once a
-- visit is inside 24 hours it can no longer be moved or skipped from the
-- portal, because that is when it bills. Price is left unchanged on a move
-- for now; interval-based repricing belongs with the charging engine and is
-- not invented here (real_data_only / do not build it until it is real).

-- ── Skip one upcoming visit ────────────────────────────────────────────
create or replace function public.bath_skip_appointment(p_appointment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_appt record;
begin
  select a.*
    into v_appt
  from public.bath_appointments a
  join public.bath_subscribers b on b.id = a.subscriber_id
  where a.id = p_appointment_id
    and b.auth_user_id = auth.uid();

  if v_appt.id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_appt.status not in ('requested', 'confirmed') then
    return jsonb_build_object('ok', false, 'error', 'not_skippable');
  end if;

  if v_appt.scheduled_start <= now() + interval '24 hours' then
    return jsonb_build_object('ok', false, 'error', 'too_late');
  end if;

  update public.bath_appointments
     set status = 'skipped', updated_at = now()
   where id = v_appt.id;

  return jsonb_build_object('ok', true, 'status', 'skipped');
end;
$$;

-- ── Reschedule one upcoming visit to a free slot ───────────────────────
create or replace function public.bath_reschedule_appointment(
  p_appointment_id uuid,
  p_new_start      timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_appt     record;
  v_city_id  uuid;
  v_slot_min integer;
  v_slot_ok  boolean;
begin
  select a.*, b.city_id as subscriber_city_id
    into v_appt
  from public.bath_appointments a
  join public.bath_subscribers b on b.id = a.subscriber_id
  where a.id = p_appointment_id
    and b.auth_user_id = auth.uid();

  if v_appt.id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_appt.status not in ('requested', 'confirmed') then
    return jsonb_build_object('ok', false, 'error', 'not_reschedulable');
  end if;

  if v_appt.scheduled_start <= now() + interval '24 hours' then
    return jsonb_build_object('ok', false, 'error', 'too_late');
  end if;

  v_city_id := v_appt.subscriber_city_id;

  select hb_slot_minutes into v_slot_min
    from public.cities where id = v_city_id;

  -- No published duration means no slots exist to move onto.
  if v_slot_min is null then
    return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
  end if;

  -- The chosen time must be a real, currently-free slot on the grid.
  select exists (
    select 1
    from public.bath_open_slots(v_city_id, p_new_start, p_new_start + interval '1 second')
    where slot_start = p_new_start
  ) into v_slot_ok;

  if not v_slot_ok then
    return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
  end if;

  update public.bath_appointments
     set original_scheduled_start = coalesce(original_scheduled_start, scheduled_start),
         scheduled_start = p_new_start,
         scheduled_end   = p_new_start + make_interval(mins => v_slot_min),
         updated_at = now()
   where id = v_appt.id;

  return jsonb_build_object('ok', true, 'status', v_appt.status, 'new_start', p_new_start);
end;
$$;

revoke all on function public.bath_skip_appointment(uuid)                  from public, anon;
revoke all on function public.bath_reschedule_appointment(uuid, timestamptz) from public, anon;
grant execute on function public.bath_skip_appointment(uuid)                  to authenticated;
grant execute on function public.bath_reschedule_appointment(uuid, timestamptz) to authenticated;
