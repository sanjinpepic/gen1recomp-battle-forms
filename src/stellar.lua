-- Stellar: the Tera type that is not a type.
--
-- Every other Tera type in this mod works by replacing what the Pokemon IS --
-- src/tera.lua assigns a one-element curTypes on Gen 1, mon.formTypes on Gold,
-- and the type chart does the rest.  Stellar cannot work that way and must not
-- be made to: it is not in the chart, it has no matchup row, nothing is weak to
-- it and it resists nothing.  Registering a STELLAR type record to make it fit
-- the existing machinery would invent eighteen matchups nobody asked for and
-- would drag National Dex into a change that belongs entirely here.
--
-- SO IT LEAVES THE TYPING ALONE.  A Stellar-terastallized Charizard is still
-- Fire/Flying: it still takes quadruple damage from Rock, still resists Grass,
-- still gets its ordinary STAB.  What changes is a damage multiplier, and only
-- that -- which is why this is a `battle.damage` hook and not a form, a type
-- override or anything src/forms.lua knows about.
--
-- WHAT THE MULTIPLIER IS.  Once per move TYPE, per Terastallization:
--
--   * a move the Pokemon already has STAB on lands at x2 instead of x1.5
--   * a move it does not lands at x1.2 instead of x1
--
-- and every later move of that same type is ordinary again.  So a Stellar
-- Charizard's first Flamethrower is x2, its second is the usual x1.5, and its
-- first Earthquake is x1.2 whether or not the Flamethrower happened.  The
-- boost is per type rather than per move, which is the whole texture of it: it
-- rewards a varied moveset once rather than one move repeatedly.
--
-- WHY THE FACTOR IS 4/3 AND NOT 2.  The engines apply STAB themselves, inside
-- the calculation this hook wraps (src/battle/Damage.lua's own `d * 3 / 2`,
-- src/battle/gen2/Damage.lua's `damage * 15 / 10`).  By the time the number
-- reaches here the x1.5 has already happened, so lifting it to x2 means
-- multiplying what came back by 2/1.5.  Multiplying by 2 would give x3 and
-- would look, from a chair, exactly like a Stellar Pokemon hitting three times
-- too hard for reasons nobody could find.
--
-- ROUNDING.  This scales the finished number rather than reaching into the
-- calculation, so it rounds once at the end where the engine rounds at each
-- step.  A handful of points either way against a faithful reimplementation of
-- two different damage formulas, one of which is deliberately bug-compatible
-- with a 1996 cartridge -- the trade is not close.
--
-- HOW A POKEMON GETS IT.  Fifty Stellar Shards, the same as any other type
-- (src/terashop.lua).  The shard is registered here rather than in
-- src/terashards.lua's loop because that loop is driven by the type chart and
-- this type is deliberately not in it -- an exception in the data would have
-- had to be an exception in the chart.
--
-- TERA BLAST does not become Stellar-typed here.  In the real games it does,
-- and doing it would mean registering a STELLAR move variant whose type the
-- chart cannot resolve -- src/tera.lua's own install already refuses exactly
-- that, out loud, for DARK on a Red-era chart.  A Stellar Pokemon's Tera Blast
-- stays Normal and takes the x1.2 or x2 above like any other move, which is
-- the faithful part of the interaction without the part that needs a type row.
local M = {}

M.TYPE = "STELLAR"

-- Shown wherever a type name is printed.  Not read off the chart the way every
-- other type's name is, because there is no chart record to read it from -- see
-- the header.
M.NAME = "STELLAR"

-- Dearer than the eighteen ordinary shards (200) because it is the one type no
-- Pokemon can be born with and the only one that boosts every move rather than
-- changing what the Pokemon is.  Fifty is still the count; the price is where
-- the difference sits, so the shard economy has exactly one rule.
M.PRICE = 1000

local deps = nil

function M.bind(modules) deps = modules end

-- One record, per battle, the shape src/tera.lua's own state keeps and for the
-- same reason: only the player's side reaches the menu and there is one
-- Terastallization a battle, so there is never a second to track.
--
-- `spent` is keyed by move type.  It lives here rather than on the mon because
-- it is battle state -- a Pokemon that switches out and back has not got its
-- boosts back, and a Pokemon in the next battle has.
-- KEYED BY POKEMON, not a single slot, and the comment above used to say why
-- it did not need to be: "only the player's side reaches the menu and there is
-- one Terastallization a battle". Enemy trainers now terastallize too
-- (src/trainerai.lua), so both sides can be Stellar at once -- and a single
-- slot meant the second one silently took the first one's boosts away.
--
-- Weak keys: a Pokemon that never gets an explicit clear -- a battle that
-- ended badly, a mon released from the party -- must not be held alive by this
-- table for the rest of the process.
local states = setmetatable({}, { __mode = "k" })

function M.begin(mon)
  if mon == nil then return end
  states[mon] = {}
end

--- Clears one Pokemon's Stellar, or EVERY one when called with nothing.
---
--- Both arms are used and they are not interchangeable: a teardown clears the
--- mon it is tearing down, while battle start clears the lot, because a state
--- left standing by a crash or an adopted battle belongs to nobody and must
--- not follow anyone into the next fight.
function M.clear(mon)
  if mon == nil then
    for key in pairs(states) do states[key] = nil end
    return
  end
  states[mon] = nil
end

function M.active(mon)
  if mon ~= nil then return states[mon] ~= nil end
  return next(states) ~= nil
end

-- Whether this Pokemon would get ordinary STAB on this move type.
--
-- Reads the Pokemon's OWN types, which under Stellar are still its real ones --
-- that is the point of Stellar -- so this asks the battler the engine built
-- rather than anything this mod wrote.
local function hasStab(user, moveType)
  local types = user and (user.curTypes or user.formTypes)
  if type(types) ~= "table" then return false end
  for _, t in ipairs(types) do
    if t == moveType then return true end
  end
  return false
end

-- The factor to scale finished damage by, or 1 for "leave it alone".
--
-- Marks the type spent as a side effect, which is deliberate rather than
-- sloppy: the boost is consumed by being used, and a caller that asked and then
-- decided not to apply it would be a caller that had already dealt the damage.
-- The one call site is the hook below.
function M.factor(user, mon, move)
  local spent = mon ~= nil and states[mon] or nil
  if not spent then return 1 end
  if type(move) ~= "table" then return 1 end
  local moveType = move.type
  if type(moveType) ~= "string" or moveType == "" then return 1 end
  -- A move that deals no damage has nothing to boost, and spending the type's
  -- one boost on a status move would be a trap nobody could see.
  if not move.power or move.power <= 0 then return 1 end
  if spent[moveType] then return 1 end

  spent[moveType] = true
  -- 2/1.5 where the engine already applied STAB; 1.2 where it applied nothing.
  return hasStab(user, moveType) and (4 / 3) or 1.2
end

-- Registers the one shard the chart-driven loop cannot.
function M.installShard(mod)
  local itemId = deps.terashards.idFor(M.TYPE)
  mod.content.items:register(itemId, {
    id = itemId,
    name = M.NAME .. " SHARD",
    price = M.PRICE,
    -- No bag byte, on either game: data/stones.lua's header covers Gold, and
    -- src/terashards.lua's covers why none of the shards carry one.
    tossable = true,
  })
  return itemId
end

-- battle.damage is a wrap-and-delegate chain on BOTH engines
-- (src/battle/BattleState.lua's computeDamage, src/battle/gen2/Battle.lua's own
-- call at :1134), so this is one installer rather than a Gen 1 and a Gen 2 one
-- -- the only difference is which battler object arrives, and neither is read
-- for anything but its types.
--
-- Delegates FIRST and scales what comes back, so every other mod's own
-- battle.damage link runs whether or not this one does anything, and a Stellar
-- Pokemon composes with them rather than replacing them.
-- Argument order is (nextFn, ctx), the shape mod.hooks:wrap passes and the same
-- one src/hpscale.lua's own battle.damage link takes.
function M.install(mod)
  mod.hooks:wrap("battle.damage", function(nextFn, ctx)
    local damage, info = nextFn(ctx)
    if type(damage) ~= "number" or damage <= 0 then return damage, info end
    local user = ctx and ctx.user
    local mon = deps.battlerof and deps.battlerof.mon(user)
      or (user and user.mon)
    local factor = M.factor(user, mon, ctx and ctx.move)
    if factor == 1 then return damage, info end
    return math.floor(damage * factor), info
  end)
end

return M
