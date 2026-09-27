-- ============================================================
-- DIRECTORY CHECKLIST
--
-- Two tables, because the list of directories is the same for every client
-- and only the progress differs.
--
--   directories         the master list. Shared, read-only to the app.
--   client_directories  one row per client per directory, holding status.
--
-- The three flags mirror the symbols on the citation tool, because they are
-- the only ones that change what you have to DO:
--   needs_phone_verification  a code arrives by phone, so someone must answer
--   needs_client_action       cannot be finished without the client
--   can_hide_address          offer it to a client working out of their house
-- ============================================================

create table if not exists directories (
  id                        uuid primary key default gen_random_uuid(),
  name                      text not null,
  url                       text,
  -- core, review, trade, local. Trade rows only apply to some clients.
  category                  text not null default 'core',
  needs_phone_verification  boolean not null default false,
  needs_client_action       boolean not null default false,
  can_hide_address          boolean not null default false,
  -- Anything that costs money or behaves oddly. Shown under the row.
  notes                     text,
  sort_order                int not null default 100,
  created_at                timestamptz not null default now(),
  -- Name is the identity, so the seed file can be re-run after an edit
  -- and update rows instead of duplicating them.
  unique (name)
);

create table if not exists client_directories (
  business_id   uuid not null references businesses  on delete cascade,
  directory_id  uuid not null references directories on delete cascade,
  -- todo | waiting | live | skipped
  status        text not null default 'todo',
  notes         text,
  updated_at    timestamptz not null default now(),
  primary key (business_id, directory_id)
);

create index if not exists client_directories_business_idx
  on client_directories (business_id);

drop trigger if exists client_directories_touch on client_directories;
create trigger client_directories_touch before update on client_directories
  for each row execute function touch_updated_at();

-- Rule 2: RLS and the policy ship with the table, never after.
alter table directories        enable row level security;
alter table client_directories enable row level security;

-- The master list is reference data. Everyone signed in can read it; only an
-- admin can change it, so a client cannot edit the checklist they are judged by.
drop policy if exists directories_select on directories;
create policy directories_select on directories
  for select using (true);

drop policy if exists directories_write on directories;
create policy directories_write on directories
  for all using (auth_is_admin()) with check (auth_is_admin());

-- A client can watch their own progress. Only an admin can move a row, since
-- the agency is the one doing the work.
drop policy if exists client_directories_select on client_directories;
create policy client_directories_select on client_directories
  for select using (business_id = auth_business_id() or auth_is_admin());

drop policy if exists client_directories_write on client_directories;
create policy client_directories_write on client_directories
  for all using (auth_is_admin()) with check (auth_is_admin());

grant select                         on directories        to authenticated;
grant insert, update, delete         on directories        to authenticated;
grant select, insert, update, delete on client_directories to authenticated;
