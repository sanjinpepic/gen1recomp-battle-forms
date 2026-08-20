-- Spending shards to change a Pokemon's Tera type, and reading back what that
-- type currently is.
--
-- TWO ITEMS, ONE MECHANIC, and which one you reach for IS the choice.
--
-- The brief asked for the Tera Orb to open a shop: pick a Pokemon, pick a type,
-- pay fifty shards.  The middle step is the problem.  Picking a Pokemon is free
-- -- `needsTarget` hands both engines' own party menus the job -- but picking a
-- TYPE has no primitive on either game: a field item's effect is handed a mon
-- and returns text, and there is no second prompt in that contract on Gen 1 at
-- all.  Building one means a registered screen per engine, and a mechanic that
-- exists only behind a bespoke screen is a mechanic that breaks the first time
-- either engine's menu stack moves.
--
-- So the type is chosen by WHICH SHARD you use, and the shard is the item you
-- use on the Pokemon.  Fifty Fire Shards used on a Charizard make it Fire-Tera.
-- The choice is identical, the payment is identical, and it needs no screen
-- that did not already exist -- it is exactly the shape every other item in
-- this mod already has (src/stone.lua's mega stones, src/persistent.lua's
-- appliances): needsTarget, used on a mon, answers in one line of text.
--
-- THE TERA ORB IS WHAT YOU READ WITH, and that turned out to be the part that
-- could not be left out.  src/teratype.lua derives a Pokemon's Tera type from
-- its DVs, which means the type is real, per-Pokemon and completely invisible
-- -- there is no summary row for it and nowhere to put one.  A player who
-- cannot see a Pokemon's Tera type cannot decide whether to spend fifty shards
-- changing it, so the mechanic would be a currency with no price tag. Using the
-- Orb on a Pokemon says what that Pokemon's Tera type is, costs nothing, and is
-- the whole reason the Orb keeps a USE verb at all.
--
-- WHY THE ORB IS NOT ALSO THE SPENDER.  It could be, if the type came from
-- somewhere.  It does not, so an Orb that spent would have to guess which of up
-- to eighteen shard piles the player meant, and guessing wrong costs fifty
-- shards.  Refusing to guess is the whole of it.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The live save, for the same reason src/fusion.lua keeps one and bound to the
-- same two events: neither engine's item ctx carries the save, and the bag is
-- where the shards are.  Both save.created and save.loaded, never just one --
-- self.save is replaced wholesale on NEW GAME and on CONTINUE, and a listener
-- bound to only the first would be holding a table nothing goes on to mutate.
local liveSave = nil

function M.onSaveReady(ev)
  liveSave = ev and ev.save
end

function M.save() return liveSave end

-- Text is returned as lines rather than a joined string because Gen 1's own
-- item-effect contract takes a list; Gen 2's takes one string with \n in it,
-- which M.gen2Record joins for.
local function lines(...) return { ... } end

-- The name to print for a type: PSYCHIC_TYPE prints as PSYCHIC, the exception
-- every file in this mod that names a type carries.
local function typeName(data, typeId)
  local types = data and data.type_chart and data.type_chart.types
  local record = types and types[typeId]
  local name = type(record) == "table" and record.name or nil
  if type(name) == "string" and name ~= "" then return name end
  return (tostring(typeId):gsub("_TYPE$", ""))
end

local function monName(mon)
  local name = mon and (mon.nickname or mon.name or mon.species)
  return tostring(name or "It")
end

-- READING: what is this Pokemon's Tera type?
--
-- Answers for any Pokemon, including one whose type is the derived default,
-- because that is the case a player most needs told -- a stamped one they chose
-- themselves.
function M.describe(data, mon)
  if not mon then return false, lines("It won't have", "any effect.") end
  local typeId = deps.teratype.of(data, mon)
  if not typeId then
    -- Out loud rather than silent: this is reachable when a save carries a
    -- stamp for a type the running chart no longer has (National Dex switched
    -- off after the fact), and "nothing happened" would read as a broken item.
    return false, lines(monName(mon) .. "'s Tera Type", "can't be read here!")
  end
  return false, lines(monName(mon) .. "'s Tera Type", "is " .. typeName(data, typeId) .. "!")
end

