-- Species-specific Z-Moves: the roster data/speciesz.lua carries, and the
-- catalog src/speciesz.lua builds from it -- species AND move both have to
-- match before a crystal converts anything, where the eighteen type
-- Z-Moves only ever check the move's type.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local SpeciesZ = dofile(MOD .. "/src/speciesz.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local ROWS = dofile(MOD .. "/data/speciesz.lua")
local CRYSTALS = dofile(MOD .. "/data/speciescrystals.lua")
local ZROWS = dofile(MOD .. "/data/zmoves.lua")
local MAXROWS = dofile(MOD .. "/data/maxmoves.lua")

local function bindSpeciesZ(log)
  SpeciesZ.bind({ substitute = Substitute, anim = Anim, log = log })
end

-- ---------------------------------------------------------------------
-- The data table itself.
-- ---------------------------------------------------------------------
do
  T.eq(#ROWS, 14, "fourteen species Z-Moves, the ones this build covers")

  local seenCrystal, seenStem, seenSpecies = {}, {}, {}
  for _, row in ipairs(ROWS) do
    T.check(not seenCrystal[row.crystal], row.crystal .. " names one row")
    seenCrystal[row.crystal] = true
    T.check(not seenStem[row.stem], row.stem .. " is a stem of its own")
    seenStem[row.stem] = true
    T.check(CRYSTALS[row.crystal] ~= nil,
      row.crystal .. " has a bag byte, without which it cannot be in a save")
    T.check(type(row.species) == "table" and #row.species > 0,
      row.crystal .. " names at least one species")
    for _, species in ipairs(row.species) do
      T.check(not seenSpecies[species],
        species .. " is not claimed by two different crystals")
      seenSpecies[species] = true
    end
    T.check(type(row.move) == "string" and row.move ~= "",
      row.crystal .. " names the one move it converts")
    T.check(type(row.power) == "number" and row.power > 0,
      row.crystal .. " carries a fixed power")
    T.eq(row.category, nil,
      row.crystal .. " carries no category, so Gen 1 decides by type")
  end

  local indexed = 0
  for crystal in pairs(CRYSTALS) do
    indexed = indexed + 1
    T.check(seenCrystal[crystal], crystal .. " is indexed and is also a row")
  end
  T.eq(indexed, 14, "and there are exactly as many bytes as rows")

  -- 238-255 is what data/drives.lua left free; this family must not spill
  -- past it, and the header's claim of four spare bytes is checked directly.
  local used = {}
  for _, index in pairs(CRYSTALS) do
    T.check(index >= 238 and index <= 255,
      "byte " .. index .. " falls inside the free 238-255 range")
    T.check(not used[index], "byte " .. index .. " is not handed out twice")
    used[index] = true
  end
  local free = 0
  for i = 238, 255 do if not used[i] then free = free + 1 end end
  T.eq(free, 4, "four bytes are left spare after this family")

  -- Stems cannot collide with the type Z-Moves' or the Max Moves' -- all
  -- three share src/speciesz.lua's / src/zmoves.lua's / src/maxmoves.lua's
  -- "BATTLE_FORMS_" prefix, so a stem collision would be a load failure for
  -- whichever registers second.
  local otherStems = { [MAXROWS.guard.stem] = true }
  for _, row in ipairs(MAXROWS.types) do otherStems[row.stem] = true end
  for _, row in ipairs(ZROWS.types) do otherStems[row.stem] = true end
  for _, row in ipairs(ROWS) do
    T.check(not otherStems[row.stem],
      row.stem .. " is not also a type Z-Move or Max Move stem")
  end
end

-- ---------------------------------------------------------------------
-- The FIGHT menu's own names: every row fits both budgets, the same
-- boundary tests/battle_forms_zmoves_test.lua measures for the type roster.
-- ---------------------------------------------------------------------
do
  local CLASSIC_BUDGET, WIDE_BUDGET = 13, 12
  for _, row in ipairs(ROWS) do
    T.check(type(row.menu) == "string" and row.menu ~= "",
      row.crystal .. " carries a FIGHT-menu display name")
    T.check(#row.menu <= WIDE_BUDGET,
      ("%s (%d chars) fits the widescreen grid's %d-column budget"):format(
        row.menu, #row.menu, WIDE_BUDGET))
    T.check(#row.menu <= CLASSIC_BUDGET,
      ("%s (%d chars) fits the classic FIGHT menu's %d-column budget"):format(
        row.menu, #row.menu, CLASSIC_BUDGET))
  end

  local names = SpeciesZ.menuNames(ROWS)
  local mapped = 0
  for _, row in ipairs(ROWS) do
    mapped = mapped + 1
    T.eq(names[SpeciesZ.idFor(row.stem)], row.menu,
      row.stem .. "'s registered id maps to its menu name")
  end
  T.eq(mapped, #ROWS, "every row was checked")
end

-- ---------------------------------------------------------------------
-- Pairings and crystal ids, the shapes src/stone.lua and src/shop.lua read.
-- ---------------------------------------------------------------------
do
  local pairings = SpeciesZ.pairings(ROWS)
  T.check(pairings.PIKACHU and pairings.PIKACHU.PIKASHUNIUM_Z,
    "Pikachu pairs with Pikashunium Z")
  T.check(pairings.PIKACHU and not pairings.PIKACHU.ALORAICHIUM_Z,
    "and with nothing else")
  T.check(pairings.LYCANROC_MIDNIGHT and pairings.LYCANROC_MIDNIGHT.LYCANIUM_Z,
    "every forme Lycanroc pairs with the one Lycanium Z")
  T.check(pairings.LYCANROC_DUSK and pairings.LYCANROC_DUSK.LYCANIUM_Z,
    "including Dusk form")

  local ids = SpeciesZ.crystalIds(ROWS)
  T.eq(#ids, 14, "one id per row, in the data's own order")
  T.eq(ids[1], ROWS[1].crystal, "starting with the first row's crystal")
end

-- ---------------------------------------------------------------------
-- Registration.
-- ---------------------------------------------------------------------
local function stubMod(moveDefs)
  local warned = {}
  local buckets = { moves = {}, battle_anims = {} }
  local content = {}
  for name, bucket in pairs(buckets) do
    content[name] = {
      register = function(_, id, record)
        T.check(bucket[id] == nil, name .. " id registered once: " .. tostring(id))
        bucket[id] = record
      end,
    }
  end
  -- A minimal stand-in for the merged move registry's own :get(id), the
  -- seam src/speciesz.lua reads a base move's type off.
  content.moves.get = function(_, id) return moveDefs[id] end
  return { content = content,
           log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
           registered = buckets, warned = warned }
end

local CATALOG
local MOVES = {
  VOLTTACKLE = { id = "VOLTTACKLE", type = "ELECTRIC", power = 120, pp = 15 },
  THUNDERBOLT = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90, pp = 15 },
  GIGAIMPACT = { id = "GIGAIMPACT", type = "NORMAL", power = 150, pp = 5 },
  -- PSYCHIC, SPIRITSHACKLE and the rest are deliberately absent, so the
  -- registration test below also proves the "no record" refusal.
}

do
  local mod = stubMod(MOVES)
  bindSpeciesZ(mod.log)
  CATALOG = SpeciesZ.install(mod, ROWS)

  local built, missing = 0, 0
  for _, row in ipairs(ROWS) do
    if MOVES[row.move] then built = built + 1 else missing = missing + 1 end
  end
  T.check(built >= 3, "precondition: at least the three stubbed moves resolve")
  T.check(missing > 0, "precondition: and most of the roster does not, on purpose")
  T.eq(#mod.warned, missing,
    "every row whose base move has no record is refused and logged, once each")

  local record = mod.registered.moves[SpeciesZ.idFor("CATASTROPIKA")]
  T.eq(record.name, "CATASTROPIKA", "the registered record keeps the real name")
  T.eq(record.type, "ELECTRIC",
    "and its type is read off VOLTTACKLE's own record, not duplicated in the data")
  T.eq(record.power, 210, "at the fixed power the data names")
  T.eq(record.accuracy, 100, "never misses under this mod's ruling")
  T.eq(record.pp, SpeciesZ.RECORD_PP, "registered at the record PP the menu math wants")
  T.check(mod.registered.battle_anims[SpeciesZ.idFor("CATASTROPIKA")] ~= nil,
    "and an animation, so it is not silent")

  T.eq(mod.registered.moves[SpeciesZ.idFor("GENESISSUPERNOVA")], nil,
    "Mewnium Z's own move never registers -- PSYCHIC has no record in this stub")
end

-- ---------------------------------------------------------------------
-- fieldsFor: species AND move both have to match.
-- ---------------------------------------------------------------------
do
  local data = { moves = MOVES }
  local pikachu = { species = "PIKACHU" }
  local raichu = { species = "RAICHU_ALOLA" }
  local slot = { id = "VOLTTACKLE", pp = 15 }

  local fields = SpeciesZ.fieldsFor(CATALOG, data, pikachu, slot, "PIKASHUNIUM_Z")
  T.check(fields ~= nil, "the right species, the right move, the right crystal converts")
  T.eq(fields.id, SpeciesZ.idFor("CATASTROPIKA"), "into the registered id")

  T.eq(SpeciesZ.fieldsFor(CATALOG, data, raichu, slot, "PIKASHUNIUM_Z"), nil,
    "the wrong species does not convert, even carrying the right move")
  T.eq(SpeciesZ.fieldsFor(CATALOG, data, pikachu, { id = "THUNDERBOLT", pp = 15 },
    "PIKASHUNIUM_Z"), nil, "the right species but the wrong move does not convert")
  T.eq(SpeciesZ.fieldsFor(CATALOG, data, pikachu, slot, "SNORLIUM_Z"), nil,
    "and a crystal this Pokemon is not carrying does nothing regardless")
  T.eq(SpeciesZ.fieldsFor(CATALOG, data, pikachu, slot, "MEWNIUM_Z"), nil,
    "a crystal whose own move never registered converts nothing, refusing "
      .. "rather than erroring")

  T.check(SpeciesZ.wouldConvert(CATALOG, data, pikachu,
    { curMoves = { slot, { id = "TACKLE" } } }, "PIKASHUNIUM_Z"),
    "wouldConvert finds the matching slot among several")
  T.check(not SpeciesZ.wouldConvert(CATALOG, data, raichu,
    { curMoves = { slot } }, "PIKASHUNIUM_Z"),
    "and answers false for a Pokemon the crystal does not fit")

  local picked = SpeciesZ.picker(CATALOG, data, pikachu, "PIKASHUNIUM_Z")(slot)
  T.eq(picked.id, SpeciesZ.idFor("CATASTROPIKA"), "the picker closes over mon and crystal")
end

T.finish("battle_forms_speciesz")
