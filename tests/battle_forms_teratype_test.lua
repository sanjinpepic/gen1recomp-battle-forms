-- A Pokemon's own Tera type, derived rather than stored.
--
-- The properties pinned here are the ones the design rests on, and each would
-- be invisible in play until it had already cost somebody a save:
--
--   STABLE.  The same Pokemon must answer the same type every time it is
--   asked, on every boot.  This is the one that would break silently: the
--   derivation reads a sorted chart list through a modulo, and `pairs` reorders
--   between runs, so an unsorted list would give a Pokemon a different rare
--   type each time the game started.
--
--   ITS OWN.  A single-typed Pokemon always gets the type it has; a dual-type
--   gets one of its two and both really occur.
--
--   RARE, BUT NOT NEVER.  Roughly one in sixteen carries something off its own
--   list.  Asserted as a rate over the whole DV space rather than on one
--   example, because a single mon proves nothing about a distribution.
--
--   THE STAMP WINS.  What the Tera Orb writes overrides the derivation, and a
--   stamp naming a type this game's chart cannot resolve is refused rather
--   than armed.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local TeraType = dofile(MOD .. "/src/teratype.lua")

-- A chart with the modern eighteen, shaped the way the merged registry hands
-- one over: id -> record.  PSYCHIC_TYPE carries the id/name split that exists
-- in the real one, so nothing here can accidentally depend on the two matching.
local TYPE_IDS = { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK",
  "BUG", "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC_TYPE", "ICE",
  "DRAGON", "DARK", "STEEL", "FAIRY" }

local function chartOf(ids)
  local types = {}
  for _, id in ipairs(ids) do
    types[id] = { name = id == "PSYCHIC_TYPE" and "PSYCHIC" or id }
  end
  return types
end

local data = {
  type_chart = { types = chartOf(TYPE_IDS) },
  pokemon = {
    CHARMANDER = { types = { "FIRE" } },
    CHARIZARD = { types = { "FIRE", "FLYING" } },
    BULBASAUR = { types = { "GRASS", "POISON" } },
  },
}

local function mon(species, a, d, s, sp)
  return { species = species, dvs = { attack = a, defense = d, speed = s,
                                      special = sp } }
end

-- --- stable across calls --------------------------------------------------
local subject = mon("CHARIZARD", 9, 4, 15, 2)
local first = TeraType.of(data, subject)
for _ = 1, 25 do
  T.eq(TeraType.of(data, subject), first,
    "the same Pokemon answers the same type every time it is asked")
end

-- The chart list is what a modulo indexes into, so its order is load-bearing.
local order1 = TeraType.chartTypes(data)
local order2 = TeraType.chartTypes({ type_chart = { types = chartOf(TYPE_IDS) } })
T.same(order1, order2, "the chart list is sorted, so it cannot reorder per boot")

-- --- a single-typed Pokemon gets its own type, or the rare one ------------
-- Walked over the whole DV space rather than sampled: 65536 Pokemon is cheap
-- here and a sample could miss the rare branch entirely.
local ownCount, offCount, wrongOwn = 0, 0, 0
for a = 0, 15 do
  for d = 0, 15 do
    for s = 0, 15 do
      for sp = 0, 15 do
        local id, why = TeraType.of(data, mon("CHARMANDER", a, d, s, sp))
        T.check(id ~= nil, "every DV spread yields a type")
        if why == "own" then
          ownCount = ownCount + 1
          if id ~= "FIRE" then wrongOwn = wrongOwn + 1 end
        else
          offCount = offCount + 1
        end
      end
    end
  end
end
T.eq(wrongOwn, 0,
  "a single-typed Pokemon's own-type answer is always the type it actually has")
T.check(offCount > 0, "the rare off-type really occurs")

-- Roughly one in sixteen, allowed to drift: this pins the design intent, not
-- the exact output of the mixing function, which is free to change.
local rate = offCount / (ownCount + offCount)
T.check(rate > 0.03 and rate < 0.11,
  string.format("the off-type rate is about 1 in 16 (measured %.3f)", rate))

-- --- a dual-typed Pokemon uses both of its types --------------------------
local sawFire, sawFlying, foreign = false, false, 0
for a = 0, 15 do
  for d = 0, 15 do
    for s = 0, 15 do
      for sp = 0, 15 do
        local id, why = TeraType.of(data, mon("CHARIZARD", a, d, s, sp))
        if why == "own" then
          if id == "FIRE" then sawFire = true
          elseif id == "FLYING" then sawFlying = true
          else foreign = foreign + 1 end
        end
      end
    end
  end
