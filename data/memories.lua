-- Bag byte for each of Silvally's seventeen Memories -- except there is
-- none, for every one of them.  data/plates.lua's header carries the full
-- reasoning (the byte space is 0-255, 98-233 is already full with no gap,
-- 234-255 is 22 bytes and Plates plus Memories are 34, and a partial split
-- between the two families would be an arbitrary line with no story behind
-- it); this file is the second half of the same decision, not a separate one.
--
-- Every entry below is `false`: registered by src/persistent.lua's install()
-- as an item with no permanent bag byte, so it does not survive a Game Boy
-- .sav export (silently dropped, the same way an unrecognised item already
-- is) but buys, stamps and derives its form on every save this mod supports
-- natively exactly like any other held-item form.
return {
  FIGHTING_MEMORY = false, -- SILVALLY_FIGHTING
  FLYING_MEMORY   = false, -- SILVALLY_FLYING
  POISON_MEMORY   = false, -- SILVALLY_POISON
  GROUND_MEMORY   = false, -- SILVALLY_GROUND
  ROCK_MEMORY     = false, -- SILVALLY_ROCK
  BUG_MEMORY      = false, -- SILVALLY_BUG
  GHOST_MEMORY    = false, -- SILVALLY_GHOST
  STEEL_MEMORY    = false, -- SILVALLY_STEEL
  FIRE_MEMORY     = false, -- SILVALLY_FIRE
  WATER_MEMORY    = false, -- SILVALLY_WATER
  GRASS_MEMORY    = false, -- SILVALLY_GRASS
  ELECTRIC_MEMORY = false, -- SILVALLY_ELECTRIC
  PSYCHIC_MEMORY  = false, -- SILVALLY_PSYCHIC
  ICE_MEMORY      = false, -- SILVALLY_ICE
  DRAGON_MEMORY   = false, -- SILVALLY_DRAGON
  DARK_MEMORY     = false, -- SILVALLY_DARK
  FAIRY_MEMORY    = false, -- SILVALLY_FAIRY
}
