-- Arceus's seventeen Plates and Silvally's seventeen Memories, wired once
-- formart.lua actually carried art for both species (see
-- dev/reports/silvally_forms.md and dev/tools/build_form_art.py; 0.21.0's
-- tests/battle_forms_art_test.lua and tests/battle_forms_formids_test.lua
-- pinned the absence as a hard assertion for exactly this reason -- so art
-- landing would break them on purpose).
--
-- Same mechanism as tests/battle_forms_heldforms_test.lua top to bottom: one
-- item, stamped on the mon, deriving a marker the battle-end sweep vouches
-- for or clears.  This suite exists beside that one rather than folded into
-- it because these two families are the first to answer `false` rather than
-- a number in their indices table -- see data/plates.lua's header for why
-- there was no byte left to give them -- and that difference has its own
-- surface to test: registration with no `index` field at all, and a shop
-- shelf that has to sort items with no byte to sort by.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local Shop = dofile(MOD .. "/src/shop.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local rows = dofile(MOD .. "/data/persistent.lua")
local applianceIndices = dofile(MOD .. "/data/appliances.lua")
local heldFormIndices = dofile(MOD .. "/data/heldforms.lua")
local plateIndices = dofile(MOD .. "/data/plates.lua")
local memoryIndices = dofile(MOD .. "/data/memories.lua")
local driveIndices = dofile(MOD .. "/data/drives.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- `rows` is the WHOLE of data/persistent.lua, Rotom, the other six held forms
-- and Genesect's four Drives included -- see tests/battle_forms_heldforms_test.lua
-- and tests/battle_forms_drives_test.lua for their own suites -- so the merged
-- `indices` below has to resolve every item those families name too, exactly
-- as those suites' own merges have to reach back the other way into this
-- file's two.
local indices = {}
for itemId, index in pairs(applianceIndices) do indices[itemId] = index end
for itemId, index in pairs(heldFormIndices) do indices[itemId] = index end
for itemId, index in pairs(plateIndices) do indices[itemId] = index end
for itemId, index in pairs(memoryIndices) do indices[itemId] = index end
for itemId, index in pairs(driveIndices) do indices[itemId] = index end

-- A handful of the 34 forms carry the battle-behavior checks; the data-table
-- section below names all 34 pairings outright, the way every other family's
-- suite does.  Alakazam rides along on the sweep check for the reason it
-- does in tests/battle_forms_heldforms_test.lua: a sweep that keeps
-- everything is as broken as one that keeps nothing.
local DATA = { pokemon = {
  ARCEUS = { baseStats = { hp = 120, attack = 120, defense = 120,
                           speed = 120, special = 120 },
             types = { "NORMAL" } },
  ARCEUS_FIRE = { baseStats = { hp = 120, attack = 120, defense = 120,
                                speed = 120, special = 120 },
                  types = { "FIRE" }, form = "FIRE" },
  ARCEUS_WATER = { baseStats = { hp = 120, attack = 120, defense = 120,
                                 speed = 120, special = 120 },
                   types = { "WATER" }, form = "WATER" },
  SILVALLY = { baseStats = { hp = 95, attack = 95, defense = 95,
                             speed = 95, special = 95 },
               types = { "NORMAL" } },
  SILVALLY_ELECTRIC = { baseStats = { hp = 95, attack = 95, defense = 95,
                                      speed = 95, special = 95 },
                        types = { "ELECTRIC" }, form = "ELECTRIC" },
  SILVALLY_DARK = { baseStats = { hp = 95, attack = 95, defense = 95,
                                  speed = 95, special = 95 },
                    types = { "DARK" }, form = "DARK" },
  ALAKAZAM = { baseStats = { hp = 55, attack = 50, defense = 45,
                             speed = 120, special = 135 },
               types = { "PSYCHIC" } },
  ALAKAZAM_MEGA = { baseStats = { hp = 55, attack = 50, defense = 65,
                                  speed = 150, special = 175 },
                    types = { "PSYCHIC" }, form = "MEGA" },
} }

local function newMon(species, held)
  local base = DATA.pokemon[species].baseStats
  local mon = { species = species, level = 50,
                dvs = { hp = 15, attack = 15, defense = 15,
                        speed = 15, special = 15 },
                statExp = {}, [E.STAMP] = held,
                hp = 120,
                moves = { { id = "TACKLE", pp = 35 } } }
  mon.stats = { hp = base.hp, attack = base.attack, defense = base.defense,
                speed = base.speed, special = base.special }
  return mon
end

local function battlerFor(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, curStats = mon.stats,
           curTypes = DATA.pokemon[mon.species].types }
end

local function makeBattle(party)
  return {
    data = DATA, phase = "menu", queue = {},
    player = battlerFor(party[1], true),
    game = { save = { party = party, inventory = {} } },
    enemyParty = {},
  }
end

local function recorder()
  local lines = {}
  return lines, { warn = function(_, fmt, ...)
    lines[#lines + 1] = string.format(fmt, ...)
  end }
end

local warnings, log = recorder()
Persistent.bind({ forms = Forms, eligibility = E, rows = rows, log = log,
                  price = Stone.PRICE })
Resolve.bind({ forms = Forms, eligibility = E, megas = megas,
               persistent = Persistent })
Stone.bind(E, Persistent)

-- ------- the data table names all 34 outright --------------------------

do
  local expected = {
    { "ARCEUS", "FIST_PLATE",   "ARCEUS_FIGHTING" },
    { "ARCEUS", "SKY_PLATE",    "ARCEUS_FLYING" },
    { "ARCEUS", "TOXIC_PLATE",  "ARCEUS_POISON" },
    { "ARCEUS", "EARTH_PLATE",  "ARCEUS_GROUND" },
    { "ARCEUS", "STONE_PLATE",  "ARCEUS_ROCK" },
    { "ARCEUS", "INSECT_PLATE", "ARCEUS_BUG" },
    { "ARCEUS", "SPOOKY_PLATE", "ARCEUS_GHOST" },
    { "ARCEUS", "IRON_PLATE",   "ARCEUS_STEEL" },
    { "ARCEUS", "FLAME_PLATE",  "ARCEUS_FIRE" },
    { "ARCEUS", "SPLASH_PLATE", "ARCEUS_WATER" },
    { "ARCEUS", "MEADOW_PLATE", "ARCEUS_GRASS" },
    { "ARCEUS", "ZAP_PLATE",    "ARCEUS_ELECTRIC" },
    { "ARCEUS", "MIND_PLATE",   "ARCEUS_PSYCHIC" },
    { "ARCEUS", "ICICLE_PLATE", "ARCEUS_ICE" },
    { "ARCEUS", "DRACO_PLATE",  "ARCEUS_DRAGON" },
    { "ARCEUS", "DREAD_PLATE",  "ARCEUS_DARK" },
    { "ARCEUS", "PIXIE_PLATE",  "ARCEUS_FAIRY" },
    { "SILVALLY", "FIGHTING_MEMORY", "SILVALLY_FIGHTING" },
    { "SILVALLY", "FLYING_MEMORY",   "SILVALLY_FLYING" },
    { "SILVALLY", "POISON_MEMORY",   "SILVALLY_POISON" },
    { "SILVALLY", "GROUND_MEMORY",   "SILVALLY_GROUND" },
    { "SILVALLY", "ROCK_MEMORY",     "SILVALLY_ROCK" },
    { "SILVALLY", "BUG_MEMORY",      "SILVALLY_BUG" },
    { "SILVALLY", "GHOST_MEMORY",    "SILVALLY_GHOST" },
    { "SILVALLY", "STEEL_MEMORY",    "SILVALLY_STEEL" },
    { "SILVALLY", "FIRE_MEMORY",     "SILVALLY_FIRE" },
    { "SILVALLY", "WATER_MEMORY",    "SILVALLY_WATER" },
    { "SILVALLY", "GRASS_MEMORY",    "SILVALLY_GRASS" },
    { "SILVALLY", "ELECTRIC_MEMORY", "SILVALLY_ELECTRIC" },
    { "SILVALLY", "PSYCHIC_MEMORY",  "SILVALLY_PSYCHIC" },
    { "SILVALLY", "ICE_MEMORY",      "SILVALLY_ICE" },
    { "SILVALLY", "DRAGON_MEMORY",   "SILVALLY_DRAGON" },
    { "SILVALLY", "DARK_MEMORY",     "SILVALLY_DARK" },
    { "SILVALLY", "FAIRY_MEMORY",    "SILVALLY_FAIRY" },
  }
  for _, row in ipairs(expected) do
    local species, item, formId = row[1], row[2], row[3]
    T.eq(rows[species] and rows[species][item], formId,
      species .. "'s " .. item .. " pairs with " .. formId)
    T.check(plateIndices[item] ~= nil or memoryIndices[item] ~= nil,
      item .. " has an indices-table entry (byteless or not)")
  end
  T.eq(#expected, 34, "seventeen Plates plus seventeen Memories is 34")

  local arceusCount, silvallyCount = 0, 0
  for _ in pairs(rows.ARCEUS or {}) do arceusCount = arceusCount + 1 end
  for _ in pairs(rows.SILVALLY or {}) do silvallyCount = silvallyCount + 1 end
  T.eq(arceusCount, 17, "Arceus wires exactly its seventeen Plates")
  T.eq(silvallyCount, 17, "Silvally wires exactly its seventeen Memories")
end

-- ------- the derivation -------------------------------------------------

do
  local mon = newMon("ARCEUS", "FLAME_PLATE")
  T.eq(Persistent.formIdFor(mon), "ARCEUS_FIRE",
    "the form is derived from the stamp, not remembered")
  T.eq(Persistent.formIdFor(newMon("ARCEUS", nil)), nil,
    "an unstamped Arceus is entitled to nothing")
  T.eq(Persistent.formIdFor(newMon("SILVALLY", "FLAME_PLATE")), nil,
    "and the pairing is per species -- a Plate on Silvally is inert")
  T.eq(Persistent.formIdFor(newMon("ARCEUS", "ELECTRIC_MEMORY")), nil,
    "a Memory does nothing off an Arceus either")
  T.eq(Persistent.formIdFor(newMon("SILVALLY", "ELECTRIC_MEMORY")),
    "SILVALLY_ELECTRIC", "a Memory on Silvally resolves the way a Plate does")
end

-- ------- registration, byteless -----------------------------------------

local function fakeMod()
  local mod = { items = {}, effects = {}, errors = {} }
  mod.content = {
    items = { register = function(_, id, record) mod.items[id] = record end },
    item_effects = {
      register = function(_, id, record) mod.effects[id] = record end },
  }
  mod.log = { error = function(_, fmt, ...)
    mod.errors[#mod.errors + 1] = string.format(fmt, ...)
  end }
  return mod
end

local byteless = {}
for itemId in pairs(plateIndices) do byteless[itemId] = true end
for itemId in pairs(memoryIndices) do byteless[itemId] = true end

local installed = fakeMod()
Persistent.install(installed, rows, indices)

do
  T.eq(#installed.errors, 0,
    "a complete plates+memories index table installs without complaint, "
      .. "`false` included")
  for itemId in pairs(byteless) do
    local record = installed.items[itemId]
    T.check(record ~= nil, itemId .. " is registered as an item")
    T.eq(record.index, nil,
      itemId .. " carries no `index` field -- `false` becomes nil, not the "
        .. "literal boolean, since GenSave.lua's crosswalk only ever tests "
        .. "`def.index ~= nil`")
    T.eq(record.price, Stone.PRICE, "priced like the other form items")
    T.eq(record.needsTarget, true, "and used on a Pokemon rather than the bag")
    local effect = installed.effects[itemId]
    T.check(effect ~= nil, itemId .. " registers an item effect")
    T.eq(effect.battle, false,
      "refused mid-battle by the engine before it can write to the save")
  end
end

-- A row naming an item genuinely missing from BOTH indices tables is still a
-- hard refusal -- `false` is a deliberate answer, an absent key is not, and
-- src/persistent.lua's install() has to keep telling the two apart.  Scoped
-- to exactly two items (one indexed, one not) so which one is missing is
-- unambiguous -- pairs() over the full seventeen-row table would still name
-- the one real gap, but leaves nothing to say the OTHER fifteen entries in
-- the assertion below are not what triggered it.
do
  local mod = fakeMod()
  Persistent.install(mod, { ARCEUS = { FIST_PLATE = rows.ARCEUS.FIST_PLATE,
                                       SKY_PLATE = rows.ARCEUS.SKY_PLATE } },
    { FIST_PLATE = false })
  T.check(mod.items.FIST_PLATE ~= nil, "the indexed one registers")
  T.eq(mod.items.SKY_PLATE, nil, "an unindexed one does not")
  T.eq(#mod.errors, 1, "and the refusal is reported, exactly once")
  T.check(mod.errors[1]:find("SKY_PLATE", 1, true) ~= nil,
    "naming the item it is about")
  T.check(mod.errors[1]:find("data/plates.lua", 1, true) ~= nil
    and mod.errors[1]:find("data/memories.lua", 1, true) ~= nil,
    "and both files it could be fixed in")
end

-- ------- using the item --------------------------------------------------

local flame = installed.effects.FLAME_PLATE.use
local electric = installed.effects.ELECTRIC_MEMORY.use

do
  local mon = newMon("ARCEUS", nil)
  local before = { species = mon.species, hp = mon.hp, stats = mon.stats,
                   moves = mon.moves }
  local result = flame({ data = DATA, target = mon })
  T.eq(result, "kept", "the item is not used up")
  T.eq(mon[E.STAMP], "FLAME_PLATE", "the Pokemon is stamped with it")
  T.eq(mon.form, "FIRE", "and carries the marker out of battle, in the save")

  T.eq(mon.species, before.species, "the species was never touched")
  T.eq(mon.stats, before.stats, "nor the stat block, by identity")
  T.eq(mon.hp, before.hp, "nor current HP")
  T.eq(mon.moves, before.moves, "nor the move array")
end

do
  -- The undo: using the same item again takes it back off.
  local mon = newMon("SILVALLY", nil)
  electric({ data = DATA, target = mon })
  T.eq(mon.form, "ELECTRIC", "the Electric Memory put Silvally in that form")
  local result = electric({ data = DATA, target = mon })
  T.eq(result, "kept", "using it again is not a refusal")
  T.eq(mon[E.STAMP], nil, "it takes the Memory back off")
  T.eq(mon.form, nil, "and the marker with it, so the save is clean again")
end

do
  local mon = newMon("ALAKAZAM", nil)
  local result = flame({ data = DATA, target = mon })
  T.eq(result, "failed", "the Flame Plate on the wrong species is refused")
  T.eq(mon[E.STAMP], nil, "and stamps nothing")
  T.eq(mon.form, nil, "and marks nothing")
end

-- The shared held-item slot: a Pokemon holding a Plate or a Memory is not
-- holding a mega stone or a Z-Crystal, the same guard every other family
-- here shares through the one stamp field.
do
  local mod = fakeMod()
  Stone.installUnpaired(mod, { "WATERIUM_Z" }, { WATERIUM_Z = 209 })
  local mon = newMon("ARCEUS", nil)
  flame({ data = DATA, target = mon })
  T.eq(mon.form, "FIRE", "the Arceus is in its Fire form")
  mod.effects.WATERIUM_Z.use({ data = DATA, target = mon })
  T.eq(mon[E.STAMP], "WATERIUM_Z", "the crystal takes the held slot")
  T.eq(mon.form, nil, "and the form goes with the item that entitled it")
end

-- ------- in battle ---------------------------------------------------

do
  local mon = newMon("ARCEUS", "SPLASH_PLATE")
  mon.form = "WATER"
  local battle = makeBattle({ mon })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(mon.form, "WATER", "the marker it arrived with is still on it")
  T.eq(battle.player.curTypes[1], "WATER",
    "and the battler took the form's types, computed rather than stored")
end

do
  -- makeBattler is form-blind, so a mon coming back from the bench needs the
  -- override put back, exactly as every other persistent form does.
  local mon = newMon("SILVALLY", "DARK_MEMORY")
  mon.form = "DARK"
  local battle = makeBattle({ mon })
  local fresh = battlerFor(mon, true)
  Persistent.onBattlerSwitched({ battle = battle, battler = fresh })
  T.eq(fresh.curTypes[1], "DARK", "switching in reapplies the form's types")
end

-- ------- the sweep -----------------------------------------------------

do
  local arceus = newMon("ARCEUS", "FLAME_PLATE")
  local zam = newMon("ALAKAZAM", "ALAKAZITE")
  arceus.form = "FIRE"
  local battle = makeBattle({ arceus, zam })

  Forms.becomeForm(DATA, battlerFor(zam, true), "ALAKAZAM_MEGA", nil)
  T.eq(zam.form, "MEGA", "the Alakazam megaed")

  Resolve.onBattleEnded({ battle = battle })

  T.eq(zam.form, nil, "the battle form did NOT survive the sweep")
  T.eq(arceus.form, "FIRE", "the persistent one did, on the very same sweep")
  T.eq(arceus.species, "ARCEUS", "and the species was never touched either way")
end

do
  local mon = newMon("SILVALLY", "ELECTRIC_MEMORY")
  mon.form = "ELECTRIC"
  local battle = makeBattle({ mon })
  Resolve.onFainted({ battle = battle, battler = battle.player })
  T.eq(mon.form, "ELECTRIC", "a fainted persistent mon keeps its marker")
end

-- ------- the guards, which must be loud --------------------------------

do
  -- An orphan: a stamp with no matching record the running data can resolve.
  local before = #warnings
  local mon = newMon("ARCEUS", "MIND_PLATE")
  mon.form = "PSYCHIC"
  local claimed = Persistent.settle({ pokemon = { ARCEUS = DATA.pokemon.ARCEUS } },
                                    mon)
  T.eq(claimed, true, "the module still claims the Pokemon")
  T.eq(mon.form, nil, "but refuses to vouch for a form it cannot resolve")
  T.eq(mon[E.STAMP], "MIND_PLATE", "leaving the item that names it in place")
  T.check(#warnings > before, "and says so out loud")
  T.check(warnings[#warnings]:find("ARCEUS_PSYCHIC", 1, true) ~= nil,
    "naming the form it could not resolve")
end

-- ------- the shelf, sorted with no byte to sort by ----------------------

do
  local Registry = require("src.mods.Registry")
  local Schemas = require("src.mods.Schemas")
  local base = { IndigoPlateauLobby = { TEXT_INDIGOPLATEAULOBBY_CLERK = {
    label = "IndigoPlateauLobbyClerkText",
    mart = { "POKE_DOLL", "FULL_RESTORE" },
  } } }
  local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
  reg.base = function() return base end
  local mod = { content = { text_pointers = {
    patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
  } } }

  Shop.installPlates(mod, plateIndices)
  local mart = reg:get("IndigoPlateauLobby").TEXT_INDIGOPLATEAULOBBY_CLERK.mart
  local sells = {}
  for _, id in ipairs(mart) do sells[id] = true end
  T.check(sells.POKE_DOLL, "the counter still sells what it always did")
  local count = 0
  for itemId in pairs(plateIndices) do
    T.check(sells[itemId], itemId .. " is on the shelf despite carrying no byte")
    count = count + 1
  end
  T.eq(#mart, 2 + count, "and nothing else was added to it")

  -- Every plate is `false`, so the whole seventeen sort by the fallback rule
  -- alone: alphabetical by item id.
  local plateNames = {}
  for _, id in ipairs(mart) do
    if plateIndices[id] ~= nil then plateNames[#plateNames + 1] = id end
  end
  local sorted = {}
  for i, id in ipairs(plateNames) do sorted[i] = id end
  table.sort(sorted)
  T.eq(table.concat(plateNames, ","), table.concat(sorted, ","),
    "with no bag byte to order by, the shelf falls back to alphabetical order")
end

-- Mixing a real byte with `false` entries on the SAME shelf call is exactly
-- what would happen if a future item joined one of these two files with a
-- real byte reclaimed from somewhere -- prove the comparator handles both
-- kinds together rather than only the all-`false` case above.  installPlates
-- is hard-wired to the Indigo Plateau counter, so this reuses that same call
-- rather than reaching into shelf() directly, with a synthetic indices table
-- standing in for data/plates.lua's real one.
do
  local Registry = require("src.mods.Registry")
  local Schemas = require("src.mods.Schemas")
  local base = { IndigoPlateauLobby = { TEXT_INDIGOPLATEAULOBBY_CLERK = {
    label = "IndigoPlateauLobbyClerkText", mart = {},
  } } }
  local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
  reg.base = function() return base end
  local mod = { content = { text_pointers = {
    patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
  } } }
  local mixed = { NUMBERED_LOW = 5, NUMBERED_HIGH = 9,
                  BYTELESS_B = false, BYTELESS_A = false }
  Shop.installPlates(mod, mixed)
  local mart = reg:get("IndigoPlateauLobby").TEXT_INDIGOPLATEAULOBBY_CLERK.mart
  T.eq(table.concat(mart, ","), "NUMBERED_LOW,NUMBERED_HIGH,BYTELESS_A,BYTELESS_B",
    "both numbered items sort by their byte, ahead of both byteless ones, "
      .. "which sort alphabetically among themselves")
end

T.finish("battle_forms_plates")
