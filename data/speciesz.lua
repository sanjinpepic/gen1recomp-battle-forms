-- The species-specific Z-Moves: fourteen crystals, each restricted to one
-- species (or a small family of forms of it) and each converting one named
-- base move rather than every damaging move of a type.
--
-- data/zmoves.lua's own header called these unbuildable -- "every one of
-- them keys off a base move Gen 1 does not have" -- and that was true when it
-- was written.  It is not true now: National Dex 0.15.0 registered all 833
-- modern moves, and VOLTTACKLE, THUNDERBOLT, GIGAIMPACT, PSYCHIC,
-- SPIRITSHACKLE, DARKESTLARIAT, SPARKLINGARIA, STONEEDGE, PLAYROUGH,
-- CLANGINGSCALES, SUNSTEELSTRIKE, MOONGEISTBEAM and SPECTRALTHIEF are all
-- among them, and every species below is a real record too.  The premise the
-- old refusal rested on no longer holds, which is the whole reason to check
-- data before repeating a refusal rather than trusting the last one.
--
-- WHAT IS STILL LEFT OUT, deliberately, and why each one is a different
-- shape from the twelve this file builds rather than merely more work:
--
-- * GUARDIAN OF ALOLA (the four Tapu, Tapunium Z, Nature's Madness) deals
--   3/4 of the TARGET's current HP rather than a fixed power -- the same
--   shape as Super Fang, not as a Z-Move.  Buildable in principle through the
--   same chooseDamage seam Super Fang already uses, but it is a genuinely
--   different code path from every other row here rather than one more of
--   the same shape, and is left for its own pass rather than folded in here.
-- * EXTREME EVOBOOST (Eevee, Eevium Z, Last Resort) replaces a 140-power
--   damage move with a pure six-stat boost and deals no damage at all --
--   the opposite shape from every other row here, not a stronger version of
--   it.  Left out for the same reason.
-- * 10,000,000 VOLT THUNDERBOLT is restricted, in the real games, to
--   Pikachu's eight cap forms rather than to an ordinary Pikachu.  National
--   Dex registers all eight (PIKACHU_ORIGINAL_CAP through PIKACHU_WORLD_CAP)
--   as real species records, so -- unlike Genesect's Drives -- this is not a
--   case of the data not describing something, and it IS included below,
--   gated on exactly those eight rather than loosened to cover every
--   Pikachu.
--
-- WHY A FIXED POWER AND NOT A LADDER.  Unlike the eighteen type Z-Moves,
-- which convert whichever damaging move of their type a Pokemon happens to
-- know, a species Z-Move is tied to ONE named move and the real games give
-- it one fixed power regardless of that move's own -- Volt Tackle is 120 and
-- Catastropika is 210, not a rung Volt Tackle's power buys.  `power` below is
-- that fixed number.
--
-- WHY `category` IS ABSENT, matching data/zmoves.lua and data/maxmoves.lua:
-- Gen 1 decides physical or special by TYPE, and Damage.categoryOf falls
-- through to the type record when a move does not say -- see those two
-- files' own headers.  The real games keep several of these moves in a fixed
-- category regardless of type (Stoked Sparksurfer is Special on an Electric
-- move that would otherwise split by type either way), but none of the
-- fourteen actually needs the override to come out right under this engine's
-- own rule, so the same simplification those two files already made is kept
-- here rather than inventing a third convention.
--
-- WHY EVERY ROW STILL CARRIES NO SECONDARY EFFECT.  Several of the real
-- moves do something extra on top of damage -- Stoked Sparksurfer always
-- paralyzes, Clangorous Soulblaze raises the user's own stats, Splintered
-- Stormshards clears both sides' screens.  data/zmoves.lua's eighteen never
-- modelled a Z-Move's secondary effect either, for the same reason repeated
-- here rather than a new one: there is no never-miss field on a move record,
-- so 100 accuracy is as close as this engine gets, and adding one move's
-- worth of bespoke effect here while every other Z-Move this mod ships stays
-- bare would be an inconsistency this data file does not want to own.
return {
  { crystal = "PIKASHUNIUM_Z", species = { "PIKACHU" }, move = "VOLTTACKLE",
    stem = "CATASTROPIKA", name = "CATASTROPIKA", menu = "CATASTROPIKA",
    power = 210 },
  { crystal = "ALORAICHIUM_Z", species = { "RAICHU_ALOLA" },
    move = "THUNDERBOLT", stem = "STOKEDSPARKSURFER",
    name = "STOKED SPARKSURFER", menu = "SPARKSURFER", power = 175 },
  { crystal = "SNORLIUM_Z", species = { "SNORLAX" }, move = "GIGAIMPACT",
    stem = "PULVERIZINGPANCAKE", name = "PULVERIZING PANCAKE",
    menu = "PANCAKE", power = 210 },
  { crystal = "MEWNIUM_Z", species = { "MEW" }, move = "PSYCHIC",
    stem = "GENESISSUPERNOVA", name = "GENESIS SUPERNOVA",
    menu = "SUPERNOVA", power = 185 },
  { crystal = "DECIDIUM_Z", species = { "DECIDUEYE" }, move = "SPIRITSHACKLE",
    stem = "SINISTERARROWRAID", name = "SINISTER ARROW RAID",
    menu = "ARROW RAID", power = 190 },
  { crystal = "INCINIUM_Z", species = { "INCINEROAR" }, move = "DARKESTLARIAT",
    stem = "MALICIOUSMOONSAULT", name = "MALICIOUS MOONSAULT",
    menu = "MOONSAULT", power = 180 },
  { crystal = "PRIMARIUM_Z", species = { "PRIMARINA" }, move = "SPARKLINGARIA",
    stem = "OCEANICOPERETTA", name = "OCEANIC OPERETTA",
    menu = "OPERETTA", power = 195 },
  -- Every forme Lycanroc has a species record of its own; one crystal covers
  -- all three the way the real games let any of them hold Lycanium Z.
  { crystal = "LYCANIUM_Z",
    species = { "LYCANROC", "LYCANROC_MIDNIGHT", "LYCANROC_DUSK" },
    move = "STONEEDGE", stem = "SPLINTEREDSTORMSHARDS",
    name = "SPLINTERED STORMSHARDS", menu = "STORMSHARDS", power = 190 },
  { crystal = "MIMIKIUM_Z", species = { "MIMIKYU" }, move = "PLAYROUGH",
    stem = "LETSSNUGGLEFOREVER", name = "LET'S SNUGGLE FOREVER",
    menu = "SNUGGLE", power = 190 },
  { crystal = "KOMMONIUM_Z", species = { "KOMMO_O" }, move = "CLANGINGSCALES",
    stem = "CLANGOROUSSOULBLAZE", name = "CLANGOROUS SOULBLAZE",
    menu = "SOULBLAZE", power = 185 },
  { crystal = "SOLGANIUM_Z", species = { "SOLGALEO" }, move = "SUNSTEELSTRIKE",
    stem = "SEARINGSUNRAZESMASH", name = "SEARING SUNRAZE SMASH",
    menu = "SUNRAZE", power = 200 },
  { crystal = "LUNALIUM_Z", species = { "LUNALA" }, move = "MOONGEISTBEAM",
    stem = "MENACINGMOONRAZEMAELSTROM", name = "MENACING MOONRAZE MAELSTROM",
    menu = "MOONRAZE", power = 200 },
  { crystal = "MARSHADIUM_Z", species = { "MARSHADOW" }, move = "SPECTRALTHIEF",
    stem = "SOULSTEALING7STARSTRIKE", name = "SOUL-STEALING 7-STAR STRIKE",
    menu = "STAR STRIKE", power = 195 },
  -- Restricted to Pikachu's eight cosmetic cap forms, matching the real
  -- games -- Pikanium Z does nothing for an ordinary Pikachu, which already
  -- has Pikashunium Z as its own species crystal.
  { crystal = "PIKANIUM_Z",
    species = { "PIKACHU_ORIGINAL_CAP", "PIKACHU_HOENN_CAP",
                "PIKACHU_SINNOH_CAP", "PIKACHU_UNOVA_CAP",
                "PIKACHU_KALOS_CAP", "PIKACHU_ALOLA_CAP",
                "PIKACHU_PARTNER_CAP", "PIKACHU_WORLD_CAP" },
    move = "THUNDERBOLT", stem = "TENMILLIONVOLTTHUNDERBOLT",
    name = "10,000,000 VOLT THUNDERBOLT", menu = "10M VOLT", power = 195 },
}
