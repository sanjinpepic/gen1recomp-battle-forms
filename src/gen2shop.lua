-- Stocks Gold's own mart shelves the way src/shop.lua stocks Gen 1's, for the
-- one family this mod can prove end to end there: persistent held-item
-- forms.  Nothing here sells a mega stone, an orb or a crystal on Gold --
-- src/shop.lua's other eleven shelves stay Gen 1 only until each one's own
-- martId is read the same way these two were.
--
-- WHY text_pointers CANNOT DO THIS.  Gen 2 has no home for it at all
-- (game/src/mods/Schemas.lua's R.GEN2.text_pointers = false), so a patch
-- there is dropped and reported rather than rerouted -- src/shop.lua's own
-- `mod.content.text_pointers:patch("CeladonMart4F", ...)` approach never
-- reaches a Gold clerk.  map_scripts has the identical gap.  Gold's real
-- stock lives in a raw, unregistered game.data.gen2Marts
-- (data/generated/marts.lua): RomExtractorGen2.lua:3759-3802's extractMarts
-- writes `lists` as a bare 1-based array in ROM order and nothing else --
-- no map, no clerk, no name -- because Marts is a same-bank pointer table
-- indexed purely by position (constants/mart_constants.asm's MART_* enum,
-- not part of this checkout).
--
-- WHERE THE TWO MARTIDS BELOW ACTUALLY CAME FROM.  Not pokecrystal's own
-- mart_constants.asm -- that file ships nowhere in this repo -- but a live
-- ROM import, cross-checked two ways.  A real Gold cache's
-- data/generated/maps.lua names CELADON_DEPT_STORE_4F and
-- INDIGO_PLATEAU_POKECENTER_1F, each with an object whose sprite is
-- SPRITE_CLERK and carries its own scriptKey; that key's row in
-- data/generated/scripts.lua decodes to `opentext / pokemart 0, <id> /
-- closetext / end` -- a `pokemart` opcode (src/script/gen2/Opcodes.lua's
-- $93, size 3) whose second and third bytes are the mart id, little-endian
-- (src/script/gen2/Vm.lua:745-748: `dialog, lo, hi`).  Celadon's clerk reads
-- id 26, Indigo Plateau's reads 32.  Cross-checked against that same cache's
-- own data/generated/marts.lua: list 27 (id 26 + 1, MartMenu.inventory's own
-- 1-based indexing) is POKé DOLL / LOVELY MAIL / SURF MAIL, and list 33 (id
-- 32 + 1) is ULTRA BALL / MAX REPEL / HYPER POTION / MAX POTION / FULL
-- RESTORE / REVIVE / FULL HEAL -- both exactly the real games' own Celadon
-- 4F and Indigo Plateau Pokémon Center shelves, not a guess dressed up as
-- one.  A structural ROM fact rather than a save-dependent one: the mart
-- table is compiled into the cart's own code, the same way NUM_MARTS = 34
-- already is in MartMenu.lua and in the extractor.
--
-- THE SEAM.  With no registry to patch, the shelf function is the seam:
-- MartMenu.inventory(marts, martId) is what every dialog kind's
-- buildEntries() already calls through (game/src/ui/gen2/MartMenu.lua
-- :334-351, :424) -- the file's own header names it the extension point for
-- exactly this reason.  So this wraps THAT function rather than the map
-- data, wrap-and-delegate, guarded by MartMenu._battleFormsMartPatched the
-- way every other engine_internals patch in this mod is (src/gen2forms.lua,
-- src/gen2formview.lua, src/menu.lua, src/boxmark.lua, src/formview.lua):
-- a second load wraps nothing, and a third-party mod's own wrap over the
-- same function -- installed before or after this one -- still runs.  Extra
-- items are appended after whatever the vanilla (or a prior mod's own) list
-- already held, each only once, and the vanilla list itself is never
-- mutated in place -- a fresh table comes back instead, the same discipline
-- src/gen2forms.lua's speciesDef wrap keeps.
local M = {}

local CELADON_4F_MART_ID = 26
local INDIGO_PLATEAU_MART_ID = 32

-- ids sorted the way src/shop.lua's shelf() orders a byteless entry: by its
-- own bag byte where it has one, alphabetically among the byteless (`false`
-- in indices, see data/plates.lua and data/memories.lua) entries after every
-- real byte.  Gold's own shelf gains nothing from matching Gen 1's exact
-- order, but a stable, reproducible one across runs is worth keeping for the
-- same reason shop.lua keeps one.
local function sortedIds(indices)
  local list = {}
  for itemId in pairs(indices or {}) do list[#list + 1] = itemId end
  table.sort(list, function(a, b)
    local ia, ib = indices[a], indices[b]
    if ia == false or ib == false then
      if ia == ib then return a < b end
      return ia ~= false
    end
    return ia < ib
  end)
  return list
end

-- celadonIndices: data/appliances.lua, the one persistent-form family Gen 1
-- sells at CeladonMart4F.  indigoIndices: every other persistent-form family
-- (data/heldforms.lua, data/plates.lua, data/memories.lua, data/drives.lua),
-- the ones Gen 1 sells at the Indigo Plateau lobby counter -- main.lua merges
-- those four into one table before calling this, the same way it merges them
-- for src/persistent.lua's own M.install.
function M.install(mod, celadonIndices, indigoIndices)
  local ok, MartMenu = pcall(require, "src.ui.gen2.MartMenu")
  if not ok or type(MartMenu) ~= "table" then
    if mod and mod.log then
      mod.log:error("battle_forms: src.ui.gen2.MartMenu is unavailable -- "
        .. "persistent-form items will not be sold on Gold")
    end
    return false
  end
  if MartMenu._battleFormsMartPatched then return true end
  if type(MartMenu.inventory) ~= "function" then
    if mod and mod.log then
      mod.log:error("battle_forms: src.ui.gen2.MartMenu.inventory has "
        .. "changed shape -- persistent-form items will not be sold on Gold")
    end
    return false
  end

  local shelves = {
    [CELADON_4F_MART_ID] = sortedIds(celadonIndices),
    [INDIGO_PLATEAU_MART_ID] = sortedIds(indigoIndices),
  }

  local vanillaInventory = MartMenu.inventory
  MartMenu._battleFormsMartPatched = true
  MartMenu.inventory = function(marts, martId)
    local list = vanillaInventory(marts, martId)
    local extra = shelves[martId or 0]
    if not extra or #extra == 0 then return list end
    local out, seen = {}, {}
    for _, id in ipairs(list) do
      out[#out + 1] = id
      seen[id] = true
    end
    for _, id in ipairs(extra) do
      if not seen[id] then
        out[#out + 1] = id
        seen[id] = true
      end
    end
    return out
  end
  return true
end

return M
