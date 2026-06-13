-- 0170_access_probe.sql
-- The masking half of the access map, read from the truth (access_map_reads_the_truth).
-- admin_access_probe is owner-only. It calls the real masking-aware RPCs
-- (admin_get_client, admin_today_appointments) once as the owner and once as a
-- representative member of each other role, then reports the FIELDS that
-- disappear for that role. It returns field names only, never any client data,
-- so it leaks nothing. Because it diffs the live functions instead of describing
-- them, the access map cannot drift from what the server actually enforces, and
-- no security code had to be rewritten to make it accurate.
create or replace function public.admin_access_probe()
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare
  v_claims text;
  v_sample uuid;
  v_full_client jsonb; v_full_today jsonb;
  v_mc jsonb; v_mt jsonb;
  r record; v_uid text; v_out jsonb := '{}'::jsonb;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  v_claims := current_setting('request.jwt.claims', true);

  -- a real client with visit history, so the money and contact diffs are visible
  select c.id into v_sample
    from public.clients c
   where coalesce(c.exclude_from_everything, false) = false
     and exists (select 1 from public.visits v where v.client_id = c.id)
   order by c.created_at limit 1;

  v_full_client := case when v_sample is not null then public.admin_get_client(v_sample) else '{}'::jsonb end;
  v_full_today := public.admin_today_appointments();

  for r in select distinct role from public.admins where is_active and role <> 'owner' loop
    select auth_user_id::text into v_uid
      from public.admins where is_active and role = r.role and auth_user_id is not null limit 1;
    if v_uid is null then
      v_out := v_out || jsonb_build_object(r.role, jsonb_build_object('probed', false));
      continue;
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    v_mc := case when v_sample is not null then public.admin_get_client(v_sample) else '{}'::jsonb end;
    v_mt := public.admin_today_appointments();
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);

    v_out := v_out || jsonb_build_object(r.role, jsonb_build_object(
      'probed', true,
      'client',   to_jsonb(array(select jsonb_object_keys(coalesce(v_full_client->'client', '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mc->'client', '{}'::jsonb)))),
      'visit',    to_jsonb(array(select jsonb_object_keys(coalesce(v_full_client->'visits'->0, '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mc->'visits'->0, '{}'::jsonb)))),
      'upcoming', to_jsonb(array(select jsonb_object_keys(coalesce(v_full_client->'upcoming'->0, '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mc->'upcoming'->0, '{}'::jsonb)))),
      'today',    to_jsonb(array(select jsonb_object_keys(coalesce(v_full_today->0, '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mt->0, '{}'::jsonb))))
    ));
  end loop;

  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  return jsonb_build_object(
    'sample_used', v_sample is not null,
    'today_sampled', jsonb_array_length(coalesce(v_full_today, '[]'::jsonb)) > 0,
    'roles', v_out);
end;
$$;
revoke all on function public.admin_access_probe() from public, anon;
grant execute on function public.admin_access_probe() to authenticated, service_role;
