-- Taking over a battle that started before the mod was enabled.
--
-- The defect this suite exists for was invisible from a chair: enabling the
-- mod from the manager mid-fight meant battle.started had already been and
-- gone, so the arm state never learned which battle it was in and every later
-- decision read "no battle" -- no MEGA cell, no primal reversion, for the rest
-- of the fight and only that fight.  Most of what follows is therefore about
-- what adoption must NOT do, because a second adoption is the one that would
-- hand the trainer a second mega.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Adopt = dofile(MOD .. "/src/adopt.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Primal = dofile(MOD .. "/src/primal.lua")
local Conditional = dofile(MOD .. "/src/conditional.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
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
  DARMANITAN = { baseStats = { hp = 105, attack = 140, defense = 55,
                               speed = 95, special = 55 },
                 types = { "FIRE" } },
  DARMANITAN_ZEN = { baseStats = { hp = 105, attack = 30, defense = 105,
                                   speed = 55, special = 105 },
                     types = { "FIRE", "PSYCHIC" }, form = "ZEN" },
  AEGISLASH = { baseStats = { hp = 60, attack = 50, defense = 150,
                              speed = 60, special = 150 },
                types = { "GHOST" } },
  AEGISLASH_BLADE = { baseStats = { hp = 60, attack = 150, defense = 50,
                                    speed = 60, special = 150 },
                      types = { "GHOST" }, form = "BLADE" },
  MIMIKYU = { baseStats = { hp = 55, attack = 90, defense = 80,
                            speed = 96, special = 50 },
              types = { "GHOST" } },
  MIMIKYU_BUSTED = { baseStats = { hp = 55, attack = 90, defense = 80,
                                   speed = 96, special = 50 },
                     types = { "GHOST" }, form = "BUSTED" },
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

local function battlerFor(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, curStats = mon.stats,
           curTypes = DATA.pokemon[mon.species].types, name = mon.species }
end

-- phase="messages" is the state the real trace caught: a battle part-way
-- through its own message queue when the mod arrived.  The command-menu
-- fields are here so a check can move the same battle to the menu and ask
-- whether the cell would be drawn.
local function makeBattle(playerMon, enemyMon, phase)
  local b = {
    data = DATA, phase = phase or "messages", queue = {}, nextInsert = nil,
    player = playerMon and battlerFor(playerMon, true) or nil,
    enemy = enemyMon and battlerFor(enemyMon, false) or nil,
    -- The trainer's Key Stone.  Adoption is about what a battle already under
    -- way brings across, so the bag has to be the ordinary one -- an empty
    -- bag would hide the MEGA cell and the check below would say nothing.
    game = { save = { inventory = { [KeyItems.KEY_STONE] = 1 } } },
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

local function messages(battle)
  local n = 0
  for _, row in ipairs(battle.queue) do
    if row.text then n = n + 1 end
  end
  return n
end

Primal.bind({ forms = Forms, eligibility = E, primals = primals,
              announce = Announce, battlerof = Battlerof })
Conditional.bind({ forms = Forms, rows = rows, battlerof = Battlerof })

local registry = Transforms.new()
registry:register(Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                               keyitems = KeyItems, animId = "TESTANIM",
                               announce = Announce, battlerof = Battlerof }))
Overlay.bind({ registry = registry })
Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
               megas = megas, primals = primals, conditionalRows = rows,
               battlerof = Battlerof })

local function newAdopter()
  local state = Arm.new()
  Adopt.bind({ state = state, primal = Primal, conditional = Conditional })
  return state
end

-- ------- the arm state's own half ------------------------------------

do
  local state = Arm.new()
  local first, second = { id = 1 }, { id = 2 }
  T.eq(state:adopt(first), true, "a state holding no battle adopts one")
  T.eq(state:current(), first, "and caches it the way battle.started would")
  T.eq(state:adopt(first), false, "adopting the same battle again is refused")

  state:consume("mega")
  T.eq(state:used("mega"), true, "precondition: this battle's mega is spent")
  T.eq(state:adopt(first), false, "the refusal holds with history to lose")
  T.eq(state:used("mega"), true, "so the spent mega survives a second attempt")

  T.eq(state:adopt(second), true, "a genuinely different battle is adopted")
  T.eq(state:used("mega"), false,
    "and the stale battle's spent flags go with it")
  T.eq(state:adopt(nil), false, "there is no adopting nothing")
  T.eq(state:current(), second, "and the refusal left the cache alone")
