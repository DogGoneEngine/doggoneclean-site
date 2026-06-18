-- 0208_dog_handling_flags.sql
--
-- Structured door-handling toggles per dog (dog_handling_toggles). The free-text
-- dogs.handling field ("we've got this") already exists for nuance; these are the
-- firm safety facts Paul wants consistent and scannable at the door, not buried in
-- prose: is the dog carried or leashed, is it an escape/runaway risk, can it be
-- turned loose after. Stored as a small text[] of known keys so the dog card can
-- show them as chips and Clio can set them by voice. Because a dog that bolts when
-- a door opens is a safety fact you cannot afford to scroll for or have go unsaid.

alter table public.dogs add column if not exists handling_flags text[];

-- Keep the vocabulary honest. New keys get added here when the door SOP grows.
alter table public.dogs drop constraint if exists dogs_handling_flags_known;
alter table public.dogs add constraint dogs_handling_flags_known
  check (handling_flags is null or handling_flags <@ array['carry','leash','flight_risk','release_ok']::text[]);

create or replace function public.admin_set_dog_handling_flags(p_dog_id uuid, p_flags text[])
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.dogs
     set handling_flags = case
           when p_flags is null or cardinality(p_flags) = 0 then null
           else (select array_agg(distinct f) from unnest(p_flags) f)
         end,
         updated_at = now()
   where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_handling_flags(uuid, text[]) from public, anon;
grant execute on function public.admin_set_dog_handling_flags(uuid, text[]) to authenticated, service_role;
