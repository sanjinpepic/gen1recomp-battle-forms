-- TERA BLAST: the one move whose type is the Tera type, built as a
-- move-substitution on top of src/tera.lua's existing curTypes override
-- rather than as a form or a second mechanism.
--
-- Three things this suite exists to prove.  The first is that a slot the
-- catalog does not name -- any move that is not TERABLAST -- is never
-- touched, which is what makes an un-terastallized Tera Blast (or a
-- terastallized Pokemon that never learned it) exactly the ordinary Normal
-- move National Dex registers, with no special case anywhere in this file.
-- The second is that the substitution goes on at ARM time, before the FIGHT
-- menu is ever drawn, and comes off on every path curTypes itself comes off
-- -- including switching back IN, which nothing else in this mod's
-- substitution-based mechanics needs, because nothing else survives a switch.
-- The third is that arming Terastallization never depends on knowing Tera
-- Blast at all: a mon with no such slot arms cleanly with nothing to convert.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Tera = dofile(MOD .. "/src/tera.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local TYPES = dofile(MOD .. "/data/terablast.lua")

local Damage = require("src.battle.Damage")
local TypeChart = require("src.battle.TypeChart")
local Ruleset = require("src.battle.rulesets.gen1_faithful")

-- ---------------------------------------------------------------------
-- A small world: enough of the type chart to prove the substituted record's
-- type is what damage math actually reads, plus TERABLAST itself, the way
-- National Dex would register it.
-- ---------------------------------------------------------------------
local CHART = {
  matchups = {
    { attacker = "NORMAL", defender = "GHOST", multiplier = 0 },
    { attacker = "FIRE", defender = "WATER", multiplier = 5 },
    { attacker = "FIRE", defender = "GRASS", multiplier = 20 },
  },
  types = {
    NORMAL = { name = "NORMAL", category = "physical" },
    GHOST = { name = "GHOST", category = "physical" },
    FIRE = { name = "FIRE", category = "special" },
    WATER = { name = "WATER", category = "special" },
    GRASS = { name = "GRASS", category = "special" },
    FLYING = { name = "FLYING", category = "physical" },
  },
}

local DATA = {
  type_chart = CHART,
  pokemon = {
    EEVEE = { baseStats = { hp = 55, attack = 55, defense = 50,
                            speed = 55, special = 50 },
              types = { "NORMAL" }, name = "EEVEE" },
  },
  moves = {
    TERABLAST = { id = "TERABLAST", type = "NORMAL", power = 80,
                  category = "special", accuracy = 100, pp = 10 },
    SCRATCH = { id = "SCRATCH", type = "NORMAL", power = 40,
                category = "physical", accuracy = 100, pp = 35 },
  },
}
TypeChart.load(DATA)

local function hit(attacker, defender, move)
  local _, info = Damage.compute(Ruleset, attacker, defender, move,
    { rng = function(_, hi) return hi end, forceCrit = false })
  return info.typeMult
end

local function damage(attacker, defender, move)
  return Damage.compute(Ruleset, attacker, defender, move,
    { rng = function(_, hi) return hi end, forceCrit = false })
end

local function makeMon(moves)
  local mon = { species = "EEVEE", level = 50, hp = 100,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15,
                        special = 15 }, statExp = {},
                moves = moves }
  mon.stats = { hp = 55, attack = 55, defense = 50, speed = 55, special = 50 }
  return mon
end

local function makeBattler(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, name = "EEVEE", stages = {},
           curStats = mon.stats, curTypes = DATA.pokemon.EEVEE.types,
           curMoves = mon.moves }
end

local function makeBattle(bag, playerMoves)
  local mon = makeMon(playerMoves or {
    { id = "TERABLAST", pp = 10 }, { id = "SCRATCH", pp = 35 },
  })
  local enemy = makeMon({ { id = "SCRATCH", pp = 35 } })
  local battle = { phase = "menu", data = DATA,
                   player = makeBattler(mon, true), enemy = makeBattler(enemy, false),
                   game = { save = { party = { mon }, inventory = bag or {} } } }
  battle.sayNext = function(self, line)
    self.nextInsert = (self.nextInsert or 0) + 1
  end
  return battle
