-- 0223_field_flags_clear_on_seen.sql
-- "Got it" on a From-the-field note should mean done with it, gone from Today now.
-- The feed (admin_field_flags) previously kept a seen note around, greyed out, for
-- 7 days before it aged off (0176). Paul 2026-06-19: that lingering week is itself
-- the noise, and the card's own help promises "it moves out of the way," so a seen
-- note must leave the daily feed immediately. Nothing is deleted: field_seen_at and
-- the photo + private note stay on the visit_photos row and on the dog's record, so
-- the finding is still findable; it just stops riding along in Today once seen.
--
-- Only change: drop the "or field_seen_at > now() - 7 days" arm so the feed returns
-- unseen flags only. With only unseen rows returned, 'seen' is always false. Live
-- definition dumped before editing (per never-rebuild-from-old-migration); this is
-- that definition with the one filter arm removed.

create or replace function public.admin_field_flags()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'path', p.storage_path, 'note', p.field_note,
      'by', btrim(coalesce(adm.first_name, '') || ' ' || coalesce(adm.last_name, '')),
      'client', c.name, 'dog_name', d.name,
      'client_id', v.client_id, 'visited_at', v.visited_at,
      'seen', false
    ) order by p.created_at desc)
    from public.visit_photos p
    left join public.admins adm on adm.id = p.flagged_by
    left join public.visits v on v.id = p.visit_id
    left join public.clients c on c.id = v.client_id
    left join public.dogs d on d.id = p.dog_id
   where p.field_flag
     and p.field_seen_at is null), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_field_flags() from public, anon;
grant execute on function public.admin_field_flags() to authenticated, service_role;
