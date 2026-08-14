-- Validates every form id in data/megas.lua against the real National Dex
-- species data on disk.  This is the test whose absence let a display name
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

local megas = dofile(MOD .. "/data/megas.lua")

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
for _, byStone in pairs(megas) do
  for _, formId in pairs(byStone) do
    formIds[#formIds + 1] = formId
  end
end
table.sort(formIds)

T.check(#formIds > 0, "data/megas.lua names at least one form")

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
