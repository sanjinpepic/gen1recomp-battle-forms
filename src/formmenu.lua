-- The submenu the gimmick cell opens: a list of every transformation
-- currently on offer, navigated and confirmed the way the FIGHT menu's own
-- move list is -- UP/DOWN move a cursor, A confirms the highlighted row, B
-- backs out -- so LEFT/RIGHT stop doing double duty between "move between
-- commands" and "cycle between transformations" and go back to meaning only
-- the first one.
--
-- Ownership: this module never runs unless src/menu.lua's own handleInput has
-- already decided the cursor is on the gimmick cell (Menu.isOnCell) and the
-- battle is safe to claim input for, so it inherits that module's whole-frame
-- ownership guarantee rather than re-deriving it -- see src/menu.lua's own
-- header for why owning the whole frame is the only way to intercept A/B at
-- all without a consume() this engine has never had.
--
-- Two fields live directly on the battle instance, the same way
-- src/menu.lua's own `_battleFormsMenuCell` does and for the identical
-- reason: a fresh BattleState backs every battle, so nothing needs to reset
-- them between battles or between mod loads.
--
-- ARMING STAYS A REAL OPERATION WITH REAL SIDE EFFECTS.  src/arm.lua's
-- `toggle` is what substitutes a Dynamax or Z-Move moveset the instant a
-- transformation arms, precisely so the FIGHT menu it is about to open
-- already lists the new moves -- see that file's own header.  This module
-- calls that exact function, unchanged, from exactly one place: A on a row.
-- Every other input here -- opening the list, moving the cursor, cancelling
-- with B -- touches neither `toggle` nor `select`, on purpose.  `select` in
-- particular disarms whenever the highlighted id changes (src/arm.lua's own
-- `retarget`), which is precisely the trap a naive "drive the cursor through
-- select() so the cell's label stays in sync" implementation would fall
-- into: merely moving the cursor to preview a different row would silently
-- unwind whatever was already armed before the player had committed to
-- anything, and cancelling out with B would then leave a transformation
-- disarmed that the player never asked to touch.  Keeping the cursor a
-- plain local index instead means nothing changes until A actually confirms
-- a row, so a cancel never has anything of its own to unwind -- whatever was
-- armed on entry is exactly what is still armed on exit.
local M = {}

local deps = nil
function M.bind(modules) deps = modules end

function M.isOpen(battle)
  return battle ~= nil and battle._battleFormsListOpen == true
end

-- The row the cursor is on, 1-based into deps.overlay.offered(state) -- an
-- accessor rather than leaving callers to reach into the battle-scoped field
-- directly, the same reason src/menu.lua exposes M.isOnCell instead of its
-- own `_battleFormsMenuCell`.
function M.index(battle)
  return battle and battle._battleFormsListIndex
end

function M.close(battle)
  if battle then battle._battleFormsListOpen = false end
end

-- The row the list opens on.  Armed beats a merely-remembered selection beats
-- the first entry, so re-opening the list while something is armed always
-- starts the cursor on the thing that is actually active rather than making
-- the player hunt for it -- the requirement that re-opening while armed must
-- let the player see and change what is armed, not just infer it from the
-- cell's own label.
local function defaultIndex(offered, state)
  local armedId = state:armed()
  local selectedId = state:selected()
  local fallback = 1
  for i, entry in ipairs(offered) do
    if armedId and entry.id == armedId then return i end
    if entry.id == selectedId then fallback = i end
  end
  return fallback
end

-- Called once, on the same frame A opens the list.  Snapshotting the count
-- here is not needed -- M.handleInput re-reads `deps.overlay.offered` fresh
-- on every call of its own -- but the starting row is decided once, the
-- moment the list appears, exactly like the FIGHT menu's own move cursor.
function M.open(battle, state)
  if not battle then return end
  local offered = deps.overlay.offered(state, battle)
  battle._battleFormsListOpen = true
  battle._battleFormsListIndex = defaultIndex(offered, state)
end

-- Called only while M.isOpen(battle) is true.  Returns the same (handled,
-- action) shape src/menu.lua's own handleInput does, so the frame-ownership
-- and confirm-sound wiring in that file's BattleState.update wrapper need
-- nothing special for this module.
function M.handleInput(battle, state)
  local input = battle.game and battle.game.input
  if not input then return true end
  local offered = deps.overlay.offered(state, battle)
  local count = #offered
  if count == 0 then
    -- Nothing left to show -- the mon that carried the last entry's item
    -- switched out, or its predicate turned false, while the list itself
    -- stayed open.  src/menu.lua's own guard already closes this list the
    -- moment shouldOffer goes false on the frame it notices; this is the
    -- same refusal reached from inside an already-open list instead, so a
    -- frame where both happen at once still leaves nothing drawing zero
    -- rows.
    M.close(battle)
    return true
  end
  local index = battle._battleFormsListIndex or 1
  if index > count then index = count end

  if input:wasPressed("up") then
    battle._battleFormsListIndex = index > 1 and index - 1 or count
    return true
  end
  if input:wasPressed("down") then
    battle._battleFormsListIndex = index < count and index + 1 or 1
    return true
  end
  if input:wasPressed("b") then
    M.close(battle)
    return true, "cancel"
  end
  if input:wasPressed("a") then
    local entry = offered[index]
    state:toggle(entry.id)
    M.close(battle)
    return true, "toggle"
  end
  battle._battleFormsListIndex = index
  return true
