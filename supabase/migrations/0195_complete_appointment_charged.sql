-- 0195_complete_appointment_charged.sql
-- Capture Charged (the quoted amount) when completing an appointment, so the Time is Money
-- ledger keeps the charged-vs-collected spread going forward, not just Paid. Defaults to the
-- appointment's amount_cents when not given.
drop function if exists public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[], jsonb);
create or replace function public.admin_complete_appointment(
  p_appointment_id uuid,
  p_work_done text default null,
  p_visit_notes text default null,
  p_actual_minutes integer default null,
  p_amount_collected_cents integer default null,
  p_tip_cents integer default null,
  p_payment_method text default null,
  p_condition_flags text[] default null,
  p_dog_ids uuid[] default null,
  p_dog_scores jsonb default null,
  p_charged_cents integer default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid; v_admin uuid; v_sub uuid; v_client uuid; v_stype text; v_amt integer;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select subscriber_id, service_type, amount_cents into v_sub, v_stype, v_amt
    from public.bath_appointments where id = p_appointment_id;
  if not found then raise exception 'appointment not found'; end if;
  select client_id into v_client from public.bath_subscribers where id = v_sub;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  update public.bath_appointments
     set status = 'completed', duration_minutes = coalesce(p_actual_minutes, duration_minutes), updated_at = now()
   where id = p_appointment_id;
  insert into public.visits (
    client_id, subscriber_id, appointment_id, visited_at, service_type,
    dog_ids, work_done, visit_notes, condition_flags, actual_minutes,
    amount_collected_cents, tip_cents, payment_method, source, completed_by, charged_cents
  ) values (
    v_client, v_sub, p_appointment_id, now(), v_stype,
    coalesce(p_dog_ids, '{}'), p_work_done, p_visit_notes, coalesce(p_condition_flags, '{}'), p_actual_minutes,
    coalesce(p_amount_collected_cents, v_amt), p_tip_cents, p_payment_method, 'appointment', v_admin,
    coalesce(p_charged_cents, v_amt)
  ) returning id into v_id;
  perform public._apply_visit_dog_scores(v_id, p_dog_scores);
  return v_id;
end;
$$;
revoke all on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[], jsonb, integer) from public;
grant execute on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[], jsonb, integer) to authenticated;
