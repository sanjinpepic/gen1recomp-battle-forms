-- The Gen 2 move-substitution primitive, proven the way
-- tests/battle_forms_substitute_test.lua proves Gen 1's: apply/restore is a
-- round trip, PP is spent from the real slot and never routed around, every
-- teardown path is safe to call blind, and nothing here ever replaces
-- mon.moves itself or any slot table's identity -- see src/gen2substitute.lua's
-- own header for why that last property is the one the whole design rests on.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Sub = dofile(MOD .. "/src/gen2substitute.lua")

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

-- T.eq is `==`, reference equality -- exactly right for the identity claims
-- this suite makes ("still the same table"), but useless against a
-- deepcopy()'d snapshot, which is a DIFFERENT table with the same values by
-- construction. Content comparisons against a snapshot go through this
-- instead; identity comparisons keep using T.eq directly and say so.
local function deepEqual(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

local function movesFixture()
  return {
    { id = "FLAMETHROWER", pp = 12, maxPp = 15 },
    { id = "SLASH",        pp = 20, maxPp = 20 },
    { id = "EARTHQUAKE",   pp = 6,  maxPp = 10 },
    { id = "ROOST",        pp = 8,  maxPp = 10 },
  }
end

local function monFixture()
  return { species = "CHARIZARD", level = 50, moves = movesFixture() }
end

-- Substitutes every slot to a MAX_ prefixed id with a flat 10-PP display
-- maximum, the shape a future Max Move picker would actually hand this
-- module -- fields shared across every basic test below.
local function pickAll(slot, index)
  return { id = "MAX_" .. slot.id, maxPp = 10 }
end

-- ---------------------------------------------------------------------
-- The basic round trip: apply substitutes every slot, restore puts every
-- field back byte-identical -- id, pp, maxPp, order and count all checked,
-- not just id, because a substitution that quietly changed the PP maximum
-- back to the wrong number would still "look" reverted at a glance.
-- ---------------------------------------------------------------------
do
  local mon = monFixture()
  local before = deepcopy(mon.moves)
  local originalArray = mon.moves

  local state = Sub.new()
  T.eq(Sub.active(state), false, "a fresh state is not active")

  local ok = Sub.apply(state, mon, pickAll)
  T.eq(ok, true, "apply succeeds when every slot is substituted")
  T.eq(Sub.active(state), true, "the state now reports active")
  T.eq(mon.moves, originalArray,
    "mon.moves is STILL the exact array object -- never replaced")
  for i, slot in ipairs(mon.moves) do
    T.eq(slot, originalArray[i], "slot " .. i .. " is still its own original table")
    T.eq(slot.id, "MAX_" .. before[i].id, "slot " .. i .. " shows the substituted id")
    T.eq(slot.maxPp, 10, "slot " .. i .. " shows the substituted display maximum")
    T.eq(slot.pp, before[i].pp, "slot " .. i .. " current PP is untouched by apply")
  end

  local restored = Sub.restore(state)
  T.eq(restored, true, "restore reports it tore an active substitution down")
  T.eq(Sub.active(state), false, "the state is inactive again")
  T.eq(mon.moves, originalArray, "mon.moves is still the same array after restore")
  for i, slot in ipairs(mon.moves) do
    T.eq(slot, originalArray[i], "slot " .. i .. " is still its own original table")
  end
  T.check(deepEqual(mon.moves, before),
    "byte-identical restoration: the whole array deep-equals the original")
end

-- ---------------------------------------------------------------------
-- Partial substitution: pick answering nil/false for a slot leaves it
-- completely alone, table identity included -- proving untouched slots
-- never even get a snapshot entry, the same guarantee src/substitute.lua's
-- own header makes for an untouched slot in ITS array.
-- ---------------------------------------------------------------------
do
  local mon = monFixture()
  local before = deepcopy(mon.moves)
  local slot2, slot4 = mon.moves[2], mon.moves[4]

  local state = Sub.new()
  Sub.apply(state, mon, function(slot, index)
    if index == 1 or index == 3 then return { id = "MAX_" .. slot.id } end
    return nil
  end)

  T.eq(mon.moves[1].id, "MAX_FLAMETHROWER", "slot 1 is substituted")
  T.eq(mon.moves[3].id, "MAX_EARTHQUAKE", "slot 3 is substituted")
  T.eq(mon.moves[2], slot2, "slot 2's table is untouched by identity")
  T.eq(mon.moves[2].id, "SLASH", "slot 2's id is untouched by value")
  T.eq(mon.moves[4], slot4, "slot 4's table is untouched by identity")
  T.eq(mon.moves[4].id, "ROOST", "slot 4's id is untouched by value")

  Sub.restore(state)
  T.check(deepEqual(mon.moves, before),
    "restore still deep-equals the original for the whole array")
end

-- A substitution with no maxPp override leaves maxPp completely alone, both
-- during and after -- an explicit nil is not the same as "set it to nil".
do
  local mon = monFixture()
  local before = deepcopy(mon.moves)
  local state = Sub.new()
  Sub.apply(state, mon, function(slot) return { id = "X_" .. slot.id } end)
  T.eq(mon.moves[1].maxPp, before[1].maxPp,
    "maxPp is untouched when the picker never mentions it")
  Sub.restore(state)
  T.check(deepEqual(mon.moves, before), "and the round trip is still byte-identical")
end

-- ---------------------------------------------------------------------
-- PP: spent from the real slot while substituted (Battle.lua:1391's own
-- decrement, `move.pp = (move.pp or 1) - 1`, run here against the exact
-- substituted table to prove it lands on the same counter), refilled the
-- same way (an Ether-shaped write), and NEVER reset by restore -- a
-- substitution that quietly gave back full PP would be a cheat, one that
-- restored the wrong slot's PP would be a bug, and this pins both false.
-- ---------------------------------------------------------------------
do
  local mon = monFixture()
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)

  local slot = mon.moves[1] -- FLAMETHROWER, pp=12 before substitution
  T.eq(slot.pp, 12, "PP reads through the substitution unchanged")
  slot.pp = (slot.pp or 1) - 1 -- the real engine's own spend, Battle.lua:1391
  T.eq(slot.pp, 11, "spending PP while substituted lands on the real slot")

  -- An Ether-shaped refill mid-substitution is visible immediately, because
  -- there is only ever the one pp field to read.
  slot.pp = slot.pp + 5
  T.eq(slot.pp, 16, "a PP refill mid-substitution reaches the same counter")

  Sub.restore(state)
  T.eq(mon.moves[1].id, "FLAMETHROWER", "id is restored")
  T.eq(mon.moves[1].pp, 16, "restore does NOT reset PP -- the spend and the refill both stick")
  T.eq(mon.moves[1].maxPp, 15, "maxPp is restored to the real move's own maximum")
