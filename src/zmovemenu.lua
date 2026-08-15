-- The FIGHT menu's own names for the Z-Move roster, drawn in place of
-- whatever data/zmoves.lua's `name` field spells -- display-time only, the
-- way src/boxmark.lua's marker is presentation and src/persistent.lua's form
-- is derived: nothing here writes to a record, and data.moves[id].name still
-- answers with the move's real name for the battle text row, Mimic and a
-- save.  See data/zmoves.lua's own header for the character budgets this
-- redraw exists to keep every shipped name inside.
--
-- WHY A REDRAW AND NOT A SHORTER RECORD.  M.install already registers the
-- record the engine executes the move through, and its `name` is read from
-- more places than the two this file touches -- the battle text row's "used
-- X!", a save export, a future dex-style move list.  A record carrying the
-- short name would fix the FIGHT menu by breaking every one of those; a
-- redraw fixes the one thing that was actually overflowing and touches
-- nothing else.
--
-- WHY TWO WRAPS AND NOT ONE.  BattleState.drawTextArea (classic) and
-- WideBattle.draw (widescreen) are two entirely separate functions with no
-- draw seam between them -- src/menu.lua's own header explains why: neither
-- layout offers a hook for the moveSelect list, so reaching either one means
-- wrapping the whole draw function that phase is one branch of and
-- overwriting the two or four name cells afterward, the same tile-overwrite
-- technique BattleState.lua's own moveSelect branch already uses to fix up
-- its move box's border corners.
--
-- WHY THIS IS A SEPARATE PATCH FROM src/menu.lua'S RATHER THAN A CHANGE TO
-- IT.  Both wrap the same two functions, and that is fine: each guards
-- itself with its OWN flag on the class table
-- (_battleFormsZMoveMenuPatched, distinct from src/menu.lua's
-- _battleFormsMenuPatched), so the two wraps stack instead of colliding, and
-- src/menu.lua's own cell stays exactly what it was -- a decision about
-- phase "menu", never about "moveSelect".  A single combined wrapper would
-- have to know about a mechanic that has nothing to do with the command
-- menu cell to draw one row inside a phase the cell never appears in.
local M = {}

local deps = nil
function M.bind(modules) deps = modules end

local function record(fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

-- ---- the redraw itself ---------------------------------------------------

-- Classic: BattleState.lua's moveSelect branch draws curMoves[i]'s name at
-- x=48, y=96+i*8, with the move box's own border at x=152 -- see
-- data/zmoves.lua's header for the 13-column budget that comes from.  The
-- wipe goes all the way to the screen edge (160) rather than stopping at the
-- border: an overlong `name` the vanilla draw just printed can run PAST the
-- border, and leaving any of it standing would defeat the redraw.
local CLASSIC_X, CLASSIC_WIPE_W = 48, 160 - 48

local function drawClassic(battle, names, Font)
  local moves = battle and battle.phase == "moveSelect"
    and battle.player and battle.player.curMoves
  if type(moves) ~= "table" then return end
  for i, mv in ipairs(moves) do
    local short = type(mv) == "table" and names[mv.id]
    if short then
      local y = 96 + i * 8
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", CLASSIC_X, y, CLASSIC_WIPE_W, 8)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(short, CLASSIC_X, y)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Widescreen: WideBattle.lua's drawMoveGrid lays curMoves out 2x2, cell (col,
-- row) at x = col==0 and 16 or 120, y = 112+row*16, and hands fitName a 96px
-- budget per cell -- see data/zmoves.lua's header for the 12-column budget
-- that comes from.  Every shipped `menu` name fits inside 96px outright
-- (tests/battle_forms_zmoves_test.lua pins the boundary), so this draws it
-- straight rather than through fitName -- there is nothing left to truncate.
local WIDE_CELL_W = 96

