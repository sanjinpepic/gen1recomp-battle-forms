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
function M.items(megas)
  local out = {}
  for _, byStone in pairs(megas) do
    for stoneId in pairs(byStone) do
      out[stoneId] = {
        id = stoneId,
        name = stoneId:gsub("_", " "),
        price = 0,
        effect = stoneId,
        needsTarget = true,
      }
    end
  end
  return out
end

function M.install(mod, megas)
  for stoneId, record in pairs(M.items(megas)) do
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
