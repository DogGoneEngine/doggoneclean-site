-- 0074_sync_fixes.sql
-- Two fixes found while wiring up the live Google Calendar sync (via the Apps
-- Script -> calendar-ingest path):
--   1. dog_count is NOT NULL on bath_appointments, so default a missing count to
--      1 (appointments without "N Dogs" in the title still sync).
--   2. Paul marks tentative appointments with a trailing "?" in the calendar
--      title; strip it when matching so "Mary Beth Anderson?" still matches.
create or replace function public._sync_appointments(p_events jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare e record; v_name text; v_client uuid; v_sub uuid; v_appt uuid; v_ins int:=0; v_upd int:=0; v_unmatched jsonb:='[]'::jsonb;
begin
  for e in select * from jsonb_to_recordset(p_events) as x(
      external_id text, starts timestamptz, ends timestamptz, client_name text, client_email text,
      dog_count int, service_type text, amount_cents int, notes text)
  loop
    v_name := lower(btrim(rtrim(btrim(e.client_name), '? ')));  -- drop trailing tentative "?"
    select c.id into v_client from public.clients c
     where not c.exclude_from_everything and (
        lower(btrim(c.name)) = v_name
        or exists (select 1 from public.client_aliases a where a.client_id=c.id and lower(btrim(a.alias))=v_name)
        or (nullif(btrim(e.client_email),'') is not null and lower(c.email)=lower(btrim(e.client_email)))
     )
     order by (lower(btrim(c.name))=v_name) desc
     limit 1;
    if v_client is null then v_unmatched := v_unmatched || to_jsonb(e.client_name); continue; end if;
    select id into v_sub from public.bath_subscribers where client_id=v_client limit 1;
    if v_sub is null then insert into public.bath_subscribers (client_id) values (v_client) returning id into v_sub; end if;
    select id into v_appt from public.bath_appointments where external_id = e.external_id;
    if v_appt is null then
      insert into public.bath_appointments (subscriber_id, scheduled_start, scheduled_end, status, service_type, amount_cents, dog_count, source, external_id, notes)
      values (v_sub, e.starts, e.ends, 'confirmed', coalesce(e.service_type,'full_groom'), coalesce(e.amount_cents,0), coalesce(e.dog_count,1), 'gcal_sync', e.external_id, e.notes);
      v_ins := v_ins + 1;
    else
      update public.bath_appointments set subscriber_id=v_sub, scheduled_start=e.starts, scheduled_end=e.ends,
        status='confirmed', service_type=coalesce(e.service_type,service_type), amount_cents=coalesce(e.amount_cents,amount_cents),
        dog_count=coalesce(e.dog_count,dog_count,1), source='gcal_sync', notes=coalesce(e.notes,notes), updated_at=now()
       where id=v_appt;
      v_upd := v_upd + 1;
    end if;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'updated', v_upd, 'unmatched', v_unmatched);
end;
$$;
revoke all on function public._sync_appointments(jsonb) from public, anon, authenticated;
grant execute on function public._sync_appointments(jsonb) to service_role;
