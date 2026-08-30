-- ============================================================
-- Onboarding a client. Run once per business.
--
-- 1. Create their login first: Supabase dashboard, Authentication > Users >
--    Add user. Use their real email and a temporary password.
-- 2. Copy the user's UUID from that screen.
-- 3. Fill in the two values below and run.
-- ============================================================

insert into businesses (name)
values ('REPLACE_ME Business Name')
returning id;
-- Copy the returned id into the next statement.

insert into profiles (id, business_id, full_name)
values (
  'REPLACE_ME auth user uuid',
  'REPLACE_ME business id from above',
  'REPLACE_ME Owner Name'
);
