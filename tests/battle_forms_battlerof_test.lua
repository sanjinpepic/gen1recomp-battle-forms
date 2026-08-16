-- Gen 1 and Gen 2 fire the same Runtime event names with different payload
-- shapes: Gen 1 hands a battler WRAPPER (BattleState.lua's makeBattler,
-- :482-524); Gen 2 has none at all -- `battler` (or `user`/`target`/
-- `previous`, or the live `battle.player`/`battle.enemy` fields) IS the mon
-- (game/src/battle/gen2/Battle.lua:3004, its own comment on the shape). This
-- pins src/battlerof.lua against both shapes, built from the real engine
-- fields rather than invented ones -- see the fixtures below for exactly
-- which lines they come from.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")

-- The Gen 1 wrapper, trimmed to the fields the header comment on
-- game/src/battle/gen2/Battle.lua:3004 singles out plus the two this mod's
-- own event handlers read (BattleState.lua:494-523, makeBattler's return).
local function gen1Battler(mon, isPlayer)
  return {
    mon = mon,
    def = { name = mon.species },
    name = mon.species,
    isPlayer = isPlayer,
    curStats = mon.stats,
    curTypes = { "NORMAL" },
    curMoves = mon.moves,
    sprite = "STUB_SPRITE",
  }
end

-- The Gen 2 mon: a plain Pokemon.new()-shaped record (game/src/pokemon/
-- Pokemon.lua:70-84). No `mon` field exists anywhere on it -- that absence is
-- exactly what game/src/battle/gen2/Battle.lua:3004 means by "no battler
-- wrapper".
local function gen2Mon(species)
  return {
    species = species, level = 50, exp = 125000,
    dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
    statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    stats = { hp = 100, attack = 80, defense = 70, speed = 90, special = 85 },
    hp = 100, catchRate = 45, status = nil,
    moves = { { id = "TACKLE", pp = 35 } },
  }
end

-- Side records: Gen 1's carry no `key` (BattleState.lua:598-601), Gen 2's do
-- (game/src/battle/gen2/Battle.lua's Battle.newSides, :357-364). `index` is
-- the one field both shapes carry, and 1 is the player's side on either
-- engine.
local GEN1_PLAYER_SIDE = { index = 1, battlers = {}, screens = {}, hazards = {}, tokens = {} }
local GEN1_ENEMY_SIDE = { index = 2, battlers = {}, screens = {}, hazards = {}, tokens = {} }
local GEN2_PLAYER_SIDE = { index = 1, key = "player", battlers = {}, screens = {}, hazards = {}, tokens = {} }
local GEN2_ENEMY_SIDE = { index = 2, key = "enemy", battlers = {}, screens = {}, hazards = {}, tokens = {} }

-- --- M.mon: Gen 1 wrapper shape -------------------------------------------

local charizard = gen2Mon("CHARIZARD")
local wrapper = gen1Battler(charizard, true)
T.eq(Battlerof.mon(wrapper), charizard,
  "a Gen 1 wrapper unwraps to the mon it carries")

-- --- M.mon: Gen 2 raw-mon shape --------------------------------------------

local totodile = gen2Mon("TOTODILE")
T.eq(Battlerof.mon(totodile), totodile,
  "a Gen 2 raw mon is handed back as itself -- there is nothing to unwrap")

-- --- M.mon: real event payloads, both generations --------------------------

-- battle.battler_switched, the shape BattleState.lua:2512-2515 emits.
local gen1Switched = { battle = {}, side = GEN1_PLAYER_SIDE, battler = wrapper,
                       previous = nil }
T.eq(Battlerof.mon(gen1Switched.battler), charizard,
  "battle.battler_switched on Gen 1: ev.battler unwraps to the mon")

-- battle.battler_switched, the shape gen2/Battle.lua:3420-3423 emits: no
-- wrapper on either `battler` or `previous`.
local outgoing = gen2Mon("CYNDAQUIL")
local gen2Switched = { battle = {}, side = GEN2_PLAYER_SIDE, battler = totodile,
                       previous = outgoing }
T.eq(Battlerof.mon(gen2Switched.battler), totodile,
  "battle.battler_switched on Gen 2: ev.battler IS the mon already")
T.eq(Battlerof.mon(gen2Switched.previous), outgoing,
  "battle.battler_switched on Gen 2: ev.previous IS the mon already")

-- battle.fainted, the shape BattleState.lua:3816 emits -- no `side` at all.
local gen1Fainted = { battle = {}, battler = wrapper }
T.eq(Battlerof.mon(gen1Fainted.battler), charizard,
  "battle.fainted on Gen 1 unwraps the wrapper despite carrying no side")

-- battle.fainted, the shape gen2/Battle.lua:3005-3006 emits.
local gen2Fainted = { battle = {}, battler = totodile, side = GEN2_PLAYER_SIDE }
T.eq(Battlerof.mon(gen2Fainted.battler), totodile,
  "battle.fainted on Gen 2 hands the mon straight through")

-- --- M.mon: nil safety ------------------------------------------------------

T.eq(Battlerof.mon(nil), nil, "a nil battler yields a nil mon, not an error")
T.eq(Battlerof.mon(false), nil, "a non-table battler yields nil rather than throwing")

-- --- M.isPlayer: Gen 1 wrapper carries it directly -------------------------

T.eq(Battlerof.isPlayer(gen1Battler(charizard, true)), true,
  "a Gen 1 wrapper's own isPlayer answers for the player's battler")
T.eq(Battlerof.isPlayer(gen1Battler(charizard, false)), false,
  "and for the enemy's")

-- --- M.isPlayer: Gen 2 has no such field, so it is read off the side -------

T.eq(Battlerof.isPlayer(totodile, GEN2_PLAYER_SIDE), true,
  "a Gen 2 mon carries no isPlayer field, so the side record answers instead")
T.eq(Battlerof.isPlayer(totodile, GEN2_ENEMY_SIDE), false,
  "and the enemy side answers false")
T.eq(Battlerof.isPlayer(totodile, GEN1_ENEMY_SIDE), false,
  "the side's `index` is what is read, so a Gen 1 side record (no `key`) works too")

-- --- M.isPlayer: neither signal present -------------------------------------

T.eq(Battlerof.isPlayer(totodile, nil), nil,
  "with no isPlayer field and no side, the answer is unknown rather than guessed")
T.eq(Battlerof.isPlayer(nil, nil), nil, "a nil battler is unknown, not false")

T.finish("battle_forms_battlerof")
