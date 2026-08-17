-- Gold's own equivalent of src/zmovemenu.lua: the FIGHT-menu redraw for a
-- Dynamaxed Pokemon's substituted move ids, drawn in place of whatever
-- data/maxmoves.lua's/data/gmaxmoves.lua's own registered `name` field
-- spells -- display-time only, the same split src/zmovemenu.lua's own
-- header keeps: nothing here writes to a record, and data.moves[id].name
-- still answers with the move's real name for the battle text row and a
-- save.
--
-- WHY THIS IS A SEPARATE FILE FROM src/zmovemenu.lua RATHER THAN A GEN 2
-- BRANCH INSIDE IT. That module's own install guards itself with a flag on
-- Gen 1's `src.battle.BattleState`/`src.battle.WideBattle` and can only be
-- called once -- but Gold's move list is drawn by a wholly DIFFERENT class,
-- `src.ui.gen2.BattleState`, which src/zmovemenu.lua never touches at all.
-- So "whether a second roster can register" has a straightforward answer:
-- yes, because this is not a second call into the same guard, it is a wrap
-- of a class that guard was never protecting.  What this file's OWN install
-- can only do once is wrap `src.ui.gen2.BattleState.drawPanel` a second
-- time -- and it can, behind its own flag
-- (_battleFormsGen2MoveMenuPatched), stacked exactly the way
-- src/zmovemenu.lua's own header describes stacking behind src/menu.lua's
-- wrap of the identical two Gen 1 functions: each guards itself, so
-- src/gen2menu.lua's own wrap of this SAME method (the FORM cell) and this
-- module's redraw compose rather than collide.
--
-- WHY drawPanel AND NOT A SEPARATE HOOK. Gold draws its whole command box,
-- move list and message box through one function
-- (game/src/ui/gen2/BattleState.lua:3355-3445, branching on `self.phase`),
-- the same reason src/gen2menu.lua wraps it for the "menu" phase -- there is
-- no per-phase draw seam to reach instead.  The move-list branch prints
-- `Chrome.print(name, 2, ty)` then `Chrome.printRight("%d/%d", 19, ty)`
-- (:3412-3415) for every slot in `self.battle.player.moves` -- Gold's
-- substituted move array, since src/gen2substitute.lua mutates that exact
-- table in place rather than swapping a battler-scoped `curMoves`.
--
-- WHY 12 COLUMNS, DERIVED RATHER THAN ASSUMED.  Gold has no widescreen
-- battle path, so there is one budget, not Gen 1's classic/wide pair. The
-- name draws at tile 2 (pixel 16); the PP field right-aligns to tile 19
-- (pixel 152, Chrome.printRight's own "exclusive" end) and, at its own worst
-- case -- two-digit current and two-digit maximum, "40/40", five monospace
-- characters at Font's flat 8px advance -- starts no earlier than pixel 112.
-- 152 - 40 - 16 = 96 pixels, twelve columns, between the name's own start
-- and the PP field's own worst-case left edge. data/maxmoves.lua's and
-- data/gmaxmoves.lua's own `menu` fields are already built to that budget
-- (tests/battle_forms_maxmoves_test.lua and this module's own suite both
-- pin it), reused here rather than re-derived so the wipe rectangle can
-- never undershoot a name it is about to paint, nor stray into a PP reading
-- the vanilla draw already painted correctly moments before.
local M = {}

local function record(deps, fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

-- Pixel x=16 (tile 2), matching the vanilla name draw's own column; wipe
-- width 96 (twelve monospace columns), this module's own derivation above.
M.NAME_X, M.NAME_WIPE_W = 16, 96
-- Pixel y=104 (tile 13), matching the vanilla move list's own first row
-- (`ty = 13 + (i - 1)`); one tile (8px) per row after that.
M.ROW_Y0, M.ROW_STEP = 104, 8

local function drawMoveNames(uiBattle, names, Font)
  local engineBattle = uiBattle and uiBattle.battle
  local mon = engineBattle and engineBattle.player
  local moves = mon and mon.moves
  if type(moves) ~= "table" then return end
  for i, slot in ipairs(moves) do
    local short = type(slot) == "table" and names[slot.id]
    if short then
      local y = M.ROW_Y0 + (i - 1) * M.ROW_STEP
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", M.NAME_X, y, M.NAME_WIPE_W, 8)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(short, M.NAME_X, y)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- `names`: the id -> short-name map src/maxmoves.lua's and
-- src/gmaxmoves.lua's own M.menuNames build, merged by main.lua the same
-- way it already merges src/zmoves.lua's, src/speciesz.lua's and
-- src/gmaxmoves.lua's own maps into `zMenuNames`. A missing or malformed
-- map is survivable -- the wrap still installs, and the redraw simply finds
-- nothing to say for any slot.
--
-- `diag` is optional, the way it is for every other engine_internals patch
-- in this mod: main.lua passes it, the unit suite does not.
function M.install(mod, names, deps)
  names = type(names) == "table" and names or {}

  local okFont, Font = pcall(require, "src.render.Font")
  record(deps, "gen2movemenu: install: Font %s", okFont and "resolved"
    or ("unavailable (" .. tostring(Font) .. ")"))
  if not okFont then Font = nil end

  local okState, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not okState or type(BattleState) ~= "table" then
    record(deps, "gen2movemenu: require(src.ui.gen2.BattleState) failed (%s)",
      tostring(BattleState))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BattleState is unavailable -- "
        .. "the Gold Max Move FIGHT menu redraw is disabled")
    end
    return false
  end
  if BattleState._battleFormsGen2MoveMenuPatched then
    record(deps, "gen2movemenu: BattleState was already patched -- this "
      .. "load wrapped nothing")
    return true
  end
  if type(BattleState.drawPanel) ~= "function" then
    record(deps, "gen2movemenu: BattleState.drawPanel is not a function -- "
      .. "the redraw is disabled")
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BattleState.drawPanel has "
        .. "changed shape -- the Gold Max Move FIGHT menu redraw is disabled")
    end
    return false
  end

  local vanillaDrawPanel = BattleState.drawPanel
  BattleState._battleFormsGen2MoveMenuPatched = true
  BattleState.drawPanel = function(self)
    vanillaDrawPanel(self)
    if self.phase ~= "moves" or not Font then return end
    local ok, err = pcall(drawMoveNames, self, names, Font)
    if not ok then
      record(deps, "gen2movemenu: the redraw failed (%s)", tostring(err))
    end
  end
  record(deps, "gen2movemenu: install: wrapped BattleState.drawPanel")
  return true
end

return M
