-- 0154: Riker's context now carries the client's last visit date and next
-- booked appointment, so "the previous appointment, whenever it was" resolves
-- to a real date (Becky Swinford case: scores belonged on the April 4 visit)
-- and "they're already booked" is visible to the parse.

create or replace function public.admin_riker_context(p_client_id uuid default null::uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is not null then
    return (select jsonb_build_object(
        'client', jsonb_build_object('id', c.id, 'name', c.name),
        'last_visit', (select max(v.visited_at)::date from public.visits v
                        where v.client_id = c.id and v.visited_at <= now()),
        'next_appointment', (select min(a.scheduled_start) from public.bath_appointments a
                              join public.bath_subscribers s on s.id = a.subscriber_id
                             where s.client_id = c.id and a.scheduled_start > now()
                               and a.status not in ('cancelled', 'no_show', 'skipped')),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name,
                            'breed', d.breed, 'price_cents', d.price_cents,
                            'roster_status', coalesce(d.roster_status, 'regular')) order by d.name)
                            from public.dogs d where d.client_id = c.id), '[]'::jsonb),
        'notify_people', coalesce((select jsonb_agg(jsonb_build_object(
                            'id', np.id, 'name', np.name, 'phone', np.phone_e164, 'email', np.email,
                            'mode', np.mode, 'active', np.active, 'until', np.until_date) order by np.created_at)
                            from public.notify_people np where np.client_id = c.id), '[]'::jsonb))
      from public.clients c where c.id = p_client_id);
  end if;
  return jsonb_build_object('clients', coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name,
        'aliases', coalesce((select jsonb_agg(a.alias) from public.client_aliases a where a.client_id = c.id), '[]'::jsonb),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name,
                            'roster_status', coalesce(d.roster_status, 'regular')) order by d.name)
                            from public.dogs d where d.client_id = c.id), '[]'::jsonb))
      order by c.name)
    from public.clients c
   where c.exclude_from_everything = false and c.archived_at is null), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_riker_context(uuid) from public, anon;
grant execute on function public.admin_riker_context(uuid) to authenticated, service_role;
