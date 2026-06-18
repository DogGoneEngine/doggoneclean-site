-- 0209_dog_door_handling.sql
--
-- Door handling, take two (dog_handling_toggles, revised 2026-06-18 after Paul's
-- note that the flat flags read like hard rules). Most door handling is "how I
-- usually do it," not a requirement; sometimes it IS a requirement. So each
-- concern now carries a LEVEL: 'usual' (my normal way, a preference) or 'always'
-- (a firm rule, surfaced hard). Stored as a jsonb map of known concern -> level,
-- replacing the flat handling_flags text[]. Adds the "keep away from other
-- animals" concern (Kacey, Kevin Cummings: does not get along with other dogs).
-- The free-text dogs.handling note stays for nuance. Because the difference
-- between "usually carry him" and "ALWAYS keep him away from other dogs" is the
-- whole point of surfacing it at the door, and a new operator must see which is
-- which without being told.

alter table public.dogs drop constraint if exists dogs_handling_flags_known;
drop function if exists public.admin_set_dog_handling_flags(uuid, text[]);
alter table public.dogs drop column if exists handling_flags;

alter table public.dogs add column if not exists door_handling jsonb;

-- Known concerns and the two levels. Validated in the RPC (jsonb shape is awkward
-- to pin with a check constraint); the RPC is the durable gate.
create or replace function public.admin_set_dog_door_handling(p_dog_id uuid, p_handling jsonb)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare cleaned jsonb := '{}'::jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_handling is not null and jsonb_typeof(p_handling) = 'object' then
    select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
      into cleaned
      from jsonb_each_text(p_handling)
     where key in ('carry','leash','flight_risk','keep_separate','release_ok')
       and value in ('usual','always');
  end if;
  update public.dogs
     set door_handling = case when cleaned = '{}'::jsonb then null else cleaned end,
         updated_at = now()
   where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_door_handling(uuid, jsonb) from public, anon;
grant execute on function public.admin_set_dog_door_handling(uuid, jsonb) to authenticated, service_role;
