package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Megaset = dofile(MOD .. "/src/megaset.lua")
local raw = dofile(MOD .. "/data/megas.lua")
local megas = Megaset.select(raw, Megaset.ALL)
local official = Megaset.select(raw, Megaset.OFFICIAL)
local E = dofile(MOD .. "/src/eligibility.lua")

T.eq(E.formFor(megas, "CHARIZARD", "CHARIZARDITE_X"), "CHARIZARD_MEGA_X",
  "species plus stone resolves to the matching form")
T.eq(E.formFor(megas, "CHARIZARD", "CHARIZARDITE_Y"), "CHARIZARD_MEGA_Y",
  "the same species with a different stone resolves elsewhere")
T.eq(E.formFor(megas, "CHARIZARD", nil), nil,
  "no stone is not eligible")
T.eq(E.formFor(megas, "PIDGEY", "CHARIZARDITE_X"), nil,
  "a stone on the wrong species is not eligible")

T.eq(E.stoneOf({ species = "CHARIZARD" }), nil,
  "an unstamped mon carries no stone")
T.eq(E.stoneOf({ species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" }),
  "CHARIZARDITE_X", "a stamped mon reports its stone")

T.eq(E.formForMon(megas, { species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_Y" }),
  "CHARIZARD_MEGA_Y", "mon eligibility combines both halves")
T.eq(E.formForMon(megas, nil), nil, "a nil mon is not eligible")

-- ------- which megas are the real games' -----------------------------

-- The 48 mega evolutions that exist in the mainline games, written out here
-- rather than read back off data/megas.lua.  The whole point of the list is
-- to be a second, independent statement of the same fact: a mega marked
-- wrong in the data file fails here instead of agreeing with itself.
--
-- RAYQUAZA/RAYQUAZITE is on the list because Mega Rayquaza is official.  The
-- STONE is not -- the real games trigger that one off knowing Dragon Ascent,
-- and a stone is the only trigger this mod implements.
local OFFICIAL_PAIRS = {
  "ABOMASNOW/ABOMASITE",
  "ABSOL/ABSOLITE",
  "AERODACTYL/AERODACTYLITE",
  "AGGRON/AGGRONITE",
  "ALAKAZAM/ALAKAZITE",
  "ALTARIA/ALTARIANITE",
  "AMPHAROS/AMPHAROSITE",
  "AUDINO/AUDINITE",
  "BANETTE/BANETTITE",
  "BEEDRILL/BEEDRILLITE",
  "BLASTOISE/BLASTOISINITE",
  "BLAZIKEN/BLAZIKENITE",
  "CAMERUPT/CAMERUPTITE",
  "CHARIZARD/CHARIZARDITE_X",
  "CHARIZARD/CHARIZARDITE_Y",
  "DIANCIE/DIANCITE",
  "GALLADE/GALLADITE",
  "GARCHOMP/GARCHOMPITE",
  "GARDEVOIR/GARDEVOIRITE",
  "GENGAR/GENGARITE",
  "GLALIE/GLALITITE",
  "GYARADOS/GYARADOSITE",
  "HERACROSS/HERACRONITE",
  "HOUNDOOM/HOUNDOOMINITE",
  "KANGASKHAN/KANGASKHANITE",
  "LATIAS/LATIASITE",
  "LATIOS/LATIOSITE",
  "LOPUNNY/LOPUNNITE",
  "LUCARIO/LUCARIONITE",
  "MANECTRIC/MANECTITE",
  "MAWILE/MAWILITE",
  "MEDICHAM/MEDICHAMITE",
  "METAGROSS/METAGROSSITE",
  "MEWTWO/MEWTWONITE_X",
  "MEWTWO/MEWTWONITE_Y",
  "PIDGEOT/PIDGEOTITE",
  "PINSIR/PINSIRITE",
  "RAYQUAZA/RAYQUAZITE",
  "SABLEYE/SABLENITE",
  "SALAMENCE/SALAMENCITE",
  "SCEPTILE/SCEPTILITE",
  "SCIZOR/SCIZORITE",
  "SHARPEDO/SHARPEDONITE",
  "SLOWBRO/SLOWBRONITE",
  "STEELIX/STEELIXITE",
  "SWAMPERT/SWAMPERTITE",
  "TYRANITAR/TYRANITARITE",
  "VENUSAUR/VENUSAURITE",
}

T.eq(#OFFICIAL_PAIRS, 48, "the list this suite checks against holds 48 pairs")

local expected = {}
for _, pair in ipairs(OFFICIAL_PAIRS) do expected[pair] = true end

local marked, markedCount = {}, 0
for species, byStone in pairs(official) do
  for stoneId in pairs(byStone) do
    local pair = species .. "/" .. stoneId
    marked[pair] = true
    markedCount = markedCount + 1
    T.check(expected[pair],
      pair .. " is marked official but is not a mega the real games have")
  end
end
T.eq(markedCount, 48, "exactly 48 megas are marked official")
for _, pair in ipairs(OFFICIAL_PAIRS) do
  T.check(marked[pair],
    pair .. " is a mega the real games have but is not marked official")
end

local allCount = 0
for _, byStone in pairs(megas) do
  for _ in pairs(byStone) do allCount = allCount + 1 end
end
T.eq(allCount, 96, "ALL selects every wired mega")

-- ------- what each setting makes eligible ----------------------------

T.eq(E.formFor(official, "ABSOL", "ABSOLITE"), "ABSOL_MEGA",
  "an official pairing is eligible under OFFICIAL")
T.eq(E.formFor(official, "ABSOL", "ABSOLITE_Z"), nil,
  "the same species' extended pairing is not eligible under OFFICIAL")
T.eq(E.formFor(megas, "ABSOL", "ABSOLITE_Z"), "ABSOL_MEGA_Z",
  "that pairing is eligible under ALL")
T.eq(official.STARMIE, nil,
  "a species with no official mega is absent from OFFICIAL entirely")
T.eq(E.formForMon(official, { species = "STARMIE", [E.STAMP] = "STARMIITE" }), nil,
  "a mon already holding an extended stone is not eligible under OFFICIAL")
T.eq(E.formForMon(megas, { species = "STARMIE", [E.STAMP] = "STARMIITE" }),
  "STARMIE_MEGA", "the same mon is eligible under ALL")

-- A stored value that was renamed or corrupted must fall to the smaller set:
-- opening the extended megas is something a player has to ask for.
T.eq(E.formFor(Megaset.select(raw, "everything"), "ABSOL", "ABSOLITE_Z"), nil,
  "a setting that is neither OFFICIAL nor ALL reads as OFFICIAL")

-- ------- an unmarked row is refused out loud -------------------------

-- Guessing either way would put a mega added later into a set nobody chose
-- for it, and it would be wrong silently.
local broken = {
  GENGAR    = { GENGARITE    = { form = "GENGAR_MEGA", official = true } },
  KABUTOPS  = { KABUTOPSITE  = { form = "KABUTOPS_MEGA", official = "yes" } },
  MISSINGNO = { MISSINGNOITE = "MISSINGNO_MEGA" },
}
local problems = Megaset.problems(broken)
T.eq(#problems, 2, "both unmarked rows are reported")
T.eq(problems[1], "KABUTOPS/KABUTOPSITE",
  "a marker that is not a boolean counts as no marker")
T.eq(problems[2], "MISSINGNO/MISSINGNOITE",
  "a bare form id counts as no marker, and the report names the pair")

T.eq(E.formFor(Megaset.select(broken, Megaset.ALL), "MISSINGNO", "MISSINGNOITE"), nil,
  "an unmarked row is dropped from ALL rather than assumed extended")
T.eq(E.formFor(Megaset.select(broken, Megaset.OFFICIAL), "MISSINGNO", "MISSINGNOITE"),
  nil, "and dropped from OFFICIAL rather than assumed official")
T.eq(E.formFor(Megaset.select(broken, Megaset.ALL), "GENGAR", "GENGARITE"),
  "GENGAR_MEGA", "a properly marked row beside it still selects")

T.eq(#Megaset.problems(raw), 0,
  "every row in data/megas.lua carries an officialness marker")

T.finish("battle_forms_eligibility")
