-- ============================================================
-- VisiScale CRM — foundation
-- Run this in the Supabase SQL editor.
--
-- Multi-tenant by design: one project holds every client, and every row
-- carries a business_id. Row Level Security is what keeps business A from
-- reading business B, so it is not optional on any table here.
-- ============================================================

-- Needed for gen_random_uuid(). Usually already on in Supabase, harmless if so.
create extension if not exists pgcrypto;

-- ---------- Tables ----------

create table if not exists businesses (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz not null default now()
);

-- One row per logged-in user, linking them to the business they belong to.
-- id matches the Supabase auth user so policies can look it up from auth.uid().
create table if not exists profiles (
  id           uuid primary key references auth.users on delete cascade,
  business_id  uuid not null references businesses on delete cascade,
  full_name    text,
  created_at   timestamptz not null default now()
);

create table if not exists customers (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references businesses on delete cascade,
  name         text not null,
  phone        text,
  email        text,
  address      text,
  -- Where the lead came from. 'form' is set by the website integration later,
  -- 'manual' by someone typing it in.
  source       text not null default 'manual',
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists customers_business_idx on customers (business_id, created_at desc);
create index if not exists profiles_business_idx  on profiles  (business_id);

-- ---------- Who am I ----------

-- Returns the caller's business_id. SECURITY DEFINER so it can read profiles
-- without RLS recursing (a policy on profiles that queries profiles deadlocks).
create or replace function auth_business_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select business_id from profiles where id = auth.uid();
$$;

-- ---------- Row Level Security ----------

alter table businesses enable row level security;
alter table profiles   enable row level security;
alter table customers  enable row level security;

-- You can see your own business, and nothing else.
drop policy if exists businesses_select on businesses;
create policy businesses_select on businesses
  for select using (id = auth_business_id());

-- You can see your own profile row.
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles
  for select using (id = auth.uid());

-- Customers: the whole model in four policies. Every one is the same shape,
-- "rows belonging to my business", which is what makes this auditable.
drop policy if exists customers_select on customers;
create policy customers_select on customers
  for select using (business_id = auth_business_id());

drop policy if exists customers_insert on customers;
create policy customers_insert on customers
  for insert with check (business_id = auth_business_id());

drop policy if exists customers_update on customers;
create policy customers_update on customers
  for update using (business_id = auth_business_id())
           with check (business_id = auth_business_id());

drop policy if exists customers_delete on customers;
create policy customers_delete on customers
  for delete using (business_id = auth_business_id());

-- ---------- Keep updated_at honest ----------

create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists customers_touch on customers;
create trigger customers_touch before update on customers
  for each row execute function touch_updated_at();


-- ---------- Let the app reach these tables ----------
-- The project was created with "automatically expose new tables" off, which is
-- the safe default. It also means nothing is readable by the app until it is
-- granted here. RLS still decides WHICH rows; these grants only decide which
-- tables are visible at all. Both have to be right.

grant usage on schema public to anon, authenticated;

grant select                         on businesses to authenticated;
grant select                         on profiles   to authenticated;
grant select, insert, update, delete on customers  to authenticated;
