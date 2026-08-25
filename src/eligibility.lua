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

-- Species that may never use ANY of the trainer's transformations, whatever
-- they are carrying.
--
-- Eternatus is the whole list and is a deliberate exception rather than a
-- balance decision: its Eternamax shape exists for one scripted fight
-- (wild_forms' own two-phase encounter) and is not a Dynamax anybody performs.
-- A caught Eternatus that could then Dynamax, Terastallize or hold a Z-Crystal
-- would be offering the player a second, ordinary route to a Pokemon whose
-- entire characterisation is that its transformation is not available to them.
--
-- Keyed by species AND by form id, because both are asked: the caught
-- Pokemon is ETERNATUS, and the battle-only shape is ETERNATUS_ETERNAMAX.
M.NO_GIMMICKS = {
  ETERNATUS = true,
  ETERNATUS_ETERNAMAX = true,
}

--- Whether this Pokemon is barred from every manual transformation.
---
--- Asked at the three places that decide whether a gimmick is on offer -- the
--- player's own menu cell, the outward-facing API, and the enemy trainer's
--- choice -- so a bar cannot hold in one and leak through another.
function M.barredFromGimmicks(mon)
  if type(mon) ~= "table" then return false end
  if mon.species and M.NO_GIMMICKS[mon.species] then return true end
  return mon.form ~= nil and M.NO_GIMMICKS[mon.form] == true
end

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
