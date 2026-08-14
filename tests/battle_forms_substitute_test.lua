-- Move substitution: the mechanism on its own, with no Max Move anywhere near
-- it.
--
-- The assertions about IDENTITY are most of the point of this suite.  A
-- battler's curMoves is the party Pokemon's own move array by reference
-- (BattleState.lua:515) and the tables inside it are the records the save writer
-- walks, so a substitution that copies the array back instead of restoring it,
-- or that writes one field onto one slot, is a change the player keeps.  Every
-- check below that compares tables with T.eq rather than their contents is
-- there to catch exactly that.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Substitute = dofile(MOD .. "/src/substitute.lua")

local function newBattler()
  local moves = {
    { id = "EMBER", pp = 25 },
    { id = "TACKLE", pp = 35, ppUps = 2 },
    { id = "GROWL", pp = 40 },
  }
  return { isPlayer = true, curMoves = moves, mon = { moves = moves } }, moves
end

-- Every key every slot carried, kept per slot so the comparison afterwards is
-- "nothing new and nothing missing" rather than a list of guesses.
local function slotKeys(moves)
  local out = {}
  for index, slot in ipairs(moves) do
    local keys = {}
    for key, value in pairs(slot) do keys[key] = value end
    out[index] = keys
  end
  return out
end

local function assertSlotsUntouched(before, moves, when)
  for index, keys in ipairs(before) do
    local slot = moves[index]
    for key, value in pairs(keys) do
      T.eq(slot[key], value,
        ("slot %d keeps %s %s"):format(index, key, when))
    end
    for key in pairs(slot) do
      T.check(keys[key] ~= nil,
        ("slot %d gained no key %s %s"):format(index, tostring(key), when))
    end
  end
end

-- ---------------------------------------------------------------------
-- A fresh record substitutes nothing and restores nothing.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  T.eq(Substitute.active(state), false, "a fresh record covers no battler")
  T.eq(Substitute.restore(state), false, "and restoring it is a refusal")
  T.eq(Substitute.restore(nil), false, "as is restoring nothing at all")
end

