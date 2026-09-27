-- ============================================================
-- SEED THE DIRECTORY LIST
--
-- Taken from the Empirical Renovations run, so every note here is something
-- that actually happened rather than something a directory claims.
--
-- Safe to re-run: matches on name, updates rather than duplicating. Add new
-- rows to the bottom of this file and run it again.
-- ============================================================

insert into directories
  (name, url, category, needs_phone_verification, needs_client_action, can_hide_address, notes, sort_order)
values
  -- ---------- Core listings ----------
  ('Bing Places', 'https://www.bingplaces.com/', 'core',
   false, true, false,
   'Sign-in is Google or Facebook only, so the client has to be the one to do it.', 10),

  ('Data Axle', 'https://www.data-axle.com/marketing-solutions/local-listings-management/', 'core',
   true, false, false,
   'If the business is already listed, verification comes through as a phone call.', 20),

  ('MapQuest', 'https://www.mapquest.com/', 'core',
   false, false, false,
   'Fed from Yelp. Update Yelp and this follows on its own. Claiming it to manage directly is $12.50/month, which is not worth it.', 30),

  ('Nextdoor', 'https://business.nextdoor.com/', 'core',
   false, false, false, null, 40),

  ('Peeptown', 'https://biz.peeptown.com/claim-business', 'core',
   false, false, false,
   'Create the listing first, then claim it. Claiming sends a verification email.', 50),

  ('Best Pros In Town', 'https://www.bestprosintown.com/addbusiness.php', 'core',
   false, false, false, null, 60),

  -- ---------- Review platforms ----------
  ('Google Business Profile', 'https://business.google.com/', 'review',
   true, true, true,
   'The one that matters. Set it up before the site goes live so the NAP on the site matches it exactly.', 70),

  ('Trustpilot', 'https://signup.business.trustpilot.com/create-account?locale=en-us&cta=free-signup_header_home', 'review',
   false, true, false,
   'Client has to click the verification email.', 80),

  ('Trustindex', 'https://www.trustindex.io/', 'review',
   false, false, false, null, 90),

  ('Houzz', 'https://pro.houzz.com/pro', 'review',
   false, true, true,
   'Client verifies by email. Address can be hidden, which suits anyone working out of their house.', 100),

  ('Bark', 'https://www.bark.com/en/us/sellers/create/', 'review',
   false, false, true, null, 110),

  ('Thumbtack', 'https://www.thumbtack.com/pro', 'review',
   true, false, false,
   'Phone code to sign up, then it pushes paid leads. Cancel before adding a card and check whether the profile stays publicly listed. If it does not, it is worth nothing to us.', 120),

  -- ---------- Trade specific (decks and remodeling) ----------
  ('TrexPro', 'https://trex.my.site.com/TrexProPortal/s/become-a-trexpro', 'trade',
   false, true, false, null, 130),

  ('TimberTech', 'https://www.timbertech.com/pros/', 'trade',
   false, true, false, null, 140),

  ('NADRA', 'https://www.nadra.org/membership/join', 'trade',
   false, true, false,
   'Paid membership. Worth pricing against what the listing is actually likely to return before committing.', 150),

  ('Great American Decks', 'https://greatamericandecks.com/', 'trade',
   false, false, false, null, 160),

  ('Local Deck Builders', 'https://localdeckbuilders.com/', 'trade',
   false, true, false, null, 170),

  ('Koalaty Remodel', 'https://koalatyremodel.com/contact-us/', 'trade',
   false, true, false, null, 180),

  -- ---------- Vermont ----------
  ('Vermont Business Magazine', 'https://vermontbiz.com/', 'local',
   false, true, false, null, 190),

  ('Vermont Chamber of Commerce', 'https://web.vermont.org/atlas/forms/1', 'local',
   false, false, false, null, 200),

  ('Growcycle', 'https://growcycle.com/', 'local',
   false, false, false,
   'Submission form does not work. Left here so nobody spends another twenty minutes finding that out.', 210)

on conflict (name) do update set
  url                      = excluded.url,
  category                 = excluded.category,
  needs_phone_verification = excluded.needs_phone_verification,
  needs_client_action      = excluded.needs_client_action,
  can_hide_address         = excluded.can_hide_address,
  notes                    = excluded.notes,
  sort_order               = excluded.sort_order;

select category, count(*) as directories
from directories group by category order by category;
