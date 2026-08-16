-- Gen 2's equivalent of src/formview.lua: draws a persistent (or fused)
-- form's real types and stats over Gold's own SUMMARY screen, the same
-- draw-after-vanilla overlay Gen 1's module uses and for the identical
-- reason -- mon.species is never re-keyed (src/forms.lua's own header, and
-- src/gen2forms.lua's), so data.pokemon[mon.species] is still the BASE
-- species everywhere Gold's own src/ui/gen2/SummaryMenu.lua reads it.
--
-- WHY THIS IS AN OVERLAY AND NOT A READ OF mon.stats.  Gold's blue page
-- prints mon.stats directly (SummaryMenu.lua:532), and src/gen2forms.lua's
-- becomeForm mutates that exact table in place while a form is active in
-- battle -- so during a fight the vanilla draw is already right.  This
-- module exists for every OTHER moment a player opens this screen: a level-
-- up recomputes mon.stats from the BASE species alone (Gold's own growth
-- curve is keyed on mon.species, with no idea a form marker is sitting on
-- the mon), so a Pokemon sitting in the party menu between battles can show
-- stale, un-boosted numbers for a form it is still genuinely wearing, until
-- its next battle reapplies gen2forms.becomeForm and corrects mon.stats
-- again.  Recomputing fresh from data.pokemon[formId] on every draw --
-- exactly what Gen 1's formview.lua already does, for the same reason --
-- sidesteps that staleness rather than chasing every place mon.stats could
-- drift: what this module draws never depends on what mon.stats currently
-- holds.
--
-- TYPES have the same story from a different angle.  Gold's own typeNames()
-- checks mon.types before data.pokemon[mon.species].types
-- (SummaryMenu.lua:391), a field nothing in the engine ever writes -- so it
-- is not a seam this mod can rely on Gold to have populated on its own, and
-- this module does not populate it either (mon.formTypes, the field
-- src/gen2forms.lua's speciesDef wrap reads, is a different field with a
-- different consumer).  It draws over the vanilla TYPE box instead, exactly
-- where Gen 1's module does.
--
-- WHICH MONS THIS EVER FIRES FOR, and in what order two claims are asked --
-- both identical to src/formview.lua's own header, because both modules
-- exist to answer the same question about the same two mechanics
-- (src/persistent.lua, src/fusion.lua) for a screen the other generation
-- happens to draw differently.
local Mon = require("src.battle.gen2.Mon")

local M = {}

local deps = nil
function M.bind(modules) deps = modules end

-- Resolved lazily, at install time, the way src/formview.lua resolves
-- src/render/Font: a draw-only dependency this module treats as a courtesy
-- rather than a hard requirement, so a host that cannot supply it draws the
-- vanilla screen and nothing more rather than failing to load at all.
local Chrome = nil
-- Pulled off the real class at install time rather than hard-coded, so a
-- page renumbering or a TYPE_NAMES addition on the engine side is picked up
-- automatically instead of silently drifting from what this module assumes.
local BluePage, GreenPage, TypeNames = 3, 2, {}

local function record(fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

-- src/resolve.lua's own settle() asks fusion first, then persistent -- see
-- src/formview.lua's identical header for why the order can never actually
-- decide an outcome (no species is both a fusion base and a persistent-form
-- holder) and why matching it here is still the right default to inherit
-- rather than pick arbitrarily.
--
-- Does NOT gate on mon.form the way src/formview.lua's identical Gen 1
-- helper safely does.  On Gen 1 that gate is free: mon.form is set the
-- instant a stamp changes (src/persistent.lua's M.mark runs inside the same
-- bag-use closure that writes the stamp), so a nil mon.form really does mean
-- neither mechanic can have anything to say.  On Gen 2, src/persistent.lua's
-- M.formIdFor also reads mon.item -- the real held-item slot
-- src/ui/gen2/HeldItemMenu.lua's GIVE writes directly, with no event this
-- mod can hook -- so a mon can reach this SUMMARY screen freshly given an
-- item, entitled to a form, with mon.form still nil because nothing has
-- applied it yet (no battle has started since the GIVE).  Gating on mon.form
-- here would draw nothing for exactly that mon, which is the bug report this
-- module exists to fix.  Asking fusion/persistent fresh on every draw is
-- already this module's own design (see the header above on stats/types
-- staleness); the one thing removed is the pre-filter that assumed the
-- answer could only ever be "no" when mon.form was empty.
local function formIdFor(mon)
  if not mon then return nil end
  local id = deps and deps.fusion and deps.fusion.formIdFor(mon)
  if id then return id end
  return deps and deps.persistent and deps.persistent.formIdFor(mon)
end

-- Refuses rather than half-applying, for src/forms.lua's own reason: a form
-- record with no `types` or no `baseStats` would draw nothing meaningful.
-- Quiet rather than logged, matching src/formview.lua's own choice --
-- src/persistent.lua and src/fusion.lua's own settle() already warn out loud
-- on the one case that can leave mon.form pointing at a record like this.
function M.resolve(data, mon)
  local formId = formIdFor(mon)
  if not formId then return nil end
  local formDef = data and data.pokemon and data.pokemon[formId]
  if type(formDef) ~= "table" or type(formDef.types) ~= "table"
      or formDef.types[1] == nil or type(formDef.baseStats) ~= "table" then
    return nil
  end
  return {
    types = formDef.types,
    stats = Mon.stats(formDef.baseStats, mon.dvs, mon.level, mon.statExp),
  }
end

-- ---- the SUMMARY screen ---------------------------------------------------

-- Tile coordinates, not pixels -- Chrome.print and the rectangle blank below
-- both take (or are converted to) the same hlcoord grid every placement list
-- in SummaryMenu.lua is built from.
--
-- PrintMonTypes writes type 1 at (1,15) and type 2 at (1,16)
-- (SummaryMenu.lua:461-463); the widest type names (FIGHTING, ELECTRIC) are
-- eight characters, so an eight-tile field from column 1 clears exactly up to
-- column 9 -- the pink page's own vertical divider (drawVerticalDivider(9))
-- -- without ever touching it.
local TYPE_TX, TYPE_TW = 1, 8
local TYPE1_TY, TYPE2_TY = 15, 16

-- PrintTempMonStats prints each value three columns wide at column 17
-- (SummaryMenu.lua:530-533), two rows apart starting at row 9: attack,
-- defense, specialAttack, specialDefense, speed -- the blue page's own
-- STAT_KEYS order, which this list matches on purpose rather than
-- src/gen2forms.lua's STAT_KEYS (ordered attack/defense/speed/special*
-- there, to mirror Battle:transform's own copy loop) so a row index here
-- always lands on the row the vanilla draw used it for.
local STAT_TX, STAT_TW = 17, 3
local STAT_KEYS = { "attack", "defense", "specialAttack", "specialDefense", "speed" }

-- Blanks a tile-aligned field and, when text is given, reprints it -- the
-- same two-step src/formview.lua's own `paint` does, so a shorter form name
-- can never leave a trailing letter of whatever the vanilla draw put there.
local function paint(tx, ty, tw, th, text)
  local G = love.graphics
  G.setColor(1, 1, 1, 1)
  G.rectangle("fill", tx * 8, ty * 8, tw * 8, (th or 1) * 8)
  if text then Chrome.print(text, tx, ty) end
  G.setColor(1, 1, 1, 1)
end

local function typeName(id)
  if not id then return nil end
  return TypeNames[id] or id
end

-- Runs after the vanilla draw. Skips the move-detail view and an egg mon the
-- same way the vanilla class itself does (SummaryMenu:placements' own
-- dispatch) -- neither ever shows a type or a stat, so there is nothing here
-- to correct on either. Every value comes from M.resolve, so an unformed
-- Pokemon -- or a form this module cannot resolve -- leaves the vanilla draw
-- exactly as it drew it, and nothing here ever writes to the mon.
function M.drawSummary(self)
  local mon = self and self.mon
  if not mon or self.moveDetail or mon.isEgg or not Chrome then return end
  local form = M.resolve(self.game and self.game.data, mon)
  if not form then return end

  if self.page == BluePage then
    for i, key in ipairs(STAT_KEYS) do
      local value = form.stats[key]
      if value then
        paint(STAT_TX, 9 + (i - 1) * 2, STAT_TW, 1, Chrome.number(value, 3))
      end
    end
  elseif self.page ~= GreenPage then
    paint(TYPE_TX, TYPE1_TY, TYPE_TW, 1, typeName(form.types[1]))
    paint(TYPE_TX, TYPE2_TY, TYPE_TW, 1, typeName(form.types[2]))
  end
end

-- pcall the requires, refuse when a shape is not the one expected, guard
-- against a second install patching an already-patched class -- the same
-- discipline src/formview.lua and src/gen2forms.lua both keep. A guard that
-- refuses must say so out loud (project rule #6).
--
-- Wraps drawPanel, not draw -- confirmed against a real, live Gold boot
-- rather than assumed from the class's own shape.  SummaryMenu:draw() is
-- defined as nothing but `self:drawPanel()` (SummaryMenu.lua:1121-1123), and
-- a fixture harness calling SummaryMenu.draw(fakeSelf) directly cannot tell
-- the two apart -- but the real render path never calls :draw() at all: a
-- driver that counted live calls through a full START -> POKeMON -> STATS
-- navigation saw drawPanel invoked on every frame and draw not once, the
-- same way every other Gen 2 screen in this engine (MartMenu, PartyMenu,
-- BoxMenu, ...) is driven through its own drawPanel by whatever owns the
-- frame, with draw (where a class bothers to define one at all) left an
-- unused alias.  Wrapping draw wraps a method the engine never calls, so the
-- earlier version of this file installed cleanly, passed every fixture
-- check, and never painted a single pixel in a real game.
function M.install(mod)
  local okSummary, SummaryMenu = pcall(require, "src.ui.gen2.SummaryMenu")
  if not okSummary or type(SummaryMenu) ~= "table" then
    record("gen2formview: require(src.ui.gen2.SummaryMenu) failed (%s)",
      tostring(SummaryMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.SummaryMenu is unavailable -- "
        .. "a Gen 2 formed Pokemon's types and stats will not show on the "
        .. "SUMMARY screen")
    end
    return false
  end
  if SummaryMenu._battleFormsGen2FormView then
    record("gen2formview: SummaryMenu was already patched -- this load "
      .. "wrapped nothing and the wrapper in place belongs to an earlier load")
    return true
  end
  if type(SummaryMenu.drawPanel) ~= "function" then
    record("gen2formview: SummaryMenu.drawPanel is not a function -- the "
      .. "SUMMARY screen overlay is disabled")
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.SummaryMenu.drawPanel has "
        .. "changed shape -- a Gen 2 formed Pokemon's types and stats will "
        .. "not show on the SUMMARY screen")
    end
    return false
  end

  local okChrome, ChromeMod = pcall(require, "src.ui.gen2.Chrome")
  Chrome = okChrome and ChromeMod or nil
  record("gen2formview: install: Chrome %s", okChrome and "resolved"
    or ("unavailable (" .. tostring(ChromeMod) .. ")"))

  BluePage = SummaryMenu.BLUE_PAGE or BluePage
  GreenPage = SummaryMenu.GREEN_PAGE or GreenPage
  TypeNames = SummaryMenu.TYPE_NAMES or {}

  local vanillaDraw = SummaryMenu.drawPanel
  SummaryMenu._battleFormsGen2FormView = true
  SummaryMenu.drawPanel = function(self)
    vanillaDraw(self)
    local ok, err = pcall(M.drawSummary, self)
    if not ok then
      record("gen2formview: SummaryMenu.drawPanel overlay failed (%s)", tostring(err))
    end
  end
  record("gen2formview: install: wrapped SummaryMenu.drawPanel")
  return true
end

return M
