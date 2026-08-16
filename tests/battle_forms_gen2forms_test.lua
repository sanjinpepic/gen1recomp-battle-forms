-- Gen 2's form primitive: the equivalent of src/forms.lua for a game with no
-- battler wrapper at all.  mon.species is still never touched -- see
-- src/gen2forms.lua's own header -- but Gen 2 has nothing else to override:
-- Battle:battleStat reads mon.stats directly (game/src/battle/gen2/Battle.lua
-- :761-762), so THIS module mutates mon.stats in place the way the engine's
-- own Transform does (:2149-2156) and restores it the same way (:2178-2194),
-- except there is nothing to cache for the restore -- mon.species never
-- moves, so data.pokemon[mon.species].baseStats plus the mon's own untouched
-- dvs/level/statExp recompute the exact original numbers on demand
-- (Mon.stats, game/src/battle/gen2/Mon.lua:67), the same "nothing was ever
-- cached" property src/forms.lua's own revertForm relies on for Gen 1.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Forms2 = dofile(MOD .. "/src/gen2forms.lua")

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

-- Two records under the same species, differing only in base stats and
-- types -- the same shape battle_forms_primitive_test.lua uses to prove the
-- Gen 1 primitive, so a stat/type change here proves the override ran for
-- the identical reason.  Gen 2 shape: baseStats splits specialAttack /
-- specialDefense (game/src/mods/Schemas.lua's gen2Fields, :780-818) rather
-- than carrying one `special` -- this mod's OWN data/megas.lua does not
-- carry that split yet (it is still Gen 1-shaped, proven by
-- battle_forms_primitive_test.lua's identical fixture using `special`), so a
-- real Gen 2 form record for this primitive has yet to be written; this
-- fixture is shaped the way data.pokemon already looks on a Gold boot,
-- whichever mod eventually supplies the row.
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                              specialAttack = 85, specialDefense = 85 },
                types = { "FIRE", "FLYING" }, name = "CHARIZARD" },
  -- baseStats.hp is DELIBERATELY different from CHARIZARD's own (real Mega
  -- Charizard X keeps the same 78 in the mainline games) so a test that
  -- forgets to exclude hp from the copied stat keys has something to catch:
  -- with matching hp values the guard would pass by accident.
  CHARIZARD_MEGA_X = { baseStats = { hp = 160, attack = 130, defense = 111,
                                     speed = 100, specialAttack = 130,
                                     specialDefense = 85 },
                       types = { "FIRE", "DRAGON" }, name = "charizard-mega-x",
                       form = "MEGA_X" },
} }

-- The real engine module, not a fixture guess: the mon's own starting
-- stats.hp/attack/... are computed through the exact function becomeForm and
-- revertMon call internally (Mon.stats, game/src/battle/gen2/Mon.lua:67), so
-- a test failure here means the primitive's math disagrees with itself, not
-- that a hand-typed fixture drifted from the real formula.
local Mon = require("src.battle.gen2.Mon")

local DVS = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 }
local STAT_EXP = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }
local LEVEL = 50
local BASE_STATS = Mon.stats(DATA.pokemon.CHARIZARD.baseStats, DVS, LEVEL, STAT_EXP)

local function mon()
  return {
    species = "CHARIZARD", level = LEVEL, exp = 125000,
    dvs = deepcopy(DVS), statExp = deepcopy(STAT_EXP),
    stats = deepcopy(BASE_STATS),
    hp = BASE_STATS.hp, maxHp = BASE_STATS.hp, catchRate = 45, status = nil,
    moves = { { id = "FLAMETHROWER", pp = 15 }, { id = "SLASH", pp = 20 } },
  }
end

-- --- becomeForm: applies stats and types, marks the mon, touches nothing else

local m = mon()
local snapshot = deepcopy(m)

