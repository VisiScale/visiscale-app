-- ============================================================
-- ADMIN CAN SEE CLIENTS
--
-- Fixes an omission in 003. That migration added the admin concept and gave
-- admins an exemption on messages, but left the policies from 001 alone. So
-- an admin could read every client's messages and could not read a single
-- client's name: businesses still returned only their own row.
--
-- The agency dashboard needs the names to label the conversations, and will
-- need profiles to show who sent what once a client has more than one user.
-- ============================================================

drop policy if exists businesses_select on businesses;
create policy businesses_select on businesses
  for select using (id = auth_business_id() or auth_is_admin());

-- auth_is_admin() is security definer, so this does not recurse through the
-- policy it is sitting on.
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles
  for select using (id = auth.uid() or auth_is_admin());
