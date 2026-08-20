-- Stellar, which is a damage rule wearing a Tera type's clothes.
--
-- The thing most worth pinning is what Stellar does NOT do: it must never
-- reach the type override every other Tera type goes through. A STELLAR
-- written into curTypes or formTypes is a type the chart has no record for,
-- which turns every matchup for that Pokemon neutral for the rest of the
-- battle -- silently, with the damage numbers as the only symptom. So the
-- override paths are asserted absent rather than merely correct.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Stellar = dofile(MOD .. "/src/stellar.lua")
local TeraType = dofile(MOD .. "/src/teratype.lua")
local Shards = dofile(MOD .. "/src/terashards.lua")

Stellar.bind({ terashards = Shards, battlerof = { mon = function(b)
  return b and b.mon or b
end } })

-- The two files each name the id so neither has to depend on the other; if
-- they ever drift, Stellar stops being spendable and starts being refused as a
-- stamp for an unknown type.
T.eq(TeraType.STELLAR, Stellar.TYPE,
  "src/teratype.lua and src/stellar.lua agree on the id")

local FIRE_MOVE = { id = "FLAMETHROWER", type = "FIRE", power = 90 }
local FIRE_MOVE_2 = { id = "FIREBLAST", type = "FIRE", power = 110 }
local GROUND_MOVE = { id = "EARTHQUAKE", type = "GROUND", power = 100 }
local STATUS_MOVE = { id = "GROWL", type = "NORMAL", power = 0 }

local function charizard()
  return { curTypes = { "FIRE", "FLYING" } }
end

-- --- inert until a Stellar Terastallization is live ----------------------
Stellar.clear()
local user, mon = charizard(), {}
T.eq(Stellar.factor(user, mon, FIRE_MOVE), 1,
  "with no Stellar active nothing is scaled")
T.eq(Stellar.active(), false, "and nothing reports active")

-- --- a STAB type: x2 total, so x4/3 on top of the engine's own x1.5 ------
Stellar.begin(mon)
T.eq(Stellar.active(mon), true, "the Pokemon that terastallized is active")
local first = Stellar.factor(user, mon, FIRE_MOVE)
T.check(math.abs(first - 4 / 3) < 1e-9,
  "the first move of a STAB type is scaled by 2/1.5, lifting x1.5 to x2")

-- --- and only the first, per TYPE, not per move --------------------------
T.eq(Stellar.factor(user, mon, FIRE_MOVE), 1,
  "the same move again is ordinary")
T.eq(Stellar.factor(user, mon, FIRE_MOVE_2),
  1, "and so is a DIFFERENT move of that same type -- the boost is per type")

-- --- a non-STAB type: x1.2, once -----------------------------------------
local ground = Stellar.factor(user, mon, GROUND_MOVE)
T.check(math.abs(ground - 1.2) < 1e-9,
  "the first move of a non-STAB type is scaled by 1.2")
T.eq(Stellar.factor(user, mon, GROUND_MOVE), 1, "and only the first")

-- --- status moves never spend a type's boost -----------------------------
-- A Growl that quietly used up Normal's one boost would be a trap with no
-- symptom until the Hyper Beam that followed it landed short.
Stellar.begin(mon)
T.eq(Stellar.factor(user, mon, STATUS_MOVE), 1, "a zero-power move is not scaled")
local normalMove = { id = "HYPERBEAM", type = "NORMAL", power = 150 }
T.check(math.abs(Stellar.factor(user, mon, normalMove) - 1.2) < 1e-9,
  "and did not spend that type's boost on its way past")

-- --- another Pokemon's moves are untouched -------------------------------
Stellar.begin(mon)
T.eq(Stellar.factor(charizard(), {}, FIRE_MOVE), 1,
  "a Pokemon that did not terastallize gets nothing")

-- --- the boost table is battle state, not Pokemon state ------------------
-- A Pokemon that switches out and back has not got its boosts back; one in the
-- next battle has. begin() is what draws that line.
Stellar.begin(mon)
Stellar.factor(user, mon, FIRE_MOVE)
T.eq(Stellar.factor(user, mon, FIRE_MOVE), 1, "spent within one battle")
Stellar.begin(mon)
T.check(math.abs(Stellar.factor(user, mon, FIRE_MOVE) - 4 / 3) < 1e-9,
  "and back for the next Terastallization")

-- --- clear really clears -------------------------------------------------
Stellar.clear()
T.eq(Stellar.active(), false, "clear ends it")
T.eq(Stellar.factor(user, mon, GROUND_MOVE), 1, "and nothing is scaled after")

-- --- a Stellar stamp survives teratype's chart validation ----------------
-- Every other Tera type is checked against the running chart, and Stellar is
-- deliberately not in it -- so without its own exemption the one type a
-- Pokemon can never be born with would also be the one it could never be given.
local chartless = { type_chart = { types = { FIRE = { name = "FIRE" } } },
                    pokemon = { CHARIZARD = { types = { "FIRE", "FLYING" } } } }
local stamped = { species = "CHARIZARD", dvs = { attack = 1, defense = 2,
                                                 speed = 3, special = 4 } }
stamped[TeraType.STAMP] = Stellar.TYPE
local id, why = TeraType.of(chartless, stamped)
T.eq(id, Stellar.TYPE, "a STELLAR stamp is honoured")
T.eq(why, "stamp", "as a stamp")

-- And it is never DERIVED -- it is not in any species' own types and not in the
-- chart, so the only way to hold it is to have paid for it.
local derivedEver = false
for a = 0, 15 do
  for d = 0, 15 do
    for s = 0, 15 do
      for sp = 0, 15 do
        local got = TeraType.of(chartless,
          { species = "CHARIZARD",
            dvs = { attack = a, defense = d, speed = s, special = sp } })
        if got == Stellar.TYPE then derivedEver = true end
      end
    end
  end
end
T.eq(derivedEver, false,
  "no Pokemon is ever born Stellar -- across all 65536 DV spreads")

T.finish("battle_forms_stellar")
