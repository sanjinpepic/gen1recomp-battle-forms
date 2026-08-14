-- What can be proven without love2d: the input decision (src/menu.lua's
-- handleInput), never the two draw functions -- those only call
-- love.graphics and Font, and are exercised by hand in-game instead.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Menu = dofile(MOD .. "/src/menu.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local megas = dofile(MOD .. "/data/megas.lua")

Overlay.bind({ eligibility = E, megas = megas })
Menu.bind({ overlay = Overlay })

-- src/core/Input.lua's wasPressed reads a per-frame set with no memory of
-- any other frame; this double is that same shape.
local function makeInput(pressed)
  return { wasPressed = function(_, btn) return (pressed or {})[btn] == true end }
end

local function eligibleMon()
  return { species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X", hp = 100 }
end

local hasRecord = { pokemon = { CHARIZARD_MEGA_X = {} } }

local function makeBattle(menuIndex, pressed)
  return {
    phase = "menu",
    menuIndex = menuIndex,
    queue = {},
    data = hasRecord,
    player = { mon = eligibleMon() },
    game = { input = makeInput(pressed) },
  }
end

-- ---------------------------------------------------------------------
-- No eligible mon: the menu is exactly vanilla.  handleInput must never
-- claim a frame, at any real index, in any direction -- that is the whole
-- guarantee the scripted tutorial cursor depends on.
-- ---------------------------------------------------------------------
do
  local state = Arm.new()
  local battle = { phase = "menu", menuIndex = 1, queue = {},
    player = { mon = { species = "PIDGEY", hp = 100 } },
    game = { input = makeInput({ left = true }) } }
  state:onBattleStarted({ battle = battle })

  T.eq(Overlay.shouldOffer(state), false, "precondition: an ineligible mon offers nothing")
  T.eq(Menu.handleInput(battle, state), false, "an ineligible mon's menu is never claimed")
  T.eq(battle.menuIndex, 1, "menuIndex is untouched")
  T.eq(Menu.isOnMegaCell(battle), false, "the cursor never leaves the real grid")

  for _, idx in ipairs({ 1, 2, 3, 4 }) do
    for _, dir in ipairs({ "left", "right", "up", "down", "a" }) do
      battle.menuIndex = idx
      battle.game.input = makeInput({ [dir] = true })
      T.eq(Menu.handleInput(battle, state), false,
        ("index %d + %s stays vanilla when nothing is offered"):format(idx, dir))
    end
  end
end

-- ---------------------------------------------------------------------
-- Eligible: the cursor can reach MEGA from either column-0 cell (FIGHT,
-- ITEM) and come back to exactly where it left from.  PKMN/RUN (column 1)
-- never border it directly, matching how left/right already work.
-- ---------------------------------------------------------------------
do
  local state = Arm.new()
  local battle = makeBattle(1, {})
  state:onBattleStarted({ battle = battle })
  T.eq(Overlay.shouldOffer(state), true, "precondition: an eligible mon offers the toggle")

  battle.game.input = makeInput({ left = true })
  T.eq(Menu.handleInput(battle, state), true, "left at FIGHT (column 0) is claimed")
  T.eq(Menu.isOnMegaCell(battle), true, "the cursor is now on MEGA")
  T.eq(battle.menuIndex, 1, "the real index is left exactly where it was")

  battle.game.input = makeInput({ right = true })
  T.eq(Menu.handleInput(battle, state), true, "right off MEGA is claimed")
  T.eq(Menu.isOnMegaCell(battle), false, "the cursor is back on the real grid")
  T.eq(battle.menuIndex, 1, "back on FIGHT, unchanged")

  battle.menuIndex = 3 -- ITEM, also column 0
  battle.game.input = makeInput({ left = true })
  Menu.handleInput(battle, state)
  T.eq(Menu.isOnMegaCell(battle), true, "left from ITEM also reaches MEGA")
  battle.game.input = makeInput({ up = true })
  Menu.handleInput(battle, state)
  T.eq(Menu.isOnMegaCell(battle), false, "up off MEGA leaves it too, not just right")
  T.eq(battle.menuIndex, 3, "back on ITEM, unchanged")

  battle.menuIndex = 2 -- PKMN, column 1
  battle.game.input = makeInput({ left = true })
  T.eq(Menu.handleInput(battle, state), false,
    "left from PKMN moves within the real grid, not onto MEGA")
  T.eq(Menu.isOnMegaCell(battle), false, "PKMN cannot reach MEGA directly")
end

-- ---------------------------------------------------------------------
-- Selecting MEGA toggles the armed flag and takes no turn action: the
-- phase and the real index are untouched, and nothing was dispatched.
-- ---------------------------------------------------------------------
do
  local state = Arm.new()
  local battle = makeBattle(1, {})
  state:onBattleStarted({ battle = battle })
  battle.game.input = makeInput({ left = true })
  Menu.handleInput(battle, state)
  T.eq(Menu.isOnMegaCell(battle), true, "precondition: cursor parked on MEGA")
  T.eq(state:isArmed(), false, "starts disarmed")

  battle.game.input = makeInput({ a = true })
  local handled, action = Menu.handleInput(battle, state)
  T.eq(handled, true, "A on MEGA is claimed")
  T.eq(action, "toggle", "the wrapper is told this frame armed or disarmed it")
  T.eq(state:isArmed(), true, "A arms the toggle")
  T.eq(battle.phase, "menu", "the phase is untouched -- no turn was taken")
  T.eq(battle.menuIndex, 1, "no real cell was dispatched by the same press")

  battle.game.input = makeInput({ a = true })
  Menu.handleInput(battle, state)
  T.eq(state:isArmed(), false, "a second A disarms it")
end

-- ---------------------------------------------------------------------
-- The two guards BattleSafety.inspect also applies to battle.menu_auxiliary
-- (fainted, forced-locked), so this module never starves their own
-- auto-resolve of the input frame it runs on.  drainHold/drainFloor are
-- deliberately NOT among them -- that is the whole reason this trigger
-- exists instead of START.
-- ---------------------------------------------------------------------
do
  local state = Arm.new()
  local battle = makeBattle(1, { left = true })
  battle.player.mon.hp = 0
  state:onBattleStarted({ battle = battle })
  T.eq(Menu.handleInput(battle, state), false, "a fainted mon's menu is never claimed")

  local state2 = Arm.new()
  local battle2 = makeBattle(1, { left = true })
  battle2.menuLockedAction = function() return { id = "STRUGGLE" } end
  state2:onBattleStarted({ battle = battle2 })
  T.eq(Menu.handleInput(battle2, state2), false,
    "a locked action's menu is never claimed either")

  local state3 = Arm.new()
  local battle3 = makeBattle(1, { left = true })
  battle3.player.mon.drainHold = 0
  state3:onBattleStarted({ battle = battle3 })
  T.eq(Menu.handleInput(battle3, state3), true,
    "a stale drainHold left over from HP presentation never blocks this trigger")
end

T.finish("battle_forms_menu")
