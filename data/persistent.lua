-- species id -> item id -> National Dex form id, for the forms that OUTLIVE
-- the battle.
--
-- The same shape as data/megas.lua and data/primals.lua and read by the same
-- lookup, and a SEPARATE table for the reason theirs are separate: which table
-- a caller hands to eligibility.formForMon is what says which transformation
-- type it is asking about.  Nothing that decides whether a mega may happen ever
-- sees this table, and nothing here ever sees theirs.
--
-- What makes this one different is not its shape but what src/resolve.lua's
-- party sweep does with a mon it names.  Every other table here describes a
-- form the sweep takes off; this one describes the form the sweep puts BACK.
-- That is the whole of the difference, and src/persistent.lua is where it
-- lives.
--
-- The form id MUST be the National Dex record's KEY -- what data.pokemon[...]
-- is indexed by (e.g. ROTOM_WASH) -- and never the record's `name` field
-- (e.g. "rotom-wash").  Those look interchangeable and are not: a `name` value
-- here compiles fine and passes review, and then every lookup in
-- Forms.becomeForm misses silently.  That exact mistake shipped in 0.2.1;
-- tests/battle_forms_formids_test.lua is why it cannot ship again.
--
-- Every species here is gated on a held item ALONE, the way the pairing table
-- itself can express and nothing more.  That is exactly right for Giratina --
-- Origin Forme is the Griseous Orb and nothing else, no location and no time
-- of day sits in front of it -- and a deliberate simplification for Shaymin,
-- whose Sky Forme in the real games also wants daytime.  This game has no
-- time-of-day system for any mechanic to read (Gen 1 never had one), so
-- Shaymin is wired on the Gracidea alone rather than left out: every other
-- item-gated mechanic in this mod already takes the same kind of liberty to
-- fit a Gen 1 engine (Rotom's appliances are bag items used on a Pokemon
-- rather than overworld furniture; a mega's "trainer capability" is a Key
-- Stone rather than a bracelet), and a Sky Forme reachable by item alone is
-- closer to what the real games do than a Sky Forme not reachable at all.
--
-- Palkia and Dialga carry Legends: Arceus items that boost stats without
-- changing species in THAT game -- Origin Forme there is a fixed capture, not
-- a toggle -- but the National Dex data models ORIGIN as a form of the base
-- species with its own record and its own art, the same shape Giratina's is,
-- so it is wired the same way: the item that names the Pokemon in the
-- collective imagination is the item that triggers the form here, exactly as
-- the Griseous Orb does for Giratina.  Zacian and Zamazenta are the plainest
-- of the six -- Crowned Forme in the real games IS a held-item toggle, no
-- caveat needed.
--
-- Rotom is still the one that proves the mechanism rather than being a special
-- case of it, because it has five forms and a base to come back to where every
-- other row here has one form and a toggle.  Arceus (17 Plates) and Silvally
-- (17 Memories) are the two largest families of all, wired the same way as
-- everything above once the form-art index actually carried their art -- see
-- data/plates.lua and data/memories.lua for the one thing that IS different
-- about them: neither family's items carry a bag byte, because the shared
-- single-byte item space ran out 12 items short of the 34 the two families
-- need between them.
--
-- Genesect's four Drives are the smallest row here and the only purely
-- cosmetic one.  National Dex's GENESECT_DOUSE/SHOCK/BURN/CHILL records exist
-- now but differ from base Genesect in nothing this engine can hold -- not
-- even typing, since a Drive changes only Techno Blast's own type in the real
-- games, a per-move property no form record here can express -- so using one
-- changes a Genesect's appearance and nothing it can do in battle.  Wired
-- exactly like every other row above regardless: the derivation, the sweep
-- and the undo do not ask whether a form carries a stat difference, only
-- whether a pairing and its art exist.
--
-- Every wired form has front AND back art under [BASE].forms.[SUFFIX]; the
-- art suite fails if that ever stops being true.  A form with only a front
-- picture is invisible on the player's own side of the battle, which is worse
-- here than anywhere else in this mod -- a battle form a player cannot see
-- lasts one fight, and this one lasts until they change it back.
--
-- Neither Arceus nor Silvally wires a NORMAL/base row: the base Pokemon holds
-- no Plate and no Memory in the real games either, National Dex registers no
-- ARCEUS_NORMAL or SILVALLY_NORMAL record to point one at, and the seventeen
-- types below are already the whole of what a Plate or a Memory changes a
-- Pokemon into.  Genesect wires no base row for the same reason: a plain
-- Genesect holds no Drive.
return {
  ROTOM = {
    MICROWAVE_OVEN  = "ROTOM_HEAT",
    WASHING_MACHINE = "ROTOM_WASH",
    REFRIGERATOR    = "ROTOM_FROST",
    ELECTRIC_FAN    = "ROTOM_FAN",
    LAWN_MOWER      = "ROTOM_MOW",
  },
  GIRATINA = {
    GRISEOUS_ORB = "GIRATINA_ORIGIN",
  },
  PALKIA = {
    LUSTROUS_GLOBE = "PALKIA_ORIGIN",
  },
  DIALGA = {
    ADAMANT_CRYSTAL = "DIALGA_ORIGIN",
  },
  ZACIAN = {
    RUSTED_SWORD = "ZACIAN_CROWNED",
  },
  ZAMAZENTA = {
    RUSTED_SHIELD = "ZAMAZENTA_CROWNED",
  },
  SHAYMIN = {
    GRACIDEA = "SHAYMIN_SKY",
  },
  ARCEUS = {
    FIST_PLATE   = "ARCEUS_FIGHTING",
    SKY_PLATE    = "ARCEUS_FLYING",
    TOXIC_PLATE  = "ARCEUS_POISON",
    EARTH_PLATE  = "ARCEUS_GROUND",
    STONE_PLATE  = "ARCEUS_ROCK",
    INSECT_PLATE = "ARCEUS_BUG",
    SPOOKY_PLATE = "ARCEUS_GHOST",
    IRON_PLATE   = "ARCEUS_STEEL",
    FLAME_PLATE  = "ARCEUS_FIRE",
    SPLASH_PLATE = "ARCEUS_WATER",
    MEADOW_PLATE = "ARCEUS_GRASS",
    ZAP_PLATE    = "ARCEUS_ELECTRIC",
    MIND_PLATE   = "ARCEUS_PSYCHIC",
    ICICLE_PLATE = "ARCEUS_ICE",
    DRACO_PLATE  = "ARCEUS_DRAGON",
    DREAD_PLATE  = "ARCEUS_DARK",
    PIXIE_PLATE  = "ARCEUS_FAIRY",
  },
  SILVALLY = {
    FIGHTING_MEMORY = "SILVALLY_FIGHTING",
    FLYING_MEMORY   = "SILVALLY_FLYING",
    POISON_MEMORY   = "SILVALLY_POISON",
    GROUND_MEMORY   = "SILVALLY_GROUND",
    ROCK_MEMORY     = "SILVALLY_ROCK",
    BUG_MEMORY      = "SILVALLY_BUG",
    GHOST_MEMORY    = "SILVALLY_GHOST",
    STEEL_MEMORY    = "SILVALLY_STEEL",
    FIRE_MEMORY     = "SILVALLY_FIRE",
    WATER_MEMORY    = "SILVALLY_WATER",
    GRASS_MEMORY    = "SILVALLY_GRASS",
    ELECTRIC_MEMORY = "SILVALLY_ELECTRIC",
    PSYCHIC_MEMORY  = "SILVALLY_PSYCHIC",
    ICE_MEMORY      = "SILVALLY_ICE",
    DRAGON_MEMORY   = "SILVALLY_DRAGON",
    DARK_MEMORY     = "SILVALLY_DARK",
    FAIRY_MEMORY    = "SILVALLY_FAIRY",
  },
  GENESECT = {
    DOUSE_DRIVE = "GENESECT_DOUSE",
    SHOCK_DRIVE = "GENESECT_SHOCK",
    BURN_DRIVE  = "GENESECT_BURN",
    CHILL_DRIVE = "GENESECT_CHILL",
  },
}
