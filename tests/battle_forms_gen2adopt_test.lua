-- The Gold battle menu points the arm state at the battle actually on screen.
--
-- WHY THIS EXISTS.  src/gen2menu.lua originally skipped adoption entirely and
-- documented the cost as "a mod enabled mid-battle on Gold loses the cell for
-- that battle only".  A real trace showed the cost was total: on a fresh boot
-- with the mod enabled from the start, the cell never appeared at all, and
-- the diagnostic said why on every frame --
--
--   menu: gen2 armState=another battle phase=menu queueEmpty=true
--   species=CHARIZARD item=CHARIZARDITE_X keys[KEY_STONE=true ...]
--   used[mega=false ...] offered=0
--
-- Every input correct and nothing offered, because src/overlay.lua's own
-- `offered` asks `entry.available(battle)` about `state:current()`, and
-- "another battle" is precisely that value failing to be the battle being
-- played.  Mega's predicate then reads a different fight's `battle.player`
-- and a different `battle.save` for the Key Stone.
--
-- So the invariant is simply: after the screen has updated once, the arm
-- state holds THAT screen's battle.  Everything below is that, plus the two
-- ways a naive fix would break a fight -- resetting spent flags every frame,
-- and re-adopting a battle it already holds.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

-- A stand-in for the engine class, installed before src/gen2menu.lua requires
-- it. Only the two methods that file wraps need to exist.
local BattleState = {}
BattleState.__index = BattleState
local vanillaUpdates = 0
function BattleState:update() vanillaUpdates = vanillaUpdates + 1 end
function BattleState:drawPanel() end
package.loaded["src.ui.gen2.BattleState"] = BattleState

local Gen2Menu = dofile(MOD .. "/src/gen2menu.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Formmenu = dofile(MOD .. "/src/formmenu.lua")

Gen2Menu.bind({ overlay = Overlay, formmenu = Formmenu })

local state = Arm.new()
local mod = { log = { info = function() end, error = function() end,
                      warn = function() end } }
T.check(Gen2Menu.install(mod, state) == true, "the Gold menu installs")

local function screenFor(battle)
  return setmetatable({ battle = battle, phase = "menu", queue = {} }, BattleState)
end

-- THE BUG, reproduced: the arm state is holding one battle and the screen is
-- showing another. Before the fix this stayed true for the whole fight and
-- the cell never appeared.
local stale = { player = {}, id = "stale" }
local live = { player = {}, id = "live" }
state:onBattleStarted({ battle = stale })
T.eq(state:current(), stale, "the arm state starts out holding the stale battle")

local screen = screenFor(live)
screen:update(0)
T.eq(state:current(), live,
  "after one update the arm state holds the battle on screen, not the stale one")

-- Idempotent: a second update must not begin() again, because begin() clears
-- the spent flags and an armed id. A fight where every frame reset those
-- would hand the player an unlimited supply of megas.
state.spent["mega"] = true
state.spentAny = true
state.armedId = "mega"
screen:update(0)
T.eq(state:current(), live, "a second update still holds the same battle")
T.check(state:used("mega"), "and does NOT clear a spent flag")
T.check(state:usedAny(), "nor the spent-any flag")
T.eq(state:armed(), "mega", "nor an armed id")

-- A genuinely new battle still resets, which is the whole point of adoption
-- being begin() and not a bare assignment.
local next_ = { player = {}, id = "next" }
screenFor(next_):update(0)
T.eq(state:current(), next_, "a new battle is adopted")
T.check(not state:used("mega"), "and its spent flags start clean")
T.check(state:armed() == nil, "with nothing armed")

-- The wrapper must still be a wrapper: the engine's own update has to run.
T.check(vanillaUpdates > 0, "the engine's own update still runs underneath")

-- A screen with no battle yet (constructed, not started) must not blank the
-- arm state -- adopting nil would drop a live fight's spent flags.
local before = state:current()
setmetatable({ phase = "menu", queue = {} }, BattleState):update(0)
T.eq(state:current(), before, "a screen with no battle adopts nothing")

T.finish("battle_forms_gen2adopt")
