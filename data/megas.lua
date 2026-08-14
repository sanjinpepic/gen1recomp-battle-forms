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
return {
  ABOMASNOW    = { ABOMASITE = "ABOMASNOW_MEGA" },
  ABSOL        = { ABSOLITE   = "ABSOL_MEGA",
                   ABSOLITE_Z = "ABSOL_MEGA_Z" },
  AERODACTYL   = { AERODACTYLITE = "AERODACTYL_MEGA" },
  AGGRON       = { AGGRONITE = "AGGRON_MEGA" },
  ALAKAZAM     = { ALAKAZITE = "ALAKAZAM_MEGA" },
  ALTARIA      = { ALTARIANITE = "ALTARIA_MEGA" },
  AMPHAROS     = { AMPHAROSITE = "AMPHAROS_MEGA" },
  AUDINO       = { AUDINITE = "AUDINO_MEGA" },
  BANETTE      = { BANETTITE = "BANETTE_MEGA" },
  BARBARACLE   = { BARBARACLITE = "BARBARACLE_MEGA" },
  BAXCALIBUR   = { BAXCALIBURITE = "BAXCALIBUR_MEGA" },
  BEEDRILL     = { BEEDRILLITE = "BEEDRILL_MEGA" },
  BLASTOISE    = { BLASTOISINITE = "BLASTOISE_MEGA" },
  BLAZIKEN     = { BLAZIKENITE = "BLAZIKEN_MEGA" },
  CAMERUPT     = { CAMERUPTITE = "CAMERUPT_MEGA" },
  CHANDELURE   = { CHANDELURITE = "CHANDELURE_MEGA" },
  CHARIZARD    = { CHARIZARDITE_X = "CHARIZARD_MEGA_X",
                   CHARIZARDITE_Y = "CHARIZARD_MEGA_Y" },
  CHESNAUGHT   = { CHESNAUGHTITE = "CHESNAUGHT_MEGA" },
  CHIMECHO     = { CHIMECHOITE = "CHIMECHO_MEGA" },
  CLEFABLE     = { CLEFABLITE = "CLEFABLE_MEGA" },
  CRABOMINABLE = { CRABOMINABLITE = "CRABOMINABLE_MEGA" },
  DARKRAI      = { DARKRAIITE = "DARKRAI_MEGA" },
  DELPHOX      = { DELPHOXITE = "DELPHOX_MEGA" },
  DIANCIE      = { DIANCITE = "DIANCIE_MEGA" },
  DRAGALGE     = { DRAGALGITE = "DRAGALGE_MEGA" },
  DRAGONITE    = { DRAGONITITE = "DRAGONITE_MEGA" },
  DRAMPA       = { DRAMPAITE = "DRAMPA_MEGA" },
  EELEKTROSS   = { EELEKTROSSITE = "EELEKTROSS_MEGA" },
  EMBOAR       = { EMBOARITE = "EMBOAR_MEGA" },
  EXCADRILL    = { EXCADRILLITE = "EXCADRILL_MEGA" },
  FALINKS      = { FALINKSITE = "FALINKS_MEGA" },
  FERALIGATR   = { FERALIGATRITE = "FERALIGATR_MEGA" },
  FLOETTE      = { FLOETTITE = "FLOETTE_MEGA" },
  FROSLASS     = { FROSLASSITE = "FROSLASS_MEGA" },
  GALLADE      = { GALLADITE = "GALLADE_MEGA" },
  GARCHOMP     = { GARCHOMPITE   = "GARCHOMP_MEGA",
                   GARCHOMPITE_Z = "GARCHOMP_MEGA_Z" },
  GARDEVOIR    = { GARDEVOIRITE = "GARDEVOIR_MEGA" },
  GENGAR       = { GENGARITE = "GENGAR_MEGA" },
  GLALIE       = { GLALITITE = "GLALIE_MEGA" },
  GLIMMORA     = { GLIMMORAITE = "GLIMMORA_MEGA" },
  GOLISOPOD    = { GOLISOPODITE = "GOLISOPOD_MEGA" },
  GOLURK       = { GOLURKITE = "GOLURK_MEGA" },
  GRENINJA     = { GRENINJAITE = "GRENINJA_MEGA" },
  GYARADOS     = { GYARADOSITE = "GYARADOS_MEGA" },
  HAWLUCHA     = { HAWLUCHAITE = "HAWLUCHA_MEGA" },
  HEATRAN      = { HEATRANITE = "HEATRAN_MEGA" },
  HERACROSS    = { HERACRONITE = "HERACROSS_MEGA" },
  HOUNDOOM     = { HOUNDOOMINITE = "HOUNDOOM_MEGA" },
  KANGASKHAN   = { KANGASKHANITE = "KANGASKHAN_MEGA" },
  LATIAS       = { LATIASITE = "LATIAS_MEGA" },
  LATIOS       = { LATIOSITE = "LATIOS_MEGA" },
  LOPUNNY      = { LOPUNNITE = "LOPUNNY_MEGA" },
  LUCARIO      = { LUCARIONITE  = "LUCARIO_MEGA",
                   LUCARIOITE_Z = "LUCARIO_MEGA_Z" },
  MAGEARNA     = { MAGEARNAITE          = "MAGEARNA_MEGA",
                   MAGEARNAITE_ORIGINAL = "MAGEARNA_ORIGINAL_MEGA" },
  MALAMAR      = { MALAMARITE = "MALAMAR_MEGA" },
  MANECTRIC    = { MANECTITE = "MANECTRIC_MEGA" },
  MAWILE       = { MAWILITE = "MAWILE_MEGA" },
  MEDICHAM     = { MEDICHAMITE = "MEDICHAM_MEGA" },
  MEGANIUM     = { MEGANIUMITE = "MEGANIUM_MEGA" },
  MEOWSTIC     = { MEOWSTICITE_MALE = "MEOWSTIC_MALE_MEGA" },
  METAGROSS    = { METAGROSSITE = "METAGROSS_MEGA" },
  MEWTWO       = { MEWTWONITE_X = "MEWTWO_MEGA_X",
                   MEWTWONITE_Y = "MEWTWO_MEGA_Y" },
  PIDGEOT      = { PIDGEOTITE = "PIDGEOT_MEGA" },
  PINSIR       = { PINSIRITE = "PINSIR_MEGA" },
  PYROAR       = { PYROARITE = "PYROAR_MEGA" },
  RAICHU       = { RAICHUITE_X = "RAICHU_MEGA_X",
                   RAICHUITE_Y = "RAICHU_MEGA_Y" },
  RAYQUAZA     = { RAYQUAZITE = "RAYQUAZA_MEGA" },
  SABLEYE      = { SABLENITE = "SABLEYE_MEGA" },
  SALAMENCE    = { SALAMENCITE = "SALAMENCE_MEGA" },
  SCEPTILE     = { SCEPTILITE = "SCEPTILE_MEGA" },
  SCIZOR       = { SCIZORITE = "SCIZOR_MEGA" },
  SCOLIPEDE    = { SCOLIPEDITE = "SCOLIPEDE_MEGA" },
  SCOVILLAIN   = { SCOVILLAINITE = "SCOVILLAIN_MEGA" },
  SCRAFTY      = { SCRAFTYITE = "SCRAFTY_MEGA" },
  SHARPEDO     = { SHARPEDONITE = "SHARPEDO_MEGA" },
  SKARMORY     = { SKARMORYITE = "SKARMORY_MEGA" },
  SLOWBRO      = { SLOWBRONITE = "SLOWBRO_MEGA" },
  STARAPTOR    = { STARAPTORITE = "STARAPTOR_MEGA" },
  STARMIE      = { STARMIITE = "STARMIE_MEGA" },
  STEELIX      = { STEELIXITE = "STEELIX_MEGA" },
  SWAMPERT     = { SWAMPERTITE = "SWAMPERT_MEGA" },
  TATSUGIRI    = { TATSUGIRIITE_CURLY    = "TATSUGIRI_CURLY_MEGA",
                   TATSUGIRIITE_DROOPY   = "TATSUGIRI_DROOPY_MEGA",
                   TATSUGIRIITE_STRETCHY = "TATSUGIRI_STRETCHY_MEGA" },
  TYRANITAR    = { TYRANITARITE = "TYRANITAR_MEGA" },
  VENUSAUR     = { VENUSAURITE = "VENUSAUR_MEGA" },
  VICTREEBEL   = { VICTREEBELITE = "VICTREEBEL_MEGA" },
  ZERAORA      = { ZERAORAITE = "ZERAORA_MEGA" },
  ZYGARDE      = { ZYGARDITE = "ZYGARDE_MEGA" },
}
