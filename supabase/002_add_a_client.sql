-- ============================================================
-- ADD A CLIENT
--
-- Do this AFTER you have created their login:
--   Supabase sidebar > Authentication > Users > Add user
--   Enter their email and a temporary password. Tick "Auto Confirm User".
--
-- Then change the three lines marked CHANGE ME below and hit Run.
-- No copying UUIDs around. It finds the user by their email address.
-- ============================================================

insert into businesses (name)
values ('Empirical Renovations');                      -- CHANGE ME: business name

insert into profiles (id, business_id, full_name)
select
  u.id,
  b.id,
  'Gavin Williams'                                     -- CHANGE ME: person's name
from auth.users u
cross join businesses b
where u.email = 'gavin@empiricalrenovations.com'       -- CHANGE ME: their login email
  and b.name  = 'Empirical Renovations';               -- must match the name above

-- Check it worked. You should get one row back.
select p.full_name, b.name as business
from profiles p join businesses b on b.id = p.business_id;
