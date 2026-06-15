-- 0191_agent_persona_names.sql
-- Put the Greek persona names on the AI department-head titles (the HR floor).
-- The persona is a display label over the existing agents; agent_key, department,
-- and every function stay exactly as they are. Format: "Persona, Role".
-- Naming cosmology and the full roster are recorded in CLEAN_SCROLL_OF_HEPHAESTUS.md
-- (and the Nails scroll) under "NAMING COSMOLOGY AND AGENT ROSTER", whose permanent
-- home is the mount-olympus repo. Personas group the agents by portfolio:
--   Plutus (finance), Daedalus (operations), Talos (infrastructure),
--   Harmonia (people), Peitho (growth), Dike (compliance), Chiron (valuation coach),
--   Mnemosyne (archivist), Nestor (weekly review), Eos (day-before brief).
-- One persona wears every hat in its portfolio; the role keeps each hat legible.

update public.agents set label = 'Plutus, CFO'                 where agent_key = 'cfo';
update public.agents set label = 'Plutus, Ledger Keeper'       where agent_key = 'ledger_keeper';
update public.agents set label = 'Plutus, Bookkeeper'          where agent_key = 'bookkeeper';
update public.agents set label = 'Plutus, Pricing watcher'     where agent_key = 'pricing';

update public.agents set label = 'Daedalus, Operations head'   where agent_key = 'coo';
update public.agents set label = 'Daedalus, Availability watcher' where agent_key = 'capacity';
update public.agents set label = 'Daedalus, Reorder watcher'   where agent_key = 'reorder';

update public.agents set label = 'Talos, Infrastructure'       where agent_key = 'infra';
update public.agents set label = 'Talos, Maintenance watcher'  where agent_key = 'maintenance';

update public.agents set label = 'Harmonia, HR head'           where agent_key = 'hr';

update public.agents set label = 'Peitho, Growth head'         where agent_key = 'growth';
update public.agents set label = 'Peitho, Retention watcher'   where agent_key = 'retention';
update public.agents set label = 'Peitho, Win-back watcher'    where agent_key = 'winback';

update public.agents set label = 'Dike, Compliance head'       where agent_key = 'compliance';

update public.agents set label = 'Chiron, Valuation coach'     where agent_key = 'value_coach';
update public.agents set label = 'Mnemosyne, Archivist'        where agent_key = 'archivist';
update public.agents set label = 'Nestor, Weekly review'       where agent_key = 'chief_of_staff';
update public.agents set label = 'Eos, Day-before brief'       where agent_key = 'tomorrow';
