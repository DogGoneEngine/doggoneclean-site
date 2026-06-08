-- 0044_schedule_admin.sql
-- The Schedule department's data layer: admin RPCs to read and write Paul's
-- work days, work hours, and per-date exceptions. These write the existing
-- bath_availability_windows (recurring weekly hours per city/weekday) and
-- bath_availability_exceptions (per-date closures or one-off open windows).
-- All gated by _is_admin(); the teeth live here, not in the page.

create or replace function public.admin_list_schedule()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'slug', c.slug, 'timezone', c.hb_timezone,
      'windows', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', w.id, 'weekday', w.weekday,
          'start_time', to_char(w.start_time, 'HH24:MI'),
          'end_time', to_char(w.end_time, 'HH24:MI'),
          'active', w.active
        ) order by w.weekday, w.start_time)
        from public.bath_availability_windows w where w.city_id = c.id), '[]'::jsonb),
      'exceptions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', e.id, 'exception_date', e.exception_date, 'is_closed', e.is_closed,
          'start_time', to_char(e.start_time, 'HH24:MI'),
          'end_time', to_char(e.end_time, 'HH24:MI'),
          'note', e.note
        ) order by e.exception_date)
        from public.bath_availability_exceptions e
        where e.city_id = c.id and e.exception_date >= current_date - 7), '[]'::jsonb)
    ) order by c.name)
    from public.cities c
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_schedule() from public;
grant execute on function public.admin_list_schedule() to authenticated;

-- Upsert a weekly work-hours window. p_id null inserts; otherwise updates.
create or replace function public.admin_set_window(
  p_id uuid,
  p_city_id uuid,
  p_weekday smallint,
  p_start time,
  p_end time,
  p_active boolean default true
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_weekday < 0 or p_weekday > 6 then raise exception 'weekday must be 0..6'; end if;
  if p_end <= p_start then raise exception 'end must be after start'; end if;
  if p_id is null then
    insert into public.bath_availability_windows (city_id, weekday, start_time, end_time, active)
    values (p_city_id, p_weekday, p_start, p_end, coalesce(p_active, true))
    returning id into v_id;
  else
    update public.bath_availability_windows
       set city_id = p_city_id, weekday = p_weekday, start_time = p_start,
           end_time = p_end, active = coalesce(p_active, true), updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then raise exception 'window not found'; end if;
  end if;
  return v_id;
end;
$$;
revoke all on function public.admin_set_window(uuid, uuid, smallint, time, time, boolean) from public;
grant execute on function public.admin_set_window(uuid, uuid, smallint, time, time, boolean) to authenticated;

create or replace function public.admin_delete_window(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.bath_availability_windows where id = p_id;
  if not found then raise exception 'window not found'; end if;
end;
$$;
revoke all on function public.admin_delete_window(uuid) from public;
grant execute on function public.admin_delete_window(uuid) to authenticated;

-- Per-date exception: close a day, or open a one-off window.
create or replace function public.admin_add_exception(
  p_city_id uuid,
  p_date date,
  p_is_closed boolean,
  p_start time default null,
  p_end time default null,
  p_note text default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if not p_is_closed and (p_start is null or p_end is null) then
    raise exception 'an open exception needs a start and end time';
  end if;
  if not p_is_closed and p_end <= p_start then
    raise exception 'end must be after start';
  end if;
  insert into public.bath_availability_exceptions (city_id, exception_date, is_closed, start_time, end_time, note)
  values (p_city_id, p_date, p_is_closed, case when p_is_closed then null else p_start end,
          case when p_is_closed then null else p_end end, p_note)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_exception(uuid, date, boolean, time, time, text) from public;
grant execute on function public.admin_add_exception(uuid, date, boolean, time, time, text) to authenticated;

create or replace function public.admin_delete_exception(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.bath_availability_exceptions where id = p_id;
  if not found then raise exception 'exception not found'; end if;
end;
$$;
revoke all on function public.admin_delete_exception(uuid) from public;
grant execute on function public.admin_delete_exception(uuid) to authenticated;
