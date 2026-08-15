-- Validates every form id this mod wires -- data/megas.lua and
-- data/primals.lua alike -- against the real National Dex species data on
-- disk.  This is the test whose absence let a display name
-- ("charizard-mega-x") ship where a record key ("CHARIZARD_MEGA_X") belonged:
-- every other suite fabricates its own DATA.pokemon fixture, so none of them
-- could ever notice the mega table pointing at a field that does not exist.
--
-- national.lua is not dofile'd -- it is enormous, and the project's own
-- notes call out a LuaJIT constant-count ceiling on it -- so this reads the
-- file as text and looks for each id as a record KEY: a line that starts
-- with the id, optional whitespace, then `= {`.  That is deliberately
-- narrower than "appears anywhere in the file": `name = "charizard-mega-x"`
-- sits one line below `CHARIZARD_MEGA_X = {` in the very same record, and a
-- looser match would not have caught the bug this test exists to catch.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Megaset = dofile(MOD .. "/src/megaset.lua")
-- The whole roster: every check below holds for any wired mega, and the
-- OFFICIAL/ALL split is pinned in the eligibility suite.  The primal table
-- needs no selecting -- it is already the plain shape select() produces --
-- and both are read here because a wrong id is exactly as silent in either.
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)
local primals = dofile(MOD .. "/data/primals.lua")
local conditional = dofile(MOD .. "/data/conditional.lua")
local gigantamax = dofile(MOD .. "/data/gigantamax.lua")
local persistent = dofile(MOD .. "/data/persistent.lua")
local fusion = dofile(MOD .. "/data/fusion.lua")
local ultraburst = dofile(MOD .. "/data/ultraburst.lua")

local NATIONAL_DEX = MOD .. "/../national_dex_mod/data/species/generated/national.lua"

local handle = io.open(NATIONAL_DEX, "rb")
if not handle then
  print("battle_forms_formids: SKIPPED -- " .. NATIONAL_DEX
    .. " not found; check out national_dex_mod alongside battle_forms_mod "
    .. "to verify the mega table's form ids against real species records")
  os.exit(0)
end
local text = handle:read("*a")
handle:close()

-- A line-start anchor for the exact key, immune to indentation.  The file
-- has no leading blank line, so a synthetic "\n" in front covers a key that
-- happens to open the file too.
local function isRecordKey(id)
  local escaped = id:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")
  return ("\n" .. text):find("\n%s*" .. escaped .. "%s*=%s*{") ~= nil
end

