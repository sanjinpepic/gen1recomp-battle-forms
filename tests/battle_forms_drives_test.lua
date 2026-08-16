-- Genesect's four Drives: Douse, Shock, Burn and Chill.  Same mechanism as
-- tests/battle_forms_heldforms_test.lua top to bottom -- one item, stamped on
-- the mon, deriving a marker the battle-end sweep vouches for or clears -- and
-- this suite is deliberately narrow for the same reason that one is: it pins
-- that these four rows are wired correctly and share the mechanism, not the
-- mechanism itself.
--
-- The one thing genuinely worth a dedicated suite over folding these four
-- into tests/battle_forms_heldforms_test.lua: a Drive changes NOTHING a form
-- record here can hold except identity and art, not even typing (see
-- data/persistent.lua's own comment on why).  The derivation, sweep and shop
-- checks below prove that holds up mechanically -- becomeForm still swaps
-- `curTypes` even when the before and after types are byte-for-byte the same
-- list -- and the cosmetic-only claim is pinned outright rather than only
-- implied by the fixture data.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local Shop = dofile(MOD .. "/src/shop.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Stats = require("src.pokemon.Stats")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local rows = dofile(MOD .. "/data/persistent.lua")
local applianceIndices = dofile(MOD .. "/data/appliances.lua")
local heldFormIndices = dofile(MOD .. "/data/heldforms.lua")
local plateIndices = dofile(MOD .. "/data/plates.lua")
local memoryIndices = dofile(MOD .. "/data/memories.lua")
local driveIndices = dofile(MOD .. "/data/drives.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- `rows` is the WHOLE of data/persistent.lua, every other family included --
-- see those families' own suites -- so the merged `indices` below has to
-- resolve every item they name too, or the "complete merged index table
-- installs without complaint" check a few lines down would fail for a reason
-- that has nothing to do with this file's own four.
local indices = {}
for itemId, index in pairs(applianceIndices) do indices[itemId] = index end
for itemId, index in pairs(heldFormIndices) do indices[itemId] = index end
for itemId, index in pairs(plateIndices) do indices[itemId] = index end
for itemId, index in pairs(memoryIndices) do indices[itemId] = index end
for itemId, index in pairs(driveIndices) do indices[itemId] = index end

-- Alakazam and its mega ride along on the sweep check below for the same
-- reason it does in the other suites: a sweep that keeps everything is as
-- broken as one that keeps nothing.
local DATA = { pokemon = {
  GENESECT = { baseStats = { hp = 71, attack = 120, defense = 95,
                             speed = 99, special = 120 },
               types = { "BUG", "STEEL" } },
  GENESECT_DOUSE = { baseStats = { hp = 71, attack = 120, defense = 95,
                                   speed = 99, special = 120 },
                     types = { "BUG", "STEEL" }, form = "DOUSE" },
  GENESECT_SHOCK = { baseStats = { hp = 71, attack = 120, defense = 95,
                                   speed = 99, special = 120 },
                     types = { "BUG", "STEEL" }, form = "SHOCK" },
  GENESECT_BURN = { baseStats = { hp = 71, attack = 120, defense = 95,
                                  speed = 99, special = 120 },
                    types = { "BUG", "STEEL" }, form = "BURN" },
  GENESECT_CHILL = { baseStats = { hp = 71, attack = 120, defense = 95,
                                   speed = 99, special = 120 },
                     types = { "BUG", "STEEL" }, form = "CHILL" },
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
                  price = Stone.PRICE, battlerof = Battlerof })
Resolve.bind({ forms = Forms, eligibility = E, megas = megas,
               persistent = Persistent, battlerof = Battlerof })
Stone.bind(E, Persistent)

-- ------- the data table names all four outright -----------------------

do
  local expected = {
    { "DOUSE_DRIVE", "GENESECT_DOUSE" },
    { "SHOCK_DRIVE", "GENESECT_SHOCK" },
    { "BURN_DRIVE",  "GENESECT_BURN" },
    { "CHILL_DRIVE", "GENESECT_CHILL" },
  }
  for _, row in ipairs(expected) do
    local item, formId = row[1], row[2]
    T.eq(rows.GENESECT and rows.GENESECT[item], formId,
      "data/persistent.lua still pairs Genesect's " .. item .. " with " .. formId)
  end
  local count = 0
  for _ in pairs(rows.GENESECT or {}) do count = count + 1 end
  T.eq(count, 4, "Genesect wires exactly its four Drives")

  for _, row in ipairs(expected) do
    local item = row[1]
    T.check(driveIndices[item] ~= nil,
      item .. " has a bag byte -- an item with none cannot exist in a save")
    T.eq(driveIndices[item], driveIndices[item] and math.floor(driveIndices[item]),
      item .. "'s byte is an integer, not the byteless `false` sentinel "
        .. "data/plates.lua and data/memories.lua needed")
    T.check(driveIndices[item] > 233,
      item .. "'s byte continues past Ultranecrozium Z rather than reusing one")
    T.check(driveIndices[item] <= 255,
      item .. "'s byte stays inside the single-byte item space")
  end
end

-- ------- the derivation -------------------------------------------------

do
  local mon = newMon("GENESECT", "DOUSE_DRIVE")
  T.eq(Persistent.formIdFor(mon), "GENESECT_DOUSE",
    "the form is derived from the stamp, not remembered")
  T.eq(Persistent.formIdFor(newMon("GENESECT", nil)), nil,
    "an unstamped Genesect is entitled to nothing")
  T.eq(Persistent.formIdFor(newMon("ALAKAZAM", "SHOCK_DRIVE")), nil,
    "and the pairing is per species -- a Drive on anything else is inert")
end

-- ------- registration, real bytes ---------------------------------------

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
  for _, itemId in ipairs({ "DOUSE_DRIVE", "SHOCK_DRIVE", "BURN_DRIVE", "CHILL_DRIVE" }) do
    local record = installed.items[itemId]
    T.check(record ~= nil, itemId .. " is registered as an item")
    T.eq(record.index, driveIndices[itemId], "with its permanent bag byte")
    T.eq(record.price, Stone.PRICE, "priced like the other form items")
    T.eq(record.needsTarget, true, "and used on a Pokemon rather than the bag")
    local effect = installed.effects[itemId]
    T.check(effect ~= nil, itemId .. " registers an item effect")
    T.eq(effect.battle, false,
      "refused mid-battle by the engine before it can write to the save")
  end
end

-- An index table missing one of the four still installs the rest, and still
-- says which file to fix -- scoped to exactly two items (one indexed, one
-- not) so which one is missing is unambiguous, the same way
-- tests/battle_forms_plates_test.lua scopes its own version of this check:
-- pairs() gives no ordering guarantee across more than one missing entry.
do
  local mod = fakeMod()
  Persistent.install(mod, { GENESECT = { DOUSE_DRIVE = rows.GENESECT.DOUSE_DRIVE,
                                         SHOCK_DRIVE = rows.GENESECT.SHOCK_DRIVE } },
    { DOUSE_DRIVE = 234 })
  T.check(mod.items.DOUSE_DRIVE ~= nil, "the indexed one registers")
  T.eq(mod.items.SHOCK_DRIVE, nil, "an unindexed one does not")
  T.eq(#mod.errors, 1, "and the refusal is reported, exactly once")
  T.check(mod.errors[1]:find("SHOCK_DRIVE", 1, true) ~= nil,
    "naming the item it is about")
  T.check(mod.errors[1]:find("data/drives.lua", 1, true) ~= nil,
    "and the file to fix it in")
end

-- ------- using the item --------------------------------------------------

local douse = installed.effects.DOUSE_DRIVE.use
local burn = installed.effects.BURN_DRIVE.use

do
  local mon = newMon("GENESECT", nil)
  local before = { species = mon.species, hp = mon.hp, stats = mon.stats,
                   moves = mon.moves }
  local result = douse({ data = DATA, target = mon })
  T.eq(result, "kept", "the item is not used up")
  T.eq(mon[E.STAMP], "DOUSE_DRIVE", "the Pokemon is stamped with it")
  T.eq(mon.form, "DOUSE", "and carries the marker out of battle, in the save")

  T.eq(mon.species, before.species, "the species was never touched")
  T.eq(mon.stats, before.stats, "nor the stat block, by identity")
  T.eq(mon.hp, before.hp, "nor current HP")
  T.eq(mon.moves, before.moves, "nor the move array")
end

do
  -- The undo: using the same item again takes it back off.
  local mon = newMon("GENESECT", nil)
  burn({ data = DATA, target = mon })
  T.eq(mon.form, "BURN", "the Burn Drive put Genesect in that form")
  local result = burn({ data = DATA, target = mon })
  T.eq(result, "kept", "using it again is not a refusal")
  T.eq(mon[E.STAMP], nil, "it takes the Burn Drive back off")
  T.eq(mon.form, nil, "and the marker with it, so the save is clean again")
end

do
  local mon = newMon("ALAKAZAM", nil)
  local result = douse({ data = DATA, target = mon })
  T.eq(result, "failed", "the Douse Drive on the wrong species is refused")
  T.eq(mon[E.STAMP], nil, "and stamps nothing")
  T.eq(mon.form, nil, "and marks nothing")
end

-- The shared held-item slot: a Pokemon holding a Drive is not holding a mega
-- stone or a Z-Crystal, the same guard every other family here shares
-- through the one stamp field.
do
  local mod = fakeMod()
  Stone.installUnpaired(mod, { "WATERIUM_Z" }, { WATERIUM_Z = 209 })
  local mon = newMon("GENESECT", nil)
  douse({ data = DATA, target = mon })
  T.eq(mon.form, "DOUSE", "the Genesect is in Douse form")
  mod.effects.WATERIUM_Z.use({ data = DATA, target = mon })
  T.eq(mon[E.STAMP], "WATERIUM_Z", "the crystal takes the held slot")
  T.eq(mon.form, nil, "and the form goes with the item that entitled it")
end

-- ------- in battle: cosmetic only ----------------------------------------

do
  local mon = newMon("GENESECT", "SHOCK_DRIVE")
  mon.form = "SHOCK"
  local battle = makeBattle({ mon })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(mon.form, "SHOCK", "the marker it arrived with is still on it")
  -- The cosmetic claim, pinned mechanically rather than merely by fixture:
  -- becomeForm always recomputes curStats through Stats.calc against the
  -- FORM's own record (src/forms.lua), so the honest comparison is against
  -- what that same formula gives the base species at the same level/DVs/stat
  -- exp -- not against mon.stats, which this suite's fixtures set to the raw
  -- baseStats rather than a calculated stat (see newMon above; every other
  -- persistent-form suite compares with an inequality for exactly this
  -- reason).  A real numeric difference here would mean SOME field in
  -- GENESECT_DOUSE/SHOCK/BURN/CHILL's baseStats diverged from GENESECT's own.
  local baseline = Stats.calc(DATA.pokemon.GENESECT, mon.level, mon.dvs, mon.statExp)
  T.eq(battle.player.curStats.attack, baseline.attack,
    "the computed stat is identical to what a plain Genesect would carry")
  T.eq(battle.player.curStats.hp, baseline.hp, "every stat, not just attack")
  T.eq(battle.player.curStats.special, baseline.special, "special included")
  T.check(battle.player.curStats ~= mon.stats,
    "but it is still a FRESH table, computed like every other form here, "
      .. "not merely left pointing at the mon's own stats")
  T.eq(battle.player.curTypes[1], "BUG", "typing is unchanged by the Drive")
  T.eq(battle.player.curTypes[2], "STEEL", "both slots, unchanged")
end

do
  -- makeBattler is form-blind, so a mon coming back from the bench needs the
  -- override put back, exactly as every other persistent form does.
  local mon = newMon("GENESECT", "CHILL_DRIVE")
  mon.form = "CHILL"
  local battle = makeBattle({ mon })
  local fresh = battlerFor(mon, true)
  Persistent.onBattlerSwitched({ battle = battle, battler = fresh })
  T.eq(fresh.curTypes[1], "BUG", "switching in reapplies the form -- same typing")
end

-- ------- the sweep -----------------------------------------------------

do
  local genesect = newMon("GENESECT", "DOUSE_DRIVE")
  local zam = newMon("ALAKAZAM", "ALAKAZITE")
  genesect.form = "DOUSE"
  local battle = makeBattle({ genesect, zam })

  Forms.becomeForm(DATA, battlerFor(zam, true), "ALAKAZAM_MEGA", nil)
  T.eq(zam.form, "MEGA", "the Alakazam megaed")

  Resolve.onBattleEnded({ battle = battle })

  T.eq(zam.form, nil, "the battle form did NOT survive the sweep")
  T.eq(genesect.form, "DOUSE", "the persistent one did, on the very same sweep")
  T.eq(genesect.species, "GENESECT", "and the species was never touched either way")
end

do
  local mon = newMon("GENESECT", "CHILL_DRIVE")
  mon.form = "CHILL"
  local battle = makeBattle({ mon })
  Resolve.onFainted({ battle = battle, battler = battle.player })
  T.eq(mon.form, "CHILL", "a fainted persistent mon keeps its marker")
end

-- ------- the guards, which must be loud --------------------------------

do
  -- An orphan: a stamp with no matching record the running data can resolve.
  local before = #warnings
  local mon = newMon("GENESECT", "SHOCK_DRIVE")
  mon.form = "SHOCK"
  local claimed = Persistent.settle({ pokemon = { GENESECT = DATA.pokemon.GENESECT } },
                                    mon)
  T.eq(claimed, true, "the module still claims the Pokemon")
  T.eq(mon.form, nil, "but refuses to vouch for a form it cannot resolve")
  T.eq(mon[E.STAMP], "SHOCK_DRIVE", "leaving the item that names it in place")
  T.check(#warnings > before, "and says so out loud")
  T.check(warnings[#warnings]:find("GENESECT_SHOCK", 1, true) ~= nil,
    "naming the form it could not resolve")
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

  Shop.installDrives(mod, driveIndices)
  local mart = reg:get("IndigoPlateauLobby").TEXT_INDIGOPLATEAULOBBY_CLERK.mart
  local sells = {}
  for _, id in ipairs(mart) do sells[id] = true end
  T.check(sells.POKE_DOLL, "the counter still sells what it always did")
  local count = 0
  for itemId in pairs(driveIndices) do
    T.check(sells[itemId], itemId .. " is on the shelf")
    count = count + 1
  end
  T.eq(#mart, 2 + count, "and nothing else was added to it")
  local last = nil
  for _, id in ipairs(mart) do
    local index = driveIndices[id]
    if index then
      T.check(last == nil or index > last, id .. " stands in bag-byte order")
      last = index
    end
  end
end

T.finish("battle_forms_drives")
