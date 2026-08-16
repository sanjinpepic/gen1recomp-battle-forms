-- Dynamax and Gigantamax: the three-turn clock, the four ways it ends, the
-- once-per-battle limit that is its own, and the HP that deliberately does not
-- move.
--
-- The HP assertions are not incidental to this suite, they are most of the
-- point of it.  mon.stats.hp and mon.hp are save data -- the engine reads max
-- HP off mon.stats.hp everywhere and has no battler-scoped copy to use instead
-- -- so a Dynamax that multiplied HP would be writing the save on a three-turn
-- timer, and a missed unwind would leave a number nothing can tell apart from
-- honest growth.  src/dynamax.lua does not touch either field; these checks are
-- what keeps that true.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- CHARIZARD has a Gigantamax and a mega both, which is what makes it the right
-- fixture: the two mechanics have to stay out of each other's way on the very
-- same mon.  PIDGEY has neither and stands in for every species that Dynamaxes
-- plainly.
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_GMAX = { baseStats = { hp = 78, attack = 84, defense = 78,
                                   speed = 100, special = 85 },
                     types = { "FIRE", "FLYING" }, form = "GMAX" },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
  PIDGEY = { baseStats = { hp = 40, attack = 45, defense = 40,
                           speed = 56, special = 35 },
             types = { "NORMAL", "FLYING" } },
} }

local GIGANTAMAX = { CHARIZARD = "CHARIZARD_GMAX" }

local function newMon(species, stamped)
  local def = DATA.pokemon[species]
  local mon = { species = species, level = 50, nickname = "ZARD",
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15,
                        special = 15 },
                statExp = {}, [E.STAMP] = stamped or nil,
                moves = { { id = "EMBER", pp = 25 } } }
  mon.stats = { hp = 150, attack = def.baseStats.attack,
                defense = def.baseStats.defense, speed = def.baseStats.speed,
                special = def.baseStats.special }
  mon.hp = 120
  return mon
end

local function makeBattle(species, stamped)
  local mon = newMon(species or "CHARIZARD", stamped)
  local said = {}
  local battle
  battle = {
    data = DATA,
    said = said,
    player = { isPlayer = true, mon = mon, name = mon.nickname,
               curStats = mon.stats, curTypes = DATA.pokemon[mon.species].types },
    -- The trainer's Dynamax Band, which is the whole of Dynamax's
    -- requirement: with an empty bag every check below would be about a cell
    -- that is not offered rather than about the state behind it.
    game = { save = { party = { mon },
                      inventory = { [KeyItems.DYNAMAX_BAND] = 1 } } },
    enemyParty = {},
    say = function(_, line) said[#said + 1] = line end,
    sayNext = function(_, line) said[#said + 1] = line end,
    animNext = function() end,
    animationsOn = function() return false end,
  }
  return battle
end

local function bind(log)
  Dynamax.bind({ forms = Forms, gigantamax = GIGANTAMAX, keyitems = KeyItems,
                 announce = Announce, log = log, battlerof = Battlerof })
end

bind(nil)

-- A whole battle's worth of HP facts, taken as one snapshot so every teardown
-- path below can assert the same thing the same way.
local function hpSnapshot(mon)
  return { stats = mon.stats, max = mon.stats.hp, cur = mon.hp }
end

local function assertHpUntouched(before, mon, when)
  T.eq(mon.stats, before.stats, "the mon's stat TABLE is the same table " .. when)
  T.eq(mon.stats.hp, before.max, "max HP is unchanged " .. when)
  T.eq(mon.hp, before.cur, "current HP is unchanged " .. when)
end

-- ---------------------------------------------------------------------
-- The registry entry.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  T.eq(entry.id, "dynamax", "the entry carries its own id")
  T.eq(entry.id, Dynamax.ID, "and the module publishes it")
  T.check(entry.id ~= Mega.ID, "which is not the mega's id")
  T.eq(entry.label, "DYNAMAX", "the cell reads DYNAMAX")
  T.eq(type(entry.available), "function", "it has a predicate")
  T.eq(type(entry.activate), "function", "and an activation")

  local reg = Transforms.new()
  T.eq(reg:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
    keyitems = KeyItems, battlerof = Battlerof })), true, "mega registers")
  T.eq(reg:register(entry), true, "and Dynamax registers beside it")
  T.eq(reg:count(), 2, "the cell now hosts two transformations")
  T.eq(reg:get("dynamax"), entry, "and the registry answers for it")

  -- Every species may Dynamax once the trainer has the Band: there is no stone
  -- to carry and no pairing table to be missing from, which is what makes this
  -- the only entry whose predicate asks nothing about the mon but that it
  -- exists.
  T.eq(entry.available(makeBattle("PIDGEY")), true,
    "a species with no Gigantamax is still offered a Dynamax")
  T.eq(entry.available(makeBattle("CHARIZARD")), true,
    "and so is one with a Gigantamax")
  T.eq(entry.available({ player = nil }), false, "with no mon out, nothing is offered")

  -- ...and nothing at all without it.  The Band is the outer gate and the
  -- refusal is silent: the predicate answers false, so the cell is absent
  -- exactly the way it is for a species the mega table has never heard of.
  local banded = makeBattle("CHARIZARD")
  banded.game.save.inventory = {}
  T.eq(entry.available(banded), false,
    "no Dynamax Band, no Dynamax, whatever the species")
  banded.game.save.inventory = { [KeyItems.KEY_STONE] = 1 }
  T.eq(entry.available(banded), false,
    "and a Key Stone is not a Dynamax Band -- the two gates are separate items")
  banded.game.save.inventory[KeyItems.DYNAMAX_BAND] = 1
  T.eq(entry.available(banded), true,
    "buying the Band mid-save makes Dynamax available with nothing reloaded")
