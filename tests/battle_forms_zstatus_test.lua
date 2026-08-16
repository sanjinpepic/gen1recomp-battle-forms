-- Z-status effects: the bonus a status move keeps ON TOP OF its own effect
-- under a matching Z-Crystal, built only for the one shape src/zmoves.lua's
-- own header explains is unambiguous -- a move that already raises one of
-- the user's own stats gets every OTHER stat raised by one stage as well.
--
-- Three things this suite exists to prove.  The first is that the move's
-- OWN effect is never touched or duplicated -- this mechanism never
-- substitutes the slot, so a Swords Dance under a crystal is still exactly
-- the ATTACK_UP2_EFFECT record it always was, running through the engine's
-- ordinary status pipeline untouched.  The second is that the bonus is
-- additive and excludes the stat the move itself already raised, so a
-- Pokemon never gets one stat pushed twice in the same turn.  The third is
-- that everything else -- a target-directed stat-lowering move, a
-- status-inducing move, a damage move -- gets no bonus at all, which is the
-- deliberate boundary this build drew and not an oversight.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local ZMoves = dofile(MOD .. "/src/zmoves.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local ROWS = dofile(MOD .. "/data/zmoves.lua")

ZMoves.bind({ substitute = Substitute, keyitems = KeyItems, eligibility = E,
              announce = Announce, anim = Anim, log = nil,
              battlerof = Battlerof })

local ELECTRIUM, NORMALIUM
for _, row in ipairs(ROWS.types) do
  if row.type == "ELECTRIC" then ELECTRIUM = row.crystal end
  if row.type == "NORMAL" then NORMALIUM = row.crystal end
end

local DATA = { moves = {
  -- A self stat-raise, the shape this file builds a bonus for.
  AGILITY = { id = "AGILITY", type = "ELECTRIC", power = 0,
              effect = "SPEED_UP2_EFFECT", accuracy = 100 },
  -- A target-directed stat-lowering status move of the SAME type -- gets no
  -- bonus, on purpose: it is not the one shape this file covers.
  THUNDERWAVE_GLARE = { id = "THUNDERWAVE_GLARE", type = "ELECTRIC", power = 0,
                        effect = "SPEED_DOWN1_EFFECT", accuracy = 100 },
  -- A status-inducing move of the same type -- also no bonus, same reason.
  STUN_SHOCK = { id = "STUN_SHOCK", type = "ELECTRIC", power = 0,
                effect = "PARALYZE_EFFECT", accuracy = 100 },
  -- A self stat-raise of a DIFFERENT type -- gets no bonus under this crystal.
  HARDEN = { id = "HARDEN", type = "NORMAL", power = 0,
            effect = "DEFENSE_UP1_EFFECT", accuracy = 100 },
  -- A damaging move of the crystal's type, so the roster's own substitution
  -- still fires for it exactly as it always has.
  THUNDERBOLT = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90, pp = 15 },
} }

-- ---------------------------------------------------------------------
-- M.statusBonusStat and M.wouldStatusBonus in isolation.
-- ---------------------------------------------------------------------
do
  T.eq(ZMoves.statusBonusStat(DATA, "AGILITY", "ELECTRIC"), "speed",
    "a self stat-raise of the crystal's type answers with the stat it raises")
  T.eq(ZMoves.statusBonusStat(DATA, "AGILITY", "NORMAL"), nil,
    "the same move under the wrong crystal answers nothing")
  T.eq(ZMoves.statusBonusStat(DATA, "THUNDERWAVE_GLARE", "ELECTRIC"), nil,
    "a target-directed stat-lowering move is not this shape")
  T.eq(ZMoves.statusBonusStat(DATA, "STUN_SHOCK", "ELECTRIC"), nil,
    "neither is a status-inducing move")
  T.eq(ZMoves.statusBonusStat(DATA, "THUNDERBOLT", "ELECTRIC"), nil,
    "and neither is a damaging move -- that is M.fieldsFor's business")
  T.eq(ZMoves.statusBonusStat(DATA, "NOSUCHMOVE", "ELECTRIC"), nil,
    "a move the registry cannot resolve answers nothing")
  T.eq(ZMoves.statusBonusStat(DATA, "AGILITY", nil), nil,
    "and so does no type at all")

  local battler = { curMoves = {
    { id = "THUNDERWAVE_GLARE" }, { id = "AGILITY" }, { id = "TACKLE" },
  } }
  local CATALOG = ZMoves.install({
    content = {
      moves = { register = function() end },
      battle_anims = { register = function() end },
      type_chart = { get = function(_, id) return { name = id } end },
    },
  }, ROWS)
  T.check(ZMoves.wouldStatusBonus(CATALOG, DATA, battler, ELECTRIUM), true,
    "a battler carrying Agility among its moves has a status bonus on offer")
  T.check(not ZMoves.wouldStatusBonus(CATALOG, DATA, battler, NORMALIUM),
    "but not under a crystal of a type nothing in the moveset matches")
  T.check(not ZMoves.wouldStatusBonus(CATALOG, DATA,
    { curMoves = { { id = "THUNDERWAVE_GLARE" } } }, ELECTRIUM),
    "and not for a moveset with no self-raise move at all")
