-- Bag byte for each of Arceus's seventeen Plates -- except there is none, for
-- every one of them, and that is the point of this file rather than an
-- omission from it.
--
-- The same rule every indices table in this directory runs on: Gen 1 stores
-- items as byte ids, one byte, 0-255.  tests/battle_forms_keyitems_test.lua
-- pins the ceiling directly (`index <= 255`), and a full sweep of every
-- indices table in this directory (stones, orbs, key items, crystals,
-- appliances, fusers, held forms, Ultranecrozium Z) finds 98-233 filled with
-- no gap at all -- 136 bytes, none spare -- which leaves 234-255, 22 bytes,
-- for whatever comes next.  Seventeen Plates and seventeen Memories
-- (data/memories.lua) are 34 items.  22 is not enough for 34, and nothing
-- here can be renumbered to make room: every earlier table is permanent, the
-- same rule this file is under.
--
-- Splitting the shortfall -- 22 Plates with real bytes, the other 12 without
-- -- was considered and rejected. There is no principled reason a Water Plate
-- would keep a cartridge-exportable byte where a Bug Plate does not; an
-- arbitrary cut would read as a bug report waiting to happen rather than a
-- decision.  So every entry below is `false`, a value src/persistent.lua's
-- install() reads as "deliberately has no byte" and registers anyway, rather
-- than the missing-entry case, which is still a hard error -- a row present
-- in data/persistent.lua with no matching key here, `false` or otherwise, is
-- still a mistake and still refused loudly.
--
-- What `false` costs: none of the seventeen survives a Game Boy .sav export
-- (src/save_convert/GenSave.lua's crosswalk only ever indexes a numeric
-- `def.index`, and a byte beyond 255 would not fail loudly -- it would wrap
-- through `bit.band(v, 0xFF)` and silently collide with whatever real item
-- already owns the wrapped byte, which is worse than losing the item outright
-- -- so nothing here is ever given a number past 255, real or invented).  A
-- Plate exported to a cartridge is dropped from the bag the same way an
-- unrecognised item already is; an Arceus wearing one keeps its form on this
-- engine's own save regardless, because that marker is derived from the
-- stamp and the stamp is a plain string field, not a byte -- see
-- src/persistent.lua's own header for why the marker needs no byte at all.
-- What it does NOT cost: every Plate still buys, still stamps, still shows
-- its form in battle, on the party screen and after a reload, on every save
-- this mod was ever going to support natively.
return {
  FIST_PLATE   = false, -- ARCEUS_FIGHTING
  SKY_PLATE    = false, -- ARCEUS_FLYING
  TOXIC_PLATE  = false, -- ARCEUS_POISON
  EARTH_PLATE  = false, -- ARCEUS_GROUND
  STONE_PLATE  = false, -- ARCEUS_ROCK
  INSECT_PLATE = false, -- ARCEUS_BUG
  SPOOKY_PLATE = false, -- ARCEUS_GHOST
  IRON_PLATE   = false, -- ARCEUS_STEEL
  FLAME_PLATE  = false, -- ARCEUS_FIRE
  SPLASH_PLATE = false, -- ARCEUS_WATER
  MEADOW_PLATE = false, -- ARCEUS_GRASS
  ZAP_PLATE    = false, -- ARCEUS_ELECTRIC
  MIND_PLATE   = false, -- ARCEUS_PSYCHIC
  ICICLE_PLATE = false, -- ARCEUS_ICE
  DRACO_PLATE  = false, -- ARCEUS_DRAGON
  DREAD_PLATE  = false, -- ARCEUS_DARK
  PIXIE_PLATE  = false, -- ARCEUS_FAIRY
}