end

-- ---------------------------------------------------------------------
-- Three turns, then revert.  Gigantamax where there is a form for it.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local mon = battle.player.mon
  local before = hpSnapshot(mon)

  T.eq(entry.activate(battle), true, "activating answers that it happened")
  T.eq(mon.species, "CHARIZARD", "the species is untouched")
  T.eq(mon.form, "GMAX", "a Gigantamax species takes the G-Max form")
  T.eq(state.turns, 3, "and the clock starts at three")
  T.eq(battle.said[1], "ZARD\nGigantamaxed!", "and it announces itself")
  assertHpUntouched(before, mon, "on activating")
  T.check(battle.player.curStats ~= mon.stats,
    "the battler's curStats is its own table, never an alias of the mon's")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.turns, 2, "one turn down")
  T.eq(mon.form, "GMAX", "still Gigantamaxed after the first turn")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.turns, 1, "two turns down")
  T.eq(mon.form, "GMAX", "still Gigantamaxed after the second turn")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(mon.form, nil, "the third turn ending takes the form back off")
  T.eq(state.mon, nil, "and drops the mon reference")
  T.eq(state.turns, 0, "and the clock")
  T.eq(state.form, nil, "and the form it was holding")
  T.eq(battle.said[2], "ZARD's\nDynamax ended!", "and it says the Dynamax ended")
  assertHpUntouched(before, mon, "after the clock ran out")
  T.eq(battle.player.curStats, mon.stats,
    "and the battler's stats point back at the mon's own block")
  T.eq(battle.player.curTypes[2], "FLYING", "with the base species' types back")

  -- A fourth turn end must not count against a Dynamax that is already over.
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.turns, 0, "a turn after the end changes nothing")
  T.eq(mon.form, nil, "and puts no form back on")
end

-- ---------------------------------------------------------------------
-- A species with no Gigantamax Dynamaxes plainly: state, no form change.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("PIDGEY")
  local mon = battle.player.mon
  local before = hpSnapshot(mon)

  T.eq(entry.activate(battle), true, "a plain Dynamax still happens")
  T.eq(mon.form, nil, "and marks no form at all")
  T.eq(state.mon, mon, "the state holds the mon")
  T.eq(state.turns, 3, "for three turns")
  T.eq(state.form, nil, "with no form to give back")
  T.eq(battle.said[1], "ZARD\nDynamaxed!",
    "and announces a Dynamax, not a Gigantamax")
  assertHpUntouched(before, mon, "on a plain Dynamax")

  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.mon, nil, "and it ends on the same three-turn clock")
  T.eq(mon.form, nil, "still with no form on the mon")
  assertHpUntouched(before, mon, "after a plain Dynamax ended")
