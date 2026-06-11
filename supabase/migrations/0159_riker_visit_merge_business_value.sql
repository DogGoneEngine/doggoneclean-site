-- 0159: three things from Paul's 2026-06-11 night batch.
--
-- 1. The duplicate-visit glitch, root-caused: the stop flow now creates the
--    visit row itself (arrival stamps), so when Paul then tells Riker about
--    the same visit, Riker's INSERT made a second row; and a bare
--    visited_at date cast to midnight UTC displays as the previous evening
--    Eastern (Eric's "June 10" row). Fix: Riker now MERGES into an existing
--    visit on the same Eastern day (preferring the appointment-linked row)
--    and only inserts when none exists; bare dates are interpreted at noon
--    Eastern so they can never drift a day.
-- 2. Eric Shannon's records repaired: the Riker duplicate's payload (both
--    5s, $100 cash, the dogs) merged into the real appointment visit, the
--    duplicate deleted.
-- 3. admin_business_value: the continuously updated what-would-it-sell-for
--    gauge for the Finance floor (business_value_in_sight). Method: while
--    the expense ledger is thin, an annual-revenue multiple (the honest
--    small-service-business yardstick), adjusted for what we actually
--    measure: recurring-revenue share and year-over-year growth. The moment
--    expenses cover at least 5% of revenue the gauge switches to SDE
--    (seller's discretionary earnings = revenue minus business costs, the
--    solo-operator profit) times the standard 2.0 to 2.8 route-business
--    multiple, same adjustments. All inputs returned so the panel can show
--    its work; assumptions live here, in one place, for Paul to retune.

-- 2 first (data repair).
update public.visit_dog_ratings set visit_id = '244f690e-d663-48de-8161-90529436e9c4'
 where visit_id = '24f01c7c-c9b0-44e6-8902-31f86c410f19';
update public.visits set
  amount_collected_cents = coalesce(amount_collected_cents, 10000),
  payment_method = coalesce(payment_method, 'cash'),
  dog_ids = (select coalesce(array_agg(distinct x), '{}') from unnest(
    coalesce(dog_ids, '{}') || array['5ee827ba-c17e-4913-89fd-391d72a58d9b','9feba0b6-9a5b-49f1-b9cf-a301fed9dc4e']::uuid[]) x)
 where id = '244f690e-d663-48de-8161-90529436e9c4';
delete from public.visits where id = '24f01c7c-c9b0-44e6-8902-31f86c410f19' and source = 'riker';

-- 1. Riker visit merge.
create or replace function public.admin_riker_apply(p_plan jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare v_client uuid; v_sub uuid; v_admin uuid; v_visit uuid;
        v_scores int := 0; v_note boolean := false; v_dognotes int := 0; r record;
        v_np jsonb; v_np_id uuid; v_status int := 0; v_wisdom text; v_wisdom_saved boolean := false;
        v_rem jsonb; v_rem_id uuid;
        v_added int := 0; v_updated int := 0; v_dog uuid;
        v_scores_j jsonb; v_visit_at timestamptz; v_raw text;
        v_cli jsonb; v_client_updated boolean := false;
        v_vu jsonb; v_vu_id uuid; v_visit_corrected boolean := false; v_vu_missed boolean := false;
        v_visit_merged boolean := false; v_new_dog_ids uuid[];
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_client := nullif(p_plan->>'client_id','')::uuid;
  v_wisdom := nullif(btrim(coalesce(p_plan->>'wisdom','')),'');
  v_rem := p_plan->'reminder';
  if v_client is null and v_wisdom is null and jsonb_typeof(v_rem) <> 'object' then
    raise exception 'riker: no client resolved';
  end if;
  if v_client is not null and not exists (select 1 from public.clients where id = v_client) then
    raise exception 'riker: client not found';
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  if v_client is not null then
    select id into v_sub from public.bath_subscribers where client_id = v_client limit 1;
  end if;

  v_cli := p_plan->'client_update';
  if v_client is not null and jsonb_typeof(v_cli) = 'object' then
    update public.clients set
      phone_e164 = coalesce(nullif(v_cli->>'phone',''), phone_e164),
      email = coalesce(nullif(v_cli->>'email',''), email),
      location_address = coalesce(nullif(v_cli->>'address',''), location_address),
      suppress_winback = coalesce(nullif(v_cli->>'suppress_winback','')::boolean, suppress_winback),
      status = case when v_cli->>'status' in ('active','standing','one_off','at_will','inactive','moved_away')
                    then v_cli->>'status' else status end,
      data_gaps = case when nullif(v_cli->>'phone','') is not null
                       then array_remove(coalesce(data_gaps,'{}'), 'phone_number') else data_gaps end,
      updated_at = now()
     where id = v_client;
    v_client_updated := true;
  end if;

  v_vu := p_plan->'visit_update';
  if v_client is not null and jsonb_typeof(v_vu) = 'object' and nullif(v_vu->>'date','') is not null then
    select id into v_vu_id from public.visits
     where client_id = v_client
       and visited_at::date between (v_vu->>'date')::date - 1 and (v_vu->>'date')::date + 1
     order by abs(extract(epoch from visited_at - ((v_vu->>'date')::date::timestamp + interval '16 hours')))
     limit 1;
    if v_vu_id is null then
      v_vu_missed := true;
    else
      update public.visits set
        service_type = coalesce(nullif(v_vu->>'service_type',''), service_type),
        amount_collected_cents = coalesce(nullif(v_vu->>'amount_cents','')::int, amount_collected_cents),
        actual_minutes = coalesce(nullif(v_vu->>'actual_minutes','')::int, actual_minutes),
        visit_notes = case when nullif(btrim(coalesce(v_vu->>'visit_notes','')),'') is not null
                           then coalesce(visit_notes || ' ; ', '') || btrim(v_vu->>'visit_notes')
                           else visit_notes end
       where id = v_vu_id;
      v_visit_corrected := true;
    end if;
  end if;

  if v_client is not null then
    for r in select btrim(e->>'name') as name, nullif(btrim(coalesce(e->>'breed','')),'') as breed,
                    nullif(e->>'price_cents','')::int as price_cents,
                    nullif(btrim(coalesce(e->>'notes','')),'') as notes
               from jsonb_array_elements(coalesce(p_plan->'dog_add','[]')) e
              where nullif(btrim(coalesce(e->>'name','')),'') is not null
    loop
      if not exists (select 1 from public.dogs d where d.client_id = v_client and lower(d.name) = lower(r.name)) then
        insert into public.dogs (client_id, name, breed, price_cents, notes)
        values (v_client, r.name, r.breed, r.price_cents, r.notes);
        v_added := v_added + 1;
      end if;
    end loop;

    for r in select nullif(e->>'dog_id','')::uuid as dog_id, btrim(coalesce(e->>'dog_name','')) as dog_name,
                    nullif(e->>'price_cents','')::int as price_cents,
                    nullif(btrim(coalesce(e->>'breed','')),'') as breed
               from jsonb_array_elements(coalesce(p_plan->'dog_update','[]')) e
    loop
      v_dog := coalesce(r.dog_id,
        (select d.id from public.dogs d where d.client_id = v_client and lower(d.name) = lower(r.dog_name) limit 1));
      if v_dog is null then continue; end if;
      update public.dogs
         set price_cents = coalesce(r.price_cents, price_cents),
             breed = coalesce(r.breed, breed),
             updated_at = now()
       where id = v_dog and client_id = v_client
         and (r.price_cents is not null or r.breed is not null);
      if found then v_updated := v_updated + 1; end if;
    end loop;
  end if;

  if v_client is not null and jsonb_typeof(p_plan->'visit') = 'object' then
    -- Bare dates land at noon Eastern, never midnight UTC: midnight UTC is
    -- the previous evening here, which is how "today" displayed as yesterday.
    v_raw := nullif(p_plan->'visit'->>'visited_at','');
    if v_raw is null then
      v_visit_at := now();
    elsif length(v_raw) <= 10 then
      v_visit_at := ((v_raw::date)::timestamp + interval '12 hours') at time zone 'America/New_York';
    else
      v_visit_at := v_raw::timestamptz;
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
             'dog_id', coalesce(nullif(e->>'dog_id',''),
               (select d.id::text from public.dogs d
                 where d.client_id = v_client and lower(d.name) = lower(btrim(coalesce(e->>'dog_name',''))) limit 1)),
             'score', e->>'score')), '[]'::jsonb)
      into v_scores_j
      from jsonb_array_elements(coalesce(p_plan->'visit'->'dog_scores','[]')) e;
    select coalesce(array_agg((e->>'dog_id')::uuid), '{}') into v_new_dog_ids
      from jsonb_array_elements(v_scores_j) e
     where nullif(e->>'dog_id','') is not null
       and exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client);

    -- MERGE, not duplicate: the stop flow already created today's visit row
    -- (arrival stamps), so a Riker note about the same Eastern day fills in
    -- that row. Only a day with no visit at all gets a new one.
    select id into v_visit from public.visits
     where client_id = v_client
       and (visited_at at time zone 'America/New_York')::date
           = (v_visit_at at time zone 'America/New_York')::date
     order by (appointment_id is not null) desc, created_at desc
     limit 1;

    if v_visit is not null then
      update public.visits set
        service_type = coalesce(nullif(p_plan->'visit'->>'service_type',''), service_type),
        work_done = coalesce(nullif(p_plan->'visit'->>'work_done',''), work_done),
        visit_notes = case when nullif(btrim(coalesce(p_plan->'visit'->>'visit_notes','')),'') is not null
                           then coalesce(visit_notes || ' ; ', '') || btrim(p_plan->'visit'->>'visit_notes')
                           else visit_notes end,
        actual_minutes = coalesce(nullif(p_plan->'visit'->>'actual_minutes','')::int, actual_minutes),
        amount_collected_cents = coalesce(nullif(p_plan->'visit'->>'amount_cents','')::int, amount_collected_cents),
        payment_method = coalesce(nullif(p_plan->'visit'->>'payment_method',''), payment_method),
        dog_ids = case when array_length(v_new_dog_ids, 1) > 0
                       then (select coalesce(array_agg(distinct x), '{}')
                               from unnest(coalesce(dog_ids, '{}') || v_new_dog_ids) x)
                       else dog_ids end
       where id = v_visit;
      v_visit_merged := true;
    else
      insert into public.visits (
        client_id, subscriber_id, visited_at, service_type, dog_ids,
        work_done, visit_notes, actual_minutes, amount_collected_cents, payment_method, source, completed_by
      ) values (
        v_client, v_sub, v_visit_at,
        nullif(p_plan->'visit'->>'service_type',''),
        v_new_dog_ids,
        nullif(p_plan->'visit'->>'work_done',''),
        nullif(p_plan->'visit'->>'visit_notes',''),
        nullif(p_plan->'visit'->>'actual_minutes','')::int,
        nullif(p_plan->'visit'->>'amount_cents','')::int,
        nullif(p_plan->'visit'->>'payment_method',''),
        'riker', v_admin
      ) returning id into v_visit;
    end if;

    insert into public.visit_dog_ratings (visit_id, dog_id, score)
    select v_visit, (e->>'dog_id')::uuid, (e->>'score')::int
      from jsonb_array_elements(v_scores_j) e
     where nullif(e->>'dog_id','') is not null
       and nullif(e->>'score','') is not null and (e->>'score')::int between 1 and 5
       and exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client)
    on conflict (visit_id, dog_id) do update set score = excluded.score;
    get diagnostics v_scores = row_count;
  end if;

  if v_client is not null and nullif(btrim(coalesce(p_plan->>'client_note','')),'') is not null then
    update public.clients set note = coalesce(note || ' ; ', '') || btrim(p_plan->>'client_note'), updated_at = now()
     where id = v_client;
    v_note := true;
  end if;

  if v_client is not null then
    for r in select (e->>'dog_id')::uuid as dog_id, btrim(e->>'text') as text
               from jsonb_array_elements(coalesce(p_plan->'dog_notes','[]')) e
              where nullif(btrim(e->>'text'),'') is not null
    loop
      update public.dogs set notes = coalesce(notes || ' ; ', '') || r.text, updated_at = now()
       where id = r.dog_id and client_id = v_client;
      if found then v_dognotes := v_dognotes + 1; end if;
    end loop;

    for r in select (e->>'dog_id')::uuid as dog_id, e->>'status' as status, btrim(coalesce(e->>'note','')) as note
               from jsonb_array_elements(coalesce(p_plan->'dog_status','[]')) e
              where e->>'status' in ('regular','occasional','moved','former','deceased')
    loop
      update public.dogs
         set roster_status = r.status,
             notes = case when r.note <> '' then coalesce(notes || ' ; ', '') || r.note else notes end,
             updated_at = now()
       where id = r.dog_id and client_id = v_client;
      if found then v_status := v_status + 1; end if;
    end loop;

    v_np := p_plan->'notify_person';
    if jsonb_typeof(v_np) = 'object' then
      v_np_id := public.admin_upsert_notify_person(
        nullif(v_np->>'id','')::uuid,
        v_client,
        v_np->>'name',
        v_np->>'phone',
        v_np->>'email',
        v_np->>'relationship',
        coalesce(nullif(v_np->>'mode',''), 'in_addition'),
        nullif(v_np->>'until','')::date
      );
    end if;
  end if;

  if v_wisdom is not null then
    perform public.admin_capture_wisdom(v_wisdom,
      case when v_client is not null then 'client' else 'unsorted' end,
      v_client, 'riker');
    v_wisdom_saved := true;
  end if;

  if jsonb_typeof(v_rem) = 'object'
     and nullif(btrim(coalesce(v_rem->>'body','')),'') is not null
     and nullif(v_rem->>'due','') is not null then
    v_rem_id := public.admin_add_reminder(
      btrim(v_rem->>'body'), (v_rem->>'due')::date, v_client, 'riker');
  end if;

  return jsonb_build_object('visit_id', v_visit, 'scores_applied', v_scores,
                           'client_note_appended', v_note, 'dog_notes_appended', v_dognotes,
                           'dog_status_changes', v_status, 'notify_person_id', v_np_id,
                           'wisdom_saved', v_wisdom_saved, 'reminder_id', v_rem_id,
                           'dogs_added', v_added, 'dogs_updated', v_updated,
                           'client_updated', v_client_updated, 'visit_merged', v_visit_merged,
                           'visit_corrected', v_visit_corrected, 'visit_update_missed', v_vu_missed);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;

