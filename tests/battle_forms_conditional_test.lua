-- Condition-driven forms: automatic, repeatable, and nowhere near the mega
-- path.
--
-- Half of this suite is the flips themselves, and the emphasis inside that
-- half is on flipping BACK -- and back again.  A Darmanitan that enters Zen
-- Mode once and stays there forever would pass any check that only looked at
-- the first transition, and the one-way shape is exactly what a form
-- primitive built for mega evolution could plausibly have had.  The other
-- half is what these must not touch: the armed flag, the MEGA cell, and a
-- form some other transformation type put on the mon.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Conditional = dofile(MOD .. "/src/conditional.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local rows = dofile(MOD .. "/data/conditional.lua")
-- The whole mega roster: what these forms must stay clear of is every mega,
-- not the option's current selection.
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- Every pair differs in a stat AND in typing, so a check can tell an applied
-- override from a battler that merely kept what it was built with.  The base
-- records carry no `form` field and the form records all do, which is what
-- Forms.becomeForm marks the mon with.
local function stats(hp, attack, defense, speed, special)
  return { hp = hp, attack = attack, defense = defense,
           speed = speed, special = special }
end

local DATA = { pokemon = {
  DARMANITAN     = { baseStats = stats(105, 140, 55, 95, 30),
                     types = { "FIRE" } },
  DARMANITAN_ZEN = { baseStats = stats(105, 30, 105, 55, 140),
                     types = { "FIRE", "PSYCHIC_TYPE" }, form = "ZEN" },
  MINIOR         = { baseStats = stats(60, 60, 100, 60, 100),
                     types = { "ROCK", "FLYING" } },
  MINIOR_RED     = { baseStats = stats(60, 100, 60, 120, 100),
                     types = { "ROCK", "FLYING" }, form = "RED" },
  WISHIWASHI     = { baseStats = stats(45, 20, 20, 40, 25),
                     types = { "WATER" } },
  WISHIWASHI_SCHOOL = { baseStats = stats(45, 140, 130, 30, 140),
                        types = { "WATER" }, form = "SCHOOL" },
  AEGISLASH      = { baseStats = stats(60, 50, 140, 60, 50),
                     types = { "STEEL", "GHOST" } },
  AEGISLASH_BLADE = { baseStats = stats(60, 140, 50, 60, 140),
                      types = { "STEEL", "GHOST" }, form = "BLADE" },
  MORPEKO        = { baseStats = stats(58, 95, 58, 97, 70),
                     types = { "ELECTRIC" } },
  MORPEKO_HANGRY = { baseStats = stats(58, 95, 58, 97, 70),
                     types = { "ELECTRIC", "DARK" }, form = "HANGRY" },
  MIMIKYU        = { baseStats = stats(55, 90, 80, 96, 50),
                     types = { "GHOST" } },
  MIMIKYU_BUSTED = { baseStats = stats(55, 90, 80, 96, 50),
                     types = { "GHOST", "FAIRY" }, form = "BUSTED" },
  EISCUE         = { baseStats = stats(75, 80, 110, 50, 65),
                     types = { "ICE" } },
  EISCUE_NOICE   = { baseStats = stats(75, 80, 70, 130, 65),
                     types = { "ICE", "WATER" }, form = "NOICE" },
  GRENINJA       = { baseStats = stats(72, 95, 67, 122, 103),
                     types = { "WATER" } },
  GRENINJA_ASH   = { baseStats = stats(72, 145, 67, 132, 153),
                     types = { "WATER", "DARK" }, form = "ASH" },
  GRENINJA_MEGA  = { baseStats = stats(72, 145, 87, 142, 153),
                     types = { "WATER", "POISON" }, form = "MEGA" },
  CHARIZARD      = { baseStats = stats(78, 84, 78, 100, 85),
                     types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = stats(78, 130, 111, 100, 130),
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

Conditional.bind({ forms = Forms, rows = rows, battlerof = Battlerof })
-- Mega evolution reaches the menu and turn resolution through the registry,
-- with nothing else registered -- exactly the shape the shipping mod wires.
local registry = Transforms.new()
registry:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                               keyitems = KeyItems, animId = "TESTANIM",
                               battlerof = Battlerof }))
Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
               megas = megas, battlerof = Battlerof })