end

-- ---------------------------------------------------------------------
-- Ends early on switching out, read off ev.previous.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local outgoing = battle.player
  local mon = outgoing.mon
  local before = hpSnapshot(mon)
  entry.activate(battle)
  T.eq(mon.form, "GMAX", "Gigantamaxed on turn one")

  -- The engine replaces battle.player outright on a switch and hands the OLD
  -- battler over as `previous`; reading ev.battler here would be reading the
  -- mon arriving, which is the wrong end of the event.
  local incoming = { isPlayer = true, mon = newMon("PIDGEY"), name = "PIDGE" }
  battle.player = incoming
  Dynamax.onBattlerSwitched(state, { battle = battle, battler = incoming,
                                     previous = outgoing })
  T.eq(mon.form, nil, "switching out takes the G-Max form off the mon that left")
  T.eq(state.mon, nil, "and ends the state")
  T.eq(state.turns, 0, "and stops the clock")
  assertHpUntouched(before, mon, "after switching out")

  -- And the clock cannot keep running against the mon that left.
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.turns, 0, "a turn ending after a switch counts nothing")
  T.eq(incoming.mon.form, nil, "and never touches the mon that came in")
end

-- A switch that is not the Dynamaxed mon leaves the state alone.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local dyna = battle.player
  entry.activate(battle)
  local other = { isPlayer = true, mon = newMon("PIDGEY"), name = "PIDGE" }
  Dynamax.onBattlerSwitched(state, { battle = battle, battler = dyna,
                                     previous = other })
  T.eq(state.mon, dyna.mon, "some other mon switching out ends nothing")
  T.eq(dyna.mon.form, "GMAX", "and leaves the Gigantamax standing")
end

-- ---------------------------------------------------------------------
-- Ends on fainting, in either handler order.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player
  local mon = battler.mon
  local before = hpSnapshot(mon)
  entry.activate(battle)

  mon.hp = 0
  Dynamax.onFainted(state, { battle = battle, battler = battler })
  T.eq(mon.form, nil, "fainting takes the form off")
  T.eq(state.mon, nil, "and ends the state")
  T.eq(mon.stats, before.stats, "and never replaced the stat table")
  T.eq(mon.stats.hp, before.max, "and left max HP where it was")
end

-- The real wiring runs resolve.onFainted first, which reverts the form through
-- the same primitive.  Dynamax has to be correct behind it, not just in front.
do
  Resolve.bind({ registry = Transforms.new(), forms = Forms, eligibility = E,
                 megas = megas, gigantamaxRows = GIGANTAMAX, battlerof = Battlerof })
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player
  local mon = battler.mon
  entry.activate(battle)

  Resolve.onFainted({ battle = battle, battler = battler })
  T.eq(mon.form, nil, "resolve's faint handler got there first")
  Dynamax.onFainted(state, { battle = battle, battler = battler })
  T.eq(state.mon, nil, "and Dynamax still ends its own state behind it")
  T.eq(mon.form, nil, "without putting anything back on the mon")
end

