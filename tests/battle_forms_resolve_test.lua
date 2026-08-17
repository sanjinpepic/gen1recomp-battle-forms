package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
-- The whole roster: every check below holds for any wired mega, and the
-- OFFICIAL/ALL split is pinned in the eligibility suite.
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

local function newMon(stamped)
  local mon = { species = "CHARIZARD", level = 50,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
                statExp = {}, [E.STAMP] = stamped and "CHARIZARDITE_X" or nil,
                moves = { { id = "EMBER", pp = 25 } } }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  return mon
end

local function makeBattle(stamped)
  local queued = {}
  local mon = newMon(stamped)
  return {
    data = DATA,
    player = { isPlayer = true, mon = mon, curStats = mon.stats,
               curTypes = DATA.pokemon.CHARIZARD.types },
    game = { save = { party = { mon } } },
    enemyParty = {},
    queued = queued,
    animNext = function(_, name) queued[#queued + 1] = name end,
    animationsOn = function() return true end,
  }
end

-- Turn resolution dispatches through the registry now, so what used to be a
-- mega-shaped dependency list is the mega entry plus the unwind paths' own
-- dependencies.  The animation id and the logger belong to the entry: they are
-- the activation's, and the sweep and the switch-in reapply neither.
local function bindResolve(log)
  local registry = Transforms.new()
  registry:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                                 animId = "TESTANIM", log = log,
                                 battlerof = Battlerof }))
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, battlerof = Battlerof })
end

bindResolve(nil)

