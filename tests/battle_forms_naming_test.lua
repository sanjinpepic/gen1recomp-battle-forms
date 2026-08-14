-- Exercised through the real Registry, the same way battle_forms_shop_test
-- proves a patch actually merges rather than just recording the call --
-- forms.lua's own suite pins the OTHER half of this bug (the HUD field), this
-- one pins the shared species record src/naming.lua patches at load.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Naming = dofile(MOD .. "/src/naming.lua")
local megas = dofile(MOD .. "/data/megas.lua")

local Registry = require("src.mods.Registry")
local Schemas = require("src.mods.Schemas")

-- Base species keep their real HUD names; the six mega records carry the
-- National Dex source data's slug, exactly the shape that shipped the bug --
-- the "MEGA" fields are along for the ride, to prove a patch merges onto the
-- record rather than replacing it wholesale.
local base = {
  VENUSAUR = { name = "VENUSAUR" },
  VENUSAUR_MEGA = { name = "venusaur-mega", types = { "GRASS", "POISON" } },
  CHARIZARD = { name = "CHARIZARD" },
  CHARIZARD_MEGA_X = { name = "charizard-mega-x", types = { "FIRE", "DRAGON" } },
  CHARIZARD_MEGA_Y = { name = "charizard-mega-y", types = { "FIRE", "FLYING" } },
  BLASTOISE = { name = "BLASTOISE" },
  BLASTOISE_MEGA = { name = "blastoise-mega", types = { "WATER" } },
  ALAKAZAM = { name = "ALAKAZAM" },
  ALAKAZAM_MEGA = { name = "alakazam-mega", types = { "PSYCHIC" } },
  GENGAR = { name = "GENGAR" },
  GENGAR_MEGA = { name = "gengar-mega", types = { "GHOST", "POISON" } },
}

local function freshMod(log)
  local reg = Registry.new("pokemon", Schemas.REGISTRIES.pokemon)
  reg.base = function() return base end
  local mod = {
    content = { pokemon = {
      get = function(_, id) return reg:get(id) end,
      patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
    } },
    log = log,
  }
  return mod, reg
end

local logged = {}
local mod, reg = freshMod({
  error = function(_, fmt, ...) logged[#logged + 1] = fmt:format(...) end,
})

Naming.install(mod, megas)

T.eq(#logged, 0, "every base species in megas.lua had a name on record")

-- Every mega form in data/megas.lua resolves to its base species' name --
-- all six, not just Charizard's pair.
local checked = 0
for baseId, byStone in pairs(megas) do
  local baseName = reg:get(baseId).name
  for _, formId in pairs(byStone) do
    checked = checked + 1
    T.eq(reg:get(formId).name, baseName,
      formId .. " takes its base species' name (" .. tostring(baseName) .. ")")
  end
end
T.eq(checked, 6, "all six mega forms in data/megas.lua were checked")

-- The patch merges onto the record rather than replacing it -- a form's
-- other fields (its own types, unlike its base) survive.
T.eq(reg:get("CHARIZARD_MEGA_X").types[1], "FIRE",
  "patching name does not clobber the form's own type table")
T.eq(reg:get("CHARIZARD_MEGA_X").types[2], "DRAGON",
  "the form keeps its own second type too")

-- The base table itself is never touched -- a second mod reading the base
-- species must not see the mega naming baked into what it thinks is vanilla.
T.eq(base.CHARIZARD_MEGA_X.name, "charizard-mega-x",
  "installing never mutates the base record")

-- A guard that refuses says so: a base species with no record on file must
-- not silently leave its forms holding the raw slug forever.
local gapLogged = {}
local gapMod, gapReg = freshMod({
  error = function(_, fmt, ...) gapLogged[#gapLogged + 1] = fmt:format(...) end,
})
local megasWithGap = { MISSINGNO = { RARETITE = "MISSINGNO_MEGA" } }
Naming.install(gapMod, megasWithGap)
T.eq(#gapLogged, 1, "a base species with no record logs a refusal")
T.eq(gapReg:get("MISSINGNO_MEGA"), nil,
  "and nothing is patched onto a form with no base name to give it")

T.finish("battle_forms_naming")
