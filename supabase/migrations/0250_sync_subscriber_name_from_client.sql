-- 0250_sync_subscriber_name_from_client.sql
--
-- Root-cause fix for the "Hi there" greeting on legacy notifications. The Google
-- Calendar sync (_sync_appointments) gets-or-makes a bath_subscribers row for the
-- matched client, but when it CREATES that row it only set client_id, leaving
-- first_name NULL. The standing book (0030) populated first_name/last_name via
-- split_part, but one_off / at_will clients were never in that seed, so their
-- subscriber row is created bare by the sync. send-notification then renders
-- `first_name || 'there'`, so every email to those clients opened "Hi there,".
-- Sally O'Laughlin (one_off) is exactly this case.
--
-- Fix, in the durable layer:
--   1. When _sync_appointments creates a subscriber, carry the client's name
--      (and email / phone), split the same way 0030 does.
--   2. If a subscriber row already exists but is missing a first_name, backfill
--      it from the client on the spot.
--   3. One-time backfill of every existing bare subscriber row from public.clients
--      so already-created rows (Sally and the rest of the synced one-offs) greet
--      by name on the next send, with no per-row hand edit.
-- Everything else in the function is preserved verbatim from 0239.

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
    if v_sub is null then
      -- Carry the client's name onto the new subscriber row (split the same way
      -- 0030 splits the standing book) so notifications greet by name, not "there".
      insert into public.bath_subscribers (client_id, first_name, last_name, email, phone_e164)
      select v_client,
             split_part(c.name, ' ', 1),
             nullif(btrim(substr(c.name, length(split_part(c.name, ' ', 1)) + 1)), ''),
             c.email, c.phone_e164
        from public.clients c where c.id = v_client
      returning id into v_sub;
    else
      -- An existing row created before this fix may be missing its name; backfill it.
      update public.bath_subscribers bs
         set first_name = split_part(c.name, ' ', 1),
             last_name  = coalesce(nullif(btrim(bs.last_name), ''),
                                   nullif(btrim(substr(c.name, length(split_part(c.name, ' ', 1)) + 1)), ''))
        from public.clients c
       where bs.id = v_sub and c.id = v_client
         and (bs.first_name is null or btrim(bs.first_name) = '');
    end if;
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

-- One-time backfill: every subscriber row that is linked to a client but is
-- missing its name gets it now, so existing synced one-offs (Sally O'Laughlin and
-- the rest) stop greeting "Hi there" on their next reminder.
update public.bath_subscribers bs
   set first_name = split_part(c.name, ' ', 1),
       last_name  = coalesce(nullif(btrim(bs.last_name), ''),
                             nullif(btrim(substr(c.name, length(split_part(c.name, ' ', 1)) + 1)), ''))
  from public.clients c
 where bs.client_id = c.id
   and (bs.first_name is null or btrim(bs.first_name) = '');
