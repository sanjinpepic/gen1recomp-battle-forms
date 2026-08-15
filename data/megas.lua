-- species id -> stone item id -> National Dex form id.
--
-- Keyed on the PAIR rather than the species: several species have more than
-- one mega and the stone is what tells them apart, so a species-keyed table
-- could not express the case that motivated this design.
--
-- The form id MUST be the National Dex record's KEY -- what data.pokemon[...]
-- is indexed by (e.g. CHARIZARD_MEGA_X) -- and never the record's `name`
-- field (e.g. "charizard-mega-x").  Those look interchangeable and are not:
-- a `name` value here compiles fine and passes review, and then every lookup
-- in Forms.becomeForm misses silently.  That exact mistake shipped in 0.2.1.
--
-- Every mega wired here has art in data/sprites/generated/formart.lua under
-- [BASE].forms[FORM]; a National Dex mega record with no art is left out on
-- purpose (it would render as its base species) -- see CHANGELOG.md 0.4.0.
-- Stone names follow the real in-game item where the mega is from the mainline
-- games (Charizardite X, Absolite, ...); a mega National Dex adds that never
-- shipped officially gets a mechanical BASE+ITE name instead, with an
-- X/Y/Z/MALE/ORIGINAL/... suffix when a species carries more than one.
--
-- This table belongs in national_dex and moves there once the primitive is
-- proven.  It lives here for the trial so that an experimental battle mod
-- cannot force a release of a stable one.

-- `official` is a mega the mainline games shipped, `extended` one only the
-- National Dex data carries.  The MEGA EVOLUTIONS option chooses between the
-- two sets and src/megaset.lua is the only file that reads the mark.
--
-- Every pair must carry one.  A bare form id is rejected by both sets and
-- reported rather than assumed either way: a mega added here later would
-- otherwise land in whichever set the default happened to be, and be wrong
-- without anyone hearing about it.
--
-- One official row still carries a trigger the real games do not have.
-- Mega Rayquaza has no stone in the mainline games -- it megas by knowing
-- Dragon Ascent -- and RAYQUAZITE was this mod's invention from the days
-- when a stone was the only trigger implemented here.  0.29.0 added the real
-- one (src/dragonascent.lua): a Rayquaza that knows Dragon Ascent reaches
-- the MEGA cell with no Key Stone and no stone at all, refused only by a
-- held Z-Crystal, per the Gen 7 rule.  RAYQUAZITE still works and this row
-- still needs its officialness marker -- Rayquaza is not placed in any
-- encounter, gift or trade yet, so the stone is the only carrier the mega
-- has until one exists -- but it is transitional and will be withdrawn once
-- it is not.  Byte 172 stays reserved either way; data/stones.lua's own rule
-- is that a stone's byte is never renumbered, because reusing one silently
-- turns a stone already in a player's bag into a different item.
local function official(form) return { form = form, official = true } end
local function extended(form) return { form = form, official = false } end

