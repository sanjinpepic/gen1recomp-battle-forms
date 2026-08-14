package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Arm = dofile(MOD .. "/src/arm.lua")

local state = Arm.new()
local battle = { player = { mon = { species = "CHARIZARD" } } }

T.eq(state:current(), nil, "no battle is cached before one starts")

state:onBattleStarted({ battle = battle })
T.eq(state:current(), battle, "the live battle is cached from battle.started")
T.eq(state:isArmed(), false, "a fresh battle starts unarmed")

T.eq(state:toggle(), true, "toggling arms")
T.eq(state:isArmed(), true, "armed state sticks")
T.eq(state:toggle(), false, "toggling again disarms")

state:toggle()
state:consume()
T.eq(state:isArmed(), false, "consuming clears the armed flag")
T.eq(state:used(), true, "consuming records that this battle has had its one change")

T.eq(state:toggle(), false, "a battle that already changed form cannot arm again")
T.eq(state:isArmed(), false, "and it stays unarmed")

state:onBattleEnded({ battle = battle })
T.eq(state:current(), nil, "the reference is dropped when the battle ends")
T.eq(state:used(), false, "the once-per-battle limit resets with the battle")

-- A second battle must start completely clean, including after one where the
-- player armed but never fired.
state:onBattleStarted({ battle = battle })
state:toggle()
state:onBattleStarted({ battle = battle })
T.eq(state:isArmed(), false, "a new battle clears a leftover armed flag")

T.finish("battle_forms_arm")
