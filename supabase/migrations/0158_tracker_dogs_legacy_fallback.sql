-- 0158: tracker_status dog names for legacy clients. Becky Swinford's live
-- tracker said "your dog's visit" because her subscriber row (created by the
-- calendar sync) has no bath_dogs rows; only funnel signups and hand-built
-- test subscribers had them, which is why Michelle's tracker showed names and
-- Becky's did not. The name chain is now: explicit appointment dog list ->
-- bath_dogs (funnel) -> the client's regular roster in public.dogs (legacy).
-- The is/are grammar on the page was always fine; it just had no names.

create or replace function public.tracker_status(p_token text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
  v public.visits%rowtype;
  v_first text;
  v_client uuid;
  v_dogs jsonb;
  v_stage text;
begin
  if p_token is null or length(p_token) < 16 then
    return jsonb_build_object('found', false);
  end if;

  select * into a from public.bath_appointments where tracker_token = p_token;
  if not found then
    return jsonb_build_object('found', false);
  end if;

  if a.scheduled_end is not null and now() > a.scheduled_end + interval '7 days' then
    return jsonb_build_object('found', true, 'stage', 'expired');
  end if;

  select * into v from public.visits
   where appointment_id = a.id
   order by created_at desc
   limit 1;

  select s.first_name, s.client_id into v_first, v_client
    from public.bath_subscribers s where s.id = a.subscriber_id;
  if v_first is null and v_client is not null then
    select split_part(c.name, ' ', 1) into v_first from public.clients c where c.id = v_client;
  end if;

  -- An appointment with an assigned dog list shows only those dogs; otherwise
  -- the funnel dogs; otherwise the legacy client's regular roster.
  if a.dog_ids is not null and array_length(a.dog_ids, 1) > 0 then
    select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
      from public.dogs d where d.id = any(a.dog_ids);
  else
    select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
      from public.bath_dogs d where d.subscriber_id = a.subscriber_id;
    if (v_dogs is null or v_dogs = '[]'::jsonb) and v_client is not null then
      select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
        from public.dogs d
       where d.client_id = v_client
         and coalesce(d.roster_status, 'regular') in ('regular', 'occasional');
    end if;
  end if;

  v_stage := case
    when a.status in ('cancelled', 'no_show', 'skipped') then 'inactive'
    when a.status = 'completed' or v.departed_at is not null then 'done'
    when a.status = 'returning' then 'returning'
    when a.status = 'in_service' then 'underway'
    when a.status = 'on_site' or v.arrived_at is not null then
      case
        when v.id is not null and exists (
          select 1 from public.visit_photos vp
           where vp.visit_id = v.id and vp.kind = 'before')
          then 'underway'
        else 'arrived'
      end
    when a.status = 'on_the_way' or v.inbound_at is not null then 'on_the_way'
    else 'scheduled'
  end;

  return jsonb_build_object(
    'found', true,
    'stage', v_stage,
    'scheduled_start', a.scheduled_start,
    'scheduled_end', a.scheduled_end,
    'first_name', v_first,
    'dogs', v_dogs
  );
end;
$$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;
