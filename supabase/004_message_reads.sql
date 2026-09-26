-- ============================================================
-- MESSAGE READS
--
-- Tracks how far each person has read in each conversation, which is what
-- the unread dot on the agency dashboard is drawn from.
--
-- Keyed on profile_id rather than business_id alone, because unread is
-- personal: Jack reading a thread must not clear it for Cam. It also means
-- the state follows you between your phone and your laptop, which a
-- localStorage version would not.
-- ============================================================

create table if not exists message_reads (
  profile_id    uuid not null references profiles   on delete cascade,
  business_id   uuid not null references businesses on delete cascade,
  last_read_at  timestamptz not null default now(),
  primary key (profile_id, business_id)
);

-- Rule 2: RLS and the policy ship with the table, never after.
alter table message_reads enable row level security;

-- Your read state is yours. No admin exemption here on purpose: an admin
-- reading everyone's threads still only owns their own place in them.
drop policy if exists message_reads_select on message_reads;
create policy message_reads_select on message_reads
  for select using (profile_id = auth.uid());

drop policy if exists message_reads_insert on message_reads;
create policy message_reads_insert on message_reads
  for insert with check (profile_id = auth.uid());

drop policy if exists message_reads_update on message_reads;
create policy message_reads_update on message_reads
  for update using (profile_id = auth.uid())
           with check (profile_id = auth.uid());

grant select, insert, update on message_reads to authenticated;
