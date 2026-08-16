-- Terastallization: the type override, what reads it, and what takes it back
-- off again.
--
-- This suite goes through the ENGINE's own damage math rather than asserting
-- on the field it writes.  A test that only read battler.curTypes back would
-- pass just as well if nothing in the game looked at it, which is the whole
-- question a type-changing mechanic has to answer -- so the proof here is a
-- move that was doing double damage doing none, computed by src/battle/Damage
-- from the same table the mod wrote.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Tera = dofile(MOD .. "/src/tera.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Menu = dofile(MOD .. "/src/menu.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local Damage = require("src.battle.Damage")
local TypeChart = require("src.battle.TypeChart")
local Ruleset = require("src.battle.rulesets.gen1_faithful")

-- ---------------------------------------------------------------------
-- The world these checks happen in.  Only the matchups the checks below
-- read are in the chart; a row that is not here is neutral, which is what
-- the engine's own lookup does with a missing pair anyway.
--
-- PSYCHIC_TYPE is in `types` under the engine's id with the name it prints,
-- because the one place those differ is the one place a message could leak
-- an id into the battle box.
-- ---------------------------------------------------------------------
local CHART = {
  matchups = {
    { attacker = "ELECTRIC", defender = "FLYING", multiplier = 20 },
    { attacker = "ELECTRIC", defender = "GROUND", multiplier = 0 },
    { attacker = "ELECTRIC", defender = "WATER", multiplier = 20 },
  },
  types = {
    NORMAL = { name = "NORMAL", category = "physical" },
    GROUND = { name = "GROUND", category = "physical" },
    FLYING = { name = "FLYING", category = "physical" },
    FIRE = { name = "FIRE", category = "special" },
    WATER = { name = "WATER", category = "special" },
    ELECTRIC = { name = "ELECTRIC", category = "special" },
    DRAGON = { name = "DRAGON", category = "special" },
    PSYCHIC_TYPE = { name = "PSYCHIC", category = "special" },
  },
}

local DATA = { type_chart = CHART, pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" }, name = "CHARIZARD" },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

TypeChart.load(DATA)

local THUNDERBOLT = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90,
                      category = "special" }

-- Deterministic: the top of the damage roll and never a crit, so a change in
-- the number below can only have come from the types.
local function hit(attacker, defender, move)
  local _, info = Damage.compute(Ruleset, attacker, defender, move or THUNDERBOLT,
    { rng = function(_, hi) return hi end, forceCrit = false })
  return info.typeMult
end

local function damage(attacker, defender, move)
  local dealt = Damage.compute(Ruleset, attacker, defender, move or THUNDERBOLT,
    { rng = function(_, hi) return hi end, forceCrit = false })
  return dealt
end

local function makeMon()
  local mon = { species = "CHARIZARD", level = 50, hp = 100,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15,
                        special = 15 },
                statExp = {}, [E.STAMP] = "CHARIZARDITE_X" }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  return mon
end

local function makeBattler(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, name = "CHARIZARD", stages = {},
           curStats = mon.stats, curTypes = DATA.pokemon.CHARIZARD.types }
end

local function makeInput(pressed)
  return { wasPressed = function(_, btn) return (pressed or {})[btn] == true end }
end

