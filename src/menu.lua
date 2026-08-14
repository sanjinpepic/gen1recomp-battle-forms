-- The fifth command-menu entry, alongside FIGHT / PKMN / ITEM / RUN: one cell
-- hosting whichever manually activated transformations are on offer, reading
-- MEGA today and cycling between them when there is more than one.
--
-- Why not the battle.overlay hook overlay.lua already uses: that seam draws
-- a label, but there is no matching seam for INPUT.  Cursor movement and the
-- FIGHT/PKMN/ITEM/RUN dispatch are one inline block inside
-- BattleState:update (engine/src/battle/BattleState.lua, the real
-- `if self.phase == "menu" then` body), with no hook of their own.  Reaching
-- it means patching BattleState.update itself, which is what the mod's
-- declared `engine_internals` permission is for.
--
-- The geometry question decided the shape of this file.  Neither command
-- box has a free CELL: the classic box (8,12)-(19,17) already spans to the
-- right screen edge, and the wide box (20,13)-(37,17) is already full width
-- too, both with FIGHT/PKMN on one text row and ITEM/RUN on the next.  But
-- both boxes carry a BLANK spacer row between those two text rows (row 15,
-- pixel y=120) -- vanilla leaves it empty in both layouts, on purpose, as
-- breathing room between the lines.  That row is where the cell lives: no new
-- box, no widened box, just two extra draw calls on a row vanilla already
-- reserved and never draws in.  It sits at the same x column FIGHT/ITEM's
-- cursor and text already use, so it reads as another row of the same menu
-- rather than a bolted-on extra.  It is also the reason several
-- transformations share ONE cell and cycle: there was never a second row to
-- give the next mechanic, so the cell had to hold them instead.
--
-- Owning the WHOLE frame while the cursor sits on the cell (rather than trying
-- to intercept one button at a time) is deliberate.  Input:wasPressed does
-- not consume a press -- every reader in the same frame sees it -- so if
-- vanilla's own navigation ran afterward with the real self.menuIndex still
-- pointing at FIGHT or ITEM, an A press meant to arm a transformation would ALSO
-- dispatch FIGHT or ITEM the same frame.  The only clean way to stop that
-- without a consume() this engine has never had is to not call vanilla's
-- update at all on a frame this module claims, and that requires owning the
-- whole frame rather than a single key.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The column each of the four real cells sits in; only column 0 (FIGHT,
-- ITEM) borders the empty space on the left where a departing cursor has
-- anywhere to land.
local function column(battle)
  return (battle.menuIndex - 1) % 2
end