-- 3. The what-would-it-sell-for gauge.
create or replace function public.admin_business_value()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_ttm bigint; v_prev bigint; v_recurring bigint; v_expenses bigint;
  v_growth numeric; v_rs numeric; v_bump numeric;
  v_method text; v_low_mult numeric; v_high_mult numeric;
  v_base bigint;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select coalesce(sum(amount_collected_cents), 0) into v_ttm
    from public.visits where visited_at > now() - interval '365 days' and visited_at <= now();
  select coalesce(sum(amount_collected_cents), 0) into v_prev
    from public.visits where visited_at > now() - interval '730 days' and visited_at <= now() - interval '365 days';
  select coalesce(sum(v.amount_collected_cents), 0) into v_recurring
    from public.visits v join public.clients c on c.id = v.client_id
   where v.visited_at > now() - interval '365 days' and v.visited_at <= now()
     and c.cadence_days is not null;
  select coalesce(sum(amount_cents), 0) into v_expenses
    from public.expenses where is_business and txn_date > current_date - 365;

  v_growth := case when v_prev > 0 then (v_ttm - v_prev)::numeric / v_prev else null end;
  v_rs := case when v_ttm > 0 then least(1, v_recurring::numeric / v_ttm) else 0 end;
  v_bump := case when coalesce(v_growth, 0) >= 0.10 then 0.05
                 when coalesce(v_growth, 0) <= -0.10 then -0.05 else 0 end;

  if v_expenses >= v_ttm * 0.05 then
    -- Real cost data: SDE (revenue minus business costs, the solo-operator
    -- earnings) times the standard owner-operated service multiple.
    v_method := 'sde';
    v_base := v_ttm - v_expenses;
    v_low_mult := 2.0 + 0.5 * v_rs + v_bump * 2;
    v_high_mult := 2.8 + 0.7 * v_rs + v_bump * 2;
  else
    -- Thin cost data: annual-revenue multiple, the honest fallback yardstick
    -- for a route business, adjusted by the quality we actually measure.
    v_method := 'revenue';
    v_base := v_ttm;
    v_low_mult := 0.50 + 0.20 * v_rs + v_bump;
    v_high_mult := 0.85 + 0.25 * v_rs + v_bump;
  end if;

  return jsonb_build_object(
    'value_low_cents', round(v_base * v_low_mult),
    'value_high_cents', round(v_base * v_high_mult),
    'method', v_method,
    'base_cents', v_base,
    'low_multiple', round(v_low_mult, 2),
    'high_multiple', round(v_high_mult, 2),
    'ttm_revenue_cents', v_ttm,
    'prev_ttm_revenue_cents', v_prev,
    'growth_pct', case when v_growth is null then null else round(v_growth * 100, 1) end,
    'recurring_share_pct', round(v_rs * 100),
    'expenses_ttm_cents', v_expenses);
end;
$$;
revoke all on function public.admin_business_value() from public, anon;
grant execute on function public.admin_business_value() to authenticated, service_role;
