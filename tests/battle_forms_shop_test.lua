-- text_pointers is a "deep" registry: a list inside a patch concatenates
-- onto the base list rather than replacing it (mod_registry_tests.lua pins
-- this down generically). Exercising that through the real Registry, rather
-- than just recording the raw patch call, is the only way to prove the
-- floor's original stock actually survives the merge.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Shop = dofile(MOD .. "/src/shop.lua")
local indices = dofile(MOD .. "/data/stones.lua")

local Registry = require("src.mods.Registry")
local Schemas = require("src.mods.Schemas")

-- The real CeladonMart4F clerk entry (data/generated/text_pointers.lua),
-- trimmed to the fields shop.lua reads and writes.
local VANILLA_STOCK = { "POKE_DOLL", "FIRE_STONE", "THUNDER_STONE", "WATER_STONE", "LEAF_STONE" }
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

Shop.install(mod, indices)

local mart = reg:get("CeladonMart4F").TEXT_CELADONMART4F_CLERK.mart
T.check(mart ~= nil, "the clerk still has a mart list at all")

local function sells(id)
  for _, entry in ipairs(mart) do
    if entry == id then return true end
  end
  return false
end

for _, id in ipairs(VANILLA_STOCK) do
  T.check(sells(id), "the floor still sells " .. id)
end

for stoneId in pairs(indices) do
  T.check(sells(stoneId), stoneId .. " is on the shelf")
end

T.eq(#mart, #VANILLA_STOCK + 6,
  "only the original stock plus exactly the six stones ends up on the shelf")

-- The base table itself is never touched -- a second mod patching the same
-- floor must see its own stones, not ours baked into what it thinks is vanilla.
T.eq(#base.CeladonMart4F.TEXT_CELADONMART4F_CLERK.mart, #VANILLA_STOCK,
  "installing never mutates the base mart list")

T.finish("battle_forms_shop")