end

-- ---- drawing ----------------------------------------------------------
--
-- What can be proven without love2d is the input decision above, never this
-- half -- src/menu.lua's own suite states the same line for its cell, and
-- the same reason applies: these two functions only call love.graphics and
-- Font.  The geometry constants below are still plain data and are pinned as
-- such.
--
-- Both boxes are sized for src/transforms.lua's own registry ceiling today --
-- MEGA, DYNAMAX, TERA, Z-MOVE, BURST, five entries -- with one row of
-- headroom apiece rather than trimmed to exactly five, so a sixth
-- registration overflows into visible truncation rather than a silently
-- unwritten row.
--
-- Classic: Font.drawBox(2, 10, 16, 8) -- interior rows 11..16 (six), the
-- cursor and label columns one and two tiles in from the left border, the
-- same offsets the FIGHT move list itself uses (BattleState.lua's own
-- moveSelect draw, box (4,12)-(20,18), cursor col 5, names col 6).  The box
-- spans down to the screen's own last row (17), so it fully covers the
-- vanilla command box (rows 12-17) it draws over, and starts two rows above
-- it rather than reusing the single spacer row the plain cell lives in --
-- there was never a free row spared for six.
local CLASSIC = {
  box = { x = 2, y = 10, w = 16, h = 8 },
  cursor = 24, label = 32, rowY0 = 88, rowStep = 8, maxRows = 6,
}

-- Wide: Font.drawBox(4, 8, 24, 10) -- interior rows 9..16 (eight, two more
-- than classic needs, kept for the same headroom reason).  Spans down to the
-- widescreen layout's own last command-box row (17,
-- WideBattle.lua's own (20,13)-(38,18)) so it fully covers that box too.
local WIDE = {
  box = { x = 4, y = 8, w = 24, h = 10 },
  cursor = 40, label = 48, rowY0 = 72, rowStep = 8, maxRows = 8,
}

M.BOX = { classic = CLASSIC, wide = WIDE }

-- The same hollow cursor every menu in this engine draws with, including the
-- plain cell's own -- src/menu.lua's header explains why a second, different
-- glyph would read as a second cursor instead.
local CURSOR_GLYPH = 0xED

local function drawList(battle, state, at, Font)
  local offered = deps.overlay.offered(state, battle)
  local index = battle._battleFormsListIndex or 1
  Font.drawBox(at.box.x, at.box.y, at.box.w, at.box.h)
  love.graphics.setColor(0, 0, 0, 1)
  local armedId = state:armed()
  for i, entry in ipairs(offered) do
    if i > at.maxRows then break end
    local y = at.rowY0 + (i - 1) * at.rowStep
    local text = (armedId == entry.id) and (entry.label .. "*") or entry.label
    Font.draw(text, at.label, y)
    if i == index then Font.drawCode(CURSOR_GLYPH, at.cursor, y) end
  end
end

function M.drawClassic(battle, state, Font)
  drawList(battle, state, CLASSIC, Font)
end

function M.drawWide(battle, state, Font)
  drawList(battle, state, WIDE, Font)
end

-- ---- Gen 2 drawing -----------------------------------------------------
--
-- src/gen2menu.lua's own list, drawn through Gold's Chrome module
-- (src/ui/gen2/Chrome.lua) rather than src/render/Font: Chrome.box and
-- Chrome.print already take TILE coordinates and delegate to that same Font
-- underneath (Chrome.lua:59-74), so this box is the CLASSIC one above
-- divided by 8 -- not a coincidence.  Gold's own non-contest command box
-- sits at the identical screen position Gen 1's classic one does
-- (game/src/ui/gen2/BattleState.lua's `Chrome.box(8, 12, 12, 6)` against
-- this file's own CLASSIC box comment on `Font.drawBox(8, 12, 12, 6)`), so
-- the list above it needs no geometry of its own: same six rows of
-- headroom, same two rows above the vanilla box, same right-edge budget --
-- pinned separately in tests/battle_forms_gen2menu_test.lua rather than
-- assumed to stay derived, the way src/menu.lua's own CELL constants are.
--
-- Contest battles are refused the cell entirely (src/gen2menu.lua's own
-- header says why), so there is no contest-box counterpart to WIDE here.
local GEN2 = {
  box = { x = 2, y = 10, w = 16, h = 8 },
  cursor = 3, label = 4, rowY0 = 11, rowStep = 1, maxRows = 6,
}
M.GEN2_BOX = GEN2

function M.drawGen2(battle, state, Chrome)
  local offered = deps.overlay.offered(state, battle)
  local index = battle._battleFormsListIndex or 1
  Chrome.box(GEN2.box.x, GEN2.box.y, GEN2.box.w, GEN2.box.h)
  local armedId = state:armed()
  for i, entry in ipairs(offered) do
    if i > GEN2.maxRows then break end
    local ty = GEN2.rowY0 + (i - 1) * GEN2.rowStep
    local text = (armedId == entry.id) and (entry.label .. "*") or entry.label
    Chrome.print(text, GEN2.label, ty)
    if i == index then Chrome.cursor(GEN2.cursor, ty) end
  end
end

return M
