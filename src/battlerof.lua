-- Gen 1 and Gen 2 fire the same Runtime event names -- battle.started,
-- battle.battler_switched, battle.fainted, battle.ended, battle.turn_ended,
-- battle.move_used, battle.damage_dealt -- but with different payload
-- shapes. Gen 1 hands a battler WRAPPER (BattleState.lua's makeBattler,
-- :482-524: `{ mon = mon, isPlayer = isPlayer, curStats = ..., ... }`). Gen 2
-- has no such wrapper at all: `battler` (or `user`/`target`/`previous` on
-- battle.move_used/battle.damage_dealt/battle.battler_switched, or the live
-- `battle.player`/`battle.enemy` fields) IS the mon --
-- game/src/battle/gen2/Battle.lua says so in its own comment at line 3004.
--
-- Every handler in this mod used to read `battler.mon` straight off one of
-- those, which answers correctly on Gen 1 and silently returns nil on Gen 2 --
-- there is no `.mon` field on a mon (src/pokemon/Pokemon.lua's Pokemon.new
-- never writes one). This module is the one place that tells the two shapes
-- apart, so a handler asks it once and gets the same answer regardless of
-- which engine's event it is looking at.
--
-- The manifest still declares "gen1" only -- nothing here runs against a
-- live Gen 2 game yet, and the mechanics themselves (curStats/curTypes
-- overrides in src/forms.lua) stay Gen 1-only until a later step gives them
-- a Gen 2 path of their own. What this buys now is that every event read in
-- the mod already tells the two payload shapes apart, so widening the
-- manifest later is not also an audit of every `.mon` read in the codebase.
local M = {}

-- The value an event names `battler`/`user`/`target`/`previous`, or a live
-- battle field (`battle.player`/`battle.enemy`). Gen 1 hands a wrapper; Gen 2
-- hands the mon itself. The wrapper's own `mon` field is the discriminator --
-- a raw Pokemon record never carries one -- so its presence, not its
-- generation, is what this checks.
function M.mon(battlerOrMon)
  if type(battlerOrMon) ~= "table" then return nil end
  if battlerOrMon.mon ~= nil then return battlerOrMon.mon end
  return battlerOrMon
end

-- Whether the battler/mon belongs to the player's side. Gen 1's wrapper
-- carries this directly (`isPlayer`, BattleState.lua:498) and is asked
-- first, because not every Gen 1 event carries a side record --
-- battle.fainted does not (BattleState.lua:3816). `side` is the payload's
-- own side record, whose `index` field is 1 for the player's side on both
-- engines (BattleState.lua:598-601 for Gen 1, Battle.newSides in
-- game/src/battle/gen2/Battle.lua:357-364 for Gen 2) -- Gen 2's side also
-- carries a `key` string, Gen 1's does not, so `index` is the one field
-- guaranteed present on either shape.
--
-- Answers nil, not false, when neither signal is available: a mon whose side
-- cannot be determined is an unknown, and treating that as "not the player's"
-- would be a guess wearing a boolean's clothes.
function M.isPlayer(battlerOrMon, side)
  if type(battlerOrMon) == "table" and battlerOrMon.isPlayer ~= nil then
    return battlerOrMon.isPlayer == true
  end
  if type(side) == "table" and side.index ~= nil then
    return side.index == 1
  end
  return nil
end

return M
