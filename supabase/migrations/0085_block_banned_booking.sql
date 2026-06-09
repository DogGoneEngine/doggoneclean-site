-- 0085_block_banned_booking.sql
-- Hard-banned clients cannot book. The booking funnel creates a bath_subscriber
-- (anonymously, keyed on phone) as the first write of bath_start_subscription, so
-- a trigger there is the durable, redesign-proof gate: any path that tries to make
-- a subscriber whose email or phone matches a BANNED client (nofly_level='banned',
-- the hard ban, not the shadow ban) aborts with a soft, non-provoking message that
-- reads like a service-area decline, never a personal rejection. Only the hard ban
-- blocks; a shadow-banned client who books on their own is still served.
-- Note: the live funnel's Confirm is currently disabled pending Stripe, so this is
-- the waiting teeth; mapping the message into a friendly funnel panel is parked
-- with the Stripe launch step. See block_banned_from_booking.

create or replace function public._block_banned_subscriber()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.clients c
     where c.nofly_level = 'banned'
       and (
         (nullif(btrim(NEW.email), '') is not null and lower(c.email) = lower(btrim(NEW.email)))
         or (nullif(btrim(NEW.phone_e164), '') is not null and c.phone_e164 = btrim(NEW.phone_e164))
       )
  ) then
    raise exception 'Sorry, we are not taking new clients in your area right now.';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_block_banned_subscriber on public.bath_subscribers;
create trigger trg_block_banned_subscriber
  before insert or update on public.bath_subscribers
  for each row execute function public._block_banned_subscriber();