local function makeBattle(bag)
  local mon = makeMon()
  local enemy = makeMon()
  local battle = {
    phase = "menu", menuIndex = 1, queue = {}, data = DATA,
    player = makeBattler(mon, true), enemy = makeBattler(enemy, false),
    enemyParty = { enemy },
    game = { save = { party = { mon }, inventory = bag or {} },
             input = makeInput({}) },
    animNext = function() end,
    animationsOn = function() return false end,
  }
  battle.say = function(self, line)
    self.queue[#self.queue + 1] = { text = line }
  end
  battle.sayNext = function(self, line)
    self.nextInsert = (self.nextInsert or 0) + 1
    table.insert(self.queue, self.nextInsert, { text = line })
  end
  return battle
end

-- A log that records rather than prints, so a refusal that must be loud can
-- be checked for having been loud.
local function makeLog()
  local lines = {}
  return { warn = function(_, fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end,
           error = function(_, fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end },
         lines
end

local function bindTera(chosen, log)
  Tera.bind({ keyitems = KeyItems, announce = Announce, log = log,
              battlerof = Battlerof,
              chosen = function() return chosen end })
end

-- ---------------------------------------------------------------------
-- The override, and that the damage path is what reads it.
-- ---------------------------------------------------------------------
do
  bindTera("GROUND")
  local state = Tera.new()
  local entry = Tera.entry(state)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })

  T.eq(hit(battle.enemy, battle.player), 20,
    "precondition: Electric is double against FIRE/FLYING")
  local before = damage(battle.enemy, battle.player)
  T.check(before > 0, "precondition: and it deals damage")

  T.eq(entry.activate(battle), true, "terastallizing succeeds")
  T.eq(#battle.player.curTypes, 1, "the battler is left with exactly one type")
  T.eq(battle.player.curTypes[1], "GROUND", "which is the one that was chosen")
  T.eq(hit(battle.enemy, battle.player), 0,
    "and the engine's own damage math now reads GROUND: Electric does nothing")
  T.eq(damage(battle.enemy, battle.player), 0, "so the hit deals no damage at all")

  -- STAB is the other half of what curTypes drives, and it is read off the
  -- ATTACKER: a terastallized Pokemon gets the boost on its new type.
  local stabbed = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  bindTera("ELECTRIC")
  local stabState = Tera.new()
  local plain = damage(stabbed.player, stabbed.enemy)
  T.eq(Tera.entry(stabState).activate(stabbed), true, "a second one terastallizes")
  T.check(damage(stabbed.player, stabbed.enemy) > plain,
    "and its Electric move gains the same-type bonus it did not have before")
end

-- ---------------------------------------------------------------------
-- What the override must not touch.  curTypes is seeded from the species
-- record BY REFERENCE (BattleState.lua:514), so an application that wrote
-- into the table it found would retype every Charizard in the loaded data
-- for the rest of the session -- in battle and out of it.
-- ---------------------------------------------------------------------
do
  bindTera("GROUND")
  local state = Tera.new()
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  local species = DATA.pokemon.CHARIZARD.types
  local sameTable = battle.player.curTypes == species

  T.eq(sameTable, true,
    "precondition: the battler starts on the species record's own table, as "
      .. "makeBattler leaves it")
  Tera.entry(state).activate(battle)
  T.eq(DATA.pokemon.CHARIZARD.types, species,
    "the species record still holds the same table")
  T.eq(species[1], "FIRE", "with its own first type")
  T.eq(species[2], "FLYING", "and its second")
  T.check(battle.player.curTypes ~= species,
    "because the override assigned a new table rather than writing into that one")
end

-- ---------------------------------------------------------------------
-- Nothing reaches the save.  The mechanic marks no mon at all, which is
-- what makes this provable rather than swept: the fields on the party mon
-- are the same set before and after, and the same after every unwind.
-- ---------------------------------------------------------------------
local function keysOf(mon)
  local out = {}
  for key in pairs(mon) do out[#out + 1] = tostring(key) end
  table.sort(out)
  return table.concat(out, ",")
end

do
  bindTera("GROUND")
  local state = Tera.new()
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  local mon = battle.player.mon
  local before = keysOf(mon)

  Tera.entry(state).activate(battle)
  T.eq(keysOf(mon), before, "terastallizing writes no field onto the Pokemon")
  T.eq(mon.form, nil, "in particular it is not a form and does not mark one")
  T.eq(mon.stats.hp, 78, "and the stat block the save carries is untouched")

  Tera.onBattleEnded(state, { battle = battle })
  T.eq(keysOf(mon), before, "and the battle ending leaves the same fields")
end

-- ---------------------------------------------------------------------
-- The unwind, on every path there is.
-- ---------------------------------------------------------------------

-- Fainting ends it (section 8's own rule, and the one place it differs from
-- a mega, which the faint handler in src/resolve.lua unwinds instead).
do
  bindTera("GROUND")
  local state = Tera.new()
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  local original = battle.player.curTypes
  Tera.entry(state).activate(battle)
  T.eq(battle.player.curTypes[1], "GROUND", "precondition: terastallized")

  Tera.onFainted(state, { battle = battle, battler = battle.player })
  T.eq(battle.player.curTypes, original,
    "fainting puts the battler's own types back, by the very table it had")
  T.eq(hit(battle.enemy, battle.player), 20,
    "and the damage math is reading FIRE/FLYING again")
  T.eq(state.mon, nil, "the state stops holding the Pokemon")

  -- A faint for some other Pokemon must not unwind this one.
  local other = Tera.new()
  local battle2 = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  Tera.entry(other).activate(battle2)
  Tera.onFainted(other, { battle = battle2, battler = battle2.enemy })
  T.eq(battle2.player.curTypes[1], "GROUND",
    "another Pokemon fainting leaves the terastallized one alone")
end

-- The battle ending unwinds it wherever the Pokemon is.
do
  bindTera("GROUND")
  local state = Tera.new()
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  local original = battle.player.curTypes
  Tera.entry(state).activate(battle)

  Tera.onBattleEnded(state, { battle = battle })
  T.eq(battle.player.curTypes, original, "the battle ending restores the types")
  T.eq(state.mon, nil, "and drops the mon reference rather than outliving the battle")

  -- Off the field there is nothing to restore and nothing to be confused by:
  -- the battler that carried the override was discarded by the switch, and
  -- the one standing there now belongs to another Pokemon entirely.
  local benched = Tera.new()
  local battle2 = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  Tera.entry(benched).activate(battle2)
  local arriving = makeBattler(makeMon(), true)
  local arrivingTypes = arriving.curTypes
  battle2.player = arriving
  Tera.onBattleEnded(benched, { battle = battle2 })
  T.eq(benched.mon, nil, "the state is cleared with the Pokemon on the bench")
  T.eq(arriving.curTypes, arrivingTypes,
    "and the Pokemon that is out keeps its own types")
end

-- A new battle starts clean even if the last one ended in a way that never
-- reached the handler above.
do
  bindTera("GROUND")
  local state = Tera.new()
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  Tera.entry(state).activate(battle)
  Tera.onBattleStarted(state)
  T.eq(state.mon, nil, "a battle starting clears whatever the last one left")
  T.eq(state.type, nil, "including the type it was holding")
end

-- ---------------------------------------------------------------------
-- Switching does NOT end it, which is the whole difference between this
-- and Dynamax at the same seam.
-- ---------------------------------------------------------------------
do
  bindTera("GROUND")
  local state = Tera.new()
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  local mon = battle.player.mon
  Tera.entry(state).activate(battle)

  -- The bench, and back: a switch builds a whole new battler, which is why
  -- the override has to be applied again rather than merely surviving.
  local other = makeBattler(makeMon(), true)
  battle.player = other
  Tera.onBattlerSwitched(state, { battle = battle, battler = other,
                                  previous = nil })
  T.eq(other.curTypes[1], "FIRE",
    "the Pokemon that came in instead is not terastallized")
  T.eq(state.mon, mon, "and the state still belongs to the one that left")

  local returned = makeBattler(mon, true)
  battle.player = returned
  Tera.onBattlerSwitched(state, { battle = battle, battler = returned })
  T.eq(#returned.curTypes, 1, "switching back in reapplies the override")
  T.eq(returned.curTypes[1], "GROUND", "with the same type it was")
  T.eq(hit(battle.enemy, returned), 0, "and the damage math reads it again")

  -- And the unwind still finds it after all that.
  Tera.onBattleEnded(state, { battle = battle })
  T.eq(returned.curTypes[1], "FIRE",
    "the battle ending restores the battler it was reapplied to")
end

-- ---------------------------------------------------------------------
-- The gate: the Tera Orb, and silence without it.
-- ---------------------------------------------------------------------
do
  bindTera("GROUND")
  local state = Tera.new()
  local entry = Tera.entry(state)

  T.eq(entry.available(makeBattle({})), false, "an empty bag is offered nothing")
  T.eq(entry.available(makeBattle({ [KeyItems.KEY_STONE] = 1 })), false,
    "a Key Stone does nothing for it")
  T.eq(entry.available(makeBattle({ [KeyItems.DYNAMAX_BAND] = 1 })), false,
    "nor does a Dynamax Band")
  T.eq(entry.available(makeBattle({ [KeyItems.TERA_ORB] = 1 })), true,
    "the Tera Orb is what opens it")

  -- Silent: an absent gate produces no cell, not a cell that refuses.  The
  -- cell is drawn from the offer, so an empty offer is the whole of it.
  local registry = Transforms.new()
  registry:register(Tera.entry(Tera.new()))
  Overlay.bind({ registry = registry })
  Menu.bind({ overlay = Overlay })
  local armState = Arm.new()
  local battle = makeBattle({})
  armState:onBattleStarted({ battle = battle })
  T.eq(Overlay.shouldOffer(armState), false, "with no Orb the cell is not offered")
  T.eq(Overlay.label(armState), nil, "and names nothing")
  T.eq(Menu.handleInput(battle, armState), false,
    "and the menu never claims a frame for it")

  battle.game.save.inventory[KeyItems.TERA_ORB] = 1
  T.eq(Overlay.shouldOffer(armState), true,
    "buying one mid-battle brings the cell up, read live off the bag")
  T.eq(Overlay.label(armState), "FORM",
    "and the cell reads the generic label, unarmed")
end

-- ---------------------------------------------------------------------
-- A type this game has no record for.  The three modern types exist only
-- once National Dex has registered a chart, so the option can name one the
-- running game cannot resolve -- and that must not be a cell that arms a
-- change nothing can make.
-- ---------------------------------------------------------------------
do
  local log, lines = makeLog()
  bindTera("FAIRY", log)
  local state = Tera.new()
  local entry = Tera.entry(state)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })

  T.eq(entry.available(battle), false,
    "a type the chart has never heard of takes the cell away")
  T.eq(#lines, 1, "and says so out loud, because nothing else would explain it")
  T.check(lines[1]:find("FAIRY", 1, true) ~= nil, "naming the type that was picked")
  for _ = 1, 200 do entry.available(battle) end
  T.eq(#lines, 1,
    "once per battle, because the cell asks this on every drawn frame")

  T.eq(entry.activate(battle), false, "and activating anyway refuses")
  T.eq(#battle.player.curTypes, 2, "leaving the battler's own types alone")

  -- The same option value with a chart that does carry the type is fine, so
  -- what is being refused is the missing record and not the id.
  local ok = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  ok.data = { type_chart = { matchups = {},
                             types = { FAIRY = { name = "FAIRY",
                                                 category = "physical" } } },
              pokemon = DATA.pokemon }
  T.eq(entry.available(ok), true, "a chart that has it offers the cell")
end

-- ---------------------------------------------------------------------
-- The message, which for this mechanic is the entire visible effect: no
-- form, no picture, no name change, no animation.
-- ---------------------------------------------------------------------
do
  bindTera("PSYCHIC_TYPE")
  local state = Tera.new()
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  Tera.entry(state).activate(battle)

  T.eq(#battle.queue, 2, "two pages are queued")
  T.eq(battle.queue[1].text, "CHARIZARD\nTerastallized!",
    "the first says what happened")
  T.eq(battle.queue[2].text, "It became the\nPSYCHIC type!",
    "and the second names the type, printed the way the chart names it rather "
      .. "than by the engine's PSYCHIC_TYPE id")
  for _, page in ipairs(battle.queue) do
    for line in (page.text .. "\n"):gmatch("([^\n]*)\n") do
      T.check(#line <= 18, "'" .. line .. "' fits the 18-character battle row")
    end
  end
end

-- ---------------------------------------------------------------------
-- The shared limit.  Being in the registry is what puts this under the
-- trainer's one manual transformation per battle, and it must be spent by
-- the dispatcher rather than by anything here.
-- ---------------------------------------------------------------------
do
  bindTera("GROUND")
  local registry = Transforms.new()
  T.eq(registry:register(Mega.entry({ forms = Forms, eligibility = E,
    megas = megas, keyitems = KeyItems, animId = "TESTANIM",
    battlerof = Battlerof })), true,
    "mega registers")
  local teraState = Tera.new()
  T.eq(registry:register(Tera.entry(teraState)), true, "and so does Tera")
  Overlay.bind({ registry = registry })
  Menu.bind({ overlay = Overlay })
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, battlerof = Battlerof })

  local battle = makeBattle({ [KeyItems.KEY_STONE] = 1,
                              [KeyItems.TERA_ORB] = 1 })
  local armState = Arm.new()
  armState:onBattleStarted({ battle = battle })
  T.eq(#Overlay.offered(armState), 2, "both are on the cell")

  armState:toggle("tera")
  Resolve.onTurnStarted(armState, { battle = battle })
  T.eq(battle.player.curTypes[1], "GROUND", "arming it terastallizes at turn start")
  T.eq(armState:used("tera"), true, "which spends its own limit")
  T.eq(armState:usedAny(), true, "and the battle's one transformation with it")
  T.eq(#Overlay.offered(armState), 0,
    "so the mega goes off the cell too, unspent though it is")
  T.eq(armState:used("mega"), false, "without its own flag being spent")

  -- And the other way round: a mega spends the Tera.
  local battle2 = makeBattle({ [KeyItems.KEY_STONE] = 1,
                               [KeyItems.TERA_ORB] = 1 })
  local armState2 = Arm.new()
  armState2:onBattleStarted({ battle = battle2 })
  armState2:toggle("mega")
  Resolve.onTurnStarted(armState2, { battle = battle2 })
  T.eq(battle2.player.mon.form, "MEGA_X", "megaing works as it always did")
  T.eq(#Overlay.offered(armState2), 0, "and takes the Tera off the cell")
  T.eq(#battle2.player.curTypes, 2,
    "which is not terastallized: it is wearing the mega's own two types")
end

-- ---------------------------------------------------------------------
-- The label fits the cell.  tests/battle_forms_menu_test.lua measures every
-- shipping label against the budget; this is the same arithmetic stated
-- where the label is chosen, so a rename here fails here first.
-- ---------------------------------------------------------------------
do
  local GLYPH = 8
  local ARMED = 1
  local budget = Menu.CELL.classic.limit - Menu.CELL.classic.label
  local label = Tera.entry(Tera.new()).label
  T.eq(label, "TERA", "the cell reads TERA")
  T.check((#label + ARMED) * GLYPH <= budget,
    "which fits the classic layout's " .. budget .. " pixels armed")
  T.check(#label <= 7,
    "and is inside the seven characters that budget is worth at all")
end

-- ---------------------------------------------------------------------
-- Gen 2: no battler wrapper, no curTypes -- the override lives on
-- mon.formTypes, the field src/gen2forms.lua's speciesDef wrap reads, and
-- is proven against the REAL game/src/battle/gen2/Battle.lua class rather
-- than a hand-rolled double: install the real speciesDef wrap, terastallize,
-- and read the type back off the real engine method every other Gen 2
-- damage/AI/immunity call site already goes through.
-- ---------------------------------------------------------------------
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local RealBattle = require("src.battle.gen2.Battle")

local GEN2_DATA = { type_chart = CHART, pokemon = {} }

local function gen2Mon()
  return { species = "CHARIZARD", level = 50, item = "TERA_ORB_HOLDER",
           dvs = {}, statExp = {},
           stats = { attack = 84, defense = 78, speed = 100,
                     specialAttack = 85, specialDefense = 85 } }
end

local function gen2Battle(bag)
  local mon = gen2Mon()
  local enemy = gen2Mon()
  return {
    data = GEN2_DATA, save = { inventory = bag or {} },
    player = mon, enemy = enemy, events = {},
    emit = RealBattle.emit, takeEvents = RealBattle.takeEvents,
    monName = RealBattle.monName,
  }
end

local function bindGen2Tera(chosen, log)
  Tera.bind({ keyitems = KeyItems, announce = Announce, log = log,
              battlerof = Battlerof, gen2 = true,
              chosen = function() return chosen end })
end

do
  T.eq(Gen2Forms.install({ log = nil }), true,
    "precondition: the real speciesDef wrap installs")

  bindGen2Tera("GROUND")
  local state = Tera.new()
  local battle = gen2Battle({ [KeyItems.TERA_ORB] = 1 })

  T.eq(RealBattle.speciesDef({ data = battle.data }, battle.player), nil,
    "precondition: an unformed Gen 2 mon carries no record from this seam "
      .. "at all (this fixture's CHARIZARD has no national_dex record)")

  T.eq(Tera.entry(state).activate(battle), true, "terastallizing succeeds on Gen 2")
  T.same(battle.player.formTypes, { "GROUND" },
    "mon.formTypes is set directly -- there is no battler to hold a curTypes copy")
  T.eq(battle.player.form, nil,
    "and mon.form is left alone -- Tera marks no form on either generation")
  T.same(RealBattle.speciesDef({ data = battle.data }, battle.player).types,
    { "GROUND" },
    "the real Battle.speciesDef wrap reads it back, the same seam every "
      .. "Gen 2 damage/AI/immunity call site already goes through")

  local events = battle:takeEvents()
  T.eq(#events, 2, "the Gen 2 message channel got both pages")
  T.eq(events[1].text, "CHARIZARD\nTerastallized!", "the same wording as Gen 1")
end

-- TERA BLAST is explicitly NOT substituted on Gen 2: Gen 2 has no curMoves
-- array to swap the way src/substitute.lua does, and that mechanism is out
-- of scope for this pass (0.42.0's own finding, extended here rather than
-- reopened). Arming still succeeds -- the cell must still work -- it just
-- substitutes nothing.
do
  bindGen2Tera("GROUND")
  local state = Tera.new()
  local entry = Tera.entry(state, { byType = { GROUND = "SOME_MOVE_ID" } })
  local battle = gen2Battle({ [KeyItems.TERA_ORB] = 1 })
  battle.player.moves = { { id = "TERABLAST", pp = 5 } }

  T.eq(entry.arm(battle), true, "arming still succeeds on Gen 2")
  T.same(battle.player.moves, { { id = "TERABLAST", pp = 5 } },
    "but the moveset is completely untouched -- no curMoves array exists to swap")
end

-- Switching survives it, and it has to be reapplied on every switch-in
-- because persistent/fusion's own switch-in handlers run first (main.lua's
-- own ordering) and would otherwise stomp mon.formTypes with THEIR form's
-- types -- Tera is the outermost layer on Gen 2 exactly as it is on Gen 1.
do
  bindGen2Tera("GROUND")
  local state = Tera.new()
  local battle = gen2Battle({ [KeyItems.TERA_ORB] = 1 })
  local mon = battle.player
  Tera.entry(state).activate(battle)

  -- Something else (a persistent form's own reapply) sets formTypes first.
  mon.formTypes = { "FIRE", "FLYING" }
  Tera.onBattlerSwitched(state, { battle = battle, battler = mon })
  T.same(mon.formTypes, { "GROUND" },
    "Tera's own switch-in handler reasserts on top of it")

  Tera.onBattleEnded(state, { battle = battle })
  T.same(mon.formTypes, { "FIRE", "FLYING" },
    "and unwinding restores whatever was underneath, not nil unconditionally")
end

-- Fainting and the battle ending both restore mon.formTypes to nil when
-- there was nothing underneath -- unlike Gen 1's battler.curTypes (which is
-- never legitimately nil), a Gen 2 mon with no other claim on it really
-- should end up back at nil.
do
  bindGen2Tera("GROUND")
  local state = Tera.new()
  local battle = gen2Battle({ [KeyItems.TERA_ORB] = 1 })
  Tera.entry(state).activate(battle)
  T.same(battle.player.formTypes, { "GROUND" }, "precondition: terastallized")

  Tera.onFainted(state, { battle = battle, battler = battle.player })
  T.eq(battle.player.formTypes, nil, "fainting clears it back to nil")
  T.eq(state.mon, nil, "and drops the mon reference")
end

T.finish("battle_forms_tera")
