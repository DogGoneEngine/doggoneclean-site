-- 0239_sync_appointments_dog_count_from_roster.sql
--
-- Root-cause fix for the legacy appointment dog-count bug. The Google Calendar
-- import (_sync_appointments) inserted each appointment with
-- coalesce(event.dog_count, 1). The calendar never carries a dog count, so every
-- synced legacy appointment defaulted to one dog, which is why multi-dog
-- households (Lisa Irwin, Cynthia Tieche, Tonya Hunt) showed one. The existing
-- appointments were corrected directly; this fixes the source so newly synced
-- appointments are right.
--
-- Fallback rule (appointment_counts_regular_dogs): when the calendar event has no
-- dog count, use the client's REGULAR roster dogs (dogs.roster_status='regular'),
-- not 1, and stamp those dog ids. Deceased/former/moved/occasional are excluded.
-- An explicit dog count on the event still wins. The update branch preserves an
-- already-set dog_count (so manual corrections are never clobbered) and only
-- backfills dog_ids when missing.

CREATE OR REPLACE FUNCTION public._sync_appointments(p_events jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare e record; v_name text; v_tentative boolean; v_status text;
        v_client uuid; v_sub uuid; v_appt uuid; v_starts timestamptz; v_ends timestamptz;
        v_ins int:=0; v_upd int:=0; v_adopt int:=0; v_skip int:=0; v_unmatched jsonb:='[]'::jsonb;
        v_regn int; v_regids uuid[];
begin
  for e in select * from jsonb_to_recordset(p_events) as x(
      external_id text, starts timestamptz, ends timestamptz, client_name text, client_email text,
      dog_count int, service_type text, amount_cents int, notes text, tentative boolean)
  loop
    v_tentative := coalesce(e.tentative, false) or right(btrim(e.client_name), 1) = '?';
    v_status := case when v_tentative then 'tentative' else 'confirmed' end;
    v_name := lower(btrim(rtrim(btrim(e.client_name), '? ')));
    select c.id into v_client from public.clients c
     where not c.exclude_from_everything and (
        lower(btrim(c.name)) = v_name
        or exists (select 1 from public.client_aliases a where a.client_id=c.id and lower(btrim(a.alias))=v_name)
        or (nullif(btrim(e.client_email),'') is not null and lower(c.email)=lower(btrim(e.client_email)))
     )
     order by (lower(btrim(c.name))=v_name) desc
     limit 1;
    if v_client is null then v_unmatched := v_unmatched || to_jsonb(e.client_name); continue; end if;

    -- regular roster fallback: the calendar never sends a dog count, so use the
    -- client's regular dogs instead of defaulting to one (appointment_counts_regular_dogs)
    select count(*)::int, array_remove(array_agg(d.id order by d.name), null)
      into v_regn, v_regids
      from public.dogs d
     where d.client_id = v_client and coalesce(d.roster_status, 'regular') = 'regular';

    select id into v_sub from public.bath_subscribers where client_id=v_client limit 1;
    if v_sub is null then insert into public.bath_subscribers (client_id) values (v_client) returning id into v_sub; end if;
    select id into v_appt from public.bath_appointments where external_id = e.external_id;

    if v_appt is null then
      v_starts := e.starts; v_ends := coalesce(e.ends, e.starts + interval '60 minutes');
      select id into v_appt from public.bath_appointments a
       where a.subscriber_id = v_sub and a.external_id is null
         and a.status not in ('cancelled', 'no_show', 'skipped')
         and a.scheduled_start < v_ends and coalesce(a.scheduled_end, a.scheduled_start) > v_starts
       order by a.scheduled_start limit 1;
      if v_appt is not null then
        update public.bath_appointments set external_id = e.external_id, updated_at = now()
         where id = v_appt;
        v_adopt := v_adopt + 1;
        continue;
      end if;
      begin
        insert into public.bath_appointments (subscriber_id, scheduled_start, scheduled_end, status, service_type, amount_cents, dog_count, dog_ids, source, external_id, notes)
        values (v_sub, e.starts, e.ends, v_status, coalesce(e.service_type,'full_groom'), coalesce(e.amount_cents,0),
                coalesce(e.dog_count, nullif(v_regn, 0), 1),
                case when e.dog_count is null then v_regids else null end,
                'gcal_sync', e.external_id, e.notes);
        v_ins := v_ins + 1;
      exception when exclusion_violation then
        v_skip := v_skip + 1;
        v_unmatched := v_unmatched || to_jsonb('overlap skipped: ' || e.client_name);
      end;
    else
      begin
        update public.bath_appointments set subscriber_id=v_sub, scheduled_start=e.starts, scheduled_end=e.ends,
          status = case when status in ('requested','confirmed','tentative') then v_status else status end,
          service_type=coalesce(e.service_type,service_type), amount_cents=coalesce(e.amount_cents,amount_cents),
          dog_count=coalesce(e.dog_count, dog_count, nullif(v_regn, 0), 1),
          dog_ids=coalesce(dog_ids, case when e.dog_count is null then v_regids else null end),
          notes=coalesce(e.notes,notes), updated_at=now()
         where id=v_appt;
        v_upd := v_upd + 1;
      exception when exclusion_violation then
        v_skip := v_skip + 1;
        v_unmatched := v_unmatched || to_jsonb('move skipped (overlap): ' || e.client_name);
      end;
    end if;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'updated', v_upd, 'adopted', v_adopt,
                            'skipped', v_skip, 'unmatched', v_unmatched);
end;
$function$;
