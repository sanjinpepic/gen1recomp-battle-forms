-- Z-status effects on Gold: the bonus a status move keeps ON TOP OF its own
-- effect under a matching Z-Crystal, the identical shape
-- tests/battle_forms_zstatus_test.lua proves for Gen 1 -- built for the one
-- shape src/zmoves.lua's own header explains is unambiguous, a move that
-- already raises one of the user's own stats gets every OTHER stat raised
-- by one stage as well.
--
-- GOLD'S OWN MECHANISM, which is the reason this is a separate suite rather
-- than a Gen 2 section bolted onto the Gen 1 one. Gen 1's own bonus runs
-- through `src.battle.MoveEffects.changeStage(battle, battler, stat, ...)`,
-- a free function taking a battler wrapper. Gold has no such module and no
-- wrapper: the identical arithmetic lives as an instance METHOD on the
-- engine's own Battle object, `battle:changeStage(mon, stat, stages)`
-- (game/src/battle/gen2/Battle.lua:1299), which applies the change,
-- clamps it at the cart's own +-6 ceiling and emits the cart's own
-- "X's STAT rose!" message itself -- so this file's own applyStatusBonus
-- calls it directly rather than reimplementing any of that.
--
-- THE SELF-RAISE TABLE IS READ LIVE, not hand-duplicated. Gen 1's own
-- SELF_RAISE_STAT is a hand-built map because Gen 1 has no existing table to
-- read it from; Gold's engine already carries the identical classification
-- as `src.battle.gen2.Effects.STAT_CHANGES`, keyed by the move's own effect
-- string and carrying `{ stat, stages, target }` where target is "self" or
-- "foe" -- exactly the shape this needs, so a Gen 2 self-raise move is
-- whichever row in that live table says target == "self", never a second
-- table this file would have to keep in step with the engine's own.
--
-- SEVEN STATS, NOT SIX. Gen 1's own ALL_STATS covers attack, defense,
-- speed, special (one field), accuracy and evasion. Gold splits Special
-- into specialAttack/specialDefense, so the raised set here is those seven
-- minus HP, matching the real games' own Z-Power-Up rule of "every other
-- stat" regardless of which generation is running.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local ZMoves = dofile(MOD .. "/src/zmoves.lua")
local Gen2Substitute = dofile(MOD .. "/src/gen2substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local ROWS = dofile(MOD .. "/data/zmoves.lua")

local ELECTRIUM, NORMALIUM
for _, row in ipairs(ROWS.types) do
  if row.type == "ELECTRIC" then ELECTRIUM = row.crystal end
  if row.type == "NORMAL" then NORMALIUM = row.crystal end
end

ZMoves.bind({ substitute = nil, keyitems = KeyItems, eligibility = E,
              announce = Announce, anim = Anim, battlerof = Battlerof,
              gen2 = true, gen2substitute = Gen2Substitute })

local DATA = { moves = {
  -- Gold's own effect id for Agility -- EFFECT_SPEED_UP_2, a self stat-raise
  -- (src.battle.gen2.Effects.STAT_CHANGES).
  AGILITY = { id = "AGILITY", type = "ELECTRIC", power = 0,
              effect = "EFFECT_SPEED_UP_2", accuracy = 100 },
  -- A target-directed stat-lowering status move of the SAME type -- no bonus.
  THUNDERWAVE_GLARE = { id = "THUNDERWAVE_GLARE", type = "ELECTRIC", power = 0,
                        effect = "EFFECT_SPEED_DOWN", accuracy = 100 },
  -- A status-inducing move of the same type (no entry in STAT_CHANGES at
  -- all) -- also no bonus.
  STUN_SHOCK = { id = "STUN_SHOCK", type = "ELECTRIC", power = 0,
                effect = "EFFECT_PARALYZE", accuracy = 100 },
  -- A self stat-raise of a DIFFERENT type -- no bonus under this crystal.
  HARDEN = { id = "HARDEN", type = "NORMAL", power = 0,
            effect = "EFFECT_DEFENSE_UP", accuracy = 100 },
  THUNDERBOLT = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90, pp = 15,
                  accuracy = 100 },
} }

-- ---------------------------------------------------------------------
-- M.statusBonusStat, read live off src.battle.gen2.Effects.
-- ---------------------------------------------------------------------
do
  T.eq(ZMoves.statusBonusStat(DATA, "AGILITY", "ELECTRIC"), "speed",
    "a self stat-raise of the crystal's type answers with the stat it raises")
  T.eq(ZMoves.statusBonusStat(DATA, "AGILITY", "NORMAL"), nil,
    "the same move under the wrong crystal answers nothing")
  T.eq(ZMoves.statusBonusStat(DATA, "THUNDERWAVE_GLARE", "ELECTRIC"), nil,
    "a target-directed stat-lowering move is not this shape")
  T.eq(ZMoves.statusBonusStat(DATA, "STUN_SHOCK", "ELECTRIC"), nil,
    "neither is a status-inducing move with no row in Effects.STAT_CHANGES at all")
  T.eq(ZMoves.statusBonusStat(DATA, "THUNDERBOLT", "ELECTRIC"), nil,
    "and neither is a damaging move -- that is M.fieldsFor's business")
  T.eq(ZMoves.statusBonusStat(DATA, "NOSUCHMOVE", "ELECTRIC"), nil,
    "a move the registry cannot resolve answers nothing")
