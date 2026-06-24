-- The operator's tracker-share text is now personalized with the dog's name(s).
-- admin_appointment_meta already feeds the stop card the tracker token and the
-- assigned operator; add the appointment's dog names so the copy can read
-- "on the way to Cooper" / "follow Cooper's bath" without a second round trip.
-- Dog selection mirrors admin_now_card exactly: the appointment's explicit
-- dog_ids when set, otherwise the household's regular/occasional roster.

CREATE OR REPLACE FUNCTION public.admin_appointment_meta(p_appointment uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  a record;
  v_client uuid;
  v_dogs text[];
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select ap.tracker_token, ap.operator_admin_id, ap.subscriber_id, ap.dog_ids,
         ad.first_name, ad.last_name
    into a
    from public.bath_appointments ap
    left join public.admins ad on ad.id = ap.operator_admin_id
   where ap.id = p_appointment;
  if not found then raise exception 'appointment not found'; end if;

  select s.client_id into v_client
    from public.bath_subscribers s where s.id = a.subscriber_id;

  select coalesce(array_agg(dg.name order by dg.name), '{}')
    into v_dogs
    from public.dogs dg
   where (a.dog_ids is not null and array_length(a.dog_ids, 1) > 0 and dg.id = any(a.dog_ids))
      or ((a.dog_ids is null or array_length(a.dog_ids, 1) = 0)
          and dg.client_id = v_client
          and coalesce(dg.roster_status, 'regular') in ('regular', 'occasional'));

  return jsonb_build_object(
    'tracker_token', a.tracker_token,
    'operator_admin_id', a.operator_admin_id,
    'operator_name', nullif(btrim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')), ''),
    'dog_names', to_jsonb(v_dogs));
end;
$function$;