Overlay.bind({ registry = registry })

local function newMon(species, level, held)
  local base = DATA.pokemon[species].baseStats
  local mon = { species = species, level = level or 50,
                dvs = { hp = 15, attack = 15, defense = 15,
                        speed = 15, special = 15 },
                statExp = {}, [E.STAMP] = held }
  mon.stats = stats(base.hp, base.attack, base.defense, base.speed, base.special)
  mon.hp = mon.stats.hp
  return mon
end

local function battlerFor(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, curStats = mon.stats,
           curTypes = DATA.pokemon[mon.species].types }
end

-- phase/queue are what Overlay.shouldOffer needs to say yes at all, so every
-- battle here is built in the state where a MEGA cell WOULD be drawn.  A
-- conditional mon being offered nothing then means the species, not the
-- moment.
local function makeBattle(playerMon, enemyMon)
  -- Carrying the Key Stone, so "no MEGA cell for a conditional species" below
  -- means the species and not an empty bag.
  local battle = { data = DATA, phase = "menu", queue = {},
    game = { save = { inventory = { [KeyItems.KEY_STONE] = 1 } } } }
  battle.player = playerMon and battlerFor(playerMon, true) or nil
  battle.enemy = enemyMon and battlerFor(enemyMon, false) or nil
  return battle
end

-- The engine writes the HP and THEN emits, so every damage event here sets
-- the mon's HP first: firing battle.damage_dealt with the old HP still in
-- place would be testing an order the engine does not have.
local function hurtTo(battle, battler, fraction, damage)
  battler.mon.hp = math.floor(battler.mon.stats.hp * fraction)
  Conditional.onDamageDealt({
    battle = battle,
    user = battler == battle.player and battle.enemy or battle.player,
    target = battler, move = { id = "TACKLE", power = 35 },
    damage = damage or 1,
  })
end

local function healTo(battle, battler, fraction)
  battler.mon.hp = math.floor(battler.mon.stats.hp * fraction)
  Conditional.onTurnEnded({ battle = battle })
end

--------------------------------------------------------------------------
-- The table itself
--------------------------------------------------------------------------

-- Every trigger name must be one src/conditional.lua actually dispatches on.
-- A typo here is a row that loads, validates against national.lua, has art,
-- and then never fires -- the quietest failure this subsystem can have.
local DISPATCHED = { hp = true, move_kind = true, hit_taken = true,
                     knockout_dealt = true, turn_end = true }
local seen = 0
for species, row in pairs(rows) do
  seen = seen + 1
  T.check(DISPATCHED[row.trigger] == true,
    species .. " names a trigger src/conditional.lua dispatches on ("
      .. tostring(row.trigger) .. ")")
  T.check(type(row.form) == "string" and row.form ~= "",
    species .. " names a form id")
  if row.trigger == "hp" then
    T.check(row.below ~= nil or row.above ~= nil,
      species .. " is an HP row and carries a threshold to compare against")
  end
end
T.eq(seen, 8, "the table wires eight species")

--------------------------------------------------------------------------
-- HP thresholds, in both directions and repeatedly
--------------------------------------------------------------------------

local dar = newMon("DARMANITAN")
local darBattle = makeBattle(dar, newMon("CHARIZARD"))
local darBase = dar.stats

Conditional.onBattleStarted({ battle = darBattle })
T.eq(dar.form, nil, "a Darmanitan at full HP enters battle in its base form")

hurtTo(darBattle, darBattle.player, 0.4)
T.eq(dar.form, "ZEN", "crossing below the threshold enters Zen Mode")
T.eq(darBattle.player.curTypes[2], "PSYCHIC_TYPE",
  "and the form's types are applied")
