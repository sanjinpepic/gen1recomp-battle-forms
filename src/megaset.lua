-- Which megas the MEGA EVOLUTIONS option turns on.
--
-- data/megas.lua marks every species/stone pair official or extended, and
-- this is the only file that reads the mark.  What it hands back is the plain
-- species -> stone -> form id table every other module already expects, so
-- eligibility, resolve, the overlay and the menu never learn that a setting
-- exists at all.
--
-- One thing is deliberately NOT selectable: which stones are registered as
-- items.  src/stone.lua registers every stone this table names whatever the
-- option says, because a stone can already be sitting in a player's bag when
-- the option changes, and an item id with no record behind it is a save that
-- cannot be read back.  The option decides what a stone DOES, not whether it
-- exists -- which is why stone.install takes both tables.
local M = {}

M.ALL = "all"
M.OFFICIAL = "official"

local function isRow(row)
  return type(row) == "table" and type(row.form) == "string"
    and type(row.official) == "boolean"
end

-- Pairs whose row carries no usable marker, as "SPECIES/STONE" strings.
-- Sorted so the same broken table always reports in the same order.
function M.problems(raw)
  local found = {}
  for species, byStone in pairs(raw or {}) do
    for stoneId, row in pairs(byStone) do
      if not isRow(row) then found[#found + 1] = species .. "/" .. stoneId end
    end
  end
  table.sort(found)
  return found
end

-- An unmarked pair is dropped from BOTH sets rather than guessed into one:
-- letting it through under ALL and not under OFFICIAL would still be a
-- silent decision about a mega nobody classified.  M.problems is what says
-- so out loud; main.lua logs it.
--
-- Any setting that is not exactly ALL reads as OFFICIAL, so a corrupted or
-- renamed stored value falls to the smaller set.  Erring the other way would
-- hand a player megas they never switched on.
function M.select(raw, setting)
  local officialOnly = setting ~= M.ALL
  local out = {}
  for species, byStone in pairs(raw or {}) do
    for stoneId, row in pairs(byStone) do
      if isRow(row) and (row.official or not officialOnly) then
        out[species] = out[species] or {}
        out[species][stoneId] = row.form
      end
    end
  end
  return out
end

-- The stone ids named by a selected table, as a set -- what src/shop.lua
-- stocks the shelf from.
function M.stoneIds(megas)
  local out = {}
  for _, byStone in pairs(megas or {}) do
    for stoneId in pairs(byStone) do out[stoneId] = true end
  end
  return out
end

return M
