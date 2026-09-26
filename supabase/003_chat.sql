-- ============================================================
-- CHAT
--
-- Adds an admin concept and a messages table.
--
-- Admin exists because every policy before this scoped to the logged-in
-- user's own business, which meant nobody could hold a conversation with a
-- client: VisiScale would only ever see VisiScale's messages.
-- ============================================================

alter table profiles add column if not exists is_admin boolean not null default false;

-- security definer so the policy can read profiles without recursing through
-- the policy on profiles itself
create or replace function auth_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false)
$$;

create table if not exists messages (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references businesses on delete cascade,
  sender_id    uuid not null references auth.users on delete cascade,
  body         text not null,
  created_at   timestamptz not null default now()
);

create index if not exists messages_business_created_idx
  on messages (business_id, created_at);

-- Rule 2: RLS and the policy ship with the table, never after.
alter table messages enable row level security;

drop policy if exists messages_select on messages;
create policy messages_select on messages
  for select using (business_id = auth_business_id() or auth_is_admin());

-- sender_id = auth.uid() so nobody can post as somebody else, admins included
drop policy if exists messages_insert on messages;
create policy messages_insert on messages
  for insert with check (
    (business_id = auth_business_id() or auth_is_admin())
    and sender_id = auth.uid()
  );

grant select, insert on messages to authenticated;

alter publication supabase_realtime add table messages;
