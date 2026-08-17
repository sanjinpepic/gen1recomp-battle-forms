-- Gold's own equivalent of src/zmovemenu.lua: the FIGHT-menu redraw for a
-- Dynamaxed Pokemon's substituted move ids, on the one class Gold draws its
-- move list through.
--
-- WHY THIS CANNOT BE src/zmovemenu.lua ITSELF.  That module's own install
-- sets a guard flag on Gen 1's `src.battle.BattleState`/`src.battle.WideBattle`
-- and refuses a second wrap of either; Gold's move list is drawn by a wholly
-- different class (`src.ui.gen2.BattleState`), which zmovemenu.lua never
-- touches at all, so its own idempotency guard is not even in the way -- there
-- was simply nothing there to reuse. This module answers the task's own
-- question ("whether a second roster can register at all") by being a SECOND,
-- independent wrap: its own flag (_battleFormsGen2MoveMenuPatched, distinct
-- from src/gen2menu.lua's own _battleFormsGen2MenuPatched on the identical
-- class) stacked behind BattleState.drawPanel exactly the way
-- src/zmovemenu.lua's own header describes stacking behind src/menu.lua's
-- wrap of the SAME two Gen 1 functions -- each guards itself, so neither
-- wrap costs the other anything.
--
-- WHAT CAN BE PROVEN WITHOUT LOVE2D is the wrap and the geometry constants,
-- never the pixel output -- the identical split src/zmovemenu.lua's own
-- suite states for the identical reason: the redraw only calls love.graphics
-- and Font. The engine class is stubbed into package.loaded, matching both
-- that file's and battle_forms_gen2menu_test.lua's own technique.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Gen2MoveMenu = dofile(MOD .. "/src/gen2movemenu.lua")
local MaxMoves = dofile(MOD .. "/src/maxmoves.lua")
local GMax = dofile(MOD .. "/src/gmaxmoves.lua")
local MAXROWS = dofile(MOD .. "/data/maxmoves.lua")
local GMAXROWS = dofile(MOD .. "/data/gmaxmoves.lua")

local NAMES = MaxMoves.menuNames(MAXROWS)
for id, short in pairs(GMax.menuNames(GMAXROWS, MAXROWS)) do NAMES[id] = short end

local OVERGROWTH_150 = MaxMoves.idFor("MAXOVERGROWTH", 150) -- menu name "OVERGROWTH"

