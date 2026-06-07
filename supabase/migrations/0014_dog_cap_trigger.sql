-- 0014_dog_cap_trigger.sql
--
-- Enforce the three-dog household cap in a place the portal cannot bypass.
-- bath_dogs already allows a signed-in client to insert/update their own
-- dogs (self RLS), so the cap cannot live only in the add button or even in
-- an RPC: a direct REST insert would skip it. A BEFORE trigger is the
-- durable home, so the cap holds no matter how the row arrives.
--
-- three_dog_cap (product): max 3 active dogs per household. This is a
-- Villages HOA data point, never surfaced to customers as a Dog Gone rule,
-- so the trigger just blocks the 4th; the UI hides the add control at 3
-- rather than explaining a policy.
create or replace function public.bath_enforce_dog_cap()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_active integer;
begin
  if NEW.active then
    select count(*)
      into v_active
    from public.bath_dogs
    where subscriber_id = NEW.subscriber_id
      and active = true
      and id <> NEW.id;

    if v_active >= 3 then
      raise exception 'dog_cap_exceeded'
        using errcode = 'check_violation',
              hint = 'A household can have at most 3 active dogs.';
    end if;
  end if;
  return NEW;
end;
$$;

-- Keep the trigger function off the exposed REST API. The trigger still
-- fires (triggers run as the table owner regardless of EXECUTE grants); we
-- just do not want it callable as an RPC.
revoke all on function public.bath_enforce_dog_cap() from public, anon, authenticated;

drop trigger if exists bath_dogs_cap on public.bath_dogs;
create trigger bath_dogs_cap
  before insert or update on public.bath_dogs
  for each row execute function public.bath_enforce_dog_cap();
