-- 0155: HR shows the real human roster from the admins table instead of a
-- hardcoded line, because Jake just joined as a Hurricane Bath Operator.
create or replace function public.admin_list_team()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'first_name', a.first_name,
        'last_name', a.last_name,
        'email', a.email,
        'role', a.role,
        'title', case a.role when 'owner' then 'Owner and Hurricane Bath Operator'
                             else 'Hurricane Bath Operator' end,
        'is_active', a.is_active,
        'signed_in', a.auth_user_id is not null)
      order by (a.role = 'owner') desc, a.created_at)
    from public.admins a where a.is_active), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_team() from public, anon;
grant execute on function public.admin_list_team() to authenticated, service_role;