end

-- ---------------------------------------------------------------------
-- Idempotency and refusal shapes, mirroring src/substitute.lua's own suite.
-- ---------------------------------------------------------------------
do
  local mon = monFixture()
  local state = Sub.new()
  T.eq(Sub.apply(state, mon, pickAll), true, "first apply succeeds")
  T.eq(Sub.apply(state, mon, pickAll), false,
    "a second apply on an already-active state is refused")
  T.eq(Sub.restore(state), true, "restore tears the real substitution down")
  T.eq(Sub.restore(state), false, "a second restore on an inactive state is refused")
  T.eq(Sub.restore(nil), false, "restoring a nil state is refused, not an error")
  T.eq(Sub.apply(nil, mon, pickAll), false, "applying to a nil state is refused")
end

do
  local state = Sub.new()
  T.eq(Sub.apply(state, nil, pickAll), false, "a nil mon is refused")
  T.eq(Sub.apply(state, { moves = "not a table" }, pickAll), false,
    "a mon whose moves field is not a table is refused")
  T.eq(Sub.apply(state, monFixture(), nil), false, "a nil picker is refused")
  T.eq(Sub.apply(state, monFixture(), "not a function"), false,
    "a picker that is not a function is refused")
  T.eq(Sub.active(state), false, "none of the refused calls left the state active")
end

