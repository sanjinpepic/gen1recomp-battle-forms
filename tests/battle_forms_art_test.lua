-- Validates that every form this mod wires -- data/megas.lua and
-- data/primals.lua alike -- has art in dev/data/sprites/generated/formart.lua,
-- keyed [BASE].forms[FORM].
--
-- The scope rule for both tables is "wire it if it has art" -- a form added
-- later without checking that first falls back to its base species' picture,
-- which is playable but wrong, and wrong quietly.  This is the guard that
-- makes it loud: a form named in either table with no matching formart.lua
-- entry fails here instead of shipping as a reskinned base species.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Megaset = dofile(MOD .. "/src/megaset.lua")
-- The whole roster: every check below holds for any wired mega, and the
-- OFFICIAL/ALL split is pinned in the eligibility suite.  A form with no art
-- is as wrong for a primal as for a mega, so both tables are swept.
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)
local primals = dofile(MOD .. "/data/primals.lua")
-- Reshaped to the pairing tables' species -> key -> form so the one sweep
-- below covers all three; a conditional row has no item, so its own key is
-- only ever the placeholder this loop never reads.
local conditional = {}
for species, row in pairs(dofile(MOD .. "/data/conditional.lua")) do
  conditional[species] = { CONDITION = row.form }
end

local NATIONAL_DEX = MOD .. "/../national_dex_mod/data/species/generated/national.lua"
local FORM_ART = MOD .. "/../data/sprites/generated/formart.lua"

local dexHandle = io.open(NATIONAL_DEX, "rb")
if not dexHandle then
  print("battle_forms_art: SKIPPED -- " .. NATIONAL_DEX
    .. " not found; check out national_dex_mod alongside battle_forms_mod "
    .. "to verify wired forms have art")
  os.exit(0)
end
local dexText = dexHandle:read("*a")
dexHandle:close()

local artHandle = io.open(FORM_ART, "rb")
if not artHandle then
  print("battle_forms_art: SKIPPED -- " .. FORM_ART
    .. " not found; build the form art index to verify wired forms have art")
  os.exit(0)
end
artHandle:close()

local formArt = dofile(FORM_ART)

-- Records are id, name, dex, ..., form, baseSpecies, in that fixed order, so
-- the first `form = "..."` after a record's opening brace is that record's
-- own field -- well before the next record's -- and never some other
-- record's leaking through.
local function formSuffixFor(id)
  local escaped = id:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")
  local blockStart = ("\n" .. dexText):find("\n%s*" .. escaped .. "%s*=%s*{")
  if not blockStart then return nil end
  local _, _, suffix = dexText:find('form%s*=%s*"([^"]+)"', blockStart)
  return suffix
end

local checked, primalsChecked, conditionalChecked = 0, 0, 0
for _, wired in ipairs({ { table_ = megas }, { table_ = primals, primal = true },
                         { table_ = conditional, conditional = true } }) do
  for base, byItem in pairs(wired.table_) do
    for _, formId in pairs(byItem) do
      checked = checked + 1
      if wired.primal then primalsChecked = primalsChecked + 1 end
      if wired.conditional then conditionalChecked = conditionalChecked + 1 end
      local suffix = formSuffixFor(formId)
      T.check(suffix ~= nil, formId .. " has a form suffix in national.lua")
      if suffix then
        local species = formArt[base]
        local forms = species and species.forms
        T.check(forms and forms[suffix] ~= nil,
          base .. ".forms." .. suffix .. " (" .. formId
          .. ") has an entry in formart.lua -- a wired form with no art "
          .. "renders as its base species")
      end
    end
  end
end

T.check(checked > 0, "at least one wired form was checked against formart.lua")
T.eq(primalsChecked, 2, "both primal forms were checked against formart.lua")
T.eq(conditionalChecked, 8,
  "all eight conditional forms were checked against formart.lua")

T.finish("battle_forms_art")
