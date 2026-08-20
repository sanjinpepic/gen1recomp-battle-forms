-- Dynamax Level, and the scaled-HP arithmetic it drives.
--
-- The arithmetic is the part worth real proof.  src/hpscale.lua never writes
-- HP -- it scales incoming damage instead and paints a scaled readout over the
-- real one -- so the model only holds together if the damage side and the
-- display side agree exactly, at every level, for every sequence of hits. A
-- disagreement does not throw: it shows a bar that drains at the wrong speed,
-- which is the kind of bug that gets reported as "Dynamax feels off" and takes
-- a week.
--
-- So the identity is proved by induction over whole battles rather than
-- sampled: for any level and any sequence of hits, the total damage applied to
-- real HP must equal floor(total dealt / multiplier), which is what a genuinely
-- scaled-HP Pokemon would have lost.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Level = dofile(MOD .. "/src/dynamaxlevel.lua")
local HpScale = dofile(MOD .. "/src/hpscale.lua")

-- --- the level itself -----------------------------------------------------
T.eq(Level.of(nil), 0, "no Pokemon reads as level 0")
T.eq(Level.of({}), 0, "an unstamped Pokemon reads as level 0")
T.eq(Level.MIN, 0, "the floor is 0")
T.eq(Level.MAX, 10, "the ceiling is 10")

local mon = {}
T.eq(Level.set(mon, 4), true, "setting a level reports the change")
T.eq(Level.of(mon), 4, "and takes")
T.eq(Level.set(mon, 4), false, "setting the same level reports no change")

-- Anything a save could hold that is not a level reads as 0 rather than
-- throwing: this is asked from inside a battle, and a Dynamax that refuses
-- because a field was the wrong shape is worse than one that happens weakly.
for _, junk in ipairs({ "10", true, {}, -3, 99, 2.7 }) do
  local dirty = { [Level.STAMP] = junk }
  local got = Level.of(dirty)
  T.check(got >= 0 and got <= 10 and got == math.floor(got),
    "a junk stamp (" .. tostring(junk) .. ") still reads as a valid level")
end
T.eq(Level.of({ [Level.STAMP] = 99 }), 10, "an over-range stamp clamps to 10")
T.eq(Level.of({ [Level.STAMP] = -3 }), 0, "an under-range stamp clamps to 0")

-- --- the multiplier is exactly the spec's table ---------------------------
-- Written out as the published table rather than recomputed from the formula,
-- so a change to the formula has to disagree with the table to land.
local WANT = { [0] = 1.50, 1.55, 1.60, 1.65, 1.70, 1.75, 1.80, 1.85, 1.90,
               1.95, 2.00 }
for level = 0, 10 do
  local num = Level.numerator(level)
  local got = num / Level.DENOMINATOR
  T.check(math.abs(got - WANT[level]) < 1e-9,
    ("level %d is x%.2f"):format(level, WANT[level]))
end
T.eq(Level.numerator(10) / Level.DENOMINATOR, 2,
  "level 10 is exactly x2 -- what every Dynamax was before levels existed")

-- --- the Candy ------------------------------------------------------------
local fed = {}
for want = 1, 10 do
  T.eq(Level.increase(fed), true, "candy " .. want .. " raises the level")
  T.eq(Level.of(fed), want, "to " .. want)
end
T.eq(Level.increase(fed), false, "an eleventh candy does nothing")
T.eq(Level.of(fed), 10, "and the level stays at the ceiling")

local ok, text = Level.feed(fed)
T.eq(ok, false, "feeding a maxed Pokemon is refused")
T.check(text[2]:find("already", 1, true) ~= nil, "and says why")
-- Refused means `used` is false, which is what keeps the Candy in the bag --
-- a misclick on a maxed Pokemon must not cost one.
local gen2Refusal = { species = "X", [Level.STAMP] = 10 }
T.eq((Level.feed(gen2Refusal)), false, "a refused candy is never consumed")

