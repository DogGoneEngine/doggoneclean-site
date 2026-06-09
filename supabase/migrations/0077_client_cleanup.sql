-- 0077_client_cleanup.sql
-- Operational client dispositions from Paul's book review (2026-06-09), encoded
-- as a REPLAYABLE migration on purpose: a prior round of this cleanup was done as
-- manual database edits and was lost (most likely wiped by a reseed). Migrations
-- run after any seed, so encoding the dispositions here makes them survive a
-- reseed, a rebuild, and a context reset. Keyed by name (stable across reseeds),
-- not by id. See client_dispositions_are_migrations + client_no_winback_flag.

-- Drop the empty, unreferenced leftover staging table (visit-import scaffolding,
-- 0 rows, nothing reads it) that tripped the RLS-disabled advisor.
drop table if exists public._tim_stage;

-- A lever to leave an ACTIVE client out of win-back without hiding them from the
-- book: seasonal regulars who book themselves, VIPs, anyone who self-manages.
alter table public.clients add column if not exists suppress_winback boolean not null default false;

-- Win-back skips suppressed clients.
create or replace function public._winback_due_view()
returns table(id uuid, name text, email text, roster_group text, cadence_days int, last_visit date, days_since int)
language sql security definer set search_path = public, pg_temp
as $$
  select c.id, c.name, c.email, c.roster_group, c.cadence_days,
         max(v.visited_at)::date, (current_date - max(v.visited_at)::date)
    from public.clients c join public.visits v on v.client_id = c.id
   where not c.exclude_from_everything
     and c.archived_at is null
     and coalesce(c.suppress_winback, false) = false
     and not exists (
       select 1 from public.bath_appointments a
       join public.bath_subscribers s on s.id = a.subscriber_id
       where s.client_id = c.id and a.scheduled_start >= now() and a.status in ('requested','confirmed','tentative'))
   group by c.id, c.name, c.email, c.roster_group, c.cadence_days
  having (current_date - max(v.visited_at)::date) >= (case when c.cadence_days is not null then c.cadence_days + 14 else 90 end)
     and (current_date - max(v.visited_at)::date) <= coalesce((select value::int from public.app_secrets where name='winback_max_days'), 540);
$$;

-- Household merge: Amanda Batson is part of Garret Little's household.
-- Move her visit history onto Garret, add her name as a household alias so a
-- search for "Amanda Batson" opens the household, and hide her duplicate record.
update public.visits
   set client_id = (select id from public.clients where name = 'Garret Little')
 where client_id = (select id from public.clients where name = 'Amanda Batson');

insert into public.client_aliases (client_id, alias)
select (select id from public.clients where name = 'Garret Little'), 'Amanda Batson'
where not exists (
  select 1 from public.client_aliases
   where client_id = (select id from public.clients where name = 'Garret Little')
     and lower(btrim(alias)) = 'amanda batson');

update public.clients
   set exclude_from_everything = true, status = 'merged',
       note = coalesce(note || ' ; ', '') || 'Merged into Garret Little household.',
       updated_at = now()
 where name = 'Amanda Batson';

-- No-fly: David Midgett. Falling out when his wife wanted to take over scheduling
-- and was difficult. Do not contact, do not win back.
update public.clients
   set nofly = true,
       nofly_reason = 'Falling out when his wife wanted to take over the dog grooming appointments and was difficult. Do not contact or win back.',
       exclude_from_everything = true, roster_group = 'banned', status = 'banned',
       updated_at = now()
 where name = 'David Midgett';

-- Permanently excluded (retained in the database, hidden from the book, every
-- agent, and win-back; these do NOT auto-unarchive). Reason in status + note.
update public.clients set exclude_from_everything = true, status = 'moved_away',
       note = coalesce(note || ' ; ', '') || 'Moved to France.', updated_at = now()
 where name = 'Diana Boos';

update public.clients set exclude_from_everything = true, status = 'moved_away',
       note = coalesce(note || ' ; ', '') || 'Moved away.', updated_at = now()
 where name = 'Kaitlyn Christopherson';

update public.clients set exclude_from_everything = true, status = 'deceased',
       note = coalesce(note || ' ; ', '') || 'Client passed away.', updated_at = now()
 where name = 'Dottie Dimery';

update public.clients set exclude_from_everything = true, status = 'deceased',
       note = coalesce(note || ' ; ', '') || 'Client passed away.', updated_at = now()
 where name = 'Sally Alderman';

update public.clients set exclude_from_everything = true, status = 'inactive',
       note = coalesce(note || ' ; ', '') || 'Dog passed away. Do not contact for win-back.', updated_at = now()
 where name = 'Robin Bennett';

update public.clients set exclude_from_everything = true, status = 'test_account',
       note = coalesce(note || ' ; ', '') || 'Paul''s wife; used as a test account.', updated_at = now()
 where name = 'Kristin Nickerson';

update public.clients set exclude_from_everything = true, status = 'test_account',
       note = coalesce(note || ' ; ', '') || 'Test account.', updated_at = now()
 where name = 'Paul Nickerson';

-- Seasonal: Mary Jane Hunt is away roughly half the year and books her own
-- appointments (a block starting in October). Keep her in the active book, but
-- never auto win-back her. Once her future appointments are on the books, the
-- existing future-appointment guard also suppresses win-back on its own.
update public.clients set suppress_winback = true,
       note = coalesce(note || ' ; ', '') || 'Seasonal: away roughly half the year; books her own appointments (block starting October). Do not win-back while away.',
       updated_at = now()
 where name = 'Mary Jane Hunt';