T.check(darBattle.player.curStats.special > darBase.special,
  "and the form's stats are applied")
T.eq(dar.stats, darBase, "the mon's own stat block is never touched")
T.eq(dar.species, "DARMANITAN", "and neither is its species")

healTo(darBattle, darBattle.player, 1.0)
T.eq(dar.form, nil, "crossing back above the threshold leaves Zen Mode")
T.eq(darBattle.player.curStats, darBase,
  "and curStats is restored to the mon's own block")
T.eq(darBattle.player.curTypes[1], "FIRE", "and curTypes to the base species'")
T.eq(darBattle.player.curTypes[2], nil, "with the form's second type gone")

-- The point of the whole exercise: not one flip, but a flip that keeps
-- working.  Three more full round trips, each asserted on both legs.
for round = 1, 3 do
  hurtTo(darBattle, darBattle.player, 0.3)
  T.eq(dar.form, "ZEN", "round " .. round .. ": re-enters Zen Mode")
  T.check(darBattle.player.curStats.special > darBase.special,
    "round " .. round .. ": with the form's stats again")
  healTo(darBattle, darBattle.player, 0.9)
  T.eq(dar.form, nil, "round " .. round .. ": leaves it again")
  T.eq(darBattle.player.curStats, darBase,
    "round " .. round .. ": with the base stats again")
end

-- Exactly at the threshold counts as below: `below = 0.5` reads as "at or
-- under half", which is where the real mechanic sits.
dar.hp = math.floor(dar.stats.hp / 2)
Conditional.onTurnEnded({ battle = darBattle })
T.eq(dar.form, "ZEN", "sitting exactly on the threshold is inside it")

-- The catch-up pass exists because Gen 1 raises battle.damage_dealt only from
-- the damaging-move hit loop: poison, burn, recoil and a healing item all move
-- the HP with nothing emitted at all.
dar.hp = dar.stats.hp
T.eq(dar.form, "ZEN", "HP moving with no event leaves the form where it was")
Conditional.onTurnEnded({ battle = darBattle })
T.eq(dar.form, nil, "and the end of the turn catches the crossing up")

-- Minior runs the same direction under a different name: the base record is
-- the meteor, and the core is what it breaks into.
local minior = newMon("MINIOR")
local miniorBattle = makeBattle(minior, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = miniorBattle })
T.eq(minior.form, nil, "a healthy Minior is still its meteor")
hurtTo(miniorBattle, miniorBattle.player, 0.45)
T.eq(minior.form, "RED", "and breaks into its core below half HP")
T.check(miniorBattle.player.curStats.speed > minior.stats.speed,
  "which is the faster, frailer stat line")
healTo(miniorBattle, miniorBattle.player, 1.0)
T.eq(minior.form, nil, "and re-forms when the HP comes back")

--------------------------------------------------------------------------
-- The HP row that runs the other way, and its level gate
--------------------------------------------------------------------------

local wishi = newMon("WISHIWASHI")
local wishiBattle = makeBattle(wishi, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = wishiBattle })
T.eq(wishi.form, "SCHOOL", "a healthy Wishiwashi enters battle already schooling")
T.check(wishiBattle.player.curStats.attack > wishi.stats.attack,
  "with the school's stats")

hurtTo(wishiBattle, wishiBattle.player, 0.2)
T.eq(wishi.form, nil, "and breaks up when its HP falls under the threshold")
T.eq(wishiBattle.player.curStats, wishi.stats, "back to the solo stat line")

healTo(wishiBattle, wishiBattle.player, 0.6)
T.eq(wishi.form, "SCHOOL", "and re-forms when the HP comes back")

-- The level gate is a property of the row, not of the moment, so it holds at
-- full HP where nothing else would stop the form.
local small = newMon("WISHIWASHI", 19)
local smallBattle = makeBattle(small, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = smallBattle })
T.eq(small.form, nil, "a Wishiwashi under the level gate never schools")
Conditional.onTurnEnded({ battle = smallBattle })
T.eq(small.form, nil, "and does not start at the end of a turn either")

