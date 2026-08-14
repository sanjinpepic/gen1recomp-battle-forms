-- A form change is a species re-key.  Everything downstream in battle derives
-- from mon.species -- the species def, the battle picture, the palette -- so
-- changing that one field and dropping the cached picture is the entire
-- transaction.  Transform already works this way; this is the same move made
-- deliberately and held for the rest of the battle.
local Stats = require("src.pokemon.Stats")

local M = {}

-- Refuses rather than half-applying.  A battler left holding a form id its
-- species table has no record for would draw nothing and compute nothing, and
-- the failure would surface somewhere far from here.
function M.becomeForm(data, battler, formId)
  local mon = battler and battler.mon
  if not mon or not formId then return nil end
  local def = data.pokemon[formId]
  if not def then return nil end

  battler.battleFormsBase = battler.battleFormsBase or mon.species
  mon.species = formId
  mon.stats = Stats.calc(def, mon.level, mon.dvs, mon.statExp)
  battler.sprite = nil
  return true
end

-- Takes `data` because the unwind has to recompute too: a mon left holding
-- the form's stats under its base species would keep the mega's numbers for
-- the rest of the save.
function M.revertForm(battler, data)
  local base = battler and battler.battleFormsBase
  if not base then return nil end
  local mon = battler.mon
  mon.species = base
  battler.battleFormsBase = nil
  battler.sprite = nil
  local def = data and data.pokemon[base]
  if def then
    mon.stats = Stats.calc(def, mon.level, mon.dvs, mon.statExp)
  end
  return true
end

return M
