package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Stone = dofile(MOD .. "/src/stone.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local megas = dofile(MOD .. "/data/megas.lua")
local indices = dofile(MOD .. "/data/stones.lua")

Stone.bind(E)

local DATA = { pokemon = { CHARIZARD = { name = "CHARIZARD" },
                           PIDGEY = { name = "PIDGEY" } } }

local use = Stone.effectFor(megas, "CHARIZARDITE_X")

local mon = { species = "CHARIZARD" }
local outcome = use({ data = DATA, target = mon })
T.eq(outcome, "kept", "the stone is not consumed -- it stays with the mon")
T.eq(E.stoneOf(mon), "CHARIZARDITE_X", "using the stone stamps the mon")

local wrong = { species = "PIDGEY" }
T.eq(use({ data = DATA, target = wrong }), "failed",
  "a stone refuses a species it has no form for")
T.eq(E.stoneOf(wrong), nil, "a refused use stamps nothing")

T.eq(use({ data = DATA, target = nil }), "failed", "no target fails cleanly")

T.check(Stone.items(megas, indices)["CHARIZARDITE_X"] ~= nil,
  "every stone in the table becomes an item")

-- Charizard has two stones and they must not collapse into one item.
local items = Stone.items(megas, indices)
T.check(items["CHARIZARDITE_Y"] ~= nil, "the second Charizard stone is its own item")

-- ------- bag indices -------------------------------------------------

-- Every stone actually named in megas.lua must have gotten an index, and no
-- two stones can share one: a collision would make one item indistinguishable
-- from another in a save.
local seenIndex = {}
for _, byStone in pairs(megas) do
  for stoneId in pairs(byStone) do
    local record = items[stoneId]
    T.check(record ~= nil, stoneId .. " became an item")
    T.check(record and record.index ~= nil, stoneId .. " got a bag index")
    if record and record.index then
      T.check(record.index >= 98 and record.index <= 255,
        stoneId .. "'s index (" .. tostring(record.index) .. ") is in the free 98..255 range")
      T.check(seenIndex[record.index] == nil,
        stoneId .. "'s index does not collide with another stone's")
      seenIndex[record.index] = stoneId
    end
  end
end

-- A stone with no entry in data/stones.lua must not be registered at all --
-- silently shipping an index-less item is exactly what a save cannot hold.
local megasWithGap = { GENGAR = { GENGARITE = "gengar-mega" },
                        MISSINGNO = { MISSINGNOITE = "missingno-mega" } }
local partialIndices = { GENGARITE = 103 }
local itemsWithGap = Stone.items(megasWithGap, partialIndices)
T.check(itemsWithGap["GENGARITE"] ~= nil, "a stone with an index is still registered")
T.check(itemsWithGap["MISSINGNOITE"] == nil,
  "a stone missing from data/stones.lua is left out of items() entirely")

-- Re-stamping with a different stone replaces rather than accumulates.
local swap = { species = "CHARIZARD" }
use({ data = DATA, target = swap })
Stone.effectFor(megas, "CHARIZARDITE_Y")({ data = DATA, target = swap })
T.eq(E.stoneOf(swap), "CHARIZARDITE_Y", "a second stone replaces the first")

T.finish("battle_forms_stone")