--------------------------------------------------------------------------
-- Move-driven stance
--------------------------------------------------------------------------

local aegis = newMon("AEGISLASH")
local aegisBattle = makeBattle(aegis, newMon("CHARIZARD"))
local aegisBase = aegis.stats

local function aegisUses(power)
  Conditional.onMoveUsed({ battle = aegisBattle, user = aegisBattle.player,
                           target = aegisBattle.enemy,
                           move = { id = "MOVE", power = power } })
end

Conditional.onBattleStarted({ battle = aegisBattle })
T.eq(aegis.form, nil, "Aegislash enters battle in its shield form")

aegisUses(80)
T.eq(aegis.form, "BLADE", "an attacking move draws the blade")
T.check(aegisBattle.player.curStats.attack > aegisBase.attack,
  "with the blade's attack")

aegisUses(0)
T.eq(aegis.form, nil, "a status move puts it back up")
T.eq(aegisBattle.player.curStats, aegisBase, "with the shield's stats")

for round = 1, 3 do
  aegisUses(60)
  T.eq(aegis.form, "BLADE", "round " .. round .. ": draws again")
  aegisUses(0)
  T.eq(aegis.form, nil, "round " .. round .. ": shields again")
end

-- An HP row and a move row must not answer each other's events.
hurtTo(aegisBattle, aegisBattle.player, 0.1)
T.eq(aegis.form, nil, "Aegislash does not change form on damage")
Conditional.onMoveUsed({ battle = darBattle, user = darBattle.player,
                         target = darBattle.enemy,
                         move = { id = "MOVE", power = 90 } })
T.eq(dar.form, nil, "and Darmanitan does not change form on a move")

--------------------------------------------------------------------------
-- The end-of-turn alternation
--------------------------------------------------------------------------

local morp = newMon("MORPEKO")
local morpBattle = makeBattle(morp, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = morpBattle })
T.eq(morp.form, nil, "Morpeko enters battle full-bellied")
for round = 1, 4 do
  Conditional.onTurnEnded({ battle = morpBattle })
  T.eq(morp.form, "HANGRY", "turn " .. round .. ": gets hangry")
  T.eq(morpBattle.player.curTypes[2], "DARK",
    "turn " .. round .. ": with the hangry typing")
  Conditional.onTurnEnded({ battle = morpBattle })
  T.eq(morp.form, nil, "turn " .. round .. ": and back again")
  T.eq(morpBattle.player.curTypes[2], nil,
    "turn " .. round .. ": with the typing back too")
end

--------------------------------------------------------------------------
-- Taking a hit, and dealing a knockout
--------------------------------------------------------------------------

local mimi = newMon("MIMIKYU")
local mimiBattle = makeBattle(mimi, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = mimiBattle })
T.eq(mimi.form, nil, "Mimikyu enters battle disguised")

-- A hit that dealt nothing is not a hit that broke anything.
mimi.hp = mimi.stats.hp
Conditional.onDamageDealt({ battle = mimiBattle, user = mimiBattle.enemy,
                            target = mimiBattle.player,
                            move = { id = "TACKLE", power = 35 }, damage = 0 })
T.eq(mimi.form, nil, "a hit that dealt no damage leaves the disguise up")

hurtTo(mimiBattle, mimiBattle.player, 0.8)
T.eq(mimi.form, "BUSTED", "a damaging hit busts it")
T.eq(mimiBattle.player.curTypes[2], "FAIRY", "with the busted typing")

-- Sticky: nothing in Gen 1 puts the disguise back, so no later event may.
Conditional.onTurnEnded({ battle = mimiBattle })
T.eq(mimi.form, "BUSTED", "and the end of a turn does not restore it")
mimi.hp = mimi.stats.hp
Conditional.onTurnEnded({ battle = mimiBattle })
T.eq(mimi.form, "BUSTED", "and neither does healing back to full")

