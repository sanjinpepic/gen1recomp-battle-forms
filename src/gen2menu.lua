-- Gen 2's equivalent of src/menu.lua: the fifth command-menu entry on Gold's
-- own battle screen (game/src/ui/gen2/BattleState.lua), which is a DIFFERENT
-- class from Gen 1's -- see src/battlerof.lua's own header on why nothing
-- here can assume Gen 1's battler wrapper or its single unified
-- battle/UI object.
--
-- WHAT GOLD'S MENU PHASE ACTUALLY IS, confirmed against the real class
-- rather than assumed from Gen 1's shape.  `BattleState:update`'s own
-- `if self.phase == "menu" then` body (BattleState.lua:1956-1971) is a fixed
-- 2x2 grid, not a loop over `menuLabels()` the way the DRAW side is --
-- left/right swap the column, up/down swap the row by exactly two, and A
-- dispatches `MENU_ACTION[MENU[self.menuIndex]]`.  `menuLabels()`
-- (BattleState.lua:3334) only decides what the DRAW side prints; the INPUT
-- side is hard-coded to four cells whatever it returns.  So this module owns
-- its own two-column check the same shape src/menu.lua's `column()` already
-- is, rather than reading anything off `menuLabels()`.
--
-- THE GEOMETRY MATCHES GEN 1'S CLASSIC LAYOUT EXACTLY, tile for tile.  The
-- non-contest command box is `Chrome.box(8, 12, 12, 6)` (MENU_BOX_X = 8,
-- BattleState.lua:130,3374-3377) -- the identical screen position Gen 1's
-- own classic box occupies (src/menu.lua's own header: `Font.drawBox(8, 12,
-- 12, 6)`).  FIGHT/<PK><MN> print on row 14, PACK/RUN on row 16
-- (BattleState.lua:3378-3384: `ty = 14 + row`, `row = floor((i-1)/2)*2`),
-- with row 15 left blank between them -- vanilla's own spacer, unused for
-- the identical reason src/menu.lua's own header gives for Gen 1's row 15.
-- The cell lives there, in FIGHT's own column (tx = boxX + 2 = 10, cursor
-- one tile left at 9), for the same reason src/menu.lua reuses FIGHT/ITEM's
-- column instead of inventing one.
--
-- CONTEST BATTLES ARE REFUSED OUTRIGHT.  BATTLETYPE_CONTEST
-- (`self.contest`, BugContest) swaps the menu box for a narrower one at
-- CONTEST_MENU_BOX_X = 2 with PARKBALL×NN standing in the PACK slot
-- (BattleState.lua:133-139, 3336-3338) and drives a wholly different
-- objective -- catching one Pokemon and holding it, not the "beat the
-- trainer" loop these mechanics are all built around.  There is no
-- transformation here a Bug-Catching Contest run has any use for, so the
-- cell simply never offers itself while `self.contest` is set, the same
-- silent-absence shape an ineligible species already gets.  BATTLETYPE_TUTORIAL
-- (`self.tutorial`, the DUDE's scripted demonstration battle) is refused for
-- an even plainer reason: no mon is sent out for the player's own side
-- (BattleState.lua:226-230), so `battle.player` -- the mon `available()`
-- reads -- would not exist to ask.
--
-- Ownership of the whole frame while the cursor sits on the cell is the
-- identical reasoning src/menu.lua's own header gives: Input:wasPressed does
-- not consume a press, so vanilla's own `chooseMenu` dispatch must not run
-- on a frame this module claims, and the only clean way to guarantee that
-- without a consume() this engine has never had is to own the whole frame.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The column the cursor sits in: MENU = { FIGHT, <PK><MN>, PACK, RUN } fills
-- row-major (BattleState.lua:127), so odd indices (1 = FIGHT, 3 = PACK) are
-- column 0, the same "reachable from the left edge" column src/menu.lua's
-- own `column()` picks out for Gen 1's FIGHT/ITEM.
local function column(uiBattle)
  return (uiBattle.menuIndex - 1) % 2
end

-- src/menu.lua's own safeToOffer, adapted to what is actually reachable from
-- here: `uiBattle` is the UI BattleState (this module's own `self`), and the
-- mon the cell asks about lives on `uiBattle.battle.player` -- the ENGINE
-- object (src/battlerof.lua's own header) -- not on the UI class itself.
-- There is no Gen 2 equivalent of Gen 1's menuLockedAction/drainHold checks
-- to carry over: BattleState.lua's own `locked-in`/`forced-switch` phases
-- (:1945, :1413, :2081, ...) are DIFFERENT phase values from `"menu"`, so a
-- locked or forced-replacement frame never reaches this module in the first
-- place -- confirmed by reading every `self.phase = "menu"` assignment in
-- the class (BattleState.lua:1221, 1786, 1951, 2302), none of which happen
-- on either of those paths.
local function safeToOffer(uiBattle)
  if uiBattle.contest or uiBattle.tutorial then return false end
  local battle = uiBattle.battle
  local mon = battle and battle.player
  if not mon or (mon.hp or 0) <= 0 then return false end
  return true
end

function M.isOnCell(battle)
  return battle ~= nil and battle._battleFormsMenuCell == true
end

-- Same return shape src/menu.lua's own handleInput uses: (handled, action).
-- `battle` here is always the UI BattleState -- src/gen2menu.lua's own
-- `self` on the wrapped `update` -- which src/overlay.lua's `offered`/
-- `shouldOffer`/`label` calls below thread through as `uiBattle` so the
-- phase/queue gate reads the right table (that function's own header says
-- why); `state:current()` inside them still resolves the ENGINE battle
-- src/mega.lua's `available`/`activate` already expect.
function M.handleInput(battle, state)
  if not battle or battle.phase ~= "menu" then return false end
  if not deps or not deps.overlay.shouldOffer(state, battle)
      or not safeToOffer(battle) then
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
    -- A opens the submenu rather than arming directly, for the identical
    -- reason src/formmenu.lua's own header gives on Gen 1's side of this.
    if input:wasPressed("a") then
      deps.formmenu.open(battle, state)
      return true, "open"
    end
    -- RIGHT/UP/DOWN leave the cell exactly as they do on Gen 1; LEFT
    -- (already leftmost) or nothing pressed stays put.
    if input:wasPressed("right") or input:wasPressed("up")
        or input:wasPressed("down") then
      battle._battleFormsMenuCell = false
      return true
    end
    return true
  end

  if column(battle) == 0 and input:wasPressed("left") then
    battle._battleFormsMenuCell = true
    return true
  end
  return false
end

-- src/menu.lua's own HIDE_INDEX trick: `menuLabels()` only ever returns four
-- entries, so aliasing `menuIndex` to a fifth makes vanilla's own
-- `if i == self.menuIndex then Chrome.cursor(...)` (BattleState.lua:3382)
-- match nothing for one draw, which is what stands in for a "no cursor"
-- mode the class does not otherwise have.
local HIDE_INDEX = 5

local function withHiddenCursor(battle, onCell, fn)
  local saved = battle.menuIndex
  if onCell then battle.menuIndex = HIDE_INDEX end
  local ok, err = pcall(fn)
  battle.menuIndex = saved
  if not ok then error(err, 0) end
end

-- Tile coordinates -- Chrome.print/Chrome.cursor both take them directly
-- (Chrome.lua:71-74, 180-183) -- not pixels the way src/menu.lua's own CELL
-- speaks, because src/render/Font (what Chrome delegates to) is the one
-- being called either way.  `cursor`/`label` are FIGHT's own column
-- (boxX + 2 = 10, one tile left of that for the cursor) and `row` is the
-- blank spacer row 15 -- this file's own header has the full derivation.
local CELL = { cursor = 9, label = 10, row = 15 }
M.CELL = CELL

local function drawCell(battle, Chrome, state, onCell)
  local label = deps.overlay.label(state, battle)
  if label then Chrome.print(label, CELL.label, CELL.row) end
  if onCell then Chrome.cursor(CELL.cursor, CELL.row) end
end

local function note(battle, what)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, "gen2menu: %s ran", what) end
end

-- Runs after the vanilla `drawPanel`, on top of it -- compose, never
-- capture, src/menu.lua's own rule.  The submenu box fully covers the
-- vanilla command box it draws over (src/formmenu.lua's own GEN2 geometry
-- header), so nothing of FIGHT/<PK><MN>/PACK/RUN survives visible beneath
-- it while the list is open.
function M.draw(battle, state, vanillaDraw, Chrome)
  note(battle, "BattleState.drawPanel")
  if not deps or not deps.overlay.shouldOffer(state, battle) then
    return vanillaDraw(battle)
  end
  local onCell = M.isOnCell(battle)
  withHiddenCursor(battle, onCell, function() vanillaDraw(battle) end)
  if not Chrome then return end
  if onCell and deps.formmenu.isOpen(battle) then
    deps.formmenu.drawGen2(battle, state, Chrome)
  else
    drawCell(battle, Chrome, state, onCell)
  end
end

-- BattleState._battleFormsGen2MenuPatched is this class's own idempotency
-- flag -- a DIFFERENT flag from Gen 1's `_battleFormsMenuPatched` on a
-- DIFFERENT class, but the same guard every other engine_internals patch in
-- this mod keeps (src/menu.lua, src/gen2forms.lua, src/gen2formview.lua,
-- src/gen2shop.lua): a second install finds it already set and wraps
-- nothing, so a third-party mod's own wrap over the same methods -- before
-- or after this one -- still runs.
function M.install(mod, state)
  local diag = deps and deps.diag
  local function record(fmt, ...)
    if diag then diag.record(fmt, ...) end
  end

  local okState, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not okState or type(BattleState) ~= "table" then
    record("gen2menu: install: require(src.ui.gen2.BattleState) failed (%s)",
      tostring(BattleState))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BattleState is unavailable -- "
        .. "the Gold transformation menu cell is disabled")
    end
    return false
  end
  if BattleState._battleFormsGen2MenuPatched then
    record("gen2menu: install: BattleState was already patched -- this load "
      .. "wrapped nothing and the wrappers in place close over an earlier "
      .. "load's arm state")
    return true
  end
  record("gen2menu: install: BattleState resolved, no earlier patch")
  BattleState._battleFormsGen2MenuPatched = true

  local okChrome, Chrome = pcall(require, "src.ui.gen2.Chrome")
  record("gen2menu: install: Chrome %s", okChrome and "resolved"
    or ("unavailable (" .. tostring(Chrome) .. ")"))
  if not okChrome then Chrome = nil end

  local vanillaUpdate = BattleState.update
  BattleState.update = function(self, dt)
    if diag then pcall(diag.record, "gen2menu: BattleState.update ran") end
    local ok, handled, action = pcall(M.handleInput, self, state)
    if ok and handled then
      -- "open", "toggle" and "cancel" are every action string this module
      -- or src/formmenu.lua ever returns -- the identical confirm-shaped
      -- moment src/menu.lua's own Press_AB sound marks on Gen 1.  `playSfx`
      -- is a real method on the live instance (BattleState.lua:1570-1576,
      -- the exact call vanilla's own A-on-menu arm makes) rather than a
      -- second require of src/core/Sound, so this never has to guess at
      -- the shape `self.game.data` needs to be in.
      if action then pcall(self.playSfx, self, "Sfx_ReadText2") end
      return
    end
    return vanillaUpdate(self, dt)
  end

  local vanillaDrawPanel = BattleState.drawPanel
  BattleState.drawPanel = function(self)
    local ok = pcall(M.draw, self, state, vanillaDrawPanel, Chrome)
    if not ok then pcall(vanillaDrawPanel, self) end
  end

  record("gen2menu: install: wrapped BattleState.update and "
    .. "BattleState.drawPanel")
  return true
end

return M
