-- The items that assign a form -- the mega stones and the orbs -- and what
-- using one does.
--
-- One module for both families because the item behaviour is the same
-- behaviour: a bag item, used on a Pokemon, that stamps the Pokemon it fits
-- and refuses one it does not.  What differs between a stone and an orb is
-- the transformation it unlocks, and that lives entirely in which pairing
-- table the caller hands in.
--
-- item_effects short-circuits the vanilla evolution-stone branch entirely, so
-- these items own their own behaviour and cannot be mistaken for a Fire Stone.
-- The item is KEPT rather than consumed: it is the mon's, the way a held item
-- would be on Gold, and taking it away on first use would make the assignment
-- unrepeatable.
local M = {}

local eligibility = nil

-- Injected rather than required: a mod's siblings are not on package.path, so
-- main.lua hands the loaded module in.
function M.bind(eligibilityModule)
  eligibility = eligibilityModule
end

-- Curried on the item so each registered effect knows which item it is
-- without reading it back out of the context.
function M.effectFor(pairings, itemId)
  return function(ctx)
    local mon = ctx and ctx.target
    if not mon then return "failed", { "It won't have\nany effect." } end
    if not eligibility.formFor(pairings, mon.species, itemId) then
      return "failed", { "It won't have\nany effect." }
    end
    mon[eligibility.STAMP] = itemId
    return "kept", { "It seems to\nresonate!" }
  end
end

-- Every item named anywhere in a pairing table, with its item record.
-- An item missing from `indices` is left out entirely: an item with no bag
-- index cannot be represented in a Gen 1 save (GenSave.lua builds its
-- id-to-byte maps only from records that have one), so registering it would
-- ship something a player could pick up and then silently lose.
function M.items(pairings, indices)
  local out = {}
  for _, byItem in pairs(pairings) do
    for itemId in pairs(byItem) do
      local index = indices and indices[itemId]
      if index then
        out[itemId] = {
          id = itemId,
          name = itemId:gsub("_", " "),
          -- The Celadon evolution-stone shelf sells its stones at 2100; what
          -- unlocks a form sits above that, stone and orb alike.
          price = 4000,
          index = index,
          effect = itemId,
          needsTarget = true,
        }
      end
    end
  end
  return out
end

-- `all` is every pair the table names; `active` is the subset that is allowed
-- to do anything.  Registration reads `all` and only `all`: an item a player
-- is already carrying has to keep existing when an option changes, or
-- switching the mega set to OFFICIAL would leave a save holding a bag byte no
-- record can name.  The option decides what an item DOES -- the effect reads
-- `active`, so a switched-off item refuses exactly the way one used on the
-- wrong species already does.  Primal reversion has no option of its own, so
-- its two tables are one and the same.
function M.install(mod, all, active, indices)
  local items = M.items(all, indices)
  for _, byItem in pairs(all) do
    for itemId in pairs(byItem) do
      if not items[itemId] then
        mod.log:error("%s has no bag index -- add it to data/stones.lua or "
          .. "data/orbs.lua", itemId)
      end
    end
  end
  for itemId, record in pairs(items) do
    mod.content.items:register(itemId, record)
    mod.content.item_effects:register(itemId, {
      needsTarget = true,
      -- Assignment is a field decision, not a battle action.
      battle = false,
      use = M.effectFor(active, itemId),
    })
  end
end

return M
