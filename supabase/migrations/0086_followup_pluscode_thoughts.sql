-- 0086_followup_pluscode_thoughts.sql
-- Three field additions from Paul reviewing client records:
--   1. dogs.follow_up: a per-dog "ask about / check next time" reminder, kept
--      SEPARATE from standing_instructions (a standing grooming instruction and a
--      one-time follow-up are different things and were getting mingled). Donna's
--      Fledge note ("ask about her belly") is moved here out of the instructions.
--   2. location_plus already exists; add a setter so the plus code is editable
--      (some addresses route to the wrong place; the plus code is the reliable
--      locator and the maps link prefers it).
--   3. clients.message_thoughts: a free, stream-of-consciousness field where Paul
--      dumps whatever he is thinking about the dog or the appointment; a draft
--      agent turns it into a personalized client message (test for now, send
--      later). See dog_follow_up + client_message_draft.

alter table public.dogs add column if not exists follow_up text;
alter table public.clients add column if not exists message_thoughts text;

create or replace function public.admin_set_dog_followup(p_dog_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.dogs set follow_up = nullif(btrim(p_text), ''), updated_at = now() where id = p_dog_id;
  if not found then raise exception 'dog not found'; end if;
end;
$$;
revoke all on function public.admin_set_dog_followup(uuid, text) from public;
grant execute on function public.admin_set_dog_followup(uuid, text) to authenticated;

create or replace function public.admin_set_client_plus(p_client_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.clients set location_plus = nullif(btrim(p_text), ''), updated_at = now() where id = p_client_id;
  if not found then raise exception 'client not found'; end if;
end;
$$;
revoke all on function public.admin_set_client_plus(uuid, text) from public;
grant execute on function public.admin_set_client_plus(uuid, text) to authenticated;

create or replace function public.admin_set_client_thoughts(p_client_id uuid, p_text text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.clients set message_thoughts = nullif(btrim(p_text), ''), updated_at = now() where id = p_client_id;
  if not found then raise exception 'client not found'; end if;
end;
$$;
revoke all on function public.admin_set_client_thoughts(uuid, text) from public;
grant execute on function public.admin_set_client_thoughts(uuid, text) to authenticated;

-- Donna's Fledge: move the "ask about her belly" note from standing instructions
-- to the follow-up field, where it belongs.
update public.dogs d set
    follow_up = 'Ask about her belly and tummy issues; she went to the vet (see Oct 2025 visit notes).',
    standing_instructions = null,
    updated_at = now()
  from public.clients c
 where c.id = d.client_id and c.name = 'Donna DiPasqua' and d.name = 'Fledge';
