-- Bag byte for each appliance.
--
-- The same rule data/stones.lua, data/orbs.lua, data/keyitems.lua and
-- data/crystals.lua run on, for the same reason: Gen 1 stores items as byte
-- ids, so an item with no index cannot exist in a save at all, and changing an
-- index silently turns every appliance already in a player's bag into a
-- different item.  These are permanent; new items append.
--
-- Five tables, ONE range.  An appliance is stamped onto a Pokemon the way a
-- stone, an orb and a crystal are -- it goes through the same held-item field
-- -- so it continues where data/crystals.lua stopped (200-217) rather than
-- starting over.  tests/battle_forms_keyitems_test.lua pins that no two of the
-- five tables ever hand out the same byte.
--
-- Order here is also shelf order (src/shop.lua sorts by index), and it is the
-- order data/persistent.lua's forms run in the National Dex data rather than
-- anything about the appliances themselves.
return {
  MICROWAVE_OVEN  = 218,
  WASHING_MACHINE = 219,
  REFRIGERATOR    = 220,
  ELECTRIC_FAN    = 221,
  LAWN_MOWER      = 222,
}
