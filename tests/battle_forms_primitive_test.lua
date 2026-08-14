package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Forms = dofile(MOD .. "/src/forms.lua")

-- Two records under the SAME species differing only in base stats and
-- types, so a stat/type change proves the override ran and mon.species
-- never moving proves the re-key model is really gone. The mega record's
-- `name` is deliberately NOT its base species' name here (matching National
-- Dex's real records, which carry the source data's raw slug) -- nothing in
-- forms.lua may touch battler.name at all, so the base species' name simply
-- never stops being what the battler shows.
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" }, name = "CHARIZARD" },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, name = "charizard-mega-x",
                       form = "MEGA_X" },
} }

local function battler()
  local mon = { species = "CHARIZARD", level = 50,
                dvs = { hp = 15, attack = 15, defense = 15,
                        speed = 15, special = 15 },
                statExp = {} }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  return { mon = mon, curStats = mon.stats, curTypes = DATA.pokemon.CHARIZARD.types,
           name = "CHARIZARD", sprite = "stale", isPlayer = false }
end

local b = battler()
local baseStats, baseTypes = b.curStats, b.curTypes

T.eq(Forms.becomeForm(DATA, b, "CHARIZARD_MEGA_X"), true, "form change succeeds")
T.eq(b.mon.species, "CHARIZARD", "species is left completely alone")
T.eq(b.mon.form, "MEGA_X", "the mon is marked with the form record's own `form` field")
T.check(b.curStats.attack > 100, "curStats are overridden from the form record")
T.eq(b.curTypes[2], "DRAGON", "curTypes are overridden from the form record")
T.eq(b.mon.stats, baseStats, "mon.stats (the HP bar's denominator) is never touched")
T.eq(b.mon.stats.attack, 84, "mon.stats keeps its original values")
T.eq(b.name, "CHARIZARD", "battler.name is never touched -- it was never wrong to begin with")

T.eq(Forms.revertForm(b, DATA), true, "revert succeeds")
T.eq(b.mon.form, nil, "the form marker is cleared, not set to false or empty")
T.eq(b.curStats, baseStats, "curStats is restored to the mon's own untouched stat block")
T.eq(b.curTypes, baseTypes, "curTypes is restored to the base species' own types")

T.eq(Forms.revertForm(b, DATA), nil, "reverting an unchanged battler is a no-op")

local missing = battler()
local missingOk, missingReason = Forms.becomeForm(DATA, missing, "NOSUCHFORM")
T.eq(missingOk, nil, "an unknown form id refuses rather than half-applying")
T.eq(missingReason, "no_record", "and reports why")
T.eq(missing.mon.species, "CHARIZARD", "a refused change leaves the species alone")
T.eq(missing.mon.form, nil, "a refused change leaves the form marker alone")

-- The refusal this rework exists to add: a record that exists but was never
-- given its own `form` field would draw nothing the sprite registry could
-- resolve (base.forms[nil] is never a real lookup) and must not be
-- half-applied by marking the mon anyway.
local NO_FORM_DATA = { pokemon = {
  CHARIZARD = DATA.pokemon.CHARIZARD,
  CHARIZARD_MEGA_X = { baseStats = DATA.pokemon.CHARIZARD_MEGA_X.baseStats,
                       types = DATA.pokemon.CHARIZARD_MEGA_X.types },
} }
local noFormField = battler()
local ok, reason = Forms.becomeForm(NO_FORM_DATA, noFormField, "CHARIZARD_MEGA_X")
T.eq(ok, nil, "a record with no `form` field refuses rather than half-applying")
T.eq(reason, "no_form_field", "and reports why")
T.eq(noFormField.mon.form, nil, "the mon is left unmarked")
T.eq(noFormField.curStats, noFormField.mon.stats, "and curStats is left alone")

