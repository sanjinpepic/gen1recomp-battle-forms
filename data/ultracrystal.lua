-- Bag byte for Ultranecrozium Z.
--
-- The same rule every indices table in this directory runs on, for the same
-- reason: Gen 1 stores items as byte ids, so an item with no index cannot
-- exist in a save at all, and changing the index silently turns every one
-- already in a player's bag into a different item.  This is permanent; a
-- later item appends after it.
--
-- Continues at 233 where data/heldforms.lua stopped (227-232).  Not folded
-- into data/crystals.lua's eighteen: those are species-agnostic and
-- registered through src/zmoves.lua's per-type catalog and src/stone.lua's
-- UNPAIRED install, where this one pairs with exactly one species through
-- data/ultraburst.lua and src/stone.lua's PAIRED install instead -- the same
-- path a mega stone takes, which is also what refuses it on anything that is
-- not a Necrozma.  Sold on the same Celadon shelf as the eighteen anyway
-- (src/shop.lua), because a player looking for a Z-Crystal should find all
-- nineteen in the one place.  tests/battle_forms_keyitems_test.lua pins that
-- no two of the eight tables ever hand out the same byte.
return {
  ULTRANECROZIUM_Z = 233,
}
