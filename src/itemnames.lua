-- The display name for an item this mod registers, from the National Dex.
--
-- Every item here was named by machine: `itemId:gsub("_", " ")` turns
-- NORMALIUM_Z into "NORMALIUM Z", which is legible and wrong -- the item is
-- called "Normalium Z". Five call sites do it, across roughly two hundred
-- items, and the dex now carries the real name for every one that exists.
--
-- WHY A TRANSLATION AND NOT A RENAME. The obvious fix is to rename this mod's
-- ids to match PokeAPI's. It would corrupt every existing save. An item id is
-- not a label here: `mon[eligibility.STAMP] = itemId` writes that exact string
-- onto a Pokemon and persists it, so a Pokemon holding NORMALIUM_Z would stop
-- matching a renamed NORMALIUMZHELD -- still stamped, still saved, no longer
-- pointing at anything. data/crystals.lua already says this about the bag
-- BYTES ("changing an index silently turns every crystal already in a player's
-- bag into a different item"); the id string has the same property and had no
-- comment saying so. Translating on the way out costs a wrong name at worst.
--
-- WHY RULES RATHER THAN A TABLE OF TWO HUNDRED ROWS. PokeAPI splits one
-- physical item into several records by FUNCTION, with a suffix, and the base
-- slug may or may not exist on its own:
--
--   electrium-z--held / --bag        the crystal, and the same crystal in a bag
--   n-solarizer--merge / --split     one item, two directions
--   fire-tera-shard                  the words in the other order
--
-- Three shapes cover almost everything. What is left over is genuinely left
-- over, not a missing rule -- see below.
--
-- WHAT HAS NO NAME TO BORROW, and must keep the derived one: twenty-nine of
-- this mod's ninety-six mega stones are for megas that do not exist in the real
-- games (Baxcaliburite, Glimmoraite, Barbaraclite and friends), the byteless
-- TMs are this project's own, and Stellar has no Tera Shard. An invented item
-- has no catalogue entry by definition, and asking for one is not a failure.
local M = {}

M.DEX_MOD = "national_dex"

-- The API version that first answered itemById. Checked rather than assumed:
-- this mod's own dependency floor is lower, so a player can genuinely be
-- running a dex that predates the catalogue.
M.MIN_API = 5

--- The dex's exports, or nil when it is absent or too old to ask.
function M.dexFor(mod)
  if not (mod and mod.find) then return nil end
  local ok, peer = pcall(mod.find, mod, M.DEX_MOD)
  if not ok or not peer then return nil end
  local exports = peer.exports
  if type(exports) ~= "table" then return nil end
  if type(exports.itemById) ~= "function" then return nil end
  if (tonumber(exports.apiVersion) or 0) < M.MIN_API then return nil end
  return exports
end

local function strip(text)
  return (tostring(text):upper():gsub("[^A-Z0-9]", ""))
end

--- Every id worth trying for one of this mod's items, cheapest first.
---
--- Ordered so the exact match always wins: a suffix rule that fired ahead of it
--- could answer with the bag form of an item whose held form is the real one,
--- and both exist.
function M.candidates(itemId)
  local bare = strip(itemId)
  local out = { bare, bare .. "HELD", bare .. "MERGE" }
  -- TERA_SHARD_FIRE -> FIRETERASHARD. PokeAPI puts the type first; this mod
  -- puts it last, because its own ids group by prefix so the shop shelf sorts
  -- them together.
  local suffix = tostring(itemId):match("^TERA_SHARD_(.+)$")
  if suffix then out[#out + 1] = strip(suffix) .. "TERASHARD" end
  return out
end

--- The catalogue's name for an item, or nil.
---
--- nil is a real answer and the caller must keep its own name for it: an
--- invented item has nothing to look up, and a lookup that invented something
--- anyway would be worse than the machine-derived name it replaced.
function M.nameFor(dex, itemId)
  if not (dex and itemId) then return nil end
  for _, candidate in ipairs(M.candidates(itemId)) do
    local ok, record = pcall(dex.itemById, candidate)
    if ok and type(record) == "table" and type(record.name) == "string"
      and record.name ~= "" then
      return record.name
    end
  end
  return nil
end

--- A resolver bound to one mod, for the five call sites that build item
--- records. Answers the derived name when the dex has nothing, so a caller
--- never has to hold both branches.
---
--- The dex handle is looked up ONCE per resolver rather than per item: two
--- hundred registrations happen in a row at load, and mod:find on each of them
--- is two hundred lookups for one answer that cannot change in between.
function M.resolver(mod)
  local dex = M.dexFor(mod)
  return function(itemId)
    local derived = tostring(itemId):gsub("_", " ")
    if not dex then return derived end
    return M.nameFor(dex, itemId) or derived
  end
end

--- Points every module that formats an item name at the dex.
---
--- One resolver, shared: the dex handle is looked up once rather than per
--- item, because two hundred registrations happen in a row at load and
--- mod:find on each of them is two hundred lookups for an answer that cannot
--- change in between.
---
--- A module that is not loaded is skipped rather than being an error -- the
--- set of modules registering items is a fact about this mod's own wiring, and
--- a caller should not have to keep a second copy of it in step.
function M.install(mod, modules)
  local resolve = M.resolver(mod)
  local pointed = 0
  for _, module in pairs(modules or {}) do
    if type(module) == "table" and type(module.displayName) == "function" then
      module.displayName = resolve
      pointed = pointed + 1
    end
  end
  return pointed, resolve
end

return M
