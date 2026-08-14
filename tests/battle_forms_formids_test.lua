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
for _, table_ in ipairs({ megas, primals }) do
  for _, byItem in pairs(table_) do
    for _, formId in pairs(byItem) do
      formIds[#formIds + 1] = formId
    end
  end
end
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