local eis = newMon("EISCUE")
local eisBattle = makeBattle(eis, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = eisBattle })
hurtTo(eisBattle, eisBattle.player, 0.7)
T.eq(eis.form, "NOICE", "Eiscue's face breaks on a damaging hit")
T.check(eisBattle.player.curStats.speed > eis.stats.speed,
  "leaving the faster stat line behind")

-- Battle Bond reads the same payload from the dealing end.
local gren = newMon("GRENINJA")
local grenBattle = makeBattle(gren, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = grenBattle })
T.eq(gren.form, nil, "Greninja enters battle ordinary")

grenBattle.enemy.mon.hp = grenBattle.enemy.mon.stats.hp
Conditional.onDamageDealt({ battle = grenBattle, user = grenBattle.player,
                            target = grenBattle.enemy,
                            move = { id = "SURF", power = 95 }, damage = 5 })
T.eq(gren.form, nil, "a hit that did not knock anything out is not a bond")

grenBattle.enemy.mon.hp = 0
Conditional.onDamageDealt({ battle = grenBattle, user = grenBattle.player,
                            target = grenBattle.enemy,
                            move = { id = "SURF", power = 95 }, damage = 99 })
T.eq(gren.form, "ASH", "a knockout it dealt does bond it")
T.check(grenBattle.player.curStats.special > gren.stats.special,
  "with the bonded stat line")

-- A mon on its way down is the faint handler's, not this module's.
local dying = newMon("DARMANITAN")
local dyingBattle = makeBattle(dying, newMon("CHARIZARD"))
dying.hp = 0
Conditional.onDamageDealt({ battle = dyingBattle, user = dyingBattle.enemy,
                            target = dyingBattle.player,
                            move = { id = "TACKLE", power = 35 }, damage = 99 })
T.eq(dying.form, nil, "a Darmanitan knocked out below the threshold is left alone")

--------------------------------------------------------------------------
-- What must not be touched
--------------------------------------------------------------------------

-- A form some other transformation type put on the mon is not this module's
-- to overwrite.  Greninja is the case that actually arises: it is the one
-- species here that also has a mega, so a knockout can land on a mon that
-- already spent the trainer's one mega for the battle.
local megaGren = newMon("GRENINJA", 50, "GRENINJAITE")
local megaBattle = makeBattle(megaGren, newMon("CHARIZARD"))
T.eq(Forms.becomeForm(DATA, megaBattle.player, "GRENINJA_MEGA"), true,
  "a Greninja megas first")
megaBattle.enemy.mon.hp = 0
Conditional.onDamageDealt({ battle = megaBattle, user = megaBattle.player,
                            target = megaBattle.enemy,
                            move = { id = "SURF", power = 95 }, damage = 99 })
T.eq(megaGren.form, "MEGA",
  "and a knockout does not quietly replace the mega with Ash-Greninja")
T.check(megaBattle.player.curTypes[2] == "POISON",
  "the mega's typing is still the one in force")

-- The other direction: a form this module did not put on is never taken off.
local marked = newMon("DARMANITAN")
local markedBattle = makeBattle(marked, newMon("CHARIZARD"))
marked.form = "MEGA_X"
marked.hp = marked.stats.hp
Conditional.onTurnEnded({ battle = markedBattle })
T.eq(marked.form, "MEGA_X",
  "a Darmanitan above the threshold does not unwind a foreign form mark")

-- The armed flag and the MEGA cell.  A conditional form that spent either
-- would pass every check above.
local armState = Arm.new()
local cellMon = newMon("DARMANITAN")
local cellBattle = makeBattle(cellMon, newMon("CHARIZARD"))
armState:onBattleStarted({ battle = cellBattle })
T.eq(Overlay.shouldOffer(armState), false,
  "no MEGA cell is offered for a species with only a conditional form")
