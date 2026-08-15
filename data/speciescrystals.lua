-- Bag byte for each species-specific Z-Crystal (data/speciesz.lua).
--
-- The same rule every indices table in this directory runs on: Gen 1 stores
-- items as byte ids, so an item with no index cannot exist in a save at all,
-- and changing an index silently turns every one already in a player's bag
-- into a different item.  These are permanent; a later item appends after
-- them.
--
-- Continues at 238, immediately past data/drives.lua's 234-237.  This is the
-- third family to reach the shared byte space's ceiling -- data/plates.lua's
-- header tells the first two apart, 98-233 packed solid and 234-255 the only
-- twenty-two bytes left before Genesect's four Drives took 234-237 -- and
-- unlike the Plates and the Memories, this family does NOT need the `false`
-- sentinel: data/speciesz.lua deliberately builds fourteen of the real
-- games' species Z-Moves rather than all of them (its own header says which
-- two were left out and why, on grounds that have nothing to do with bytes),
-- and fourteen fits the eighteen still free at 238-255 with four to spare.
-- That is not the byte ceiling being generous -- it is this family being
-- smaller than the Plates and Memories were, on its own terms, before the
-- ceiling ever became the question.
return {
  PIKASHUNIUM_Z    = 238,
  ALORAICHIUM_Z    = 239,
  SNORLIUM_Z       = 240,
  MEWNIUM_Z        = 241,
  DECIDIUM_Z       = 242,
  INCINIUM_Z       = 243,
  PRIMARIUM_Z      = 244,
  LYCANIUM_Z       = 245,
  MIMIKIUM_Z       = 246,
  KOMMONIUM_Z      = 247,
  SOLGANIUM_Z      = 248,
  LUNALIUM_Z       = 249,
  MARSHADIUM_Z     = 250,
  PIKANIUM_Z       = 251,
}