-- SPENDING: fifty shards of one type, and that Pokemon is now that type.
--
-- ORDER MATTERS.  The Pokemon is written FIRST and the shards are taken
-- SECOND, which is the opposite of what it looks like it should be.  Taking
-- payment first and then failing to write leaves a player fifty shards poorer
-- with nothing to show and no way to prove it; writing first and then failing
-- to take payment leaves them a Tera type they did not pay for.  Of the two,
-- only the second is recoverable by the player noticing, and only the first is
-- the kind of loss that gets reported as theft.
--
-- In practice neither happens: M.spend cannot fail once M.count has answered,
-- because nothing runs between them.  The order is chosen for the case where
-- that stops being true.
function M.change(data, mon, typeId)
  if not mon then return false, lines("It won't have", "any effect.") end

  local save = liveSave
  if not save then
    return false, lines("The shards can't", "be counted here!")
  end

  local shards = deps.terashards
  local held = shards.count(save, typeId)
  if held < shards.COST then
    return false, lines(
      ("Need %d %s SHARD."):format(shards.COST, typeName(data, typeId)),
      ("You have %d."):format(held))
  end

  local already = deps.teratype.of(data, mon)
  if already == typeId then
    -- Refused rather than charged.  There is nothing to buy, and an item that
    -- silently takes fifty shards to change nothing is the single worst
    -- outcome available here.
    return false, lines(monName(mon) .. "'s Tera Type",
      "is already " .. typeName(data, typeId) .. "!")
  end

  mon[deps.teratype.STAMP] = typeId
  shards.spend(save, typeId, shards.COST)

  return true, lines(monName(mon) .. "'s Tera Type", "became " .. typeName(data, typeId) .. "!")
end

-- --- the two engines' own item-effect shapes ------------------------------
-- Gen 1 hands { target = mon, data = ... } and wants `status, {lines}` where
-- status is "kept" or "failed"; Gen 2 hands { item, mon, data } and wants
-- { used, text }.  Neither is wrapped in terms of the other -- the two are
-- genuinely different contracts and pretending otherwise is how
-- src/speciesbasemoves.lua's own Gen 2 crashes happened.

local function gen1(fn)
  return function(ctx)
    local ok, text = fn(ctx and ctx.data, ctx and ctx.target, ctx)
    -- "kept" means the item stays in the bag.  Both verbs keep it: the Orb is
    -- a key item and is never consumed, and a shard spend has already taken
    -- its own fifty through the bag directly rather than by being used up.
    return ok and "kept" or "failed", text
  end
end

local function gen2(fn)
  return function(ctx)
    local ok, text = fn(ctx and ctx.data, ctx and ctx.mon, ctx)
    return { used = false, text = table.concat(text, "\n") }, ok
  end
end

-- Registers the Tera Orb's own read verb and one spend verb per shard.
--
-- The Orb's fieldMenu/battleMenu are set here rather than left to
-- src/keyitems.lua's blanket ITEMMENU_NOUSE: that refusal exists because those
-- items had nothing to be used ON, and this one now does.  The other three key
-- items keep it.
function M.install(mod, shardIds, gen2Flag)
  local orbId = deps.keyitems.TERA_ORB

  mod.content.items:patch(orbId, {
    needsTarget = true,
    fieldMenu = gen2Flag and "ITEMMENU_PARTY" or nil,
    battleMenu = gen2Flag and "ITEMMENU_NOUSE" or nil,
  })
  mod.content.item_effects:register(orbId, gen2Flag and {
    needsTarget = true, action = "form", field = true,
    use = gen2(M.describe),
  } or {
    needsTarget = true, battle = false, field = true,
    use = gen1(M.describe),
  })

  for _, itemId in ipairs(shardIds or {}) do
    local typeId = deps.terashards.typeFor(itemId)
    if typeId then
      mod.content.items:patch(itemId, {
        needsTarget = true,
        fieldMenu = gen2Flag and "ITEMMENU_PARTY" or nil,
        battleMenu = gen2Flag and "ITEMMENU_NOUSE" or nil,
      })
      local function run(data, mon) return M.change(data, mon, typeId) end
      mod.content.item_effects:register(itemId, gen2Flag and {
        needsTarget = true, action = "form", field = true, use = gen2(run),
      } or {
        needsTarget = true, battle = false, field = true, use = gen1(run),
      })
    end
  end
end

return M
