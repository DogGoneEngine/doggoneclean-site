-- 0210_door_handling_simplified.sql
--
-- Door handling, take three (dog_handling_toggles, simplified 2026-06-18 after
-- Paul ran the scenarios and found the No/Usually/Always model fit none of them:
-- these are facts, not preferences with a gradient. New shape, a small jsonb:
--   transport: 'carry' | 'leash'   (how the dog gets to the trailer; answers the
--                                    real question, do I bring a leash to the door)
--   escape: true                   (bolts / door-darts; a warning)
--   keep_separate: true            (keep away from other animals; a warning)
--   loose_ok: true                 (can be let loose after; a calm yes)
-- The "leash before the door" concern is gone: it blurred walking-on-leash with
-- escape control, which `escape` already covers. The free-text dogs.handling note
-- stays for nuance. Because clear binary facts beat a three-way that reads as
-- nonsense ("usually a bolt risk").

create or replace function public.admin_set_dog_door_handling(p_dog_id uuid, p_handling jsonb)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare cleaned jsonb := '{}'::jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_handling is not null and jsonb_typeof(p_handling) = 'object' then
    if p_handling->>'transport' in ('carry','leash') then
      cleaned := cleaned || jsonb_build_object('transport', p_handling->>'transport');
    end if;
    if (p_handling->>'escape') = 'true' then cleaned := cleaned || '{"escape":true}'::jsonb; end if;
    if (p_handling->>'keep_separate') = 'true' then cleaned := cleaned || '{"keep_separate":true}'::jsonb; end if;
    if (p_handling->>'loose_ok') = 'true' then cleaned := cleaned || '{"loose_ok":true}'::jsonb; end if;
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

-- Convert any existing usual/always data to the new shape (only Kacey today).
update public.dogs set door_handling = jsonb_strip_nulls(jsonb_build_object(
  'transport',     case when door_handling ? 'carry' then 'carry' when door_handling ? 'leash' then 'leash' end,
  'escape',        case when door_handling ? 'flight_risk' then true end,
  'keep_separate', case when door_handling ? 'keep_separate' then true end,
  'loose_ok',      case when door_handling ? 'release_ok' then true end
)) where door_handling is not null;
update public.dogs set door_handling = null where door_handling = '{}'::jsonb;
