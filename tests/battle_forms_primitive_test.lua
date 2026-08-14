package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Forms = dofile(MOD .. "/src/forms.lua")

-- Two species records differing only in base stats, so a stat change proves
-- the recompute ran rather than the re-key alone.
-- charizard-mega-x's name is deliberately NOT its base species' name here --
-- forms.lua only has to follow whatever the record says, the same as any
-- other field recompute reads; src/naming.lua (and its own suite) is what
-- makes the two agree in a real load.
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" }, name = "CHARIZARD" },
  ["charizard-mega-x"] = { baseStats = { hp = 78, attack = 130, defense = 111,
                                         speed = 100, special = 130 },
                           types = { "FIRE", "DRAGON" }, name = "MEGA-X-RAW" },
} }

local function battler()
  return { mon = { species = "CHARIZARD", level = 50,
                   dvs = { hp = 15, attack = 15, defense = 15,
                           speed = 15, special = 15 },
                   statExp = {} },
           sprite = "stale", isPlayer = false }
end

local b = battler()

T.eq(Forms.becomeForm(DATA, b, "charizard-mega-x"), true, "form change succeeds")
T.eq(b.mon.species, "charizard-mega-x", "species is re-keyed to the form")
T.check(b.mon.stats.attack > 100, "stats are recomputed from the form record")
T.eq(b.sprite, "stale", "no battle was given, so the cached picture is left alone")

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

-- The picture is proven genuinely reloaded through the real engine
-- constructor, not through a fake standing in for whatever forms.lua
-- happens to call.  This suite runs with the engine checkout as cwd, so
-- "src.battle.BattleState" and "tests.modkit" resolve to the real files --
-- the identical relative path forms.lua's own require resolves at runtime.
-- tests.modkit registers a headless love stub so BattleState's image loader
-- runs without a real love2d window, and T.fixtures gives species backed by
-- real sprite files under tests/fixture_data/assets so two different
-- species genuinely build two different cached image objects.
local T2 = require("tests.modkit")
local RealBattleState = require("src.battle.BattleState")
local fixtureData = T2.fixtures.fresh()

local function fixtureMon(species)
  return { species = species, level = 10,
           dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
           statExp = {} }
end

-- The picture actually built for a species, independent of forms.lua, to
-- compare against what becomeForm/revertForm leave on the battler.
local function realSprite(species, isPlayer)
  return RealBattleState.makeBattler(fixtureData, fixtureMon(species), isPlayer).sprite
end

local baseSprite = realSprite("FIXMON_A", false)
local formSprite = realSprite("FIXMON_B", false)
T.check(baseSprite ~= formSprite,
  "sanity: the two fixture species really do build distinct pictures")

-- becomeForm reloads the picture through makeBattler's own-palette path,
-- never through speciesSprite's forced Transform gray.
local withBattle = { mon = fixtureMon("FIXMON_A"), sprite = "stale", isPlayer = false }
local battle1 = { data = fixtureData }
T.eq(Forms.becomeForm(fixtureData, withBattle, "FIXMON_B", battle1), true,
  "form change succeeds with a battle in hand")
T.eq(withBattle.sprite, formSprite,
  "the picture is rebuilt through makeBattler for the new species")

-- revertForm reloads too, and gets back the BASE species' picture.
T.eq(Forms.revertForm(withBattle, fixtureData, battle1), true, "revert succeeds")
T.eq(withBattle.sprite, baseSprite, "revert rebuilds the base species' picture")

-- A battle with no `.data` (the fixture shape every other suite's fake
-- battle uses, since none of them touch the picture today) still succeeds:
-- makeBattler(nil, ...) genuinely errors indexing a nil data table, the
-- pcall around the build catches it, and the previous picture survives.
local noData = { mon = fixtureMon("FIXMON_A"), sprite = "stale", isPlayer = false }
T.eq(Forms.becomeForm(fixtureData, noData, "FIXMON_B", {}), true,
  "a battle-shaped table with no data still succeeds")
T.eq(noData.sprite, "stale", "and leaves the picture alone")

-- A species record makeBattler can build a battler for, but that resolves
-- to no sprite asset at all (no dex/sprite metadata) -- must not blank the
-- picture the way an unconditional overwrite would.
fixtureData.pokemon.FIXMON_GHOST = {
  baseStats = fixtureData.pokemon.FIXMON_A.baseStats,
  types = fixtureData.pokemon.FIXMON_A.types,
  name = "FIXMON GHOST",
}
local missingPic = { mon = fixtureMon("FIXMON_A"), sprite = "stale", isPlayer = false }
T.eq(Forms.becomeForm(fixtureData, missingPic, "FIXMON_GHOST", battle1), true,
  "form change succeeds even when the new species has no sprite asset")
T.eq(missingPic.sprite, "stale",
  "a build that resolves with no sprite leaves the previous picture intact")

-- BattleState itself unavailable (an older engine, or the mod running
-- somewhere engine_internals was never granted) degrades the same way,
-- proven by forcing the real require machinery to fail rather than
-- special-casing forms.lua's own pcall.
local savedLoaded = package.loaded["src.battle.BattleState"]
package.loaded["src.battle.BattleState"] = nil
package.preload["src.battle.BattleState"] = function()
  error("battle_forms test: forced require failure")
end
local unavailable = { mon = fixtureMon("FIXMON_A"), sprite = "stale", isPlayer = false }
T.eq(Forms.becomeForm(fixtureData, unavailable, "FIXMON_B", battle1), true,
  "form change still succeeds when BattleState cannot be required at all")
T.eq(unavailable.sprite, "stale", "and the picture is left alone")
package.preload["src.battle.BattleState"] = nil
package.loaded["src.battle.BattleState"] = savedLoaded

-- battler.name follows the form record and is restored on revert, so the
-- HUD does not wait for the next send-out to catch up.
local named = battler()
named.name = "CHARIZARD"
T.eq(Forms.becomeForm(DATA, named, "charizard-mega-x"), true, "form change succeeds")
T.eq(named.name, "MEGA-X-RAW", "the HUD name follows the form record")
T.eq(Forms.revertForm(named, DATA), true, "revert succeeds")
T.eq(named.name, "CHARIZARD", "and is restored to the base species' name")

-- A nickname outranks both the base and the form's own name throughout.
local nicknamed = battler()
nicknamed.mon.nickname = "SPARKY"
nicknamed.name = "SPARKY"
T.eq(Forms.becomeForm(DATA, nicknamed, "charizard-mega-x"), true,
  "form change succeeds for a nicknamed mon")
T.eq(nicknamed.name, "SPARKY", "the nickname survives the form change")
T.eq(Forms.revertForm(nicknamed, DATA), true, "revert succeeds")
T.eq(nicknamed.name, "SPARKY", "and survives the revert too")

T.finish("battle_forms_primitive")
