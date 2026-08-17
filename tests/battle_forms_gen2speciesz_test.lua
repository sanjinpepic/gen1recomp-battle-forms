-- Species Z-Moves on Gold: src/speciesz.lua's own `deps.gen2` branch on
-- M.fieldsFor, the maxPp-not-ppUps correction src/maxmoves.lua's and
-- src/zmoves.lua's own Gen 2 branches already carry, and proof through the
-- shared Z-MOVE cell (src/zmoves.lua's own `entry`) that a species crystal
-- reached through mon.item converts the one named move it names, on the one
-- species it fits, exactly as the type catalog does for a type.
--
-- What this suite does NOT re-prove: the once-per-battle lock and every
-- teardown path are src/arm.lua's and src/zmoves.lua's own state, neither of
-- which knows or cares which catalog produced a substitution -- proven once
-- for Gold in tests/battle_forms_gen2zmoves_test.lua, exactly the discipline
-- tests/battle_forms_zmoves_test.lua's own "species catalog" section keeps
-- for Gen 1.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local SpeciesZ = dofile(MOD .. "/src/speciesz.lua")
local ZMoves = dofile(MOD .. "/src/zmoves.lua")
local Gen2Substitute = dofile(MOD .. "/src/gen2substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local ROWS = dofile(MOD .. "/data/speciesz.lua")
local ZROWS = dofile(MOD .. "/data/zmoves.lua")

local MOVES = {
  VOLTTACKLE = { id = "VOLTTACKLE", name = "VOLT TACKLE", type = "ELECTRIC",
                 power = 120, pp = 15, accuracy = 100 },
  EMBER = { id = "EMBER", name = "EMBER", type = "FIRE", power = 40, pp = 25,
            accuracy = 100 },
}

-- ---------------------------------------------------------------------
-- fieldsFor: maxPp is the base move's own real maximum, never a ppUps
-- correction -- Gold's FIGHT menu draws move.maxPp straight off the slot,
-- and src/gen2substitute.lua writes it onto the SAME table it mutates.
-- ---------------------------------------------------------------------
do
  SpeciesZ.bind({ substitute = nil, anim = Anim, log = nil, gen2 = true })
  local mod = { content = {
    moves = { get = function(_, id) return MOVES[id] end,
              register = function() end },
    battle_anims = { register = function() end },
  } }
  local catalog = SpeciesZ.install(mod, ROWS)
  local data = { moves = MOVES }
  local pikachu = { species = "PIKACHU" }
  local slot = { id = "VOLTTACKLE", pp = 15, maxPp = 15 }

  local fields = SpeciesZ.fieldsFor(catalog, data, pikachu, slot, "PIKASHUNIUM_Z")
  T.check(fields ~= nil, "the right species, move and crystal still converts on Gold")
  T.eq(fields.id, SpeciesZ.idFor("CATASTROPIKA"), "into the registered id")
  T.eq(fields.maxPp, 15, "and VOLT TACKLE's own real maxPp")
  T.eq(rawget(fields, "ppUps"), nil, "never a ppUps correction -- that is Gen 1's own")

  SpeciesZ.bind({ substitute = nil, anim = Anim, log = nil })
end

-- ---------------------------------------------------------------------
-- Through the shared cell: a species crystal reached via mon.item, on Gold.
-- ---------------------------------------------------------------------
do
  local mod = { content = {
    moves = { get = function(_, id) return MOVES[id] end,
              register = function() end },
    battle_anims = { register = function() end },
  } }
  SpeciesZ.bind({ substitute = nil, anim = Anim, log = nil, gen2 = true })
  local speciesCatalog = SpeciesZ.install(mod, ROWS)

  local zMod = { content = {
    moves = { register = function() end },
    battle_anims = { register = function() end },
    type_chart = { get = function() return nil end },
  } }
  ZMoves.bind({ substitute = nil, keyitems = KeyItems, eligibility = E,
                announce = Announce, anim = Anim, speciesz = SpeciesZ,
                battlerof = Battlerof, gen2 = true,
                gen2substitute = Gen2Substitute })
  -- No type registers at all (the type chart stub answers nothing), so
  -- ANY conversion below can only be the species catalog's doing.
  local zCatalog = ZMoves.install(zMod, ZROWS)

  local mon = { species = "PIKACHU", level = 50, nickname = "SPARKY", hp = 100,
                item = "PIKASHUNIUM_Z",
                moves = { { id = "VOLTTACKLE", pp = 15, maxPp = 15 },
                          { id = "EMBER", pp = 25, maxPp = 25 } } }
  local battle = {
    data = { moves = MOVES }, player = mon, party = { mon }, enemyParty = {},
    events = {}, save = { inventory = { [KeyItems.Z_RING] = 1 } },
    emit = function(self, ev) self.events[#self.events + 1] = ev end,
    monName = function(_, m) return m and m.nickname end,
  }

  local entry = ZMoves.entry(ZMoves.new(), zCatalog, speciesCatalog)
  T.eq(entry.available(battle), true,
    "a species crystal on mon.item lights the cell, even with no type "
      .. "catalog behind it")

  T.eq(entry.arm(battle), true, "arming succeeds")
  T.eq(mon.moves[1].id, SpeciesZ.idFor("CATASTROPIKA"),
    "the named move becomes the species Z-Move")
  T.eq(mon.moves[1].maxPp, 15, "carrying VOLT TACKLE's own real maxPp")
  T.eq(mon.moves[2].id, "EMBER", "and the other slot is left exactly as it was")

  entry.disarm()
  T.eq(mon.moves[1].id, "VOLTTACKLE", "disarming puts the real move back")

  -- The wrong species, or the crystal without the one move it needs, gets
  -- nothing to convert and no cell -- read off mon.item, the same as above.
  local wrongSpecies = { species = "RAICHU", level = 50, nickname = "RAI", hp = 100,
                         item = "PIKASHUNIUM_Z",
                         moves = { { id = "VOLTTACKLE", pp = 15, maxPp = 15 } } }
  local wrongBattle = {
    data = { moves = MOVES }, player = wrongSpecies, party = { wrongSpecies },
    enemyParty = {}, events = {},
    save = { inventory = { [KeyItems.Z_RING] = 1 } },
    emit = function(self, ev) self.events[#self.events + 1] = ev end,
    monName = function(_, m) return m and m.nickname end,
  }
  T.eq(ZMoves.entry(ZMoves.new(), zCatalog, speciesCatalog).available(wrongBattle),
    false, "the right crystal on the wrong species offers nothing")

  ZMoves.bind({ substitute = nil, keyitems = KeyItems, eligibility = E,
                announce = Announce, anim = Anim, battlerof = Battlerof })
  SpeciesZ.bind({ substitute = nil, anim = Anim, log = nil })
end

T.finish("battle_forms_gen2speciesz")