do
  -- A picker that substitutes nothing at all (every answer nil, or an
  -- answer with no `id`) must not leave a live-looking state behind.
  local mon = monFixture()
  local state = Sub.new()
  local ok = Sub.apply(state, mon, function() return nil end)
  T.eq(ok, false, "a picker that substitutes nothing reports failure")
  T.eq(Sub.active(state), false, "and the state is not left active")

  local ok2 = Sub.apply(state, mon, function() return { maxPp = 5 } end)
  T.eq(ok2, false, "a fields table with no id substitutes nothing")
  T.eq(Sub.active(state), false, "and again the state is not left active")
end

-- ---------------------------------------------------------------------
-- The architecture claim itself: mon.moves is NEVER reassigned, at any
-- point in apply or restore -- the property the whole safety argument rests
-- on, since there is no separate curMoves layer here to swap into instead.
-- ---------------------------------------------------------------------
do
  local mon = monFixture()
  local originalArray = mon.moves
  local originalSlots = {}
  for i, slot in ipairs(mon.moves) do originalSlots[i] = slot end

  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  T.eq(mon.moves, originalArray, "apply never reassigns mon.moves")
  for i, slot in ipairs(mon.moves) do
    T.eq(slot, originalSlots[i], "apply never replaces slot " .. i .. "'s table")
  end

  Sub.restore(state)
  T.eq(mon.moves, originalArray, "restore never reassigns mon.moves either")
  for i, slot in ipairs(mon.moves) do
    T.eq(slot, originalSlots[i], "restore never replaces slot " .. i .. "'s table")
  end
end

-- ---------------------------------------------------------------------
-- Every teardown path this mod's own HANDOFF names, proven the same way
-- tests/battle_forms_hpscale_test.lua proves Dynamax's four: each scenario
-- ends in the identical M.restore(state) call, because that is the whole
-- point of a shared primitive -- every consumer's own onTurnEnded/
-- onBattlerSwitched/onFainted/onBattleEnded/disarm/onModDisabled has nothing
-- left to do beyond calling this.
-- ---------------------------------------------------------------------

-- 1. Ends on its own (the substituted move resolved and the effect expired).
do
  local mon = monFixture()
  local before = deepcopy(mon.moves)
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  Sub.restore(state)
  T.check(deepEqual(mon.moves, before), "path 1 (expires on its own): exact restoration")
end

-- 2. Switching out: the substituted mon leaves the field and a DIFFERENT
-- mon becomes the active battler. The state holds its own mon reference
-- captured at apply time, so the switch never has to tell it who left.
do
  local outgoing = monFixture()
  local before = deepcopy(outgoing.moves)
  local incoming = { species = "BLASTOISE", level = 50,
                     moves = { { id = "SURF", pp = 15, maxPp = 15 } } }

  local state = Sub.new()
  Sub.apply(state, outgoing, pickAll)
  -- the switch: some other battler is active now, unrelated to `state`
  local activeMon = incoming
  T.eq(activeMon.moves[1].id, "SURF", "the incoming battler's own moves are untouched")

  Sub.restore(state)
  T.check(deepEqual(outgoing.moves, before), "path 2 (switching out): the outgoing mon restores exactly")
  T.eq(incoming.moves[1].id, "SURF", "and the incoming mon was never touched at all")
end

-- 3. Fainting.
do
  local mon = monFixture()
  mon.hp = 0
  local before = deepcopy(mon.moves)
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  Sub.restore(state) -- the faint handler's own call
  T.check(deepEqual(mon.moves, before), "path 3 (fainting): exact restoration")
end

-- 4. The battle ending outright (win, loss, flee, catch).
do
  local mon = monFixture()
  local before = deepcopy(mon.moves)
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  Sub.restore(state) -- battle-end sweep
  T.check(deepEqual(mon.moves, before), "path 4 (battle ending): exact restoration")
end

-- 5. The player disarming the cell before it ever resolves -- arm.lua's own
-- header notes the mechanism has to unwind on disarm as well as on the
-- other four, since a substitution follows the armed flag rather than the
-- spent one.
do
  local mon = monFixture()
  local before = deepcopy(mon.moves)
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  T.eq(Sub.active(state), true, "armed and substituted")
  Sub.restore(state) -- disarm
  T.eq(Sub.active(state), false, "disarming clears the active flag")
  T.check(deepEqual(mon.moves, before), "path 5 (disarming): exact restoration")
