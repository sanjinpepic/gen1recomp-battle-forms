-- species -> the G-Max Move that species' Dynamax converts one type of its
-- moveset into, in place of that type's ordinary Max Move.
--
-- The seventh pairing table, and the second keyed on a SPECIES rather than a
-- type -- src/speciesz.lua's own header explains the shape this follows:
-- "does this crystal's SPECIES match the Pokemon" rather than "does this
-- crystal's TYPE match any damaging move in the set". A G-Max Move asks a
-- narrower question again -- does the Pokemon's SPECIES have one of these AND
-- does the move being replaced share its ONE type -- which is why this is a
-- third catalog for the Max Move substitution src/maxmoves.lua's eighteen
-- type rows already own, checked first and falling back to them, rather than
-- a branch inside that file.
--
-- ONE ROW PER SPECIES on purpose, unlike data/speciesz.lua's fourteen rows:
-- a species Z-Crystal converts one NAMED move, but a G-Max Move converts
-- every damaging move of its type the way an ordinary Max Move does -- the
-- real games give a Gigantamax Charizard's Ember AND Flamethrower both
-- G-MAX WILDFIRE, not just one of them.
--
-- WHERE THIS DATA COMES FROM. `type` and `power` (where a row carries one) are
-- public, known facts about the real games -- the same class of fact
-- data/gigantamax.lua's own species -> form pairing already is -- transcribed
-- rather than invented. Every row but three shares the identical seven-rung
-- ladder src/maxmoves.lua's own M.powerFor already computes for an ordinary
-- Max Move of the same type (Fighting and Poison's own lower rungs included,
-- which is why Machamp's and Garbodor's rows read off that ladder's lowered
-- column exactly as MAX KNUCKLE and MAX OOZE already do) -- so
-- src/gmaxmoves.lua reads that function live rather than this file carrying a
-- second copy of the same seven numbers to drift out of step with the first.
--
-- WHAT THIS DATA DOES NOT CARRY, and why the omission is not an oversight.
-- Every G-Max Move but three does something beyond damage in the real games
-- -- Wildfire, Cannonade and Vine Lash burn the field for four turns,
-- Volcalith does the same with rockfall, Stonesurge and Steelsurge lay entry
-- hazards, Depletion drains two PP, and the rest inflict a field-wide status
-- or a stat drop. None of that is buildable: Gen 1 predates weather outright
-- and has no residual-damage, field-effect, PP-draining or multi-turn-effect
-- primitive in MoveEffects for any of it to be built from -- not merely
-- unwired, genuinely absent from the primitive set this engine offers a mod.
-- So every row below is a plain damaging move at its real type and real
-- power and asks for nothing else, the same honesty
-- data/maxmoves.lua already keeps for the eighteen ordinary Max Moves.
--
-- THE THREE EXCEPTIONS, which carry a fixed `power` because the real games
-- give them one regardless of the move they replace: G-MAX FIREBALL
-- (Cinderace), G-MAX DRUM SOLO (Rillaboom) and G-MAX HYDROSNIPE (Inteleon)
-- are all fixed at 160 and their entire effect past damage, in the real
-- games, is ignoring an Ability that would otherwise affect the hit's type
-- or power -- the identical shape Sunsteel Strike and Moongeist Beam were
-- given in 0.36.0, where the effect stayed unmodelled everywhere else this
-- codebase reaches for it. This engine has no abilities at all, so there is
-- nothing an "ignores the target's Ability" clause could still be doing --
-- these three are the ones G-Max Move here that are the COMPLETE truth of
-- the real move rather than a stub of it.
--
-- WHAT IS LEFT OUT ENTIRELY. The three Gigantamax forms data/gigantamax.lua
-- itself leaves unwired -- Corviknight (half its art is missing) and the Low
-- Key and Rapid Strike variants of Toxtricity and Urshifu (their art indexes
-- under the base species, not the variant) -- have no row here either, for
-- the same reason a G-Max Move for a form nothing can show has nothing to
-- attach to: G-MAX WIND RAGE (Corviknight) and G-MAX RAPID FLOW (Urshifu
-- Rapid Strike) are real moves in the real games and are not modelled here.
-- tests/battle_forms_gmaxmoves_test.lua checks this file's roster against
-- data/gigantamax.lua's own so the two cannot quietly drift apart.
--
-- THE NAME-LENGTH TRAP. A Gen 1 move name is twelve columns wide and the
-- FIGHT menu is built for it -- see data/zmoves.lua's own header for the
-- 13-column classic / 12-column widescreen budget this exists to keep every
-- shipped name inside. "G-MAX WILDFIRE" is fourteen, and every other row's
-- real name is at least that long, so `menu` carries the short FIGHT-menu
-- display the same DISPLAY-ONLY split data/zmoves.lua's own `menu` field
-- keeps: `name` below is still what src/gmaxmoves.lua's M.install registers
-- and what a save, the battle text row and Mimic all see.
return {
  -- Registration order, so the shelf of registered records is the same from
  -- one run to the next -- a keyed table reorders between runs.
  { species = "ALCREMIE",    stem = "GMAXFINALE",     type = "FAIRY",
    name = "G-MAX FINALE",     menu = "G-MAX FINALE" },
  { species = "APPLETUN",    stem = "GMAXSWEETNESS",  type = "GRASS",
    name = "G-MAX SWEETNESS",  menu = "SWEETNESS" },
  { species = "BLASTOISE",   stem = "GMAXCANNONADE",  type = "WATER",
    name = "G-MAX CANNONADE",  menu = "CANNONADE" },
  { species = "BUTTERFREE",  stem = "GMAXBEFUDDLE",   type = "BUG",
    name = "G-MAX BEFUDDLE",   menu = "BEFUDDLE" },
  { species = "CENTISKORCH", stem = "GMAXCENTIFERNO", type = "FIRE",
    name = "G-MAX CENTIFERNO", menu = "CENTIFERNO" },
  { species = "CHARIZARD",   stem = "GMAXWILDFIRE",   type = "FIRE",
    name = "G-MAX WILDFIRE",   menu = "WILDFIRE" },
  -- Fixed at 160, whatever power the Fire move it replaces carries -- see
  -- this file's own header for why that is this row's whole real effect
  -- rather than a stub of a bigger one.
  { species = "CINDERACE",   stem = "GMAXFIREBALL",   type = "FIRE",
    name = "G-MAX FIREBALL",   menu = "FIREBALL", power = 160 },
  { species = "COALOSSAL",   stem = "GMAXVOLCALITH",  type = "ROCK",
    name = "G-MAX VOLCALITH",  menu = "VOLCALITH" },
  { species = "COPPERAJAH",  stem = "GMAXSTEELSURGE", type = "STEEL",
    name = "G-MAX STEELSURGE", menu = "STEELSURGE" },
  { species = "DREDNAW",     stem = "GMAXSTONESURGE", type = "WATER",
    name = "G-MAX STONESURGE", menu = "STONESURGE" },
  { species = "DURALUDON",   stem = "GMAXDEPLETION",  type = "DRAGON",
    name = "G-MAX DEPLETION",  menu = "DEPLETION" },
  { species = "EEVEE",       stem = "GMAXCUDDLE",     type = "NORMAL",
    name = "G-MAX CUDDLE",     menu = "G-MAX CUDDLE" },
  { species = "FLAPPLE",     stem = "GMAXTARTNESS",   type = "GRASS",
    name = "G-MAX TARTNESS",   menu = "TARTNESS" },
  { species = "GARBODOR",    stem = "GMAXMALODOR",    type = "POISON",
    name = "G-MAX MALODOR",    menu = "MALODOR" },
  { species = "GENGAR",      stem = "GMAXTERROR",     type = "GHOST",
    name = "G-MAX TERROR",     menu = "G-MAX TERROR" },
  { species = "GRIMMSNARL",  stem = "GMAXSNOOZE",     type = "DARK",
    name = "G-MAX SNOOZE",     menu = "G-MAX SNOOZE" },
  { species = "HATTERENE",   stem = "GMAXSMITE",      type = "FAIRY",
    name = "G-MAX SMITE",      menu = "G-MAX SMITE" },
  -- Fixed at 160, same shape as Cinderace's row above.
  { species = "INTELEON",    stem = "GMAXHYDROSNIPE", type = "WATER",
    name = "G-MAX HYDROSNIPE", menu = "HYDROSNIPE", power = 160 },
  { species = "KINGLER",     stem = "GMAXFOAMBURST",  type = "WATER",
    name = "G-MAX FOAM BURST", menu = "FOAM BURST" },
  { species = "LAPRAS",      stem = "GMAXRESONANCE",  type = "ICE",
    name = "G-MAX RESONANCE",  menu = "RESONANCE" },
  { species = "MACHAMP",     stem = "GMAXCHISTRIKE",  type = "FIGHTING",
    name = "G-MAX CHI STRIKE", menu = "CHI STRIKE" },
  { species = "MELMETAL",    stem = "GMAXMELTDOWN",   type = "STEEL",
    name = "G-MAX MELTDOWN",   menu = "MELTDOWN" },
  { species = "MEOWTH",      stem = "GMAXGOLDRUSH",   type = "NORMAL",
    name = "G-MAX GOLD RUSH",  menu = "GOLD RUSH" },
  -- The engine's id for the type is PSYCHIC_TYPE and its name is PSYCHIC;
  -- data/maxmoves.lua, data/zmoves.lua and src/tera.lua carry the same
  -- exception.
  { species = "ORBEETLE",    stem = "GMAXGRAVITAS",   type = "PSYCHIC_TYPE",
    name = "G-MAX GRAVITAS",   menu = "GRAVITAS" },
  { species = "PIKACHU",     stem = "GMAXVOLTCRASH",  type = "ELECTRIC",
    name = "G-MAX VOLT CRASH", menu = "VOLT CRASH" },
  -- Fixed at 160, same shape as Cinderace's and Inteleon's rows above.
  { species = "RILLABOOM",   stem = "GMAXDRUMSOLO",   type = "GRASS",
    name = "G-MAX DRUM SOLO",  menu = "DRUM SOLO", power = 160 },
  { species = "SANDACONDA",  stem = "GMAXSANDBLAST",  type = "GROUND",
    name = "G-MAX SANDBLAST",  menu = "SANDBLAST" },
  { species = "SNORLAX",     stem = "GMAXREPLENISH",  type = "NORMAL",
    name = "G-MAX REPLENISH",  menu = "REPLENISH" },
  -- The default (Amped) form's own key, matching data/gigantamax.lua: Low
  -- Key Toxtricity is a separate species record and is not wired here or
  -- there.
  { species = "TOXTRICITY",  stem = "GMAXSTUNSHOCK",  type = "ELECTRIC",
    name = "G-MAX STUN SHOCK", menu = "STUN SHOCK" },
  -- Single Strike's own key, matching data/gigantamax.lua: Rapid Strike
  -- Urshifu is a separate species record, its own G-MAX RAPID FLOW (Water)
  -- is a different move entirely, and neither is wired here or there.
  { species = "URSHIFU",     stem = "GMAXONEBLOW",    type = "DARK",
    name = "G-MAX ONE BLOW",   menu = "ONE BLOW" },
  { species = "VENUSAUR",    stem = "GMAXVINELASH",   type = "GRASS",
    name = "G-MAX VINE LASH",  menu = "VINE LASH" },
}
