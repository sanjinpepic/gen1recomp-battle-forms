-- Tera Shards: one bag item per type, and the currency a Tera Orb spends to
-- change a Pokemon's Tera type.
--
-- THE BAG IS THE LEDGER.  There is no shard array anywhere in this mod and
-- there deliberately is not one.  A per-type counter kept on the side would be
-- a second thing to save, a second thing to validate, a second thing for a
-- .sav round trip to disagree with -- and the engine already ships a per-item
-- counter that does all three: save.inventory, keyed by item id, capped at 99 a
-- stack, scrubbed against the registry on load.  Eighteen items IS the
-- eighteen-slot ledger, and buying, selling and tossing them work because
-- nothing here had to reimplement any of it.
--
-- BYTELESS, ALL EIGHTEEN, and the reason is arithmetic rather than taste.
-- data/plates.lua counted 234-255 as what was left after every other indices
-- table in this directory; TM171 and three others have since taken part of it,
-- leaving seventeen free bytes on Gen 1.  Eighteen shards do not fit in
-- seventeen bytes, and there is no principled way to choose which type goes
-- without: a Fire Shard that survives a cartridge export where a Fairy Shard
-- does not is a bug report waiting to be filed, not a design.  So none of them
-- carry a byte, which is exactly the conclusion data/plates.lua reached for the
-- Plates and the Memories and for the same reason.
--
-- On Gold that is not even a choice -- data/stones.lua's header covers why no
-- item this mod registers may carry a byte there at all.
--
-- WHAT A SHARD IS NOT.  It is not spent to terastallize.  Terastallization
-- costs nothing and is gated by the Tera Orb alone, exactly as it was before
-- shards existed; a shard only ever buys a CHANGE to what a Pokemon's Tera type
-- is.  Keeping those two apart is why this file knows nothing about battles.
local M = {}

M.PREFIX = "TERA_SHARD_"

-- Fifty of one type changes one Pokemon.  It is meant to be a project rather
-- than an errand -- the point of a Tera type being mostly the Pokemon's own is
-- that overriding one costs something -- and fifty at the shelf price below is
-- roughly a gym's worth of prize money.
M.COST = 50

-- Nominal, and cheaper than a mega stone (4000) on purpose: a stone buys one
-- Pokemon a permanent second form, where a shard is one fiftieth of one type
-- change.  Not free, for the reason src/keyitems.lua gives -- a zero price
-- makes the mart's affordable-quantity division a division by zero.
M.PRICE = 200

function M.idFor(typeId) return M.PREFIX .. typeId end

-- The type a shard id names, or nil for anything that is not one of ours.
function M.typeFor(itemId)
  if type(itemId) ~= "string" then return nil end
  local typeId = itemId:match("^" .. M.PREFIX .. "(.+)$")
  if typeId == nil or typeId == "" then return nil end
  return typeId
end

-- PSYCHIC_TYPE is the engine's id and PSYCHIC is what a player calls it; the
-- same exception src/tera.lua, data/terablast.lua, data/zmoves.lua and
-- data/maxmoves.lua each carry. Read off the chart record where there is one so
-- this follows a renamed type rather than a copy of its name going stale.
local function displayName(mod, typeId)
  local registry = mod and mod.content and mod.content.type_chart
  if registry and type(registry.get) == "function" then
    local ok, record = pcall(registry.get, registry, typeId)
    if ok and type(record) == "table" and type(record.name) == "string"
        and record.name ~= "" then
      return record.name
    end
  end
  return (typeId:gsub("_TYPE$", ""))
end

-- Whether the merged chart carries this type, guarded exactly as
-- src/tera.lua's own typeExists is and for the same reason: a shard for a type
-- the running game has never heard of is an item that can be bought and can
-- never be spent, and Red's chart really does lack DARK, STEEL and FAIRY until
-- National Dex registers one over the top.
local function typeExists(mod, typeId)
  local registry = mod and mod.content and mod.content.type_chart
  if not registry or type(registry.get) ~= "function" then return false end
  local ok, record = pcall(registry.get, registry, typeId)
  return ok and record ~= nil
end

-- Registers one shard per type the running chart can resolve, and answers the
-- id list in the order it was given -- data/terablast.lua's order, which is
-- Red's fifteen first and the three National Dex adds last, so the shelf reads
-- the way TERA TYPE's own row does.
--
-- A type with no chart record is skipped and SAID, the rule src/tera.lua's own
-- install runs on: one missing shard is a better outcome than a load failure,
-- and silence would leave a player hunting a shelf row that was never built.
function M.install(mod, types)
  local ids = {}
  for _, typeId in ipairs(types or {}) do
    if typeExists(mod, typeId) then
      local itemId = M.idFor(typeId)
      mod.content.items:register(itemId, {
        id = itemId,
        name = displayName(mod, typeId) .. " SHARD",
        price = M.PRICE,
        -- No index on either game; see this file's header and
        -- data/stones.lua's.
        tossable = true,
      })
      ids[#ids + 1] = itemId
    elseif mod and mod.log then
      mod.log:warn(
        "battle_forms: no %s SHARD -- this game's merged type chart has no "
          .. "record for %s, which is what a Red-era chart looks like; the "
          .. "shard is left off the shelf rather than sold as something no "
          .. "Tera Orb could ever spend", tostring(typeId), tostring(typeId))
    end
  end
  return ids
end

-- How many of one type's shards the bag holds.
--
-- Read live off save.inventory rather than captured, for the reason
-- src/keyitems.lua's own M.held gives: a shard bought between one Tera Orb use
-- and the next has to count, and no event tells this mod one was.
function M.count(save, typeId)
  local inv = save and save.inventory
  if type(inv) ~= "table" then return 0 end
  return tonumber(inv[M.idFor(typeId)]) or 0
end

-- Every type the bag currently holds enough of, in the given type order.
function M.affordable(save, types, cost)
  cost = cost or M.COST
  local out = {}
  for _, typeId in ipairs(types or {}) do
    if M.count(save, typeId) >= cost then out[#out + 1] = typeId end
  end
  return out
end

-- Spends the cost, or answers false and changes nothing.
--
-- All-or-nothing on purpose: a partial spend that then failed to write the
-- Pokemon's new Tera type would take a player's shards and give nothing back,
-- and there is no way to hand them a refund they would trust.  So the caller
-- writes the type FIRST and calls this second -- see src/terashop.lua.
function M.spend(save, typeId, cost)
  cost = cost or M.COST
  local inv = save and save.inventory
  if type(inv) ~= "table" then return false end
  local itemId = M.idFor(typeId)
  local held = tonumber(inv[itemId]) or 0
  if held < cost then return false end
  local left = held - cost
  inv[itemId] = left > 0 and left or nil
  if left <= 0 and type(save.bagOrder) == "table" then
    for i = #save.bagOrder, 1, -1 do
      if save.bagOrder[i] == itemId then table.remove(save.bagOrder, i) end
    end
  end
  return true
end

return M
