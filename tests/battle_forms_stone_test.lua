package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Stone = dofile(MOD .. "/src/stone.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local raw = dofile(MOD .. "/data/megas.lua")
-- The whole roster: what a stone IS never depends on the MEGA EVOLUTIONS
-- option, so every check here reads the ALL selection.
local megas = Megaset.select(raw, Megaset.ALL)
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

-- The reverse direction: every index data/stones.lua hands out must belong to
-- a stone data/megas.lua actually names.  Without this, a stone could be
-- retired from megas.lua and its permanent index would sit there forever,
-- unnoticed, still sellable and still doing nothing.
local namedStones = {}
for _, byStone in pairs(megas) do
  for stoneId in pairs(byStone) do
    namedStones[stoneId] = true
  end
end
for stoneId in pairs(indices) do
  T.check(namedStones[stoneId], stoneId
    .. " has a bag index in data/stones.lua but is not named in data/megas.lua")
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

-- ------- registration ignores the option -----------------------------

-- The save-safety rule.  A player can be holding any stone at the moment the
-- MEGA EVOLUTIONS option changes, and an item id with no record behind it is
-- a bag byte the save can no longer resolve -- so every stone is registered
-- under both settings, and only what the stone DOES narrows.
local function recorder()
  local seen = { items = {}, effects = {}, errors = {} }
  local mod = {
    log = { error = function(_, fmt, ...)
      seen.errors[#seen.errors + 1] = string.format(fmt, ...)
    end },
    content = {
      items = { register = function(_, id, record) seen.items[id] = record end },
      item_effects = { register = function(_, id, record) seen.effects[id] = record end },
    },
  }
  return seen, mod
end

local STARMIE_DATA = { pokemon = { STARMIE = { name = "STARMIE" } } }

for _, setting in ipairs({ Megaset.OFFICIAL, Megaset.ALL }) do
  local seen, fakeMod = recorder()
  Stone.install(fakeMod, megas, Megaset.select(raw, setting), indices)

  local registered = 0
  for _, byStone in pairs(megas) do
    for stoneId in pairs(byStone) do
      registered = registered + 1
      T.check(seen.items[stoneId] ~= nil,
        stoneId .. " is registered as an item under " .. setting)
      T.check(seen.effects[stoneId] ~= nil,
        stoneId .. " keeps its item effect under " .. setting)
    end
  end
  T.eq(registered, 96, "every wired stone was checked under " .. setting)
  T.eq(#seen.errors, 0, "no stone reports a missing bag index under " .. setting)

  -- Starmie's mega is one the real games never had, so its stone is inert
  -- under OFFICIAL -- inert, not absent, and it fails the way a stone used on
  -- the wrong species fails rather than raising.
  local target = { species = "STARMIE" }
  T.eq(seen.effects["STARMIITE"].use({ data = STARMIE_DATA, target = target }),
    setting == Megaset.ALL and "kept" or "failed",
    "the registered STARMIITE effect follows the " .. setting .. " setting")
  T.eq(E.stoneOf(target), setting == Megaset.ALL and "STARMIITE" or nil,
    "a refused use under " .. setting .. " stamps nothing")
end

T.finish("battle_forms_stone")
