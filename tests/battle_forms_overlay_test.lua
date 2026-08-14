package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local megas = dofile(MOD .. "/data/megas.lua")

Overlay.bind({ eligibility = E, megas = megas })

local eligible = { phase = "menu", player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local plain = { player = { mon = { species = "PIDGEY" } } }

local s = Arm.new()

T.eq(Overlay.shouldOffer(s), false, "no battle offers nothing")

s:onBattleStarted({ battle = plain })
T.eq(Overlay.shouldOffer(s), false, "an ineligible mon is offered nothing")

s:onBattleStarted({ battle = eligible })
T.eq(Overlay.shouldOffer(s), true, "an eligible mon is offered the toggle")

T.eq(Overlay.label(s), "MEGA", "the indicator reads MEGA when disarmed")
s:toggle()
T.eq(Overlay.label(s), "MEGA*", "the indicator marks the armed state")

s:consume()
T.eq(Overlay.shouldOffer(s), false, "a battle that already changed offers nothing")

-- The indicator must be on screen exactly when the key is live.  The engine
-- only fires menu_auxiliary at the command menu with nothing queued, so
-- drawing at any other moment advertises a key that does nothing.
local messaging = { phase = "messages", player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s2 = Arm.new()
s2:onBattleStarted({ battle = messaging })
T.eq(Overlay.shouldOffer(s2), false, "nothing is offered while a message is up")

local queued = { phase = "menu", queue = { "something" }, player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s3 = Arm.new()
s3:onBattleStarted({ battle = queued })
T.eq(Overlay.shouldOffer(s3), false, "nothing is offered while work is queued")

local ready = { phase = "menu", queue = {}, player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s4 = Arm.new()
s4:onBattleStarted({ battle = ready })
T.eq(Overlay.shouldOffer(s4), true, "an empty queue at the menu is offered")

T.finish("battle_forms_overlay")
