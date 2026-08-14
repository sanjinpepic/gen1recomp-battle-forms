-- Who may change form, and into what.
--
-- A pairing table is species -> item -> form id, and WHICH one a caller
-- passes is what says which transformation type it is asking about:
-- data/megas.lua answers "may this mon mega", data/primals.lua answers "is
-- this mon primal".  Nothing here knows the difference, which is exactly why
-- neither transformation type can leak into the other's decisions.
--
-- The item is stamped straight onto the party mon's own table.  Gen 1 has no
-- held-item slot, and a side table keyed by mon is not possible: nothing in a
-- Gen 1 mon is both unique and stable (no personality value, no uuid; otId is
-- the trainer's and DVs are four 4-bit rolls, so two same-species catches
-- collide).  The save format is a schema-less Lua-literal writer that re-emits
-- whatever keys it finds, so a field added here round-trips for free.
local M = {}

-- One field, so a mon carries one of these items at a time -- which is how a
-- held item behaves in the games that have a slot for one, and why an orb and
-- a stone need no separate stamps.  The name is save data: every mon already
-- stamped is stamped under this exact key, so it stays as written even though
-- orbs stamp through it too.
M.STAMP = "battleFormsStone"

function M.stoneOf(mon)
  return mon and mon[M.STAMP] or nil
end

function M.formFor(pairings, species, stone)
  if not species or not stone then return nil end
  local byStone = pairings[species]
  return byStone and byStone[stone] or nil
end

function M.formForMon(pairings, mon)
  if not mon then return nil end
  return M.formFor(pairings, mon.species, M.stoneOf(mon))
end

return M
