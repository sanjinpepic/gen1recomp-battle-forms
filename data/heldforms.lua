-- Bag byte for each held-item persistent form outside Rotom's appliances.
--
-- The same rule every indices table in this directory runs on, for the same
-- reason: Gen 1 stores items as byte ids, so an item with no index cannot
-- exist in a save at all, and changing an index silently turns every one
-- already in a player's bag into a different item.  These are permanent; new
-- items append.
--
-- Continues at 227 where data/fusers.lua stopped (223-226).  Registered
-- through src/persistent.lua's own install, the same as the appliances --
-- these items stamp onto the Pokemon through the shared held-item field, see
-- data/persistent.lua -- and sold at the Indigo Plateau lobby counter rather
-- than the Celadon stone floor: every species here is an endgame legendary or
-- mythical, which is where this mod already sells for that tier (the orbs,
-- the fusion items).  tests/battle_forms_keyitems_test.lua pins that no two
-- of the seven tables ever hand out the same byte.
--
-- Order here is shelf order (src/shop.lua sorts by index) and matches the
-- order the families are introduced in data/persistent.lua: Giratina, then
-- Palkia and Dialga, then Zacian and Zamazenta, then Shaymin.
return {
  GRISEOUS_ORB    = 227,
  LUSTROUS_GLOBE  = 228,
  ADAMANT_CRYSTAL = 229,
  RUSTED_SWORD    = 230,
  RUSTED_SHIELD   = 231,
  GRACIDEA        = 232,
}
