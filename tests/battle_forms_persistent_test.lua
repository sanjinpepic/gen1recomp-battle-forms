-- The form that outlives the battle, and the one thing in this mod that
-- deliberately writes into a player's save.
--
-- Half of this suite is about what a persistent form does; the other half is
-- about what it must not do, and that half matters more.  Every other form here
-- is safe because the battle takes it away again, and this one gives that up --
-- so a check that a Rotom-Wash is still Rotom-Wash after the battle proves
-- nothing on its own unless a mega on the same Pokemon still is not.
--
-- The four fields that are never written are pinned as hard as the two that
-- are: mon.species, because SaveData.validate quarantines a mon whose species
-- is not a record; mon.stats, because the party menu reads that block directly
-- and a level-up recomputes it from the base species; mon.hp and mon.moves,
-- because they are the save too.  Between them they are the reason the worst a
-- bug here can do is show the wrong picture for one battle.
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
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- Alakazam and its mega ride along so the battle-scoped half of the mod can be
-- exercised on the SAME sweep as the persistent half.  A sweep that keeps
-- everything is as broken as one that keeps nothing, and only a fixture holding
-- both kinds can tell the two failures apart.
local DATA = { pokemon = {
  ROTOM = { baseStats = { hp = 50, attack = 50, defense = 77,
                          speed = 91, special = 95 },
            types = { "ELECTRIC", "GHOST" } },
  ROTOM_WASH = { baseStats = { hp = 50, attack = 65, defense = 107,
                               speed = 86, special = 107 },
                 types = { "ELECTRIC", "WATER" }, form = "WASH" },
  ROTOM_HEAT = { baseStats = { hp = 50, attack = 65, defense = 107,
                               speed = 86, special = 107 },
                 types = { "ELECTRIC", "FIRE" }, form = "HEAT" },
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

local function makeBattle(party, enemyMon)
  return {
    data = DATA, phase = "menu", queue = {},
    player = battlerFor(party[1], true),
    enemy = enemyMon and battlerFor(enemyMon, false) or nil,
    game = { save = { party = party, inventory = {} } },
    enemyParty = enemyMon and { enemyMon } or {},
  }
end

-- A log that remembers, because half the guards below are required to be loud
-- and a silent refusal is exactly the failure they exist to prevent.
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

-- ------- the data table says what it means ---------------------------

do
  T.eq(rows.ROTOM and rows.ROTOM.WASHING_MACHINE, "ROTOM_WASH",
    "the washing machine pairs with the Wash form's record key")
  local count = 0
  for _ in pairs(rows.ROTOM or {}) do count = count + 1 end
  T.eq(count, 5, "five appliances are wired")
  for itemId in pairs(rows.ROTOM or {}) do
    T.check(applianceIndices[itemId] ~= nil,
      itemId .. " has a bag byte -- an item with none cannot exist in a save")
    T.check(applianceIndices[itemId] > 217,
      itemId .. "'s byte continues past the crystals rather than reusing one")
  end
end

-- ------- the derivation, which is the whole safety argument ----------

do
  local mon = newMon("ROTOM", "WASHING_MACHINE")
  T.eq(Persistent.formIdFor(mon), "ROTOM_WASH",
    "the form is derived from the stamp, not remembered")
  T.eq(Persistent.formIdFor(newMon("ROTOM", nil)), nil,
    "an unstamped Rotom is entitled to nothing")
  T.eq(Persistent.formIdFor(newMon("ALAKAZAM", "WASHING_MACHINE")), nil,
    "and the pairing is per species -- an appliance on anything else is inert")
end

-- ------- the item ----------------------------------------------------

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
Persistent.install(installed, rows, applianceIndices)

do
  T.eq(#installed.errors, 0, "a complete index table installs without complaint")
  for itemId in pairs(rows.ROTOM) do
    local record = installed.items[itemId]
    T.check(record ~= nil, itemId .. " is registered as an item")
    T.eq(record.index, applianceIndices[itemId], "with its permanent bag byte")
    T.eq(record.price, Stone.PRICE, "priced like the other form items")
    T.eq(record.needsTarget, true, "and used on a Pokemon rather than the bag")
    local effect = installed.effects[itemId]
    T.check(effect ~= nil, itemId .. " registers an item effect")
    T.eq(effect.battle, false,
      "refused mid-battle by the engine before it can write to the save")
  end
end

do
  local mod = fakeMod()
  Persistent.install(mod, rows, { WASHING_MACHINE = 219 })
  T.check(mod.items.WASHING_MACHINE ~= nil, "the indexed one registers")
  T.eq(mod.items.MICROWAVE_OVEN, nil, "an unindexed one does not")
  T.eq(#mod.errors, 4, "and each refusal is reported")
  T.check(mod.errors[1]:find("data/appliances.lua", 1, true) ~= nil,
    "naming the file to fix it in")
end

local washer = installed.effects.WASHING_MACHINE.use
local oven = installed.effects.MICROWAVE_OVEN.use

do
  local mon = newMon("ROTOM", nil)
  local before = { species = mon.species, hp = mon.hp, stats = mon.stats,
                   moves = mon.moves }
  local result = washer({ data = DATA, target = mon })
  T.eq(result, "kept", "the appliance is not used up")
  T.eq(mon[E.STAMP], "WASHING_MACHINE", "the Pokemon is stamped with it")
  T.eq(mon.form, "WASH", "and carries the marker out of battle, in the save")

  T.eq(mon.species, before.species, "the species was never touched")
  T.eq(mon.stats, before.stats, "nor the stat block, by identity")
  T.eq(mon.stats.speed, 91, "which still holds the BASE form's numbers")
  T.eq(mon.hp, before.hp, "nor current HP")
  T.eq(mon.moves, before.moves, "nor the move array")
end

do
  -- The undo, and the reason this family has an install of its own.
  local mon = newMon("ROTOM", nil)
  washer({ data = DATA, target = mon })
  local result = washer({ data = DATA, target = mon })
  T.eq(result, "kept", "using the same appliance again is not a refusal")
  T.eq(mon[E.STAMP], nil, "it takes the appliance back off")
  T.eq(mon.form, nil, "and the marker with it, so the save is clean again")
end

do
  local mon = newMon("ROTOM", nil)
  washer({ data = DATA, target = mon })
  oven({ data = DATA, target = mon })
  T.eq(mon[E.STAMP], "MICROWAVE_OVEN", "a different appliance replaces the first")
  T.eq(mon.form, "HEAT", "and the marker follows the stamp rather than lingering")
end

do
  local mon = newMon("ALAKAZAM", nil)
  local result = washer({ data = DATA, target = mon })
  T.eq(result, "failed", "an appliance on the wrong species is refused")
  T.eq(mon[E.STAMP], nil, "and stamps nothing")
  T.eq(mon.form, nil, "and marks nothing")
  T.eq(washer({ data = DATA }), "failed", "and with no target at all")
end

-- Moving the stamp to another family takes the form off with it.  Without this
-- a Rotom-Wash given a Z-Crystal would keep appliance art with base stats
-- behind it -- the silent mismatch this mod exists not to have.
do
  local mod = fakeMod()
  Stone.installUnpaired(mod, { "WATERIUM_Z" }, { WATERIUM_Z = 209 })
  local mon = newMon("ROTOM", nil)
  washer({ data = DATA, target = mon })
  T.eq(mon.form, "WASH", "the Rotom is in its appliance form")
  mod.effects.WATERIUM_Z.use({ data = DATA, target = mon })
  T.eq(mon[E.STAMP], "WATERIUM_Z", "the crystal takes the held slot")
  T.eq(mon.form, nil, "and the form goes with the appliance that entitled it")
end

-- ------- in battle ---------------------------------------------------

do
  local mon = newMon("ROTOM", "WASHING_MACHINE")
  mon.form = "WASH"
  local battle = makeBattle({ mon })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(mon.form, "WASH", "the marker it arrived with is still on it")
  T.eq(battle.player.curTypes[2], "WATER",
    "and the battler took the form's types, not the base species'")
  T.eq(battle.player.curStats.defense > mon.stats.defense, true,
    "and the form's stats, computed rather than stored")
  T.eq(mon.stats.defense, 77, "while the mon's own block is left alone")
end

do
  -- makeBattler is form-blind, so a mon coming back from the bench arrives with
  -- base stats and needs the override put back.
  local mon = newMon("ROTOM", "WASHING_MACHINE")
  mon.form = "WASH"
  local battle = makeBattle({ mon })
  local fresh = battlerFor(mon, true)
  Persistent.onBattlerSwitched({ battle = battle, battler = fresh })
  T.eq(fresh.curTypes[2], "WATER", "switching in reapplies the form's types")
  T.eq(fresh.curStats.defense > mon.stats.defense, true, "and its stats")
end

do
  -- A persistent form is a baseline, not something that outranks a battle form:
  -- a mon another mechanic has already dressed is left exactly as it is.
  local mon = newMon("ROTOM", "WASHING_MACHINE")
  mon.form = "GMAX"
  local battle = makeBattle({ mon })
  local battler = battlerFor(mon, true)
  Persistent.apply(battle, battler)
  T.eq(mon.form, "GMAX", "a form some other mechanic applied is not overwritten")
  T.eq(battler.curTypes[2], "GHOST", "and its stats and types are left standing")
end

-- ------- the sweep, which is the point -------------------------------

do
  local rotom = newMon("ROTOM", "WASHING_MACHINE")
  local zam = newMon("ALAKAZAM", "ALAKAZITE")
  rotom.form = "WASH"
  local battle = makeBattle({ rotom, zam })

  -- The mega happens for real, through the same primitive the menu uses.
  Forms.becomeForm(DATA, battlerFor(zam, true), "ALAKAZAM_MEGA", nil)
  T.eq(zam.form, "MEGA", "the Alakazam megaed")

  Resolve.onBattleEnded({ battle = battle })

  T.eq(zam.form, nil, "the battle form did NOT survive the sweep")
  T.eq(rotom.form, "WASH", "the persistent one did, on the very same sweep")
  T.eq(rotom.species, "ROTOM", "and the species was never touched either way")
  T.eq(rotom.stats.defense, 77, "nor the stat block")
end

do
  -- The sweep does not merely spare a persistent mon: it OVERWRITES it from the
  -- pairing table, so a battle form standing on one cannot ride out on it.
  local rotom = newMon("ROTOM", "WASHING_MACHINE")
  rotom.form = "MEGA"
  Resolve.onBattleEnded({ battle = makeBattle({ rotom }) })
  T.eq(rotom.form, "WASH",
    "a battle form left on a persistent Pokemon is replaced, not kept")
end

do
  -- Both parties, because the sweep has always swept both.
  local enemy = newMon("ROTOM", "MICROWAVE_OVEN")
  local player = newMon("ALAKAZAM", "ALAKAZITE")
  player.form = "MEGA"
  local battle = makeBattle({ player }, enemy)
  Resolve.onBattleEnded({ battle = battle })
  T.eq(enemy.form, "HEAT", "an enemy Rotom keeps its form through the sweep")
  T.eq(player.form, nil, "and the player's mega still does not")
end

do
  -- A faint reverts at once; for a persistent form the base is not where it
  -- should land, because the player can open the party menu before the battle
  -- is over and the Pokemon is still what it was.
  local mon = newMon("ROTOM", "WASHING_MACHINE")
  mon.form = "WASH"
  local battle = makeBattle({ mon })
  Resolve.onFainted({ battle = battle, battler = battle.player })
  T.eq(mon.form, "WASH", "a fainted persistent mon keeps its marker")
end

do
  local mon = newMon("ALAKAZAM", "ALAKAZITE")
  mon.form = "MEGA"
  local battle = makeBattle({ mon })
  Resolve.onFainted({ battle = battle, battler = battle.player })
  T.eq(mon.form, nil, "where a fainted mega still loses its")
end

-- Nothing was bound differently for these two: the same Resolve handles both,
-- and it is the pairing table rather than a flag on the mon that separates them.

-- ------- through the save --------------------------------------------

do
  -- The save format is a schema-less Lua-literal writer that re-emits whatever
  -- keys it finds (src/core/SaveSerializer.lua walks pairs()), so a by-value
  -- copy is what a save and a reload actually do to a party mon.
  local mon = newMon("ROTOM", nil)
  washer({ data = DATA, target = mon })

  local copy = {}
  for k, v in pairs(mon) do copy[k] = v end
  T.eq(copy.form, "WASH", "the marker round-trips through the save by value")
  T.eq(copy[E.STAMP], "WASHING_MACHINE", "and so does the stamp it derives from")
  T.eq(Persistent.formIdFor(copy), "ROTOM_WASH",
    "so a reloaded Pokemon is still entitled to the form")

  -- And is still in it after the next battle it fights.
  local battle = makeBattle({ copy })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(battle.player.curTypes[2], "WATER", "and wears it when it next battles")
  Resolve.onBattleEnded({ battle = battle })
  T.eq(copy.form, "WASH", "and still after that battle ends")

  -- Boxing is a reference move in this engine, so both fields go with it.
  local party, box = { copy }, {}
  table.insert(box, table.remove(party, 1))
  table.insert(party, table.remove(box, 1))
  T.eq(party[1].form, "WASH", "the form survives a box deposit and withdraw")
end

do
  -- A mon that came back from a Game Boy .sav has neither field, because
  -- GenSave.lua rebuilds a byte-exact 44-byte struct with no room for either.
  -- It must simply be a plain Rotom -- not an error, and not a Pokemon wearing
  -- a form with nothing behind it.
  local reimported = newMon("ROTOM", nil)
  T.eq(reimported.form, nil, "a reimported Rotom carries no marker")
  T.eq(Persistent.formIdFor(reimported), nil, "and is entitled to none")
  local battle = makeBattle({ reimported })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(reimported.form, nil, "and stays plain when it battles")
  T.eq(battle.player.curTypes[2], "GHOST", "as its own base species")
  Resolve.onBattleEnded({ battle = battle })
  T.eq(reimported.form, nil, "and after")
end

-- ------- the guards, which must be loud ------------------------------

do
  -- An orphan: a marker with no stamp to entitle it, which is the only shape a
  -- HALF-lost round trip could take.  The battle-END sweep is what takes it
  -- off, because that is where the whole party is walked -- and the send-out
  -- handler deliberately does not, so that its correctness cannot depend on
  -- running before every other handler in the mod.
  local mon = newMon("ROTOM", nil)
  mon.form = "WASH"
  local battle = makeBattle({ mon })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(mon.form, "WASH", "the send-out handler reconciles nothing on its own")
  T.eq(battle.player.curTypes[2], "GHOST",
    "and applies nothing either, so an orphan is a wrong picture and never "
      .. "wrong stats")
  Resolve.onBattleEnded({ battle = battle })
  T.eq(mon.form, nil, "and the party sweep is what takes the orphan off")
end

do
  -- The bug that decision exists to prevent, pinned as a fact rather than left
  -- in a comment: the send-out handler must not take a form off a mon that some
  -- other transformation type put one on, whichever order the two run in.
  local mon = newMon("ROTOM", nil)
  mon.form = "PRIMAL"
  local battle = makeBattle({ mon })
  Persistent.onBattleStarted({ battle = battle })
  T.eq(mon.form, "PRIMAL",
    "a form another mechanic applied survives this module's send-out handler")
end

do
  -- A stamp naming a form the running data has no record for.  The marker is
  -- cleared rather than kept, because the stamp still names the appliance and
  -- the form comes back the moment the record does -- where a marker left
  -- standing would be art with no stats behind it.
  local before = #warnings
  local mon = newMon("ROTOM", "WASHING_MACHINE")
  mon.form = "WASH"
  local claimed = Persistent.settle({ pokemon = { ROTOM = DATA.pokemon.ROTOM } },
                                    mon)
  T.eq(claimed, true, "the module still claims the Pokemon")
  T.eq(mon.form, nil, "but refuses to vouch for a form it cannot resolve")
  T.eq(mon[E.STAMP], "WASHING_MACHINE", "leaving the item that names it in place")
  T.check(#warnings > before, "and says so out loud")
  T.check(warnings[#warnings]:find("ROTOM_WASH", 1, true) ~= nil,
    "naming the form it could not resolve")
end

do
  local before = #warnings
  local mon = newMon("ROTOM", "WASHING_MACHINE")
  local battler = battlerFor(mon, true)
  Persistent.apply({ data = { pokemon = {} } }, battler)
  T.check(#warnings > before, "a refused send-out is reported too")
  T.check(warnings[#warnings]:find("data/persistent.lua", 1, true) ~= nil,
    "naming the table to fix it in")
end

do
  -- settle answers whether it claimed the mon, and that answer is what
  -- src/resolve.lua's sweep branches on -- a wrong one here is a battle form in
  -- the save or a persistent form swept out of it.
  T.eq(Persistent.settle(DATA, newMon("ALAKAZAM", "ALAKAZITE")), false,
    "a mon with no pairing is not this module's to settle")
  T.eq(Persistent.settle(DATA, newMon("ROTOM", "WASHING_MACHINE")), true,
    "and one with a pairing is")
  T.eq(Persistent.settle(DATA, nil), false, "and no mon at all is refused")
end

-- ------- the shelf ---------------------------------------------------

do
  local Registry = require("src.mods.Registry")
  local Schemas = require("src.mods.Schemas")
  local base = { CeladonMart4F = { TEXT_CELADONMART4F_CLERK = {
    label = "CeladonMart4FClerkText",
    mart = { "POKE_DOLL", "FIRE_STONE" },
  } } }
  local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
  reg.base = function() return base end
  local mod = { content = { text_pointers = {
    patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
  } } }

  Shop.installAppliances(mod, applianceIndices)
  local mart = reg:get("CeladonMart4F").TEXT_CELADONMART4F_CLERK.mart
  local sells = {}
  for _, id in ipairs(mart) do sells[id] = true end
  T.check(sells.POKE_DOLL, "the floor still sells what it always did")
  local count = 0
  for itemId in pairs(applianceIndices) do
    T.check(sells[itemId], itemId .. " is on the shelf")
    count = count + 1
  end
  T.eq(#mart, 2 + count, "and nothing else was added to it")
  -- Shelf order is bag-byte order, which is what stops the mart menu
  -- reshuffling between runs.
  local last = nil
  for _, id in ipairs(mart) do
    local index = applianceIndices[id]
    if index then
      T.check(last == nil or index > last, id .. " stands in bag-byte order")
      last = index
    end
  end
end

T.finish("battle_forms_persistent")
