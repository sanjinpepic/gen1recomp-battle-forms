-- Move substitution: giving a battler a different set of moves for as long as
-- something else says so, and taking it back off again.
--
-- This is the mechanism, not a mechanic.  Max Moves are its first consumer and
-- Z-Moves are meant to be its second, which is why nothing here knows what a
-- Max Move is -- the caller hands over a function that answers, per slot, what
-- that slot should become.
--
-- WHY NOTHING IS WRITTEN INTO A MOVE SLOT, which is the decision worth reading.
--
-- makeBattler seeds `curMoves` from the party Pokemon BY REFERENCE
-- (BattleState.lua:515, `curMoves = mon.moves`), and the tables inside it are
-- the mon's own move records -- the very tables the save writer walks.  The
-- engine says so itself where Mimic overwrites a slot's id: "curMoves aliases
-- mon.moves ... pokered never writes the party copy" (BattleState.lua:
-- 2206-2214).  So a flag written onto a slot to mark it substituted, or an id
-- overwritten in place, is a write into the player's save file that outlives
-- the battle.  Nothing here touches a slot table.
--
-- Instead the whole ARRAY is replaced -- curTypes is overridden the same way in
-- src/tera.lua and for the same reason -- and the unwind puts the original
-- array back by reference rather than rebuilding it, so a battler that was
-- Transformed, Mimicking or reordered mid-battle gets back exactly the list it
-- had.  Substituting the array is enough: every reader in the battle goes
-- through `curMoves` (the FIGHT menu and its PP check, BattleState.lua:1868 and
-- 2084; turn resolution, which is handed the slot the menu picked, :2116-2127;
-- Disable and Mimic, :1222 and :2178-2238; the AI's move scoring,
-- TrainerAI.lua:172 and :233; both battle layouts' move lists, :5825 and
-- WideBattle.lua:247).  The two places that read `mon.moves` directly are the
-- move-slot swap, which deliberately keeps the stored order in step
-- (BattleState.lua:1880), and level-up learning, which is about the party
-- Pokemon and not about the battle (:4192).
--
-- PP IS THE ONE FIELD THAT MUST STILL REACH THE MON.  A substituted move spends
-- the PP of the move it stands in for -- that is how Max Moves work in the real
-- games, and it is also the only answer that leaves the save honest: the player
-- used a turn of that slot.  performMove writes it straight onto whatever
-- instance it was handed (`moveInst.pp = math.max(0, moveInst.pp - 1)`,
-- BattleState.lua:3614), so a substitute carrying its own `pp` would quietly
-- give the Pokemon unlimited PP for the duration and hand the slot back
-- untouched.  A substitute therefore has NO `pp` key of its own: __index and
-- __newindex only fire while a key is absent from the table, so every read and
-- every write of `pp` lands on the slot underneath, which is where PP has
-- always lived.  An Ether used mid-substitution refills the slot and the
-- substitute reads the new number, because there is only ever one number.
local M = {}

-- The other half of that, which every consumer needs and none of them should
-- work out for itself: the substitute reads the slot's REMAINING PP, but the
-- FIGHT menu draws a MAXIMUM and takes that from the substitute's own registered
-- record -- `def.pp + ppUps * floor(def.pp / 5)` (BattleState.lua:5850,
-- WideBattle.lua:222).  Left alone, the menu would show a remaining count from
-- one move against a maximum from another.
--
-- So a substitute carries a `ppUps` that makes the formula come back out at the
-- base move's own maximum: `recordPP + ppUps * floor(recordPP / 5)` is asked to
-- equal `basePP + slotPPUps * floor(basePP / 5)`, which is the number the player
-- is actually spending against.  Answers nil when the base move has no PP to
-- read, so the caller leaves the field off rather than sending a nil through
-- arithmetic.
function M.menuPPUps(recordPP, basePP, slotPPUps)
  recordPP, basePP = tonumber(recordPP), tonumber(basePP)
  if not recordPP or not basePP then return nil end
  local step = math.floor(recordPP / 5)
  if step <= 0 then return nil end
  local want = basePP + (tonumber(slotPPUps) or 0) * math.floor(basePP / 5)
  -- Floored rather than exact, because a record PP whose step does not divide
  -- the difference would otherwise hand the menu a fraction, and the menu
  -- formats its maximum with %d.  Rounding down shows a maximum no higher than
  -- the real one, which is the safe direction to be wrong in.
  return math.floor((want - recordPP) / step)
end

-- One substituted slot.  `fields` is the caller's record for it -- `id` at
-- minimum -- and is copied in rather than used directly, so the caller may
-- reuse one table across four slots without four battlers sharing it.
local function substitute(slot, fields)
  local sub = {}
  for key, value in pairs(fields) do
    -- `pp` would defeat the alias below by existing.  A caller that supplies
    -- one is asking for the substitute to keep its own PP, which is exactly
    -- the write this module exists to avoid.
    if key ~= "pp" then sub[key] = value end
  end
  return setmetatable(sub, {
    __index = function(_, key)
      if key == "pp" then return slot.pp end
      return nil
    end,
    __newindex = function(target, key, value)
      if key == "pp" then slot.pp = value else rawset(target, key, value) end
    end,
  })
end

-- One record per consumer, holding the battler it is covering, the array it
-- took off and the array it put on.  The last is what makes the unwind safe to
-- run blind: Transform replaces curMoves wholesale (MoveEffects.lua:331), and
-- restoring over the top of that would undo someone else's change rather than
-- this one's.
function M.new()
  return { battler = nil, was = nil, applied = nil }
end

function M.active(state)
  return state ~= nil and state.applied ~= nil
end

-- `pick(slot, index)` answers with the fields the substitute should carry, or
-- nil to leave that slot exactly as it is -- untouched slots keep their own
-- identity in the new array, so a partly substituted moveset still spends and
-- shows PP through the same tables it always did.
--
-- Answers false when nothing was substituted, so a caller cannot end up
-- holding a record that has to be unwound but has nothing to unwind.
function M.apply(state, battler, pick)
  if not state or state.applied then return false end
  local original = battler and battler.curMoves
  if type(original) ~= "table" or type(pick) ~= "function" then return false end

  local moves, replaced = {}, false
  for index, slot in ipairs(original) do
    local fields = type(slot) == "table" and pick(slot, index) or nil
    if type(fields) == "table" and fields.id then
      moves[index] = substitute(slot, fields)
      replaced = true
    else
      moves[index] = slot
    end
  end
  if not replaced then return false end

  state.battler, state.was, state.applied = battler, original, moves
  battler.curMoves = moves
  return true
end

-- Puts the original array back by reference, which also restores
-- BattleCheckpoint's `curMovesFromMon` shortcut (BattleCheckpoint.lua:72) to
-- the answer it gave before this ran.
--
-- Refuses to restore over an array this module did not install, and clears
-- itself either way: a record kept past a failed unwind would hold a battler --
-- and through it a mon -- for the rest of the session.
function M.restore(state)
  if not state then return false end
  local battler, was, applied = state.battler, state.was, state.applied
  state.battler, state.was, state.applied = nil, nil, nil
  if not battler or applied == nil then return false end
  if battler.curMoves ~= applied then return false end
  battler.curMoves = was
  return true
end

return M