local function drawWide(battle, names, Font)
  local moves = battle and battle.phase == "moveSelect"
    and battle.player and battle.player.curMoves
  if type(moves) ~= "table" then return end
  for i, mv in ipairs(moves) do
    local short = type(mv) == "table" and names[mv.id]
    if short then
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local x, y = col == 0 and 16 or 120, 112 + row * 16
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", x, y, WIDE_CELL_W, 8)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(short, x, y)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---- installation ---------------------------------------------------------
--
-- The same technique src/menu.lua's own install uses: pcall the require,
-- refuse when the shape is not the one expected, guard against a second
-- install patching an already-patched class, and fall back to the vanilla
-- function on any error the wrapper itself raises.  Classic and wide are
-- reported and refused SEPARATELY rather than atomically -- the same
-- contract src/menu.lua keeps (battle_forms_diag_test.lua pins the identical
-- case for it): a widescreen shape change costs widescreen its redraw and
-- nothing else, because a player is on one layout or the other, never both
-- at once, and the classic redraw owes the widescreen one no dependency.

local function installClassic(mod, names, Font)
  local okState, BattleState = pcall(require, "src.battle.BattleState")
  if not okState or type(BattleState) ~= "table" then
    record("zmovemenu: require(src.battle.BattleState) failed (%s)",
      tostring(BattleState))
    if mod.log then
      mod.log:error("battle_forms: src.battle.BattleState is unavailable -- "
        .. "the Z-Move FIGHT menu redraw is disabled in the classic layout")
    end
    return false
  end
  if BattleState._battleFormsZMoveMenuPatched then
    record("zmovemenu: BattleState was already patched -- this load "
      .. "wrapped nothing")
    return true
  end
  if type(BattleState.drawTextArea) ~= "function" then
    record("zmovemenu: BattleState.drawTextArea is not a function -- the "
      .. "redraw is disabled in the classic layout")
    if mod.log then
      mod.log:error("battle_forms: src.battle.BattleState.drawTextArea has "
        .. "changed shape -- the Z-Move FIGHT menu redraw is disabled in "
        .. "the classic layout")
    end
    return false
  end

  local vanillaDraw = BattleState.drawTextArea
  BattleState._battleFormsZMoveMenuPatched = true
  BattleState.drawTextArea = function(self)
    vanillaDraw(self)
    if not Font then return end
    local ok, err = pcall(drawClassic, self, names, Font)
    if not ok then
      record("zmovemenu: the classic redraw failed (%s)", tostring(err))
    end
  end
  record("zmovemenu: install: wrapped BattleState.drawTextArea")
  return true
end

local function installWide(mod, names, Font)
  local okWide, WideBattle = pcall(require, "src.battle.WideBattle")
  if not okWide or type(WideBattle) ~= "table" then
    record("zmovemenu: require(src.battle.WideBattle) failed (%s)",
      tostring(WideBattle))
    if mod.log then
      mod.log:error("battle_forms: src.battle.WideBattle is unavailable -- "
        .. "the Z-Move FIGHT menu redraw is disabled in the widescreen layout")
    end
    return false
  end
  if WideBattle._battleFormsZMoveMenuPatched then
    record("zmovemenu: WideBattle was already patched -- this load wrapped "
      .. "nothing")
    return true
  end
  if type(WideBattle.draw) ~= "function" then
    record("zmovemenu: WideBattle.draw is not a function -- the redraw is "
      .. "disabled in the widescreen layout")
    if mod.log then
      mod.log:error("battle_forms: src.battle.WideBattle.draw has changed "
        .. "shape -- the Z-Move FIGHT menu redraw is disabled in the "
        .. "widescreen layout")
    end
    return false
  end

  local vanillaDraw = WideBattle.draw
  WideBattle._battleFormsZMoveMenuPatched = true
  WideBattle.draw = function(battle)
    vanillaDraw(battle)
    if not Font then return end
    local ok, err = pcall(drawWide, battle, names, Font)
    if not ok then
      record("zmovemenu: the widescreen redraw failed (%s)", tostring(err))
    end
  end
  record("zmovemenu: install: wrapped WideBattle.draw")
  return true
end

-- `names`: the id -> short-name map src/zmoves.lua's M.menuNames builds.  A
-- missing or malformed one is survivable -- the wraps still install, and the
-- redraw simply finds nothing to say for any slot.
function M.install(mod, names)
  names = type(names) == "table" and names or {}

  local okFont, Font = pcall(require, "src.render.Font")
  record("zmovemenu: install: Font %s", okFont and "resolved"
    or ("unavailable (" .. tostring(Font) .. ")"))
  if not okFont then Font = nil end

  local classicOk = installClassic(mod, names, Font)
  local wideOk = installWide(mod, names, Font)
  return classicOk
end

return M