local formIds = {}
-- data/persistent.lua is the same species -> item -> form shape, so it joins
-- the sweep rather than needing a pass of its own.  A wrong id there is worse
-- than a wrong id anywhere else in this file: every other table describes a
-- form that would simply never happen, where this one describes a form the
-- battle-end sweep is meant to put BACK, and an unresolvable one is a marker
-- cleared out of a player's save on every fight.
for _, table_ in ipairs({ megas, primals, persistent, ultraburst }) do
  for _, byItem in pairs(table_) do
    for _, formId in pairs(byItem) do
      formIds[#formIds + 1] = formId
    end
  end
end
-- data/fusion.lua is species -> item -> PARTNER -> form, one level deeper than
-- the three above.  Every id it names is swept the same way, and so is every
-- PARTNER key: a partner species that is not a record is a Pokemon this mod
-- would never find in a party, so the item would refuse forever with nothing
-- anywhere to say why.  A wrong id here is worse than a wrong id in any other
-- table -- the others describe a form that never happens, and this one describes
-- the form of a Pokemon that has a second Pokemon sitting in the PC behind it.
local fusionBases, fusionPartners = {}, {}
for species, byItem in pairs(fusion) do
  fusionBases[#fusionBases + 1] = species
  for _, byPartner in pairs(byItem) do
    for partner, formId in pairs(byPartner) do
      formIds[#formIds + 1] = formId
      fusionPartners[#fusionPartners + 1] = partner
    end
  end
end
table.sort(fusionBases)
table.sort(fusionPartners)

-- data/conditional.lua is species -> one row, not species -> item -> form,
-- because a condition-driven form has no item to key on.  Same id rule,
-- one level shallower.
local conditionalSpecies = {}
for species, row in pairs(conditional) do
  formIds[#formIds + 1] = row.form
  conditionalSpecies[#conditionalSpecies + 1] = species
end
-- data/gigantamax.lua is species -> form id, flatter still: a Gigantamax has
-- no item and no condition to key on, only the species that owns one.
local gigantamaxSpecies = {}
for species, formId in pairs(gigantamax) do
  formIds[#formIds + 1] = formId
  gigantamaxSpecies[#gigantamaxSpecies + 1] = species
end
table.sort(formIds)
table.sort(conditionalSpecies)
table.sort(gigantamaxSpecies)

T.check(#formIds > 0, "the wired tables name at least one form")

-- The two primal ids are also named outright: a pairing quietly dropped from
-- data/primals.lua would only make the sweep above one shorter, and nothing
-- would fail.
T.eq(primals.GROUDON and primals.GROUDON.RED_ORB, "GROUDON_PRIMAL",
  "data/primals.lua still pairs Groudon with the Red Orb")
T.eq(primals.KYOGRE and primals.KYOGRE.BLUE_ORB, "KYOGRE_PRIMAL",
  "data/primals.lua still pairs Kyogre with the Blue Orb")

-- Ultra Burst's one pairing, named outright for the same reason: a pairing
-- quietly dropped would only make the sweep above one shorter, and nothing
-- would fail.
T.eq(ultraburst.NECROZMA and ultraburst.NECROZMA.ULTRANECROZIUM_Z,
  "NECROZMA_ULTRA",
  "data/ultraburst.lua still pairs Necrozma's Ultranecrozium Z with "
    .. "NECROZMA_ULTRA")
do
  local wired = 0
  for _ in pairs(ultraburst) do wired = wired + 1 end
  T.eq(wired, 1, "data/ultraburst.lua wires exactly the one species it says")
  local byItem = ultraburst.NECROZMA or {}
  local items = 0
  for _ in pairs(byItem) do items = items + 1 end
  T.eq(items, 1, "and pairs nothing else -- one item, one form")
end

-- And for the persistent pairings, named outright rather than counted, for the
-- reason the two primals are: a pairing quietly dropped would only make the
-- sweep above one shorter and nothing would fail -- but here it would also
-- strip that form off every Pokemon already wearing it in a player's save the
-- next time a battle ended, because the marker is derived and this table is the
-- only thing entitled to vouch for it.
do
  local rotom = persistent.ROTOM or {}
  local expected = {
    MICROWAVE_OVEN  = "ROTOM_HEAT",
    WASHING_MACHINE = "ROTOM_WASH",
    REFRIGERATOR    = "ROTOM_FROST",
    ELECTRIC_FAN    = "ROTOM_FAN",
    LAWN_MOWER      = "ROTOM_MOW",
  }
  local count = 0
  for itemId, formId in pairs(expected) do
    T.eq(rotom[itemId], formId,
      "data/persistent.lua still pairs Rotom's " .. itemId .. " with " .. formId)
    count = count + 1
  end
  local wired = 0
  for _ in pairs(rotom) do wired = wired + 1 end
  T.eq(wired, count, "and pairs nothing else -- five appliances, five forms")
end

-- The six held-item persistent forms wired in 0.21.0, named outright for the
-- same reason the appliances are: a pairing quietly dropped here would strip
-- that form off every Pokemon already wearing it in a player's save the next
-- time a battle ended.
do
  local expected = {
    { "GIRATINA",  "GRISEOUS_ORB",    "GIRATINA_ORIGIN" },
    { "PALKIA",    "LUSTROUS_GLOBE",  "PALKIA_ORIGIN" },
    { "DIALGA",    "ADAMANT_CRYSTAL", "DIALGA_ORIGIN" },
    { "ZACIAN",    "RUSTED_SWORD",    "ZACIAN_CROWNED" },
    { "ZAMAZENTA", "RUSTED_SHIELD",   "ZAMAZENTA_CROWNED" },
    { "SHAYMIN",   "GRACIDEA",        "SHAYMIN_SKY" },
  }
  for _, row in ipairs(expected) do
    local species, item, formId = row[1], row[2], row[3]
    T.eq(persistent[species] and persistent[species][item], formId,
      "data/persistent.lua still pairs " .. species .. "'s " .. item
        .. " with " .. formId)
    local wired = 0
    for _ in pairs(persistent[species] or {}) do wired = wired + 1 end
    T.eq(wired, 1, species .. " pairs nothing else -- one item, one form")
  end

  local species = {}
  for key in pairs(persistent) do species[#species + 1] = key end
  table.sort(species)
  T.eq(table.concat(species, ","),
    "ARCEUS,DIALGA,GIRATINA,PALKIA,ROTOM,SHAYMIN,SILVALLY,ZACIAN,ZAMAZENTA",
    "data/persistent.lua wires exactly the nine species it says it does")
  for _, key in ipairs(species) do
    T.check(isRecordKey(key), key .. " is a record KEY in national.lua (a "
      .. "persistent row keyed on a species that does not exist can never fire)")
  end
end

-- Arceus's seventeen Plates and Silvally's seventeen Memories, named outright
-- for the same reason the six held-item forms above are: a pairing quietly
-- dropped would only make the sweep above one shorter, and here it would also
-- strip that form off every Arceus or Silvally already wearing it in a
-- player's save the next time a battle ended.  See
-- tests/battle_forms_plates_test.lua for the mechanism itself (registration,
-- the byteless bag entry, using and un-using the item); this is only the id
-- table, the same way the six rows above are only the id table in this file.
do
  local expected = {
    { "ARCEUS", "FIST_PLATE",   "ARCEUS_FIGHTING" },
    { "ARCEUS", "SKY_PLATE",    "ARCEUS_FLYING" },
    { "ARCEUS", "TOXIC_PLATE",  "ARCEUS_POISON" },
    { "ARCEUS", "EARTH_PLATE",  "ARCEUS_GROUND" },
    { "ARCEUS", "STONE_PLATE",  "ARCEUS_ROCK" },
    { "ARCEUS", "INSECT_PLATE", "ARCEUS_BUG" },
    { "ARCEUS", "SPOOKY_PLATE", "ARCEUS_GHOST" },
    { "ARCEUS", "IRON_PLATE",   "ARCEUS_STEEL" },
    { "ARCEUS", "FLAME_PLATE",  "ARCEUS_FIRE" },
    { "ARCEUS", "SPLASH_PLATE", "ARCEUS_WATER" },
    { "ARCEUS", "MEADOW_PLATE", "ARCEUS_GRASS" },
    { "ARCEUS", "ZAP_PLATE",    "ARCEUS_ELECTRIC" },
    { "ARCEUS", "MIND_PLATE",   "ARCEUS_PSYCHIC" },
    { "ARCEUS", "ICICLE_PLATE", "ARCEUS_ICE" },
    { "ARCEUS", "DRACO_PLATE",  "ARCEUS_DRAGON" },
    { "ARCEUS", "DREAD_PLATE",  "ARCEUS_DARK" },
    { "ARCEUS", "PIXIE_PLATE",  "ARCEUS_FAIRY" },
    { "SILVALLY", "FIGHTING_MEMORY", "SILVALLY_FIGHTING" },
    { "SILVALLY", "FLYING_MEMORY",   "SILVALLY_FLYING" },
    { "SILVALLY", "POISON_MEMORY",   "SILVALLY_POISON" },
    { "SILVALLY", "GROUND_MEMORY",   "SILVALLY_GROUND" },
    { "SILVALLY", "ROCK_MEMORY",     "SILVALLY_ROCK" },
    { "SILVALLY", "BUG_MEMORY",      "SILVALLY_BUG" },
    { "SILVALLY", "GHOST_MEMORY",    "SILVALLY_GHOST" },
    { "SILVALLY", "STEEL_MEMORY",    "SILVALLY_STEEL" },
    { "SILVALLY", "FIRE_MEMORY",     "SILVALLY_FIRE" },
    { "SILVALLY", "WATER_MEMORY",    "SILVALLY_WATER" },
    { "SILVALLY", "GRASS_MEMORY",    "SILVALLY_GRASS" },
    { "SILVALLY", "ELECTRIC_MEMORY", "SILVALLY_ELECTRIC" },
    { "SILVALLY", "PSYCHIC_MEMORY",  "SILVALLY_PSYCHIC" },
    { "SILVALLY", "ICE_MEMORY",      "SILVALLY_ICE" },
    { "SILVALLY", "DRAGON_MEMORY",   "SILVALLY_DRAGON" },
    { "SILVALLY", "DARK_MEMORY",     "SILVALLY_DARK" },
    { "SILVALLY", "FAIRY_MEMORY",    "SILVALLY_FAIRY" },
  }
  for _, row in ipairs(expected) do
    local species, item, formId = row[1], row[2], row[3]
    T.eq(persistent[species] and persistent[species][item], formId,
      "data/persistent.lua still pairs " .. species .. "'s " .. item
        .. " with " .. formId)
  end
  local arceusCount, silvallyCount = 0, 0
  for _ in pairs(persistent.ARCEUS or {}) do arceusCount = arceusCount + 1 end
  for _ in pairs(persistent.SILVALLY or {}) do silvallyCount = silvallyCount + 1 end
  T.eq(arceusCount, 17, "Arceus wires exactly its seventeen Plates")
  T.eq(silvallyCount, 17, "Silvally wires exactly its seventeen Memories")
end

-- The six pairings named outright rather than counted, for the reason the
-- primals and the appliances are: a pairing quietly dropped would only make the
-- sweep above shorter and nothing would fail -- and here it would also strand
-- every Pokemon already fused through it, because that pairing is the only
-- thing entitled to name the form AND the only thing that knows the item may
-- undo it.
do
  local expected = {
    { "KYUREM",   "DNA_SPLICERS",   "RESHIRAM",  "KYUREM_WHITE" },
    { "KYUREM",   "DNA_SPLICERS",   "ZEKROM",    "KYUREM_BLACK" },
    { "NECROZMA", "N_SOLARIZER",    "SOLGALEO",  "NECROZMA_DUSK" },
    { "NECROZMA", "N_LUNARIZER",    "LUNALA",    "NECROZMA_DAWN" },
    { "CALYREX",  "REINS_OF_UNITY", "GLASTRIER", "CALYREX_ICE" },
    { "CALYREX",  "REINS_OF_UNITY", "SPECTRIER", "CALYREX_SHADOW" },
  }
  local wired = 0
  for _, row in ipairs(expected) do
    local base, item, partner, formId = row[1], row[2], row[3], row[4]
    local byItem = fusion[base] or {}
    T.eq(byItem[item] and byItem[item][partner], formId,
      "data/fusion.lua still pairs " .. base .. " + " .. partner .. " under the "
        .. item .. " with " .. formId)
  end
  for _, byItem in pairs(fusion) do
    for _, byPartner in pairs(byItem) do
      for _ in pairs(byPartner) do wired = wired + 1 end
    end
  end
  T.eq(wired, #expected,
    "and pairs nothing else -- three families, six results")

  T.eq(table.concat(fusionBases, ","), "CALYREX,KYUREM,NECROZMA",
    "data/fusion.lua wires exactly the three base species it says it does")
  T.eq(table.concat(fusionPartners, ","),
    "GLASTRIER,LUNALA,RESHIRAM,SOLGALEO,SPECTRIER,ZEKROM",
    "and exactly the six partners")
end

-- A base key is what src/fusion.lua indexes with mon.species and a partner key
-- is what it matches a party member against, so either one that is not itself a
-- record in national.lua is a pairing that can never fire.
for _, species in ipairs(fusionBases) do
  T.check(isRecordKey(species), species
    .. " is a record KEY in national.lua (a fusion base that does not exist "
    .. "can never fire)")
end
for _, species in ipairs(fusionPartners) do
  T.check(isRecordKey(species), species
    .. " is a record KEY in national.lua (a fusion partner that does not "
    .. "exist could never be found in a party)")
end

-- Same reasoning for the conditional rows: a row quietly dropped would only
-- make the id sweep one shorter, and nothing would fail.  The list is the
-- wired roster, so a form added without art or without a seam fails here.
T.eq(table.concat(conditionalSpecies, ","),
  "AEGISLASH,DARMANITAN,EISCUE,GRENINJA,MIMIKYU,MINIOR,MORPEKO,WISHIWASHI",
  "data/conditional.lua wires exactly the eight species it says it does")

-- A row is keyed by the BASE species, and that key is what src/conditional.lua
-- indexes with mon.species -- so a key that is not itself a record in
-- national.lua is a row that can never fire, as silently as a wrong form id.
for _, species in ipairs(conditionalSpecies) do
  T.check(isRecordKey(species), species
    .. " is a record KEY in national.lua (a conditional row keyed on a "
    .. "species that does not exist can never fire)")
end

-- The same rule for the Gigantamax table, indexed by src/dynamax.lua with
-- mon.species: a key that is not a record is a species that silently never
-- Gigantamaxes and gets a plain Dynamax forever.
T.eq(#gigantamaxSpecies, 31,
  "data/gigantamax.lua wires exactly the 31 species it says it does")
for _, species in ipairs(gigantamaxSpecies) do
  T.check(isRecordKey(species), species
    .. " is a record KEY in national.lua (a Gigantamax keyed on a species "
    .. "that does not exist can never fire)")
end

-- The two exclusions named outright, so dropping one from the table is not
-- the same as never having decided about it.  Corviknight is out for want of
-- front art; the Low Key and Rapid Strike Gigantamax records are out because
-- their art is filed under the base species, where a mon of that species key
-- would never find it.
T.eq(gigantamax.CORVIKNIGHT, nil,
  "Corviknight is not wired -- its Gigantamax has no front art")
T.eq(gigantamax.TOXTRICITY, "TOXTRICITY_AMPED_GMAX",
  "Toxtricity wires the Amped Gigantamax, the one its base record is")
T.eq(gigantamax.URSHIFU, "URSHIFU_SINGLE_STRIKE_GMAX",
  "Urshifu wires the Single Strike Gigantamax, the one its base record is")
T.eq(gigantamax.TOXTRICITY_LOW_KEY, nil,
  "the Low Key variant is not wired under its own species key")
T.eq(gigantamax.URSHIFU_RAPID_STRIKE, nil,
  "the Rapid Strike variant is not wired under its own species key")

for _, formId in ipairs(formIds) do
  T.check(isRecordKey(formId), formId
    .. " is a record KEY in national.lua (data/megas.lua must name the "
    .. "record's key, not its `name` field)")
end

-- The mistake this test exists to catch: the old ids were the record's
-- `name` field (lowercase, hyphenated), not the key data.pokemon is indexed
-- by.  If any of these still matched as a key, the two patterns above would
-- not actually be distinguishing the two fields.
local displayNames = {
  "venusaur-mega", "charizard-mega-x", "charizard-mega-y",
  "blastoise-mega", "alakazam-mega", "gengar-mega",
}
for _, name in ipairs(displayNames) do
  T.check(not isRecordKey(name),
    name .. " is a display name and must NOT match as a record key")
end

T.finish("battle_forms_formids")