hurtTo(cellBattle, cellBattle.player, 0.3)
T.eq(cellMon.form, "ZEN", "the conditional form still happens")
T.eq(armState:used(Mega.ID), false, "and the trainer's one mega is not spent")
T.eq(armState:usedAny(), false,
  "nor the one manual transformation the whole battle shares")
T.eq(armState:isArmed(), false, "and nothing was armed")
T.eq(Overlay.shouldOffer(armState), false,
  "and still no MEGA cell after the change")

-- The same boundary from the other side, which is what 0.14.0 put at risk: the
-- trainer has already used their one manual transformation, and a
-- condition-driven form must not have been swept up by that.  These forms are
-- not in the registry, are unlimited, and flip back and forth by design, so a
-- spent arm state is nothing they can be asked about.
local lockedState = Arm.new()
local lockedMon = newMon("DARMANITAN")
local lockedBattle = makeBattle(lockedMon, newMon("CHARIZARD"))
lockedState:onBattleStarted({ battle = lockedBattle })
lockedState:consume(Mega.ID)
T.eq(lockedState:usedAny(), true,
  "precondition: the battle's manual transformation is spent")
hurtTo(lockedBattle, lockedBattle.player, 0.3)
T.eq(lockedMon.form, "ZEN",
  "a conditional form still fires after the manual one was used")
-- And flips back, which is the part a once-per-battle limit would have killed
-- most quietly: the change happening once and never again looks like a working
-- mechanic right up until the mon is healed.
healTo(lockedBattle, lockedBattle.player, 0.9)
T.eq(lockedMon.form, nil, "and still flips back, unlimited, as it always has")
hurtTo(lockedBattle, lockedBattle.player, 0.2)
T.eq(lockedMon.form, "ZEN", "and back again")
T.eq(lockedState:used(Mega.ID), true, "with the spent flag it found untouched")

--------------------------------------------------------------------------
-- Coming back from the bench
--------------------------------------------------------------------------

-- makeBattler is form-blind, so a mon returning from the bench arrives with
-- base stats and types even though its mark survived.  Both kinds of row have
-- to survive that, by different routes: an HP row is re-derived, a sticky one
-- is simply reapplied.
local benched = newMon("DARMANITAN")
local benchBattle = makeBattle(benched, newMon("CHARIZARD"))
hurtTo(benchBattle, benchBattle.player, 0.3)
T.eq(benched.form, "ZEN", "a Darmanitan is in Zen Mode before it switches out")
local freshDar = battlerFor(benched, true)
benchBattle.player = freshDar
Conditional.onBattlerSwitched({ battle = benchBattle, battler = freshDar })
T.eq(benched.form, "ZEN", "and is still in Zen Mode on the way back in")
T.check(freshDar.curStats.special > benched.stats.special,
  "with the form's stats reapplied to the new battler")
T.eq(freshDar.curTypes[2], "PSYCHIC_TYPE", "and its types")

-- Healed on the bench, it comes back out of the form rather than merely
-- keeping it: the answer is re-derived, not remembered.
benched.hp = benched.stats.hp
local healedDar = battlerFor(benched, true)
healedDar.curStats = freshDar.curStats
benchBattle.player = healedDar
Conditional.onBattlerSwitched({ battle = benchBattle, battler = healedDar })
T.eq(benched.form, nil, "a Darmanitan healed on the bench comes back normal")
T.eq(healedDar.curStats, benched.stats, "with the base stat line")

local busted = newMon("MIMIKYU")
local bustBattle = makeBattle(busted, newMon("CHARIZARD"))
hurtTo(bustBattle, bustBattle.player, 0.8)
T.eq(busted.form, "BUSTED", "a Mimikyu busts before switching out")
local freshMimi = battlerFor(busted, true)
bustBattle.player = freshMimi
Conditional.onBattlerSwitched({ battle = bustBattle, battler = freshMimi })
T.eq(busted.form, "BUSTED", "and comes back still busted")
T.eq(freshMimi.curTypes[2], "FAIRY",
  "with the busted typing reapplied to the new battler")