T.eq(Forms2.becomeForm(DATA, m, "CHARIZARD_MEGA_X"), true, "form change succeeds")
T.eq(m.species, "CHARIZARD", "species is left completely alone")
T.eq(m.form, "MEGA_X", "the mon is marked with the form record's own `form` field")
T.eq(m.hp, snapshot.hp, "current hp is never touched")
T.eq(m.maxHp, snapshot.maxHp, "maxHp (the HP bar's denominator) is never touched")
T.same(m.moves, snapshot.moves, "the move list is never touched")
T.check(m.stats.attack > snapshot.stats.attack,
  "mon.stats.attack is overridden from the form record")
T.eq(m.stats.hp, snapshot.stats.hp,
  "mon.stats.hp is never touched even though the rest of mon.stats was")
T.same(m.formTypes, DATA.pokemon.CHARIZARD_MEGA_X.types,
  "the form's types are recorded for the type-resolution seam to read")

-- --- revert: exact, byte-identical round trip

T.eq(Forms2.revertMon(m, DATA), true, "revert succeeds")
T.same(m, snapshot, "a full apply-then-revert cycle leaves the mon byte-identical")

T.eq(Forms2.revertMon(m, DATA), nil, "reverting an unchanged mon is a no-op")

-- --- refusals: never half-applied

local missing = mon()
local missingSnapshot = deepcopy(missing)
local missingOk, missingReason = Forms2.becomeForm(DATA, missing, "NOSUCHFORM")
T.eq(missingOk, nil, "an unknown form id refuses rather than half-applying")
T.eq(missingReason, "no_record", "and reports why")
T.same(missing, missingSnapshot, "a refused change leaves the mon untouched")

local NO_FORM_DATA = { pokemon = {
  CHARIZARD = DATA.pokemon.CHARIZARD,
  CHARIZARD_MEGA_X = { baseStats = DATA.pokemon.CHARIZARD_MEGA_X.baseStats,
                       types = DATA.pokemon.CHARIZARD_MEGA_X.types },
} }
local noFormField = mon()
local ok, reason = Forms2.becomeForm(NO_FORM_DATA, noFormField, "CHARIZARD_MEGA_X")
T.eq(ok, nil, "a record with no `form` field refuses rather than half-applying")
T.eq(reason, "no_form_field", "and reports why")
T.eq(noFormField.form, nil, "the mon is left unmarked")

local NO_STATS_DATA = { pokemon = {
  CHARIZARD = DATA.pokemon.CHARIZARD,
  CHARIZARD_MEGA_X = { types = DATA.pokemon.CHARIZARD_MEGA_X.types,
                       form = "MEGA_X" },
} }
local noStats = mon()
local statsOk, statsReason = Forms2.becomeForm(NO_STATS_DATA, noStats, "CHARIZARD_MEGA_X")
T.eq(statsOk, nil, "a record with no baseStats refuses rather than half-applying")
T.eq(statsReason, "no_base_stats", "and reports why")
T.eq(noStats.form, nil, "the mon is left unmarked")

-- --- flip A -> B -> A -> B, four times, nothing cached across a change

local flipper = mon()
local flipSnapshot = deepcopy(flipper)
for round = 1, 4 do
  T.eq(Forms2.becomeForm(DATA, flipper, "CHARIZARD_MEGA_X"), true,
    "round " .. round .. ": the same mon changes form again")
  T.eq(flipper.form, "MEGA_X", "round " .. round .. ": and is marked again")
  T.check(flipper.stats.attack > flipSnapshot.stats.attack,
    "round " .. round .. ": stats are freshly recomputed from the form record")

  T.eq(Forms2.revertMon(flipper, DATA), true, "round " .. round .. ": and reverts again")
  T.same(flipper, flipSnapshot, "round " .. round .. ": exactly back to the original")
end

-- --- revertForm is the same operation as revertMon: Gen 2 has no battler to
-- tell a fainting mon from a benched one, so both callers share one path.
local fainted = mon()
Forms2.becomeForm(DATA, fainted, "CHARIZARD_MEGA_X")
T.eq(Forms2.revertForm(fainted, DATA), true, "revertForm succeeds on a fainting mon")
T.same(fainted, mon(), "revertForm restores exactly the way revertMon does")

