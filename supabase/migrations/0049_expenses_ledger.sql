-- 0049_expenses_ledger.sql
-- The expense ledger: the business account's actual money-out. A monthly bank
-- statement imports every outflow as a business expense by default (no per-row
-- clicking) - it is the business account, so everything out of it is a business
-- expense. Outliers can be flagged not-business; a business charge that landed
-- on a personal card can be added by hand. This is the business's own books, so
-- it lives in the DB (the sellability rule is about personal accounts, not the
-- business ledger). external_id is always set, so a plain unique index gives
-- idempotent re-imports.

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  txn_date date not null,
  description text not null,
  amount_cents integer not null check (amount_cents >= 0),
  category text not null default 'other'
    check (category = any (array['supplies','fuel','equipment','software','infrastructure','ai','payments','domains','insurance','marketing','meals','wages','other'])),
  vendor text,
  card text check (card is null or card = any (array['business','personal'])),
  is_business boolean not null default true,
  source text not null default 'bank_import' check (source = any (array['bank_import','manual'])),
  external_id text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists expenses_external_uidx on public.expenses (external_id);
create index if not exists expenses_date_idx on public.expenses (txn_date desc);
alter table public.expenses enable row level security;

create or replace function public.admin_import_expenses(p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_received int; v_inserted int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  with input as (
    select * from jsonb_to_recordset(p_rows) as x(
      txn_date date, description text, amount_cents int, category text, is_business boolean, external_id text)
  ),
  norm as (
    select txn_date, description, amount_cents, coalesce(category,'other') as category,
           coalesce(is_business,true) as is_business,
           coalesce(nullif(external_id,''), md5(txn_date::text||'|'||amount_cents||'|'||lower(coalesce(description,'')))) as ext
      from input where txn_date is not null and amount_cents is not null and amount_cents >= 0
  ),
  ins as (
    insert into public.expenses (txn_date, description, amount_cents, category, is_business, source, external_id)
    select txn_date, description, amount_cents, category, is_business, 'bank_import', ext from norm
    on conflict (external_id) do nothing
    returning 1
  )
  select (select count(*) from norm), (select count(*) from ins) into v_received, v_inserted;
  return jsonb_build_object('received', v_received, 'inserted', v_inserted, 'skipped', v_received - v_inserted);
end;
$$;
revoke all on function public.admin_import_expenses(jsonb) from public;
grant execute on function public.admin_import_expenses(jsonb) to authenticated;

create or replace function public.admin_add_expense(
  p_txn_date date, p_description text, p_amount_cents integer,
  p_category text default 'other', p_card text default null, p_vendor text default null, p_notes text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_description),'')='' then raise exception 'description required'; end if;
  insert into public.expenses (txn_date, description, amount_cents, category, card, vendor, notes, source, external_id, is_business)
  values (p_txn_date, p_description, p_amount_cents, coalesce(p_category,'other'), p_card, p_vendor, p_notes, 'manual', 'manual:'||gen_random_uuid()::text, true)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_expense(date, text, integer, text, text, text, text) from public;
grant execute on function public.admin_add_expense(date, text, integer, text, text, text, text) to authenticated;

create or replace function public.admin_set_expense_business(p_id uuid, p_is_business boolean)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.expenses set is_business = p_is_business, updated_at = now() where id = p_id;
  if not found then raise exception 'expense not found'; end if;
end;
$$;
revoke all on function public.admin_set_expense_business(uuid, boolean) from public;
grant execute on function public.admin_set_expense_business(uuid, boolean) to authenticated;

create or replace function public.admin_set_expense_category(p_id uuid, p_category text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.expenses set category = p_category, updated_at = now() where id = p_id;
  if not found then raise exception 'expense not found'; end if;
end;
$$;
revoke all on function public.admin_set_expense_category(uuid, text) from public;
grant execute on function public.admin_set_expense_category(uuid, text) to authenticated;

create or replace function public.admin_expense_summary(p_window_days integer default 90)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_total bigint; v_count int; v_excluded int; v_bycat jsonb; v_bymonth jsonb; v_recent jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(sum(amount_cents) filter (where is_business),0),
         count(*) filter (where is_business),
         count(*) filter (where not is_business)
    into v_total, v_count, v_excluded
    from public.expenses where txn_date >= (now() - make_interval(days => p_window_days))::date;

  select coalesce(jsonb_agg(jsonb_build_object('category', category, 'cents', cents, 'n', n) order by cents desc), '[]'::jsonb)
    into v_bycat from (
      select category, sum(amount_cents) cents, count(*) n from public.expenses
       where is_business and txn_date >= (now() - make_interval(days => p_window_days))::date
       group by category) c;

  select coalesce(jsonb_agg(jsonb_build_object('month', to_char(mon,'Mon YYYY'), 'cents', cents) order by mon), '[]'::jsonb)
    into v_bymonth from (
      select date_trunc('month', txn_date) mon, sum(amount_cents) cents from public.expenses
       where is_business and txn_date >= date_trunc('month', now())::date - interval '5 months'
       group by 1) m;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', id, 'txn_date', txn_date, 'description', description, 'amount_cents', amount_cents,
           'category', category, 'is_business', is_business, 'source', source) order by txn_date desc, created_at desc), '[]'::jsonb)
    into v_recent from (
      select * from public.expenses order by txn_date desc, created_at desc limit 60) r;

  return jsonb_build_object('window_days', p_window_days, 'total_business_cents', v_total,
    'business_count', v_count, 'excluded_count', v_excluded,
    'by_category', v_bycat, 'by_month', v_bymonth, 'recent', v_recent);
end;
$$;
revoke all on function public.admin_expense_summary(integer) from public;
grant execute on function public.admin_expense_summary(integer) to authenticated;
