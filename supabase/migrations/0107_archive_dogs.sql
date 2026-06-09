-- 0107_archive_dogs.sql
-- Archiving a dog (reversibly) is just moving it off the regular roster via
-- roster_status, never deleting it (lose-nothing). Adds a 'moved' status for a dog
-- that relocated and may or may not return (Paul: Kevin's Ace and Kage moved to
-- Tampa), plus the RPCs the contact sheet uses to change a dog's status and to edit
-- its notes (so the reason, like "moved to Tampa", is captured). Restoring a dog is
-- the same control set back to regular. See dog_roster_status + visit_history_migration.

alter table public.dogs drop constraint if exists dogs_roster_status_check;
alter table public.dogs add constraint dogs_roster_status_check
  check (roster_status in ('regular','occasional','moved','former','deceased'));

create or replace function public.admin_set_dog_status(p_dog_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_status not in ('regular','occasional','moved','former','deceased') then
    raise exception 'invalid roster_status: %', p_status;
  end if;
  update public.dogs set roster_status = p_status, updated_at = now() where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_status(uuid, text) from public;
grant execute on function public.admin_set_dog_status(uuid, text) to authenticated;

create or replace function public.admin_set_dog_note(p_dog_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.dogs set notes = nullif(btrim(p_text), ''), updated_at = now() where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_note(uuid, text) from public;
grant execute on function public.admin_set_dog_note(uuid, text) to authenticated;

-- Kevin Cummings: Ace and Kage moved to Tampa.
update public.dogs d set roster_status = 'moved',
  notes = 'Moved to Tampa (June 2026); may or may not return.'
where d.name in ('Ace','Kage')
  and d.client_id = (select id from public.clients where name = 'Kevin Cummings');
