-- The line a form change prints, and the eight that print nothing.
--
-- Half of this suite is about the message and the other half is about its
-- absence: a mod that narrated every Aegislash stance and every Morpeko round
-- would pass every check in the first half and be unplayable.
--
-- The two queue doubles below are the engine's own implementations copied
-- field for field (BattleState:say, :sayNext, :animNext), because WHERE a row
-- lands is the entire question -- a double that merely appended would make
-- both placements look identical and prove nothing.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Announce = dofile(MOD .. "/src/announce.lua")
local Primal = dofile(MOD .. "/src/primal.lua")
local Conditional = dofile(MOD .. "/src/conditional.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local primals = dofile(MOD .. "/data/primals.lua")
local rows = dofile(MOD .. "/data/conditional.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local DATA = { pokemon = {
  GROUDON = { baseStats = { hp = 100, attack = 150, defense = 140,
                            speed = 90, special = 100 },
              types = { "GROUND" } },
  GROUDON_PRIMAL = { baseStats = { hp = 100, attack = 180, defense = 160,
                                   speed = 90, special = 150 },
                     types = { "GROUND", "FIRE" }, form = "PRIMAL" },
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
  AEGISLASH = { baseStats = { hp = 60, attack = 50, defense = 150,
                              speed = 60, special = 150 },
                types = { "GHOST" } },
  AEGISLASH_BLADE = { baseStats = { hp = 60, attack = 150, defense = 50,
                                    speed = 60, special = 150 },
                      types = { "GHOST" }, form = "BLADE" },
  MORPEKO = { baseStats = { hp = 58, attack = 95, defense = 58,
                            speed = 97, special = 70 },
              types = { "ELECTRIC" } },
  MORPEKO_HANGRY = { baseStats = { hp = 58, attack = 95, defense = 58,
                                   speed = 97, special = 70 },
                     types = { "ELECTRIC" }, form = "HANGRY" },
  DARMANITAN = { baseStats = { hp = 105, attack = 140, defense = 55,
                               speed = 95, special = 55 },
                 types = { "FIRE" } },
  DARMANITAN_ZEN = { baseStats = { hp = 105, attack = 30, defense = 105,
                                   speed = 55, special = 105 },
                     types = { "FIRE", "PSYCHIC" }, form = "ZEN" },
} }

local function newMon(species, held)
  local base = DATA.pokemon[species].baseStats
  local mon = { species = species, level = 50,
                dvs = { hp = 15, attack = 15, defense = 15,
                        speed = 15, special = 15 },
                statExp = {}, [E.STAMP] = held }
  mon.stats = { hp = base.hp, attack = base.attack, defense = base.defense,
                speed = base.speed, special = base.special }
  mon.hp = mon.stats.hp
  return mon
end

local function battlerFor(mon, isPlayer, name)
  return { isPlayer = isPlayer, mon = mon, curStats = mon.stats,
           curTypes = DATA.pokemon[mon.species].types,
           name = name or mon.species }
end

