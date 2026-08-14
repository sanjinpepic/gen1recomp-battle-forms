-- A form change is a species re-key.  Everything downstream in battle derives
-- from mon.species -- the species def, the battle picture, the palette -- so
-- changing that one field and dropping the cached picture is the entire
-- transaction.  Transform already works this way; this is the same move made
-- deliberately and held for the rest of the battle.
--
-- The base species is remembered on the MON, not on the battler.  A mega
-- survives switching out, and the engine builds a fresh battler every
-- send-out -- a marker held on the battler would vanish on the way back in
-- while the re-keyed species stayed, leaving the mon permanently transformed
-- in the save.
local Stats = require("src.pokemon.Stats")

local M = {}

M.BASE = "battleFormsBase"

local function recompute(data, mon, speciesId)
  local def = data and data.pokemon and data.pokemon[speciesId]
  if def then
    mon.stats = Stats.calc(def, mon.level, mon.dvs, mon.statExp)
  end
end

-- Refuses rather than half-applying.  A mon left holding a form id its
-- species table has no record for would draw nothing and compute nothing, and
-- the failure would surface somewhere far from here.  The refusal reason is
-- returned rather than swallowed: a caller (src/resolve.lua) logs it, because
-- a silent refusal here is exactly the failure that let a wrong form id ship
-- for a whole release without a single error anywhere.
function M.becomeForm(data, battler, formId)
  local mon = battler and battler.mon
  if not mon or not formId then return nil, "no_target" end
  if not (data and data.pokemon and data.pokemon[formId]) then return nil, "no_record" end

  mon[M.BASE] = mon[M.BASE] or mon.species
  mon.species = formId
  recompute(data, mon, formId)
  battler.sprite = nil
  return true
end

-- Takes the mon rather than the battler: the battle-end sweep walks the whole
-- party, where a mon that transformed and then switched out has no battler at
-- all.  Reverting an untransformed mon is a no-op so the sweep can be blunt.
function M.revertMon(data, mon)
  local base = mon and mon[M.BASE]
  if not base then return nil end
  mon.species = base
  mon[M.BASE] = nil
  recompute(data, mon, base)
  return true
end

function M.revertForm(battler, data)
  if not battler then return nil end
  local done = M.revertMon(data, battler.mon)
  if done then battler.sprite = nil end
  return done
end

return M