-- The bug this file exists to pin: a mega survives switching out, and the
-- engine builds a fresh battler on the way back in. mon.form lives on the
-- MON, not the battler, so it is the one thing that must and does survive
-- being wrapped in a brand-new battler object.
local switched = battler()
Forms.becomeForm(DATA, switched, "CHARIZARD_MEGA_X")
local returned = { mon = switched.mon, curStats = switched.mon.stats,
                   curTypes = DATA.pokemon.CHARIZARD.types, sprite = "fresh" }
T.eq(returned.mon.form, "MEGA_X",
  "the form marker survives being wrapped in a new battler")
T.eq(Forms.revertForm(returned, DATA), true,
  "a battler rebuilt on send-out can still revert its mon")
T.eq(returned.mon.form, nil, "and the marker comes back off")

-- Condition-driven forms flip back and forth for as long as a battle lasts,
-- and this is the property that lets them: nothing is cached across a change.
-- becomeForm derives curStats from the target record every time and
-- revertForm derives them back from mon.stats and the base record every time,
-- so A -> B -> A -> B is four independent derivations rather than one
-- remembered "before" being handed round -- which is what a primitive built
-- only for mega evolution, where a mon changes at most once, could plausibly
-- have got away with.
local flipper = battler()
local flipBase, flipTypes = flipper.mon.stats, DATA.pokemon.CHARIZARD.types
for round = 1, 4 do
  T.eq(Forms.becomeForm(DATA, flipper, "CHARIZARD_MEGA_X"), true,
    "round " .. round .. ": the same battler changes form again")
  T.eq(flipper.mon.form, "MEGA_X", "round " .. round .. ": and is marked again")
  T.check(flipper.curStats ~= flipBase,
    "round " .. round .. ": curStats is a freshly computed block")
  T.check(flipper.curStats.attack > flipBase.attack,
    "round " .. round .. ": computed from the form record, not from a cache")
  T.eq(flipper.curTypes, DATA.pokemon.CHARIZARD_MEGA_X.types,
    "round " .. round .. ": and the form's types are in force")

  T.eq(Forms.revertForm(flipper, DATA), true,
    "round " .. round .. ": and reverts again")
  T.eq(flipper.mon.form, nil, "round " .. round .. ": the mark comes off again")
  T.eq(flipper.curStats, flipBase,
    "round " .. round .. ": curStats is the mon's own block again")
  T.eq(flipper.curTypes, flipTypes,
    "round " .. round .. ": and curTypes the base species' again")
end
T.eq(flipper.mon.stats, flipBase,
  "and four round trips left the mon's own stat block exactly where it was")
T.eq(flipper.mon.stats.attack, 84, "with its original values")

-- The battle-end sweep walks the party, where there is no battler at all.
local benched = battler()
Forms.becomeForm(DATA, benched, "CHARIZARD_MEGA_X")
T.eq(Forms.revertMon(benched.mon), true, "a mon reverts without a battler")
T.eq(benched.mon.form, nil, "a benched mon is restored too")
T.eq(Forms.revertMon(benched.mon), nil, "sweeping an untransformed mon is a no-op")

-- The picture is proven genuinely reloaded through the real engine
-- constructor, not through a fake standing in for whatever forms.lua
-- happens to call. This suite runs with the engine checkout as cwd, so
-- "src.battle.BattleState" and "tests.modkit" resolve to the real files.
-- tests.modkit registers a headless love stub so BattleState's image loader
-- runs without a real love2d window.
local T2 = require("tests.modkit")
local RealBattleState = require("src.battle.BattleState")
local fixtureData = T2.fixtures.fresh()
fixtureData.pokemon.FIXMON_A_MEGA = {
  baseStats = fixtureData.pokemon.FIXMON_A.baseStats,
  types = fixtureData.pokemon.FIXMON_A.types,
  name = "fixmon-a-mega",
  form = "MEGA",
}

