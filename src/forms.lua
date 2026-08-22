-- A form change marks the Pokemon rather than rewriting it.
--
-- mon.species is never touched.  The sprite mod resolves form art from a
-- `form` field on the mon (dev/src/registry.lua's formId(): ctx.form or
-- ctx.mon.form), keyed under the BASE species' own art entry --
-- CHARIZARD.forms.MEGA_X, never a re-keyed CHARIZARD_MEGA_X -- so a species
-- re-key could never find any art at all. Leaving the species alone is also
-- what makes a form change safe to leave mid-battle: there is no re-key to
-- forget to undo, and the displayed name is right for free, because the
-- engine reads it off data.pokemon[mon.species], which never changed either.
--
-- Stats and types follow the shape the engine's own Transform already uses:
-- override the battler's curStats/curTypes rather than the mon's own, since
-- those are exactly the fields Damage.lua, TurnOrder.lua and Status.lua read
-- for battle math (BattleState.lua's own comment on makeBattler: "volatile
-- state; Transform/Conversion/Mimic override the cur* fields"). mon.stats
-- -- the HP bar's denominator -- is never touched: a mega form keeps the
-- base form's HP in the real games, and changing it would disturb the bar
-- for a stat that was never supposed to move.
local Stats = require("src.pokemon.Stats")

local M = {}

local deps = nil

-- `api` alone: src/formapi.lua, the outward-facing announcement of a form
-- change (that file's own header on why the announcement is fired from this
-- primitive rather than from the eight mechanics that call it).  Bound by
-- main.lua and deliberately optional -- this module is dofile()d bare by
-- half a dozen suites that never wire anything, and a primitive that
-- applied a form correctly only once something had been bound to it would
-- be a worse primitive than one that simply says nothing to nobody.
function M.bind(modules) deps = modules end

local function report(fn, fields)
  local api = deps and deps.api
  if api and api[fn] then api[fn](fields) end
end

-- The battle picture is rebuilt through the real send-out constructor rather
-- than merely invalidated: BattleState builds battler.sprite once and the
-- draw path just blits whatever is cached there, so clearing it with nothing
-- to reload would leave the mon undrawn for the rest of the fight.
-- BattleState.makeBattler reads data/mon (now including the mon's own
-- `form`) and returns a fresh battler, mutating nothing, so a throwaway one
-- built for this mon, keeping only its sprite, is the real send-out picture
-- -- built through the species' own palette, not Transform's forced gray --
-- without touching the engine.
--
-- `battle` is optional -- the unit suite exercises forms.lua with a bare
-- battler and no battle at all -- and requiring BattleState is wrapped in
-- pcall because engine_internals is a courtesy the host owes the mod, not a
-- guarantee: whenever the module, or the build itself, is unavailable the
-- picture is simply left as it was rather than blanked. `fresh and
-- fresh.sprite or battler.sprite` covers a build that resolves but comes
-- back with no sprite the same way.
local function reloadSprite(battle, battler)
  if not (battle and battler) then return end
  local okRequire, BattleState = pcall(require, "src.battle.BattleState")
  if not okRequire or not (BattleState and BattleState.makeBattler) then return end
  local okBuild, fresh = pcall(BattleState.makeBattler, battle.data, battler.mon,
                                battler.isPlayer)
  if okBuild then
    battler.sprite = fresh and fresh.sprite or battler.sprite
  end
end

-- Refuses rather than half-applying. A mon left holding a form whose record
-- is missing, or whose record has no `form` field of its own, would draw
-- nothing the sprite registry can resolve and compute nothing meaningful,
-- and the failure would surface somewhere far from here. The reason is
-- returned rather than swallowed: resolve.lua logs it, because a silent
-- refusal here is exactly the failure that let a wrong form id ship for a
-- whole release without a single error anywhere (0.2.1's mega table naming
-- a display-name field instead of a record key).
function M.becomeForm(data, battler, formId, battle)
  local mon = battler and battler.mon
  if not mon or not formId then return nil, "no_target" end
  local formDef = data and data.pokemon and data.pokemon[formId]
  if not formDef then return nil, "no_record" end
  if type(formDef.form) ~= "string" or formDef.form == "" then
    return nil, "no_form_field"
  end

  mon.form = formDef.form
  battler.curStats = Stats.calc(formDef, mon.level, mon.dvs, mon.statExp)
  battler.curTypes = formDef.types
  reloadSprite(battle, battler)
  -- Last, once the form is actually standing: a listener that reads off
  -- payload.mon has to see the same world the payload describes.
  report("applied", { mon = mon, form = formDef.form, formId = formId,
                      stats = battler.curStats, types = battler.curTypes,
                      isPlayer = battler.isPlayer })
  return true
end

-- The marker write itself, split out of M.revertMon so that M.revertForm can
-- clear it FIRST and announce LAST, once the battler's own fields are back:
-- announcing from inside revertMon, the way revertForm used to call it,
-- would have fired a payload carrying the mon's out-of-battle block while
-- the battler was still holding the form's -- the one moment those two
-- disagree. Returns the form that came off, so the announcement can name it.
--
-- `form` is cleared to nil, not to false or "" -- the save writer re-emits
-- whatever field it finds on the mon, and a falsy-but-present key would
-- round-trip into the save file as a lingering, meaningless entry instead
-- of vanishing the way an untransformed mon's save always looked.
local function clearMark(mon)
  if not mon or not mon.form then return nil end
  local was = mon.form
  mon.form = nil
  return was
end

-- Clears the marker on a mon with no battler in hand: the battle-end sweep
-- walks the whole party, where a mon that transformed and then switched out
-- has no battler at all. Reverting an untransformed mon is a no-op so the
-- sweep can be blunt.
function M.revertMon(mon)
  local was = clearMark(mon)
  if not was then return nil end
  -- No battler in hand at all here (this is the party sweep's path), so the
  -- block named is the mon's own -- which, out of battle, is exactly what
  -- the Pokemon has.
  report("reverted", { mon = mon, form = was, stats = mon.stats })
  return true
end

-- Restores the battler's curStats/curTypes to what a fresh send-out would
-- have given it. Nothing needs to have been cached for this: becomeForm
-- never touched mon.species or mon.stats, so the base species' own record
-- and the mon's own stat block are always the right values to fall back to.
function M.revertForm(battler, data, battle)
  local mon = battler and battler.mon
  local was = clearMark(mon)
  if not was then return nil end
  local baseDef = data and data.pokemon and data.pokemon[mon.species]
  battler.curStats = mon.stats
  battler.curTypes = baseDef and baseDef.types or battler.curTypes
  reloadSprite(battle, battler)
  report("reverted", { mon = mon, form = was, stats = battler.curStats,
                       types = battler.curTypes, isPlayer = battler.isPlayer })
  return true
end

return M
