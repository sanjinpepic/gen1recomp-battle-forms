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
-- (17 Memories) are the two item-driven families this table does NOT wire:
-- both have real held-item mechanics and real National Dex records for every
-- type, but neither has a single entry in dev/data/sprites/generated/formart.lua
-- -- not even a base-species one -- so wiring either would show every one of
-- eighteen forms as the plain species with nothing to tell them apart.
-- Genesect's four Drives are not wired for a different reason: no
-- GENESECT_DOUSE/SHOCK/BURN/CHILL record exists in national.lua at all, so
-- there is no form id a pairing here could even name.
--
-- Every wired form has front AND back art under [BASE].forms.[SUFFIX]; the
-- art suite fails if that ever stops being true.  A form with only a front
-- picture is invisible on the player's own side of the battle, which is worse
-- here than anywhere else in this mod -- a battle form a player cannot see
-- lasts one fight, and this one lasts until they change it back.
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
}
