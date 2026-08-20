-- The items the TRAINER carries, as against the ones a Pokemon is stamped
-- with.
--
-- The real games gate these transformations at two tiers and this mod only
-- ever modelled one of them.  A mega evolution needs a Mega Stone on the
-- Pokemon AND a Key Stone on the trainer; a Dynamax needs no per-Pokemon item
-- at all and rests entirely on the trainer's Dynamax Band.  Without the outer
-- tier a stone was the whole requirement and Dynamax had no requirement, which
-- is why it was offered to every species in every battle from the first route.
--
-- Primal reversion deliberately has no entry here.  The Red and Blue Orbs are
-- the whole of its requirement in the real games too, so inventing a trainer
-- item for it would be this mod making something up rather than modelling
-- something.
--
-- The rows below are the shape the later mechanics need and nothing more: the
-- Tera Orb arrived as an id, a bag byte and one `available` line, and the
-- Z-Ring arrived the same way rather than as another module.
--
-- The Z-Ring is the one of the four that is the OUTER of two tiers again, the
-- way the Key Stone is: a Z-Move needs the ring on the trainer and a Z-Crystal
-- on the Pokemon, where a Dynamax and a Terastallization rest on the trainer's
-- item alone.
local M = {}

M.KEY_STONE = "KEY_STONE"
M.DYNAMAX_BAND = "DYNAMAX_BAND"
M.TERA_ORB = "TERA_ORB"
M.Z_RING = "Z_RING"

-- Registration order, and the order they are checked in when a suite walks
-- them.  An array rather than a keyed table for the same reason
-- src/transforms.lua keeps one: iterating a keyed table reorders the shelf
-- between runs.
M.ITEMS = { M.KEY_STONE, M.DYNAMAX_BAND, M.TERA_ORB, M.Z_RING }

-- Nominal on purpose.  A mega stone is 4000 because it buys one Pokemon one
-- form; a key item buys the mechanic itself, and pricing a whole mechanic like
-- a collectible would make the first one a wall rather than an errand.  Not
-- free: a zero price makes the mart's own affordable-quantity division a
-- division by zero, and an item worth nothing is one a player walks past.
M.PRICE = 200

-- gen2 gates fieldMenu/battleMenu below the same way src/stone.lua's own
-- registration does, for the same reason: these carry no `use` effect at
-- all -- there is nothing to use one ON, so nothing here ever registered
-- one -- and Gold's own PACK still offers a USE row for any item that does
-- not explicitly refuse it, which reaches Game2:usePartyItem's data-less
-- dispatch and, on an item with no engine-builtin record, does nothing.
-- Before this a Key Stone showed a dead USE verb on Gold with nothing to
-- explain it; a player who tried it (reasonably, since these gate a
-- mechanic and look actionable) got silence and no way to tell a real
-- refusal from a broken one. These items gate a mechanic through the bag
-- alone -- src/keyitems.lua's own M.held reads straight off the inventory
-- -- so there was never a USE action to lose.
local function record(itemId, index, gen2)
  return {
    id = itemId,
    name = itemId:gsub("_", " "),
    price = M.PRICE,
    -- No bag byte on Gold, and data/stones.lua holds the whole argument.  The
    -- short version: 196-199 are TM_ROAR, TM_TOXIC, TM_ZAP_CANNON and
    -- TM_ROCK_SMASH there, the TM range is what gym leaders award, and Gold
    -- resolves an award byte by scanning every registered item for a matching
    -- `index` -- so a gym prize handed out a Key Stone or a Tera Orb instead
    -- of the TM.  A record with no index matches no byte and cannot be handed
    -- out at all.  Gen 1 keeps these four: 98+ really is free there.
    -- `(not gen2) and index or nil`, never `gen2 and nil or index` -- the
    -- latter reads correctly and always yields `index`, because `and nil`
    -- collapses to the false branch.
    index = (not gen2) and index or nil,
    -- There is nothing to use one on and nothing to spend, so every bag verb
    -- that would move it back out is refused.  `keyItem` is the field the Gen 1
    -- bag, mart and item PC actually read when they refuse to toss, sell or
    -- deposit something; `tossable` says the same thing in the vocabulary the
    -- item schema declares.  Both, because losing one to a stray TOSS would
    -- switch a whole mechanic off with nothing in battle to say why.
    keyItem = true,
    tossable = false,
    fieldMenu = gen2 and "ITEMMENU_NOUSE" or nil,
    battleMenu = gen2 and "ITEMMENU_NOUSE" or nil,
  }
end

-- Registration is never gated, on anything.  That is the rule src/megaset.lua
-- follows for a switched-off stone and it holds harder here: an item in a save
-- must always be an item the save can name, and a bag byte with no record
-- behind it is a save the game can no longer read back.  Nothing about these
-- two is optional in the first place -- there is no option that turns a key
-- item off -- but the reason to state it is that the GATE is conditional and
-- the registration must never learn that.
function M.install(mod, indices, gen2)
  for _, itemId in ipairs(M.ITEMS) do
    local index = indices and indices[itemId]
    if not index then
      mod.log:error("%s has no bag index -- add it to data/keyitems.lua; "
        .. "until then the item cannot exist in a save and the mechanic it "
        .. "gates can never be switched on", itemId)
    else
      mod.content.items:register(itemId, record(itemId, index, gen2))
    end
  end
end

-- Whether the trainer is carrying one, read live off the bag rather than
-- captured when the battle started: a key item bought between fights has to
-- work in the next one, and there is no event that would tell this mod it was
-- bought.  battle.game.save.inventory is the engine's own possession path
-- (BattleState.lua:577 keeps the game, and its EXP.ALL check at 3975 reads the
-- bag exactly here).
--
-- `battle.save` is asked second, for src/gen2menu.lua's own reason:
-- game/src/battle/gen2/Battle.lua carries `self.save` directly
-- (`self.save = opts.save`) and no `.game` field at all -- there is no UI
-- BattleState in reach of `available(battle)`, only the engine object
-- src/battlerof.lua's own header describes, so `battle.game.save` alone
-- would never resolve on Gen 2 and no key item would ever read as held.
-- Gen 1's BattleState never carries a `.save` field of its own, so this is
-- inert there and the `game.save` branch keeps deciding it exactly as
-- before.
--
-- Answers false rather than throwing when any link is missing.  This runs from
-- the menu cell's decision on every drawn frame, and a battle screen taken
-- down by a nil index is a worse outcome than a cell that is not offered.
function M.held(battle, itemId)
  local game = battle and battle.game
  local save = (game and game.save) or (battle and battle.save)
  local inventory = save and save.inventory
  if not inventory or not itemId then return false end
  local carried = inventory[itemId]
  -- A bag entry is a count, but the engine's own badge reads only ever test
  -- truthiness and its fixtures store `true` (parity_cinnabar_east_surf.lua) --
  -- so comparing straight to a number here would error on that shape instead
  -- of answering about it.
  if type(carried) == "number" then return carried > 0 end
  return carried ~= nil and carried ~= false
end

return M