-- ---------------------------------------------------------------------
-- The unwind leaves nothing on the mon, and nothing survives the battle.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local mon = battle.player.mon
  local before = hpSnapshot(mon)

  -- Every key the mon carried before the Dynamax, so the comparison after it
  -- is "nothing new and nothing missing" rather than a list of guesses.
  local keysBefore = {}
  for k in pairs(mon) do keysBefore[k] = true end

  entry.activate(battle)
  T.eq(mon.form, "GMAX", "Gigantamaxed")

  -- The battle ends mid-Dynamax, which is the case that matters: the party
  -- sweep reverts the form and Dynamax drops the mon it was holding.
  Resolve.onBattleEnded({ battle = battle })
  Dynamax.onBattleEnded(state)

  T.eq(mon.form, nil, "the party sweep took the form off")
  T.eq(state.mon, nil, "and the state let the mon go")
  T.eq(state.turns, 0, "with the clock cleared")
  T.eq(state.form, nil, "and the form cleared")
  assertHpUntouched(before, mon, "after the battle ended mid-Dynamax")

  for k in pairs(mon) do
    T.check(keysBefore[k], "the mon carries no new key after the unwind: " .. tostring(k))
  end
  for k in pairs(keysBefore) do
    T.check(mon[k] ~= nil, "and lost none of its own: " .. tostring(k))
  end
  -- `form` is cleared to nil rather than false: the save writer re-emits
  -- whatever key it finds, so a falsy-but-present field would round-trip into
  -- the save as a lingering entry.
  T.eq(rawget(mon, "form"), nil, "and `form` is absent, not merely falsy")
end

-- A battle STARTING clears a record left behind by anything that went wrong.
do
  local state = Dynamax.new()
  state.mon, state.turns, state.form = { species = "GHOST" }, 2, "GMAX"
  Dynamax.onBattleStarted(state)
  T.eq(state.mon, nil, "a new battle starts holding no mon")
  T.eq(state.turns, 0, "and no clock")
  T.eq(state.form, nil, "and no form")
end

-- ---------------------------------------------------------------------
-- Once per battle per trainer, and a limit that is its OWN.
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  local state = Dynamax.new()
  registry:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                                 announce = Announce, battlerof = Battlerof }))
  registry:register(Dynamax.entry(state))
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, gigantamaxRows = GIGANTAMAX, battlerof = Battlerof })

  local battle = makeBattle("CHARIZARD", "CHARIZARDITE_X")
  local arm = Arm.new()
  arm:onBattleStarted({ battle = battle })

  -- Arm the Dynamax and let turn resolution dispatch it.
  arm:toggle(Dynamax.ID)
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(arm:used(Dynamax.ID), true, "the battle records its one Dynamax")
  T.eq(arm:used(Mega.ID), false,
    "and spends no mega doing it -- the flags are keyed, not counted")
  T.eq(battle.player.mon.form, "GMAX", "the Gigantamax landed")

  -- A second Dynamax cannot even be armed.
  T.eq(arm:toggle(Dynamax.ID), false, "a spent Dynamax refuses to arm again")
  T.eq(arm:isArmed(), false, "so nothing is armed")

  -- The mega's own flag is untouched by all of it, which is what keeps the two
  -- limits distinct.  What the mega HAS lost is the cell -- the battle's one
  -- manual transformation went with the Dynamax, and that is pinned through
  -- src/overlay.lua further down -- so the arm state is driven directly here.
  -- What is under test either side of this line is the form interaction, and
  -- that needs a mega laid over a live Gigantamax to be testable at all.
  T.eq(arm:used(Mega.ID), false, "the mega's own flag survived the Dynamax")
  T.eq(arm:toggle(Mega.ID), true, "so the arm state still takes it")
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(arm:used(Mega.ID), true, "and spends its own flag")
  T.eq(arm:used(Dynamax.ID), true, "leaving the Dynamax's spent")

  -- Arming the mega second means the mon was already wearing GMAX, and
  -- becomeForm overwrites it -- so when the Dynamax clock runs out it must
  -- leave the mega exactly where it is rather than stripping a change the
  -- player only gets once a battle.
  T.eq(battle.player.mon.form, "MEGA_X", "the mega overwrote the G-Max form")
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(battle.player.mon.form, "MEGA_X",
    "and the Dynamax expiring leaves the mega alone")
  T.eq(state.mon, nil, "while still ending its own state")
end

