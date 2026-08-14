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
                                 animId = "TESTANIM", log = log }))
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas })
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

T.finish("battle_forms_resolve")
