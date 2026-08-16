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
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
-- The whole roster: every check below holds for any wired mega, and the
-- OFFICIAL/ALL split is pinned in the eligibility suite.
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- Exactly one transformation registered, which is what ships: everything
-- below is the 0.7.0 menu, unchanged.  The multi-entry cell is pinned in the
-- transforms suite, on a second entry that exists only there.
local registry = Transforms.new()
registry:register(Mega.entry({ eligibility = E, megas = megas,
  keyitems = KeyItems, battlerof = Battlerof }))
Overlay.bind({ registry = registry })
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

-- The trainer's Key Stone, which every fixture here carries: without it the
-- cell is never offered and each check below would pass for the wrong reason.
-- A fresh table per battle because a fixture is free to take it away again.
local function bag()
  return { inventory = { [KeyItems.KEY_STONE] = 1 } }
end

local function makeBattle(menuIndex, pressed)
  return {
    phase = "menu",
    menuIndex = menuIndex,
    queue = {},
    data = hasRecord,
    player = { mon = eligibleMon() },
    game = { save = bag(), input = makeInput(pressed) },
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
    game = { save = bag(), input = makeInput({ left = true }) } }
  state:onBattleStarted({ battle = battle })

  T.eq(Overlay.shouldOffer(state), false, "precondition: an ineligible mon offers nothing")
  T.eq(Menu.handleInput(battle, state), false, "an ineligible mon's menu is never claimed")
  T.eq(battle.menuIndex, 1, "menuIndex is untouched")
  T.eq(Menu.isOnCell(battle), false, "the cursor never leaves the real grid")

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
  T.eq(Overlay.cyclable(state), false,
    "precondition: one transformation leaves the cell a plain label")

  battle.game.input = makeInput({ left = true })
  T.eq(Menu.handleInput(battle, state), true, "left at FIGHT (column 0) is claimed")
  T.eq(Menu.isOnCell(battle), true, "the cursor is now on MEGA")
  T.eq(battle.menuIndex, 1, "the real index is left exactly where it was")

  battle.game.input = makeInput({ right = true })
  T.eq(Menu.handleInput(battle, state), true, "right off MEGA is claimed")
  T.eq(Menu.isOnCell(battle), false, "the cursor is back on the real grid")
  T.eq(battle.menuIndex, 1, "back on FIGHT, unchanged")

  battle.menuIndex = 3 -- ITEM, also column 0
  battle.game.input = makeInput({ left = true })
  Menu.handleInput(battle, state)
  T.eq(Menu.isOnCell(battle), true, "left from ITEM also reaches MEGA")
  battle.game.input = makeInput({ up = true })
  Menu.handleInput(battle, state)
  T.eq(Menu.isOnCell(battle), false, "up off MEGA leaves it too, not just right")
  T.eq(battle.menuIndex, 3, "back on ITEM, unchanged")

  battle.menuIndex = 2 -- PKMN, column 1
  battle.game.input = makeInput({ left = true })
  T.eq(Menu.handleInput(battle, state), false,
    "left from PKMN moves within the real grid, not onto MEGA")
  T.eq(Menu.isOnCell(battle), false, "PKMN cannot reach MEGA directly")
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
  T.eq(Menu.isOnCell(battle), true, "precondition: cursor parked on MEGA")
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

