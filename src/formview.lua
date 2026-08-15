-- The party and summary screens read data.pokemon[mon.species] for a
-- Pokemon's displayed types and stats, and src/forms.lua's own header is
-- explicit about why mon.species is never re-keyed by a form change: the
-- sprite mod resolves art under the BASE species' own entry, and a re-key
-- would also make a form change unsafe to leave mid-battle.  That is
-- correct and unhelpful at once -- an Arceus holding a Flame Plate already
-- has FIRE typing and a Fire-boosted stat block on the battler
-- (src/forms.lua's becomeForm sets curTypes/curStats from the form record),
-- but the party menu and the STATS screen read the mon straight off
-- data.pokemon[mon.species] and show NORMAL and the base block regardless.
--
-- This module closes that gap the same way src/hpscale.lua's battle.overlay
-- seam and src/boxmark.lua's SummaryMenu.draw wrap both do: it draws the
-- form's numbers over the vanilla ones AFTER the real draw has already run,
-- and writes nothing to the mon at all.  Nothing here is cached onto the
-- mon either -- every value is recomputed from data.pokemon[formId] on
-- every draw, through the exact same two calls src/forms.lua's becomeForm
-- makes (Stats.calc, formDef.types) -- so a level-up between visits to this
-- screen, or a data reload, can never leave a stale number on screen the
-- way caching one onto the mon could.
--
-- WHICH SCREENS.  Only the STATS screen (src/ui/SummaryMenu.lua) ever draws
-- a Pokemon's types or its ATTACK/DEFENSE/SPEED/SPECIAL numbers -- the
-- party list (src/ui/PartyMenu.lua) draws a nickname, a level and an HP bar
-- and nothing else, so there is no second seam to wrap for it.  Page 1 is
-- the only page with either block; page 2 is EXP and moves, untouched.
-- Reached from the party menu's STATS entry or from either PC box list's
-- STATS entry alike (src/boxmark.lua's own header covers that second path),
-- because both push the very same class -- one wrap covers everywhere a
-- player can see this Pokemon's numbers.
--
-- WHICH MONS THIS EVER FIRES FOR.  Only two mechanics leave mon.form set
-- once a battle is over -- src/persistent.lua (Plates, Memories, Drives,
-- the six Origin Formes and appliances) and src/fusion.lua -- because
-- src/resolve.lua's battle-end sweep asks exactly those two "is this mon's
-- form yours?" and blunt-clears every other mechanic's mark for everyone
-- else (src/resolve.lua's own `settle`).  This module asks the identical
-- two questions in the identical order for the identical reason: whichever
-- of the two claims the mon is the one whose pairing table names the form
-- id, and nothing else could still be standing on mon.form by the time a
-- screen draws it.  A mega, a primal Groudon, a Gigantamax or a
-- conditional form never reaches here, because the sweep already stripped
-- their marker before the player could look.
--
-- HP IS NEVER TOUCHED, on purpose, twice over: mon.stats.hp is not part of
-- the stats box this screen draws (it lives in the HP bar, a separate seam
-- this module does not reach at all), and even if it did, a form keeps the
-- base form's HP in the real games -- src/forms.lua's becomeForm already
-- leaves it alone for the same reason.  The name is not touched either: it
-- is read off the unchanged species record, which is exactly right for
-- free, the same way src/forms.lua's own header explains it is in battle.
local Stats = require("src.pokemon.Stats")
local TypeChart = require("src.battle.TypeChart")
local Strings = require("src.core.Strings")

local M = {}

local deps = nil
function M.bind(modules) deps = modules end

-- Resolved lazily, at install time, the way src/boxmark.lua resolves
-- src/render/Font: a draw-only dependency this module treats as a courtesy
-- rather than a hard requirement, so a host that cannot supply it draws the
-- vanilla screen and nothing more rather than failing to load at all.
local Font = nil

local function record(fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

-- src/resolve.lua's own settle() asks fusion first, then persistent, for the
-- reason its header gives: no species is both a fusion base and a
-- persistent-form holder, so the order can never decide an outcome by
-- itself -- asking the stronger claim (a fusion, which stands a second
-- Pokemon in the PC) first is the order to be wrong in if that ever stops
-- being true.  Matching that order here, rather than picking either
-- arbitrarily, is what keeps this module's answer from ever disagreeing
-- with what the save itself would say the mon is.
local function formIdFor(mon)
  if not mon or not mon.form then return nil end
  local id = deps and deps.fusion and deps.fusion.formIdFor(mon)
  if id then return id end
  return deps and deps.persistent and deps.persistent.formIdFor(mon)
end

-- Refuses rather than half-applying, for src/forms.lua's own reason: a form
-- record with no `types` or no `baseStats` would draw nothing meaningful,
-- and there would be no way to tell that refusal from a form with a
-- genuinely empty type list. Quiet rather than logged -- src/persistent.lua
-- and src/fusion.lua's own settle() already warn out loud on the one case
-- that can leave mon.form pointing at a record like this (a data reload
-- between a save and this draw), and repeating that warning on every frame
-- the screen stays open would drown it out rather than explain it.
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
    stats = Stats.calc(formDef, mon.level, mon.dvs or {}, mon.statExp),
  }
end

-- ---- the STATS screen ----------------------------------------------------

-- Coordinates SummaryMenu.lua's own draw already reserves for these six
-- numbers (its page-1 branch): the stats box's four values sit at x=48, one
-- tile shy of the box's right edge at x=80 -- 32px is exactly four
-- characters, a margin vanilla's own "%3d" print never crosses either.  The
-- type box's values sit at x=88, and TypeChart.displayName's longest name
-- (FIGHTING, ELECTRIC: 8 characters) already reaches that box's edge at
-- x=152 in vanilla's own draw, so 64px is the same ceiling, not a new one.
local STAT_ROWS = {
  { key = "attack", y = 80 }, { key = "defense", y = 96 },
  { key = "speed", y = 112 }, { key = "special", y = 128 },
}
local STAT_X, STAT_W = 48, 32
local TYPE_VALUE_X, TYPE_VALUE_W = 88, 64
local TYPE1_Y = 80
local TYPE2_LABEL_X, TYPE2_LABEL_Y, TYPE2_LABEL_W = 80, 88, 48
local TYPE2_VALUE_Y = 96
-- Both rows in one rect, for the case a form drops back to a single type
-- where the base SummaryMenu's own vanilla draw already gave it two: this
-- blanks the label AND the value without needing to know what the base
-- species itself had, because it is wide and tall enough to cover either
-- vanilla layout (one type or two) and short enough to stop before the
-- ID/OT block underneath, which never moves.
local TYPE2_ERASE = { x = 80, y = 88, w = 72, h = 16 }

local function paint(x, y, w, h, text)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", x, y, w, h)
  if text then
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, x, y)
  end
end

-- Runs after the vanilla draw, page 1 only -- page 2 is EXP and the move
-- list, nothing this module ever changes.  Every value comes from
-- M.resolve, so a mon with no active form (or one this module cannot
-- resolve) leaves the vanilla draw exactly as it drew it: nothing here
-- fires at all for an unremarkable Pokemon, and nothing here ever writes to
-- the mon in either case.
function M.drawSummary(self)
  local mon = self and self.mon
  if not mon or self.page ~= 1 or not Font then return end
  local game = self.game
  local form = M.resolve(game and game.data, mon)
  if not form then return end

  for _, row in ipairs(STAT_ROWS) do
    local v = form.stats[row.key]
    if v then paint(STAT_X, row.y, STAT_W, 8, ("%3d"):format(v)) end
  end
  paint(TYPE_VALUE_X, TYPE1_Y, TYPE_VALUE_W, 8,
        TypeChart.displayName(form.types[1]))
  if form.types[2] then
    paint(TYPE2_LABEL_X, TYPE2_LABEL_Y, TYPE2_LABEL_W, 8, Strings("TYPE2/"))
    paint(TYPE_VALUE_X, TYPE2_VALUE_Y, TYPE_VALUE_W, 8,
          TypeChart.displayName(form.types[2]))
  else
    paint(TYPE2_ERASE.x, TYPE2_ERASE.y, TYPE2_ERASE.w, TYPE2_ERASE.h, nil)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- pcall the require, refuse when the shape is not the one expected, guard
-- against a second install patching an already-patched class -- the same
-- discipline src/boxmark.lua and src/menu.lua's own engine wraps keep. A
-- guard that refuses must say so out loud (project rule #6), so both
-- refusals below reach mod.log as well as the trace.
function M.install(mod)
  local okSummary, SummaryMenu = pcall(require, "src.ui.SummaryMenu")
  if not okSummary or type(SummaryMenu) ~= "table" then
    record("formview: require(src.ui.SummaryMenu) failed (%s)",
      tostring(SummaryMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.SummaryMenu is unavailable -- a "
        .. "formed Pokemon's types and stats will not show on the STATS "
        .. "screen")
    end
    return false
  end
  if SummaryMenu._battleFormsFormView then
    record("formview: SummaryMenu was already patched -- this load wrapped "
      .. "nothing and the wrapper in place belongs to an earlier load")
    return true
  end
  if type(SummaryMenu.draw) ~= "function" then
    record("formview: SummaryMenu.draw is not a function -- the STATS "
      .. "screen overlay is disabled")
    if mod.log then
      mod.log:error("battle_forms: src.ui.SummaryMenu.draw has changed "
        .. "shape -- a formed Pokemon's types and stats will not show on "
        .. "the STATS screen")
    end
    return false
  end

  local okFont, F = pcall(require, "src.render.Font")
  Font = okFont and F or nil
  record("formview: install: Font %s", okFont and "resolved"
    or ("unavailable (" .. tostring(F) .. ")"))

  local vanillaDraw = SummaryMenu.draw
  SummaryMenu._battleFormsFormView = true
  SummaryMenu.draw = function(self)
    vanillaDraw(self)
    local ok, err = pcall(M.drawSummary, self)
    if not ok then
      record("formview: SummaryMenu.draw overlay failed (%s)", tostring(err))
    end
  end
  record("formview: install: wrapped SummaryMenu.draw")
  return true
end

return M
