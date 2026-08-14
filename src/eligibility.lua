-- Who may change form, and into what.
--
-- The stone is stamped straight onto the party mon's own table.  Gen 1 has no
-- held-item slot, and a side table keyed by mon is not possible: nothing in a
-- Gen 1 mon is both unique and stable (no personality value, no uuid; otId is
-- the trainer's and DVs are four 4-bit rolls, so two same-species catches
-- collide).  The save format is a schema-less Lua-literal writer that re-emits
-- whatever keys it finds, so a field added here round-trips for free.
local M = {}

M.STAMP = "battleFormsStone"

function M.stoneOf(mon)
  return mon and mon[M.STAMP] or nil
end

function M.formFor(megas, species, stone)
  if not species or not stone then return nil end
  local byStone = megas[species]
  return byStone and byStone[stone] or nil
end

function M.formForMon(megas, mon)
  if not mon then return nil end
  return M.formFor(megas, mon.species, M.stoneOf(mon))
end

return M