end

local function bindTera(chosen, log)
  Tera.bind({ keyitems = KeyItems, announce = Announce, log = log,
              substitute = Substitute, anim = Anim, battlerof = Battlerof,
              chosen = function() return chosen end })
end

-- ---------------------------------------------------------------------
-- data/terablast.lua itself.
-- ---------------------------------------------------------------------
do
  T.eq(#TYPES, 18, "one row per type, the same eighteen TERA TYPE offers")
  local seen = {}
  for _, typeId in ipairs(TYPES) do
    T.check(not seen[typeId], typeId .. " appears once")
    seen[typeId] = true
  end
  T.check(seen.PSYCHIC_TYPE, "the engine's own Psychic id is used, not PSYCHIC")
end

-- ---------------------------------------------------------------------
-- Registration.
-- ---------------------------------------------------------------------
local function stubMod(chart)
  local warned = {}
  local buckets = { moves = {}, battle_anims = {} }
  local content = {}
  for name, bucket in pairs(buckets) do
    content[name] = {
      register = function(_, id, record)
        T.check(bucket[id] == nil, name .. " id registered once: " .. tostring(id))
        bucket[id] = record
      end,
    }
  end
  content.type_chart = { get = function(_, id) return chart[id] end }
  return { content = content,
           log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
           registered = buckets, warned = warned }
end

local function chartOf(list)
  local chart = {}
  for _, id in ipairs(list) do chart[id] = { name = id } end
  return chart
end

local CATALOG
do
  local mod = stubMod(chartOf({ "NORMAL", "FIRE", "GHOST" }))
  bindTera("NORMAL", mod.log)
  CATALOG = Tera.install(mod, { "NORMAL", "FIRE", "GHOST", "WATER" })

  T.eq(CATALOG.byType.NORMAL, Tera.idFor("NORMAL"), "a resolvable type is catalogued")
  T.eq(CATALOG.byType.WATER, nil,
    "a type the chart cannot resolve is left out of the catalog")
  T.eq(#mod.warned, 1, "and the omission is logged exactly once")
  T.check(mod.warned[1]:find("WATER", 1, true) ~= nil, "naming the type left out")

  local record = mod.registered.moves[Tera.idFor("FIRE")]
  T.eq(record.name, "TERA BLAST", "every variant keeps the one real name")
  T.eq(record.type, "FIRE", "and carries the type that variant is for")
  T.eq(record.power, 80, "at the fixed 80 power the task describes")
  T.eq(record.category, "special", "kept Special explicitly, whatever the type")
  T.eq(record.accuracy, 100, "never misses under this mod's ruling")
  T.eq(record.pp, Tera.RECORD_PP, "registered at the record PP the menu math wants")
  T.eq(record.effect, "NO_ADDITIONAL_EFFECT", "and no effect of its own")
  T.check(mod.registered.battle_anims[Tera.idFor("FIRE")] ~= nil,
    "and an animation, so it is not silent")
end

-- ---------------------------------------------------------------------
-- The substitution: what it does, and what it leaves alone.
-- ---------------------------------------------------------------------
do
  bindTera("FIRE")
  local state = Tera.new()
  local entry = Tera.entry(state, CATALOG)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })

  T.eq(hit(battle.player, battle.enemy, DATA.moves.TERABLAST), 10,
    "precondition: TERABLAST is Normal, and Normal is neutral against Grass")

  entry.arm(battle)
  local slot = battle.player.curMoves[1]
  T.eq(slot.id, Tera.idFor("FIRE"), "the TERA BLAST slot becomes the Fire variant")
  T.eq(battle.player.curMoves[2].id, "SCRATCH",
    "and the other slot is left exactly as it was")

  local fireRecord = DATA.moves[slot.id]
  T.eq(fireRecord, nil,
    "precondition: the mock DATA table carries no such record, so the check "
      .. "below is reading the SLOT the substitution built, not a coincidence")

  entry.activate(battle)
  T.eq(battle.player.curTypes[1], "FIRE", "and Terastallizing still changes the type")

  entry.disarm()
  T.eq(battle.player.curMoves[1].id, "TERABLAST",
    "disarming puts the original move back")
