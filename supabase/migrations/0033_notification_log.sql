-- 0033_notification_log.sql
-- Idempotency backbone for Clean's confirmations + reminders (the Acuity
-- replacement). Mirrors DGN's notification_log, retargeted to Clean's tables.
-- Every successful send writes a row keyed by dedup_key; the partial unique
-- index (where status='sent') makes a double-send impossible even if the cron
-- watcher fires twice or a missed run catches up on the next pass. Service-role
-- only (the send-notification edge function reads/writes it); RLS denies all
-- client access. Email only for now; SMS is a configured channel that no-ops
-- until Twilio/A2P 10DLC is wired, so the column shape already allows it.
create table if not exists public.notification_log (
  id             uuid        primary key default gen_random_uuid(),
  tenant_id      text        not null default 'DGC',
  subscriber_id  uuid        references public.bath_subscribers(id)  on delete cascade,
  appointment_id uuid        references public.bath_appointments(id) on delete set null,
  bath_dog_id    uuid        references public.bath_dogs(id)         on delete set null,
  kind           text        not null,
  channel        text        not null check (channel in ('email', 'sms')),
  status         text        not null check (status in ('sent', 'skipped', 'failed')),
  skip_reason    text,
  provider_id    text,
  dedup_key      text        not null,
  subject        text,
  recipient      text,
  payload        jsonb,
  error          text,
  sent_at        timestamptz not null default now()
);

create unique index if not exists notification_log_dedup_sent_idx
  on public.notification_log (dedup_key) where status = 'sent';
create index if not exists notification_log_subscriber_kind_idx
  on public.notification_log (subscriber_id, kind, sent_at desc);
create index if not exists notification_log_appointment_idx
  on public.notification_log (appointment_id);

alter table public.notification_log enable row level security;
revoke all on public.notification_log from anon, authenticated;

comment on table public.notification_log is
  'Append-only ledger of every notification dispatch (sent/skipped/failed). The unique index on dedup_key where status=sent enforces no-duplicate-sends. Dedup conventions: {kind}:{appointment_id}:{channel}.';