-- ---------------------------------------------------------------------
-- Applying replaces the ARRAY and leaves every slot alone.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  local battler, original = newBattler()
  local keysBefore = slotKeys(original)

  local seen = {}
  local applied = Substitute.apply(state, battler, function(slot, index)
    seen[#seen + 1] = { id = slot.id, index = index }
    return { id = "SUB_" .. slot.id }
  end)

  T.eq(applied, true, "the substitution happened")
  T.eq(Substitute.active(state), true, "and the record says so")
  T.eq(#seen, 3, "the picker was asked about every slot")
  T.eq(seen[1].id, "EMBER", "in order, starting at the first")
  T.eq(seen[3].index, 3, "and told which slot it was looking at")

  T.check(battler.curMoves ~= original,
    "the battler is holding a different array")
  T.eq(battler.mon.moves, original,
    "and the Pokemon is still holding its own")
  T.eq(#battler.curMoves, 3, "with the same number of slots")
  T.eq(battler.curMoves[1].id, "SUB_EMBER", "reading the substituted ids")
  T.eq(battler.curMoves[2].id, "SUB_TACKLE", "in every slot")
  assertSlotsUntouched(keysBefore, original, "while a substitution is live")

  -- The substitute is not the slot and must never be mistaken for it.
  for index, slot in ipairs(original) do
    T.check(battler.curMoves[index] ~= slot,
      ("slot %d's substitute is its own table"):format(index))
  end
end

-- ---------------------------------------------------------------------
-- PP reads through to the slot, and spending it lands on the slot.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  local battler, original = newBattler()
  Substitute.apply(state, battler, function(slot)
    return { id = "SUB_" .. slot.id, ppUps = 7 }
  end)

  local sub = battler.curMoves[1]
  T.eq(sub.pp, 25, "the substitute reads the slot's PP")
  T.eq(rawget(sub, "pp"), nil,
    "and carries none of its own -- which is what keeps the alias firing")

  -- This is the write performMove makes: `moveInst.pp = max(0, moveInst.pp - 1)`
  -- (BattleState.lua:3614).  It must land on the party Pokemon's slot, because
  -- spending a turn of that move is exactly what happened.
  sub.pp = sub.pp - 1
  T.eq(original[1].pp, 24, "spending the substitute spends the slot")
  T.eq(sub.pp, 24, "and the substitute reads the new number back")
  T.eq(rawget(sub, "pp"), nil, "still with no PP of its own")

  -- An Ether refills the slot mid-substitution; there is only one number, so
  -- the substitute simply reads the new one.
  original[1].pp = 25
  T.eq(sub.pp, 25, "a refilled slot is a refilled substitute")

  -- Fields the picker supplied are the substitute's own.
  T.eq(rawget(sub, "ppUps"), 7, "supplied fields are real keys on the substitute")
  T.eq(original[2].ppUps, 2, "and the slot's own ppUps is untouched")
  T.eq(battler.curMoves[2].ppUps, 7,
    "with the substitute's own value shadowing it")

  -- Anything the picker did not supply is absent rather than borrowed: a
  -- substitute that fell through to the slot for `id` would be the base move
  -- wearing a new name.
  T.eq(sub.mimic, nil, "an unsupplied field reads nil")
  sub.mimic = true
  T.eq(rawget(sub, "mimic"), true, "writing one lands on the substitute")
  T.eq(rawget(original[1], "mimic"), nil, "and never on the slot")
end

-- A picker that supplies `pp` is refused it, because a substitute with its own
-- PP is a Pokemon with unlimited PP for the duration.
do
  local state = Substitute.new()
  local battler, original = newBattler()
  Substitute.apply(state, battler, function(slot)
    return { id = "SUB_" .. slot.id, pp = 99 }
  end)
  T.eq(rawget(battler.curMoves[1], "pp"), nil, "a supplied pp is dropped")
  T.eq(battler.curMoves[1].pp, 25, "and the slot's PP is what is read")
  battler.curMoves[1].pp = 20
  T.eq(original[1].pp, 20, "and what is written")
end

-- ---------------------------------------------------------------------
-- A slot the picker passes on keeps its own identity.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  local battler, original = newBattler()
  local applied = Substitute.apply(state, battler, function(slot)
    if slot.id == "TACKLE" then return nil end
    return { id = "SUB_" .. slot.id }
  end)

  T.eq(applied, true, "a partial substitution is still a substitution")
  T.eq(battler.curMoves[2], original[2],
    "the passed-over slot is the SAME table, so its PP was never rerouted")
  T.check(battler.curMoves[1] ~= original[1], "while the others were replaced")

  battler.curMoves[2].pp = 30
  T.eq(original[2].pp, 30, "and spending it spends the slot directly")
end

-- A picker that passes on everything substitutes nothing and leaves no record
-- to unwind.
do
  local state = Substitute.new()
  local battler, original = newBattler()
  T.eq(Substitute.apply(state, battler, function() return nil end), false,
    "nothing to substitute is answered as a refusal")
  T.eq(battler.curMoves, original, "the battler kept its own array")
  T.eq(Substitute.active(state), false, "and there is no record to unwind")
end

-- A picker answering with no id is the same refusal: a substitute the registry
-- could never resolve is worse than no substitute.
do
  local state = Substitute.new()
  local battler, original = newBattler()
  T.eq(Substitute.apply(state, battler, function() return { ppUps = 3 } end),
    false, "fields with no id substitute nothing")
  T.eq(battler.curMoves, original, "and the array is untouched")
end

-- ---------------------------------------------------------------------
-- Restoring puts the original array back BY IDENTITY.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  local battler, original = newBattler()
  local keysBefore = slotKeys(original)

  Substitute.apply(state, battler, function(slot)
    return { id = "SUB_" .. slot.id }
  end)
  T.eq(Substitute.restore(state), true, "restoring answers that it happened")
  T.eq(battler.curMoves, original,
    "and the battler is holding the exact table it started with")
  T.eq(battler.curMoves, battler.mon.moves,
    "which is the Pokemon's own array again, not a copy of it")
  assertSlotsUntouched(keysBefore, original, "after the unwind")

  T.eq(Substitute.active(state), false, "the record is empty")
  T.eq(state.battler, nil, "and holds no battler")
  T.eq(state.was, nil, "and no array")
  T.eq(Substitute.restore(state), false, "so a second unwind changes nothing")
  T.eq(battler.curMoves, original, "and leaves the array where it is")
end

-- ---------------------------------------------------------------------
-- One record covers one battler at a time.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  local first = newBattler()
  local second = newBattler()
  local pick = function(slot) return { id = "SUB_" .. slot.id } end

  T.eq(Substitute.apply(state, first, pick), true, "the first is covered")
  local firstList = first.curMoves
  T.eq(Substitute.apply(state, second, pick), false,
    "a record already covering a battler refuses a second")
  T.eq(second.curMoves, second.mon.moves, "so the second keeps its own array")
  T.eq(first.curMoves, firstList, "and the first is undisturbed")
end

-- ---------------------------------------------------------------------
-- Something else replacing curMoves wins, and the unwind stands down.
--
-- Transform rebuilds the list wholesale (MoveEffects.lua:331), and restoring
-- over the top of that would undo someone else's change rather than this one's.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  local battler, original = newBattler()
  Substitute.apply(state, battler, function(slot)
    return { id = "SUB_" .. slot.id }
  end)

  local transformed = { { id = "PSYCHIC_TYPE", pp = 5, mimic = true } }
  battler.curMoves = transformed

  T.eq(Substitute.restore(state), false,
    "restoring refuses when the battler is holding someone else's list")
  T.eq(battler.curMoves, transformed, "which is left exactly where it was")
  T.eq(Substitute.active(state), false,
    "and the record clears itself anyway, so it holds no battler afterwards")
  T.eq(battler.mon.moves, original, "the Pokemon's own array is untouched")
end

-- ---------------------------------------------------------------------
-- Nothing to work with is answered rather than thrown.
-- ---------------------------------------------------------------------
do
  local state = Substitute.new()
  T.eq(Substitute.apply(state, nil, function() return { id = "X" } end), false,
    "no battler, no substitution")
  T.eq(Substitute.apply(state, { curMoves = "not a table" }, function() end),
    false, "and no move array either")
  T.eq(Substitute.apply(state, newBattler(), nil), false,
    "a missing picker is a refusal rather than a call on nil")
  T.eq(Substitute.apply(nil, newBattler(), function() end), false,
    "and so is a missing record")
end

T.finish("battle_forms_substitute")