-- --- abnormal path: switching out and back in needs no reapply at all.
--
-- Gen 1's resolve.lua reapplies on battle.battler_switched because
-- BattleState.makeBattler builds a brand-new, form-blind battler at every
-- send-out. Gen 2 has no such reconstruction (Battle.lua only calls
-- Mon.refreshStats once, at Battle:new, for the whole party at once -- never
-- per switch), so a benched mon's mutated mon.stats and mon.form marker are
-- simply still sitting on the SAME table when it switches back in. This is
-- the property that removes the whole onBattlerSwitched dance Gen 1 needs.
local switched = mon()
Forms2.becomeForm(DATA, switched, "CHARIZARD_MEGA_X")
local afterSwitchOut = deepcopy(switched) -- nothing touches the mon on the way out
T.same(switched, afterSwitchOut, "switching out changes nothing by itself")
-- ...time passes, other mons take turns, `switched` is not the active mon...
local afterSwitchIn = switched -- switching back in is the SAME table, not a rebuild
T.eq(afterSwitchIn.form, "MEGA_X",
  "switching back in: the marker is still there with no reapply call")
T.check(afterSwitchIn.stats.attack > mon().stats.attack,
  "switching back in: the overridden stats are still there with no reapply call")
T.eq(Forms2.revertMon(afterSwitchIn, DATA), true, "and it still reverts cleanly later")

-- --- abnormal path: battle end sweeps the whole party, formed and plain alike

local party = { mon(), mon(), mon() }
party[2].species = "CHARIZARD"
Forms2.becomeForm(DATA, party[1], "CHARIZARD_MEGA_X")
-- party[2] and party[3] never transformed this battle.
for _, partyMon in ipairs(party) do Forms2.revertMon(partyMon, DATA) end
T.same(party[1], mon(), "the formed party member is swept back to its own stats")
T.same(party[2], mon(), "an untransformed party member is untouched by the sweep")
T.same(party[3], mon(), "and so is another")

-- --- abnormal path: the mod disabled mid-battle
--
-- Nothing here can run once the mod stops receiving events, so a mon left
-- mid-form keeps mon.form and its overridden mon.stats for the rest of that
-- one battle -- exactly the cosmetic risk src/forms.lua's own header accepts
-- for a lingering mon.form on Gen 1. What must still hold with no revert call
-- ever made: species and the move list, which nothing in this primitive ever
-- touches regardless of whether revert runs.
local abandoned = mon()
local abandonedSnapshot = deepcopy(abandoned)
Forms2.becomeForm(DATA, abandoned, "CHARIZARD_MEGA_X")
-- ...the mod is disabled here; no further code in this file ever runs on
-- `abandoned` again...
T.eq(abandoned.species, abandonedSnapshot.species,
  "species survives an abandoned form with no revert, same as every other path")
T.same(abandoned.moves, abandonedSnapshot.moves,
  "the move list survives an abandoned form with no revert, same as every other path")
T.eq(abandoned.hp, abandonedSnapshot.hp,
  "current hp survives an abandoned form with no revert, same as every other path")
-- And stats self-heal at the very next battle: Battle.lua:292-297 calls
-- Mon.refreshStats over the whole party unconditionally at Battle:new,
-- independent of any mon's leftover `form` marker.
Mon.refreshStats(abandoned, DATA)
T.eq(abandoned.stats.attack, abandonedSnapshot.stats.attack,
  "the next battle's own Mon.refreshStats recomputes stats from base data "
    .. "regardless of a stale form marker")

-- --- M.install: the type-resolution seam
--
-- This section requires the real game/src/battle/gen2/Battle.lua and patches
-- its actual Battle.speciesDef, the same way battle_forms_primitive_test.lua
-- proves reloadSprite against the real BattleState.makeBattler rather than a
-- stand-in. `Battle.speciesDef(fakeSelf, mon)` is called directly (it only
-- ever reads `self.data.pokemon`, Battle.lua:712-714), so none of this needs
-- a live battle.
local RealBattle = require("src.battle.gen2.Battle")

