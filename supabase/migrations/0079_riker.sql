-- 0079_riker.sql
-- Riker: Paul speaks an appointment update in plain language and it gets filed
-- into the right place on the contact sheet, instead of typed by hand. The split
-- is the house pattern: an edge function has Claude PARSE the utterance into a
-- structured plan (proposes, never writes), and these RPCs do the reading and the
-- writing under the admin gate. admin_riker_context feeds the parser the client +
-- dogs it is allowed to touch; admin_riker_apply executes a confirmed plan.
-- The voice-to-text is the phone's job; nothing here takes audio.
-- See riker_capture_agent.

-- Context for the parser: one client's dogs, or the whole active book to resolve
-- a spoken name. Admin-gated, so the edge function also uses it as the auth check.
create or replace function public.admin_riker_context(p_client_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is not null then
    return (select jsonb_build_object(
        'client', jsonb_build_object('id', c.id, 'name', c.name),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name) order by d.name)
                            from public.dogs d where d.client_id = c.id), '[]'::jsonb))
      from public.clients c where c.id = p_client_id);
  end if;
  return jsonb_build_object('clients', coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name,
        'aliases', coalesce((select jsonb_agg(a.alias) from public.client_aliases a where a.client_id = c.id), '[]'::jsonb),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name) order by d.name)
                            from public.dogs d where d.client_id = c.id), '[]'::jsonb))
      order by c.name)
    from public.clients c
   where c.exclude_from_everything = false and c.archived_at is null), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_riker_context(uuid) from public;
grant execute on function public.admin_riker_context(uuid) to authenticated;

-- Apply a confirmed plan. Shape (all parts optional except client_id):
--   { "client_id": uuid,
--     "visit": { "service_type", "work_done", "visit_notes", "actual_minutes",
--                "amount_cents", "payment_method",
--                "dog_scores": [ { "dog_id", "score" 1-5 } ] } | null,
--     "client_note": text | null,
--     "dog_notes": [ { "dog_id", "text" } ] | null }
-- Every dog reference is validated to belong to the client before it is written.
create or replace function public.admin_riker_apply(p_plan jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_client uuid; v_sub uuid; v_admin uuid; v_visit uuid;
        v_scores int := 0; v_note boolean := false; v_dognotes int := 0; r record;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_client := nullif(p_plan->>'client_id','')::uuid;
  if v_client is null then raise exception 'riker: no client resolved'; end if;
  if not exists (select 1 from public.clients where id = v_client) then raise exception 'riker: client not found'; end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  select id into v_sub from public.bath_subscribers where client_id = v_client limit 1;

  if jsonb_typeof(p_plan->'visit') = 'object' then
    insert into public.visits (
      client_id, subscriber_id, visited_at, service_type, dog_ids,
      work_done, visit_notes, actual_minutes, amount_collected_cents, payment_method, source, completed_by
    ) values (
      v_client, v_sub, now(),
      nullif(p_plan->'visit'->>'service_type',''),
      coalesce((select array_agg((e->>'dog_id')::uuid)
                  from jsonb_array_elements(coalesce(p_plan->'visit'->'dog_scores','[]')) e
                 where exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client)), '{}'),
      nullif(p_plan->'visit'->>'work_done',''),
      nullif(p_plan->'visit'->>'visit_notes',''),
      nullif(p_plan->'visit'->>'actual_minutes','')::int,
      nullif(p_plan->'visit'->>'amount_cents','')::int,
      nullif(p_plan->'visit'->>'payment_method',''),
      'riker', v_admin
    ) returning id into v_visit;

    insert into public.visit_dog_ratings (visit_id, dog_id, score)
    select v_visit, (e->>'dog_id')::uuid, (e->>'score')::int
      from jsonb_array_elements(coalesce(p_plan->'visit'->'dog_scores','[]')) e
     where nullif(e->>'score','') is not null and (e->>'score')::int between 1 and 5
       and exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client)
    on conflict (visit_id, dog_id) do update set score = excluded.score;
    get diagnostics v_scores = row_count;
  end if;

  if nullif(btrim(coalesce(p_plan->>'client_note','')),'') is not null then
    update public.clients set note = coalesce(note || ' ; ', '') || btrim(p_plan->>'client_note'), updated_at = now()
     where id = v_client;
    v_note := true;
  end if;

  for r in select (e->>'dog_id')::uuid as dog_id, btrim(e->>'text') as text
             from jsonb_array_elements(coalesce(p_plan->'dog_notes','[]')) e
            where nullif(btrim(e->>'text'),'') is not null
  loop
    update public.dogs set notes = coalesce(notes || ' ; ', '') || r.text, updated_at = now()
     where id = r.dog_id and client_id = v_client;
    if found then v_dognotes := v_dognotes + 1; end if;
  end loop;

  return jsonb_build_object('visit_id', v_visit, 'scores_applied', v_scores,
                           'client_note_appended', v_note, 'dog_notes_appended', v_dognotes);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public;
grant execute on function public.admin_riker_apply(jsonb) to authenticated;
