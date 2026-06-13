-- 0181_book_price_by_selected_dogs.sql
--
-- Bug from the field (Paul, 2026-06-13): he booked Tonya Hunt for just Koa, and
-- the Today stop showed $450 instead of $100. Cause: admin_book_appointment set
-- dog_count from the selected dogs (correctly 1) but set amount_cents to the
-- subscription's base price (the whole book, all four dogs = $450), ignoring
-- which dogs were actually picked. Fix: when specific dogs are booked, price the
-- appointment as the sum of THOSE dogs' price_cents; fall back to the
-- subscription base only when no dogs are specified (the default all-dogs book).
-- See price_by_dogs_going in the Oracle.

drop function if exists public.admin_book_appointment(uuid, timestamptz, boolean, uuid[]);
create or replace function public.admin_book_appointment(
  p_client_id uuid, p_start timestamptz, p_override boolean default false, p_dog_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  ctx record;
  v_open boolean;
  v_id uuid;
  v_end timestamptz;
  v_dogs uuid[];
  v_amount int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_start is null or p_start <= now() then
    return jsonb_build_object('ok', false, 'error', 'start_in_past');
  end if;

  if p_dog_ids is not null and array_length(p_dog_ids, 1) > 0 then
    select array_agg(d.id) into v_dogs
      from public.dogs d
     where d.id = any(p_dog_ids) and d.client_id = p_client_id;
    if coalesce(array_length(v_dogs, 1), 0) <> array_length(p_dog_ids, 1) then
      return jsonb_build_object('ok', false, 'error', 'dogs_not_this_client');
    end if;
  end if;

  select * into ctx from public._client_booking_context(p_client_id);
  v_end := p_start + make_interval(mins => ctx.o_dur);

  -- Price the dogs actually going. Only when no dogs are named does it fall back
  -- to the subscription base (the whole-book price).
  v_amount := null;
  if v_dogs is not null and array_length(v_dogs, 1) > 0 then
    select nullif(sum(coalesce(d.price_cents, 0)), 0)::int into v_amount
      from public.dogs d where d.id = any(v_dogs);
  end if;
  v_amount := coalesce(v_amount, ctx.o_price, 0);

  select exists (
    select 1 from public.bath_open_slots(ctx.o_city, p_start - interval '1 second', p_start + interval '1 second', ctx.o_dur) s
     where s.slot_start = p_start
  ) into v_open;

  if not v_open and not p_override then
    return jsonb_build_object('ok', false, 'error', 'slot_conflict',
      'duration_minutes', ctx.o_dur,
      'overlaps', coalesce((
        select jsonb_agg(jsonb_build_object('start', a.scheduled_start, 'client',
            (select c2.name from public.bath_subscribers s2 left join public.clients c2 on c2.id = s2.client_id where s2.id = a.subscriber_id)))
          from public.bath_appointments a
         where a.status not in ('cancelled','skipped','no_show')
           and a.scheduled_start < v_end and coalesce(a.scheduled_end, a.scheduled_start) > p_start
      ), '[]'::jsonb));
  end if;

  begin
    insert into public.bath_appointments (
      subscriber_id, subscription_id, scheduled_start, scheduled_end, duration_minutes,
      status, service_type, amount_cents, dog_count, dog_ids, notes
    ) values (
      ctx.o_sub, ctx.o_subscription, p_start, v_end, ctx.o_dur,
      'confirmed', ctx.o_service, v_amount,
      coalesce(array_length(v_dogs, 1), ctx.o_dogs), v_dogs,
      case when not v_open then 'Booked with operator override' else null end
    ) returning id into v_id;
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'error', 'overlaps_existing');
  end;

  return jsonb_build_object('ok', true, 'appointment_id', v_id,
    'scheduled_start', p_start, 'scheduled_end', v_end,
    'duration_minutes', ctx.o_dur, 'amount_cents', v_amount,
    'overridden', not v_open);
end;
$$;
revoke all on function public.admin_book_appointment(uuid, timestamptz, boolean, uuid[]) from public, anon;
grant execute on function public.admin_book_appointment(uuid, timestamptz, boolean, uuid[]) to authenticated, service_role;

-- Correct the appointment that surfaced the bug: Tonya Hunt, today, Koa only.
update public.bath_appointments
   set amount_cents = (select nullif(sum(coalesce(d.price_cents,0)),0)::int from public.dogs d where d.id = any(dog_ids))
 where id = '32e6a749-ddb7-45bd-a575-552cc1e9bef8'
   and dog_ids is not null;
