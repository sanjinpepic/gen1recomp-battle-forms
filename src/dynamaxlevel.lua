-- A Pokemon's Dynamax Level, 0-10, and the Candy that raises it.
--
-- WRITTEN, NOT DERIVED, and that is forced rather than chosen.  src/teratype.lua
-- derives a Tera type from a Pokemon's DVs precisely so that nothing has to be
-- written into a save -- but a Tera type is an identity, where this is
-- PROGRESS.  A value a player spends items raising cannot be a function of
-- fields that never change, so this is a stamp on the mon and there was no
-- second option to weigh.
--
-- WHAT THAT COSTS, said plainly because it is the real downside: a Game Boy
-- .sav export drops it.  src/persistent.lua's header has the mechanism -- a
-- byte-exact 44-byte party struct with no hook anywhere near it -- and here the
-- loss is worse-shaped than it is there, because an absent stamp reads as level
-- 0 and level 0 is the WEAKEST value rather than a neutral one.  A Pokemon that
-- has been through a cartridge comes back needing its Candy again.  Accepted
-- deliberately: the alternative is treating an import as a special case, and
-- that turns exporting and reimporting into a way to skip the Candy entirely.
--
-- THE MULTIPLIER IS A CLEAN RATIONAL, which is the whole reason this fits the
-- existing HP machinery instead of replacing it.  1.5 + 0.05 * level is
-- (30 + level) / 20, exactly, for every level from 0 to 10 -- no floating point
-- anywhere and no rounding table to keep in step with a formula.  Level 10 is
-- 40/20, which is x2, which is what src/hpscale.lua has always done: every
-- Dynamax before this file existed was a level 10 one, and levels generalise
-- that code rather than rewriting it.
--
-- LEVEL 0 IS THE DEFAULT AND EXISTING POKEMON DROP TO IT.  That is a real
-- balance change to saves that already exist -- x2 becomes x1.5 for every
-- Pokemon a player already owns -- and it is the deliberate choice: a level
-- that every Pokemon already has at maximum is a mechanic with nothing to do,
-- and Dynamax Candy is on the Celadon shelf beside the Tera Shards, so getting
-- back to x2 is a shopping trip rather than lost progress.
local M = {}

M.STAMP = "battleFormsDynamaxLevel"

M.MIN = 0
M.MAX = 10

-- The multiplier is NUMERATOR(level) / DENOMINATOR, kept as two integers so
-- every consumer does integer arithmetic.  src/hpscale.lua's carry depends on
-- that: it accounts for the fraction of a hit point a scaled hit did not use,
-- and a float would let that accounting drift by a point over a long battle
-- in a way nobody could reproduce.
M.DENOMINATOR = 20

function M.numerator(level)
  return 30 + M.clamp(level)
end

function M.clamp(level)
  level = tonumber(level)
  if not level then return M.MIN end
  level = math.floor(level)
  if level < M.MIN then return M.MIN end
  if level > M.MAX then return M.MAX end
  return level
end

-- The Pokemon's level.  Anything a save could hold that is not a level -- a
-- string a different mod wrote, a number out of range, a value an old build
-- meant differently -- reads as M.MIN rather than as an error: this is asked
-- from inside a battle, and a Dynamax that refuses to happen because a field
-- was the wrong shape is worse than one that happens weakly.
function M.of(mon)
  if not mon then return M.MIN end
  local raw = mon[M.STAMP]
  if type(raw) ~= "number" then return M.MIN end
  return M.clamp(raw)
end

-- Answers false when nothing changed, so a caller can tell "set to 7" from
-- "was already 7" without comparing before and after itself.
function M.set(mon, level)
  if not mon then return false end
  local want = M.clamp(level)
  if M.of(mon) == want then return false end
  -- Level 0 is stored as 0 rather than by clearing the field.  A cleared field
  -- and an absent one read identically through M.of, but only a written 0 says
  -- "this Pokemon has been looked at", which is what a future migration would
  -- need to tell apart.
  mon[M.STAMP] = want
  return true
end

-- One Candy's worth.  False at the ceiling, which is what makes the refusal
-- below possible without the caller knowing the ceiling.
function M.increase(mon)
  local now = M.of(mon)
  if now >= M.MAX then return false end
  return M.set(mon, now + 1)
