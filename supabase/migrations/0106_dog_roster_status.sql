-- 0106_dog_roster_status.sql
-- A dog's standing on the client's roster, so the regular working roster stays
-- distinct from the dogs kept only for reference (deceased, former, occasional
-- drop-ins) without throwing any of them away. Paul (2026-06-09): keep every dog's
-- info "so if she mentions a dog's name I won't be like who the fuck was that," but
-- Tonya's regular roster is really Kai and Lydia, with Koa and Ruthie sometimes.
--   regular    = core, serviced most/every cycle
--   occasional = current dog, but not every visit
--   former     = no longer serviced (moved on, given away, unknown)
--   deceased   = passed away
-- Default 'regular'. Flows to the UI automatically via admin_get_client's to_jsonb(d.*).

alter table public.dogs add column if not exists roster_status text not null default 'regular';
alter table public.dogs drop constraint if exists dogs_roster_status_check;
alter table public.dogs add constraint dogs_roster_status_check
  check (roster_status in ('regular','occasional','former','deceased'));

-- Tonya Hunt: Kai + Lydia regular; Koa + Ruthie occasional; Andy deceased; the rest former.
update public.dogs d set roster_status = v.status
from (values
  ('Kai','regular'),('Lydia','regular'),
  ('Koa','occasional'),('Ruthie','occasional'),
  ('Andy','deceased'),('Scrappy','former'),('Pebbles','former'),('Polly','former')
) as v(name, status)
where d.name = v.name
  and d.client_id = (select id from public.clients where name = 'Tonya Hunt');

update public.dogs set notes = 'Deceased. Senior shepherd mix (15-16 years old as of early 2023); last groomed Aug 2024.'
where name = 'Andy' and client_id = (select id from public.clients where name = 'Tonya Hunt');

-- Chloe Castellano: Louie regular; Whiskey + Skout deceased.
update public.dogs d set roster_status = v.status
from (values
  ('Louie','regular'),('Whiskey','deceased'),('Skout','deceased')
) as v(name, status)
where d.name = v.name
  and d.client_id = (select id from public.clients where name = 'Chloe Castellano');
