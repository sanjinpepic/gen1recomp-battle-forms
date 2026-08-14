-- The stones, and what using one does.
--
-- item_effects short-circuits the vanilla evolution-stone branch entirely, so
-- a mega stone owns its own behaviour and cannot be mistaken for a Fire Stone.
-- The stone is KEPT rather than consumed: it is the mon's, the way a held item
-- would be on Gold, and taking it away on first use would make the assignment
-- unrepeatable.
local M = {}

local eligibility = nil

-- Injected rather than required: a mod's siblings are not on package.path, so
-- main.lua hands the loaded module in.
function M.bind(eligibilityModule)
  eligibility = eligibilityModule
end

-- Curried on the stone so each registered effect knows which stone it is
-- without reading it back out of the context.
function M.effectFor(megas, stoneId)
  return function(ctx)
    local mon = ctx and ctx.target
    if not mon then return "failed", { "It won't have\nany effect." } end
    if not eligibility.formFor(megas, mon.species, stoneId) then
      return "failed", { "It won't have\nany effect." }
    end
    mon[eligibility.STAMP] = stoneId
    return "kept", { "It seems to\nresonate!" }
  end
end

-- Every stone named anywhere in the mega table, with its item record.
-- A stone missing from `indices` is left out entirely: an item with no bag
-- index cannot be represented in a Gen 1 save (GenSave.lua builds its
-- id-to-byte maps only from records that have one), so registering it would
-- ship something a player could pick up and then silently lose.
function M.items(megas, indices)
  local out = {}
  for _, byStone in pairs(megas) do
    for stoneId in pairs(byStone) do
      local index = indices and indices[stoneId]
      if index then
        out[stoneId] = {
          id = stoneId,
          name = stoneId:gsub("_", " "),
          -- The Celadon evolution-stone shelf sells its stones at 2100; a
          -- mega stone sits above that.
          price = 4000,
          index = index,
          effect = stoneId,
          needsTarget = true,
        }
      end
    end
  end
  return out
end

function M.install(mod, megas, indices)
  local items = M.items(megas, indices)
  for _, byStone in pairs(megas) do
    for stoneId in pairs(byStone) do
      if not items[stoneId] then
        mod.log:error("%s has no bag index -- add it to data/stones.lua", stoneId)
      end
    end
  end
  for stoneId, record in pairs(items) do
    mod.content.items:register(stoneId, record)
    mod.content.item_effects:register(stoneId, {
      needsTarget = true,
      -- Assignment is a field decision, not a battle action.
      battle = false,
      use = M.effectFor(megas, stoneId),
    })
  end
end

return M