-- ---------------------------------------------------------------------
-- The cell's geometry.  Only one transformation is registered in this file,
-- which is what ships, so the first three checks are the 0.12.0 cell pinned
-- where it was: the label in FIGHT/ITEM's own column and the cursor in
-- theirs, and nothing else drawn on the row.
--
-- The rest is the width budget the cycle marker leaves behind it.  The
-- marker sits in the last column inside the command box -- classic
-- Font.drawBox(8, 12, 12, 6) borders tiles 8 and 19, widescreen
-- Font.drawBox(20, 13, 18, 5) borders 20 and 37 -- so the gap from the label
-- column to it is every pixel a label has.  Classic is the tighter layout
-- and DYNAMAX plus the armed '*' fills it exactly; one more character in any
-- shipping label draws over the marker rather than wrapping, and there is
-- nowhere for either of them to move to.
-- ---------------------------------------------------------------------
do
  local GLYPH = 8 -- the font page's flat advance (src/render/Font.lua)
  local ARMED = 1 -- the '*' src/overlay.lua appends

  T.eq(Menu.CELL.classic.cursor, 72, "classic keeps the cursor in FIGHT/ITEM's column")
  T.eq(Menu.CELL.classic.label, 80, "and the label in the column they print at")
  T.eq(Menu.CELL.wide.cursor, 168, "widescreen keeps its own cursor column")
  T.eq(Menu.CELL.wide.label, 176, "and its own label column")

  T.eq(Menu.CELL.classic.cycle, 18 * 8, "the marker takes classic's last free column")
  T.eq(Menu.CELL.wide.cycle, 36 * 8, "and widescreen's, one in from each right border")

  -- Read out of the sources main.lua itself names, the way the options suite
  -- reads its file list.  A roster mirrored by hand here would keep passing
  -- after the next transformation is registered, which is the single moment
  -- this check exists for.
  local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local body = handle:read("*a")
    handle:close()
    return body
  end
  local labels = {}
  for name in readFile(MOD .. "/main.lua"):gmatch('"(src/[%w_]+%.lua)"') do
    for label in readFile(MOD .. "/" .. name):gmatch('label%s*=%s*"([^"]+)"') do
      labels[#labels + 1] = label
    end
  end
  T.check(#labels >= 2, "the shipping labels were read back out of the sources")

  for _, layout in ipairs({ "classic", "wide" }) do
    local at = Menu.CELL[layout]
    local budget = at.cycle - at.label
    for _, label in ipairs(labels) do
      T.check((#label + ARMED) * GLYPH <= budget,
        ("%s: %s armed fits the %d px the marker leaves a label"):format(
          layout, label, budget))
    end
  end
end

-- ---------------------------------------------------------------------
-- The cell vanishing while the cursor is standing on it.
--
-- Spending the transformation empties the cell mid-battle, and the frame the
-- cursor is parked there is the one most likely to strand it.  handleInput
-- clears _battleFormsMenuCell on the same frame it stops claiming input, and
-- the two have to happen together: a frame handed back to vanilla with the
-- flag still set is a cursor on a cell nothing draws, and both draw paths
-- would already have stopped drawing it.
--
-- Parked from ITEM rather than FIGHT on purpose -- a cursor that came back to
-- the wrong place would land on FIGHT, so returning to FIGHT proves nothing.
-- ---------------------------------------------------------------------
do
  local state = Arm.new()
  local battle = makeBattle(3, {})
  state:onBattleStarted({ battle = battle })
  battle.game.input = makeInput({ left = true })
  Menu.handleInput(battle, state)
  T.eq(Menu.isOnCell(battle), true, "precondition: the cursor is parked on the cell")

  state:consume(Mega.ID)
  T.eq(Overlay.shouldOffer(state), false, "the cell empties under the cursor")

  battle.game.input = makeInput({})
  T.eq(Menu.handleInput(battle, state), false,
    "the very next frame goes straight back to vanilla")
  T.eq(Menu.isOnCell(battle), false, "with the cursor off the cell that is gone")
  T.eq(battle.menuIndex, 3, "and back on ITEM, the real cell it left from")

  -- Every direction, because a stranded cursor is a frame claimed by a cell
  -- that is not drawn and any one of them could be the claim.
  for _, dir in ipairs({ "left", "right", "up", "down", "a" }) do
    battle.game.input = makeInput({ [dir] = true })
    T.eq(Menu.handleInput(battle, state), false,
      dir .. " on the vanished cell is left to vanilla")
    T.eq(Menu.isOnCell(battle), false, "and never puts the cursor back on it")
  end
end

T.finish("battle_forms_menu")