local function fakeMod()
  local logged = {}
  return {
    log = { error = function(_, fmt, ...) logged[#logged + 1] =
      { level = "error", msg = fmt:format(...) } end },
    logged = logged,
  }
end

local function firstLogged(mod, needle)
  for _, line in ipairs(mod.logged) do
    if line.msg:find(needle, 1, true) then return line end
  end
  return nil
end

local savedLoaded = {}
for _, name in ipairs({ "src.ui.gen2.BattleState", "src.render.Font" }) do
  savedLoaded[name] = package.loaded[name]
end

local function stubEngine()
  local calls = { vanilla = 0, drawFont = {} }
  local BattleState = {
    drawPanel = function() calls.vanilla = calls.vanilla + 1 end,
  }
  local Font = {
    draw = function(text, x, y)
      calls.drawFont[#calls.drawFont + 1] = { text = text, x = x, y = y }
    end,
  }
  package.loaded["src.ui.gen2.BattleState"] = BattleState
  package.loaded["src.render.Font"] = Font
  return BattleState, Font, calls
end

love = love or _G.love

-- ---------------------------------------------------------------------
-- Only a "moves" phase, and only a mapped slot, gets redrawn.
-- ---------------------------------------------------------------------
do
  local BattleState, _, calls = stubEngine()
  T.eq(Gen2MoveMenu.install(fakeMod(), NAMES), true, "precondition: install succeeds")

  local battle = { phase = "moves",
                   battle = { player = { moves = {
                     { id = OVERGROWTH_150 }, { id = "TACKLE" },
                   } } } }
  BattleState.drawPanel(battle)
  T.eq(calls.vanilla, 1, "the vanilla drawPanel still ran first")
  T.eq(#calls.drawFont, 1, "exactly the one substituted slot was redrawn")
  T.eq(calls.drawFont[1].text, "OVERGROWTH", "with its own short name")
  T.eq(calls.drawFont[1].x, 16, "at the name column's own pixel x (tile 2)")
  T.eq(calls.drawFont[1].y, 104, "on slot 1's own row (tile 13)")

  calls.drawFont = {}
  battle.phase = "menu"
  BattleState.drawPanel(battle)
  T.eq(#calls.drawFont, 0, "outside the moves phase nothing is redrawn")

  calls.drawFont = {}
  battle.phase = "choose-forget"
  BattleState.drawPanel(battle)
  T.eq(#calls.drawFont, 0,
    "choose-forget is a different list (a level-up's own moves) and is left alone")
end

-- ---------------------------------------------------------------------
-- Four slots: one per row, at the identical geometry.
-- ---------------------------------------------------------------------
do
  local BattleState, _, calls = stubEngine()
  Gen2MoveMenu.install(fakeMod(), NAMES)

  local battle = { phase = "moves",
                   battle = { player = { moves = {
                     { id = "TACKLE" }, { id = OVERGROWTH_150 },
                     { id = "GROWL" },
                     { id = MaxMoves.PREFIX .. "MAXGUARD" },
                   } } } }
  BattleState.drawPanel(battle)
  T.eq(#calls.drawFont, 2, "two mapped slots, GUARD and OVERGROWTH")
  T.eq(calls.drawFont[1].y, 104 + 1 * 8, "slot 2's own row")
  T.eq(calls.drawFont[2].text, "MAX GUARD", "slot 4's own short name")
  T.eq(calls.drawFont[2].y, 104 + 3 * 8, "slot 4's own row")
  T.eq(calls.drawFont[2].x, 16, "the same x every row shares")
end

-- ---------------------------------------------------------------------
-- Malformed input never crashes the wrapped draw.
-- ---------------------------------------------------------------------
do
  local BattleState, _, calls = stubEngine()
  Gen2MoveMenu.install(fakeMod(), NAMES)

  local ok1 = pcall(BattleState.drawPanel, { phase = "moves" })
  T.check(ok1, "no battle at all does not throw")

  local ok2 = pcall(BattleState.drawPanel, { phase = "moves", battle = {} })
  T.check(ok2, "a battle with no player does not throw")

  local ok3 = pcall(BattleState.drawPanel,
    { phase = "moves", battle = { player = { moves = { "not a table" } } } })
  T.check(ok3, "a slot that is not a table does not throw")
  T.eq(#calls.drawFont, 0, "and nothing was drawn for any of it")
end

-- ---------------------------------------------------------------------
-- Idempotency, matching src/gen2menu.lua's own contract.
-- ---------------------------------------------------------------------
do
  local BattleState = stubEngine()
  local vanilla = BattleState.drawPanel

  T.eq(Gen2MoveMenu.install(fakeMod(), NAMES), true, "first install succeeds")
  T.check(BattleState.drawPanel ~= vanilla, "drawPanel was wrapped")

  local wrapped = BattleState.drawPanel
  T.eq(Gen2MoveMenu.install(fakeMod(), NAMES), true,
    "a second install still reports success")
  T.eq(BattleState.drawPanel, wrapped, "and wraps no further")
end

-- ---------------------------------------------------------------------
-- The two wraps stack: src/gen2menu.lua's own drawPanel wrap and this one
-- both reach the class, each guarded by its own flag.
-- ---------------------------------------------------------------------
do
  local BattleState, _, calls = stubEngine()
  local Gen2Menu = dofile(MOD .. "/src/gen2menu.lua")
  local Overlay = dofile(MOD .. "/src/overlay.lua")
  local Formmenu = dofile(MOD .. "/src/formmenu.lua")
  local Transforms = dofile(MOD .. "/src/transforms.lua")
  local Arm = dofile(MOD .. "/src/arm.lua")
  local registry = Transforms.new()
  Overlay.bind({ registry = registry })
  Formmenu.bind({ overlay = Overlay })
  Gen2Menu.bind({ overlay = Overlay, formmenu = Formmenu })

  T.eq(Gen2Menu.install(fakeMod(), Arm.new()), true,
    "src/gen2menu.lua installs first")
  T.eq(Gen2MoveMenu.install(fakeMod(), NAMES), true,
    "and this module still installs behind it")
  T.check(BattleState._battleFormsGen2MenuPatched == true,
    "gen2menu's own flag is set")
  T.check(BattleState._battleFormsGen2MoveMenuPatched == true,
    "and this module's own, DIFFERENT flag is set too")

  local battle = { phase = "moves",
                   battle = { player = { moves = { { id = OVERGROWTH_150 } } } } }
  BattleState.drawPanel(battle)
  T.eq(calls.vanilla, 1, "the real vanilla still ran exactly once through both wraps")
  T.eq(#calls.drawFont, 1, "and this module's own redraw still ran through the stack")
end

-- ---------------------------------------------------------------------
-- Missing/reshaped engine class: refuses cleanly and says so.
-- ---------------------------------------------------------------------
do
  stubEngine()
  package.loaded["src.ui.gen2.BattleState"] = { drawPanel = "not a function" }
  local mod = fakeMod()
  T.eq(Gen2MoveMenu.install(mod, NAMES), false,
    "a BattleState.drawPanel that is not a function refuses")
  T.check(firstLogged(mod, "battle_forms:") ~= nil, "and says so through mod.log")
end

do
  stubEngine()
  package.loaded["src.ui.gen2.BattleState"] = nil
  package.preload["src.ui.gen2.BattleState"] = function() error("no such module") end
  local mod = fakeMod()
  T.eq(Gen2MoveMenu.install(mod, NAMES), false, "an unrequireable BattleState refuses cleanly")
  T.check(firstLogged(mod, "battle_forms:") ~= nil, "and says so")
  package.preload["src.ui.gen2.BattleState"] = nil
end

-- ---------------------------------------------------------------------
-- Font missing costs the redraw its text without costing the wrap.
-- ---------------------------------------------------------------------
do
  local BattleState, _, calls = stubEngine()
  package.loaded["src.render.Font"] = nil
  package.preload["src.render.Font"] = function() error("no font module") end
  local mod = fakeMod()
  T.eq(Gen2MoveMenu.install(mod, NAMES), true,
    "install still succeeds without a Font to draw through")
  local ok = pcall(BattleState.drawPanel,
    { phase = "moves", battle = { player = { moves = { { id = OVERGROWTH_150 } } } } })
  T.check(ok, "and the wrapped draw does not throw reaching for one")
  package.preload["src.render.Font"] = nil
end

-- ---------------------------------------------------------------------
-- An empty or missing name map is survivable.
-- ---------------------------------------------------------------------
do
  local BattleState, _, calls = stubEngine()
  T.eq(Gen2MoveMenu.install(fakeMod(), nil), true, "a nil map still installs")
  BattleState.drawPanel(
    { phase = "moves", battle = { player = { moves = { { id = OVERGROWTH_150 } } } } })
  T.eq(#calls.drawFont, 0, "and redraws nothing without a map")
end

-- ---------------------------------------------------------------------
-- Geometry: derived and pinned, not assumed. The name column starts at
-- pixel 16 (Chrome's own tile 2, matching the vanilla name draw at
-- game/src/ui/gen2/BattleState.lua:3414's `Chrome.print(..., 2, ty)`), and
-- the wipe stops at pixel 112 -- short of pixel 152 (tile 19), where
-- Chrome.printRight right-aligns the PP text (BattleState.lua:3415) even
-- at its own worst case ("40/40", 5 monospace characters, 40px) -- so the
-- wipe can never eat into a PP reading the vanilla draw already painted
-- correctly moments before.
-- ---------------------------------------------------------------------
do
  T.eq(Gen2MoveMenu.NAME_X, 16, "the name column's own pixel x")
  T.eq(Gen2MoveMenu.NAME_WIPE_W, 96, "96px = 12 monospace columns, Gold's own budget")
  T.eq(Gen2MoveMenu.NAME_X + Gen2MoveMenu.NAME_WIPE_W, 112,
    "which stops 40px short of pixel 152, the worst-case PP field's own left edge")
  T.eq(Gen2MoveMenu.ROW_Y0, 104, "the first row's own pixel y (tile 13)")
  T.eq(Gen2MoveMenu.ROW_STEP, 8, "one tile per row")
end

for name, value in pairs(savedLoaded) do package.loaded[name] = value end

T.finish("battle_forms_gen2movemenu")
