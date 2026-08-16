-- The fifth command-menu entry, alongside FIGHT / PKMN / ITEM / RUN: one cell
-- hosting whichever manually activated transformations are on offer.  A on
-- the cell opens src/formmenu.lua's own list -- shaped like the FIGHT menu's
-- own move list, one row per transformation on offer -- rather than arming
-- directly; see that file's header for why LEFT/RIGHT cycling the cell
-- itself was retired rather than kept for the two-or-more case.
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
-- transformations share ONE cell rather than one row apiece: there was never
-- a second row to give the next mechanic, so the cell holds a single label
-- -- generic until something is armed, src/overlay.lua's own `label` -- and
-- opens src/formmenu.lua's own list, drawn in a box of its own, for anything
-- that needs choosing among more than one.
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
--   action   "open" when the submenu list just opened, "toggle" when handled
--            and the armed flag just flipped, "cancel" when the list just
--            closed without changing it -- all three want the confirm sound;
--            nil otherwise
function M.handleInput(battle, state)
  if not battle or battle.phase ~= "menu" or battle.demo or battle.safari then
    return false
  end
  if not deps or not deps.overlay.shouldOffer(state) or not safeToOffer(battle) then
    battle._battleFormsMenuCell = false
    if deps and deps.formmenu then deps.formmenu.close(battle) end
    return false
  end
  local input = battle.game and battle.game.input
  if not input then return false end

  if M.isOnCell(battle) then
    if deps.formmenu.isOpen(battle) then
      return deps.formmenu.handleInput(battle, state)
    end
    -- A opens the submenu rather than arming directly -- see
    -- src/formmenu.lua's own header for why every registered count, not just
    -- two or more, goes through the same list: the cell's own label is the
    -- generic word until something is armed, so a direct toggle here would
    -- arm a transformation the player was never shown by name.
    if input:wasPressed("a") then
      deps.formmenu.open(battle, state)
      return true, "open"
    end
    -- RIGHT/UP/DOWN leave the cell exactly as they always have; LEFT/RIGHT no
    -- longer carry a second meaning now that the list is where selection
    -- among more than one happens.
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

-- None of these columns are new numbers.  `cursor` and `label` are the same
-- ones FIGHT and ITEM already put their cursor and their text in (classic
-- 72/80, wide 168/176).  `limit` is the last printable column inside the
-- command box before its own border -- classic Font.drawBox(8, 12, 12, 6)
-- borders tiles 8 and 19, widescreen Font.drawBox(20, 13, 18, 5) borders
-- tiles 20 and 37, so tiles 18 and 36.  The row is y=120, the blank spacer
-- row between the FIGHT/PKMN line and the ITEM/RUN line, empty in both
-- templates.
--
-- `limit` used to be where the cycle marker parked; the marker is gone (that
-- job moved to src/formmenu.lua's own list, opened from this same cell), but
-- the number survives as what it always secretly was -- the box's own right
-- edge, one tile in from the border -- because a label run past it would
-- print over that border rather than wrapping.
local CELL = {
  classic = { cursor = 72, label = 80, limit = 144 },
  wide = { cursor = 168, label = 176, limit = 288 },
}
M.CELL = CELL

local ROW_Y = 120

-- The HOLLOW arrow, not the solid one.  $ED is the cursor in every menu this
-- engine draws, including the one this cell puts at `cursor` on the same row,
-- and a second solid arrow there would read as a second cursor.
local CURSOR_GLYPH = 0xED

-- Both layouts draw the same two things and differ only in which columns
-- they draw them at, so the decision of WHAT appears is made once instead of
-- twice: a cell that gained a marker in classic alone would be a cell missing
-- from half the game, which is the mistake src/overlay.lua's header exists to
-- prevent for the decisions above it.
local function drawCell(Font, state, at, onCell)
  Font.draw(deps.overlay.label(state), at.label, ROW_Y)
  if onCell then Font.drawCode(CURSOR_GLYPH, at.cursor, ROW_Y) end
end

-- Noted before the shouldOffer check rather than after it, in both draw
-- paths: "the wrapper ran and the decision said no" and "the wrapper is not
-- the function the engine calls" are different bugs, and a note behind the
-- check could not tell them apart.
local function note(battle, key, what)
  local diag = deps and deps.diag
  if diag then pcall(diag.note, battle, key, "wrapper: %s ran", what) end
end

-- The submenu list only ever draws while the cursor is on the cell (opening
-- it from anywhere else is not reachable, see M.handleInput), so the vanilla
-- draw is still called underneath it exactly as it is for the plain cell --
-- compose, never capture, the same rule this file's own header states for
-- the input side.  The list box is sized to fully cover the vanilla command
-- box it draws over (src/formmenu.lua's own header on its geometry), so
-- nothing of FIGHT/PKMN/ITEM/RUN survives visible beneath it.
function M.drawClassic(battle, state, vanillaDraw, Font)
  note(battle, "drawTextArea", "BattleState.drawTextArea")
  if not deps or not deps.overlay.shouldOffer(state) then
    return vanillaDraw(battle)
  end
  local onCell = M.isOnCell(battle)
  withHiddenCursor(battle, onCell, function() vanillaDraw(battle) end)
  if not Font then return end
  love.graphics.setColor(0, 0, 0, 1)
  if onCell and deps.formmenu.isOpen(battle) then
    deps.formmenu.drawClassic(battle, state, Font)
  else
    drawCell(Font, state, CELL.classic, onCell)
  end
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
  if onCell and deps.formmenu.isOpen(battle) then
    deps.formmenu.drawWide(battle, state, Font)
  else
    drawCell(Font, state, CELL.wide, onCell)
  end
end

-- BattleState._battleFormsMenuPatched (and WideBattle's own copy below) is
-- the flag other engine_internals patches in this codebase guard with: a
-- second install (a mod reloaded, or somehow loaded twice) sees it already
-- true and leaves the class alone instead of wrapping its own wrapper.
function M.install(mod, state)
  local diag = deps and deps.diag
  -- The update wrapper is this mod's only per-frame seam and the only place
  -- the live battle arrives without an event, so adoption rides it rather than
  -- patching BattleState.update a second time.  Optional the way diag is: the
  -- unit suites bind neither.
  local adopt = deps and deps.adopt
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
    -- First, ahead of the diagnostic and the input decision both: each of them
    -- reads the arm state, and a mod enabled mid-battle has an arm state that
    -- never learned which battle it is in.
    if adopt then pcall(adopt.consider, self) end
    if diag then
      pcall(diag.note, self, "update", "wrapper: BattleState.update ran")
      pcall(diag.menu, self)
    end
    local ok, handled, action = pcall(M.handleInput, self, state)
    if ok and handled then
      -- "open" (the submenu appearing), "toggle" (a row arming or disarming)
      -- and "cancel" (B closing the submenu) are every action string this
      -- module or src/formmenu.lua ever returns, and all three are a
      -- confirm-shaped moment the same way vanilla's own A/B presses are --
      -- plain cursor movement returns no action and stays silent, matching
      -- the vanilla move list's own convention of a sound on commit, none on
      -- a bare cursor step.
      if action and Sound then
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
