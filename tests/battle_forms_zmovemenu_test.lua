-- The FIGHT menu redraw: takes data/zmoves.lua's `menu` names (proven to fit
-- both layouts in tests/battle_forms_zmoves_test.lua) and puts them where the
-- engine drew the overlong `name` a moment before, on both the classic and
-- the widescreen move list.
--
-- What is proven here is the WRAP, not the pixels -- src/menu.lua's own test
-- draws the same line: "What can be proven without love2d: the input
-- decision, never the two draw functions -- those only call love.graphics and
-- Font, and are exercised by hand in-game instead."  The engine classes are
-- stubbed into package.loaded, matching battle_forms_diag_test.lua's own
-- technique, so the real game/src/battle files are never touched and the
-- wrapped functions can be called directly to prove they are what the engine
-- would actually reach.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local ZMoveMenu = dofile(MOD .. "/src/zmovemenu.lua")
local ZMoves = dofile(MOD .. "/src/zmoves.lua")
local ROWS = dofile(MOD .. "/data/zmoves.lua")

local NAMES = ZMoves.menuNames(ROWS)
local GIGAVOLT_175 = ZMoves.idFor("GIGAVOLTHAVOC", 175) -- menu name "VOLT HAVOC"

local function fakeMod()
  local logged = {}
  return {
    log = {
      error = function(_, fmt, ...) logged[#logged + 1] =
        { level = "error", msg = fmt:format(...) } end,
    },
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
for _, name in ipairs({ "src.battle.BattleState", "src.battle.WideBattle",
                        "src.render.Font" }) do
  savedLoaded[name] = package.loaded[name]
end

local function stubEngine(withWide)
  local calls = { classicVanilla = 0, wideVanilla = 0, drawFont = {} }
  local BattleState = {
    drawTextArea = function() calls.classicVanilla = calls.classicVanilla + 1 end,
  }
  local WideBattle = withWide and {
    draw = function() calls.wideVanilla = calls.wideVanilla + 1 end,
  } or nil
  local Font = {
    draw = function(text, x, y)
      calls.drawFont[#calls.drawFont + 1] = { text = text, x = x, y = y }
    end,
  }
  package.loaded["src.battle.BattleState"] = BattleState
  package.loaded["src.battle.WideBattle"] = WideBattle
  package.loaded["src.render.Font"] = Font
  return BattleState, WideBattle, Font, calls
end

love = love or _G.love

-- ---------------------------------------------------------------------
-- Classic: only a moveSelect frame, and only the slots this file has a
-- short name for, get redrawn -- an ordinary move (no entry in the map) is
-- left exactly as the vanilla draw left it.
-- ---------------------------------------------------------------------
do
  local BattleState, _, _, calls = stubEngine(true)
  T.eq(ZMoveMenu.install(fakeMod(), NAMES), true, "precondition: install succeeds")

  local battle = { phase = "moveSelect",
                   player = { curMoves = {
                     { id = GIGAVOLT_175 }, { id = "THUNDERBOLT" },
                   } } }
  BattleState.drawTextArea(battle)
  T.eq(calls.classicVanilla, 1, "the vanilla draw still ran first")
  T.eq(#calls.drawFont, 1, "exactly the one Z-Move slot was redrawn")
  T.eq(calls.drawFont[1].text, "VOLT HAVOC", "with its own short name")
  T.eq(calls.drawFont[1].x, 48, "at the same x the vanilla name started at")
  T.eq(calls.drawFont[1].y, 96 + 1 * 8, "on its own row")

  calls.drawFont = {}
  battle.phase = "menu"
  BattleState.drawTextArea(battle)
  T.eq(#calls.drawFont, 0, "outside moveSelect nothing is redrawn")

  calls.drawFont = {}
  battle.phase = "mimicSelect"
  BattleState.drawTextArea(battle)
  T.eq(#calls.drawFont, 0,
    "mimicSelect is a different list (the ENEMY's moves) and is left alone")
end

-- ---------------------------------------------------------------------
-- Widescreen: the 2x2 grid, same rule -- only a mapped id is redrawn, at
-- its own cell's column and row.
-- ---------------------------------------------------------------------
do
  local _, WideBattle, _, calls = stubEngine(true)
  ZMoveMenu.install(fakeMod(), NAMES)

  local battle = { phase = "moveSelect",
                   player = { curMoves = {
                     { id = "TACKLE" }, { id = GIGAVOLT_175 },
                     { id = "GROWL" }, { id = "THUNDERWAVE" },
                   } } }
  WideBattle.draw(battle)
  T.eq(calls.wideVanilla, 1, "the vanilla wide draw still ran first")
  T.eq(#calls.drawFont, 1, "one redraw, for the one Z-Move slot")
  T.eq(calls.drawFont[1].text, "VOLT HAVOC", "the same short name as classic")
  -- slot 2 -> col 1, row 0: x = 120, y = 112
  T.eq(calls.drawFont[1].x, 120, "at slot 2's column")
  T.eq(calls.drawFont[1].y, 112, "and slot 2's row")
end

-- ---------------------------------------------------------------------
-- Malformed input never crashes the wrapped draw: no player, no curMoves,
-- a slot that is not a table.  All of it falls through to "nothing redrawn"
-- rather than an error a battle screen cannot survive.
-- ---------------------------------------------------------------------
do
  local BattleState, WideBattle, _, calls = stubEngine(true)
  ZMoveMenu.install(fakeMod(), NAMES)

  local ok1 = pcall(BattleState.drawTextArea, { phase = "moveSelect" })
  T.check(ok1, "no player at all does not throw")

  local ok2 = pcall(BattleState.drawTextArea,
    { phase = "moveSelect", player = {} })
  T.check(ok2, "a player with no curMoves does not throw")

  local ok3 = pcall(WideBattle.draw,
    { phase = "moveSelect", player = { curMoves = { "not a table" } } })
  T.check(ok3, "a slot that is not a table does not throw")
  T.eq(#calls.drawFont, 0, "and nothing was drawn for any of it")
end

-- ---------------------------------------------------------------------
-- Idempotency, matching src/menu.lua's own contract: a second install wraps
-- neither function again and still reports success.
-- ---------------------------------------------------------------------
do
  local BattleState, WideBattle = stubEngine(true)
  local vanillaClassic, vanillaWide = BattleState.drawTextArea, WideBattle.draw

  T.eq(ZMoveMenu.install(fakeMod(), NAMES), true, "first install succeeds")
  T.check(BattleState.drawTextArea ~= vanillaClassic, "classic was wrapped")
  T.check(WideBattle.draw ~= vanillaWide, "wide was wrapped")

  local wrappedClassic, wrappedWide = BattleState.drawTextArea, WideBattle.draw
  T.eq(ZMoveMenu.install(fakeMod(), NAMES), true,
    "a second install still reports success")
  T.eq(BattleState.drawTextArea, wrappedClassic, "and wraps classic no further")
  T.eq(WideBattle.draw, wrappedWide, "nor wide")
end

-- ---------------------------------------------------------------------
-- Widescreen missing is survivable and separately reported -- the same
-- contract src/menu.lua's own install keeps (battle_forms_diag_test.lua
-- pins the identical case for that file): the classic redraw still installs
-- and only the wide one is refused.
-- ---------------------------------------------------------------------
do
  local BattleState = stubEngine(false)
  package.loaded["src.battle.WideBattle"] = { draw = "not a function" }
  local mod = fakeMod()
  T.eq(ZMoveMenu.install(mod, NAMES), true,
    "classic installing is enough for a true result")
  T.check(BattleState.drawTextArea ~= nil, "classic is still wrapped")
  T.check(firstLogged(mod, "battle_forms:") ~= nil,
    "and the wide refusal is still said out loud")
end

-- ---------------------------------------------------------------------
-- A guard that refuses must say so out loud: a classic seam the engine no
-- longer offers builds nothing rather than something fragile -- and does not
-- stop the widescreen half from installing on its own, the same independence
-- proven the other way round above.
-- ---------------------------------------------------------------------
do
  stubEngine(true)
  package.loaded["src.battle.BattleState"] = { drawTextArea = "not a function" }
  local mod = fakeMod()
  T.eq(ZMoveMenu.install(mod, NAMES), false,
    "a BattleState.drawTextArea that is not a function refuses the classic half")
  T.check(firstLogged(mod, "battle_forms:") ~= nil, "and says so through mod.log")
  local WideBattle = package.loaded["src.battle.WideBattle"]
  T.check(WideBattle.draw ~= nil and WideBattle._battleFormsZMoveMenuPatched,
    "but the widescreen half installs anyway -- neither owes the other a "
      .. "dependency")
end

do
  stubEngine(true)
  package.loaded["src.battle.BattleState"] = nil
  package.preload["src.battle.BattleState"] = function() error("no such module") end
  local mod = fakeMod()
  T.eq(ZMoveMenu.install(mod, NAMES), false,
    "an unrequireable BattleState refuses cleanly")
  T.check(firstLogged(mod, "battle_forms:") ~= nil, "and says so")
  package.preload["src.battle.BattleState"] = nil
end

-- ---------------------------------------------------------------------
-- Font missing costs the redraw its text without costing the wrap: the same
-- degradation src/menu.lua's own cell accepts when its Font require fails.
-- ---------------------------------------------------------------------
do
  local BattleState, _, _, calls = stubEngine(true)
  package.loaded["src.render.Font"] = nil
  package.preload["src.render.Font"] = function() error("no font module") end
  local mod = fakeMod()
  T.eq(ZMoveMenu.install(mod, NAMES), true,
    "install still succeeds without a Font to draw through")
  local ok = pcall(BattleState.drawTextArea,
    { phase = "moveSelect", player = { curMoves = { { id = GIGAVOLT_175 } } } })
  T.check(ok, "and the wrapped draw does not throw reaching for one")
  package.preload["src.render.Font"] = nil
end

-- ---------------------------------------------------------------------
-- An empty or missing name map is survivable: install still wraps, and the
-- wrapped draw simply redraws nothing.
-- ---------------------------------------------------------------------
do
  local BattleState, _, _, calls = stubEngine(true)
  T.eq(ZMoveMenu.install(fakeMod(), nil), true, "a nil map still installs")
  BattleState.drawTextArea({ phase = "moveSelect",
                             player = { curMoves = { { id = GIGAVOLT_175 } } } })
  T.eq(#calls.drawFont, 0, "and redraws nothing without a map")
end

for name, value in pairs(savedLoaded) do package.loaded[name] = value end

T.finish("battle_forms_zmovemenu")