end

-- ---------------------------------------------------------------------
-- The full activation, Gen 2-shaped: a Pokemon with ONLY a self-raise status
-- move of the crystal's type -- nothing to substitute -- still arms and
-- still bonuses, through the real battle:changeStage.
-- ---------------------------------------------------------------------
local function makeMon()
  local moves = { { id = "AGILITY", pp = 30, maxPp = 30 },
                  { id = "THUNDERBOLT", pp = 15, maxPp = 15 } }
  return { species = "PIKACHU", level = 50, nickname = "SPARKY", hp = 100,
           moves = moves, item = ELECTRIUM }
end

-- A minimal, faithful stand-in for game/src/battle/gen2/Battle.lua:1299 --
-- the real signature (mon, stat, stages), the real clamp-and-message
-- contract reduced to what this suite needs to observe: which stats were
-- raised and by how much.
local function makeBattle(mon)
  local events, stages = {}, {}
  return {
    data = DATA, player = mon, party = { mon }, enemyParty = {},
    events = events, stages = stages,
    save = { inventory = { [KeyItems.Z_RING] = 1 } },
    emit = function(_, ev) events[#events + 1] = ev end,
    monName = function(_, m) return m and m.nickname end,
    changeStage = function(self, target, stat, delta)
      T.eq(target, mon, "changeStage is called with the real mon, never a wrapper")
      stages[stat] = (stages[stat] or 0) + delta
      self.events[#self.events + 1] =
        { kind = "message", text = mon.nickname .. "'s " .. stat .. " rose!" }
    end,
  }
end

do
  local mon = makeMon()
  local CATALOG
  do
    local mod = { content = {
      moves = { register = function() end },
      battle_anims = { register = function() end },
      type_chart = { get = function(_, id) return { name = id } end },
    } }
    CATALOG = ZMoves.install(mod, ROWS)
  end

  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local battle = makeBattle(mon)

  T.eq(entry.available(battle), true,
    "the cell is offered even though nothing in the moveset can substitute")
  T.eq(entry.arm(battle), true, "arming succeeds with nothing to substitute")
  T.eq(mon.moves[1].id, "AGILITY",
    "and Agility is left exactly as it is -- no substitution, on purpose")
  T.eq(state.statusType, "ELECTRIC", "the crystal's type is remembered for later")
  T.eq(entry.activate(battle), true, "and the Pokemon still surrounds itself")

  ZMoves.onMoveUsed(state, { user = mon, move = DATA.moves.AGILITY, battle = battle })
  T.eq(state.spent, true, "using the unconverted status move spends the Z-Power")
  T.check(state.statusBonus ~= nil, "and records the bonus to apply")
  T.eq(state.statusBonus.stat, "speed", "the stat Agility itself already raised")
  T.eq(state.statusBonus.battler, mon,
    "the bare mon is stored directly -- Gold's own event payload never wraps it")

  ZMoves.onTurnEnded(state)
  T.eq(battle.stages.speed, nil,
    "SPEED is not bonused again -- Agility's own effect already raised it "
      .. "(which this suite never ran through the real pipeline, so it is "
      .. "absent here too)")
  T.eq(battle.stages.attack, 1, "ATTACK is raised by the bonus")
  T.eq(battle.stages.defense, 1, "DEFENSE is raised by the bonus")
  T.eq(battle.stages.specialAttack, 1, "SPCL.ATK is raised -- Gold's own split stat")
  T.eq(battle.stages.specialDefense, 1, "SPCL.DEF is raised too")
  T.eq(battle.stages.accuracy, 1, "ACCURACY is raised by the bonus")
  T.eq(battle.stages.evasion, 1, "EVASION is raised by the bonus")
  T.check(#battle.events > 0,
    "and the bonus prints through the real battle:changeStage, the engine's own text")

  T.eq(state.mon, nil, "the turn ending also unwinds the whole activation")
  T.eq(state.statusBonus, nil, "leaving nothing pending for a later battle")
end

-- A damaging move used instead spends the ordinary way and gets no bonus
-- stacked onto it.
do
  local mon = makeMon()
  local CATALOG
  do
    local mod = { content = {
      moves = { register = function() end },
      battle_anims = { register = function() end },
      type_chart = { get = function(_, id) return { name = id } end },
    } }
    CATALOG = ZMoves.install(mod, ROWS)
  end
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local battle = makeBattle(mon)

  entry.arm(battle)
  local boltId = mon.moves[2].id
  T.check(boltId ~= "THUNDERBOLT", "Thunderbolt substitutes as usual")

  ZMoves.onMoveUsed(state, { user = mon, move = { id = boltId }, battle = battle })
  T.eq(state.spent, true, "using the substituted move spends it the usual way")
  T.eq(state.statusBonus, nil, "and no status bonus was ever recorded")

  ZMoves.onTurnEnded(state)
  T.eq(next(battle.stages), nil,
    "so no stage changed at all -- a damage Z-Move stacks no bonus onto itself")
end

ZMoves.bind({ substitute = nil, keyitems = KeyItems, eligibility = E,
              announce = Announce, anim = Anim, battlerof = Battlerof })

T.finish("battle_forms_gen2zstatus")