local seamData = { pokemon = {
  TOTODILE = { types = { "WATER" }, name = "TOTODILE" },
} }
local fakeSelf = { data = seamData }

local plainMon = { species = "TOTODILE" }
local formedMon = { species = "TOTODILE", form = "PUDDLE",
                    formTypes = { "WATER", "GROUND" } }

T.same(RealBattle.speciesDef(fakeSelf, plainMon).types, { "WATER" },
  "before install: an unformed mon reads the real species types")
T.same(RealBattle.speciesDef(fakeSelf, formedMon).types, { "WATER" },
  "before install: a formed mon ALSO reads the real species types -- the "
    .. "bug this module exists to fix")

local installLog = { errors = {} }
local fakeMod = { log = { error = function(_, fmt, ...)
  installLog.errors[#installLog.errors + 1] = fmt:format(...)
end } }

T.eq(Forms2.install(fakeMod), true, "install succeeds against the real engine")

T.same(RealBattle.speciesDef(fakeSelf, plainMon).types, { "WATER" },
  "after install: an unformed mon is unaffected")
T.same(RealBattle.speciesDef(fakeSelf, formedMon).types, { "WATER", "GROUND" },
  "after install: a formed mon's types are overridden")
T.eq(RealBattle.speciesDef(fakeSelf, formedMon).name, "TOTODILE",
  "every OTHER field the real record carries still answers with the truth")

-- --- M.install: wrap-and-delegate, not replace
--
-- A wrap installed before this one (standing in for a third-party mod's own
-- speciesDef patch, or for a Gen 9 battle engine mod per this mod's own
-- composition rule) must still run afterward -- its own marker field has to
-- survive alongside this module's `.types` override, or two mods stacking
-- would mean whichever installed second erases the first.
package.loaded["src.battle.gen2.Battle"] = nil
local ComposeBattle = require("src.battle.gen2.Battle")
local vanillaForCompose = ComposeBattle.speciesDef
ComposeBattle.speciesDef = function(self, mon)
  local def = vanillaForCompose(self, mon)
  local out = {}
  for k, v in pairs(def or {}) do out[k] = v end
  out.priorModTouched = true
  return out
end

local Forms2Compose = dofile(MOD .. "/src/gen2forms.lua")
Forms2Compose.install(fakeMod)

local composed = ComposeBattle.speciesDef(fakeSelf, formedMon)
T.eq(composed.priorModTouched, true,
  "a wrap installed BEFORE this one still runs -- delegate, not replace")
T.same(composed.types, { "WATER", "GROUND" },
  "and this module's own override still applies on top of it")

-- --- M.install: idempotent
--
-- A second call must wrap nothing: same reference back, not a second layer
-- closing over the first.
local beforeSecondInstall = ComposeBattle.speciesDef
Forms2Compose.install(fakeMod)
T.eq(ComposeBattle.speciesDef, beforeSecondInstall,
  "installing a second time wraps nothing -- same function, not a new layer")

-- --- M.install: refuses out loud when the engine module cannot be required
--
-- The same forced-require-failure technique battle_forms_primitive_test.lua
-- uses against src.battle.BattleState, here against src.battle.gen2.Battle.
package.loaded["src.battle.gen2.Battle"] = nil
package.preload["src.battle.gen2.Battle"] = function()
  error("battle_forms test: forced require failure")
end
local Forms2Unavailable = dofile(MOD .. "/src/gen2forms.lua")
local unavailableLog = { errors = {} }
local unavailableMod = { log = { error = function(_, fmt, ...)
  unavailableLog.errors[#unavailableLog.errors + 1] = fmt:format(...)
end } }
T.eq(Forms2Unavailable.install(unavailableMod), false,
  "install refuses when the engine module cannot be required")
T.eq(#unavailableLog.errors, 1, "and says so out loud rather than staying silent")
package.preload["src.battle.gen2.Battle"] = nil
package.loaded["src.battle.gen2.Battle"] = nil

T.finish("battle_forms_gen2forms")