end

-- ------- adopting a battle already under way -------------------------

do
  local groudon = newMon("GROUDON", "RED_ORB")
  local charizard = newMon("CHARIZARD", "CHARIZARDITE_X")
  local battle = makeBattle(charizard, groudon)
  local state = newAdopter()

  T.eq(state:current(), nil,
    "precondition: battle.started fired before the mod existed")
  T.eq(Overlay.shouldOffer(state), false,
    "precondition: with no battle cached the cell is never offered")

  T.eq(Adopt.consider(battle), true, "the battle in progress is adopted")
  T.eq(state:current(), battle, "and is what the arm state now answers with")
  T.eq(groudon.form, "PRIMAL",
    "the enemy's orb holder reverts, late but correctly: holding the orb is a "
      .. "state, so the answer is as true now as at the send-out")
  T.eq(messages(battle), 1, "and the reversion says so")

  -- The command menu the player next sees: phase back to menu with the
  -- reversion's own line read and the queue drained behind it.
  battle.phase = "menu"
  battle.queue = {}
  T.eq(Overlay.shouldOffer(state), true,
    "and the MEGA cell is available at the next command menu")
end

-- ------- adopting twice changes nothing ------------------------------

do
  local groudon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(newMon("CHARIZARD", "CHARIZARDITE_X"), groudon)
  local state = newAdopter()

  Adopt.consider(battle)
  local reverted = battle.enemy.curStats
  T.eq(messages(battle), 1, "precondition: adopted once, announced once")

  for _ = 1, 20 do
    T.eq(Adopt.consider(battle), false, "every later frame adopts nothing")
  end
  T.eq(messages(battle), 1, "no second line was printed")
  T.eq(groudon.form, "PRIMAL", "the form is exactly what it was")
  T.eq(battle.enemy.curStats, reverted, "and so is the override on the battler")
end

-- The once-per-battle mega is the thing a second adoption would refund, so it
-- is checked from both ends: unspent before, and still spent after.
do
  local charizard = newMon("CHARIZARD", "CHARIZARDITE_X")
  local battle = makeBattle(charizard, nil, "menu")
  local state = newAdopter()

  Adopt.consider(battle)
  T.eq(state:used("mega"), false,
    "adoption does not spend the battle's one mega -- the player never armed it")

  state:toggle("mega")
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(charizard.form, "MEGA_X", "precondition: the mega then happened normally")
  T.eq(state:used("mega"), true, "precondition: and was spent")

  for _ = 1, 20 do Adopt.consider(battle) end
  T.eq(state:used("mega"), true,
    "and no amount of adopting gives it back -- the state already holds this "
      .. "battle, which is the whole of the guarantee")
  T.eq(charizard.form, "MEGA_X", "the transformed mon is left transformed")
end

-- A mon that is already wearing its form when the mod arrives -- a reload
-- mid-battle, a second load -- must not be announced or re-derived into
-- something else.
do
  local groudon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(nil, groudon)
  Forms.becomeForm(DATA, battle.enemy, "GROUDON_PRIMAL")
  T.eq(groudon.form, "PRIMAL", "precondition: already reverted")
  local state = newAdopter()

  T.eq(Adopt.consider(battle), true, "the battle is still adopted")
  T.eq(groudon.form, "PRIMAL", "the mon keeps the form it already had")
  T.eq(messages(battle), 0,
    "and nothing is announced for a transformation that already happened")
end

-- ------- battle.started stays the primary path -----------------------

do
  local groudon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(nil, groudon)
  local state = newAdopter()

  state:onBattleStarted({ battle = battle })
  Primal.onBattleStarted({ battle = battle })
  T.eq(messages(battle), 1, "precondition: a normal boot announced once")

  for _ = 1, 20 do
    T.eq(Adopt.consider(battle), false,
      "a battle the event already delivered is never adopted")
  end
  T.eq(messages(battle), 1, "so a normal load can never double the message")
  T.eq(state:current(), battle, "and the cached battle is untouched")
end

-- ------- a finished battle is never picked up ------------------------