end

-- --- the Candy, and the Band that reads the level back --------------------

M.CANDY = "DYNAMAX_CANDY"

-- Dearer than a Tera Shard (200) and cheaper than a mega stone (4000): ten of
-- these take one Pokemon from x1.5 to x2, so the shelf cost of a maxed
-- Pokemon lands near a stone's, which is the comparison a player is actually
-- making.
M.CANDY_PRICE = 400

local monName, deps

function M.bind(modules) deps = modules end

monName = function(mon)
  return tostring(mon and (mon.nickname or mon.name or mon.species) or "It")
end

-- Reading the level back is not a convenience here for the same reason it was
-- not one for the Tera Orb (src/terashop.lua's header): the level is written
-- data that appears on no screen anywhere, so without something that names it
-- a player cannot tell a Pokemon they have fed ten Candies from one they have
-- fed none, and has no way to know when to stop buying.
function M.describe(mon)
  if not mon then return false, { "It won't have", "any effect." } end
  local level = M.of(mon)
  return false, { monName(mon) .. "'s Dynamax",
                  ("Level is %d/%d."):format(level, M.MAX) }
end

function M.feed(mon)
  if not mon then return false, { "It won't have", "any effect." } end
  if not M.increase(mon) then
    return false, { monName(mon) .. "'s Dynamax",
                    ("Level is already %d!"):format(M.MAX) }
  end
  return true, { monName(mon) .. "'s Dynamax",
                 ("Level rose to %d!"):format(M.of(mon)) }
end

-- The two engines' own item-effect shapes, the same pair src/terashop.lua
-- spells out: Gen 1 hands { target, data } and wants `status, {lines}`, Gen 2
-- hands { item, mon, data } and wants { used, text }.  Written out here rather
-- than shared with that file because they are eight lines and genuinely
-- different contracts -- the same reason every gen2 branch in this mod is
-- duplicated rather than abstracted.
local function gen1(fn)
  return function(ctx)
    local ok, text = fn(ctx and ctx.target)
    return ok and "used" or "failed", text
  end
end

local function gen2(fn)
  return function(ctx)
    local ok, text = fn(ctx and ctx.mon)
    return { used = ok and true or false, text = table.concat(text, "\n") }
  end
end

-- `used` is TRUE for the Candy and false for the Band, which is the one place
-- these two differ mechanically: a Candy is consumed by working, and the
-- engines take it out of the bag on that flag.  A refused Candy -- a Pokemon
-- already at ten -- answers false and stays in the bag, so a misclick costs
-- nothing.
function M.install(mod, gen2Flag)
  mod.content.items:register(M.CANDY, {
    id = M.CANDY,
    name = "MAX CANDY",
    price = M.CANDY_PRICE,
    -- No bag byte on either game; data/stones.lua's header has why.
    needsTarget = true,
    tossable = true,
    fieldMenu = gen2Flag and "ITEMMENU_PARTY" or nil,
    battleMenu = gen2Flag and "ITEMMENU_NOUSE" or nil,
  })
  mod.content.item_effects:register(M.CANDY, gen2Flag and {
    needsTarget = true, action = "form", field = true, use = gen2(M.feed),
  } or {
    needsTarget = true, battle = false, field = true, use = gen1(M.feed),
  })

  -- The Dynamax Band gains a read verb exactly as the Tera Orb did, and
  -- src/keyitems.lua's blanket ITEMMENU_NOUSE is lifted for it alone: that
  -- refusal covers items with nothing to be used ON, and this one now has
  -- something.  The Key Stone and the Z-Ring keep it.
  local bandId = deps and deps.keyitems and deps.keyitems.DYNAMAX_BAND
  if not bandId then return end
  mod.content.items:patch(bandId, {
    needsTarget = true,
    fieldMenu = gen2Flag and "ITEMMENU_PARTY" or nil,
    battleMenu = gen2Flag and "ITEMMENU_NOUSE" or nil,
  })
  mod.content.item_effects:register(bandId, gen2Flag and {
    needsTarget = true, action = "form", field = true, use = gen2(M.describe),
  } or {
    needsTarget = true, battle = false, field = true, use = gen1(M.describe),
  })
end

return M
