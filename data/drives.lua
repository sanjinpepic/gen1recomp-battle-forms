-- Bag byte for each of Genesect's four Drives.
--
-- The same rule every indices table in this directory runs on: Gen 1 stores
-- items as byte ids, so an item with no index cannot exist in a save at all,
-- and changing an index silently turns every one already in a player's bag
-- into a different item.  These are permanent; new items append.
--
-- Unlike data/plates.lua and data/memories.lua, these get REAL bytes.  98-233
-- was full with no gap before this file (tests/battle_forms_keyitems_test.lua
-- pins the ceiling and the fact that 234-255 sat entirely unused), and four
-- items fit the 22 that leaves with eighteen to spare -- there was no shortage
-- here to force the byteless sentinel those two families needed.  Continues at
-- 234, immediately past data/heldforms.lua's 227-232 and Ultranecrozium Z's
-- 233 (data/ultracrystal.lua).
--
-- Sold at the Indigo Plateau lobby counter, behind the Plates and the
-- Memories: Genesect is a mythical on the same footing as the other endgame
-- species this mod already sells for at that counter rather than on the
-- Celadon stone floor.
return {
  DOUSE_DRIVE = 234,
  SHOCK_DRIVE = 235,
  BURN_DRIVE  = 236,
  CHILL_DRIVE = 237,
}
