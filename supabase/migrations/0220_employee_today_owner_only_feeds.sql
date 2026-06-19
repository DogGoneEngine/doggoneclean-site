-- 0220_employee_today_owner_only_feeds.sql
--
-- Employee-mode visibility fix. The Today floor is shared with the operator
-- (Employee) role on purpose: an operator drives the route from it. But three
-- feeds on Today were gated only by _is_admin() (true for ANY active admin),
-- so the operator saw the owner's full Emperor view:
--   1. the AI department-head briefing feed (win-back targets, below-rate
--      pricing clients with their per-hour revenue, churn/retention lists, the
--      CFO money counsel, capacity, reorder) -- admin_list_briefings;
--   2. the owner's "On your plate" reminders -- admin_list_reminders.
-- admin_today_appointments already masks money for the operator role with
-- _admin_role() = 'operator'; these two feeds simply never got the gate.
--
-- The briefing feed is the Emperor's crystal ball (Today's own copy calls it
-- "the briefing feed from your AI department heads"), and the reminders are
-- Paul's own commitments. Both are owner-only. Per-person work reaches an
-- operator through the Tasks panel (already owner-assigns / assignee-completes),
-- not through these feeds.
--
-- Teeth live here, server-side, so the boundary survives any redesign of the
-- Today screen. The client also hides the sections, but that is cosmetic; this
-- RPC gate is the security boundary.
--
-- admin_access_probe is also extended to report these owner-only feeds per
-- role, so the Access floor (access_map_reads_the_truth) shows the masking
-- empirically instead of staying blind to it -- the exact gap that let this
-- leak ship.

-- 1. Briefings: owner-only. Non-owner admins get an empty feed (not an error,
--    so an operator's Today renders cleanly with no feed rather than throwing).
create or replace function public.admin_list_briefings(p_department text default null, p_status text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if public._admin_role() <> 'owner' then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'agent_key', b.agent_key, 'department', b.department,
      'severity', b.severity, 'title', b.title, 'body', b.body,
      'evidence', b.evidence, 'recommended_action', b.recommended_action,
      'status', b.status, 'disposition', b.disposition, 'created_at', b.created_at,
      'notes', (select coalesce(jsonb_agg(jsonb_build_object('author',n.author,'body',n.body,'created_at',n.created_at) order by n.created_at),'[]'::jsonb)
                 from public.briefing_notes n where n.briefing_id=b.id)
    ) order by b.created_at desc)
    from public.briefings b
    where (p_department is null or b.department = p_department)
      and (p_status is null or b.status = p_status)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_briefings(text, text) from public;
grant execute on function public.admin_list_briefings(text, text) to authenticated;

-- 2. Reminders: owner-only. Non-owner admins get the empty shape so the client
--    panel hides itself with no error.
create or replace function public.admin_list_reminders()
returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if public._admin_role() <> 'owner' then
    return jsonb_build_object('open', '[]'::jsonb, 'upcoming', '[]'::jsonb, 'recently_done', '[]'::jsonb);
  end if;
  return jsonb_build_object(
    'open', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_id', r.client_id, 'client_name', c.name,
          'overdue', r.due_date < current_date,
          'due', r.due_date <= current_date)
        order by r.due_date, r.created_at)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'open' and r.due_date <= current_date), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_id', r.client_id, 'client_name', c.name)
        order by r.due_date, r.created_at)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'open' and r.due_date > current_date), '[]'::jsonb),
    'recently_done', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_name', c.name, 'done_at', r.done_at)
        order by r.done_at desc)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'done' and r.done_at > now() - interval '7 days'), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_list_reminders() from public, anon;
grant execute on function public.admin_list_reminders() to authenticated, service_role;

-- 3. Access probe: also report the owner-only feeds per role, empirically, by
--    calling the feeds under each impersonated role and comparing to the owner
--    baseline. A feed the owner has but the role gets empty is reported hidden,
--    in a new `feeds` array the Access floor renders alongside the field masks.
create or replace function public.admin_access_probe()
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare
  v_claims text;
  v_sample uuid;
  v_full_client jsonb; v_full_today jsonb;
  v_full_briefings jsonb; v_full_reminders jsonb;
  v_mc jsonb; v_mt jsonb; v_mb jsonb; v_mr jsonb; v_feeds jsonb;
  r record; v_uid text; v_out jsonb := '{}'::jsonb;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  v_claims := current_setting('request.jwt.claims', true);

  select c.id into v_sample
    from public.clients c
   where coalesce(c.exclude_from_everything, false) = false
     and exists (select 1 from public.visits v where v.client_id = c.id)
   order by c.created_at limit 1;

  v_full_client := case when v_sample is not null then public.admin_get_client(v_sample) else '{}'::jsonb end;
  v_full_today := public.admin_today_appointments();
  -- Owner baseline for the owner-only feeds (this function is owner-gated above).
  v_full_briefings := public.admin_list_briefings();
  v_full_reminders := public.admin_list_reminders();

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
    v_mb := public.admin_list_briefings();
    v_mr := public.admin_list_reminders();
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);

    v_feeds := '[]'::jsonb;
    if jsonb_array_length(coalesce(v_full_briefings, '[]'::jsonb)) > 0
       and jsonb_array_length(coalesce(v_mb, '[]'::jsonb)) = 0 then
      v_feeds := v_feeds || '["briefing_feed"]'::jsonb;
    end if;
    if (jsonb_array_length(coalesce(v_full_reminders->'open', '[]'::jsonb))
        + jsonb_array_length(coalesce(v_full_reminders->'upcoming', '[]'::jsonb))) > 0
       and (jsonb_array_length(coalesce(v_mr->'open', '[]'::jsonb))
        + jsonb_array_length(coalesce(v_mr->'upcoming', '[]'::jsonb))) = 0 then
      v_feeds := v_feeds || '["reminders_feed"]'::jsonb;
    end if;

    v_out := v_out || jsonb_build_object(r.role, jsonb_build_object(
      'probed', true,
      'client',   to_jsonb(array(select jsonb_object_keys(coalesce(v_full_client->'client', '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mc->'client', '{}'::jsonb)))),
      'visit',    to_jsonb(array(select jsonb_object_keys(coalesce(v_full_client->'visits'->0, '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mc->'visits'->0, '{}'::jsonb)))),
      'upcoming', to_jsonb(array(select jsonb_object_keys(coalesce(v_full_client->'upcoming'->0, '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mc->'upcoming'->0, '{}'::jsonb)))),
      'today',    to_jsonb(array(select jsonb_object_keys(coalesce(v_full_today->0, '{}'::jsonb))
                                  except select jsonb_object_keys(coalesce(v_mt->0, '{}'::jsonb)))),
      'feeds',    v_feeds
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
