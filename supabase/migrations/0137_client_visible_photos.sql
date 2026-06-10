-- 0137: client-visible visit photos (pizza_tracker_client_loop slice 4).
-- Sharing a photo with the client is a deliberate per-photo choice: Paul
-- flips a toggle on the Orbit visit photo (admin_set_photo_visibility), and
-- only then can the client see it. Two client surfaces read the flag: the
-- portal (this migration: bath_my_visit_photos + a storage policy so the
-- signed-in client can sign URLs for exactly their own shared photos) and
-- the Dog Gone Tracker page (next slice, needs an edge function because a
-- token-only visitor has no auth to satisfy storage RLS).
-- Grants explicit per rpc_grants_explicit.

-- The client may read exactly their own shared photos; everything else in
-- the bucket stays admin-only (the 0080 policies remain for Paul).
drop policy if exists "visit_photos_client_select" on storage.objects;
create policy "visit_photos_client_select" on storage.objects for select to authenticated
  using (
    bucket_id = 'visit-photos'
    and exists (
      select 1
        from public.visit_photos vp
        join public.visits v on v.id = vp.visit_id
        join public.bath_subscribers s on s.auth_user_id = auth.uid()
       where vp.storage_path = storage.objects.name
         and vp.client_visible
         and (v.subscriber_id = s.id
              or (v.client_id is not null and v.client_id = s.client_id))
    )
  );

create or replace function public.admin_set_photo_visibility(p_id uuid, p_visible boolean)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.visit_photos set client_visible = coalesce(p_visible, false) where id = p_id;
  if not found then raise exception 'photo not found'; end if;
end;
$$;
revoke all on function public.admin_set_photo_visibility(uuid, boolean) from public;
grant execute on function public.admin_set_photo_visibility(uuid, boolean) to authenticated, service_role;

-- The signed-in client's shared photos, grouped by the portal client-side.
-- Covers both write paths: visits keyed to the bath subscriber directly and
-- legacy visits keyed to the linked clients record.
create or replace function public.bath_my_visit_photos()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  s public.bath_subscribers%rowtype;
begin
  select * into s from public.bath_subscribers where auth_user_id = auth.uid() limit 1;
  if not found then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', vp.id,
      'kind', vp.kind,
      'path', vp.storage_path,
      'visited_at', v.visited_at
    ) order by v.visited_at desc, vp.created_at)
      from public.visit_photos vp
      join public.visits v on v.id = vp.visit_id
     where vp.client_visible
       and (v.subscriber_id = s.id
            or (v.client_id is not null and v.client_id = s.client_id))
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.bath_my_visit_photos() from public;
grant execute on function public.bath_my_visit_photos() to authenticated, service_role;

-- admin_get_client: photos now carry client_visible so the Orbit toggle
-- renders its current state.
CREATE OR REPLACE FUNCTION public.admin_get_client(p_client_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'client', to_jsonb(c.*),
    'dogs', coalesce((select jsonb_agg(to_jsonb(d.*) order by d.name) from public.dogs d where d.client_id = c.id), '[]'::jsonb),
    'subscriber', (select to_jsonb(s.*) from public.bath_subscribers s where s.client_id = c.id limit 1),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'visited_at', v.visited_at, 'service_type', v.service_type,
        'work_done', v.work_done, 'visit_notes', v.visit_notes,
        'actual_minutes', v.actual_minutes,
        'amount_collected_cents', v.amount_collected_cents, 'tip_cents', v.tip_cents,
        'payment_method', v.payment_method, 'condition_flags', v.condition_flags, 'source', v.source,
        'dog_ratings', coalesce((
          select jsonb_agg(jsonb_build_object('dog_id', r.dog_id, 'name', d2.name, 'score', r.score, 'note', r.note) order by d2.name)
            from public.visit_dog_ratings r left join public.dogs d2 on d2.id = r.dog_id
           where r.visit_id = v.id), '[]'::jsonb),
        'photos', coalesce((
          select jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'path', p.storage_path, 'client_visible', p.client_visible) order by p.created_at)
            from public.visit_photos p where p.visit_id = v.id), '[]'::jsonb)
      ) order by v.visited_at desc)
        from public.visits v where v.client_id = c.id), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'scheduled_start', a.scheduled_start, 'status', a.status,
        'service_type', a.service_type, 'amount_cents', a.amount_cents
      ) order by a.scheduled_start)
        from public.bath_appointments a
        join public.bath_subscribers s2 on s2.id = a.subscriber_id
       where s2.client_id = c.id and a.status in ('requested','confirmed','tentative')), '[]'::jsonb)
  ) into result
  from public.clients c where c.id = p_client_id;
  if result is null then raise exception 'client not found'; end if;
  return result;
end;
$function$;