-- Unarmed: nothing happens at all.
local b1 = makeBattle(true)
local s1 = Arm.new(); s1:onBattleStarted({ battle = b1 })
Resolve.onTurnStarted(s1, { battle = b1 })
T.eq(b1.player.mon.species, "CHARIZARD", "an unarmed turn changes the species not at all")
T.eq(b1.player.mon.form, nil, "an unarmed turn marks no form")
T.eq(#b1.queued, 0, "an unarmed turn queues no animation")

-- Armed: the form changes and the move is untouched.
local b2 = makeBattle(true)
local s2 = Arm.new(); s2:onBattleStarted({ battle = b2 })
s2:toggle(Mega.ID)
Resolve.onTurnStarted(s2, { battle = b2 })
T.eq(b2.player.mon.species, "CHARIZARD", "the species is still untouched after an armed turn")
T.eq(b2.player.mon.form, "MEGA_X", "an armed turn marks the form")
T.check(b2.player.curStats.attack > 100, "curStats follow the form")
T.eq(b2.player.curTypes[2], "DRAGON", "curTypes follow the form")
T.eq(b2.player.mon.moves[1].pp, 25, "no PP is spent")
T.eq(b2.player.mon.moves[1].id, "EMBER", "the chosen move is untouched")
T.eq(#b2.queued, 1, "the change queues its animation")
T.eq(b2.queued[1], "TESTANIM", "and queues the configured animation id")
T.eq(s2:isArmed(), false, "the flag is consumed")
T.eq(s2:used(Mega.ID), true, "the battle records its one change")

-- Armed but ineligible: refuses without spending the battle's one change.
local b3 = makeBattle(false)
local s3 = Arm.new(); s3:onBattleStarted({ battle = b3 })
s3:toggle(Mega.ID)
Resolve.onTurnStarted(s3, { battle = b3 })
T.eq(b3.player.mon.form, nil, "an ineligible mon does not change")
T.eq(s3:used(Mega.ID), false, "a refused change does not spend the battle's one change")

-- Animations off: the form change must still happen.
local b4 = makeBattle(true)
b4.animationsOn = function() return false end
local s4 = Arm.new(); s4:onBattleStarted({ battle = b4 })
s4:toggle(Mega.ID)
Resolve.onTurnStarted(s4, { battle = b4 })
T.eq(b4.player.mon.form, "MEGA_X",
  "the form changes with battle animations turned off")
T.eq(#b4.queued, 0, "and queues nothing")

-- Switching a megaed mon out and back in gets a brand-new battler from the
-- engine's own makeBattler, which knows nothing about mon.form and would
-- otherwise leave curStats/curTypes at their base values while the picture
-- (built off mon.form directly) shows the mega. battle.battler_switched
-- reapplies the override through the same becomeForm path.
local b5 = makeBattle(true)
b5.player.mon.form = "MEGA_X"
-- Simulates the fresh, form-blind battler makeBattler would actually hand
-- back: base curStats/curTypes even though the mon is still marked.
b5.player.curStats = b5.player.mon.stats
b5.player.curTypes = DATA.pokemon.CHARIZARD.types
Resolve.onBattlerSwitched({ battle = b5, battler = b5.player })
T.check(b5.player.curStats.attack > 100,
  "switching back in reapplies the form's curStats")
T.eq(b5.player.curTypes[2], "DRAGON",
  "switching back in reapplies the form's curTypes")

-- An untransformed mon switching in triggers no lookup at all.
local b6 = makeBattle(false)
Resolve.onBattlerSwitched({ battle = b6, battler = b6.player })
T.eq(b6.player.curStats, b6.player.mon.stats,
  "an untransformed mon's curStats are left alone on switch-in")

-- Battle end sweeps the PARTY, not just the field: a mega survives switching
-- out, so the transformed mon may be benched when the battle ends.
local b7 = makeBattle(true)
local benched = newMon(true)
table.insert(b7.game.save.party, benched)
Forms.becomeForm(DATA, { mon = benched }, "CHARIZARD_MEGA_X")
T.eq(benched.form, "MEGA_X", "precondition: the benched mon is megaed")
Resolve.onBattleEnded({ battle = b7 })
T.eq(benched.form, nil, "a benched transformed mon reverts at battle end")

-- Enemy side too.
local b8 = makeBattle(true)
local foe = newMon(false)
b8.enemyParty = { foe }
Forms.becomeForm(DATA, { mon = foe }, "CHARIZARD_MEGA_X")
Resolve.onBattleEnded({ battle = b8 })
T.eq(foe.form, nil, "an enemy transformed mon reverts too")

-- Fainting reverts at once rather than waiting for the battle to end.
local b9 = makeBattle(true)
local fainter = { isPlayer = true, mon = newMon(true) }
Forms.becomeForm(DATA, fainter, "CHARIZARD_MEGA_X")
Resolve.onFainted({ battle = b9, battler = fainter })
T.eq(fainter.mon.form, nil, "a fainted mon reverts at once")
T.eq(fainter.curStats, fainter.mon.stats, "and curStats is restored too")

-- Sweeping twice is harmless.
Resolve.onBattleEnded({ battle = b9 })
T.eq(fainter.mon.form, nil, "reverting twice is a no-op")

-- Armed and eligible, but the National Dex record is missing: refuses, and
-- says so through the logger rather than swallowing it. This is the shape
-- of the bug that shipped in 0.2.1 -- a mega table entry pointing at an id
-- with no matching record -- minus the typo that caused it.
local NO_RECORD_DATA = { pokemon = {
  CHARIZARD = DATA.pokemon.CHARIZARD,
} }
local logged = {}
local fakeLog = {
  warn = function(_, fmt, ...) logged[#logged + 1] = fmt:format(...) end,
}
bindResolve(fakeLog)

local b10 = makeBattle(true)
b10.data = NO_RECORD_DATA
local s10 = Arm.new(); s10:onBattleStarted({ battle = b10 })
s10:toggle(Mega.ID)
Resolve.onTurnStarted(s10, { battle = b10 })
T.eq(b10.player.mon.form, nil, "a missing record refuses the change")
T.eq(s10:used(Mega.ID), false, "a refused change does not spend the battle's one change")
T.eq(#logged, 1, "the refusal is logged")
T.check(logged[1]:find("CHARIZARD", 1, true) ~= nil,
  "the log names the species")
T.check(logged[1]:find("CHARIZARD_MEGA_X", 1, true) ~= nil,
  "the log names the form id it could not find")

-- No logger bound (the shape every other test in this file uses): the
-- refusal still happens, it just has nowhere to report to.
bindResolve(nil)
local b11 = makeBattle(true)
b11.data = NO_RECORD_DATA
local s11 = Arm.new(); s11:onBattleStarted({ battle = b11 })
s11:toggle(Mega.ID)
Resolve.onTurnStarted(s11, { battle = b11 })
T.eq(b11.player.mon.form, nil, "no logger bound still refuses safely")

-- ---------------------------------------------------------------------
-- Gen 2: no `battle.game`, no battler wrapper, and mon.stats is a REAL
-- save field src/gen2forms.lua writes -- so this exercises the exact gap
-- that made every one of the checks above silently do nothing on Gold: the
-- engine's own Gen 2 Battle object (game/src/battle/gen2/Battle.lua) carries
-- `.party`/`.enemyParty`/`.save` directly and no `.game` at all
-- (confirmed against the real class's own opts table, Battle.lua:236-242),
-- so `battle.game and battle.game.save` -- what M.onBattleEnded read before
-- this pass -- was always nil there, and the sweep it guards never ran a
-- single iteration.
-- ---------------------------------------------------------------------
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local Persistent = dofile(MOD .. "/src/persistent.lua")

local GEN2_DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                              specialAttack = 85, specialDefense = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, specialAttack = 130,
                                     specialDefense = 85 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

local Mon2 = require("src.battle.gen2.Mon")
local GEN2_BASE_STATS = Mon2.stats(GEN2_DATA.pokemon.CHARIZARD.baseStats, {}, 50, {})

local function gen2Mon()
  local mon = { species = "CHARIZARD", level = 50, dvs = {}, statExp = {} }
  mon.stats = {}
  for key, value in pairs(GEN2_BASE_STATS) do mon.stats[key] = value end
  return mon
end

local function bindGen2Resolve()
  local registry = Transforms.new()
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, battlerof = Battlerof, gen2 = true,
                 gen2forms = Gen2Forms })
end

-- Switching: nothing needs reapplying at all on Gen 2, because mon.stats/
-- mon.formTypes live on the mon itself rather than a battler makeBattler
-- would otherwise rebuild -- so this must be a no-op, and the assertion that
-- would catch it doing something wrong (or logging a false "no longer
-- eligible" warning for a mon that is, in fact, still fine) is that it
-- leaves the mon completely alone.
do
  bindGen2Resolve()
  local mon = gen2Mon()
  mon.form = "MEGA_X"
  Gen2Forms.becomeForm(GEN2_DATA, mon, "CHARIZARD_MEGA_X")
  local snapshot = { attack = mon.stats.attack, form = mon.form }
  local logged = {}
  Resolve.onBattlerSwitched({ battle = { data = GEN2_DATA }, battler = mon })
  T.eq(mon.stats.attack, snapshot.attack,
    "Gen 2 switch-in reapplication is a no-op -- nothing was ever rebuilt to reapply to")
  T.eq(mon.form, snapshot.form, "and the marker is untouched")
end

-- Fainting: a plain mega'd mon reverts stats AND the marker, through the
-- real Gen 2 primitive.
do
  bindGen2Resolve()
  local mon = gen2Mon()
  Gen2Forms.becomeForm(GEN2_DATA, mon, "CHARIZARD_MEGA_X")
  T.eq(mon.form, "MEGA_X", "precondition: megaed")
  T.check(mon.stats.attack > GEN2_BASE_STATS.attack, "precondition: boosted stats")

  Resolve.onFainted({ battle = { data = GEN2_DATA }, battler = mon })
  T.eq(mon.form, nil, "fainting clears the marker on Gen 2")
  T.eq(mon.stats.attack, GEN2_BASE_STATS.attack, "and the real stat field the save writes is reverted too")
end

-- Fainting: a mon entitled to a PERSISTENT form reverts to THAT form's own
-- stats, not to base -- proving settle() is asked, not just a blunt clear.
do
  bindGen2Resolve()
  Persistent.bind({ forms = Forms, eligibility = E,
                     rows = { CHARIZARD = { HELD_ITEM = "CHARIZARD_MEGA_X" } },
                     gen2forms = Gen2Forms, gen2 = true })
  local registry = Transforms.new()
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, battlerof = Battlerof, gen2 = true,
                 gen2forms = Gen2Forms, persistent = Persistent })

  local mon = gen2Mon()
  mon.item = "HELD_ITEM"
  Gen2Forms.becomeForm(GEN2_DATA, mon, "CHARIZARD_MEGA_X")
  Resolve.onFainted({ battle = { data = GEN2_DATA }, battler = mon })
  T.eq(mon.form, "MEGA_X",
    "the persistent form's own marker is restored, not cleared to nil")
end

-- Battle end sweeps battle.party / battle.enemyParty directly -- the fields
-- the real engine object actually carries -- not battle.game.save.party.
do
  bindGen2Resolve()
  local benched = gen2Mon()
  Gen2Forms.becomeForm(GEN2_DATA, benched, "CHARIZARD_MEGA_X")
  local foe = gen2Mon()
  Gen2Forms.becomeForm(GEN2_DATA, foe, "CHARIZARD_MEGA_X")
  T.eq(benched.form, "MEGA_X", "precondition: the benched mon is megaed")
  T.eq(foe.form, "MEGA_X", "precondition: so is the enemy's")

  Resolve.onBattleEnded({ battle = { data = GEN2_DATA,
                                     party = { benched }, enemyParty = { foe } } })
  T.eq(benched.form, nil, "a benched Gen 2 mon reverts at battle end")
  T.eq(benched.stats.attack, GEN2_BASE_STATS.attack, "with its real stats field reverted too")
  T.eq(foe.form, nil, "and the enemy side, read off battle.enemyParty directly")
end

-- ---------------------------------------------------------------------
-- The killing-blow spoiler: Gen 2's battle.ended fires from inside
-- Battle:resolveFaints, synchronously and before the caller has even taken
-- this turn's queued display events off the battle -- so a Pokemon that just
-- delivered the killing blow while wearing a form used to revert to its base
-- picture and stats before the hit that killed the target had animated at
-- all. With deps.deferred bound (the real mod's own wiring, main.lua's
-- deferred.install), the sweep must not settle synchronously; it must wait
-- for src/deferred.lua's own hold before the marker and the real stats field
-- move. Without deps.deferred bound (every OTHER test in this file), the
-- sweep stays exactly as it always has -- proven already, above.
-- ---------------------------------------------------------------------
local Deferred = dofile(MOD .. "/src/deferred.lua")

do
  Deferred.reset()
  local registry = Transforms.new()
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, battlerof = Battlerof, gen2 = true,
                 gen2forms = Gen2Forms, deferred = Deferred })

  local killer = gen2Mon()
  Gen2Forms.becomeForm(GEN2_DATA, killer, "CHARIZARD_MEGA_X")
  T.eq(killer.form, "MEGA_X", "precondition: wearing the form that delivered the kill")
  local formedAttack = killer.stats.attack
  T.check(formedAttack > GEN2_BASE_STATS.attack, "precondition: with the form's boosted stats")

  Resolve.onBattleEnded({ battle = { data = GEN2_DATA,
                                     party = { killer }, enemyParty = {} } })
  T.eq(killer.form, "MEGA_X",
    "the marker survives the instant the battle ends -- the sweep did not "
      .. "settle synchronously")
  T.eq(killer.stats.attack, formedAttack,
    "and so does the real stats field the save writes -- nothing about the "
      .. "kill's own animation would see the base picture partway through it")

  Deferred.tick(Deferred.HOLD_SECONDS + 0.01)
  T.eq(killer.form, nil,
    "once the hold elapses the deferred settle runs and the marker clears")
  T.eq(killer.stats.attack, GEN2_BASE_STATS.attack,
    "with the real stats field reverted too, exactly as an immediate sweep "
      .. "would have left it -- only later")

  -- Rebind without deferred so every OTHER Gen 2 test in this file (before
  -- and after this one) keeps exercising the plain, immediate sweep.
  bindGen2Resolve()
end

-- ---------------------------------------------------------------------
-- Cross-mod correctness: a form marker this mod never set must survive the
-- battle-end sweep and the faint handler untouched.
--
-- A sibling mod (wild_forms) marks caught regional and Minior forms with the
-- identical field, mon.form, because that is the field the sprite registry
-- reads regardless of which mod set it -- and that field OUTLIVES the
-- battle for wild_forms exactly the way a persistent held-item form outlives
-- one here.  The blunt fallback below used to assume "neither fusion nor
-- persistent claims this mon" meant "so whatever is on mon.form is battle-
-- scoped and safe to clear" -- true for every mechanic THIS mod has ever
-- shipped, and false the moment a second mod reuses the same field for
-- something that is never supposed to come off.  A VULPIX with no row in
-- this mod's megas table is the proof: nothing here could ever have put
-- "ALOLAN" there.
-- ---------------------------------------------------------------------
do
  bindResolve(nil)
  local foreign = newMon(false)
  foreign.species = "VULPIX"
  foreign.form = "ALOLAN"
  local battle = makeBattle(false)
  battle.game.save.party = { foreign }
  Resolve.onBattleEnded({ battle = battle })
  T.eq(foreign.form, "ALOLAN",
    "a foreign form marker survives the battle-end sweep untouched")
end

do
  bindResolve(nil)
  local foreignMon = newMon(false)
  foreignMon.species = "VULPIX"
  foreignMon.form = "ALOLAN"
  local foreignBattler = { isPlayer = true, mon = foreignMon,
                           curStats = { attack = 999 }, curTypes = { "ICE" } }
  Resolve.onFainted({ battle = makeBattle(false), battler = foreignBattler })
  T.eq(foreignMon.form, "ALOLAN", "a foreign form marker survives fainting too")
  T.eq(foreignBattler.curStats.attack, 999,
    "and the OTHER mod's own battler-scoped override is left standing")
  T.eq(foreignBattler.curTypes[1], "ICE", "curTypes too")
end

-- The Gen 2 half: mon.stats is a REAL save field there, so resetting it for
-- a foreign form would touch a field this mod does not own, not merely a
-- marker.
do
  bindGen2Resolve()
  local foreign = gen2Mon()
  foreign.species = "VULPIX"
  foreign.form = "ALOLAN"
  local originalAttack = foreign.stats.attack
  Resolve.onFainted({ battle = { data = GEN2_DATA }, battler = foreign })
  T.eq(foreign.form, "ALOLAN", "a foreign form marker survives fainting on Gen 2 too")
  T.eq(foreign.stats.attack, originalAttack,
    "and the real stats field the save writes is left completely alone")
end

do
  bindGen2Resolve()
  local foreign = gen2Mon()
  foreign.species = "VULPIX"
  foreign.form = "ALOLAN"
  local originalAttack = foreign.stats.attack
  Resolve.onBattleEnded({ battle = { data = GEN2_DATA, party = { foreign },
                                     enemyParty = {} } })
  T.eq(foreign.form, "ALOLAN", "and it survives the Gen 2 battle-end sweep too")
  T.eq(foreign.stats.attack, originalAttack, "with stats untouched")
end

-- A leftover form this mod DID set is still cleared -- the fix is about not
-- touching foreign markers, not about ceasing to clean up its own, so a
-- benched mega left standing must still revert exactly as it always has.
do
  bindResolve(nil)
  local ours = newMon(true)
  Forms.becomeForm(DATA, { mon = ours }, "CHARIZARD_MEGA_X")
  T.eq(ours.form, "MEGA_X", "precondition: this mod's own mega marker is set")
  local battle = makeBattle(false)
  battle.game.save.party = { ours }
  Resolve.onBattleEnded({ battle = battle })
  T.eq(ours.form, nil, "and still reverts, unlike the foreign one above")
end

T.finish("battle_forms_resolve")
