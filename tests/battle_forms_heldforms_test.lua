-- The six persistent forms wired in 0.21.0 beside Rotom's five appliances:
-- Giratina, Palkia, Dialga, Zacian, Zamazenta and Shaymin.  Every one of them
-- goes through src/persistent.lua exactly the way an appliance does -- one
-- item, stamped on the mon, deriving a marker the battle-end sweep vouches
-- for or clears -- so this suite is deliberately narrower than
-- tests/battle_forms_persistent_test.lua rather than a second copy of it: it
-- pins that these six rows are wired correctly and that they share the
-- mechanism, not the mechanism itself.
--
-- Two species carry the weight of the individual checks -- Giratina for the
-- ordinary path, Shaymin for the guards -- and the data-table section below
-- names all six outright, for the reason data/persistent.lua's own comment
-- gives: a pairing quietly dropped would only make the sweep one row shorter
-- and nothing would fail on its own.
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
-- `rows` is the WHOLE of data/persistent.lua, Arceus, Silvally and Genesect
-- included -- see tests/battle_forms_plates_test.lua and
-- tests/battle_forms_drives_test.lua for their own suites -- so the merged
-- `indices` below has to resolve every item those three families name as
-- well, or the "complete merged index table installs without complaint"
-- check a few lines down would see items with no entry and fail for a reason
-- that has nothing to do with this file's own six.
local plateIndices = dofile(MOD .. "/data/plates.lua")
local memoryIndices = dofile(MOD .. "/data/memories.lua")
local driveIndices = dofile(MOD .. "/data/drives.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local indices = {}
for itemId, index in pairs(applianceIndices) do indices[itemId] = index end
for itemId, index in pairs(heldFormIndices) do indices[itemId] = index end
for itemId, index in pairs(plateIndices) do indices[itemId] = index end
for itemId, index in pairs(memoryIndices) do indices[itemId] = index end
for itemId, index in pairs(driveIndices) do indices[itemId] = index end

-- Alakazam and its mega ride along on the sweep check below for the same
-- reason they do in the other suite: a sweep that keeps everything is as
-- broken as one that keeps nothing.
local DATA = { pokemon = {
  GIRATINA = { baseStats = { hp = 150, attack = 100, defense = 120,
                             speed = 90, special = 100 },
               types = { "GHOST", "DRAGON" } },
  GIRATINA_ORIGIN = { baseStats = { hp = 150, attack = 120, defense = 100,
                                    speed = 90, special = 120 },
                      types = { "GHOST", "DRAGON" }, form = "ORIGIN" },
  SHAYMIN = { baseStats = { hp = 100, attack = 100, defense = 100,
                           speed = 100, special = 100 },
             types = { "GRASS" } },
  SHAYMIN_SKY = { baseStats = { hp = 100, attack = 103, defense = 75,
                               speed = 127, special = 120 },
                 types = { "GRASS", "FLYING" }, form = "SKY" },
  PALKIA = { baseStats = { hp = 90, attack = 100, defense = 100,
                          speed = 100, special = 100 },
            types = { "WATER", "DRAGON" } },
  PALKIA_ORIGIN = { baseStats = { hp = 90, attack = 100, defense = 100,
                                  speed = 120, special = 150 },
                    types = { "WATER", "DRAGON" }, form = "ORIGIN" },
  DIALGA = { baseStats = { hp = 100, attack = 100, defense = 100,
                          speed = 90, special = 100 },
            types = { "STEEL", "DRAGON" } },
  DIALGA_ORIGIN = { baseStats = { hp = 100, attack = 100, defense = 120,
                                  speed = 90, special = 150 },
                    types = { "STEEL", "DRAGON" }, form = "ORIGIN" },
  ZACIAN = { baseStats = { hp = 92, attack = 130, defense = 100,
                          speed = 138, special = 100 },
            types = { "FAIRY" } },
  ZACIAN_CROWNED = { baseStats = { hp = 92, attack = 150, defense = 115,
                                   speed = 148, special = 115 },
                     types = { "FAIRY", "STEEL" }, form = "CROWNED" },
  ZAMAZENTA = { baseStats = { hp = 92, attack = 130, defense = 100,
                             speed = 128, special = 100 },
               types = { "FIGHTING" } },
  ZAMAZENTA_CROWNED = { baseStats = { hp = 92, attack = 120, defense = 140,
                                      speed = 128, special = 140 },
                        types = { "FIGHTING", "STEEL" }, form = "CROWNED" },
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

-- ------- the data table names all six outright -----------------------

do
  local expected = {
    { "GIRATINA",  "GRISEOUS_ORB",    "GIRATINA_ORIGIN" },
    { "PALKIA",    "LUSTROUS_GLOBE",  "PALKIA_ORIGIN" },
    { "DIALGA",    "ADAMANT_CRYSTAL", "DIALGA_ORIGIN" },
    { "ZACIAN",    "RUSTED_SWORD",    "ZACIAN_CROWNED" },
    { "ZAMAZENTA", "RUSTED_SHIELD",   "ZAMAZENTA_CROWNED" },
    { "SHAYMIN",   "GRACIDEA",        "SHAYMIN_SKY" },
  }
  for _, row in ipairs(expected) do
    local species, item, formId = row[1], row[2], row[3]
    T.eq(rows[species] and rows[species][item], formId,
      species .. "'s " .. item .. " still pairs with " .. formId)
    local count = 0
    for _ in pairs(rows[species] or {}) do count = count + 1 end
    T.eq(count, 1, species .. " wires exactly its one item")
  end

  for _, row in ipairs(expected) do
    local item = row[2]
    T.check(heldFormIndices[item] ~= nil,
      item .. " has a bag byte -- an item with none cannot exist in a save")
    T.check(heldFormIndices[item] > 226,
      item .. "'s byte continues past the fusion items rather than reusing one")
  end
end

-- ------- the derivation -----------------------------------------------

do
  local mon = newMon("GIRATINA", "GRISEOUS_ORB")
  T.eq(Persistent.formIdFor(mon), "GIRATINA_ORIGIN",
    "the form is derived from the stamp, not remembered")
  T.eq(Persistent.formIdFor(newMon("GIRATINA", nil)), nil,
    "an unstamped Giratina is entitled to nothing")
  T.eq(Persistent.formIdFor(newMon("SHAYMIN", "GRISEOUS_ORB")), nil,
    "and the pairing is per species -- the Orb on anything else is inert")
  T.eq(Persistent.formIdFor(newMon("ALAKAZAM", "GRACIDEA")), nil,
    "a Gracidea does nothing off a Shaymin either")
end

-- ------- registration, merged across both shelves ---------------------

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

local installed = fakeMod()
Persistent.install(installed, rows, indices)

do
  T.eq(#installed.errors, 0, "a complete merged index table installs without complaint")
  for _, itemId in ipairs({ "GRISEOUS_ORB", "LUSTROUS_GLOBE", "ADAMANT_CRYSTAL",
                            "RUSTED_SWORD", "RUSTED_SHIELD", "GRACIDEA" }) do
    local record = installed.items[itemId]
    T.check(record ~= nil, itemId .. " is registered as an item")
    T.eq(record.index, heldFormIndices[itemId], "with its permanent bag byte")
    T.eq(record.price, Stone.PRICE, "priced like the other form items")
    T.eq(record.needsTarget, true, "and used on a Pokemon rather than the bag")
    local effect = installed.effects[itemId]
    T.check(effect ~= nil, itemId .. " registers an item effect")
    T.eq(effect.battle, false,
      "refused mid-battle by the engine before it can write to the save")
  end
end

-- An index table missing one of the six still installs the rest, and still
-- says which file to fix -- scoped to just this family so the count is not
-- coupled to Rotom's five appliances riding along in the same call.
do
  local mod = fakeMod()
  Persistent.install(mod, { GIRATINA = rows.GIRATINA, SHAYMIN = rows.SHAYMIN },
    { GRISEOUS_ORB = 227 })
  T.check(mod.items.GRISEOUS_ORB ~= nil, "the indexed one registers")
  T.eq(mod.items.GRACIDEA, nil, "an unindexed one does not")
  T.eq(#mod.errors, 1, "and the refusal is reported")
  T.check(mod.errors[1]:find("GRACIDEA", 1, true) ~= nil,
    "naming the item it is about")
  T.check(mod.errors[1]:find("data/heldforms.lua", 1, true) ~= nil,
    "and a file it could be fixed in")
end

-- ------- using the item -------------------------------------------

local orb = installed.effects.GRISEOUS_ORB.use
local gracidea = installed.effects.GRACIDEA.use

do
  local mon = newMon("GIRATINA", nil)
  local before = { species = mon.species, hp = mon.hp, stats = mon.stats,
                   moves = mon.moves }
  local result = orb({ data = DATA, target = mon })
  T.eq(result, "kept", "the item is not used up")
  T.eq(mon[E.STAMP], "GRISEOUS_ORB", "the Pokemon is stamped with it")
  T.eq(mon.form, "ORIGIN", "and carries the marker out of battle, in the save")

  T.eq(mon.species, before.species, "the species was never touched")
  T.eq(mon.stats, before.stats, "nor the stat block, by identity")
  T.eq(mon.stats.defense, 120, "which still holds the BASE form's numbers")
  T.eq(mon.hp, before.hp, "nor current HP")
  T.eq(mon.moves, before.moves, "nor the move array")
end

do
  -- The undo: using the same item again takes it back off, the way an
  -- appliance does.
  local mon = newMon("SHAYMIN", nil)
  gracidea({ data = DATA, target = mon })
  T.eq(mon.form, "SKY", "the Gracidea put Shaymin in Sky Forme")
  local result = gracidea({ data = DATA, target = mon })
  T.eq(result, "kept", "using it again is not a refusal")
  T.eq(mon[E.STAMP], nil, "it takes the Gracidea back off")
  T.eq(mon.form, nil, "and the marker with it, so the save is clean again")
end

do
  local mon = newMon("ALAKAZAM", nil)
  local result = orb({ data = DATA, target = mon })
  T.eq(result, "failed", "the Griseous Orb on the wrong species is refused")
  T.eq(mon[E.STAMP], nil, "and stamps nothing")
  T.eq(mon.form, nil, "and marks nothing")
end

-- The shared held-item slot: a Pokemon holding one of these six items is not
-- holding a mega stone, exactly as data/persistent.lua's Rotom rows already
-- prove, and the same guard covers all seven families through the one stamp.
do
  local mod = fakeMod()
  Stone.installUnpaired(mod, { "WATERIUM_Z" }, { WATERIUM_Z = 209 })
  local mon = newMon("GIRATINA", nil)
  orb({ data = DATA, target = mon })
  T.eq(mon.form, "ORIGIN", "the Giratina is in Origin Forme")
  mod.effects.WATERIUM_Z.use({ data = DATA, target = mon })
  T.eq(mon[E.STAMP], "WATERIUM_Z", "the crystal takes the held slot")
  T.eq(mon.form, nil, "and the form goes with the item that entitled it")
end

-- ------- in battle ---------------------------------------------------

do
  local mon = newMon("GIRATINA", "GRISEOUS_ORB")
  mon.form = "ORIGIN"
  local battle = makeBattle({ mon })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(mon.form, "ORIGIN", "the marker it arrived with is still on it")
  T.eq(battle.player.curStats.attack > mon.stats.attack, true,
    "and the battler took the form's stats, computed rather than stored")
  T.eq(mon.stats.attack, 100, "while the mon's own block is left alone")
end

do
  -- makeBattler is form-blind, so a mon coming back from the bench needs the
  -- override put back, exactly as an appliance does.
  local mon = newMon("SHAYMIN", "GRACIDEA")
  mon.form = "SKY"
  local battle = makeBattle({ mon })
  local fresh = battlerFor(mon, true)
  Persistent.onBattlerSwitched({ battle = battle, battler = fresh })
  T.eq(fresh.curTypes[2], "FLYING", "switching in reapplies the form's types")
  T.eq(fresh.curStats.speed > mon.stats.speed, true, "and its stats")
end

-- ------- the sweep -----------------------------------------------------

do
  local giratina = newMon("GIRATINA", "GRISEOUS_ORB")
  local zam = newMon("ALAKAZAM", "ALAKAZITE")
  giratina.form = "ORIGIN"
  local battle = makeBattle({ giratina, zam })

  Forms.becomeForm(DATA, battlerFor(zam, true), "ALAKAZAM_MEGA", nil)
  T.eq(zam.form, "MEGA", "the Alakazam megaed")

  Resolve.onBattleEnded({ battle = battle })

  T.eq(zam.form, nil, "the battle form did NOT survive the sweep")
  T.eq(giratina.form, "ORIGIN", "the persistent one did, on the very same sweep")
  T.eq(giratina.species, "GIRATINA", "and the species was never touched either way")
end

do
  local mon = newMon("ZACIAN", "RUSTED_SWORD")
  mon.form = "CROWNED"
  local battle = makeBattle({ mon })
  Resolve.onFainted({ battle = battle, battler = battle.player })
  T.eq(mon.form, "CROWNED", "a fainted persistent mon keeps its marker")
end

-- ------- the guards, which must be loud --------------------------------

do
  -- An orphan: a stamp with no matching record the running data can resolve.
  local before = #warnings
  local mon = newMon("DIALGA", "ADAMANT_CRYSTAL")
  mon.form = "ORIGIN"
  local claimed = Persistent.settle({ pokemon = { DIALGA = DATA.pokemon.DIALGA } },
                                    mon)
  T.eq(claimed, true, "the module still claims the Pokemon")
  T.eq(mon.form, nil, "but refuses to vouch for a form it cannot resolve")
  T.eq(mon[E.STAMP], "ADAMANT_CRYSTAL", "leaving the item that names it in place")
  T.check(#warnings > before, "and says so out loud")
  T.check(warnings[#warnings]:find("DIALGA_ORIGIN", 1, true) ~= nil,
    "naming the form it could not resolve")
end

do
  T.eq(Persistent.settle(DATA, newMon("ALAKAZAM", "ALAKAZITE")), false,
    "a mon with no pairing is not this module's to settle")
  T.eq(Persistent.settle(DATA, newMon("ZAMAZENTA", "RUSTED_SHIELD")), true,
    "and one with a pairing is")
end

-- ------- the shelf -----------------------------------------------------

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

  Shop.installHeldForms(mod, heldFormIndices)
  local mart = reg:get("IndigoPlateauLobby").TEXT_INDIGOPLATEAULOBBY_CLERK.mart
  local sells = {}
  for _, id in ipairs(mart) do sells[id] = true end
  T.check(sells.POKE_DOLL, "the counter still sells what it always did")
  local count = 0
  for itemId in pairs(heldFormIndices) do
    T.check(sells[itemId], itemId .. " is on the shelf")
    count = count + 1
  end
  T.eq(#mart, 2 + count, "and nothing else was added to it")
  local last = nil
  for _, id in ipairs(mart) do
    local index = heldFormIndices[id]
    if index then
      T.check(last == nil or index > last, id .. " stands in bag-byte order")
      last = index
    end
  end
end

T.finish("battle_forms_heldforms")
