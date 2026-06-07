-- 0011_portal_subscription_actions.sql
--
-- Client self-service for the subscription lifecycle: pause, cancel, and
-- restart. bath_subscriptions exposes only a self_read RLS policy (no
-- direct UPDATE), so these state changes have to live in SECURITY DEFINER
-- functions where the rule is enforced once, server-side, and survives any
-- redesign of the portal UI.
--
-- Every function resolves the caller's own subscriber through auth.uid(),
-- so a signed-in client can only ever move their own plan. An anonymous
-- caller (auth.uid() IS NULL) matches no subscriber and gets a clean
-- "no_active_subscription" result.
--
-- Pausing or cancelling also takes any still-scheduled future visit off the
-- calendar, so a stopped plan never leaves a live appointment behind.

-- ── Pause ──────────────────────────────────────────────────────────────
create or replace function public.bath_pause_subscription()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub_id  uuid;
  v_subr_id uuid;
begin
  select s.id, s.subscriber_id
    into v_sub_id, v_subr_id
  from public.bath_subscriptions s
  join public.bath_subscribers b on b.id = s.subscriber_id
  where b.auth_user_id = auth.uid()
    and s.status = 'active'
  order by s.started_at desc
  limit 1;

  if v_sub_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_active_subscription');
  end if;

  update public.bath_subscriptions
     set status = 'paused',
         paused_at = now(),
         paused_reason = 'self',
         updated_at = now()
   where id = v_sub_id;

  update public.bath_appointments
     set status = 'cancelled',
         updated_at = now()
   where subscriber_id = v_subr_id
     and scheduled_start > now()
     and status in ('requested', 'confirmed', 'on_the_way', 'on_site', 'in_service');

  return jsonb_build_object('ok', true, 'status', 'paused');
end;
$$;

-- ── Restart (paused -> active) ─────────────────────────────────────────
create or replace function public.bath_resume_subscription()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub_id uuid;
begin
  select s.id
    into v_sub_id
  from public.bath_subscriptions s
  join public.bath_subscribers b on b.id = s.subscriber_id
  where b.auth_user_id = auth.uid()
    and s.status = 'paused'
  order by s.started_at desc
  limit 1;

  if v_sub_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_paused_subscription');
  end if;

  update public.bath_subscriptions
     set status = 'active',
         paused_at = null,
         paused_reason = null,
         updated_at = now()
   where id = v_sub_id;

  return jsonb_build_object('ok', true, 'status', 'active');
end;
$$;

-- ── Cancel ─────────────────────────────────────────────────────────────
create or replace function public.bath_cancel_subscription()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub_id  uuid;
  v_subr_id uuid;
begin
  select s.id, s.subscriber_id
    into v_sub_id, v_subr_id
  from public.bath_subscriptions s
  join public.bath_subscribers b on b.id = s.subscriber_id
  where b.auth_user_id = auth.uid()
    and s.status in ('active', 'paused')
  order by s.started_at desc
  limit 1;

  if v_sub_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_active_subscription');
  end if;

  update public.bath_subscriptions
     set status = 'cancelled',
         cancelled_at = now(),
         updated_at = now()
   where id = v_sub_id;

  update public.bath_appointments
     set status = 'cancelled',
         updated_at = now()
   where subscriber_id = v_subr_id
     and scheduled_start > now()
     and status in ('requested', 'confirmed', 'on_the_way', 'on_site', 'in_service');

  return jsonb_build_object('ok', true, 'status', 'cancelled');
end;
$$;

-- These are client-invoked: only signed-in users, never the anon role.
revoke all on function public.bath_pause_subscription()  from public, anon;
revoke all on function public.bath_resume_subscription() from public, anon;
revoke all on function public.bath_cancel_subscription() from public, anon;
grant execute on function public.bath_pause_subscription()  to authenticated;
grant execute on function public.bath_resume_subscription() to authenticated;
grant execute on function public.bath_cancel_subscription() to authenticated;