end
T.check(sawFire, "a Charizard can be Fire")
T.check(sawFlying, "a Charizard can be Flying")
T.eq(foreign, 0, "an own-type answer never names a type the Pokemon lacks")

-- --- species is mixed in --------------------------------------------------
-- Without it every Pokemon sharing a DV spread would answer identically, so a
-- box of perfect-DV Pokemon would all carry one type.  Two different dual-types
-- on identical DVs must be free to disagree; across the whole space they must.
local disagreements = 0
for a = 0, 15 do
  for d = 0, 15 do
    local bulb = TeraType.of(data, mon("BULBASAUR", a, d, 0, 0))
    local char = TeraType.of(data, mon("CHARIZARD", a, d, 0, 0))
    -- Different type lists, so compare the SLOT each landed on rather than the
    -- id: agreeing on "first type" for all 256 spreads is the tell.
    local bulbFirst = bulb == "GRASS"
    local charFirst = char == "FIRE"
    if bulbFirst ~= charFirst then disagreements = disagreements + 1 end
  end
end
T.check(disagreements > 0,
  "two species on identical DVs do not march in lockstep")

-- --- the slice that caught the first implementation ----------------------
-- speed = special = 0 makes the packed DV word a multiple of 256, and the
-- original single-accumulator hash preserved that all the way through, so the
-- low bits ended up a function of the species alone: every Bulbasaur in this
-- slice answered GRASS, all 256 of them.  Pinned as its own case because the
-- whole-space assertions above still passed while it was broken.
local flat = { GRASS = 0, POISON = 0, other = 0 }
for a = 0, 15 do
  for d = 0, 15 do
    local id = TeraType.of(data, mon("BULBASAUR", a, d, 0, 0))
    flat[id] = (flat[id] or 0) + 1
  end
end
T.check(flat.GRASS > 0 and flat.POISON > 0,
  string.format("both of a dual-type's types occur when speed and special are "
    .. "zero (grass %d, poison %d of 256)", flat.GRASS, flat.POISON))

-- --- the stamp overrides the derivation -----------------------------------
local stamped = mon("CHARIZARD", 9, 4, 15, 2)
stamped[TeraType.STAMP] = "DRAGON"
local id, why = TeraType.of(data, stamped)
T.eq(id, "DRAGON", "a stamped Tera type wins over the derived one")
T.eq(why, "stamp", "and says which it was")

-- A stamp written while National Dex was on, read back with it off.  Refused
-- rather than armed: src/tera.lua's cell must not promise a change the
-- activation can only fail to make.
local redEra = { type_chart = { types = chartOf({ "NORMAL", "FIRE", "FLYING" }) },
                 pokemon = data.pokemon }
local gone, goneWhy = TeraType.of(redEra, stamped)
T.eq(gone, nil, "a stamp naming a type this chart lacks is refused")
T.eq(goneWhy, "stamp_unknown_type", "and says why")

-- --- refusals -------------------------------------------------------------
T.eq(TeraType.of(data, nil), nil, "no Pokemon, no type")

-- A Pokemon with no DVs still gets one, hashed on its species alone.  Refusing
-- would take the TERA cell off the menu with nothing on screen to explain it,
-- which src/tera.lua's own header rules out; both engines roll DVs at creation
-- so this is the malformed case rather than a real one.
local noDvs = { species = "CHARIZARD" }
local dvlessId = TeraType.of(data, noDvs)
T.check(dvlessId == "FIRE" or dvlessId == "FLYING",
  "a Pokemon with no DVs still gets one of its own types")
T.eq(TeraType.of(data, { species = "CHARIZARD" }), dvlessId,
  "and the same one every time")

local unknown = mon("MISSINGNO", 1, 2, 3, 4)
local unkId, unkWhy = TeraType.of(data, unknown)
T.eq(unkId, nil, "a species with no record yields no type")
T.eq(unkWhy, "no_types", "and says so")

-- --- own() filters to what the chart can resolve --------------------------
-- A Red-era chart has no FAIRY, so a Fairy-typed species must not offer one.
local fairyData = {
  type_chart = { types = chartOf({ "NORMAL", "WATER" }) },
  pokemon = { AZUMARILL = { types = { "WATER", "FAIRY" } } },
}
T.same(TeraType.own(fairyData, { species = "AZUMARILL" }), { "WATER" },
  "own types are filtered to the ones this game's chart carries")

T.finish("battle_forms_teratype")
