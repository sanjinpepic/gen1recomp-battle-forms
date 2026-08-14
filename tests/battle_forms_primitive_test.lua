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

-- The bug this file exists to pin: a mega survives switching out, and the
-- engine builds a fresh battler on the way back in.  A marker held on the
-- battler would be lost there, and the mon would never revert.
local switched = battler()
Forms.becomeForm(DATA, switched, "charizard-mega-x")
local returned = { mon = switched.mon, sprite = "fresh" }
T.eq(returned.mon.species, "charizard-mega-x",
  "the form survives being wrapped in a new battler")
T.eq(Forms.revertForm(returned, DATA), true,
  "a battler rebuilt on send-out can still revert its mon")
T.eq(returned.mon.species, "CHARIZARD", "and the base species comes back")

-- The battle-end sweep walks the party, where there is no battler at all.
local benched = battler()
Forms.becomeForm(DATA, benched, "charizard-mega-x")
T.eq(Forms.revertMon(DATA, benched.mon), true, "a mon reverts without a battler")
T.eq(benched.mon.species, "CHARIZARD", "a benched mon is restored too")
T.eq(Forms.revertMon(DATA, benched.mon), nil, "sweeping an untransformed mon is a no-op")

T.finish("battle_forms_primitive")
