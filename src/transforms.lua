-- The registry of manually activated transformations: the ones the player has
-- to ask for.  Primal reversion and the condition-driven forms are wired
-- straight to their own events and are deliberately not in here -- there is
-- nothing for a player to decide about either, so neither has a cell, an
-- armed flag or a once-per-battle limit to share.
--
-- Every mechanic of this kind needs the same four things and differs only in
-- what it puts in them: an id, a label for the one menu cell there is room
-- for, a predicate for whether it is on offer right now, and an activation.
--
-- Being in this registry is also what puts a mechanic under the trainer's one
-- manual transformation per battle: the limit is one across everything
-- registered here, so a mega and a Dynamax cannot both happen in one fight.
-- The id still keys a limit of its own beside it (src/arm.lua), because a
-- mechanic exempted from the shared rule -- the generations differed over
-- which were -- would still be once per battle on its own account.
--
-- Registration order is the order the cell cycles in, which is why the list is
-- an array and the id map is only a lookup beside it: iterating a keyed table
-- would reorder the player's menu between runs.
local M = {}

local Registry = {}
Registry.__index = Registry

function M.new()
  return setmetatable({ list = {}, index = {} }, Registry)
end

-- Refuses rather than half-registering, and hands the reason back so the
-- caller can say it out loud.  An entry missing its predicate would draw a
-- cell that cannot be armed, and a second entry under an id already taken
-- would silently share the first one's spent flag -- both are exactly the
-- kind of quiet wrongness this mod has paid for before.
function Registry:register(entry)
  if type(entry) ~= "table" then return false, "not a table" end
  if type(entry.id) ~= "string" or entry.id == "" then
    return false, "id must be a non-empty string"
  end
  if type(entry.label) ~= "string" or entry.label == "" then
    return false, "label must be a non-empty string"
  end
  if type(entry.available) ~= "function" then
    return false, "available must be a function"
  end
  if type(entry.activate) ~= "function" then
    return false, "activate must be a function"
  end
  if self.index[entry.id] then
    return false, "id " .. entry.id .. " is already registered"
  end
  self.index[entry.id] = entry
  self.list[#self.list + 1] = entry
  return true
end

function Registry:all() return self.list end

function Registry:count() return #self.list end

function Registry:get(id)
  if type(id) ~= "string" then return nil end
  return self.index[id]
end

return M
