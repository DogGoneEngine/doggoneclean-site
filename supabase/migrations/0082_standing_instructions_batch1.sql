-- 0082_standing_instructions_batch1.sql
-- First batch of per-dog standing instructions, transcribed from the newest Drive
-- contact sheet for each client: the explicit "Standing Instructions" field, plus
-- a header-area standing note where the field was blank but a clear standing note
-- sat under the dog block. Real data only: dogs whose sheet had nothing are left
-- null, never invented (Cynthia's Luna, Mary Beth's Theo, Lisa's Tao). Keyed by
-- client + dog name so it replays after a reseed (client_dispositions_are_migrations).
-- Batch = the four clients on the 2026-06-09 route. See dog_standing_instructions.

update public.dogs d set standing_instructions = '8mm comb on body. 13mm comb on head. Leave eyelashes.', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Cynthia Tieche' and d.name = 'Satin';

update public.dogs d set standing_instructions = 'Ask about her belly and tummy issues; she went to the vet (see Oct 2025 visit notes).', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Donna DiPasqua' and d.name = 'Fledge';

update public.dogs d set standing_instructions = 'Full groom: 8mm comb on body, 13mm comb on head. Touch-up: bath and sanitary shave.', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Mary Beth Anderson' and d.name = 'Toby';

update public.dogs d set standing_instructions = '8mm comb on body. 13mm comb on head. Ears long.', updated_at = now()
  from public.clients c where c.id = d.client_id and c.name = 'Lisa Irwin' and d.name = 'Mia';
