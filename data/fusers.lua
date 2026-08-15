-- Bag byte for each fusion item.
--
-- The same rule data/stones.lua, data/orbs.lua, data/keyitems.lua,
-- data/crystals.lua and data/appliances.lua run on, for the same reason: Gen 1
-- stores items as byte ids, so an item with no index cannot exist in a save at
-- all, and changing an index silently turns every one already in a player's bag
-- into a different item.  These are permanent; new items append.
--
-- Continues at 223 where data/appliances.lua stopped (218-222).  Unlike every
-- table before it these items are NOT stamped onto the Pokemon -- a fusion is
-- recorded by the partner's species, not by the item that made it, see
-- src/fusion.lua -- so this range shares nothing but the bag with the others.
-- tests/battle_forms_keyitems_test.lua pins that no two of the six tables ever
-- hand out the same byte.
--
-- Order here is also shelf order (src/shop.lua sorts by index): the two Kyurem
-- forms, then Necrozma's two, then Calyrex's, which is the order the families
-- run in data/fusion.lua.
return {
  DNA_SPLICERS   = 223,
  N_SOLARIZER    = 224,
  N_LUNARIZER    = 225,
  REINS_OF_UNITY = 226,
}