end

-- ---------------------------------------------------------------------
-- The full activation: a Pokemon with ONLY a self-raise status move of the
-- crystal's type -- nothing to substitute -- still arms and still bonuses.
-- ---------------------------------------------------------------------
local function makeMon()
  local moves = { { id = "AGILITY", pp = 30 }, { id = "TACKLE", pp = 35 } }
  local mon = { species = "PIKACHU", hp = 100, moves = moves,
                [E.STAMP] = ELECTRIUM }
  return mon
end

local function makeBattle(mon)
  local said = {}
  local battler = { isPlayer = true, name = "PIKACHU", mon = mon,
                    curMoves = mon.moves, stages = {} }
  return {
    phase = "menu", data = DATA, player = battler,
    game = { save = { inventory = { [KeyItems.Z_RING] = 1 }, party = { mon } } },
    said = said,
    sayNext = function(self, line) said[#said + 1] = line end,
  }
end

local CATALOG
do
  local mod = {
    content = {
      moves = { register = function() end },
      battle_anims = { register = function() end },
      type_chart = { get = function(_, id) return { name = id } end },
    },
  }
  CATALOG = ZMoves.install(mod, ROWS)
end

do
  local mon = makeMon()
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local battle = makeBattle(mon)

  T.eq(entry.available(battle), true,
    "the cell is offered even though nothing in the moveset can substitute")

  T.eq(entry.arm(battle), true, "arming succeeds with nothing to substitute")
  T.eq(battle.player.curMoves[1].id, "AGILITY",
    "and Agility is left exactly as it is -- no substitution, on purpose")
  T.eq(state.statusType, "ELECTRIC", "the crystal's type is remembered for later")

  T.eq(entry.activate(battle), true, "and the Pokemon still terastallizes -- "
    .. "Z-Power still went up even though nothing converted")

  -- Using Agility: the effect itself would run through the engine's own
  -- pipeline (untested here, since that pipeline is not this file's), and
  -- this event only marks that the bonus is owed.
  ZMoves.onMoveUsed(state, { user = battle.player,
    move = DATA.moves.AGILITY, battle = battle })
  T.eq(state.spent, true, "using the unconverted status move spends the Z-Power")
  T.check(state.statusBonus ~= nil, "and records the bonus to apply")
  T.eq(state.statusBonus.stat, "speed", "the stat Agility itself already raised")

  ZMoves.onTurnEnded(state)
  local raised = {}
  for stat, stage in pairs(battle.player.stages) do raised[stat] = stage end
  T.eq(raised.speed, nil,
    "SPEED is not bonused again -- Agility's own effect already raised it "
      .. "(which this suite never ran, so it is absent here too)")
  T.eq(raised.attack, 1, "ATTACK is raised by the bonus")
  T.eq(raised.defense, 1, "DEFENSE is raised by the bonus")
  T.eq(raised.special, 1, "SPECIAL is raised by the bonus")
  T.eq(raised.accuracy, 1, "ACCURACY is raised by the bonus")
  T.eq(raised.evasion, 1, "EVASION is raised by the bonus")
  T.check(#battle.said > 0, "and the bonus prints the engine's own stat-rose text")

  T.eq(state.mon, nil, "the turn ending also unwinds the whole activation")
  T.eq(state.statusBonus, nil, "leaving nothing pending for a later battle")
end

-- ---------------------------------------------------------------------
-- A damaging move used instead spends the ordinary way and gets no bonus
-- stacked onto it -- the two paths in M.onMoveUsed are mutually exclusive.
-- ---------------------------------------------------------------------
do
  local mon = makeMon()
  mon.moves[2] = { id = "THUNDERBOLT", pp = 15 }
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local battle = makeBattle(mon)

  entry.arm(battle)
  local boltId = battle.player.curMoves[2].id
  T.check(boltId ~= "THUNDERBOLT", "Thunderbolt substitutes as usual")

  ZMoves.onMoveUsed(state, { user = battle.player,
    move = { id = boltId }, battle = battle })
  T.eq(state.spent, true, "using the substituted move spends it the usual way")
  T.eq(state.statusBonus, nil, "and no status bonus was ever recorded")

  ZMoves.onTurnEnded(state)
  T.eq(next(battle.player.stages), nil,
    "so no stage changed at all -- a damage Z-Move stacks no bonus onto itself")
end

-- ---------------------------------------------------------------------
-- A status move of the WRONG type, or one that is not a self-raise, is
-- simply not offered and not bonused -- verified through the same cell
-- rather than through the isolated function above.
-- ---------------------------------------------------------------------
do
  local mon = { species = "PIKACHU", hp = 100,
                moves = { { id = "THUNDERWAVE_GLARE", pp = 20 } },
                [E.STAMP] = ELECTRIUM }
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local battle = makeBattle(mon)

  T.eq(entry.available(battle), false,
    "a target-directed status move of the crystal's own type offers nothing")
end

T.finish("battle_forms_zstatus")
