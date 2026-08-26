-- Item display names, resolved through the National Dex against the REAL
-- catalogue rather than a fixture.
--
-- Two promises, and the second matters more than the first.
--
-- The first is that a real item gets its real name: NORMALIUM_Z is called
-- "Normalium Z", not "NORMALIUM Z", and the same for ninety-odd mega stones.
--
-- The second is that an INVENTED item keeps the machine-derived one. Twenty-
-- nine of this mod's mega stones are for megas that do not exist in the games,
-- so the catalogue has no entry and never will. A resolver that answered
-- anything at all for those would be worse than the name it replaced, because
-- a wrong name that looks official is harder to spot than a shouty one.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Names = dofile(MOD .. "/src/itemnames.lua")

-- The real catalogue, read the way the dex's own API reads it, so this suite
-- fails when the payload changes rather than when a fixture goes stale.
local DEX = MOD .. "/../national_dex_mod/data/items/generated/api"
local index = dofile(DEX .. "/index.lua")
local shards = {}
local function itemById(id)
  local number = index[id]
  if not number then return nil end
  shards[number] = shards[number] or dofile(string.format("%s/%03d.lua", DEX, number))
  return shards[number][id]
end
local dex = { apiVersion = 5, itemById = itemById }

-- --- the candidate rules ----------------------------------------------------
-- Exact first, always: a suffix rule that fired ahead of it could answer with
-- the BAG form of an item whose held form is the real one, and both exist.
local c = Names.candidates("ELECTRIUM_Z")
T.eq(c[1], "ELECTRIUMZ", "the exact id is tried first")
T.eq(c[2], "ELECTRIUMZHELD", "then the held form")
T.eq(c[3], "ELECTRIUMZMERGE", "then the merge form")
local shard = Names.candidates("TERA_SHARD_FIRE")
T.eq(shard[#shard], "FIRETERASHARD",
  "and a Tera Shard is tried with the words in PokeAPI's order")
T.eq(#Names.candidates("LEFTOVERS"), 3,
  "an id with no special shape gets the three general candidates")

-- --- the real names ---------------------------------------------------------
T.eq(Names.nameFor(dex, "NORMALIUM_Z"), "Normalium Z",
  "a Z-Crystal resolves through the held form")
T.eq(Names.nameFor(dex, "CHARIZARDITE_X"), "Charizardite X",
  "a real mega stone resolves exactly")
T.eq(Names.nameFor(dex, "TERA_SHARD_FIRE"), "Fire Tera Shard",
  "a Tera Shard resolves through the reordered id")
T.eq(Names.nameFor(dex, "DNA_SPLICERS"), "DNA Splicers",
  "and a fuser resolves too")

-- --- every crystal, every real stone ----------------------------------------
local crystals = dofile(MOD .. "/data/crystals.lua")
local unresolved = {}
for key in pairs(crystals) do
  local name = Names.nameFor(dex, key)
  if not name then unresolved[#unresolved + 1] = key end
  -- The whole point of the exercise: the resolved name must not be the shouty
  -- one the fallback would have produced.
  if name and name == tostring(key):gsub("_", " ") then
    unresolved[#unresolved + 1] = key .. " (unchanged)"
  end
end
T.eq(#unresolved, 0, "all 18 Z-Crystals get a real name ("
  .. (#unresolved > 0 and table.concat(unresolved, ", ") or "every one") .. ")")

local stones = dofile(MOD .. "/data/stones.lua")
local resolved, invented = 0, {}
for key in pairs(stones) do
  if Names.nameFor(dex, key) then resolved = resolved + 1
  else invented[#invented + 1] = key end
end
T.check(resolved > 60, "most mega stones resolve to a real name (" .. resolved .. ")")
T.check(#invented > 0, "and the invented ones do not (" .. #invented .. ")")
-- Named rather than merely counted: if a REAL stone ever fell into this bucket
-- it would mean a lookup rule broke, and a bare count would hide it.
local surprising = {}
for _, key in ipairs(invented) do
  -- every invented mega is for a species with no mega in the real games; the
  -- giveaway is that the catalogue has no entry under any candidate at all
  if itemById((tostring(key):upper():gsub("[^A-Z0-9]", ""))) then
    surprising[#surprising + 1] = key
  end
end
T.eq(#surprising, 0, "and none of them is a stone the catalogue actually has ("
  .. (#surprising > 0 and table.concat(surprising, ", ") or "checked") .. ")")

-- --- the fallback -----------------------------------------------------------
-- An invented item has nothing to look up, and that is not a failure.
T.eq(Names.nameFor(dex, "BAXCALIBURITE"), nil,
  "an invented mega stone resolves to nothing")
local resolve = Names.resolver({ find = function() return nil end })
T.eq(resolve("BAXCALIBURITE"), "BAXCALIBURITE",
  "and the resolver hands back the derived name for it")
T.eq(resolve("NORMALIUM_Z"), "NORMALIUM Z",
  "with no dex at all, every name is the derived one -- exactly as before")

-- --- refusing an old dex ----------------------------------------------------
-- itemById arrived at API 5. A dex below that is not a broken dex, it is an
-- older one, and asking it for a catalogue it does not have would answer nil
-- for everything while looking like a lookup failure.
T.eq(Names.dexFor(nil), nil, "no mod handle, no dex")
T.eq(Names.dexFor({ find = function() return nil end }), nil, "no peer, no dex")
T.eq(Names.dexFor({ find = function()
  return { exports = { apiVersion = 4, itemById = function() end } }
end }), nil, "a dex below API 5 is declined rather than asked")
T.check(Names.dexFor({ find = function()
  return { exports = { apiVersion = 5, itemById = function() end } }
end }) ~= nil, "and one at API 5 is accepted")

-- --- install points the modules that need it --------------------------------
-- Every module that formats an item name carries a default; install swaps it.
-- A module that does not is skipped rather than being an error: the set of
-- registrars is a fact about this mod's own wiring, not something a caller
-- should keep a second copy of.
local modules = {
  ["src/stone.lua"] = { displayName = function(id) return id end },
  ["src/keyitems.lua"] = { displayName = function(id) return id end },
  ["src/shop.lua"] = { somethingElse = true },
}
local pointed = Names.install({ find = function() return nil end }, modules)
T.eq(pointed, 2, "only the modules that format a name are pointed at the dex")
T.eq(modules["src/shop.lua"].displayName, nil, "the others are left alone")
T.eq(modules["src/stone.lua"].displayName("NORMALIUM_Z"), "NORMALIUM Z",
  "and with no dex they fall back to the derived name")

-- --- the four registrars really do carry the default ------------------------
-- A test that pointed at modules which no longer have the field would pass
-- while resolving nothing, so the field's presence is checked directly.
for _, name in ipairs({ "fusion", "keyitems", "persistent", "stone" }) do
  local module = dofile(MOD .. "/src/" .. name .. ".lua")
  T.eq(type(module.displayName), "function",
    "src/" .. name .. ".lua carries a displayName for install to replace")
  T.eq(module.displayName("A_B"), "A B",
    "defaulting to the derived name until it is replaced")
end

T.finish("battle_forms_itemnames")