end

-- 6. The mod being disabled mid-battle. There is no special call for this --
-- restore must be safe to invoke from wherever a disable notification is
-- caught, even blind, even on a state nothing else has touched this frame.
do
  local mon = monFixture()
  local before = deepcopy(mon.moves)
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  local ok = Sub.restore(state) -- the disable handler's own blind call
  T.eq(ok, true, "path 6 (mod disabled mid-battle): restore runs and reports success")
  T.check(deepEqual(mon.moves, before), "and restores exactly")
  -- Calling it again (a second disable notification, or an overlapping
  -- teardown from another path) must still be safe.
  T.eq(Sub.restore(state), false, "a repeated disable notification is a safe no-op")
end

-- ---------------------------------------------------------------------
-- The engine also writes moves: mid-battle level-up. Two shapes, both
-- driven through the REAL engine module rather than a guess at its
-- behaviour -- Mon.learnMove's own append case, and a hand-built
-- Battle:resolveForget-shaped overwrite for the full-moveset case, matching
-- Battle.lua:3391-3397 (`mon.moves[slot] = entry`) exactly.
-- ---------------------------------------------------------------------
local Mon = require("src.battle.gen2.Mon")

-- Append case: room in the moveset, so Mon.learnMove adds a fifth-would-be
-- slot... except a real mon never has more than four, so this proves the
-- boring, common case first -- learning while under three moves never
-- touches an existing (possibly substituted) slot at all.
do
  local mon = { species = "PIDGEY", level = 10,
                moves = { { id = "TACKLE", pp = 35, maxPp = 35 },
                          { id = "GROWL", pp = 40, maxPp = 40 } } }
  local before1, before2 = deepcopy(mon.moves[1]), deepcopy(mon.moves[2])
  local data = { moves = { SAND_ATTACK = { pp = 15 } } }

  local state = Sub.new()
  Sub.apply(state, mon, function(slot) return { id = "MAX_" .. slot.id } end)
  T.eq(mon.moves[1].id, "MAX_TACKLE", "slot 1 substituted before the level-up")

  local ok = Mon.learnMove(mon, "SAND_ATTACK", data)
  T.eq(ok, true, "the real engine learns the new move")
  T.eq(#mon.moves, 3, "into a brand new third slot")
  T.eq(mon.moves[3].id, "SAND_ATTACK", "carrying the real learned id")

  Sub.restore(state)
  T.check(deepEqual(mon.moves[1], before1),
    "slot 1 restores exactly -- the append never touched it")
  T.check(deepEqual(mon.moves[2], before2),
    "slot 2 is untouched throughout (it was never substituted)")
  T.eq(mon.moves[3].id, "SAND_ATTACK", "and the newly learned third move is still there")
end

-- Full-moveset forget case: the dangerous one. A substituted slot is
-- overwritten by Battle:resolveForget's own write mid-battle, and restore
-- must leave the newly learned move alone rather than clobbering it with
-- the stale pre-substitution snapshot.
do
  local mon = monFixture() -- four full slots
  local before = deepcopy(mon.moves)

  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  T.eq(mon.moves[2].id, "MAX_SLASH", "slot 2 substituted")

  -- Battle:resolveForget's own write (Battle.lua:3397): `mon.moves[slot] = entry`,
  -- a BRAND NEW table, not a mutation of the one already there.
  local learned = { id = "DRAGON_CLAW", pp = 15, maxPp = 15 }
  mon.moves[2] = learned

  Sub.restore(state)
  T.eq(mon.moves[2], learned, "slot 2 keeps the exact table the engine just wrote")
  T.eq(mon.moves[2].id, "DRAGON_CLAW",
    "the newly learned move is NOT clobbered by the stale SLASH snapshot")
  T.eq(mon.moves[1].id, before[1].id, "slot 1 (untouched by the forget) restores normally")
  T.eq(mon.moves[3].id, before[3].id, "slot 3 (untouched by the forget) restores normally")
  T.eq(mon.moves[4].id, before[4].id, "slot 4 (untouched by the forget) restores normally")
  T.eq(mon.moves[1].pp, before[1].pp, "slot 1's pp is untouched throughout")
end

-- ---------------------------------------------------------------------
-- Deliberate breakage of the identity guard: with the per-slot identity
-- check disabled (restoring by index alone, the naive port of Gen 1's
-- shape), the forget-case test above must fail. Proven here by re-running
-- the exact scenario against a hand-rolled "naive" restore that skips the
-- check, showing it WOULD clobber the learned move -- the guard this suite
-- exists to pin is not a decoration.
-- ---------------------------------------------------------------------
do
  local mon = monFixture()
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)
  local learned = { id = "DRAGON_CLAW", pp = 15, maxPp = 15 }
  mon.moves[2] = learned

  -- The naive restore: index-only, no identity check -- exactly what
  -- src/gen2substitute.lua's own M.restore does NOT do. Reads a COPY of the
  -- snapshot list rather than touching state.slots itself, so the real
  -- M.restore below still has its own bookkeeping intact afterward.
  local naiveSlots = {}
  for i, entry in ipairs(state.slots) do naiveSlots[i] = entry end
  for _, entry in ipairs(naiveSlots) do
    mon.moves[entry.index].id = entry.id
    mon.moves[entry.index].maxPp = entry.maxPp
  end
  T.eq(mon.moves[2].id, "SLASH",
    "breakage check: the naive index-only restore DOES clobber the learned move")
  T.eq(learned.id, "SLASH",
    "breakage check: it corrupts the learned TABLE's own fields in place, "
      .. "worse than losing the id -- the same table the engine just wrote is now lying")

  -- Put the learned move's real content back by hand (undoing only the
  -- damage the naive simulation above did) and let the REAL M.restore run
  -- to completion, so this block leaves no stale entry in the module's
  -- internal active-state registry for anything later in this file to trip
  -- over. The real restore correctly skips slot 2 (identity no longer
  -- matches), exactly like the earlier forget-case test proved.
  learned.id, learned.maxPp = "DRAGON_CLAW", 15
  local before1, before3, before4 =
    deepcopy(mon.moves[1]), deepcopy(mon.moves[3]), deepcopy(mon.moves[4])
  Sub.restore(state)
  T.check(deepEqual(mon.moves[1], before1), "the real restore still fixes slot 1 correctly")
  T.check(deepEqual(mon.moves[3], before3), "the real restore still fixes slot 3 correctly")
  T.check(deepEqual(mon.moves[4], before4), "the real restore still fixes slot 4 correctly")
  T.eq(mon.moves[2], learned, "and the real restore still leaves the learned move's table alone")