local fresh = { nickname = "SPARKY" }
local rose, roseText = Level.feed(fresh)
T.eq(rose, true, "feeding a fresh Pokemon works")
T.check(roseText[1]:find("SPARKY", 1, true) ~= nil, "and names the Pokemon")
T.check(roseText[2]:find("1", 1, true) ~= nil, "and the level it reached")

local _, readText = Level.describe(fresh)
T.check(readText[2]:find("1/10", 1, true) ~= nil,
  "the Band reads the level back as a fraction of the ceiling")

-- --- the scaled-damage identity, at every level --------------------------
-- HpScale falls back to a flat x2 when no level module is bound, which is what
-- keeps every pre-existing suite green; bound, it must follow the Pokemon.
HpScale.install({ hooks = { wrap = function() end },
                  content = { move_effects = { patch = function() end,
                                               register = function() end } } },
                { }, nil, false, Level)

-- A deterministic spread of hit sizes, including the ones most likely to
-- expose a carry bug: 1 (smaller than any multiplier's fractional step), and
-- runs of odd numbers.
local HITS = { 1, 1, 1, 3, 7, 2, 5, 9, 1, 4, 13, 6, 11, 1, 8 }

for level = 0, 10 do
  local target = { [Level.STAMP] = level, hp = 10000,
                   stats = { hp = 10000 } }
  local state = { mon = target, carry = 0 }
  local num = Level.numerator(level)
  local den = Level.DENOMINATOR

  local dealt, applied = 0, 0
  for _, hit in ipairs(HITS) do
    dealt = dealt + hit
    applied = applied + HpScale.scaleDamage(state, target, hit)
    -- The induction step: after EVERY hit, not merely at the end.
    T.eq(applied, math.floor(dealt * den / num),
      ("level %d: after %d dealt, %d has reached real HP")
        :format(level, dealt, applied))
  end
end

-- --- the display agrees with the damage ----------------------------------
-- The scaled bar must equal what a genuinely scaled-HP Pokemon would show, at
-- every point in a battle. This is the half that cannot throw and so would
-- otherwise only be noticed by eye.
for level = 0, 10 do
  local num, den = Level.numerator(level), Level.DENOMINATOR
  local maxHp = 137 -- deliberately not a round number
  local target = { [Level.STAMP] = level, hp = maxHp,
                   stats = { hp = maxHp } }
  local state = { mon = target, carry = 0 }

  T.eq(HpScale.displayedMax(state, target), math.floor(maxHp * num / den),
    ("level %d: the scaled maximum is the Pokemon's own"):format(level))
  T.eq(HpScale.displayedCurrent(state, target),
    HpScale.displayedMax(state, target),
    ("level %d: an undamaged Pokemon shows full"):format(level))

  local dealt = 0
  for _, hit in ipairs(HITS) do
    dealt = dealt + hit
    target.hp = target.hp - HpScale.scaleDamage(state, target, hit)
    -- What the scaled model itself would be showing: full scaled HP less
    -- everything dealt so far, on the scaled scale.
    T.eq(HpScale.displayedCurrent(state, target),
      math.floor(maxHp * num / den) - dealt,
      ("level %d: the bar matches the scaled model after %d dealt")
        :format(level, dealt))
  end
end

-- --- an unbound build still behaves exactly as it used to ----------------
-- Every suite written before levels existed depends on this, and so does any
-- build that loads hpscale without the level module.
local Unbound = dofile(MOD .. "/src/hpscale.lua")
local plain = { hp = 100, stats = { hp = 100 } }
local plainState = { mon = plain, carry = 0 }
T.eq(Unbound.scaleDamage(plainState, plain, 3), 1, "unbound halves, as before")
T.eq(plainState.carry, 1, "carrying the odd half-point, as before")
T.eq(Unbound.displayedMax(plainState, plain), 200, "and doubles the maximum")

T.finish("battle_forms_dynamaxlevel")
