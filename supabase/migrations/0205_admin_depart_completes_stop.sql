-- 0205: "All done, rolling out" must complete the stop, not just stamp the time
-- (Paul, 2026-06-18, field bug). The Today step button's final tap stamped the
-- departed time but left the appointment status at 'returning', so the StopCard
-- looked wrapped (it treats a departed stamp as wrapped) while the appointment
-- was stuck mid-stage underneath. Anything that reads status (schedule, the
-- now-card window, reports) saw a stop that never finished. admin_depart is the
-- lightweight final flip, mirroring admin_returning / admin_arrived: it stamps
-- departed (if not already) AND sets status = 'completed'. The undo path already
-- treats departed-or-completed as the "All done" state and rolls both back.
--
-- Also a one-time cleanup of any stop left in an active status with a departed
-- stamp (Colleen Smith's 2026-06-17 visit, and any other test stop like it).
--
-- This does NOT charge: legacy bills in person and v2 charges at the 24h cron;
-- admin_complete_appointment remains the separate heavier visit-logging path.
--
-- Applied to dgc-prod 2026-06-18.

create or replace function public.admin_depart(p_appointment uuid, p_at timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_dep timestamptz;
  v_res jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if not exists (select 1 from public.bath_appointments where id = p_appointment) then
    raise exception 'appointment not found';
  end if;

  select departed_at into v_dep
    from public.visits where appointment_id = p_appointment order by created_at limit 1;

  if v_dep is null then
    -- stamps departed (creating the visit if needed) and returns the clock row
    v_res := public.admin_stamp_appointment_time(p_appointment, 'departed', p_at);
  else
    select jsonb_build_object('visit_id', id, 'inbound_at', inbound_at, 'arrived_at', arrived_at,
                              'departed_at', departed_at, 'actual_minutes', actual_minutes)
      into v_res from public.visits where appointment_id = p_appointment order by created_at limit 1;
  end if;

  update public.bath_appointments set status = 'completed', updated_at = now()
   where id = p_appointment;

  return coalesce(v_res, '{}'::jsonb) || jsonb_build_object('status', 'completed');
end;
$$;
revoke all on function public.admin_depart(uuid, timestamptz) from public, anon;
grant execute on function public.admin_depart(uuid, timestamptz) to authenticated, service_role;

-- One-time cleanup: stops that were wrapped (departed stamped) but left in an
-- active status by the old final-step bug.
update public.bath_appointments a
   set status = 'completed', updated_at = now()
 where a.status in ('on_the_way', 'on_site', 'in_service', 'returning')
   and exists (select 1 from public.visits v where v.appointment_id = a.id and v.departed_at is not null);
