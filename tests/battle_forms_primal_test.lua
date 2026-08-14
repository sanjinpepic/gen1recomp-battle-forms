-- Primal reversion: automatic, unlimited, and nowhere near the mega path.
--
-- Half of this suite is about what primal reversion does; the other half is
-- about what it must not touch.  A primal Groudon that quietly spent the
-- trainer's one mega for the battle, or that made a MEGA cell appear, would
-- pass every check in the first half.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Primal = dofile(MOD .. "/src/primal.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local Shop = dofile(MOD .. "/src/shop.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local primals = dofile(MOD .. "/data/primals.lua")
local orbIndices = dofile(MOD .. "/data/orbs.lua")
local stoneIndices = dofile(MOD .. "/data/stones.lua")
-- The whole mega roster: what primal reversion must stay clear of is every
-- mega, not the option's current selection.
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local DATA = { pokemon = {
  GROUDON = { baseStats = { hp = 100, attack = 150, defense = 140,
                            speed = 90, special = 100 },
              types = { "GROUND" } },
  GROUDON_PRIMAL = { baseStats = { hp = 100, attack = 180, defense = 160,
                                   speed = 90, special = 150 },
                     types = { "GROUND", "FIRE" }, form = "PRIMAL" },
  KYOGRE = { baseStats = { hp = 100, attack = 100, defense = 90,
                           speed = 90, special = 150 },
             types = { "WATER" } },
  KYOGRE_PRIMAL = { baseStats = { hp = 100, attack = 150, defense = 90,
                                  speed = 90, special = 180 },
                    types = { "WATER" }, form = "PRIMAL" },
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

local function newMon(species, held)
  local base = DATA.pokemon[species].baseStats
  local mon = { species = species, level = 50,
                dvs = { hp = 15, attack = 15, defense = 15,
                        speed = 15, special = 15 },
                statExp = {}, [E.STAMP] = held,
                moves = { { id = "TACKLE", pp = 35 } } }
  mon.stats = { hp = base.hp, attack = base.attack, defense = base.defense,
                speed = base.speed, special = base.special }
  return mon
end

local function battlerFor(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, curStats = mon.stats,
           curTypes = DATA.pokemon[mon.species].types }
end

-- phase/queue are what overlay.shouldOffer needs to say yes at all, so every
-- battle here is built in the state where a MEGA cell WOULD be drawn.  A
-- primal mon being offered nothing then means the pairing, not the moment.
local function makeBattle(playerMon, enemyMon)
  local queued = {}
  return {
    data = DATA, phase = "menu", queue = {},
    player = battlerFor(playerMon, true),
    enemy = enemyMon and battlerFor(enemyMon, false) or nil,
    -- Carrying the Key Stone for the same reason phase and queue are set the
    -- way they are: a primal mon offered no cell has to mean the pairing, not
    -- a bag that could never have offered one.
    game = { save = { party = { playerMon },
                      inventory = { [KeyItems.KEY_STONE] = 1 } } },
    enemyParty = enemyMon and { enemyMon } or {},
    queued = queued,
    animNext = function(_, name) queued[#queued + 1] = name end,
    animationsOn = function() return true end,
  }
end

Primal.bind({ forms = Forms, eligibility = E, primals = primals })
-- Mega evolution reaches the menu and turn resolution through the registry,
-- with nothing else registered -- exactly the shape the shipping mod wires.
-- Primal reversion is not in it, which is half of what this suite is about.
local registry = Transforms.new()
registry:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                               keyitems = KeyItems, animId = "TESTANIM" }))
local function bindResolve(log)
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, log = log })
end
bindResolve(nil)
Overlay.bind({ registry = registry })

-- ------- the pairings themselves -------------------------------------

T.eq(E.formFor(primals, "GROUDON", "RED_ORB"), "GROUDON_PRIMAL",
  "Groudon plus the Red Orb resolves to Primal Groudon")
T.eq(E.formFor(primals, "KYOGRE", "BLUE_ORB"), "KYOGRE_PRIMAL",
  "Kyogre plus the Blue Orb resolves to Primal Kyogre")
T.eq(E.formFor(primals, "GROUDON", "BLUE_ORB"), nil,
  "the wrong orb on Groudon resolves to nothing")
