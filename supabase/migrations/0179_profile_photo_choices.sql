-- 0179_profile_photo_choices.sql
--
-- "Choose from the Library" for an operator's profile photo (Paul, 2026-06-13):
-- the HR photo picker can pick an existing shared photo as the tracker face,
-- not just a fresh phone upload. The Team gallery (admin_team_gallery) is the
-- obvious source but is empty today, while there are dozens of client-shared
-- photos, so the picker draws from everything already shared to someone
-- (client_visible or team_visible). A profile photo becomes the public tracker
-- face, so only already-shared photos are offered; a private/internal photo is
-- never silently promoted to everyone's tracker. Same row shape as
-- admin_team_gallery so the picker UI is unchanged. See who_is_coming_is_pilot.

create or replace function public.admin_profile_photo_choices()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'path', p.storage_path, 'kind', p.kind,
      'dog_name', d.name, 'client', c.name, 'visited_at', v.visited_at
    ) order by p.created_at desc)
    from public.visit_photos p
    left join public.dogs d on d.id = p.dog_id
    left join public.visits v on v.id = p.visit_id
    left join public.clients c on c.id = v.client_id
   where (p.client_visible or p.team_visible)
     and p.kind in ('with_dog', 'after', 'extra')), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_profile_photo_choices() from public, anon;
grant execute on function public.admin_profile_photo_choices() to authenticated, service_role;
