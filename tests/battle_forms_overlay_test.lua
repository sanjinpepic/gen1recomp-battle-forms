package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
-- The whole roster: every check below holds for any wired mega, and the
-- OFFICIAL/ALL split is pinned in the eligibility suite.
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- Overlay reads the registry and nothing else now, so a mega set reaches it
-- through the entry that owns it rather than directly.
local function bindMegas(set)
  local registry = Transforms.new()
  T.eq(registry:register(Mega.entry({ eligibility = E, megas = set,
    keyitems = KeyItems })), true, "the mega entry registers")
  Overlay.bind({ registry = registry })
end

bindMegas(megas)

local hasRecord = { pokemon = { CHARIZARD_MEGA_X = {} } }

-- The trainer's half of the requirement.  Every fixture below carries it, so
-- each check is about the half it is actually testing; the Key Stone's own
-- absence is exercised in the key items suite and again through the whole
-- loaded mod in the options suite.  Shared because nothing here writes to it.
local BAG = { save = { inventory = { [KeyItems.KEY_STONE] = 1 } } }

local eligible = { phase = "menu", data = hasRecord, game = BAG, player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local plain = { game = BAG, player = { mon = { species = "PIDGEY" } } }

local s = Arm.new()

T.eq(Overlay.shouldOffer(s), false, "no battle offers nothing")

s:onBattleStarted({ battle = plain })
T.eq(Overlay.shouldOffer(s), false, "an ineligible mon is offered nothing")

s:onBattleStarted({ battle = eligible })
T.eq(Overlay.shouldOffer(s), true, "an eligible mon is offered the toggle")

T.eq(Overlay.label(s), "MEGA", "the indicator reads MEGA when disarmed")
s:toggle(Mega.ID)
T.eq(Overlay.label(s), "MEGA*", "the indicator marks the armed state")

s:consume(Mega.ID)
T.eq(Overlay.shouldOffer(s), false, "a battle that already changed offers nothing")

-- The indicator must be on screen exactly when the key is live.  The engine
-- only fires menu_auxiliary at the command menu with nothing queued, so
-- drawing at any other moment advertises a key that does nothing.
local messaging = { phase = "messages", game = BAG, player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s2 = Arm.new()
s2:onBattleStarted({ battle = messaging })
T.eq(Overlay.shouldOffer(s2), false, "nothing is offered while a message is up")

local queued = { phase = "menu", queue = { "something" }, game = BAG,
  player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s3 = Arm.new()
s3:onBattleStarted({ battle = queued })
T.eq(Overlay.shouldOffer(s3), false, "nothing is offered while work is queued")

local ready = { phase = "menu", queue = {}, data = hasRecord, game = BAG,
  player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s4 = Arm.new()
s4:onBattleStarted({ battle = ready })
T.eq(Overlay.shouldOffer(s4), true, "an empty queue at the menu is offered")

-- The cell must never promise a form the species table cannot deliver: the
-- toggle would arm, the confirm sound would play, and Forms.becomeForm would
-- refuse in silence.  This is the fixture shape of the bug 0.2.2 fixed.
local noRecord = { phase = "menu", queue = {}, data = { pokemon = {} }, game = BAG,
  player = { mon = { species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s5 = Arm.new()
s5:onBattleStarted({ battle = noRecord })
T.eq(Overlay.shouldOffer(s5), false,
  "a form with no National Dex record is never offered")

local noData = { phase = "menu", queue = {}, game = BAG, player = { mon = {
  species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" } } }
local s6 = Arm.new()
s6:onBattleStarted({ battle = noData })
T.eq(Overlay.shouldOffer(s6), false,
  "a battle with no species table at all is never offered")

-- Nothing may be offered for a pairing the MEGA EVOLUTIONS option turned off.
-- The stone is still a real item and can still be sitting on the mon -- what
-- the option takes away is the eligibility the cell is drawn from, so the
-- player is never shown a MEGA the resolve step would have to refuse.
local raw = dofile(MOD .. "/data/megas.lua")
local starmieBattle = { phase = "menu", queue = {}, game = BAG,
  data = { pokemon = { STARMIE_MEGA = {} } },
  player = { mon = { species = "STARMIE", [E.STAMP] = "STARMIITE" } } }
local s7 = Arm.new()
s7:onBattleStarted({ battle = starmieBattle })

bindMegas(Megaset.select(raw, Megaset.OFFICIAL))
T.eq(Overlay.shouldOffer(s7), false,
  "an extended pairing is offered no cell under OFFICIAL")

bindMegas(megas)
T.eq(Overlay.shouldOffer(s7), true,
  "the same mon in the same battle is offered the cell under ALL")

T.finish("battle_forms_overlay")
