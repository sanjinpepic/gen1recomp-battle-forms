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
-- data/gigantamax.lua is species -> form id, flatter still: a Gigantamax has
-- neither an item nor a condition to key on.  Reshaped the same way so the one
-- sweep below covers it too.
local gigantamax = {}
for species, formId in pairs(dofile(MOD .. "/data/gigantamax.lua")) do
  gigantamax[species] = { GIGANTAMAX = formId }
end
-- data/persistent.lua is already species -> item -> form, so it needs no
-- reshaping.  It is swept under the STRICTER of the two rules below -- both
-- faces, not merely an entry -- because a form with a front picture and no back
-- is invisible on the player's own side of the battle, and this is the one
-- family where that would not end when the battle did.
local persistent = dofile(MOD .. "/data/persistent.lua")
-- data/fusion.lua is species -> item -> PARTNER -> form, one level deeper than
-- everything above, because the partner is half of what the form is.  Flattened
-- on the partner so the one sweep below covers it, and swept under the same
-- stricter rule as the persistent table and for a sharper version of the same
-- reason: a fused Pokemon wears its form until the player separates it, and a
-- second Pokemon is sitting in the PC for as long as it does.
local fusion = {}
for species, byItem in pairs(dofile(MOD .. "/data/fusion.lua")) do
  fusion[species] = {}
  for _, byPartner in pairs(byItem) do
    for partner, formId in pairs(byPartner) do fusion[species][partner] = formId end
  end
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
local gigantamaxChecked, persistentChecked, fusionChecked = 0, 0, 0
for _, wired in ipairs({ { table_ = megas }, { table_ = primals, primal = true },
                         { table_ = conditional, conditional = true },
                         { table_ = gigantamax, gigantamax = true },
                         { table_ = persistent, persistent = true },
                         { table_ = fusion, fusion = true } }) do
  for base, byItem in pairs(wired.table_) do
    for _, formId in pairs(byItem) do
      checked = checked + 1
      if wired.primal then primalsChecked = primalsChecked + 1 end
      if wired.conditional then conditionalChecked = conditionalChecked + 1 end
      if wired.gigantamax then gigantamaxChecked = gigantamaxChecked + 1 end
      if wired.persistent then persistentChecked = persistentChecked + 1 end
      if wired.fusion then fusionChecked = fusionChecked + 1 end
      local suffix = formSuffixFor(formId)
      T.check(suffix ~= nil, formId .. " has a form suffix in national.lua")
      if suffix then
        local species = formArt[base]
        local forms = species and species.forms
        local entry = forms and forms[suffix]
        T.check(entry ~= nil,
          base .. ".forms." .. suffix .. " (" .. formId
          .. ") has an entry in formart.lua -- a wired form with no art "
          .. "renders as its base species")
        -- Both faces, for the Gigantamax table only.  An entry is not the
        -- same as art: Corviknight's Gigantamax has a back picture and no
        -- front, and half an entry passes the check above while showing the
        -- base species from one side.  This is the check that keeps it out.
        if (wired.gigantamax or wired.persistent or wired.fusion) and entry then
          T.check(entry.front ~= nil,
            base .. ".forms." .. suffix .. " has FRONT art")
          T.check(entry.back ~= nil,
            base .. ".forms." .. suffix .. " has BACK art")
        end
      end
    end
  end
end

T.check(checked > 0, "at least one wired form was checked against formart.lua")
T.eq(primalsChecked, 2, "both primal forms were checked against formart.lua")
T.eq(conditionalChecked, 8,
  "all eight conditional forms were checked against formart.lua")
T.eq(gigantamaxChecked, 31,
  "all 31 wired Gigantamax forms were checked against formart.lua")
T.eq(persistentChecked, 5,
  "all five wired persistent forms were checked against formart.lua")
T.eq(fusionChecked, 6,
  "all six fusion result forms were checked against formart.lua")

-- The two exclusions, pinned as facts about the data rather than as prose in
-- data/gigantamax.lua's header.  If a later art build fills Corviknight's
-- front in, or the form art index starts filing a variant's art under its own
-- species key, this fails and says the table can grow.
do
  local corviknight = formArt.CORVIKNIGHT and formArt.CORVIKNIGHT.forms
    and formArt.CORVIKNIGHT.forms.GMAX
  T.check(corviknight ~= nil,
    "CORVIKNIGHT.forms.GMAX exists in formart.lua")
  T.check(corviknight == nil or corviknight.front == nil,
    "CORVIKNIGHT.forms.GMAX still has no front art -- the reason it is not "
    .. "wired; wire it once this stops being true")
  for _, variant in ipairs({ "TOXTRICITY_LOW_KEY", "URSHIFU_RAPID_STRIKE" }) do
    T.check(formArt[variant] == nil,
      variant .. " has no form art entry of its own -- its Gigantamax art is "
      .. "filed under the base species, which is why the variant is not wired")
  end
end

T.finish("battle_forms_art")
