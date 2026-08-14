package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Forms = dofile(MOD .. "/src/forms.lua")

-- Two species records differing only in base stats, so a stat change proves
-- the recompute ran rather than the re-key alone.
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  ["charizard-mega-x"] = { baseStats = { hp = 78, attack = 130, defense = 111,
                                         speed = 100, special = 130 },
                           types = { "FIRE", "DRAGON" } },
} }

local function battler()
  return { mon = { species = "CHARIZARD", level = 50,
                   dvs = { hp = 15, attack = 15, defense = 15,
                           speed = 15, special = 15 },
                   statExp = {} },
           sprite = "stale" }
end

local b = battler()

T.eq(Forms.becomeForm(DATA, b, "charizard-mega-x"), true, "form change succeeds")
T.eq(b.mon.species, "charizard-mega-x", "species is re-keyed to the form")
T.check(b.mon.stats.attack > 100, "stats are recomputed from the form record")
T.eq(b.sprite, nil, "the cached battle picture is invalidated")

local megaAttack = b.mon.stats.attack

T.eq(Forms.revertForm(b, DATA), true, "revert succeeds")
T.eq(b.mon.species, "CHARIZARD", "species is restored")
T.check(b.mon.stats.attack < megaAttack, "stats are recomputed back")

T.eq(Forms.revertForm(b, DATA), nil, "reverting an unchanged battler is a no-op")

local missing = battler()
T.eq(Forms.becomeForm(DATA, missing, "nosuchform"), nil,
  "an unknown form id refuses rather than half-applying")
T.eq(missing.mon.species, "CHARIZARD", "a refused change leaves the mon alone")

T.finish("battle_forms_primitive")
