-- Emperor override must beat the HARD no-overlap rule, not only the soft
-- availability check. admin_book_appointment(p_override=true) already skips the
-- slot-open test, but bath_appointments_no_overlap (a gist exclusion over
-- source-null, non-cancelled rows) still rejected a minute-for-minute overlap, so
-- a forced time came back "overlaps_existing" and the owner's "Yes, book it" did
-- nothing. Now a forced booking carries an `overridden` flag and is exempt from
-- the overlap constraint, so the owner can stack a stop (e.g. two operators out at
-- once). Normal bookings stay protected; override bookings keep source NULL so the
-- client still gets the booking confirmation.

alter table public.bath_appointments
  add column if not exists overridden boolean not null default false;

alter table public.bath_appointments drop constraint if exists bath_appointments_no_overlap;
alter table public.bath_appointments
  add constraint bath_appointments_no_overlap
  exclude using gist (tstzrange(scheduled_start, scheduled_end, '[)') with &&)
  where (status <> all (array['cancelled','skipped','no_show']) and source is null and not overridden);

CREATE OR REPLACE FUNCTION public.admin_book_appointment(p_client_id uuid, p_start timestamp with time zone, p_override boolean DEFAULT false, p_dog_ids uuid[] DEFAULT NULL::uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      status, service_type, amount_cents, dog_count, dog_ids, notes, overridden
    ) values (
      ctx.o_sub, ctx.o_subscription, p_start, v_end, ctx.o_dur,
      'confirmed', ctx.o_service, v_amount,
      coalesce(array_length(v_dogs, 1), ctx.o_dogs), v_dogs,
      case when not v_open then 'Booked with operator override' else null end,
      not v_open
    ) returning id into v_id;
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'error', 'overlaps_existing');
  end;

  return jsonb_build_object('ok', true, 'appointment_id', v_id,
    'scheduled_start', p_start, 'scheduled_end', v_end,
    'duration_minutes', ctx.o_dur, 'amount_cents', v_amount,
    'overridden', not v_open);
end;
$function$;