-- The other direction: a mega spent first must not spend the Dynamax, and the
-- Dynamax must not overwrite the mega's form.
do
  local registry = Transforms.new()
  local state = Dynamax.new()
  registry:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                                 announce = Announce, battlerof = Battlerof }))
  local entry = Dynamax.entry(state)
  registry:register(entry)
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, gigantamaxRows = GIGANTAMAX, battlerof = Battlerof })

  local battle = makeBattle("CHARIZARD", "CHARIZARDITE_X")
  local arm = Arm.new()
  arm:onBattleStarted({ battle = battle })
  arm:toggle(Mega.ID)
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(arm:used(Mega.ID), true, "the mega is spent")
  T.eq(arm:used(Dynamax.ID), false, "and the Dynamax is not")
  T.eq(battle.player.mon.form, "MEGA_X", "the mega landed")

  -- The entry's own predicate, not the cell: the cell has already withdrawn it
  -- for the battle (below), and what these two lines are for is the form
  -- interaction behind it.
  T.eq(entry.available(battle), true, "the Dynamax's own predicate still passes")
  T.eq(entry.activate(battle), true, "and it still activates")
  T.eq(battle.player.mon.form, "MEGA_X",
    "but refuses to dress a mon already wearing another form")
  T.eq(state.form, nil, "so it holds no form to give back")
  T.eq(state.turns, 3, "while the Dynamax state itself is real")

  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(battle.player.mon.form, "MEGA_X", "and its expiry leaves the mega alone")
end

-- ---------------------------------------------------------------------
-- One manual transformation per battle, across both of them.
--
-- The two checks above are about the arm state's keyed flags, which are
-- deliberately unchanged.  These are about what the player can actually reach:
-- the cell, decided by src/overlay.lua, which is where the shared limit lives.
-- ---------------------------------------------------------------------

-- Everything the cell needs before it will draw at all: the command menu with
-- an empty queue, and both trainer items, so a cell that is missing below is
-- missing for the reason under test and not for one of the other four.
local function cellBattle()
  local battle = makeBattle("CHARIZARD", "CHARIZARDITE_X")
  battle.phase = "menu"
  battle.queue = {}
  battle.game.save.inventory[KeyItems.KEY_STONE] = 1
  return battle
end

local function bothRegistered()
  local registry = Transforms.new()
  registry:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                                 keyitems = KeyItems, announce = Announce, battlerof = Battlerof }))
  registry:register(Dynamax.entry(Dynamax.new()))
  Overlay.bind({ registry = registry })
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, gigantamaxRows = GIGANTAMAX, battlerof = Battlerof })
  return registry
end

