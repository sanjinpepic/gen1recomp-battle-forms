-- text_pointers is a "deep" registry: a list inside a patch concatenates
-- onto the base list rather than replacing it (mod_registry_tests.lua pins
-- this down generically). Exercising that through the real Registry, rather
-- than just recording the raw patch call, is the only way to prove the
-- floor's original stock actually survives the merge.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Shop = dofile(MOD .. "/src/shop.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local raw = dofile(MOD .. "/data/megas.lua")
local indices = dofile(MOD .. "/data/stones.lua")

local Registry = require("src.mods.Registry")
local Schemas = require("src.mods.Schemas")

-- The real CeladonMart4F clerk entry (data/generated/text_pointers.lua),
-- trimmed to the fields shop.lua reads and writes.
local VANILLA_STOCK = { "POKE_DOLL", "FIRE_STONE", "THUNDER_STONE", "WATER_STONE", "LEAF_STONE" }

-- One floor per setting, each with its own base table: the point of the last
-- check in here is that the base survives untouched, and a shared one would
-- carry the first install's stones into the second.
local function stock(setting)
  local base = {
    CeladonMart4F = {
      TEXT_CELADONMART4F_CLERK = {
        label = "CeladonMart4FClerkText",
        mart = { "POKE_DOLL", "FIRE_STONE", "THUNDER_STONE", "WATER_STONE", "LEAF_STONE" },
      },
    },
  }

  local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
  reg.base = function() return base end

  local mod = { content = { text_pointers = {
    patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
  } } }

  Shop.install(mod, indices, Megaset.stoneIds(Megaset.select(raw, setting)))

  return reg:get("CeladonMart4F").TEXT_CELADONMART4F_CLERK.mart, base
end

local function sells(mart, id)
  for _, entry in ipairs(mart) do
    if entry == id then return true end
  end
  return false
end

-- ------- ALL: the whole roster is buyable ----------------------------

local mart, base = stock(Megaset.ALL)
T.check(mart ~= nil, "the clerk still has a mart list at all")

for _, id in ipairs(VANILLA_STOCK) do
  T.check(sells(mart, id), "the floor still sells " .. id)
end

-- RAYQUAZITE keeps a permanent bag byte in data/stones.lua (see that file's
-- own header) but is withdrawn from data/megas.lua as of 0.30.0, so the
-- shelf -- stocked from megaset.stoneIds(megas), which reads the pairing
-- table and not the byte table -- must not offer it under any setting.
local RETIRED = { RAYQUAZITE = true }

for stoneId in pairs(indices) do
  if RETIRED[stoneId] then
    T.check(not sells(mart, stoneId),
      stoneId .. " is withdrawn and must not be on the shelf")
  else
    T.check(sells(mart, stoneId), stoneId .. " is on the shelf")
  end
end

local stoneCount = 0
for stoneId in pairs(indices) do
  if not RETIRED[stoneId] then stoneCount = stoneCount + 1 end
end

T.eq(#mart, #VANILLA_STOCK + stoneCount,
  "only the original stock plus exactly the wired, non-retired stones ends "
    .. "up on the shelf")

-- The base table itself is never touched -- a second mod patching the same
-- floor must see its own stones, not ours baked into what it thinks is vanilla.
T.eq(#base.CeladonMart4F.TEXT_CELADONMART4F_CLERK.mart, #VANILLA_STOCK,
  "installing never mutates the base mart list")

-- ------- OFFICIAL: only the real games' stones are buyable -----------

local officialMart = stock(Megaset.OFFICIAL)
local officialStones = Megaset.stoneIds(Megaset.select(raw, Megaset.OFFICIAL))

for _, id in ipairs(VANILLA_STOCK) do
  T.check(sells(officialMart, id),
    "the floor still sells " .. id .. " under OFFICIAL")
end

local offeredCount = 0
for stoneId in pairs(indices) do
  if officialStones[stoneId] then
    offeredCount = offeredCount + 1
    T.check(sells(officialMart, stoneId),
      stoneId .. " is on the shelf under OFFICIAL")
  else
    T.check(not sells(officialMart, stoneId),
      stoneId .. " is off the shelf under OFFICIAL")
  end
end

T.eq(offeredCount, 47, "the shelf offers the 47 official stones under OFFICIAL")
T.eq(#officialMart, #VANILLA_STOCK + 47,
  "and nothing else -- the extended stones are not quietly still on it")

T.finish("battle_forms_shop")
