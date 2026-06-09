-- 0080_visit_photos.sql
-- Photos on a visit. Paul takes three per appointment on his phone (before,
-- after, and one of him with the dog) plus any extras, and they live in his
-- Google Photos. Intake is the simplest path that works on his Pixel: a direct
-- multi-select upload from the phone in the visit history (the Android picker
-- reaches Google Photos), into a PRIVATE Supabase Storage bucket, viewed through
-- short-lived signed URLs. Private because these are client property and Clean
-- must stay sellable: Clean's data, Clean's project, never entangled. The bucket
-- and table are admin-only via storage RLS + _is_admin. See visit_photos_capture.

insert into storage.buckets (id, name, public) values ('visit-photos', 'visit-photos', false)
  on conflict (id) do nothing;

-- Only an admin (Paul) may read or write the bucket.
drop policy if exists "visit_photos_select" on storage.objects;
create policy "visit_photos_select" on storage.objects for select to authenticated
  using (bucket_id = 'visit-photos' and public._is_admin());
drop policy if exists "visit_photos_insert" on storage.objects;
create policy "visit_photos_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'visit-photos' and public._is_admin());
drop policy if exists "visit_photos_update" on storage.objects;
create policy "visit_photos_update" on storage.objects for update to authenticated
  using (bucket_id = 'visit-photos' and public._is_admin());
drop policy if exists "visit_photos_delete" on storage.objects;
create policy "visit_photos_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'visit-photos' and public._is_admin());

create table if not exists public.visit_photos (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  kind text not null check (kind in ('before','after','with_dog','extra')),
  storage_path text not null,
  created_at timestamptz not null default now()
);
create index if not exists visit_photos_visit_idx on public.visit_photos (visit_id, created_at);
alter table public.visit_photos enable row level security;

create or replace function public.admin_add_visit_photo(p_visit_id uuid, p_kind text, p_path text)
returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_kind not in ('before','after','with_dog','extra') then raise exception 'bad photo kind'; end if;
  if not exists (select 1 from public.visits where id = p_visit_id) then raise exception 'visit not found'; end if;
  insert into public.visit_photos (visit_id, kind, storage_path) values (p_visit_id, p_kind, p_path) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_visit_photo(uuid, text, text) from public;
grant execute on function public.admin_add_visit_photo(uuid, text, text) to authenticated;

create or replace function public.admin_delete_visit_photo(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_path text;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.visit_photos where id = p_id returning storage_path into v_path;
  return jsonb_build_object('deleted', v_path is not null, 'path', v_path);
end;
$$;
revoke all on function public.admin_delete_visit_photo(uuid) from public;
grant execute on function public.admin_delete_visit_photo(uuid) to authenticated;

-- admin_get_client: include each visit's photos (id, kind, path; the UI signs them).
create or replace function public.admin_get_client(p_client_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
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
          select jsonb_agg(jsonb_build_object('dog_id', r.dog_id, 'name', d2.name, 'score', r.score) order by d2.name)
            from public.visit_dog_ratings r left join public.dogs d2 on d2.id = r.dog_id
           where r.visit_id = v.id), '[]'::jsonb),
        'photos', coalesce((
          select jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'path', p.storage_path) order by p.created_at)
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
$$;
revoke all on function public.admin_get_client(uuid) from public;
grant execute on function public.admin_get_client(uuid) to authenticated;