local function labels(arm)
  local out = {}
  for _, entry in ipairs(Overlay.offered(arm)) do out[#out + 1] = entry.label end
  return table.concat(out, ",")
end

-- The mega first: it takes the Dynamax with it.
do
  local registry = bothRegistered()
  local battle = cellBattle()
  local arm = Arm.new()
  arm:onBattleStarted({ battle = battle })
  T.eq(labels(arm), "MEGA,DYNAMAX", "precondition: both are on the cell")

  arm:toggle(Mega.ID)
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(battle.player.mon.form, "MEGA_X", "the mega landed")
  T.eq(labels(arm), "", "and took the Dynamax off the cell with it")
  T.eq(arm:usedAny(), true, "the battle's one manual transformation is gone")
  T.eq(arm:used(Dynamax.ID), false,
    "without spending the Dynamax's own flag -- the cell is what withholds it")
  T.eq(registry:get(Dynamax.ID).available(battle), true,
    "and without touching its predicate either")
end

-- The Dynamax first: the same rule, the other way round.
do
  local registry = bothRegistered()
  local battle = cellBattle()
  local arm = Arm.new()
  arm:onBattleStarted({ battle = battle })
  T.eq(labels(arm), "MEGA,DYNAMAX", "precondition: both are on the cell")

  arm:toggle(Dynamax.ID)
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(battle.player.mon.form, "GMAX", "the Gigantamax landed")
  T.eq(labels(arm), "", "and the mega went off the cell with it")
  T.eq(arm:usedAny(), true, "the battle's one manual transformation is gone")
  T.eq(arm:used(Mega.ID), false, "with the mega's own flag unspent")
  T.eq(registry:get(Mega.ID).available(battle), true,
    "and the mega still perfectly eligible")

  -- The limit is the BATTLE's.  A player who spends it in one fight walks into
  -- the next with both back, which is the only reason it can sit in the arm
  -- state at all rather than on a mon or in the save.
  arm:onBattleEnded({ battle = battle })
  arm:onBattleStarted({ battle = cellBattle() })
  T.eq(arm:usedAny(), false, "the next battle starts with the limit back")
  T.eq(labels(arm), "MEGA,DYNAMAX", "and with both on the cell again")
end

-- ---------------------------------------------------------------------
-- A refused Gigantamax still Dynamaxes, and says why.
-- ---------------------------------------------------------------------
do
  local warned = {}
  Dynamax.bind({ forms = Forms, gigantamax = { CHARIZARD = "CHARIZARD_NOPE" },
                 announce = Announce, battlerof = Battlerof,
                 log = { warn = function(_, fmt, ...)
                   warned[#warned + 1] = string.format(fmt, ...)
                 end } })
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")

  T.eq(entry.activate(battle), true, "a missing G-Max record still Dynamaxes")
  T.eq(battle.player.mon.form, nil, "with no form on the mon")
  T.eq(state.turns, 3, "and a real three-turn state")
  T.eq(battle.said[1], "ZARD\nDynamaxed!", "announced as a plain Dynamax")
  -- A guard that refuses must say so out loud.  The DYNAMAX cell is offered to
  -- every species, so nothing checked this record before the activation did --
  -- if it went unlogged here it would go unlogged anywhere.
  T.eq(#warned, 1, "a G-Max id with no species record is logged, not swallowed")
  T.check(warned[1]:find("CHARIZARD_NOPE", 1, true) ~= nil,
    "and the line names the id that could not be found")
  T.check(warned[1]:find("no_record", 1, true) ~= nil,
    "and says the record was what was missing")
end

-- The record exists but has no `form` field: becomeForm refuses, and that
-- refusal is the one that has to be audible.
do
  local warned = {}
  local data = { pokemon = { CHARIZARD = DATA.pokemon.CHARIZARD,
                             CHARIZARD_BAD = { baseStats =
                               DATA.pokemon.CHARIZARD.baseStats,
                               types = { "FIRE" } } } }
  Dynamax.bind({ forms = Forms, gigantamax = { CHARIZARD = "CHARIZARD_BAD" },
                 announce = Announce, battlerof = Battlerof,
                 log = { warn = function(_, fmt, ...)
                   warned[#warned + 1] = string.format(fmt, ...)
                 end } })
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  battle.data = data

  T.eq(entry.activate(battle), true, "a refused Gigantamax still Dynamaxes")
  T.eq(battle.player.mon.form, nil, "and puts no half-applied form on the mon")
  T.eq(#warned, 1, "and the refusal is logged rather than swallowed")
  T.check(warned[1]:find("gigantamax", 1, true) ~= nil,
    "the line names the mechanic that refused")
  T.check(warned[1]:find("CHARIZARD_BAD", 1, true) ~= nil,
    "and the form id it refused")
end

bind(nil)

-- ---------------------------------------------------------------------
-- The shipped table, against the shipped species data.
-- ---------------------------------------------------------------------
do
  local shipped = dofile(MOD .. "/data/gigantamax.lua")
  local count = 0
  for species, formId in pairs(shipped) do
    count = count + 1
    T.eq(type(species), "string", "every key is a species id")
    T.eq(type(formId), "string", "and every value a form id")
    T.check(formId:find("GMAX", 1, true) ~= nil,
      formId .. " is a Gigantamax record key")
  end
  T.eq(count, 31, "the shipped table wires 31 species")
  T.eq(shipped.CHARIZARD, "CHARIZARD_GMAX", "Charizard among them")
  T.eq(shipped.CORVIKNIGHT, nil, "and Corviknight deliberately not")
end

T.finish("battle_forms_dynamax")