-- resolve.onBattleEnded sweeps both parties clear of any form, and those mons
-- go back to the save.  Re-adopting the battle after that would put a form
-- back on a party mon with nothing left to take it off again.
do
  local groudon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(nil, groudon)
  local state = newAdopter()

  battle.enemyParty = { groudon }
  Adopt.consider(battle)
  T.eq(groudon.form, "PRIMAL", "precondition: adopted and reverted")

  Resolve.onBattleEnded({ battle = battle })
  state:onBattleEnded()
  Adopt.onBattleEnded({ battle = battle })
  T.eq(groudon.form, nil, "precondition: the party sweep took the form off")

  for _ = 1, 20 do
    T.eq(Adopt.consider(battle), false, "a battle marked over is never adopted")
  end
  T.eq(groudon.form, nil, "so no form is written back onto a swept party mon")
  T.eq(state:current(), nil, "and the arm state stays empty between battles")
end

-- ------- what adoption recovers, and what it cannot ------------------

-- An HP row is a reading of the HP bar, so it is as answerable now as it was
-- at the send-out that happened without us.
do
  local darmanitan = newMon("DARMANITAN")
  darmanitan.hp = 10
  local battle = makeBattle(darmanitan)
  newAdopter()

  Adopt.consider(battle)
  T.eq(darmanitan.form, "ZEN",
    "a threshold already crossed is re-derived, because the threshold is a "
      .. "state and not an event")
  T.eq(messages(battle), 0, "silently, the way every conditional form is")
end

-- An event row is not.  The trigger already happened, the mod was not there to
-- see it, and inventing it after the fact would be fiction rather than
-- recovery -- so these resume from their next occurrence instead.
do
  local aegislash = newMon("AEGISLASH")
  local mimikyu = newMon("MIMIKYU")
  local battle = makeBattle(aegislash, mimikyu)
  newAdopter()

  Adopt.consider(battle)
  T.eq(aegislash.form, nil,
    "an Aegislash that attacked before the mod loaded arrives shielded")
  T.eq(mimikyu.form, nil,
    "and a Mimikyu whose disguise should already be broken arrives whole")

  Conditional.onMoveUsed({ battle = battle, user = battle.player,
                           move = { power = 80 } })
  T.eq(aegislash.form, "BLADE", "but the next move works normally")
end

-- ------- the guards --------------------------------------------------

do
  local state = newAdopter()
  T.eq(Adopt.consider(nil), false, "there is no battle to adopt")
  T.eq(Adopt.consider({}), false, "nor in a table that is not one")
  T.eq(Adopt.consider({ data = DATA }), false,
    "a battle with no sides yet is left to battle.started, which is about to "
      .. "fire for it anyway")
  T.eq(state:current(), nil, "and none of those cached anything")
  T.eq(Adopt.onBattleEnded(nil), nil, "an empty end payload is survivable")
end

-- ------- the seam it rides on ----------------------------------------

-- Adoption has no patch of its own: it is one question asked at the top of the
-- BattleState.update wrapper src/menu.lua already installs, which is the only
-- place the live battle reaches this mod without an event.
do
  local Menu = dofile(MOD .. "/src/menu.lua")
  local saved = {}
  for _, name in ipairs({ "src.battle.BattleState", "src.render.Font",
                          "src.core.Sound", "src.battle.WideBattle" }) do
    saved[name] = package.loaded[name]
  end

  local BattleState = { update = function() end,
                        drawTextArea = function() end,
                        tickFx = function() end }
  package.loaded["src.battle.BattleState"] = BattleState
  package.loaded["src.render.Font"] = { draw = function() end,
                                        drawCode = function() end }
  package.loaded["src.core.Sound"] = { play = function() end }
  package.loaded["src.battle.WideBattle"] = { draw = function() end }

  local groudon = newMon("GROUDON", "RED_ORB")
  local battle = makeBattle(newMon("CHARIZARD", "CHARIZARDITE_X"), groudon,
                            "menu")
  local state = newAdopter()
  Menu.bind({ overlay = Overlay, adopt = Adopt })
  T.eq(Menu.install({}, state), true, "precondition: the wrapper installed")

  T.eq(state:current(), nil, "precondition: nothing cached before a frame runs")
  BattleState.update(battle, 0)
  T.eq(state:current(), battle,
    "one frame of the patched update is all adoption needs")
  T.eq(groudon.form, "PRIMAL", "and the send-out handlers ran with it")

  for _ = 1, 50 do BattleState.update(battle, 0) end
  T.eq(messages(battle), 1, "fifty more frames add nothing")

  for name, value in pairs(saved) do package.loaded[name] = value end
  package.loaded["src.battle.WideBattle"] = saved["src.battle.WideBattle"]
end

T.finish("battle_forms_adopt")
