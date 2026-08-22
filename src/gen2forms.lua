-- Gen 2's equivalent of src/forms.lua: apply a form's stats and types to a
-- Pokemon in battle, and revert exactly on every path.
--
-- Gen 2 gives this primitive nothing to attach a battler-scoped override to
-- -- there is no battler wrapper at all (src/battlerof.lua's own header),
-- so mon.species, mon.stats and (for the type seam below) mon.form/
-- mon.formTypes are the mon's OWN fields for the whole battle, not a copy
-- something else owns.  mon.species is still never touched, for forms.lua's
-- own reasons, which hold just as hard here: the sprite registry resolves
-- art from `ctx.mon.form` under the BASE species, and a form change safe to
-- leave mid-battle depends on there being no re-key to forget to undo.  Gen
-- 2's own sprite path (game/src/ui/gen2/BattleState.lua:465-511, `:pic`)
-- reads `self.pokemon[mon.species]` and hands the live `mon` straight to the
-- SAME `pokemon.sprite` hook Gen 1 resolves its battle pics through, fresh
-- on every draw call rather than through any cached battler.sprite -- so
-- unlike Gen 1's forms.lua this module needs no reloadSprite step at all;
-- there is nothing here to invalidate.
--
-- STATS follow the one working precedent Gen 2 already has for a
-- battle-scoped stat change: Transform mutates mon.stats in place
-- (game/src/battle/gen2/Battle.lua:2149-2156) and restores it the same way
-- on the way out (:2178-2194) -- the shape this module's becomeForm/
-- revertMon copy, because Battle:battleStat reads mon.stats directly
-- (:761-762) with no curStats layer to override instead.  Restoring needs no
-- cache the way Transform's own preTransform table does, though: mon.species
-- never moves, so data.pokemon[mon.species].baseStats plus the mon's own
-- untouched dvs/level/statExp (Mon.stats, game/src/battle/gen2/Mon.lua:67)
-- recompute the exact pre-form numbers on demand -- the identical "nothing
-- was ever cached" property src/forms.lua's own revertForm relies on for Gen
-- 1.  hp is never one of the five keys copied, matching Transform's own
-- exclusion list: the HP bar's denominator does not move for a form any more
-- than it does for a Transform.
--
-- TYPES have no comparable seam. Battle:speciesDef(mon)
-- (game/src/battle/gen2/Battle.lua:712, `data.pokemon[mon.species]`) is read
-- FIRST at roughly ten damage/AI/type call sites, every one shaped
-- `(self:speciesDef(x) or {}).types or x.types`, and never consults
-- mon.form -- so a form that only marks the mon is silently ignored there.
-- No Runtime hook covers all ten: `battle.damage` (Battle.lua:1133) wraps
-- only the two full damage calculations (:1093-1099, :2208-2214), where
-- Curse's Ghost check (:2431), Leech Seed's Grass check (:2489), the
-- fixed-damage immunity check (:1632) and the rest read speciesDef directly
-- with no hook at all. Battle.speciesDef ITSELF is the one thing every one
-- of those ten sites already funnels through, so M.install wraps that single
-- method instead of patching ten call sites, none of which read anything off
-- the returned record except `.types` -- wrap-and-delegate, guarded by
-- Battle._battleFormsSpeciesDefPatched the way every other engine_internals
-- patch in this codebase is (src/menu.lua, src/boxmark.lua,
-- src/formview.lua), so a second load wraps nothing and a third-party mod's
-- own wrap over the same method, installed before or after this one, still
-- runs.  The wrapper hands back a shallow copy with `.types` swapped for
-- `mon.formTypes` only when that field is set, so every OTHER field a future
-- call site might read (name, baseStats, growthRate, ...) still answers with
-- the real species' own truth.
local Mon = require("src.battle.gen2.Mon")

local M = {}

local deps = nil

-- `api` alone, and for the identical reason src/forms.lua's own bind takes
-- it: src/formapi.lua announces a form change to anything outside this mod,
-- and it is announced from the two primitives rather than from the eight
-- mechanics that call them so that a mechanic added later cannot apply a
-- form nobody outside hears about. Optional at every point of use -- this
-- module is dofile()d bare by several suites that wire nothing.
function M.bind(modules) deps = modules end

local function report(fn, fields)
  local api = deps and deps.api
  if api and api[fn] then api[fn](fields) end
end

-- Copied in this order and no other: `hp` is deliberately absent, the same
-- exclusion Battle:transform's own loop makes (Battle.lua:2151-2152) for the
-- same reason -- the HP bar's denominator is not supposed to move for a form.
local STAT_KEYS = { "attack", "defense", "speed", "specialAttack", "specialDefense" }

local function applyStats(mon, computed)
  mon.stats = mon.stats or {}
  for _, key in ipairs(STAT_KEYS) do
    mon.stats[key] = computed[key]
  end
end

-- Refuses rather than half-applying, for forms.lua's own reason: a mon left
-- holding a form whose record is missing, carries no `form` field, or
-- carries no baseStats to compute from would draw nothing the sprite
-- registry can resolve and compute nothing meaningful, and the failure
-- would surface somewhere far from here.
function M.becomeForm(data, mon, formId)
  if not mon or not formId then return nil, "no_target" end
  local formDef = data and data.pokemon and data.pokemon[formId]
  if not formDef then return nil, "no_record" end
  if type(formDef.form) ~= "string" or formDef.form == "" then
    return nil, "no_form_field"
  end
  if type(formDef.baseStats) ~= "table" then return nil, "no_base_stats" end

  local computed = Mon.stats(formDef.baseStats, mon.dvs, mon.level, mon.statExp)
  applyStats(mon, computed)
  mon.form = formDef.form
  -- Read by M.install's speciesDef wrap; nil on every mon this module has
  -- never touched, which is what tells that wrapper to answer with the real
  -- species' own types unchanged.
  mon.formTypes = formDef.types
  -- Last, once the form is actually standing, exactly as src/forms.lua's own
  -- becomeForm announces: a listener reading off payload.mon sees the same
  -- world the payload describes. `isPlayer` is deliberately absent -- Gen 2
  -- has no battler wrapper to read a side off (src/battlerof.lua's own
  -- header), and guessing one from a battle this primitive is never handed
  -- would be inventing a field rather than reporting one.
  report("applied", { mon = mon, form = formDef.form, formId = formId,
                      stats = mon.stats, types = mon.formTypes })
  return true
end

-- The one revert both a fainting mon and a benched one go through: Gen 2 has
-- no battler to tell them apart the way Gen 1's revertForm/revertMon split
-- does, since there is no per-battler curStats/curTypes to restore only one
-- of. Reverting an unmarked mon is a no-op so a party sweep can be blunt the
-- same way src/forms.lua's own revertMon is.
function M.revertMon(mon, data)
  if not mon or not mon.form then return nil end
  local was = mon.form
  local baseDef = data and data.pokemon and data.pokemon[mon.species]
  if baseDef and baseDef.baseStats then
    applyStats(mon, Mon.stats(baseDef.baseStats, mon.dvs, mon.level, mon.statExp))
  end
  mon.form = nil
  mon.formTypes = nil
  -- The types named are the species' own, read back off the record rather
  -- than off mon.formTypes, which is nil by now and was the FORM's anyway.
  -- Absent on a call made with no dataset in hand -- the same degradation
  -- the stat restore above already makes, reported rather than faked.
  report("reverted", { mon = mon, form = was, stats = mon.stats,
                       types = baseDef and baseDef.types or nil })
  return true
end

-- Same operation, kept as its own name because resolve.lua's own Gen 1
-- handlers call revertForm from a fainting battler and revertMon from the
-- party sweep -- a future Gen 2 resolve path can keep calling whichever name
-- reads right at its own call site without either one drifting from the
-- other's behaviour.
M.revertForm = M.revertMon

-- Wraps Battle.speciesDef so a formed mon's types reach every damage, AI and
-- immunity check that already reads through it, without any of those ten
-- call sites changing. Delegates to whatever speciesDef already answered --
-- a third-party mod's own wrap over the same method keeps running, before or
-- after this one installs -- and is idempotent the way every other
-- engine_internals patch in this codebase is: a second call finds the guard
-- already set and wraps nothing, so repeated loads in one process cannot
-- stack a chain of wrappers around themselves.
function M.install(mod)
  local ok, Battle = pcall(require, "src.battle.gen2.Battle")
  if not ok or type(Battle) ~= "table" then
    if mod and mod.log then
      mod.log:error("battle_forms: src.battle.gen2.Battle is unavailable -- "
        .. "a Gen 2 form's types will not affect damage, AI or immunity "
        .. "checks")
    end
    return false
  end
  if Battle._battleFormsSpeciesDefPatched then return true end
  if type(Battle.speciesDef) ~= "function" then
    if mod and mod.log then
      mod.log:error("battle_forms: src.battle.gen2.Battle.speciesDef has "
        .. "changed shape -- a Gen 2 form's types will not affect damage, "
        .. "AI or immunity checks")
    end
    return false
  end

  local vanillaSpeciesDef = Battle.speciesDef
  Battle._battleFormsSpeciesDefPatched = true
  Battle.speciesDef = function(self, mon)
    local def = vanillaSpeciesDef(self, mon)
    if not (mon and mon.formTypes) then return def end
    local out = {}
    for key, value in pairs(def or {}) do out[key] = value end
    out.types = mon.formTypes
    return out
  end
  return true
end

return M
