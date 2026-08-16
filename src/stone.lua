-- The items a Pokemon is stamped with -- the mega stones, the orbs and the
-- Z-Crystals -- and what using one does.
--
-- One module for all three families because the item behaviour is the same
-- behaviour: a bag item, used on a Pokemon, that stamps the Pokemon it fits
-- and refuses one it does not.  What differs between a stone and an orb is
-- the transformation it unlocks, and that lives entirely in which pairing
-- table the caller hands in.  A crystal differs by fitting EVERY Pokemon,
-- which is why it has an install of its own below rather than a pairing table
-- listing all 1025 species against all eighteen items.
--
-- All three write the same field, and that is the point: src/eligibility.lua
-- keeps one stamp because a Pokemon holds one item, which is also the rule the
-- games that have a held-item slot enforce -- a Pokemon carrying a Z-Crystal is
-- a Pokemon not carrying a mega stone, and the player picks.
--
-- item_effects short-circuits the vanilla evolution-stone branch entirely, so
-- these items own their own behaviour and cannot be mistaken for a Fire Stone.
-- The item is KEPT rather than consumed: it is the mon's, the way a held item
-- would be on Gold, and taking it away on first use would make the assignment
-- unrepeatable.
local M = {}

local eligibility = nil
local persistent = nil
local gen2 = nil

-- Injected rather than required: a mod's siblings are not on package.path, so
-- main.lua hands the loaded module in.
--
-- The second module is optional and is here for one job: a persistent form is
-- derived from this very stamp (src/persistent.lua), so moving the stamp has to
-- move the form with it.  Without this, giving a Rotom-Wash a Z-Crystal would
-- take away the appliance that entitles it to the form and leave the marker
-- standing -- appliance art with base stats behind it until the next battle
-- ended.  Every write to the stamp below therefore re-derives, and a build
-- without the module bound simply has no persistent forms to re-derive.
--
-- The third argument is the same flag every other Gen 2 branch in this mod
-- reads, and it decides M.items' own fieldMenu/battleMenu fields below --
-- see that function's own header for why.
function M.bind(eligibilityModule, persistentModule, gen2Flag)
  eligibility = eligibilityModule
  persistent = persistentModule
  gen2 = gen2Flag
end

-- The Celadon evolution-stone shelf sells its stones at 2100; what unlocks a
-- form or a move sits above that, stone, orb and crystal alike.
M.PRICE = 4000

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
    if persistent then persistent.mark(ctx.data, mon) end
    return "kept", { "It seems to\nresonate!" }
  end
end

-- Every item named anywhere in a pairing table, with its item record.
-- An item missing from `indices` is left out entirely: an item with no bag
-- index cannot be represented in a Gen 1 save (GenSave.lua builds its
-- id-to-byte maps only from records that have one), so registering it would
-- ship something a player could pick up and then silently lose.
--
-- On Gen 2, fieldMenu/battleMenu = "ITEMMENU_NOUSE" take the USE verb off
-- both PACK pockets, the identical treatment src/persistent.lua's own
-- registration already gives every held-item form -- and for the identical
-- reason: Gold's own PACK dispatcher (Game2:usePartyItem) calls
-- ItemEffects.partyAction(itemId) with no `data` argument, so it can only
-- ever resolve the engine's own built-in item_effects table and never
-- reaches this module's `use` closure below, on any item, regardless of
-- what it registers (confirmed as of 0.39.0). Leaving USE on screen here
-- would show a verb that silently does nothing -- exactly the report that
-- prompted this fix, a player who tried USE on the Red Orb and read the
-- resulting no-op as primal reversion being broken rather than as GIVE
-- being the only real trigger. GIVE writes mon.item directly and is
-- unaffected; src/mega.lua's and src/primal.lua's own Gen 2 branches read
-- it, never this file's own `use`.
function M.items(pairings, indices)
  local out = {}
  for _, byItem in pairs(pairings) do
    for itemId in pairs(byItem) do
      local index = indices and indices[itemId]
      if index then
        out[itemId] = {
          id = itemId,
          name = itemId:gsub("_", " "),
          price = M.PRICE,
          index = index,
          effect = itemId,
          needsTarget = true,
          fieldMenu = gen2 and "ITEMMENU_NOUSE" or nil,
          battleMenu = gen2 and "ITEMMENU_NOUSE" or nil,
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

-- The items with no pairing table behind them, which today is the Z-Crystals.
--
-- A crystal fits every Pokemon there is -- what it selects is a move TYPE, not
-- a species -- so there is no eligibility to consult and no species to refuse.
-- That makes this the shorter half of the same behaviour rather than a second
-- one: the stamp, the field, the item record and the kept-not-consumed rule are
-- all the ones above.  Whether the stamped crystal then does anything is asked
-- much later, in src/zmoves.lua, off the moveset in front of it.
--
-- `itemIds` is an ARRAY so registration order is the caller's and not pairs()'.
-- An id with no bag index is refused out loud for the reason M.install refuses
-- one: a Gen 1 save cannot hold an item with no byte, so registering it would
-- ship something a player could pick up and then silently lose.
function M.installUnpaired(mod, itemIds, indices)
  for _, itemId in ipairs(itemIds) do
    local index = indices and indices[itemId]
    if not index then
      mod.log:error("%s has no bag index -- add it to data/crystals.lua; until "
        .. "then the item cannot exist in a save and no Pokemon can be given "
        .. "one", itemId)
    else
      mod.content.items:register(itemId, {
        id = itemId,
        name = itemId:gsub("_", " "),
        price = M.PRICE,
        index = index,
        effect = itemId,
        needsTarget = true,
      })
      mod.content.item_effects:register(itemId, {
        needsTarget = true,
        battle = false,
        use = function(ctx)
          local mon = ctx and ctx.target
          if not mon then return "failed", { "It won't have\nany effect." } end
          mon[eligibility.STAMP] = itemId
          if persistent then persistent.mark(ctx.data, mon) end
          return "kept", { "It seems to\nresonate!" }
        end,
      })
    end
  end
end

return M
