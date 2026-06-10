-- 0145: _capacity_window fixes, caught in live verification minutes after
-- 0144 (two real misparses in the actual book).
-- The bare "Xpm" time fallback was gated on o_parsed, so any constraint that
-- had already matched a day word skipped its time entirely: Chester's "any
-- WEEKDAY at 12pm first-slot" parsed as all-day weekdays, Cynthia's "Tuesday
-- ~3pm" as all-day Tuesday, Lisa Irwin's "12pm every OTHER Tuesday" as
-- all-day Tuesday. Time parsing now tracks its own flag, so a day match and
-- a time match compose instead of shadowing each other.

create or replace function public._capacity_window(
  p_hard text,
  p_not_days text[],
  out o_dows int[],
  out o_start time,
  out o_end_start time,
  out o_parsed boolean
)
language plpgsql
immutable
set search_path to ''
as $$
declare
  v_t text := lower(coalesce(p_hard, ''));
  v_d text;
  v_x int;
  v_named int[] := array[]::int[];
  v_time_done boolean := false;
  m text[];
  h1 int; h2 int;
begin
  o_dows := array[0,1,2,3,4,5,6];
  o_start := time '00:00';
  o_end_start := time '23:59';
  o_parsed := true;

  if p_not_days is not null then
    foreach v_d in array p_not_days loop
      v_x := case lower(left(v_d, 3))
        when 'sun' then 0 when 'mon' then 1 when 'tue' then 2 when 'wed' then 3
        when 'thu' then 4 when 'fri' then 5 when 'sat' then 6 else null end;
      if v_x is not null then
        o_dows := array_remove(o_dows, v_x);
      end if;
    end loop;
  end if;

  if v_t = '' then
    return;
  end if;
  o_parsed := false;

  if v_t like '%sunday%' then v_named := v_named || 0; end if;
  if v_t like '%monday%' then v_named := v_named || 1; end if;
  if v_t like '%tuesday%' then v_named := v_named || 2; end if;
  if v_t like '%wednesday%' then v_named := v_named || 3; end if;
  if v_t like '%thursday%' then v_named := v_named || 4; end if;
  if v_t like '%friday%' then v_named := v_named || 5; end if;
  if v_t like '%saturday%' then v_named := v_named || 6; end if;
  if v_t like '%weekend%' then v_named := v_named || array[0, 6]; end if;
  if v_t like '%weekday%' then v_named := v_named || array[1, 2, 3, 4, 5]; end if;
  if array_length(v_named, 1) is not null then
    select coalesce(array_agg(x), array[]::int[]) into o_dows
      from unnest(o_dows) x where x = any(v_named);
    o_parsed := true;
  end if;

  -- Time-of-day language, most specific first; v_time_done tracks the time
  -- half on its own so it composes with a day match instead of being
  -- shadowed by it.
  m := regexp_match(v_t, '(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})');
  if m is not null then
    o_start := make_time(m[1]::int, m[2]::int, 0);
    o_end_start := make_time(m[3]::int, m[4]::int, 0);
    o_parsed := true; v_time_done := true;
  else
    m := regexp_match(v_t, '(\d{1,2})\s*pm\s+or\s+(\d{1,2})\s*pm');
    if m is not null then
      h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
      h2 := m[2]::int; if h2 < 12 then h2 := h2 + 12; end if;
      o_start := make_time(h1, 0, 0);
      o_end_start := make_time(least(h2 + 1, 23), 0, 0);
      o_parsed := true; v_time_done := true;
    else
      -- The negated form first: "gate hard after 6pm" means the visit must
      -- END by then (Barbara Lape), the opposite of "available after 6pm".
      m := regexp_match(v_t, 'hard after\s+(\d{1,2})(:\d{2})?\s*pm');
      if m is not null then
        h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
        o_end_start := make_time(h1, 0, 0);
        o_parsed := true; v_time_done := true;
      end if;
      if not v_time_done then
        m := regexp_match(v_t, 'after\s+(\d{1,2})(:\d{2})?\s*pm');
        if m is not null then
          h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
          o_start := make_time(h1, 0, 0);
          o_parsed := true; v_time_done := true;
        end if;
      end if;
      m := regexp_match(v_t, '(?:no later than|before|by)\s+(\d{1,2})(:\d{2})?\s*pm');
      if m is not null then
        h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
        o_end_start := make_time(h1, 0, 0);
        o_parsed := true; v_time_done := true;
      end if;
      if not v_time_done then
        m := regexp_match(v_t, '(\d{1,2})\s*pm');
        if m is not null then
          h1 := m[1]::int; if h1 < 12 then h1 := h1 + 12; end if;
          o_start := make_time(greatest(h1 - 1, 0), 0, 0);
          o_end_start := make_time(least(h1 + 1, 23), 0, 0);
          o_parsed := true;
        end if;
      end if;
    end if;
  end if;

  if array_length(o_dows, 1) is null then
    o_dows := array[0,1,2,3,4,5,6];
    o_parsed := false;
  end if;
end;
$$;
revoke all on function public._capacity_window(text, text[]) from public;
grant execute on function public._capacity_window(text, text[]) to service_role;
