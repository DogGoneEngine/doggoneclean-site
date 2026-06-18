-- 0215_portal_dogs_sync_roster.sql
--
-- The portal now lets an owner manage their own past dogs (see them, bring one
-- back), the mirror of the operator's archived-dogs section (Paul 2026-06-18:
-- "the client should be able to do the same thing in their portal"). The portal
-- works on bath_dogs.active. For a legacy client the same dog also exists in
-- public.dogs (roster_status), and 0213 made the operator's archive action sync
-- bath_dogs.active. This adds the OTHER direction, so a portal archive/bring-back
-- keeps public.dogs.roster_status in step and the drift that announced moved dogs
-- on the tracker cannot come back from the portal side.
--
-- It is written to never fight the operator path (admin_set_dog_status sets
-- public.dogs first, then bath_dogs.active; this trigger only changes roster_status
-- when active actually crosses the active/archived line, so re-setting the same
-- value is a no-op and 'occasional'/'deceased' nuance is preserved).

create or replace function public._sync_dogs_roster_from_bath()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare v_client uuid;
begin
  select s.client_id into v_client from public.bath_subscribers s where s.id = NEW.subscriber_id;
  if v_client is null then return NEW; end if;

  if NEW.active is true then
    -- Brought back: a matching archived legacy dog returns to the working roster.
    update public.dogs set roster_status = 'regular', updated_at = now()
     where client_id = v_client and lower(name) = lower(NEW.name)
       and roster_status in ('moved', 'former', 'deceased');
  else
    -- Taken off the plan: a matching working legacy dog is archived as 'former'.
    update public.dogs set roster_status = 'former', updated_at = now()
     where client_id = v_client and lower(name) = lower(NEW.name)
       and roster_status in ('regular', 'occasional');
  end if;
  return NEW;
end;
$function$;

drop trigger if exists trg_sync_dogs_roster_from_bath on public.bath_dogs;
create trigger trg_sync_dogs_roster_from_bath
  after insert or update of active on public.bath_dogs
  for each row execute function public._sync_dogs_roster_from_bath();