--------------------------------------------------------------------------
-- Unwinding
--------------------------------------------------------------------------

local fainter = newMon("DARMANITAN")
local faintBattle = makeBattle(fainter, newMon("CHARIZARD"))
hurtTo(faintBattle, faintBattle.player, 0.3)
T.eq(fainter.form, "ZEN", "a Darmanitan is in Zen Mode")
Resolve.onFainted({ battle = faintBattle, battler = faintBattle.player })
T.eq(fainter.form, nil, "and reverts the moment it faints")
T.eq(faintBattle.player.curStats, fainter.stats, "with its own stats back")

-- The party sweep is what catches a mon that transformed and was benched
-- before the battle ended: it never has a battler to revert through.
local swept = newMon("MORPEKO")
local sweptEnemy = newMon("EISCUE")
local endBattle = makeBattle(swept, sweptEnemy)
Conditional.onTurnEnded({ battle = endBattle })
hurtTo(endBattle, endBattle.enemy, 0.7)
T.eq(swept.form, "HANGRY", "a Morpeko is hangry when the battle ends")
T.eq(sweptEnemy.form, "NOICE", "and the enemy Eiscue's face is broken")

local benchedMimi = newMon("MIMIKYU")
benchedMimi.form = "BUSTED"
endBattle.game = { save = { party = { swept, benchedMimi } } }
endBattle.enemyParty = { sweptEnemy }
Resolve.onBattleEnded({ battle = endBattle })
T.eq(swept.form, nil, "the battle ending unwinds the active mon")
T.eq(benchedMimi.form, nil, "and the benched one the sweep is there for")
T.eq(sweptEnemy.form, nil, "and the enemy's too")

--------------------------------------------------------------------------
-- No state of its own
--------------------------------------------------------------------------

-- The module keeps nothing between battles, so a second Morpeko starts its
-- own alternation from the beginning rather than continuing the first one's.
local nextMorp = newMon("MORPEKO")
local nextBattle = makeBattle(nextMorp, newMon("CHARIZARD"))
Conditional.onBattleStarted({ battle = nextBattle })
T.eq(nextMorp.form, nil, "a fresh Morpeko in a fresh battle starts full-bellied")
Conditional.onTurnEnded({ battle = nextBattle })
T.eq(nextMorp.form, "HANGRY", "and alternates from there")

-- A species with no row is never touched, whichever event arrives.
local zard = newMon("CHARIZARD")
local zardBattle = makeBattle(zard, newMon("DARMANITAN"))
Conditional.onBattleStarted({ battle = zardBattle })
hurtTo(zardBattle, zardBattle.player, 0.1)
Conditional.onMoveUsed({ battle = zardBattle, user = zardBattle.player,
                         target = zardBattle.enemy,
                         move = { id = "MOVE", power = 90 } })
Conditional.onTurnEnded({ battle = zardBattle })
T.eq(zard.form, nil, "a species with no row is left alone by every trigger")

-- A battle with only one side, and payloads missing the pieces a handler
-- reads, must not error: these events fire from paths this mod does not own.
local loneBattle = makeBattle(newMon("DARMANITAN"), nil)
Conditional.onBattleStarted({ battle = loneBattle })
Conditional.onTurnEnded({ battle = loneBattle })
Conditional.onBattlerSwitched({ battle = loneBattle })
Conditional.onDamageDealt({ battle = loneBattle })
Conditional.onMoveUsed({ battle = loneBattle })
Conditional.onBattleStarted(nil)
Conditional.onTurnEnded({})
Conditional.onDamageDealt({})
Conditional.onMoveUsed({})
Conditional.onBattlerSwitched({})
T.check(true, "empty and one-sided payloads are survived rather than indexed")

T.finish("battle_forms_conditional")
