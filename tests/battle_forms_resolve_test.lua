package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local megas = dofile(MOD .. "/data/megas.lua")

local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 } },
} }

local function newMon(stamped)
  return { species = "CHARIZARD", level = 50,
           dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
           statExp = {}, [E.STAMP] = stamped and "CHARIZARDITE_X" or nil,
           moves = { { id = "EMBER", pp = 25 } } }
end

local function makeBattle(stamped)
  local queued = {}
  local mon = newMon(stamped)
  return {
    data = DATA,
    player = { isPlayer = true, mon = mon },
    game = { save = { party = { mon } } },
    enemyParty = {},
    queued = queued,
    animNext = function(_, name) queued[#queued + 1] = name end,
    animationsOn = function() return true end,
  }
end

Resolve.bind({ forms = Forms, eligibility = E, megas = megas, animId = "TESTANIM" })

-- Unarmed: nothing happens at all.
local b1 = makeBattle(true)
local s1 = Arm.new(); s1:onBattleStarted({ battle = b1 })
Resolve.onTurnStarted(s1, { battle = b1 })
T.eq(b1.player.mon.species, "CHARIZARD", "an unarmed turn changes no form")
T.eq(#b1.queued, 0, "an unarmed turn queues no animation")

-- Armed: the form changes and the move is untouched.
local b2 = makeBattle(true)
local s2 = Arm.new(); s2:onBattleStarted({ battle = b2 })
s2:toggle()
Resolve.onTurnStarted(s2, { battle = b2 })
T.eq(b2.player.mon.species, "CHARIZARD_MEGA_X", "an armed turn changes form")
T.eq(b2.player.mon.moves[1].pp, 25, "no PP is spent")
T.eq(b2.player.mon.moves[1].id, "EMBER", "the chosen move is untouched")
T.eq(#b2.queued, 1, "the change queues its animation")
T.eq(b2.queued[1], "TESTANIM", "and queues the configured animation id")
T.eq(s2:isArmed(), false, "the flag is consumed")
T.eq(s2:used(), true, "the battle records its one change")

-- Armed but ineligible: refuses without spending the battle's one change.
local b3 = makeBattle(false)
local s3 = Arm.new(); s3:onBattleStarted({ battle = b3 })
s3:toggle()
Resolve.onTurnStarted(s3, { battle = b3 })
T.eq(b3.player.mon.species, "CHARIZARD", "an ineligible mon does not change")
T.eq(s3:used(), false, "a refused change does not spend the battle's one change")

-- Animations off: the form change must still happen.
local b4 = makeBattle(true)
b4.animationsOn = function() return false end
local s4 = Arm.new(); s4:onBattleStarted({ battle = b4 })
s4:toggle()
Resolve.onTurnStarted(s4, { battle = b4 })
T.eq(b4.player.mon.species, "CHARIZARD_MEGA_X",
  "the form changes with battle animations turned off")
T.eq(#b4.queued, 0, "and queues nothing")

-- Battle end sweeps the PARTY, not just the field: a mega survives switching
-- out, so the transformed mon may be benched when the battle ends.
local b5 = makeBattle(true)
local benched = newMon(true)
table.insert(b5.game.save.party, benched)
Forms.becomeForm(DATA, { mon = benched }, "CHARIZARD_MEGA_X")
T.eq(benched.species, "CHARIZARD_MEGA_X", "precondition: the benched mon is megaed")
Resolve.onBattleEnded({ battle = b5 })
T.eq(benched.species, "CHARIZARD", "a benched transformed mon reverts at battle end")

-- Enemy side too.
local b6 = makeBattle(true)
local foe = newMon(false)
b6.enemyParty = { foe }
Forms.becomeForm(DATA, { mon = foe }, "CHARIZARD_MEGA_X")
Resolve.onBattleEnded({ battle = b6 })
T.eq(foe.species, "CHARIZARD", "an enemy transformed mon reverts too")

-- Fainting reverts at once rather than waiting for the battle to end.
local b7 = makeBattle(true)
local fainter = { isPlayer = true, mon = newMon(true) }
Forms.becomeForm(DATA, fainter, "CHARIZARD_MEGA_X")
Resolve.onFainted({ battle = b7, battler = fainter })
T.eq(fainter.mon.species, "CHARIZARD", "a fainted mon reverts at once")

-- Sweeping twice is harmless.
Resolve.onBattleEnded({ battle = b7 })
T.eq(fainter.mon.species, "CHARIZARD", "reverting twice is a no-op")

-- Armed and eligible, but the National Dex record is missing: refuses, and
-- says so through the logger rather than swallowing it.  This is the shape
-- of the bug that shipped in 0.2.1 -- a mega table entry pointing at an id
-- with no matching record -- minus the typo that caused it.
local NO_RECORD_DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 } },
} }
local logged = {}
local fakeLog = {
  warn = function(_, fmt, ...) logged[#logged + 1] = fmt:format(...) end,
}
Resolve.bind({ forms = Forms, eligibility = E, megas = megas,
               animId = "TESTANIM", log = fakeLog })

local b8 = makeBattle(true)
b8.data = NO_RECORD_DATA
local s8 = Arm.new(); s8:onBattleStarted({ battle = b8 })
s8:toggle()
Resolve.onTurnStarted(s8, { battle = b8 })
T.eq(b8.player.mon.species, "CHARIZARD", "a missing record refuses the change")
T.eq(s8:used(), false, "a refused change does not spend the battle's one change")
T.eq(#logged, 1, "the refusal is logged")
T.check(logged[1]:find("CHARIZARD", 1, true) ~= nil,
  "the log names the species")
T.check(logged[1]:find("CHARIZARD_MEGA_X", 1, true) ~= nil,
  "the log names the form id it could not find")

-- No logger bound (the shape every other test in this file uses): the
-- refusal still happens, it just has nowhere to report to.
Resolve.bind({ forms = Forms, eligibility = E, megas = megas, animId = "TESTANIM" })
local b9 = makeBattle(true)
b9.data = NO_RECORD_DATA
local s9 = Arm.new(); s9:onBattleStarted({ battle = b9 })
s9:toggle()
Resolve.onTurnStarted(s9, { battle = b9 })
T.eq(b9.player.mon.species, "CHARIZARD", "no logger bound still refuses safely")

T.finish("battle_forms_resolve")
