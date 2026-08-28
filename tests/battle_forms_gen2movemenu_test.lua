-- Gold's own equivalent of src/zmovemenu.lua: the FIGHT-menu names for a
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
-- WHAT CAN BE PROVEN WITHOUT LOVE2D.  The module no longer paints anything
-- itself: it swaps `data.moves[id].name` for the short menu spelling, lets
-- the vanilla draw print it, and puts the real name back.  That is testable
-- to the letter without a graphics stack -- the stub records what the name
-- READ AS from inside the vanilla call, which is exactly the thing the pixels
-- used to only imply.  What is still out of reach is the engine's own
-- geometry, and that is the point of the redesign: the old suite pinned four
-- column constants, three of which turned out to be pinning a bug (see the
-- module header's own account of tile 2 vs tile 6).
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
local GUARD = MaxMoves.PREFIX .. "MAXGUARD"                 -- menu name "MAX GUARD"

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

-- The vanilla draw, standing in for Chrome.printThrough: it reads each slot's
-- name out of the move records the way BattleState.lua:3806-3808 does, so
-- `calls.seen` is the list of strings the engine WOULD have printed.
local function stubEngine(throws)
  local calls = { vanilla = 0, seen = {} }
  local BattleState = {
    drawPanel = function(self)
      calls.vanilla = calls.vanilla + 1
      local seen = {}
      local defs = self and self.game and self.game.data and self.game.data.moves
      local moves = self and self.battle and self.battle.player
        and self.battle.player.moves
      if type(defs) == "table" and type(moves) == "table" then
        for i, slot in ipairs(moves) do
          local def = type(slot) == "table" and slot.id and defs[slot.id]
          seen[i] = type(def) == "table" and def.name or nil
        end
      end
      calls.seen[#calls.seen + 1] = seen
      if throws then error("the draw threw") end
    end,
  }
  package.loaded["src.ui.gen2.BattleState"] = BattleState
  return BattleState, calls
end

-- The two real names this mod registers that the old wipe could not cover:
-- fourteen characters and thirteen, against a name field of thirteen tiles.
local function fakeGame()
  return { data = { moves = {
    [OVERGROWTH_150] = { name = "MAX OVERGROWTH" },
    [GUARD] = { name = "MAX GUARD" },
    TACKLE = { name = "TACKLE" },
    GROWL = { name = "GROWL" },
  } } }
end

local function battleWith(game, ids)
  local moves = {}
  for i, id in ipairs(ids) do moves[i] = { id = id } end
  return { phase = "moves", game = game,
           battle = { player = { moves = moves } } }
end

love = love or _G.love

-- ---------------------------------------------------------------------
-- Only a "moves" phase, and only a mapped slot, is renamed -- and the real
-- name is back before the call returns.
-- ---------------------------------------------------------------------
do
  local BattleState, calls = stubEngine()
  T.eq(Gen2MoveMenu.install(fakeMod(), NAMES), true, "precondition: install succeeds")

  local game = fakeGame()
  local battle = battleWith(game, { OVERGROWTH_150, "TACKLE" })
  BattleState.drawPanel(battle)
  T.eq(calls.vanilla, 1, "the vanilla drawPanel ran")
  T.eq(calls.seen[1][1], "OVERGROWTH", "the substituted slot read as its short name")
  T.eq(calls.seen[1][2], "TACKLE", "and an unsubstituted slot was left alone")
  T.eq(game.data.moves[OVERGROWTH_150].name, "MAX OVERGROWTH",
    "the real name is restored the moment the draw returns -- battle text and "
    .. "the save read this same field")

  battle.phase = "menu"
  BattleState.drawPanel(battle)
  T.eq(calls.seen[2][1], "MAX OVERGROWTH", "outside the moves phase nothing is renamed")

  battle.phase = "choose-forget"
  BattleState.drawPanel(battle)
  T.eq(calls.seen[3][1], "MAX OVERGROWTH",
    "choose-forget is a different list (a level-up's own moves) and is left alone")
end

-- ---------------------------------------------------------------------
-- Four slots, two of them substituted, each renamed independently.
-- ---------------------------------------------------------------------
do
  local BattleState, calls = stubEngine()
  Gen2MoveMenu.install(fakeMod(), NAMES)

  local game = fakeGame()
  BattleState.drawPanel(
    battleWith(game, { "TACKLE", OVERGROWTH_150, "GROWL", GUARD }))
  local seen = calls.seen[1]
  T.eq(seen[1], "TACKLE", "slot 1 untouched")
  T.eq(seen[2], "OVERGROWTH", "slot 2 renamed")
  T.eq(seen[3], "GROWL", "slot 3 untouched")
  T.eq(seen[4], "MAX GUARD", "slot 4 renamed")
  T.eq(game.data.moves[OVERGROWTH_150].name, "MAX OVERGROWTH", "slot 2 restored")
  T.eq(game.data.moves[GUARD].name, "MAX GUARD", "slot 4 restored")
end

-- ---------------------------------------------------------------------
-- Two slots sharing ONE record: Charizard's Fire moves all substitute to the
-- same G-MAX WILDFIRE id, so the same table is visited twice.  The undo list
-- must not restore the menu spelling over the real name.
-- ---------------------------------------------------------------------
do
  local BattleState, calls = stubEngine()
  Gen2MoveMenu.install(fakeMod(), NAMES)

  local game = fakeGame()
  BattleState.drawPanel(battleWith(game, { OVERGROWTH_150, OVERGROWTH_150 }))
  T.eq(calls.seen[1][1], "OVERGROWTH", "both slots read as the short name")
  T.eq(calls.seen[1][2], "OVERGROWTH", "including the second visit to that record")
  T.eq(game.data.moves[OVERGROWTH_150].name, "MAX OVERGROWTH",
    "and the shared record is restored ONCE, to the real name")
end

-- ---------------------------------------------------------------------
-- A throwing draw still restores.  A name left swapped would follow the move
-- into battle text and onto the save.
-- ---------------------------------------------------------------------
do
  local BattleState = stubEngine(true)
  Gen2MoveMenu.install(fakeMod(), NAMES)

  local game = fakeGame()
  local ok = pcall(BattleState.drawPanel, battleWith(game, { OVERGROWTH_150 }))
  T.check(not ok, "the draw's own error is not swallowed")
  T.eq(game.data.moves[OVERGROWTH_150].name, "MAX OVERGROWTH",
    "and the name was put back on the way out")
end

-- ---------------------------------------------------------------------
-- Malformed input never crashes the wrapped draw.
-- ---------------------------------------------------------------------
do
  local BattleState = stubEngine()
  Gen2MoveMenu.install(fakeMod(), NAMES)

  T.check(pcall(BattleState.drawPanel, { phase = "moves" }),
    "no battle and no game at all does not throw")
  T.check(pcall(BattleState.drawPanel, { phase = "moves", battle = {} }),
    "a battle with no player does not throw")
  T.check(pcall(BattleState.drawPanel, { phase = "moves", game = fakeGame(),
    battle = { player = { moves = { "not a table" } } } }),
    "a slot that is not a table does not throw")
  T.check(pcall(BattleState.drawPanel, { phase = "moves", game = { data = {} },
    battle = { player = { moves = { { id = OVERGROWTH_150 } } } } }),
    "a game carrying no move records does not throw")
  T.check(pcall(BattleState.drawPanel, { phase = "moves", game = fakeGame(),
    battle = { player = { moves = { { id = "NOSUCHMOVE" } } } } }),
    "a slot naming a move with no record does not throw")
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
  local BattleState, calls = stubEngine()
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

  local game = fakeGame()
  BattleState.drawPanel(battleWith(game, { OVERGROWTH_150 }))
  T.eq(calls.vanilla, 1, "the real vanilla still ran exactly once through both wraps")
  T.eq(calls.seen[1][1], "OVERGROWTH",
    "and this module's own swap still reached it through the stack")
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
-- An empty or missing name map is survivable.
-- ---------------------------------------------------------------------
do
  local BattleState, calls = stubEngine()
  T.eq(Gen2MoveMenu.install(fakeMod(), nil), true, "a nil map still installs")
  local game = fakeGame()
  BattleState.drawPanel(battleWith(game, { OVERGROWTH_150 }))
  T.eq(calls.seen[1][1], "MAX OVERGROWTH", "and renames nothing without a map")
end

-- ---------------------------------------------------------------------
-- The names this mod ships are what made a wipe unworkable, and the reason
-- is worth keeping in front of whoever edits data/gmaxmoves.lua next: the
-- FIGHT menu's name field is tiles 6-18 (Chrome.box(4, 12, 16, 6) counts its
-- own border, so tile 19 IS the border), thirteen columns.  The `menu`
-- spellings fit that; several real `name` values do not, and the engine
-- prints them straight over the border.  Swapping the name means only the
-- short one is ever drawn, so the overrun stops being reachable.
-- ---------------------------------------------------------------------
do
  local NAME_FIELD_TILES = 13
  local overrunning = {}
  for _, row in ipairs(GMAXROWS) do
    if type(row) == "table" and type(row.name) == "string"
        and #row.name > NAME_FIELD_TILES then
      overrunning[#overrunning + 1] = row.name
    end
  end
  T.check(#overrunning > 0,
    "at least one shipped name overruns the field -- G-MAX WILDFIRE is 14 "
    .. "characters, which is what left 'RE' standing past the old wipe")

  local menus = GMax.menuNames(GMAXROWS, MAXROWS)
  local longest = 0
  for _, short in pairs(menus) do longest = math.max(longest, #short) end
  T.check(longest <= NAME_FIELD_TILES,
    "and every menu spelling fits the field it is drawn into")
end

for name, value in pairs(savedLoaded) do package.loaded[name] = value end

T.finish("battle_forms_gen2movemenu")
