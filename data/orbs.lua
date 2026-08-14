-- Bag byte for each orb.
--
-- The same rule data/stones.lua runs on, for the same reason: Gen 1 stores
-- items as byte ids, so an item with no index cannot exist in a save at all,
-- and changing an index silently turns every orb already in a player's bag
-- into a different item.  These are permanent; new items append.
--
-- Two tables, ONE range.  The orbs are a different item family from the mega
-- stones and belong to a different transformation type, but they share the
-- bag with them, so they continue where data/stones.lua stopped (98-193)
-- rather than starting over.  tests/battle_forms_primal_test.lua pins that
-- the two tables never hand out the same byte.
return {
  RED_ORB  = 194,
  BLUE_ORB = 195,
}