T.eq(E.formFor(primals, "KYOGRE", "RED_ORB"), nil,
  "the wrong orb on Kyogre resolves to nothing")
T.eq(E.formFor(primals, "CHARIZARD", "RED_ORB"), nil,
  "an orb on a species with no primal form resolves to nothing")

-- The two tables must not overlap in either direction, which is what keeps a
-- stone from ever triggering a reversion and an orb from ever being a mega.
for species, byOrb in pairs(primals) do
  T.eq(megas[species], nil, species .. " is a primal species and has no mega")
  for orbId in pairs(byOrb) do
    T.eq(E.formFor(megas, species, orbId), nil,
      orbId .. " names no mega anywhere in data/megas.lua")
  end
end

-- ------- entering battle ---------------------------------------------

local b1 = makeBattle(newMon("GROUDON", "RED_ORB"))
Primal.onBattleStarted({ battle = b1 })
T.eq(b1.player.mon.form, "PRIMAL",
  "a Groudon holding the Red Orb reverts on battle start, with no player action")
T.eq(b1.player.mon.species, "GROUDON", "and its species is untouched")
T.check(b1.player.curStats.attack > b1.player.mon.stats.attack,
  "curStats follow the primal form")
T.eq(b1.player.curTypes[2], "FIRE", "curTypes follow the primal form")
T.eq(#b1.queued, 0,
  "nothing is queued: the change lands before the mon is ever drawn")

-- No orb, no reversion -- and no orb is the normal case for every other mon
-- in the game.
local b2 = makeBattle(newMon("GROUDON", nil))
Primal.onBattleStarted({ battle = b2 })
T.eq(b2.player.mon.form, nil, "a Groudon holding nothing does not revert")

-- The wrong orb on the wrong species does nothing at all: not a refusal to
-- log, not a half-applied form, nothing.
local b3 = makeBattle(newMon("GROUDON", "BLUE_ORB"), newMon("KYOGRE", "RED_ORB"))
Primal.onBattleStarted({ battle = b3 })
T.eq(b3.player.mon.form, nil, "the Blue Orb on Groudon does nothing")
T.eq(b3.enemy.mon.form, nil, "the Red Orb on Kyogre does nothing")
T.eq(b3.player.curStats, b3.player.mon.stats,
  "and the mon's own stat block is still what the battler reads")

-- A mega stone on a primal species is not a back door into the primal table.
local b4 = makeBattle(newMon("GROUDON", "CHARIZARDITE_X"))
Primal.onBattleStarted({ battle = b4 })
T.eq(b4.player.mon.form, nil, "a mega stone on Groudon reverts nothing")

-- ------- both of them, in the same battle ----------------------------

-- The rule that separates primal reversion from mega evolution most sharply.
-- Mega evolution is once per battle per TRAINER; primal reversion has no
-- limit of any kind, so a team fielding both legendaries reverts both.
local groudon = newMon("GROUDON", "RED_ORB")
local kyogre = newMon("KYOGRE", "BLUE_ORB")
local b5 = makeBattle(groudon)
table.insert(b5.game.save.party, kyogre)
Primal.onBattleStarted({ battle = b5 })
T.eq(groudon.form, "PRIMAL", "Groudon reverts on entering")

-- Kyogre comes in from the bench: a fresh battler off makeBattler, base
-- curStats and all, exactly as the engine would hand it over.
b5.player = battlerFor(kyogre, true)
Primal.onBattlerSwitched({ battle = b5, battler = b5.player })
T.eq(kyogre.form, "PRIMAL",
  "Kyogre reverts on switching in, in the same battle Groudon already did")
T.check(b5.player.curStats.special > kyogre.stats.special,
  "the switched-in mon's curStats follow its own primal form")
T.eq(groudon.form, "PRIMAL",
  "and the first one is still primal -- there is no once-per-battle limit")

-- An enemy Groudon reverts on the same terms: the orb is the Pokemon's, the
-- way a held item is, not the trainer's.
local b6 = makeBattle(newMon("CHARIZARD", nil), newMon("GROUDON", "RED_ORB"))
Primal.onBattleStarted({ battle = b6 })
T.eq(b6.enemy.mon.form, "PRIMAL", "an enemy Groudon reverts too")

