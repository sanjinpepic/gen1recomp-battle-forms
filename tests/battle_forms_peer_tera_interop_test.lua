-- Composing with a peer battle-engine mod's own Tera damage layer.
--
-- The peer here is not simulated and not named beyond the one functional
-- string this mod's manifest matches on: what is pinned is THIS mod's side of
-- the contract, which has to hold whether or not anything else is installed.
--
-- THE CONTRACT, and why it is shaped this way.  A peer's Tera damage layer can
-- detect a Terastallization without being told: curTypes (Gen 1) or formTypes
-- (Gen 2) collapsed to exactly one type that is not one of the species' own is
-- a state only a Terastallization produces, and it is exactly what
-- src/tera.lua writes.  So this mod must KEEP writing it -- standing aside
-- would take the trigger away from anything built on top of it -- and the two
-- things that actually need care are the ones a peer cannot observe:
--
--   * the Tera type a peer DRAWS comes from its own per-mon field, not from
--     curTypes, so a Pokemon whose type this mod derived would show one value
--     on a peer's screen and terastallize into another.  M.mirror closes that.
--
--   * STELLAR deliberately has no chart record here, and the rare-roll used to
--     rely on that.  A peer that registers one would start handing out, for
--     free, the one Tera type that is supposed to cost fifty shards.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local TeraType = dofile(MOD .. "/src/teratype.lua")
local Shards = dofile(MOD .. "/src/terashards.lua")
local Shop = dofile(MOD .. "/src/terashop.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Stellar = dofile(MOD .. "/src/stellar.lua")

Shop.bind({ teratype = TeraType, terashards = Shards, keyitems = KeyItems })

-- --- the manifest names the peer, and only the current id -----------------
local manifest = (function()
  local h = assert(io.open(MOD .. "/manifest.json", "rb"))
  local body = h:read("*a"); h:close(); return body
end)()
T.check(manifest:find("g9-battle-engine-beta", 1, true) ~= nil,
  "the peer's current manifest id is listed as an optional dependency, which "
    .. "is what orders this mod after it when it is present")
-- The superseded id is gone rather than kept alongside: an optional dependency
-- on an id nothing declares is inert, but two ids for one peer is a list that
-- goes stale silently and reads as though both were checked.
T.check(manifest:gsub("g9%-battle%-engine%-beta", ""):find("g9-battle-engine",
  1, true) == nil, "and the superseded id is not left beside it")

-- --- STELLAR never enters the rare roll, chart or no chart ----------------
-- Without a peer: STELLAR is absent from the chart, so this passed for free.
local plain = {
  type_chart = { types = { FIRE = { name = "FIRE" }, WATER = { name = "WATER" },
                           FLYING = { name = "FLYING" } } },
  pokemon = { CHARIZARD = { types = { "FIRE", "FLYING" } } },
}
for _, id in ipairs(TeraType.chartTypes(plain)) do
  T.check(id ~= TeraType.STELLAR, "no STELLAR in the roll without a peer")
end

-- With one: a STELLAR identity record is registered into the chart, exactly as
-- a peer does.  The roll must still refuse it -- this is the assertion that
-- was passing for the wrong reason before.
local withPeer = {
  type_chart = { types = { FIRE = { name = "FIRE" }, WATER = { name = "WATER" },
                           FLYING = { name = "FLYING" },
                           STELLAR = { name = "STELLAR" } } },
  pokemon = { CHARIZARD = { types = { "FIRE", "FLYING" } } },
}
local rollable = TeraType.chartTypes(withPeer)
for _, id in ipairs(rollable) do
  T.check(id ~= TeraType.STELLAR,
    "a peer's STELLAR chart record does not make it rollable")
end
T.check(#rollable == 3, "and the other three types are still rollable")

-- Exhaustive, because "rare" means a sampled test would miss it: no DV spread
-- may produce STELLAR even with the record present.
local born = 0
for a = 0, 15 do
  for d = 0, 15 do
    for s = 0, 15 do
      for sp = 0, 15 do
        if TeraType.of(withPeer, { species = "CHARIZARD",
             dvs = { attack = a, defense = d, speed = s, special = sp } })
             == Stellar.TYPE then
          born = born + 1
        end
      end
    end
  end
end
T.eq(born, 0,
  "no Pokemon is born Stellar across all 65536 spreads, peer chart or not")

-- A Pokemon that PAID for Stellar still has it: the exclusion is about the
-- roll, not about the type being unreachable.
local paid = { species = "CHARIZARD", dvs = { attack = 1, defense = 1,
                                              speed = 1, special = 1 } }
paid[TeraType.STAMP] = Stellar.TYPE
T.eq(TeraType.of(withPeer, paid), Stellar.TYPE,
  "a stamped Stellar is still honoured with a peer's chart record present")

-- --- the mirror -----------------------------------------------------------
T.eq(TeraType.MIRROR, "teraType", "the mirrored field is the peer's own name")

local mon = { species = "CHARIZARD" }
T.eq(TeraType.mirror(mon, "WATER"), true, "mirroring writes the field")
T.eq(mon.teraType, "WATER", "with the type as its value")
T.eq(TeraType.mirror(mon, "WATER"), false, "and reports no change on a repeat")
T.eq(TeraType.mirror(mon, nil), false, "a nil type mirrors nothing")
T.eq(mon.teraType, "WATER", "and leaves what was there")
T.eq(TeraType.mirror(nil, "FIRE"), false, "and no Pokemon mirrors nothing")

-- Spending shards writes BOTH fields, so a peer's own screen and this mod's
-- own Tera Orb cannot disagree about what was just bought.
local buyer = { species = "CHARIZARD", nickname = "ZARD",
                dvs = { attack = 3, defense = 6, speed = 9, special = 12 } }
local save = { inventory = { [Shards.idFor("WATER")] = Shards.COST },
               bagOrder = { Shards.idFor("WATER") } }
Shop.onSaveReady({ save = save })
T.eq((Shop.change(withPeer, buyer, "WATER")), true, "the shards buy the change")
T.eq(buyer[TeraType.STAMP], "WATER", "this mod's own field is written")
T.eq(buyer.teraType, "WATER", "and the peer's field agrees with it")

-- The mirror follows a later change rather than sticking at the first.
local save2 = { inventory = { [Shards.idFor("FIRE")] = Shards.COST },
                bagOrder = { Shards.idFor("FIRE") } }
Shop.onSaveReady({ save = save2 })
T.eq((Shop.change(withPeer, buyer, "FIRE")), true, "a second change is bought")
T.eq(buyer.teraType, "FIRE", "and the mirror follows it")

-- --- this mod stays the source of truth -----------------------------------
-- Mirroring is one-directional on purpose: a peer rolls its own default into
-- that field on first read, and honouring it would make this mod's behaviour
-- depend on what else is installed.  A foreign value in the mirror must not
-- change what this mod answers.
local foreign = { species = "CHARIZARD", teraType = "WATER",
                  dvs = { attack = 2, defense = 4, speed = 6, special = 8 } }
local ours = TeraType.of(plain, foreign)
T.check(ours == "FIRE" or ours == "FLYING",
  "a value already in the peer's field does not override this mod's own "
    .. "derivation -- behaviour cannot depend on what else is loaded")

T.finish("battle_forms_peer_tera_interop")