-- BattleState's own queue, minus everything that is not insertion order.
-- nextInsert starts nil exactly as it does at battle.turn_started, where the
-- engine clears it the moment the queue drains.
local function makeBattle(playerMon, enemyMon, names)
  names = names or {}
  local b = {
    data = DATA, phase = "menu", queue = {}, nextInsert = nil,
    player = playerMon and battlerFor(playerMon, true, names.player) or nil,
    enemy = enemyMon and battlerFor(enemyMon, false, names.enemy) or nil,
    animationsOn = function() return true end,
  }
  b.say = function(self, text)
    self.queue[#self.queue + 1] = { text = text }
  end
  b.sayNext = function(self, text)
    self.nextInsert = (self.nextInsert or 0) + 1
    table.insert(self.queue, self.nextInsert, { text = text })
  end
  b.animNext = function(self, name)
    self.nextInsert = (self.nextInsert or 0) + 1
    table.insert(self.queue, self.nextInsert, { anim = name })
  end
  return b
end

local function texts(battle)
  local out = {}
  for _, row in ipairs(battle.queue) do
    if row.text then out[#out + 1] = row.text end
  end
  return out
end

local function rowsOf(text)
  local out = {}
  for line in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
    out[#out + 1] = line
  end
  return out
end

-- ------- the wording -------------------------------------------------

do
  local battle = makeBattle(newMon("GROUDON", "RED_ORB"), nil,
                            { player = "GROUDON" })
  T.eq(Announce.primal(battle, battle.player), true, "the primal line is emitted")
  T.eq(texts(battle)[1], "GROUDON's\nPrimal Reversion!",
    "and reads the mainline games' own line for it")

  local mega = makeBattle(newMon("CHARIZARD", "CHARIZARDITE_X"), nil,
                          { player = "CHARIZARD" })
  T.eq(Announce.mega(mega, mega.player), true, "the mega line is emitted")
  T.eq(texts(mega)[1], "CHARIZARD's\nMega Evolution!",
    "and reads the mainline games' own line for that one")
end

-- pokered qualifies an enemy mon's name in battle text and never the player's
-- (home/text.asm PlaceMoveUsersName), so a message this mod authors has to do
-- the same or read as though the player's own mon reverted.
do
  local battle = makeBattle(nil, newMon("GROUDON", "RED_ORB"),
                            { enemy = "GROUDON" })
  Announce.primal(battle, battle.enemy)
  T.eq(texts(battle)[1], "Enemy GROUDON's\nPrimal Reversion!",
    "an enemy mon's line carries pokered's Enemy qualifier")
end

-- The box is 18 characters a row.  The widest line either template can produce
-- is an enemy mon with the longest nickname Gen 1 allows, which lands exactly
-- on the limit -- so this is the check that a wording change cannot quietly
-- push a line off the right edge.
do
  local WIDTH = 18
  local longest = "ABCDEFGHIJ" -- a full ten-character Gen 1 nickname
  for _, case in ipairs({ { Announce.primal, "primal" },
                          { Announce.mega, "mega" } }) do
    for _, side in ipairs({ "player", "enemy" }) do
      local battle = makeBattle(newMon("GROUDON", "RED_ORB"),
                                newMon("GROUDON", "RED_ORB"),
                                { player = longest, enemy = longest })
      case[1](battle, battle[side])
      for _, line in ipairs(rowsOf(texts(battle)[1])) do
        T.check(#line <= WIDTH,
          ("%s's %s line fits the text box (%q is %d of %d)")
            :format(case[2], side, line, #line, WIDTH))
      end
    end
  end
end

-- ------- where the line lands ----------------------------------------

-- Primal reversion resolves from the send-out seams, where the engine is
-- part-way through inserting its own rows through nextInsert.  Appending is
-- the only insert that cannot take that cursor from it.
do
  local battle = makeBattle(newMon("GROUDON", "RED_ORB"), nil,
                            { player = "GROUDON" })
  battle.queue[1] = { text = "already queued" }
  Announce.primal(battle, battle.player)
  T.eq(#battle.queue, 2, "the primal line was added, not inserted over")
  T.eq(texts(battle)[2], "GROUDON's\nPrimal Reversion!",
    "and landed behind whatever the queue already held")
  T.eq(battle.nextInsert, nil,
    "the battle's own insert cursor was never touched")
end

-- Mega evolution resolves from battle.turn_started with the queue drained, so
-- the cursor is the mod's to use -- and using it is what keeps the line ahead
-- of the animation queued straight after, the order pokered narrates moves in.
do
  local battle = makeBattle(newMon("CHARIZARD", "CHARIZARDITE_X"), nil,
                            { player = "CHARIZARD" })
  local entry = Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                             animId = "TESTANIM", announce = Announce })
  T.eq(entry.activate(battle), true, "precondition: the mega happened")
  T.eq(battle.queue[1] and battle.queue[1].text, "CHARIZARD's\nMega Evolution!",
    "the message is the first row of the turn")
  T.eq(battle.queue[2] and battle.queue[2].anim, "TESTANIM",
    "and the animation follows it rather than preceding it")
end

-- A player who turned battle animations off asked for no animation, not for no
-- mega and no word of one: that combination is how a mega became as silent as
-- primal reversion was.
do
  local battle = makeBattle(newMon("CHARIZARD", "CHARIZARDITE_X"), nil,
                            { player = "CHARIZARD" })
  battle.animationsOn = function() return false end
  local entry = Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                             animId = "TESTANIM", announce = Announce })
  entry.activate(battle)
  T.eq(#texts(battle), 1, "animations off still leaves the message")
  T.eq(battle.queue[1].anim, nil, "and queues no animation")
end

-- A refusal must stay silent: becomeForm answering no means nothing changed,
-- and a line printed anyway would be the mod claiming a transformation the
-- player did not get.
do
  local battle = makeBattle(newMon("CHARIZARD", "CHARIZARDITE_X"), nil,
                            { player = "CHARIZARD" })
  battle.data = { pokemon = { CHARIZARD = DATA.pokemon.CHARIZARD } }
  local entry = Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                             animId = "TESTANIM", announce = Announce })
  T.eq(entry.activate(battle), false, "precondition: the mega was refused")
  T.eq(#battle.queue, 0, "a refused mega says nothing")
end

-- ------- primal reversion through its own module ---------------------

Primal.bind({ forms = Forms, eligibility = E, primals = primals,
              announce = Announce })

do
  local mon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(mon, nil, { player = "GROUDON" })
  Primal.onBattleStarted({ battle = battle })
  T.eq(mon.form, "PRIMAL", "precondition: the reversion happened")
  T.eq(#texts(battle), 1, "and said so, which is the whole point of the change")
  T.eq(texts(battle)[1], "GROUDON's\nPrimal Reversion!", "in the right words")
end

-- becomeForm is idempotent and this handler is deliberately called on every
-- switch-in, so a message keyed on success rather than on change would print
-- again every time an already-primal Groudon came back from the bench.
do
  local mon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(mon, nil, { player = "GROUDON" })
  Primal.onBattleStarted({ battle = battle })
  T.eq(#texts(battle), 1, "precondition: announced once on the way in")

  battle.player.curStats = mon.stats -- what makeBattler hands back on a switch
  Primal.onBattlerSwitched({ battle = battle, battler = battle.player })
  T.eq(#texts(battle), 1, "switching a primal mon back in announces nothing")
  T.check(battle.player.curStats ~= mon.stats,
    "but the stat override was reapplied all the same")
end

do
  local mon = newMon("GROUDON", nil)
  local battle = makeBattle(mon, nil, { player = "GROUDON" })
  Primal.onBattleStarted({ battle = battle })
  T.eq(mon.form, nil, "precondition: no orb, no reversion")
  T.eq(#battle.queue, 0, "and nothing is said about one")
end

do
  local mon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(mon, nil, { player = "GROUDON" })
  battle.data = { pokemon = { GROUDON = DATA.pokemon.GROUDON } }
  Primal.onBattleStarted({ battle = battle })
  T.eq(mon.form, nil, "precondition: no record, so becomeForm refused")
  T.eq(#battle.queue, 0, "a refused reversion says nothing either")
end

-- ------- the guards --------------------------------------------------

-- A battler with no name answers nil rather than a placeholder: "nil's Primal
-- Reversion!" is a worse failure than the silence this module exists to end.
do
  local battle = makeBattle(newMon("GROUDON", "RED_ORB"))
  battle.player.name = nil
  T.eq(Announce.primal(battle, battle.player), false,
    "a nameless battler is not announced")
  T.eq(#battle.queue, 0, "and nothing lands in the queue")
  T.eq(Announce.primal(battle, nil), false, "neither is no battler at all")
end

-- The mod runs against whatever build the player has, and a battle object with
-- no say/sayNext is a build this mod cannot narrate -- which must cost it the
-- message and nothing else.
do
  local battle = { data = DATA, queue = {},
                   player = { isPlayer = true, name = "GROUDON" } }
  T.eq(Announce.primal(battle, battle.player), false,
    "a battle with no say function is refused rather than raising")
  T.eq(Announce.mega(battle, battle.player), false, "the same for sayNext")
  T.eq(Announce.primal(nil, nil), false, "and no battle at all is refused too")
end

-- ------- the eight that stay silent ----------------------------------

-- Frequency is the reason, so the check is run over the triggers that recur:
-- a stance flip on every move, an alternation at the end of every round, and
-- a threshold the HP bar can cross more than once in a fight.  Each one is
-- proven to have actually changed the form, so silence here is a decision
-- rather than a mechanic that failed to fire.
Conditional.bind({ forms = Forms, rows = rows })

do
  local mon = newMon("AEGISLASH")
  local battle = makeBattle(mon, nil, { player = "AEGISLASH" })
  local user = battle.player
  for _ = 1, 4 do
    Conditional.onMoveUsed({ battle = battle, user = user,
                             move = { power = 80 } })
    T.eq(mon.form, "BLADE", "precondition: an attacking move draws the blade")
    Conditional.onMoveUsed({ battle = battle, user = user,
                             move = { power = 0 } })
    T.eq(mon.form, nil, "precondition: a status move shields again")
  end
  T.eq(#battle.queue, 0,
    "eight Aegislash stance changes print nothing: a line each would be two "
      .. "prompts a turn for the length of the battle")
end

do
  local mon = newMon("MORPEKO")
  local battle = makeBattle(mon, nil, { player = "MORPEKO" })
  for round = 1, 6 do
    Conditional.onTurnEnded({ battle = battle })
    T.eq(mon.form, round % 2 == 1 and "HANGRY" or nil,
      "precondition: Morpeko alternates at the close of every round")
  end
  T.eq(#battle.queue, 0, "and six rounds of alternating print nothing")
end

do
  local mon = newMon("DARMANITAN")
  local battle = makeBattle(mon, nil, { player = "DARMANITAN" })
  for _ = 1, 3 do
    mon.hp = 10
    Conditional.onTurnEnded({ battle = battle })
    T.eq(mon.form, "ZEN", "precondition: below half enters Zen Mode")
    mon.hp = mon.stats.hp
    Conditional.onTurnEnded({ battle = battle })
    T.eq(mon.form, nil, "precondition: back above half leaves it")
  end
  T.eq(#battle.queue, 0, "and crossing the threshold six times prints nothing")
end

T.finish("battle_forms_announce")
