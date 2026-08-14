-- Bag byte for each trainer key item.
--
-- The same rule data/stones.lua and data/orbs.lua run on, for the same
-- reason: Gen 1 stores items as byte ids, so an item with no index cannot
-- exist in a save at all, and changing an index silently turns every key item
-- already in a player's bag into a different item.  These are permanent; new
-- items append.
--
-- Four tables, ONE range.  These are neither stones, orbs nor crystals --
-- nothing is stamped with them and no Pokemon carries one -- but they share the
-- bag with all three, so they continue where data/orbs.lua stopped (194-195)
-- rather than starting over, and data/crystals.lua continues from here.
-- tests/battle_forms_keyitems_test.lua pins that no two of the four tables ever
-- hand out the same byte.
--
-- Order here is also shelf order (src/shop.lua sorts by index), so the four
-- stand at the counter in the order their mechanics were added.
return {
  KEY_STONE    = 196,
  DYNAMAX_BAND = 197,
  TERA_ORB     = 198,
  Z_RING       = 199,
}