-- The same two guards BattleSafety.inspect applies for battle.menu_auxiliary,
-- MINUS the drainHold/drainFloor check that made START unfixable.  Those two
-- fields track HP-bar presentation catching up and do not apply once phase
-- is already "menu" with an empty queue (BattleState:update's own safety net
-- forces shownHP/shownStatus back in sync on every menu-phase frame, before
-- this ever runs).  hp <= 0 and menuLockedAction are different: they mark
-- frames where the command menu is on screen but about to auto-resolve
-- (forced replacement, a trapped mon's locked move) without ANY player
-- input, and claiming this frame's input instead would freeze that
-- auto-resolve for as long as the cursor stayed on the cell.
local function safeToOffer(battle)
  local player = battle.player
  if not player or not player.mon or player.mon.hp <= 0 then return false end
  if type(battle.menuLockedAction) == "function"
      and battle:menuLockedAction(player) then
    return false
  end
  return true
end

-- True while the cursor is parked on the transformation cell rather than on
-- one of the four real ones.  A plain field on the battle instance: a fresh
-- BattleState backs every battle, so this needs no lifecycle hook of its own
-- to reset between battles the way the armed flag does.
function M.isOnCell(battle)
  return battle ~= nil and battle._battleFormsMenuCell == true
end

-- Runs before BattleState:update's own body every frame.  Returns:
--   handled  true when this frame's input belonged to this module, meaning
--            the installed wrapper must NOT call vanilla update this frame
--   action   "toggle" when handled and the armed flag just flipped, for the
--            confirm sound; nil otherwise
function M.handleInput(battle, state)
  if not battle or battle.phase ~= "menu" or battle.demo or battle.safari then
    return false
  end
  if not deps or not deps.overlay.shouldOffer(state) or not safeToOffer(battle) then
    battle._battleFormsMenuCell = false
    return false
  end
  local input = battle.game and battle.game.input
  if not input then return false end

  if M.isOnCell(battle) then
    if input:wasPressed("a") then
      state:toggle(deps.overlay.selected(state).id)
      return true, "toggle"
    end
    -- With a second transformation on offer the cell becomes a selector and
    -- LEFT/RIGHT cycle it, which costs RIGHT its old job of leaving the cell
    -- -- UP and DOWN still do that, and both lead back to the same column-0
    -- cell the cursor arrived from.  Below two there is nothing to cycle
    -- through, so this branch never runs and the cursor behaves exactly as it
    -- did when MEGA was the only thing here.
    if #deps.overlay.offered(state) > 1 then
      if input:wasPressed("left") then
        deps.overlay.cycle(state, -1)
        return true
      end
      if input:wasPressed("right") then
        deps.overlay.cycle(state, 1)
        return true
      end
    end
    if input:wasPressed("right") or input:wasPressed("up")
        or input:wasPressed("down") then
      battle._battleFormsMenuCell = false
      return true
    end
    -- left (already leftmost) or nothing pressed: stay put, still ours
    return true
  end

  if column(battle) == 0 and input:wasPressed("left") then
    battle._battleFormsMenuCell = true
    return true
  end
  return false
end

-- Both draw paths read battle.menuIndex only for the cursor's col/row, never
-- for which text to print, so aliasing it to a row past the last real one
-- (row 2, where 1-4 never reach) makes vanilla draw its OWN cursor off the
-- bottom of the canvas for one call -- invisible, without touching what it
-- draws for FIGHT/PKMN/ITEM/RUN.  That is what stands in for a "no cursor"
-- mode neither draw function has: the cell's own cursor replaces it instead
-- of sitting beside it.
local HIDE_INDEX = 5

local function withHiddenCursor(battle, onCell, fn)
  local saved = battle.menuIndex
  if onCell then battle.menuIndex = HIDE_INDEX end
  local ok, err = pcall(fn)
  battle.menuIndex = saved
  if not ok then error(err, 0) end
end

-- x=80/176 and cursor x=72/168 are not new numbers: they are the same
-- column FIGHT and ITEM already print at (classic 80, wide 176) and the
-- same column their own cursor already sits in (classic 72, wide 168).
-- The cell is drawn one row below/above them, at y=120 -- the blank spacer
-- row between the FIGHT/PKMN line and the ITEM/RUN line in both templates.
local ROW_Y = 120

-- Noted before the shouldOffer check rather than after it, in both draw
-- paths: "the wrapper ran and the decision said no" and "the wrapper is not
-- the function the engine calls" are different bugs, and a note behind the
-- check could not tell them apart.
local function note(battle, key, what)
  local diag = deps and deps.diag
  if diag then pcall(diag.note, battle, key, "wrapper: %s ran", what) end
end

function M.drawClassic(battle, state, vanillaDraw, Font)
  note(battle, "drawTextArea", "BattleState.drawTextArea")
  if not deps or not deps.overlay.shouldOffer(state) then
    return vanillaDraw(battle)
  end
  local onCell = M.isOnCell(battle)
  withHiddenCursor(battle, onCell, function() vanillaDraw(battle) end)
  if not Font then return end
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(deps.overlay.label(state), 80, ROW_Y)
  if onCell then Font.drawCode(0xED, 72, ROW_Y) end
end

function M.drawWide(battle, state, vanillaDraw, Font)
  note(battle, "wideDraw", "WideBattle.draw")
  if not deps or not deps.overlay.shouldOffer(state) then
    return vanillaDraw(battle)
  end
  local onCell = M.isOnCell(battle)
  withHiddenCursor(battle, onCell, function() vanillaDraw(battle) end)
  if not Font then return end
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(deps.overlay.label(state), 176, ROW_Y)
  if onCell then Font.drawCode(0xED, 168, ROW_Y) end
end

-- BattleState._battleFormsMenuPatched (and WideBattle's own copy below) is
-- the flag other engine_internals patches in this codebase guard with: a
-- second install (a mod reloaded, or somehow loaded twice) sees it already
-- true and leaves the class alone instead of wrapping its own wrapper.
function M.install(mod, state)
  local diag = deps and deps.diag
  local function record(fmt, ...)
    if diag then diag.record(fmt, ...) end
  end

  local okState, BattleState = pcall(require, "src.battle.BattleState")
  if not okState or type(BattleState) ~= "table" then
    record("install: require(src.battle.BattleState) failed (%s)",
      tostring(BattleState))
    if mod.log then
      mod.log:error("battle_forms: src.battle.BattleState unavailable -- "
        .. "the transformation menu cell is disabled")
    end
    return false
  end
  if BattleState._battleFormsMenuPatched then
    -- Worth a line of its own rather than a silent success: an install that
    -- finds the guard already set wraps NOTHING, so the wrappers doing the
    -- work belong to whichever load got here first and close over that load's
    -- arm state -- which is a live cell fed by a state nothing updates.
    record("install: BattleState was already patched -- this load wrapped "
      .. "nothing and the wrappers in place close over an earlier load's "
      .. "arm state")
    return true
  end
  record("install: BattleState resolved, no earlier patch")
  BattleState._battleFormsMenuPatched = true

  local okFont, Font = pcall(require, "src.render.Font")
  -- Font going missing costs the cell its text without costing anything else,
  -- which draws as a menu that looks exactly like a menu with no cell.
  record("install: Font %s", okFont and "resolved"
    or ("unavailable (" .. tostring(Font) .. ")"))
  if not okFont then Font = nil end
  local okSound, Sound = pcall(require, "src.core.Sound")
  if not okSound then Sound = nil end

  local vanillaUpdate = BattleState.update
  BattleState.update = function(self, dt)
    if diag then
      pcall(diag.note, self, "update", "wrapper: BattleState.update ran")
      pcall(diag.menu, self)
    end
    local ok, handled, action = pcall(M.handleInput, self, state)
    if ok and handled then
      if action == "toggle" and Sound then
        pcall(Sound.play, self.data, "Press_AB")
      end
      self:tickFx()
      return
    end
    return vanillaUpdate(self, dt)
  end

  local vanillaDrawTextArea = BattleState.drawTextArea
  BattleState.drawTextArea = function(self)
    local ok = pcall(M.drawClassic, self, state, vanillaDrawTextArea, Font)
    if not ok then pcall(vanillaDrawTextArea, self) end
  end

  record("install: wrapped BattleState.update and BattleState.drawTextArea")

  -- Reported separately from the classic pair because it is separately
  -- survivable and separately fatal: a widescreen battle draws through this
  -- function and never through drawTextArea, so this one failing to wrap
  -- takes the cell away in widescreen alone.
  local okWide, WideBattle = pcall(require, "src.battle.WideBattle")
  local wide
  if not okWide or type(WideBattle) ~= "table" then
    wide = "unavailable (" .. tostring(WideBattle) .. ")"
  elseif type(WideBattle.draw) ~= "function" then
    wide = "has no draw function to wrap"
  elseif WideBattle._battleFormsMenuPatched then
    wide = "was already patched"
  else
    WideBattle._battleFormsMenuPatched = true
    local vanillaWideDraw = WideBattle.draw
    WideBattle.draw = function(battle)
      local ok = pcall(M.drawWide, battle, state, vanillaWideDraw, Font)
      if not ok then pcall(vanillaWideDraw, battle) end
    end
    wide = "wrapped"
  end
  record("install: WideBattle.draw %s", wide)

  return true
end

return M
