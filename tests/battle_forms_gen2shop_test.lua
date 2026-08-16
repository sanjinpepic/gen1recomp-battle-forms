-- Gen 2's equivalent of battle_forms_shop_test.lua: proving persistent-form
-- items reach a Gold shelf.
--
-- text_pointers has no Gen 2 home (Schemas.lua's GEN2.text_pointers = false)
-- and neither does map_scripts, so src/shop.lua's registry patch cannot touch
-- a Gold mart at all, and data/generated/marts.lua itself carries no map or
-- clerk name -- RomExtractorGen2.lua's extractMarts writes `lists` as a bare
-- 1-based array in ROM order, nothing else. The two martIds this module
-- targets were read out of a live ROM import rather than guessed: see
-- src/gen2shop.lua's own header for the file:line evidence trail.
--
-- With no registry to patch, MartMenu.inventory(marts, martId) is the shelf
-- itself -- every dialog kind's buildEntries() already calls through it
-- (game/src/ui/gen2/MartMenu.lua:334-351,424) -- so this proves the wrap the
-- same way battle_forms_gen2forms_test.lua proves the Battle.speciesDef one:
-- against the real engine class, wrap-and-delegate, idempotent, refuses out
-- loud.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local CELADON_4F_MART_ID = 26
local INDIGO_PLATEAU_MART_ID = 32
local OTHER_MART_ID = 4 -- Violet City, unrelated to either shelf

local function freshMartMenu()
  package.loaded["src.ui.gen2.MartMenu"] = nil
  return dofile(MOD .. "/src/gen2shop.lua"), require("src.ui.gen2.MartMenu")
end

local function has(list, id)
  for _, entry in ipairs(list) do
    if entry == id then return true end
  end
  return false
end

local fakeMod = { log = { error = function() end } }

-- Two rows each -- one with a real bag byte, one byteless (`false`, matching
-- data/plates.lua and data/memories.lua's own shape) -- so both of shop.lua's
-- shelf() cases are exercised here too.
local CELADON_INDICES = { ROTOM_FAN = 210 }
local INDIGO_INDICES = { GRISEOUS_ORB = 211, SPOOKY_PLATE = false }

-- --- basic install: both shelves gain exactly their own items -------------

local Shop, MartMenu = freshMartMenu()
T.eq(Shop.install(fakeMod, CELADON_INDICES, INDIGO_INDICES), true,
  "install succeeds against the real engine")

local vanillaCeladon = { "POKE_DOLL", "LOVELY_MAIL", "SURF_MAIL" }
local vanillaIndigo = { "ULTRA_BALL", "MAX_REPEL", "HYPER_POTION" }
local marts = { lists = {} }
marts.lists[CELADON_4F_MART_ID + 1] = { vanillaCeladon[1], vanillaCeladon[2],
  vanillaCeladon[3] }
marts.lists[INDIGO_PLATEAU_MART_ID + 1] = { vanillaIndigo[1], vanillaIndigo[2],
  vanillaIndigo[3] }
marts.lists[OTHER_MART_ID + 1] = { "POTION", "ANTIDOTE" }

local celadonShelf = MartMenu.inventory(marts, CELADON_4F_MART_ID)
for _, id in ipairs(vanillaCeladon) do
  T.check(has(celadonShelf, id), "Celadon 4F keeps selling " .. id)
end
T.check(has(celadonShelf, "ROTOM_FAN"), "Celadon 4F now sells ROTOM_FAN")
T.eq(#celadonShelf, #vanillaCeladon + 1,
  "Celadon 4F gained exactly the one appended item")

local indigoShelf = MartMenu.inventory(marts, INDIGO_PLATEAU_MART_ID)
for _, id in ipairs(vanillaIndigo) do
  T.check(has(indigoShelf, id), "Indigo Plateau keeps selling " .. id)
end
T.check(has(indigoShelf, "GRISEOUS_ORB"),
  "Indigo Plateau now sells the real-byte GRISEOUS_ORB")
T.check(has(indigoShelf, "SPOOKY_PLATE"),
  "Indigo Plateau now sells the byteless SPOOKY_PLATE too -- shop.lua's own "
    .. "`false` sentinel names a real item id, not a missing one")
T.eq(#indigoShelf, #vanillaIndigo + 2,
  "Indigo Plateau gained exactly its two appended items")

-- --- an unrelated mart is untouched ----------------------------------------

local otherShelf = MartMenu.inventory(marts, OTHER_MART_ID)
T.same(otherShelf, { "POTION", "ANTIDOTE" },
  "a mart id that is neither shelf is returned exactly as vanilla built it")

-- --- no duplication: an id already on the shelf is never appended twice ---

local dupeMarts = { lists = {} }
dupeMarts.lists[INDIGO_PLATEAU_MART_ID + 1] = { "GRISEOUS_ORB" }
local dupeShelf = MartMenu.inventory(dupeMarts, INDIGO_PLATEAU_MART_ID)
T.eq(#dupeShelf, 2, "GRISEOUS_ORB already on the shelf is not duplicated, "
  .. "only SPOOKY_PLATE is appended")

-- --- the vanilla list itself is never mutated in place ---------------------

local sourceList = { "POTION" }
local sourceMarts = { lists = { [INDIGO_PLATEAU_MART_ID + 1] = sourceList } }
MartMenu.inventory(sourceMarts, INDIGO_PLATEAU_MART_ID)
T.eq(#sourceList, 1,
  "the underlying marts.lua list is never mutated -- a fresh table is "
    .. "returned instead, the way src/gen2forms.lua's speciesDef wrap "
    .. "hands back a copy rather than editing the original")

-- --- wrap-and-delegate: a wrap installed before this one still runs -------

package.loaded["src.ui.gen2.MartMenu"] = nil
local ComposeMartMenu = require("src.ui.gen2.MartMenu")
local vanillaForCompose = ComposeMartMenu.inventory
local priorModCalls = 0
ComposeMartMenu.inventory = function(marts2, martId2)
  priorModCalls = priorModCalls + 1
  local list = vanillaForCompose(marts2, martId2)
  local out = {}
  for _, id in ipairs(list) do out[#out + 1] = id end
  out[#out + 1] = "PRIOR_MOD_ITEM"
  return out
end

local ShopCompose = dofile(MOD .. "/src/gen2shop.lua")
T.eq(ShopCompose.install(fakeMod, CELADON_INDICES, INDIGO_INDICES), true,
  "install succeeds even with a prior wrap already in place")

local composedShelf = ComposeMartMenu.inventory(marts, INDIGO_PLATEAU_MART_ID)
T.check(priorModCalls > 0, "the prior wrap ran -- delegate, not replace")
T.check(has(composedShelf, "PRIOR_MOD_ITEM"),
  "a third-party mod's own append survives underneath this one")
T.check(has(composedShelf, "GRISEOUS_ORB"),
  "and this mod's own items still land on top of it")

-- --- idempotent: a second install wraps nothing -----------------------

local beforeSecondInstall = ComposeMartMenu.inventory
T.eq(ShopCompose.install(fakeMod, CELADON_INDICES, INDIGO_INDICES), true,
  "a second install call still reports success")
T.eq(ComposeMartMenu.inventory, beforeSecondInstall,
  "installing a second time wraps nothing -- same function, not a new layer")

-- --- refuses out loud when the engine module cannot be required -----------

package.loaded["src.ui.gen2.MartMenu"] = nil
package.preload["src.ui.gen2.MartMenu"] = function()
  error("battle_forms test: forced require failure")
end
local ShopUnavailable = dofile(MOD .. "/src/gen2shop.lua")
local unavailableLog = { errors = {} }
local unavailableMod = { log = { error = function(_, fmt, ...)
  unavailableLog.errors[#unavailableLog.errors + 1] = fmt:format(...)
end } }
T.eq(ShopUnavailable.install(unavailableMod, CELADON_INDICES, INDIGO_INDICES),
  false, "install refuses when the engine module cannot be required")
T.eq(#unavailableLog.errors, 1, "and says so out loud rather than staying silent")
package.preload["src.ui.gen2.MartMenu"] = nil
package.loaded["src.ui.gen2.MartMenu"] = nil

-- --- refuses out loud when MartMenu.inventory has changed shape -----------

package.loaded["src.ui.gen2.MartMenu"] = nil
package.preload["src.ui.gen2.MartMenu"] = function()
  return { inventory = "not a function" }
end
local ShopWrongShape = dofile(MOD .. "/src/gen2shop.lua")
local wrongShapeLog = { errors = {} }
local wrongShapeMod = { log = { error = function(_, fmt, ...)
  wrongShapeLog.errors[#wrongShapeLog.errors + 1] = fmt:format(...)
end } }
T.eq(ShopWrongShape.install(wrongShapeMod, CELADON_INDICES, INDIGO_INDICES),
  false, "install refuses when MartMenu.inventory is not a function")
T.eq(#wrongShapeLog.errors, 1, "and says so out loud rather than staying silent")
package.preload["src.ui.gen2.MartMenu"] = nil
package.loaded["src.ui.gen2.MartMenu"] = nil

-- --- empty/nil indices: install still succeeds, no shelf gains anything ---

local EmptyShop, EmptyMartMenu = freshMartMenu()
T.eq(EmptyShop.install(fakeMod, {}, {}), true,
  "install succeeds with two empty pairing tables")
local emptyMarts = { lists = { [INDIGO_PLATEAU_MART_ID + 1] = { "ULTRA_BALL" } } }
T.same(EmptyMartMenu.inventory(emptyMarts, INDIGO_PLATEAU_MART_ID),
  { "ULTRA_BALL" }, "an empty pairing table appends nothing")

T.finish("battle_forms_gen2shop")