end

-- ---------------------------------------------------------------------
-- Abnormal termination: the "save.write" veto. Proven through a stand-in
-- `mod` the way tests/battle_forms_hpscale_test.lua's own M.install section
-- does -- capturing the registered hook rather than reaching into the real
-- Runtime bus, so the wiring itself is what is under test.
-- ---------------------------------------------------------------------
do
  local hooks = {}
  local mod = { hooks = { wrap = function(_, name, fn) hooks[name] = fn end } }
  T.eq(Sub.install(mod), true, "install succeeds")
  T.eq(type(hooks["save.write"]), "function", "save.write is wrapped")

  -- No active substitution: the vanilla writer (or the next mod's own link)
  -- still runs, and its result passes through untouched.
  local vanillaCalls = 0
  local result = hooks["save.write"](function(...)
    vanillaCalls = vanillaCalls + 1
    return true
  end, "GAME")
  T.eq(vanillaCalls, 1, "with nothing active, the real writer runs")
  T.eq(result, true, "and its result passes through")

  -- An active substitution vetoes the write outright -- the writer must
  -- never even be called, not just have its result overridden, because the
  -- vanilla writer has the side effect of touching disk.
  local mon = monFixture()
  local state = Sub.new()
  Sub.apply(state, mon, pickAll)

  local vanillaCalls2 = 0
  local result2 = hooks["save.write"](function(...)
    vanillaCalls2 = vanillaCalls2 + 1
    return true
  end, "GAME")
  T.eq(vanillaCalls2, 0,
    "with a substitution live, the real writer is never even called")
  T.eq(result2, false, "and the hook itself reports the write as refused")

  -- Restoring turns the veto back off.
  Sub.restore(state)
  local vanillaCalls3 = 0
  hooks["save.write"](function(...) vanillaCalls3 = vanillaCalls3 + 1 return true end, "GAME")
  T.eq(vanillaCalls3, 1, "once restored, an ordinary save goes through again")

  -- Two independent consumers: the veto answers for the UNION of every
  -- state this module is tracking, not just the most recently applied one.
  local mon2 = monFixture()
  local stateA, stateB = Sub.new(), Sub.new()
  Sub.apply(stateA, mon, pickAll)
  Sub.apply(stateB, mon2, pickAll)
  Sub.restore(stateA)
  local vanillaCalls4 = 0
  local result4 = hooks["save.write"](function(...) vanillaCalls4 = vanillaCalls4 + 1 return true end, "GAME")
  T.eq(vanillaCalls4, 0,
    "one of two active substitutions restored is still not enough to allow a save")
  T.eq(result4, false, "the veto still holds while stateB is live")
  Sub.restore(stateB)
  local vanillaCalls5 = 0
  hooks["save.write"](function(...) vanillaCalls5 = vanillaCalls5 + 1 return true end, "GAME")
  T.eq(vanillaCalls5, 1, "only once BOTH are restored does a save go through again")
end

-- Idempotent install: a second call subscribes nothing new.
do
  local hooks = {}
  local calls = 0
  local mod = { hooks = { wrap = function(_, name, fn)
    calls = calls + 1
    hooks[name] = fn
  end } }
  Sub.install(mod)
  local callsAfterFirst = calls
  Sub.install(mod)
  T.eq(calls, callsAfterFirst, "a second install wraps nothing new")
end

-- Missing mod.hooks degrades to a loud refusal, not a crash.
do
  T.eq(Sub._installed, true,
    "precondition: a real install already ran earlier in this file")
end
do
  -- A fresh copy of the module (installed flag unset) against a mod with no
  -- hooks table at all.
  local Fresh = dofile(MOD .. "/src/gen2substitute.lua")
  local errors = {}
  local mod = { log = { error = function(_, ...) errors[#errors + 1] = table.concat({...}, " ") end } }
  local ok = Fresh.install(mod)
  T.eq(ok, false, "install refuses rather than crashing when mod.hooks is unavailable")
  T.check(#errors > 0, "and logs why")
end

-- ---------------------------------------------------------------------
-- Real engine drive: a mon built through the actual Gen 2 Mon constructor,
-- not a hand-typed fixture, proving the primitive works against the shape
-- the real party record actually has (dvs/statExp/stats/hp all present, the
-- way a real save's mon carries them) and not just a bare {species,moves}
-- stand-in.
-- ---------------------------------------------------------------------
do
  local data = { pokemon = {
    CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                                specialAttack = 85, specialDefense = 85 },
                  types = { "FIRE", "FLYING" }, name = "CHARIZARD", growthRate = "MEDIUM_SLOW" },
  }, moves = {
    FLAMETHROWER = { pp = 15 }, SLASH = { pp = 20 },
  } }
  local realMon = Mon.new(data, "CHARIZARD", 50,
    { dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
      moves = { { id = "FLAMETHROWER", pp = 12, maxPp = 15 },
                { id = "SLASH", pp = 20, maxPp = 20 } } })
  T.check(realMon ~= nil, "the real engine constructor builds a mon")
  local before = deepcopy(realMon.moves)
  local realArray = realMon.moves

  local state = Sub.new()
  local ok = Sub.apply(state, realMon, function(slot) return { id = "MAX_" .. slot.id, maxPp = 10 } end)
  T.eq(ok, true, "apply succeeds against a real engine-built mon")
  T.eq(realMon.moves, realArray, "mon.moves is still the exact array the constructor built")
  T.eq(realMon.moves[1].id, "MAX_FLAMETHROWER", "slot 1 substituted")
  T.eq(realMon.hp, realMon.stats.hp, "nothing about HP is touched -- this primitive never reads it")

  Sub.restore(state)
  T.check(deepEqual(realMon.moves, before), "byte-identical restoration against the real engine mon too")
  T.eq(realMon.moves, realArray, "and the array is still the exact one the constructor built")
end

T.finish("battle_forms_gen2substitute")
