-- No bag byte on Gold, and the reason is a real bug rather than tidiness:
-- every indices table in data/ was numbered against Gen 1, where vanilla ends
-- at 97 and 98 up is free.  Gold has 250 items filling 1-250.  This mod fills
-- 98-233, so on Gold each of those bytes carried a second record, and Gold's
-- own item-award path resolves a byte by scanning every registered item for a
-- matching `index` (game/src/world/gen2/World.lua:354) with `pairs` deciding
-- the winner.  Gym prizes handed out key items; apricorn and berry trees
-- handed out mega stones.
--
-- What is pinned here is the shape that makes that impossible rather than
-- unlikely: on Gen 2 the records carry no `index` AT ALL, so the scan can
-- never return one.  A test asserting "the byte is different on Gold" would
-- pass a fix that only moved the collision; asserting the field is absent is
-- the only version that cannot.
--
-- Gen 1 is pinned in the same breath and for the opposite reason -- those
-- bytes are permanent, and a change that quietly dropped them there would
-- turn every stone already in a Red bag into nothing nameable.
--
-- data/stones.lua carries the full argument and the evidence trail.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local E = dofile(MOD .. "/src/eligibility.lua")

-- Captures what actually reached the registry, which is the only thing that
-- matters here -- an item record built correctly and registered with a stale
-- table would pass any assertion made against the builder.
local function recorder()
  local seen = {}
  local function register(_, id, record) seen[id] = record end
  return seen, {
    log = { error = function() end, warn = function() end,
            info = function() end },
    content = {
      items = { register = register },
      item_effects = { register = function() end },
    },
  }
end

-- --- the four trainer key items -------------------------------------------
-- 196-199 on Gold are TM_ROAR, TM_TOXIC, TM_ZAP_CANNON and TM_ROCK_SMASH, and
-- the TM range is what gym leaders award.  This is the collision a player
-- actually reported.
local keyIndices = dofile(MOD .. "/data/keyitems.lua")

local gen1Keys, gen1Mod = recorder()
KeyItems.install(gen1Mod, keyIndices, false)
for _, itemId in ipairs(KeyItems.ITEMS) do
  T.eq(gen1Keys[itemId].index, keyIndices[itemId],
    itemId .. " keeps its permanent bag byte on Gen 1")
end

local gen2Keys, gen2Mod = recorder()
KeyItems.install(gen2Mod, keyIndices, true)
for _, itemId in ipairs(KeyItems.ITEMS) do
  T.eq(gen2Keys[itemId] ~= nil, true, itemId .. " is still registered on Gold")
  T.eq(gen2Keys[itemId].index, nil,
    itemId .. " carries no bag byte on Gold, so no gym prize can resolve to it")
end

-- --- mega stones ----------------------------------------------------------
-- 101 and 102 are PNK_APRICORN and BLACKGLASSES on Gold: the tree pickups.
local pairings = { VENUSAUR = { VENUSAURITE = "VENUSAUR_MEGA" } }
local stoneIndices = { VENUSAURITE = 98 }

Stone.bind(E, nil, false)
local gen1Stones, gen1StoneMod = recorder()
Stone.install(gen1StoneMod, pairings, pairings, stoneIndices)
T.eq(gen1Stones.VENUSAURITE.index, 98, "a stone keeps its byte on Gen 1")

Stone.bind(E, nil, true)
local gen2Stones, gen2StoneMod = recorder()
Stone.install(gen2StoneMod, pairings, pairings, stoneIndices)
T.eq(gen2Stones.VENUSAURITE ~= nil, true, "the stone is still registered on Gold")
T.eq(gen2Stones.VENUSAURITE.index, nil, "a stone carries no bag byte on Gold")

