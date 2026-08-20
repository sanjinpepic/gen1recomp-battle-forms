-- Bag byte for each stone.
--
-- Gen 1 stores items as byte ids, so a record with no index cannot exist in a
-- save at all -- it will not survive a save/load and no save editor can see
-- it.  Vanilla occupies 1-97 with no gaps; 98 up is free.
--
-- THAT LAST SENTENCE IS ABOUT RED, AND EVERY NUMBER IN THIS DIRECTORY WAS
-- CHOSEN BY IT.  Gold ships 250 items filling 1-250, leaving 251-255 and
-- nothing else.  This directory's own tables fill 98-233, so on Gold 140 of
-- the 141 bytes declared across all of them name an item Gold already has --
-- 98 is BLACKBELT_I, 101 PNK_APRICORN, 102 BLACKGLASSES, 196-199 the four TMs
-- a gym leader hands out.  Only data/tm171.lua's 252 escapes it.
--
-- Registering an item on an occupied byte does not replace Gold's item, it
-- puts a second record on the same number, and Gold picks between them by
-- scanning every registered item for a matching `index` (`itemByIndex` in
-- game/src/world/gen2/World.lua, behind gym prizes, item balls, NPC gifts and
-- tree pickups alike).  `pairs` has no defined order, so the winner was
-- decided per lookup: beating a gym could hand out a Key Stone instead of the
-- TM, an apricorn tree a Blastoisinite, intermittently.
--
-- So the bytes below are registered ON GEN 1 ONLY.  src/stone.lua,
-- src/keyitems.lua, src/persistent.lua and src/fusion.lua each pass
-- `(not gen2) and index or nil`, and a record carrying no byte matches nothing
-- that scan can ask for -- which makes the substitution impossible rather than
-- merely unlikely.  Moving the numbers instead was never available: five free
-- bytes, 136 needed.  It is also the treatment data/plates.lua already argued
-- for and the Plates and Memories already ship with on both games.
--
-- Nothing in an existing save moves, because nothing in a save is keyed by
-- byte: save.inventory, the mart shelves and SaveData's own scrub all work on
-- item ids (game/src/inventory/Bag.lua's `inv[id]`).  The one cost is that
-- these items cannot cross a Game Boy .sav export on Gold, since
-- src/save_convert/GenSave.lua builds its crosswalk from `index` alone.
--
-- The numbers below therefore stay exactly as they are.  They are still live
-- on Red, and they are still permanent for the reason the next paragraph
-- gives.
--
-- These are permanent.  Changing one silently turns every stone already in a
-- player's bag into a different item, so new stones append and nothing here
-- is ever renumbered.  98-103 were assigned before this table existed in its
-- current form; 104 upward were assigned in the same alphabetical-by-species
-- order megas.lua now lists them in, so the two files read the same way even
-- though nothing requires the numbers themselves to run in that order.
return {
  ABOMASITE             = 104,
  ABSOLITE              = 105,
  ABSOLITE_Z            = 106,
  AERODACTYLITE         = 107,
  AGGRONITE             = 108,
  ALAKAZITE             = 102,
  ALTARIANITE           = 109,
  AMPHAROSITE           = 110,
  AUDINITE              = 111,
  BANETTITE             = 112,
  BARBARACLITE          = 113,
  BAXCALIBURITE         = 114,
  BEEDRILLITE           = 115,
  BLASTOISINITE         = 101,
  BLAZIKENITE           = 116,
  CAMERUPTITE           = 117,
  CHANDELURITE          = 118,
  CHARIZARDITE_X        = 99,
  CHARIZARDITE_Y        = 100,
  CHESNAUGHTITE         = 119,
  CHIMECHOITE           = 120,
  CLEFABLITE            = 121,
  CRABOMINABLITE        = 122,
  DARKRAIITE            = 123,
  DELPHOXITE            = 124,
  DIANCITE              = 125,
  DRAGALGITE            = 126,
  DRAGONITITE           = 127,
  DRAMPAITE             = 128,
  EELEKTROSSITE         = 129,
  EMBOARITE             = 130,
  EXCADRILLITE          = 131,
  FALINKSITE            = 132,
  FERALIGATRITE         = 133,
  FLOETTITE             = 134,
  FROSLASSITE           = 135,
  GALLADITE             = 136,
  GARCHOMPITE           = 137,
  GARCHOMPITE_Z         = 138,
  GARDEVOIRITE          = 139,
  GENGARITE             = 103,
  GLALITITE             = 140,
  GLIMMORAITE           = 141,
  GOLISOPODITE          = 142,
  GOLURKITE             = 143,
  GRENINJAITE           = 144,
  GYARADOSITE           = 145,
  HAWLUCHAITE           = 146,
  HEATRANITE            = 147,
  HERACRONITE           = 148,
  HOUNDOOMINITE         = 149,
  KANGASKHANITE         = 150,
  LATIASITE             = 151,
  LATIOSITE             = 152,
  LOPUNNITE             = 153,
  LUCARIONITE           = 154,
  LUCARIOITE_Z          = 155,
  MAGEARNAITE           = 156,
  MAGEARNAITE_ORIGINAL  = 157,
  MALAMARITE            = 158,
  MANECTITE             = 159,
  MAWILITE              = 160,
  MEDICHAMITE           = 161,
  MEGANIUMITE           = 162,
  MEOWSTICITE_MALE      = 163,
  METAGROSSITE          = 164,
  MEWTWONITE_X          = 165,
  MEWTWONITE_Y          = 166,
  PIDGEOTITE            = 167,
  PINSIRITE             = 168,
  PYROARITE             = 169,
  RAICHUITE_X           = 170,
  RAICHUITE_Y           = 171,
  -- Withdrawn 0.30.0.  RAYQUAZITE was this mod's invented stand-in trigger
  -- for Mega Rayquaza before src/dragonascent.lua existed; that trigger
  -- (knowing Dragon Ascent) is the only one left, data/megas.lua carries no
  -- row for this stone any longer, and nothing pairs with byte 172 or ever
  -- will again -- it is retired, not reassignable, per this file's own rule
  -- two lines up.  tests/battle_forms_stone_test.lua pins the byte itself so
  -- a future edit here cannot hand 172 to a new stone by accident.
  RAYQUAZITE            = 172,
  SABLENITE             = 173,
  SALAMENCITE           = 174,
  SCEPTILITE            = 175,
  SCIZORITE             = 176,
  SCOLIPEDITE           = 177,
  SCOVILLAINITE         = 178,
  SCRAFTYITE            = 179,
  SHARPEDONITE          = 180,
  SKARMORYITE           = 181,
  SLOWBRONITE           = 182,
  STARAPTORITE          = 183,
  STARMIITE             = 184,
  STEELIXITE            = 185,
  SWAMPERTITE           = 186,
  TATSUGIRIITE_CURLY    = 187,
  TATSUGIRIITE_DROOPY   = 188,
  TATSUGIRIITE_STRETCHY = 189,
  TYRANITARITE          = 190,
  VENUSAURITE           = 98,
  VICTREEBELITE         = 191,
  ZERAORAITE            = 192,
  ZYGARDITE             = 193,
}
