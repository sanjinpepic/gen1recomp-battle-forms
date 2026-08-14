-- Bag byte for each Z-Crystal.
--
-- The same rule data/stones.lua, data/orbs.lua and data/keyitems.lua run on,
-- for the same reason: Gen 1 stores items as byte ids, so an item with no index
-- cannot exist in a save at all, and changing an index silently turns every
-- crystal already in a player's bag into a different item.  These are
-- permanent; new items append.
--
-- Four tables, ONE range.  A crystal is stamped onto a Pokemon the way a stone
-- and an orb are -- it goes through the same held-item field -- so it continues
-- where data/keyitems.lua stopped (196-198) rather than starting over.
-- tests/battle_forms_keyitems_test.lua pins that no two of the four tables ever
-- hand out the same byte.
--
-- Assigned in data/zmoves.lua's own row order, which is the type chart's, so
-- the two files read the same way and the shop shelf (src/shop.lua sorts by
-- index) stands them in that order too.
return {
  NORMALIUM_Z  = 200,
  FIGHTINIUM_Z = 201,
  FLYINIUM_Z   = 202,
  POISONIUM_Z  = 203,
  GROUNDIUM_Z  = 204,
  ROCKIUM_Z    = 205,
  BUGINIUM_Z   = 206,
  GHOSTIUM_Z   = 207,
  FIRIUM_Z     = 208,
  WATERIUM_Z   = 209,
  GRASSIUM_Z   = 210,
  ELECTRIUM_Z  = 211,
  PSYCHIUM_Z   = 212,
  ICIUM_Z      = 213,
  DRAGONIUM_Z  = 214,
  DARKINIUM_Z  = 215,
  STEELIUM_Z   = 216,
  FAIRIUM_Z    = 217,
}