end

-- Damage math itself, through the substituted record -- the same proof
-- src/tera.lua's own suite holds curTypes to.
do
  bindTera("FIRE")
  local mod = stubMod(chartOf({ "NORMAL", "FIRE", "GHOST" }))
  local liveCatalog = Tera.install(mod, TYPES)
  local data = { type_chart = CHART, moves = {} }
  for id, record in pairs(mod.registered.moves) do data.moves[id] = record end
  data.moves.TERABLAST = DATA.moves.TERABLAST
  data.moves.SCRATCH = DATA.moves.SCRATCH

  local state = Tera.new()
  local entry = Tera.entry(state, liveCatalog)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  battle.data = data
  -- A Grass-typed target, so Normal (neutral) and Fire (super effective) read
  -- differently -- proving the substituted record's type, not merely its id.
  battle.enemy.curTypes = { "GRASS" }

  entry.arm(battle)
  local fireSlot = battle.player.curMoves[1]
  local fireDef = data.moves[fireSlot.id]
  T.eq(fireDef.type, "FIRE", "the substituted slot resolves to a Fire record")
  T.eq(hit(battle.player, battle.enemy, DATA.moves.TERABLAST), 10,
    "precondition: the un-terastallized Normal move is neutral against Grass")
  T.eq(hit(battle.player, battle.enemy, fireDef), 20,
    "and Damage.compute reads the substituted record's type: super effective "
      .. "against Grass, where the Normal move it replaced was neutral")
end

-- ---------------------------------------------------------------------
-- Not terastallized: TERA BLAST is the ordinary Normal move.
-- ---------------------------------------------------------------------
do
  bindTera("FIRE")
  local state = Tera.new()
  Tera.entry(state, CATALOG)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  local before = battle.player.curMoves[1]

  T.eq(before.id, "TERABLAST", "with the cell never armed, the slot is untouched")
  T.eq(hit(battle.player, battle.enemy, DATA.moves.TERABLAST), 10,
    "and it hits as the plain Normal-type 80-power attack it is registered as")
end

-- ---------------------------------------------------------------------
-- Arming never depends on carrying TERA BLAST.
-- ---------------------------------------------------------------------
do
  bindTera("FIRE")
  local state = Tera.new()
  local entry = Tera.entry(state, CATALOG)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 },
    { { id = "SCRATCH", pp = 35 } })

  T.eq(entry.arm(battle), true, "arming succeeds with no TERA BLAST in the moveset")
  T.eq(battle.player.curMoves[1].id, "SCRATCH", "and nothing was substituted")
  T.eq(entry.activate(battle), true, "and the Pokemon still terastallizes")
  T.eq(battle.player.curTypes[1], "FIRE", "changing its type as normal")
end

-- ---------------------------------------------------------------------
-- Disarming is safe blind, and cycling away undoes exactly what arming did.
-- ---------------------------------------------------------------------
do
  bindTera("FIRE")
  local state = Tera.new()
  local entry = Tera.entry(state, CATALOG)

  entry.disarm() -- never armed at all
  T.check(true, "disarming a Terastallization that was never armed does not error")

  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  entry.arm(battle)
  T.eq(battle.player.curMoves[1].id, Tera.idFor("FIRE"), "precondition: armed")
  entry.disarm()
  T.eq(battle.player.curMoves[1].id, "TERABLAST", "and disarming restores it")
  entry.disarm()
  T.check(true, "disarming a second time, already clean, does not error either")