-- Switching in a mon that is already primal reapplies the same override
-- rather than doubling anything or refusing.
local repeated = newMon("GROUDON", "RED_ORB")
local b7 = makeBattle(repeated)
Primal.onBattleStarted({ battle = b7 })
local firstAttack = b7.player.curStats.attack
b7.player = battlerFor(repeated, true)
Primal.onBattlerSwitched({ battle = b7, battler = b7.player })
T.eq(b7.player.curStats.attack, firstAttack,
  "a primal mon switching back in lands on the same curStats it left with")

-- ------- what primal reversion must not touch ------------------------

-- No MEGA cell.  Groudon is in no mega table, so the cell that arms a mega
-- has nothing to offer it -- in a battle state where it would otherwise draw.
local b8 = makeBattle(newMon("GROUDON", "RED_ORB"))
local s8 = Arm.new()
s8:onBattleStarted({ battle = b8 })
Primal.onBattleStarted({ battle = b8 })
T.eq(Overlay.shouldOffer(s8), false,
  "a primal Pokemon is offered no MEGA cell")
T.eq(s8:used(Mega.ID), false, "and the battle's one mega is not spent")
T.eq(s8:isArmed(), false, "and nothing armed itself")

-- The budget is not merely unspent, it is still SPENDABLE: a Charizard
-- brought in after a primal reversion still megas.
b8.player = battlerFor(newMon("CHARIZARD", "CHARIZARDITE_X"), true)
T.eq(Overlay.shouldOffer(s8), true,
  "a mega-capable mon is offered the cell in the same battle")
s8:toggle(Mega.ID)
Resolve.onTurnStarted(s8, { battle = b8 })
T.eq(b8.player.mon.form, "MEGA_X",
  "and megas normally after a primal reversion happened in the same battle")
T.eq(s8:used(Mega.ID), true, "the mega spends the battle's one change, as it always did")

-- The other side of the same boundary, and the one 0.14.0 could have broken:
-- the trainer's one manual transformation is now gone, and primal reversion
-- must not have noticed.  It has no limit to have been charged and no cell to
-- have been taken away, so a Groudon coming in after the mega still reverts --
-- and reverts on both send-out paths, since either could have been the one
-- taught to ask the arm state a question it must not ask.
T.eq(s8:usedAny(), true, "precondition: the battle's manual transformation is spent")
local afterMega = newMon("GROUDON", "RED_ORB")
b8.player = battlerFor(afterMega, true)
Primal.onBattlerSwitched({ battle = b8, battler = b8.player })
T.eq(afterMega.form, "PRIMAL",
  "a Groudon switching in after the mega was spent still reverts")
T.check(b8.player.curStats.attack > afterMega.stats.attack,
  "with the primal form's stats really in force")
T.eq(s8:usedAny(), true, "and the reversion spent nothing of its own")
T.eq(s8:used(Mega.ID), true, "leaving the mega's flag exactly as it found it")

-- battle.started is the other path a primal mon arrives by, so a battle whose
-- arm state already carries a spent transformation reverts on entering too.
local startedSpent = newMon("GROUDON", "RED_ORB")
local b8b = makeBattle(startedSpent)
local s8b = Arm.new()
s8b:onBattleStarted({ battle = b8b })
s8b:consume(Mega.ID)
Primal.onBattleStarted({ battle = b8b })
T.eq(startedSpent.form, "PRIMAL",
  "and a spent arm state does not stop a reversion at battle start either")

-- Arming a mega while a primal Pokemon is out changes nothing and costs
-- nothing: the mon is not in the mega table, so the turn handler refuses and
-- the armed flag survives for whoever comes in next.
local b9 = makeBattle(newMon("GROUDON", "RED_ORB"))
local s9 = Arm.new()
s9:onBattleStarted({ battle = b9 })
Primal.onBattleStarted({ battle = b9 })
s9:toggle(Mega.ID)
Resolve.onTurnStarted(s9, { battle = b9 })
T.eq(b9.player.mon.form, "PRIMAL", "the primal form is left exactly as it was")
T.eq(s9:used(Mega.ID), false, "and the mega the player armed is still theirs to spend")

