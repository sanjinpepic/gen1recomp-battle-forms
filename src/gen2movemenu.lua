-- Gold's own equivalent of src/zmovemenu.lua: the FIGHT-menu display for a
-- Dynamaxed Pokemon's substituted move ids, showing data/maxmoves.lua's and
-- data/gmaxmoves.lua's own short `menu` spelling in place of the long `name`
-- those rows register -- display-time only, the same split src/zmovemenu.lua's
-- own header keeps: nothing here writes to a save, and data.moves[id].name
-- still answers with the move's real name everywhere outside the one draw.
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
-- module's swap compose rather than collide.
--
-- WHY drawPanel AND NOT A SEPARATE HOOK. Gold draws its whole command box,
-- move list and message box through one function
-- (game/src/ui/gen2/BattleState.lua:3355-3445, branching on `self.phase`),
-- the same reason src/gen2menu.lua wraps it for the "menu" phase -- there is
-- no per-phase draw seam to reach instead.
--
-- WHY A SWAP BEFORE THE DRAW AND NOT A REDRAW OVER THE TOP.  This module
-- used to let the vanilla name print and then paint a white rectangle over
-- it, which cost two bugs at once and could not have avoided a third:
--
--   * The rectangle was placed at tile 2 from a reading of the vanilla draw
--     that had picked the wrong branch.  BattleState.lua:3790-3791 chooses
--     per screen -- `cursorCol = moveMenu and 5 or 1`, `nameCol = moveMenu
--     and 6 or 2` -- and 2 is the forget-move screen, not the FIGHT menu.
--     So the wipe painted a column to the LEFT of the real one: the vanilla
--     name stayed put and the Max Move name landed beside it, two names to
--     a row, while the rectangle's own left edge swallowed the cursor in the
--     gutter at tile 5 and the hovered row showed nothing.
--
--   * Its 96px width came from budgeting around a PP field the FIGHT menu
--     does not draw -- BattleState.lua:3810 guards `Chrome.printRightThrough`
--     with `if not moveMenu then`, so PP belongs to the forget screen and to
--     drawMoveInfoBox, never to a row here.
--
--   * And no width could have finished the job.  `Chrome.box(4, 12, 16, 6)`
--     is sixteen tiles INCLUDING its border, so the name field is tiles 6-18
--     and the border sits on 19 -- which "G-MAX WILDFIRE" (fourteen
--     characters, and gmaxmoves.lua's own header notes every other row is at
--     least that long) overruns by a character.  A wipe short of tile 19
--     leaves that character standing; a wipe covering it punches a hole in
--     the box border.
--
-- Swapping the name for the duration of the vanilla call has none of those
-- edges: the engine prints the short spelling itself, at whatever column,
-- box and palette it decides are right, and this module never needs to know
-- the geometry it kept getting wrong.  Registry:freeze only refuses further
-- registration (game/src/mods/Registry.lua:38-39, :277) -- built records
-- carry no __newindex -- so the field is writable, and it is put back before
-- the call returns whether or not the draw throws.
local M = {}

local function record(deps, fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

-- Point each substituted slot's record at its short name, returning the undo
-- list.  Two slots can share one record -- Charizard's Fire moves all become
-- G-MAX WILDFIRE -- so the `~= short` guard doubles as the de-duplicator: the
-- second visit finds the swap already made and saves nothing, which is what
-- keeps the undo list from restoring a name over a name.
local function swapNames(uiBattle, names)
  local game = uiBattle and uiBattle.game
  local defs = game and game.data and game.data.moves
  local battle = uiBattle and uiBattle.battle
  local mon = battle and battle.player
  local moves = mon and mon.moves
  if type(defs) ~= "table" or type(moves) ~= "table" then return nil end
  local saved
  for _, slot in ipairs(moves) do
    local id = type(slot) == "table" and slot.id or nil
    local short = id ~= nil and names[id] or nil
    local def = short and defs[id] or nil
    if type(def) == "table" and def.name ~= short then
      saved = saved or {}
      saved[#saved + 1] = { def = def, name = def.name }
      def.name = short
    end
  end
  return saved
end

local function restoreNames(saved)
  if not saved then return end
  for i = 1, #saved do saved[i].def.name = saved[i].name end
end

-- `names`: the id -> short-name map src/maxmoves.lua's and
-- src/gmaxmoves.lua's own M.menuNames build, merged by main.lua the same
-- way it already merges src/zmoves.lua's, src/speciesz.lua's and
-- src/gmaxmoves.lua's own maps into `zMenuNames`. A missing or malformed
-- map is survivable -- the wrap still installs, and the draw simply finds
-- nothing to rename for any slot.
--
-- `diag` is optional, the way it is for every other engine_internals patch
-- in this mod: main.lua passes it, the unit suite does not.
function M.install(mod, names, deps)
  names = type(names) == "table" and names or {}

  local okState, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not okState or type(BattleState) ~= "table" then
    record(deps, "gen2movemenu: require(src.ui.gen2.BattleState) failed (%s)",
      tostring(BattleState))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BattleState is unavailable -- "
        .. "the Gold Max Move FIGHT menu names are disabled")
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
      .. "the swap is disabled")
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BattleState.drawPanel has "
        .. "changed shape -- the Gold Max Move FIGHT menu names are disabled")
    end
    return false
  end

  local vanillaDrawPanel = BattleState.drawPanel
  BattleState._battleFormsGen2MoveMenuPatched = true
  BattleState.drawPanel = function(self)
    if type(self) ~= "table" or self.phase ~= "moves" then
      return vanillaDrawPanel(self)
    end
    local okSwap, saved = pcall(swapNames, self, names)
    if not okSwap then
      record(deps, "gen2movemenu: the name swap failed (%s)", tostring(saved))
      saved = nil
    end
    -- Protected so a throwing draw still puts every name back: a record left
    -- carrying its menu spelling would follow the move into battle text and
    -- onto the save's own move list.
    local okDraw, err = pcall(vanillaDrawPanel, self)
    restoreNames(saved)
    if not okDraw then error(err, 0) end
  end
  record(deps, "gen2movemenu: install: wrapped BattleState.drawPanel")
  return true
end

return M