-- installUnpaired is the Z-Crystal path and registers through its own literal
-- rather than M.items, so it is pinned separately rather than assumed.
Stone.bind(E, nil, false)
local gen1Unpaired, gen1UnpairedMod = recorder()
Stone.installUnpaired(gen1UnpairedMod, { "NORMALIUM_Z" }, { NORMALIUM_Z = 200 })
T.eq(gen1Unpaired.NORMALIUM_Z.index, 200, "a crystal keeps its byte on Gen 1")

Stone.bind(E, nil, true)
local gen2Unpaired, gen2UnpairedMod = recorder()
Stone.installUnpaired(gen2UnpairedMod, { "NORMALIUM_Z" }, { NORMALIUM_Z = 200 })
T.eq(gen2Unpaired.NORMALIUM_Z ~= nil, true, "the crystal is still registered on Gold")
T.eq(gen2Unpaired.NORMALIUM_Z.index, nil, "a crystal carries no bag byte on Gold")

-- --- persistent-form items ------------------------------------------------
-- These already had a byteless case: `false` is data/plates.lua's deliberate
-- "no byte on either game".  Both cases are pinned, because the edit here
-- changed the expression that reads `false` and a regression could plausibly
-- turn a Plate's nil into something else.
-- Same nesting as data/persistent.lua and data/appliances.lua: species, then
-- the item that stamps it, then the form that item means.
local persistentRows = { ROTOM = { ROTOM_FAN = "ROTOM_FAN" },
                         ARCEUS = { SPOOKY_PLATE = "ARCEUS_GHOST" } }
local persistentIndices = { ROTOM_FAN = 210, SPOOKY_PLATE = false }

Persistent.bind({ price = 200, gen2 = false })
local gen1Persist, gen1PersistMod = recorder()
Persistent.install(gen1PersistMod, persistentRows, persistentIndices)
T.eq(gen1Persist.ROTOM_FAN.index, 210, "an appliance keeps its byte on Gen 1")
T.eq(gen1Persist.SPOOKY_PLATE.index, nil, "a Plate is byteless on Gen 1 too")

Persistent.bind({ price = 200, gen2 = true })
local gen2Persist, gen2PersistMod = recorder()
Persistent.install(gen2PersistMod, persistentRows, persistentIndices)
T.eq(gen2Persist.ROTOM_FAN ~= nil, true, "the appliance is still registered on Gold")
T.eq(gen2Persist.ROTOM_FAN.index, nil, "an appliance carries no bag byte on Gold")
T.eq(gen2Persist.SPOOKY_PLATE.index, nil, "a Plate stays byteless on Gold")

-- --- fusion items ---------------------------------------------------------
local fusionRows = { KYUREM = { DNA_SPLICERS = "KYUREM_BLACK" } }
local fuserIndices = { DNA_SPLICERS = 220 }

Fusion.bind({ price = 200, gen2 = false })
local gen1Fuse, gen1FuseMod = recorder()
Fusion.install(gen1FuseMod, fusionRows, fuserIndices)
T.eq(gen1Fuse.DNA_SPLICERS.index, 220, "a fuser keeps its byte on Gen 1")

Fusion.bind({ price = 200, gen2 = true })
local gen2Fuse, gen2FuseMod = recorder()
Fusion.install(gen2FuseMod, fusionRows, fuserIndices)
T.eq(gen2Fuse.DNA_SPLICERS ~= nil, true, "the fuser is still registered on Gold")
T.eq(gen2Fuse.DNA_SPLICERS.index, nil, "a fuser carries no bag byte on Gold")

-- --- TM171 is deliberately NOT in this list -------------------------------
-- 252 sits in Gold's own free range (251-255 are the only bytes Gold leaves
-- open), so it collides with nothing and keeps its byte on both games.  Pinned
-- so that a later sweep "for consistency" has to argue with this line first.
local tmIndices = dofile(MOD .. "/data/tm171.lua")
T.eq(tmIndices.TM171 >= 251 and tmIndices.TM171 <= 255, true,
  "TM171 sits in the five bytes Gold leaves free, so it needs no exemption")

T.finish("battle_forms_bagbyte")