-- The mega path's switch-in reapplication must stay silent about a mon it
-- does not own.  Before primal reversion existed, a marked mon with no mega
-- pairing could only mean a stone had gone missing, and it warned; now it can
-- also mean another transformation type marked it.
local warned = {}
bindResolve({ warn = function(_, fmt, ...)
  warned[#warned + 1] = fmt:format(...)
end })
local b10 = makeBattle(newMon("GROUDON", "RED_ORB"))
Primal.onBattleStarted({ battle = b10 })
Resolve.onBattlerSwitched({ battle = b10, battler = b10.player })
T.eq(#warned, 0,
  "the mega path neither reapplies nor complains about a primal mon's form")
T.eq(b10.player.mon.form, "PRIMAL", "and leaves the form itself alone")
bindResolve(nil)

-- ------- unwinding ---------------------------------------------------

-- Fainting reverts at once, through the same handler a mega faints through.
local fainter = newMon("GROUDON", "RED_ORB")
local b11 = makeBattle(fainter)
Primal.onBattleStarted({ battle = b11 })
Resolve.onFainted({ battle = b11, battler = b11.player })
T.eq(fainter.form, nil, "a fainted primal mon reverts at once")
T.eq(b11.player.curStats, fainter.stats, "and its curStats are restored")
T.eq(b11.player.curTypes[1], "GROUND", "and its types with them")

-- Battle end sweeps the party, which is the case that matters: a primal mon
-- can be on the bench when the battle ends, and a form left set there is a
-- form written into the save.
local benched = newMon("KYOGRE", "BLUE_ORB")
local active = newMon("GROUDON", "RED_ORB")
local enemy = newMon("GROUDON", "RED_ORB")
local b12 = makeBattle(active, enemy)
table.insert(b12.game.save.party, benched)
Primal.onBattleStarted({ battle = b12 })
b12.player = battlerFor(benched, true)
Primal.onBattlerSwitched({ battle = b12, battler = b12.player })
T.eq(active.form, "PRIMAL", "precondition: the benched mon reverted before benching")
T.eq(benched.form, "PRIMAL", "precondition: the mon that came in reverted too")
T.eq(enemy.form, "PRIMAL", "precondition: the enemy reverted too")
Resolve.onBattleEnded({ battle = b12 })
T.eq(active.form, nil, "a benched primal mon reverts at battle end")
T.eq(benched.form, nil, "and so does the one that was on the field")
T.eq(enemy.form, nil, "and the enemy's")
T.eq(active[E.STAMP], "RED_ORB",
  "the orb itself stays on the mon -- it is not consumed by the battle")

-- ------- the orbs as items -------------------------------------------

Stone.bind(E)
local ORB_DATA = { pokemon = { GROUDON = { name = "GROUDON" },
                               KYOGRE = { name = "KYOGRE" },
                               CHARIZARD = { name = "CHARIZARD" } } }

local useRed = Stone.effectFor(primals, "RED_ORB")
local target = { species = "GROUDON" }
T.eq(useRed({ data = ORB_DATA, target = target }), "kept",
  "the Red Orb is kept rather than consumed, the way a stone is")
T.eq(E.stoneOf(target), "RED_ORB", "using it stamps the mon")

local wrongSpecies = { species = "KYOGRE" }
T.eq(useRed({ data = ORB_DATA, target = wrongSpecies }), "failed",
  "the Red Orb refuses Kyogre")
T.eq(E.stoneOf(wrongSpecies), nil, "and stamps nothing")
local notPrimal = { species = "CHARIZARD" }
T.eq(useRed({ data = ORB_DATA, target = notPrimal }), "failed",
  "the Red Orb refuses a species with no primal form")
T.eq(useRed({ data = ORB_DATA, target = nil }), "failed", "no target fails cleanly")

-- ------- bag indices --------------------------------------------------

local orbItems = Stone.items(primals, orbIndices)
local namedOrbs, orbCount = {}, 0
for _, byOrb in pairs(primals) do
  for orbId in pairs(byOrb) do
    namedOrbs[orbId] = true
    orbCount = orbCount + 1
    local record = orbItems[orbId]
    T.check(record ~= nil, orbId .. " became an item")
    T.check(record and record.index ~= nil, orbId .. " got a bag index")
    T.check(record and record.index and record.index >= 98 and record.index <= 255,
      orbId .. "'s index is in the free 98..255 range")
  end
end
T.eq(orbCount, 2, "both orbs were checked")

for orbId in pairs(orbIndices) do
  T.check(namedOrbs[orbId], orbId
    .. " has a bag index in data/orbs.lua but is not named in data/primals.lua")
end

-- The two index tables share one bag, so a byte handed out twice would make
-- an orb indistinguishable from a stone in a save.
for orbId, index in pairs(orbIndices) do
  for stoneId, stoneIndex in pairs(stoneIndices) do
    T.check(index ~= stoneIndex,
      orbId .. " (" .. index .. ") does not collide with " .. stoneId)
  end
end

-- ------- registration -------------------------------------------------

local seen = { items = {}, effects = {}, errors = {} }
local fakeMod = {
  log = { error = function(_, fmt, ...)
    seen.errors[#seen.errors + 1] = string.format(fmt, ...)
  end },
  content = {
    items = { register = function(_, id, record) seen.items[id] = record end },
    item_effects = { register = function(_, id, record) seen.effects[id] = record end },
  },
}
Stone.install(fakeMod, primals, primals, orbIndices)
for orbId in pairs(namedOrbs) do
  T.check(seen.items[orbId] ~= nil, orbId .. " is registered as an item")
  T.check(seen.effects[orbId] ~= nil, orbId .. " has an item effect")
  T.eq(seen.effects[orbId].battle, false,
    orbId .. " is a field item, not a battle one")
end
T.eq(#seen.errors, 0, "no orb reports a missing bag index")

-- No option gates a primal pairing, so an orb's effect works whatever the
-- MEGA EVOLUTIONS setting is -- there is nothing for the setting to reach.
local stillWorks = { species = "KYOGRE" }
T.eq(seen.effects.BLUE_ORB.use({ data = ORB_DATA, target = stillWorks }), "kept",
  "the registered Blue Orb effect assigns the orb")
T.eq(E.stoneOf(stillWorks), "BLUE_ORB", "and stamps the mon it fits")

-- ------- the shelf ----------------------------------------------------

local Registry = require("src.mods.Registry")
local Schemas = require("src.mods.Schemas")

-- The real Indigo Plateau lobby clerk (data/generated/text_pointers.lua),
-- trimmed to the fields shop.lua reads and writes.
local LOBBY_STOCK = { "ULTRA_BALL", "GREAT_BALL", "FULL_RESTORE" }
local base = {
  IndigoPlateauLobby = {
    TEXT_INDIGOPLATEAULOBBY_CLERK = {
      label = "IndigoPlateauLobbyClerkText",
      mart = { "ULTRA_BALL", "GREAT_BALL", "FULL_RESTORE" },
    },
  },
  CeladonMart4F = {
    TEXT_CELADONMART4F_CLERK = {
      label = "CeladonMart4FClerkText",
      mart = { "POKE_DOLL", "FIRE_STONE" },
    },
  },
}
local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
reg.base = function() return base end
local shopMod = { content = { text_pointers = {
  patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
} } }

Shop.install(shopMod, stoneIndices, Megaset.stoneIds(megas))
Shop.installOrbs(shopMod, orbIndices)

local lobby = reg:get("IndigoPlateauLobby").TEXT_INDIGOPLATEAULOBBY_CLERK.mart
local celadon = reg:get("CeladonMart4F").TEXT_CELADONMART4F_CLERK.mart

local function sells(mart, id)
  for _, entry in ipairs(mart) do
    if entry == id then return true end
  end
  return false
end

for _, id in ipairs(LOBBY_STOCK) do
  T.check(sells(lobby, id), "the lobby still sells " .. id)
end
for orbId in pairs(orbIndices) do
  T.check(sells(lobby, orbId), orbId .. " is on the Indigo Plateau shelf")
  T.check(not sells(celadon, orbId),
    orbId .. " is not on the mega stones' shelf")
end
T.eq(#lobby, #LOBBY_STOCK + orbCount,
  "the lobby's own stock plus exactly the two orbs, and nothing else")
T.check(not sells(lobby, "VENUSAURITE"), "no mega stone reached the lobby")

-- Ordered by bag index, so the counter does not reshuffle between runs.
T.eq(lobby[#lobby - 1], "RED_ORB", "the orbs are shelved in bag-index order")
T.eq(lobby[#lobby], "BLUE_ORB", "with the Blue Orb after the Red")

T.finish("battle_forms_primal")
