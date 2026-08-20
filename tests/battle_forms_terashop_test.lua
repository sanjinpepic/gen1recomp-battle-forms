-- Spending shards, and reading a Tera type back.
--
-- The assertions that matter here are all about the two ways a player can lose
-- something they cannot get back: paying and receiving nothing, and paying for
-- something they already had.  Everything else is text.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Shards = dofile(MOD .. "/src/terashards.lua")
local TeraType = dofile(MOD .. "/src/teratype.lua")
local Shop = dofile(MOD .. "/src/terashop.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")

Shop.bind({ teratype = TeraType, terashards = Shards, keyitems = KeyItems })

local data = {
  type_chart = { types = { FIRE = { name = "FIRE" }, WATER = { name = "WATER" },
                           FLYING = { name = "FLYING" },
                           PSYCHIC_TYPE = { name = "PSYCHIC" } } },
  pokemon = { CHARIZARD = { types = { "FIRE", "FLYING" } } },
}

local function charizard()
  return { species = "CHARIZARD", nickname = "ZARD",
           dvs = { attack = 9, defense = 4, speed = 15, special = 2 } }
end

local function saveWith(counts)
  local inv, order = {}, {}
  for typeId, n in pairs(counts or {}) do
    local id = Shards.idFor(typeId)
    inv[id] = n
    order[#order + 1] = id
  end
  return { inventory = inv, bagOrder = order }
end

-- --- counting is the bag, not a ledger of our own -------------------------
local save = saveWith({ WATER = 50, FIRE = 3 })
T.eq(Shards.count(save, "WATER"), 50, "the bag is the shard ledger")
T.eq(Shards.count(save, "FIRE"), 3, "and counts each type separately")
T.eq(Shards.count(save, "GRASS"), 0, "a type never bought counts zero")
T.same(Shards.affordable(save, { "WATER", "FIRE", "GRASS" }),
  { "WATER" }, "only the piles at or over the cost are affordable")

-- --- too few shards takes nothing ----------------------------------------
Shop.onSaveReady({ save = save })
local mon = charizard()
local before = TeraType.of(data, mon)
local ok, text = Shop.change(data, mon, "FIRE")
T.eq(ok, false, "three shards do not buy a fifty-shard change")
T.eq(Shards.count(save, "FIRE"), 3, "and the three are still in the bag")
T.eq(mon[TeraType.STAMP], nil, "and nothing was written to the Pokemon")
T.eq(TeraType.of(data, mon), before, "so its Tera type is what it was")
T.check(text[2]:find("3", 1, true) ~= nil,
  "the refusal says how many the player actually has")

-- --- enough shards buys the change, once ---------------------------------
local ok2 = Shop.change(data, mon, "WATER")
T.eq(ok2, true, "fifty shards buy the change")
T.eq(mon[TeraType.STAMP], "WATER", "the Pokemon carries the new type")
T.eq(TeraType.of(data, mon), "WATER", "and reads back as that type")
T.eq(Shards.count(save, "WATER"), 0, "the fifty are gone")
for _, id in ipairs(save.bagOrder) do
  T.check(id ~= Shards.idFor("WATER"),
    "an emptied shard pile leaves the bag order too, rather than lingering "
      .. "as a zero row")
end

-- --- paying twice for the same type is refused ---------------------------
-- The single worst outcome available here: fifty shards for a change that
-- changes nothing.  Refused rather than charged.
local save2 = saveWith({ WATER = 50 })
Shop.onSaveReady({ save = save2 })
local ok3, text3 = Shop.change(data, mon, "WATER")
T.eq(ok3, false, "a Pokemon already of that Tera type is refused")
T.eq(Shards.count(save2, "WATER"), 50, "and keeps the player's fifty shards")
T.check(text3[2]:find("already", 1, true) ~= nil, "and says why")

-- The same refusal has to fire for a DERIVED type, not just a stamped one --
-- otherwise a player pays fifty shards to be told nothing changed.
local fresh = charizard()
local derived = TeraType.of(data, fresh)
local save3 = saveWith({ [derived] = 50 })
Shop.onSaveReady({ save = save3 })
local ok4 = Shop.change(data, fresh, derived)
T.eq(ok4, false,
  "buying the type a Pokemon already derives is refused, not charged")
T.eq(Shards.count(save3, derived), 50, "and costs nothing")

-- --- spend is all-or-nothing ---------------------------------------------
local partial = saveWith({ FIRE = 49 })
T.eq(Shards.spend(partial, "FIRE", 50), false, "49 cannot pay 50")
T.eq(Shards.count(partial, "FIRE"), 49, "and none of the 49 are taken")

-- --- with no save there is nothing to count ------------------------------
Shop.onSaveReady({ save = nil })
local ok5 = Shop.change(data, charizard(), "WATER")
T.eq(ok5, false, "with no live save the change refuses rather than guessing")

-- --- the Orb reads the type back ------------------------------------------
Shop.onSaveReady({ save = saveWith({}) })
local read, readText = Shop.describe(data, mon)
T.eq(read, false, "reading is not a use -- the Orb is never consumed")
T.check(readText[2]:find("WATER", 1, true) ~= nil,
  "and it names the Pokemon's actual Tera type")

-- PSYCHIC_TYPE prints as PSYCHIC, the exception every type-naming file carries.
local psychic = charizard()
psychic[TeraType.STAMP] = "PSYCHIC_TYPE"
local _, psyText = Shop.describe(data, psychic)
T.check(psyText[2]:find("PSYCHIC", 1, true) ~= nil
    and psyText[2]:find("PSYCHIC_TYPE", 1, true) == nil,
  "PSYCHIC_TYPE is printed as PSYCHIC, never as its engine id")

-- A stamp the running chart cannot resolve says so rather than going quiet.
local orphan = charizard()
orphan[TeraType.STAMP] = "FAIRY"
local _, orphanText = Shop.describe(data, orphan)
T.check(orphanText[2]:find("can't be read", 1, true) ~= nil,
  "a Tera type this chart has no record for is refused out loud")

-- --- shard ids round-trip -------------------------------------------------
T.eq(Shards.typeFor(Shards.idFor("PSYCHIC_TYPE")), "PSYCHIC_TYPE",
  "a shard id names its type, including the one with an underscore in it")
T.eq(Shards.typeFor("POTION"), nil, "and nothing else is mistaken for one")
T.eq(Shards.typeFor(nil), nil, "nor is nothing")

T.finish("battle_forms_terashop")
