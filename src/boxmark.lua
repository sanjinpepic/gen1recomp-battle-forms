-- The fusion partner boxed in the PC (src/fusion.lua's M.HELD) is an
-- ordinary Pokemon once it is there, and nothing on screen says otherwise --
-- a player can RELEASE it exactly as they would any other box mon, with no
-- way back for the fusion it silently ends.  This module marks it wherever
-- the engine draws a boxed Pokemon, so the warning is in front of the player
-- before they press A on RELEASE, not after.
--
-- WHY NOT A NICKNAME.  Stamping the boxed partner's nickname at fuse time
-- would show the same warning without a new draw seam at all, and it was
-- considered and rejected: it is a SAVE WRITE, and it collides with a
-- player's own nickname the moment they had one -- the write would then have
-- to remember and restore it on split, a second thing this mechanic could get
-- wrong for no mechanical gain.  A marker drawn at READ time writes nothing
-- and can never go stale against the field it reads; src/fusion.lua's own
-- M.HELD is still the only place any of this is recorded.
--
-- WHERE IT GOES, and why both.  BoxMenu's per-mon submenu (src/ui/
-- BoxMenu.lua's monSubmenu) reaches the STATS screen straight from either box
-- list, so a marker in the list a player leaves the instant they check STATS
-- would be in one place and not the very next -- worse than no marker at all.
--
--   The box lists: WITHDRAW and RELEASE.  DEPOSIT lists the PARTY, and a
--   fusion partner is never in it -- only the survivor is, and it carries
--   src/fusion.lua's OTHER stamp (M.STAMP), not this one.  Both marked lists
--   are already tagged with an opts.kind ListMenu.new carries for a reason of
--   its own ("pc_box_withdraw" / "pc_box_release"), and that tag doubles as
--   the seam this module needs: no BoxMenu internal has to be reached, only
--   the one generic list constructor every list in the game already funnels
--   through.  item.right is read generically by ListMenu:draw -- the same
--   field the shop's price and the box-change screen's slot count already
--   use -- and sits empty on both of these lists today, so setting it costs
--   neither list anything it was using.
--
--   The STATS screen (src/ui/SummaryMenu.lua), reached from either list's
--   submenu.  The party's own status screen never needs this: a fused BASE
--   carries M.STAMP, never M.HELD, so nothing here fires for a Pokemon a
--   player still has in hand.
--
-- WHY THE SAME TECHNIQUE AS src/menu.lua's engine wraps.  pcall the require,
-- refuse when the shape is not the one expected, guard against a second
-- install patching an already-patched class, and fall back to the vanilla
-- function on any error a wrapper itself raises.  A guard that refuses must
-- say so out loud -- if either seam is not there to wrap, nothing is built,
-- and the other half is UNDONE rather than left standing alone: a marker in
-- the box list with none on the STATS screen it opens into (or the reverse)
-- is the "one place and not the next" failure this module exists to avoid.
local M = {}

local deps = nil
function M.bind(modules) deps = modules end

-- The one glyph this marker ever draws -- plain ASCII, so both ListMenu's
-- item.right (a font string drawn right-aligned) and Font.draw (which takes
-- the same kind of string) render it with no charmap byte to look up and no
-- risk of a page that has never heard of it drawing a hole instead.
M.GLYPH = "F"

local function record(fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

local function isFusedPartner(mon)
  return type(mon) == "table" and deps ~= nil and deps.fusion ~= nil
    and mon[deps.fusion.HELD] ~= nil
end

-- ---- the box lists ------------------------------------------------------

-- The two box-list kinds BoxMenu.lua tags withdraw() and release() with.
-- DEPOSIT is deliberately absent: it lists the party, and a fusion partner is
-- never in it.
local BOX_LIST_KINDS = { pc_box_withdraw = true, pc_box_release = true }

local function markBoxItems(game, items, kind)
  if not BOX_LIST_KINDS[kind] then return end
  if type(items) ~= "table" or type(game) ~= "table" or not game.save then
    return
  end
  local Boxes = require("src.pokemon.Boxes")
  local box = Boxes.active(game.save)
  if type(box) ~= "table" then return end
  for _, item in ipairs(items) do
    local index = type(item) == "table" and item.value
    local mon = type(index) == "number" and box[index]
    if isFusedPartner(mon) then item.right = M.GLYPH end
  end
end

-- Returns ok, undo.  `undo` is always callable -- a no-op when there was
-- nothing to undo -- so a caller never has to branch on whether install
-- actually changed anything before deciding whether to unwind it.
local function installBoxList(mod)
  local okList, ListMenu = pcall(require, "src.ui.ListMenu")
  if not okList or type(ListMenu) ~= "table" then
    record("boxmark: require(src.ui.ListMenu) failed (%s)", tostring(ListMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.ListMenu is unavailable -- the "
        .. "boxed fusion partner marker is disabled in the PC list")
    end
    return false, function() end
  end
  if ListMenu._battleFormsBoxMarked then
    record("boxmark: ListMenu was already patched -- this load wrapped "
      .. "nothing and the wrapper in place belongs to an earlier load")
    return true, function() end
  end
  if type(ListMenu.new) ~= "function" then
    record("boxmark: ListMenu.new is not a function -- the marker is "
      .. "disabled in the PC list")
    if mod.log then
      mod.log:error("battle_forms: src.ui.ListMenu.new has changed shape -- "
        .. "the boxed fusion partner marker is disabled in the PC list")
    end
    return false, function() end
  end

  local vanillaNew = ListMenu.new
  ListMenu._battleFormsBoxMarked = true
  ListMenu.new = function(game, title, items, opts)
    local ok, err = pcall(markBoxItems, game, items, opts and opts.kind)
    if not ok then
      record("boxmark: marking the box list failed (%s)", tostring(err))
    end
    return vanillaNew(game, title, items, opts)
  end
  record("boxmark: install: wrapped ListMenu.new")
  return true, function()
    ListMenu.new = vanillaNew
    ListMenu._battleFormsBoxMarked = nil
  end
end

-- ---- the STATS screen ----------------------------------------------------

-- The free two-tile gap on the dex-number row, shared by both status pages
-- (SummaryMenu:draw prints "No." + the dex number before it branches on
-- self.page): the three-digit dex number ends at x=48 and drawLineBox's own
-- leftward run does not start until x=64 (status_screen.asm:143-146's own
-- layout, SummaryMenu.lua's drawLineBox(19, 1, 6, 10) call) -- untouched by
-- vanilla on either page.
local MARK_X, MARK_Y = 48, 56

local function installSummary(mod)
  local okSummary, SummaryMenu = pcall(require, "src.ui.SummaryMenu")
  if not okSummary or type(SummaryMenu) ~= "table" then
    record("boxmark: require(src.ui.SummaryMenu) failed (%s)",
      tostring(SummaryMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.SummaryMenu is unavailable -- the "
        .. "boxed fusion partner marker is disabled on the STATS screen")
    end
    return false, function() end
  end
  if SummaryMenu._battleFormsBoxMarked then
    record("boxmark: SummaryMenu was already patched -- this load wrapped "
      .. "nothing and the wrapper in place belongs to an earlier load")
    return true, function() end
  end
  if type(SummaryMenu.draw) ~= "function" then
    record("boxmark: SummaryMenu.draw is not a function -- the marker is "
      .. "disabled on the STATS screen")
    if mod.log then
      mod.log:error("battle_forms: src.ui.SummaryMenu.draw has changed "
        .. "shape -- the boxed fusion partner marker is disabled on the "
        .. "STATS screen")
    end
    return false, function() end
  end

  local okFont, Font = pcall(require, "src.render.Font")
  if not okFont then Font = nil end
  record("boxmark: install: Font %s", okFont and "resolved"
    or ("unavailable (" .. tostring(Font) .. ")"))

  local vanillaDraw = SummaryMenu.draw
  SummaryMenu._battleFormsBoxMarked = true
  SummaryMenu.draw = function(self)
    vanillaDraw(self)
    if not Font or not isFusedPartner(self and self.mon) then return end
    local ok, err = pcall(function()
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(M.GLYPH, MARK_X, MARK_Y)
      love.graphics.setColor(1, 1, 1, 1)
    end)
    if not ok then
      record("boxmark: SummaryMenu.draw marker failed (%s)", tostring(err))
    end
  end
  record("boxmark: install: wrapped SummaryMenu.draw")
  return true, function()
    SummaryMenu.draw = vanillaDraw
    SummaryMenu._battleFormsBoxMarked = nil
  end
end

-- ---- Gen 2: the PC panel and Gold's own STATS screen ---------------------
--
-- Gold's BoxMenu (game/src/ui/gen2/BoxMenu.lua) was recorded in HANDOFF.md
-- as "a self-drawn icon grid ... with no text slot", and reading the class
-- turns out to say otherwise on both counts: its withdraw/release list
-- draws plain nickname TEXT (Chrome.print at BoxMenu.lua:738, no per-row
-- icon anywhere in the file), and PCMonInfo's own left-hand info panel
-- (drawPanel, :704-800) carries a text slot too -- just not one every row
-- can safely share.
--
-- THE LIST ROWS ARE REFUSED, though, and for a reason worth keeping
-- explicit: PlaceNickname prints a Gen 2 nickname verbatim, up to the full
-- ten-tile width of the list box (LIST_X=9 through the box's own right
-- edge), with no separate field the way Gen 1's ListMenu gives item.right.
-- There is no column guaranteed empty for every row a ten-character
-- nickname might occupy, and truncating a boxed Pokemon's own name to make
-- room for this mod's marker would show the player a name they did not
-- give it -- worse than the marker this module exists to add.  So nothing
-- wraps the list draw on Gold; see M.installGen2's own refusal being a
-- deliberate no-op there, not a shortfall.
--
-- THE PANEL IS NOT REFUSED.  drawPanel prints the level as "<LV>" plus at
-- most three digits, starting at PIC_X=1 (four tiles, columns 1-4), and a
-- gender glyph at column 5 only when the mon actually has one -- so columns
-- 6 and 7 of PCMonInfo's own eight-tile-wide panel (:12) are empty for
-- every mon, gendered or not, level 1 or level 100.  The panel already
-- redraws for whichever mon the cursor currently sits on, and RELEASE is
-- one menu deeper than that (under "What's up?"), so marking it satisfies
-- the identical "in front of the player before they press A on RELEASE"
-- requirement the two Gen 1 seams above exist for -- continuously, as the
-- player scrolls, rather than needing a marker on every row at once.
--
-- THE STATS SCREEN is reached the way Gen 1's is: BoxMenu:openStats pushes
-- "Gen2SummaryMenu" (src/ui/gen2/SummaryMenu.lua, resolved through
-- game/src/ui/Screens.lua's own Gen2 prefix table) -- a different class
-- from src.ui.SummaryMenu, wrapped above.  Its own dex-number row
-- (upperPlacements, SummaryMenu.lua:407-428) leaves column 13 empty: the
-- three-digit dex number ends at column 12 and the level text does not
-- start until column 14, on every mon regardless of dex number or level.
-- upperPlacements builds a plain { text, x, y } list rather than drawing
-- directly -- that class's own header says why: "so the layout can be
-- asserted without a graphics device" -- so this wraps THAT method rather
-- than draw(), and the marker becomes one more entry in the exact list
-- SummaryMenu:drawPlacements already walks, provable with no love.graphics
-- stub at all.
local function gen2PanelMon(boxMenu)
  local ok, mon = pcall(boxMenu.panelMon, boxMenu)
  return ok and mon or nil
end

-- Pixel coordinates, matching MARK_X/MARK_Y's own convention above: PCMonInfo's
-- panel is 8 tiles wide (columns 0-7), the level/gender row is row 12, and
-- columns 6-7 are the free pair this module's own header measures.
local PANEL_MARK_X, PANEL_MARK_Y = 48, 96

local function installGen2BoxMenu(mod)
  local ok, BoxMenu = pcall(require, "src.ui.gen2.BoxMenu")
  if not ok or type(BoxMenu) ~= "table" then
    record("boxmark: require(src.ui.gen2.BoxMenu) failed (%s)", tostring(BoxMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BoxMenu is unavailable -- the "
        .. "boxed fusion partner marker is disabled on Gold's PC panel")
    end
    return false, function() end
  end
  if BoxMenu._battleFormsBoxMarked then
    record("boxmark: gen2 BoxMenu was already patched -- this load wrapped "
      .. "nothing and the wrapper in place belongs to an earlier load")
    return true, function() end
  end
  if type(BoxMenu.drawPanel) ~= "function" then
    record("boxmark: gen2 BoxMenu.drawPanel is not a function -- the marker "
      .. "is disabled on Gold's PC panel")
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BoxMenu.drawPanel has changed "
        .. "shape -- the boxed fusion partner marker is disabled on Gold's "
        .. "PC panel")
    end
    return false, function() end
  end

  local okFont, Font = pcall(require, "src.render.Font")
  if not okFont then Font = nil end

  local vanillaDrawPanel = BoxMenu.drawPanel
  BoxMenu._battleFormsBoxMarked = true
  BoxMenu.drawPanel = function(self)
    vanillaDrawPanel(self)
    if not Font or not isFusedPartner(gen2PanelMon(self)) then return end
    local ok2, err = pcall(function()
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(M.GLYPH, PANEL_MARK_X, PANEL_MARK_Y)
      love.graphics.setColor(1, 1, 1, 1)
    end)
    if not ok2 then
      record("boxmark: gen2 BoxMenu.drawPanel marker failed (%s)", tostring(err))
    end
  end
  record("boxmark: install: wrapped gen2 BoxMenu.drawPanel")
  return true, function()
    BoxMenu.drawPanel = vanillaDrawPanel
    BoxMenu._battleFormsBoxMarked = nil
  end
end

-- Tile coordinates, the shape upperPlacements' own { text, x, y } rows carry
-- (SummaryMenu:drawPlacements multiplies by 8 itself through Chrome.print).
local SUMMARY_MARK_X, SUMMARY_MARK_Y = 13, 0

local function installGen2Summary(mod)
  local ok, SummaryMenu = pcall(require, "src.ui.gen2.SummaryMenu")
  if not ok or type(SummaryMenu) ~= "table" then
    record("boxmark: require(src.ui.gen2.SummaryMenu) failed (%s)",
      tostring(SummaryMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.SummaryMenu is unavailable -- "
        .. "the boxed fusion partner marker is disabled on Gold's STATS "
        .. "screen")
    end
    return false, function() end
  end
  if SummaryMenu._battleFormsBoxMarked then
    record("boxmark: gen2 SummaryMenu was already patched -- this load "
      .. "wrapped nothing and the wrapper in place belongs to an earlier load")
    return true, function() end
  end
  if type(SummaryMenu.upperPlacements) ~= "function" then
    record("boxmark: gen2 SummaryMenu.upperPlacements is not a function -- "
      .. "the marker is disabled on Gold's STATS screen")
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.SummaryMenu.upperPlacements "
        .. "has changed shape -- the boxed fusion partner marker is "
        .. "disabled on Gold's STATS screen")
    end
    return false, function() end
  end

  local vanillaUpper = SummaryMenu.upperPlacements
  SummaryMenu._battleFormsBoxMarked = true
  SummaryMenu.upperPlacements = function(self)
    local out = vanillaUpper(self)
    if type(out) == "table" and isFusedPartner(self and self.mon) then
      out[#out + 1] = { text = M.GLYPH, x = SUMMARY_MARK_X, y = SUMMARY_MARK_Y }
    end
    return out
  end
  record("boxmark: install: wrapped gen2 SummaryMenu.upperPlacements")
  return true, function()
    SummaryMenu.upperPlacements = vanillaUpper
    SummaryMenu._battleFormsBoxMarked = nil
  end
end

-- Both Gen 2 seams or neither, for the identical reason M.install keeps its
-- own two Gen 1 halves atomic: a marker in the PC panel with none on the
-- STATS screen it opens into (or the reverse) is worse than no marker.
function M.installGen2(mod)
  local panelOk, undoPanel = installGen2BoxMenu(mod)
  if not panelOk then return false end

  local summaryOk = installGen2Summary(mod)
  if not summaryOk then
    undoPanel()
    if mod.log then
      mod.log:error("battle_forms: the STATS screen half of Gold's boxed "
        .. "fusion partner marker could not be built, so the PC panel half "
        .. "that DID wrap has been reverted too -- a marker in one place "
        .. "and not the other would be worse than none")
    end
    return false
  end
  return true
end

-- Both seams or neither.  A marker that stood in the box list with no
-- matching one on the STATS screen it opens into (or the other way round)
-- is worse than no marker, so a failure on either half undoes the other
-- rather than leaving a half-built marker in place.
function M.install(mod)
  local listOk, undoList = installBoxList(mod)
  if not listOk then return false end

  local summaryOk = installSummary(mod)
  if not summaryOk then
    undoList()
    if mod.log then
      mod.log:error("battle_forms: the STATS screen half of the boxed "
        .. "fusion partner marker could not be built, so the PC list half "
        .. "that DID wrap has been reverted too -- a marker in one place "
        .. "and not the other would be worse than none")
    end
    return false
  end
  return true
end

return M