end

-- ---------------------------------------------------------------------
-- Switching out and back in: curTypes and the TERA BLAST substitution move
-- together, because both are rebuilt from scratch on every send-out.
-- ---------------------------------------------------------------------
do
  bindTera("FIRE")
  local state = Tera.new()
  local entry = Tera.entry(state, CATALOG)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  entry.arm(battle)
  entry.activate(battle)
  T.eq(battle.player.curTypes[1], "FIRE", "precondition: terastallized")
  T.eq(battle.player.curMoves[1].id, Tera.idFor("FIRE"), "precondition: substituted")

  -- The mon switches out: a brand-new battler arrives, seeded from the base
  -- species and the party move list the way makeBattler always does, knowing
  -- nothing about either override.
  local arriving = makeBattler(battle.player.mon, true)
  T.eq(arriving.curTypes[1], "NORMAL", "precondition: freshly rebuilt as base")
  T.eq(arriving.curMoves[1].id, "TERABLAST", "precondition: freshly rebuilt too")

  Tera.onBattlerSwitched(state, { battle = battle, battler = arriving })
  T.eq(arriving.curTypes[1], "FIRE", "switching back in reapplies the type")
  T.eq(arriving.curMoves[1].id, Tera.idFor("FIRE"),
    "and reapplies the TERA BLAST substitution on the NEW battler")
  T.eq(arriving.curMoves[2].id, "SCRATCH", "leaving the other slot alone")
end

-- ---------------------------------------------------------------------
-- Fainting and the battle ending unwind both halves together.
-- ---------------------------------------------------------------------
do
  bindTera("FIRE")
  local state = Tera.new()
  local entry = Tera.entry(state, CATALOG)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  entry.arm(battle)
  entry.activate(battle)

  Tera.onFainted(state, { battle = battle, battler = battle.player })
  T.eq(battle.player.curTypes[1], "NORMAL", "fainting restores the base type")
  T.eq(battle.player.curMoves[1].id, "TERABLAST",
    "and restores the TERA BLAST slot in the same stroke")
end

do
  bindTera("FIRE")
  local state = Tera.new()
  local entry = Tera.entry(state, CATALOG)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  entry.arm(battle)
  entry.activate(battle)

  Tera.onBattleEnded(state, { battle = battle })
  T.eq(battle.player.curTypes[1], "NORMAL", "the battle ending restores the type")
  T.eq(battle.player.curMoves[1].id, "TERABLAST", "and the move together with it")
end

-- ---------------------------------------------------------------------
-- Never a persistent write.  The party mon's own field set, and the move
-- record table identity inside it, are the same before and after every path.
-- ---------------------------------------------------------------------
local function keysOf(mon)
  local out = {}
  for key in pairs(mon) do out[#out + 1] = tostring(key) end
  table.sort(out)
  return table.concat(out, ",")
end

do
  bindTera("FIRE")
  local state = Tera.new()
  local entry = Tera.entry(state, CATALOG)
  local battle = makeBattle({ [KeyItems.TERA_ORB] = 1 })
  local mon = battle.player.mon
  local slotTable = mon.moves[1]
  local before = keysOf(mon)

  entry.arm(battle)
  entry.activate(battle)
  T.eq(keysOf(mon), before, "arming and activating write no new field onto the mon")
  T.eq(mon.moves[1], slotTable,
    "and the party's own move-slot table is untouched by identity -- the "
      .. "substitution replaced the ARRAY on the battler, never the slot "
      .. "inside the mon's own list")
  T.eq(mon.moves[1].id, "TERABLAST", "which still reads its real, saved id")

  Tera.onBattleEnded(state, { battle = battle })
  T.eq(keysOf(mon), before, "and the battle ending leaves the same fields")
end

T.finish("battle_forms_terablast")