-- hp and stats are not decoration: makeBattler computes the HP bar's own
-- pixel length at construction (Timing.hpBarPixels off mon.stats.hp), so a
-- mon without them crashes the constructor rather than building a battler.
-- A real party mon always carries both; Stats.ensure sees to it.
local function fixtureMon(species)
  return { species = species, level = 10, hp = 20,
           stats = { hp = 20, attack = 10, defense = 10, speed = 10, special = 10 },
           dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
           statExp = {} }
end

-- becomeForm reloads the picture through makeBattler's own-palette path.
-- Species never changes, so the two builds compared here are of the SAME
-- mon (mon.form set beforehand) -- proving reloadSprite genuinely calls the
-- real constructor rather than leaving the stale sentinel in place, not
-- proving form-aware art resolution, which needs a sprite-mod hook this
-- bare fixture harness does not load.
local withBattle = { mon = fixtureMon("FIXMON_A"), sprite = "stale", isPlayer = false }
local battle1 = { data = fixtureData }
T.eq(Forms.becomeForm(fixtureData, withBattle, "FIXMON_A_MEGA", battle1), true,
  "form change succeeds with a battle in hand")
T.eq(withBattle.mon.form, "MEGA", "the mon is marked")
local rebuilt = RealBattleState.makeBattler(fixtureData, withBattle.mon, false)
T.eq(withBattle.sprite, rebuilt.sprite,
  "the picture is rebuilt through makeBattler on the (now-marked) mon")
T.check(withBattle.sprite ~= "stale", "and is not the stale sentinel")

-- revertForm reloads too, through the same path, on the now-unmarked mon.
T.eq(Forms.revertForm(withBattle, fixtureData, battle1), true, "revert succeeds")
local revertedBuild = RealBattleState.makeBattler(fixtureData, withBattle.mon, false)
T.eq(withBattle.sprite, revertedBuild.sprite,
  "revert rebuilds the picture through makeBattler on the unmarked mon")

-- A battle with no `.data` (the fixture shape every other suite's fake
-- battle uses, since none of them touch the picture today) still succeeds:
-- makeBattler(nil, ...) genuinely errors indexing a nil data table, the
-- pcall around the build catches it, and the previous picture survives.
local noData = { mon = fixtureMon("FIXMON_A"), sprite = "stale", isPlayer = false }
T.eq(Forms.becomeForm(fixtureData, noData, "FIXMON_A_MEGA", {}), true,
  "a battle-shaped table with no data still succeeds")
T.eq(noData.sprite, "stale", "and leaves the picture alone")

-- A mon whose BASE species resolves to no sprite asset at all (no
-- dex/sprite metadata) must not have its picture blanked by an
-- unconditional overwrite. Species never changes under this model, so it is
-- the base species' own art, not the form record's, that the rebuild reads
-- -- the form record here carries no sprite fields of its own on purpose,
-- to prove reloadSprite never looks at them.
fixtureData.pokemon.FIXMON_GHOST = {
  baseStats = fixtureData.pokemon.FIXMON_A.baseStats,
  types = fixtureData.pokemon.FIXMON_A.types,
  name = "FIXMON GHOST",
}
fixtureData.pokemon.FIXMON_GHOST_MEGA = {
  baseStats = fixtureData.pokemon.FIXMON_A.baseStats,
  types = fixtureData.pokemon.FIXMON_A.types,
  name = "fixmon-ghost-mega",
  form = "MEGA",
}
local missingPic = { mon = fixtureMon("FIXMON_GHOST"), sprite = "stale", isPlayer = false }
T.eq(Forms.becomeForm(fixtureData, missingPic, "FIXMON_GHOST_MEGA", battle1), true,
  "form change succeeds even when the base species has no sprite asset")
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
T.eq(Forms.becomeForm(fixtureData, unavailable, "FIXMON_A_MEGA", battle1), true,
  "form change still succeeds when BattleState cannot be required at all")
T.eq(unavailable.sprite, "stale", "and the picture is left alone")
package.preload["src.battle.BattleState"] = nil
package.loaded["src.battle.BattleState"] = savedLoaded

T.finish("battle_forms_primitive")