return {
  ABOMASNOW    = { ABOMASITE = official "ABOMASNOW_MEGA" },
  ABSOL        = { ABSOLITE   = official "ABSOL_MEGA",
                   ABSOLITE_Z = extended "ABSOL_MEGA_Z" },
  AERODACTYL   = { AERODACTYLITE = official "AERODACTYL_MEGA" },
  AGGRON       = { AGGRONITE = official "AGGRON_MEGA" },
  ALAKAZAM     = { ALAKAZITE = official "ALAKAZAM_MEGA" },
  ALTARIA      = { ALTARIANITE = official "ALTARIA_MEGA" },
  AMPHAROS     = { AMPHAROSITE = official "AMPHAROS_MEGA" },
  AUDINO       = { AUDINITE = official "AUDINO_MEGA" },
  BANETTE      = { BANETTITE = official "BANETTE_MEGA" },
  BARBARACLE   = { BARBARACLITE = extended "BARBARACLE_MEGA" },
  BAXCALIBUR   = { BAXCALIBURITE = extended "BAXCALIBUR_MEGA" },
  BEEDRILL     = { BEEDRILLITE = official "BEEDRILL_MEGA" },
  BLASTOISE    = { BLASTOISINITE = official "BLASTOISE_MEGA" },
  BLAZIKEN     = { BLAZIKENITE = official "BLAZIKEN_MEGA" },
  CAMERUPT     = { CAMERUPTITE = official "CAMERUPT_MEGA" },
  CHANDELURE   = { CHANDELURITE = extended "CHANDELURE_MEGA" },
  CHARIZARD    = { CHARIZARDITE_X = official "CHARIZARD_MEGA_X",
                   CHARIZARDITE_Y = official "CHARIZARD_MEGA_Y" },
  CHESNAUGHT   = { CHESNAUGHTITE = extended "CHESNAUGHT_MEGA" },
  CHIMECHO     = { CHIMECHOITE = extended "CHIMECHO_MEGA" },
  CLEFABLE     = { CLEFABLITE = extended "CLEFABLE_MEGA" },
  CRABOMINABLE = { CRABOMINABLITE = extended "CRABOMINABLE_MEGA" },
  DARKRAI      = { DARKRAIITE = extended "DARKRAI_MEGA" },
  DELPHOX      = { DELPHOXITE = extended "DELPHOX_MEGA" },
  DIANCIE      = { DIANCITE = official "DIANCIE_MEGA" },
  DRAGALGE     = { DRAGALGITE = extended "DRAGALGE_MEGA" },
  DRAGONITE    = { DRAGONITITE = extended "DRAGONITE_MEGA" },
  DRAMPA       = { DRAMPAITE = extended "DRAMPA_MEGA" },
  EELEKTROSS   = { EELEKTROSSITE = extended "EELEKTROSS_MEGA" },
  EMBOAR       = { EMBOARITE = extended "EMBOAR_MEGA" },
  EXCADRILL    = { EXCADRILLITE = extended "EXCADRILL_MEGA" },
  FALINKS      = { FALINKSITE = extended "FALINKS_MEGA" },
  FERALIGATR   = { FERALIGATRITE = extended "FERALIGATR_MEGA" },
  FLOETTE      = { FLOETTITE = extended "FLOETTE_MEGA" },
  FROSLASS     = { FROSLASSITE = extended "FROSLASS_MEGA" },
  GALLADE      = { GALLADITE = official "GALLADE_MEGA" },
  GARCHOMP     = { GARCHOMPITE   = official "GARCHOMP_MEGA",
                   GARCHOMPITE_Z = extended "GARCHOMP_MEGA_Z" },
  GARDEVOIR    = { GARDEVOIRITE = official "GARDEVOIR_MEGA" },
  GENGAR       = { GENGARITE = official "GENGAR_MEGA" },
  GLALIE       = { GLALITITE = official "GLALIE_MEGA" },
  GLIMMORA     = { GLIMMORAITE = extended "GLIMMORA_MEGA" },
  GOLISOPOD    = { GOLISOPODITE = extended "GOLISOPOD_MEGA" },
  GOLURK       = { GOLURKITE = extended "GOLURK_MEGA" },
  GRENINJA     = { GRENINJAITE = extended "GRENINJA_MEGA" },
  GYARADOS     = { GYARADOSITE = official "GYARADOS_MEGA" },
  HAWLUCHA     = { HAWLUCHAITE = extended "HAWLUCHA_MEGA" },
  HEATRAN      = { HEATRANITE = extended "HEATRAN_MEGA" },
  HERACROSS    = { HERACRONITE = official "HERACROSS_MEGA" },
  HOUNDOOM     = { HOUNDOOMINITE = official "HOUNDOOM_MEGA" },
  KANGASKHAN   = { KANGASKHANITE = official "KANGASKHAN_MEGA" },
  LATIAS       = { LATIASITE = official "LATIAS_MEGA" },
  LATIOS       = { LATIOSITE = official "LATIOS_MEGA" },
  LOPUNNY      = { LOPUNNITE = official "LOPUNNY_MEGA" },
  LUCARIO      = { LUCARIONITE  = official "LUCARIO_MEGA",
                   LUCARIOITE_Z = extended "LUCARIO_MEGA_Z" },
  MAGEARNA     = { MAGEARNAITE          = extended "MAGEARNA_MEGA",
                   MAGEARNAITE_ORIGINAL = extended "MAGEARNA_ORIGINAL_MEGA" },
  MALAMAR      = { MALAMARITE = extended "MALAMAR_MEGA" },
  MANECTRIC    = { MANECTITE = official "MANECTRIC_MEGA" },
  MAWILE       = { MAWILITE = official "MAWILE_MEGA" },
  MEDICHAM     = { MEDICHAMITE = official "MEDICHAM_MEGA" },
  MEGANIUM     = { MEGANIUMITE = extended "MEGANIUM_MEGA" },
  MEOWSTIC     = { MEOWSTICITE_MALE = extended "MEOWSTIC_MALE_MEGA" },
  METAGROSS    = { METAGROSSITE = official "METAGROSS_MEGA" },
  MEWTWO       = { MEWTWONITE_X = official "MEWTWO_MEGA_X",
                   MEWTWONITE_Y = official "MEWTWO_MEGA_Y" },
  PIDGEOT      = { PIDGEOTITE = official "PIDGEOT_MEGA" },
  PINSIR       = { PINSIRITE = official "PINSIR_MEGA" },
  PYROAR       = { PYROARITE = extended "PYROAR_MEGA" },
  RAICHU       = { RAICHUITE_X = extended "RAICHU_MEGA_X",
                   RAICHUITE_Y = extended "RAICHU_MEGA_Y" },
  RAYQUAZA     = { RAYQUAZITE = official "RAYQUAZA_MEGA" },
  SABLEYE      = { SABLENITE = official "SABLEYE_MEGA" },
  SALAMENCE    = { SALAMENCITE = official "SALAMENCE_MEGA" },
  SCEPTILE     = { SCEPTILITE = official "SCEPTILE_MEGA" },
  SCIZOR       = { SCIZORITE = official "SCIZOR_MEGA" },
  SCOLIPEDE    = { SCOLIPEDITE = extended "SCOLIPEDE_MEGA" },
  SCOVILLAIN   = { SCOVILLAINITE = extended "SCOVILLAIN_MEGA" },
  SCRAFTY      = { SCRAFTYITE = extended "SCRAFTY_MEGA" },
  SHARPEDO     = { SHARPEDONITE = official "SHARPEDO_MEGA" },
  SKARMORY     = { SKARMORYITE = extended "SKARMORY_MEGA" },
  SLOWBRO      = { SLOWBRONITE = official "SLOWBRO_MEGA" },
  STARAPTOR    = { STARAPTORITE = extended "STARAPTOR_MEGA" },
  STARMIE      = { STARMIITE = extended "STARMIE_MEGA" },
  STEELIX      = { STEELIXITE = official "STEELIX_MEGA" },
  SWAMPERT     = { SWAMPERTITE = official "SWAMPERT_MEGA" },
  TATSUGIRI    = { TATSUGIRIITE_CURLY    = extended "TATSUGIRI_CURLY_MEGA",
                   TATSUGIRIITE_DROOPY   = extended "TATSUGIRI_DROOPY_MEGA",
                   TATSUGIRIITE_STRETCHY = extended "TATSUGIRI_STRETCHY_MEGA" },
  TYRANITAR    = { TYRANITARITE = official "TYRANITAR_MEGA" },
  VENUSAUR     = { VENUSAURITE = official "VENUSAUR_MEGA" },
  VICTREEBEL   = { VICTREEBELITE = extended "VICTREEBEL_MEGA" },
  ZERAORA      = { ZERAORAITE = extended "ZERAORA_MEGA" },
  ZYGARDE      = { ZYGARDITE = extended "ZYGARDE_MEGA" },
}
