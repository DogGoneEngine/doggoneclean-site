-- 0019_client_block_times.sql
-- Attach each legacy client's on-site block time (the median appointment cycle
-- from years of history) to their record, so the scheduler can reserve each
-- client's real minutes instead of a fixed slot (legacy_folds_into_v2). Source
-- of the numbers: legacy/data/block_times.json, derived from
-- legacy/data/cycle_times.md (the Claude-dgc_legacy_cycle_times sheet).
-- Confidence reflects how many visits backed the median (single-visit and the
-- mixed groom/nails client are low).

alter table public.clients
  add column if not exists visit_minutes integer
    check (visit_minutes is null or visit_minutes > 0),
  add column if not exists visit_minutes_confidence text
    check (visit_minutes_confidence is null
           or visit_minutes_confidence in ('high', 'medium', 'low'));
