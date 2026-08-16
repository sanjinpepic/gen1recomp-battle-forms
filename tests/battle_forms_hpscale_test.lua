-- Dynamax's HP multiplier: halved damage standing in for doubled HP, proven
-- exact rather than merely close, proven to never write mon.hp or
-- mon.stats.hp, proven off on every one of src/dynamax.lua's four teardown
-- paths, and the one gap battle.damage cannot close on its own -- OHKO moves,
-- which fail outright against a Dynamaxed target the way they do in the real
-- games.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local HPScale = dofile(MOD .. "/src/hpscale.lua")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")

Dynamax.bind({ forms = Forms, gigantamax = {}, keyitems = KeyItems,
               announce = Announce, battlerof = Battlerof })

-- ---------------------------------------------------------------------
-- The equivalence, proven by algebraic invariant across many sequences.
--
-- scaleDamage's own header claims 2*AppliedSum_n + carry_n == S_n for every
-- prefix of every sequence, where S_n is the running total of raw damage and
-- AppliedSum_n is the running total of what scaleDamage actually applied.
-- That is exactly "our halved model equals the doubled model's own total,
-- floored back down" -- checked at EVERY prefix below, not just the end, so
-- a mechanism that only agrees on the final total (and drifts through the
-- middle) would still be caught.
-- ---------------------------------------------------------------------
local SEQUENCES = {
  { 3, 3 },                          -- the module header's own worked example
  { 1, 1, 1, 1, 1 },                 -- the smallest amount that can drift
  { 7, 2, 9, 4, 1, 6, 3 },           -- mixed odd/even
  { 50, 51, 49, 50 },                -- larger, still mixed parity
  { 0, 5, 0, 3, 0 },                 -- a zero-damage hit must not eat a carry
  { 1 },                             -- a single odd hit: carry ends at 1
}

for _, seq in ipairs(SEQUENCES) do
  local state = { mon = "MON", carry = 0 }
  local appliedSum, rawSum = 0, 0
  for i, d in ipairs(seq) do
    local applied = HPScale.scaleDamage(state, "MON", d)
    appliedSum = appliedSum + applied
    rawSum = rawSum + d
    T.eq(2 * appliedSum + state.carry, rawSum,
      ("prefix %d of {%s}: 2*applied+carry tracks the raw total exactly")
        :format(i, table.concat(seq, ",")))
  end
end

-- ---------------------------------------------------------------------
-- The faint boundary, in the task's own words: a mon taking N hits while
-- Dynamaxed must survive exactly as long as mainline's doubled-HP model
-- predicts.  Three totals bracketing the threshold (2C-1, 2C, 2C+1), split
-- across hit counts and parities so the boundary is not just tested at a
-- single convenient split.
-- ---------------------------------------------------------------------
local function survives(startHp, hits)
  local state = { mon = "MON", carry = 0 }
  local hp = startHp
  for _, d in ipairs(hits) do
    hp = hp - HPScale.scaleDamage(state, "MON", d)
  end
  return hp > 0
end

local function mainlineSurvives(startHp, hits)
  local doubled = 2 * startHp
  for _, d in ipairs(hits) do doubled = doubled - d end
  return doubled > 0
end

local BOUNDARY_CASES = {
  { hp = 50, hits = { 33, 33, 33 } },   -- sum 99 = 2*50-1: mainline survives
  { hp = 50, hits = { 33, 33, 34 } },   -- sum 100 = 2*50: mainline faints
  { hp = 50, hits = { 34, 33, 34 } },   -- sum 101 = 2*50+1: mainline faints
  { hp = 77, hits = { 51, 51, 51 } },   -- odd max HP, sum 153 = 2*77-1
  { hp = 77, hits = { 51, 51, 52 } },   -- sum 154 = 2*77
  { hp = 1, hits = { 1 } },             -- smallest possible, sum 2 = 2*1
  { hp = 1, hits = {} },                -- no hits at all: nobody faints
}

for _, case in ipairs(BOUNDARY_CASES) do
  T.eq(survives(case.hp, case.hits), mainlineSurvives(case.hp, case.hits),
    ("hp=%d hits={%s}: our survival matches the doubled model's")
      :format(case.hp, table.concat(case.hits, ",")))
end

-- ---------------------------------------------------------------------
-- scaleDamage never writes mon.hp or mon.stats.hp -- it does not even
-- receive the mon's stat table, only the number Damage.compute returned.
-- ---------------------------------------------------------------------
do
  local mon = { hp = 120, stats = { hp = 150, attack = 84 }, species = "X" }
  local statsTable = mon.stats
  local state = { mon = mon, carry = 0 }
  for _, d in ipairs({ 5, 12, 3, 40, 1 }) do
    HPScale.scaleDamage(state, mon, d)
  end
  T.eq(mon.hp, 120, "current HP is untouched by any number of halvings")
  T.eq(mon.stats, statsTable, "the stat table is still the same table")
  T.eq(mon.stats.hp, 150, "and max HP inside it is untouched")
end

-- Damage against a mon that is NOT the Dynamaxed one passes through whole,
-- and never even reads state.carry.
do
  local state = { mon = "DYNAMAXED", carry = 7 }
  T.eq(HPScale.scaleDamage(state, "SOME_OTHER_MON", 9), 9,
    "a mon that is not state.mon gets the raw number back")
  T.eq(HPScale.scaleDamage(state, nil, 9), 9,
    "a nil mon (no target.mon to compare against) is also passed through")
  T.eq(state.carry, 7, "and the untouched carry is not disturbed either way")
end

-- ---------------------------------------------------------------------
-- The display numbers: doubled, carry-corrected, and nil for anyone who is
-- not the Dynamaxed mon (the overlay's own signal to paint nothing).
-- ---------------------------------------------------------------------
do
  local mon = { hp = 61, stats = { hp = 90 } }
  local state = { mon = mon, carry = 0 }
  T.eq(HPScale.displayedCurrent(state, mon), 122, "2x current HP when carry is zero")
  T.eq(HPScale.displayedMax(state, mon), 180, "2x max HP")

  state.carry = 1
  T.eq(HPScale.displayedCurrent(state, mon), 121,
    "a pending carry corrects the doubled reading down by exactly one")

  local other = { hp = 61, stats = { hp = 90 } }
  T.eq(HPScale.displayedCurrent(state, other), nil,
    "a different mon (even with identical numbers) shows nothing")
  T.eq(HPScale.displayedMax(state, other), nil, "on both readings")
  T.eq(HPScale.displayedCurrent(state, nil), nil, "and nil is not a mon either")
end

-- ---------------------------------------------------------------------
-- Every teardown path src/dynamax.lua already proves for mon/turns/form
-- also turns the multiplier off -- read through scaleDamage's own
-- behaviour (raw damage comes back unhalved), not through the field name,
-- since the field is this module's implementation detail and the behaviour
-- is the contract.
-- ---------------------------------------------------------------------
local function makeBattle(mon)
  local said = {}
  return {
    data = { pokemon = { PIDGEY = { baseStats = { hp = 40, attack = 45,
                                                   defense = 40, speed = 56,
                                                   special = 35 },
                                    types = { "NORMAL", "FLYING" } } } },
    said = said,
    player = { isPlayer = true, mon = mon, name = mon.nickname,
               curStats = mon.stats, curTypes = { "NORMAL", "FLYING" } },
    game = { save = { party = { mon },
                      inventory = { [KeyItems.DYNAMAX_BAND] = 1 } } },
    enemyParty = {},
    say = function(_, line) said[#said + 1] = line end,
    sayNext = function(_, line) said[#said + 1] = line end,
    animNext = function() end,
    animationsOn = function() return false end,
  }
end

local function newMon()
  return { species = "PIDGEY", level = 50, nickname = "BIRD",
           dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
           statExp = {}, moves = { { id = "TACKLE", pp = 35 } },
           stats = { hp = 100, attack = 45, defense = 40, speed = 56, special = 35 },
           hp = 80 }
end

-- Built directly against Dynamax's real state/entry pair for each path,
-- mirroring tests/battle_forms_dynamax_test.lua's own fixtures.
local function activated()
  local mon = newMon()
  local battle = makeBattle(mon)
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  entry.activate(battle)
  return state, battle, mon
end

-- Every path below pins TWO things: the behavioural check (scaleDamage
-- hands back the raw number once the Dynamax is over) and a direct read of
-- state.carry itself.  The two are not redundant -- a stale nonzero carry
-- left behind by a teardown that clears state.mon but not state.carry is
-- invisible to the behavioural check alone, because scaleDamage's own
-- identity guard (state.mon ~= mon) already short-circuits before the carry
-- is ever consulted.  It is only a live bug the day that guard changes, but
-- a correctness invariant that depends on a SEPARATE piece of code never
-- being touched is exactly the kind of thing this suite exists to pin down
-- directly rather than leave to that other code's discipline.

do -- turn expiry
  local state, battle, mon = activated()
  T.eq(HPScale.scaleDamage(state, mon, 3), 1, "halving is live mid-Dynamax") -- carry now 1
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.mon, nil, "precondition: the clock ran out")
  T.eq(state.carry, 0, "and the pending carry went with it")
  T.eq(HPScale.scaleDamage(state, mon, 10), 10,
    "and halving is off once the three turns are spent")
end

do -- switching out
  local state, battle, mon = activated()
  HPScale.scaleDamage(state, mon, 3) -- leaves carry = 1
  local outgoing = battle.player
  local incoming = { isPlayer = true, mon = newMon(), name = "OTHER" }
  battle.player = incoming
  Dynamax.onBattlerSwitched(state, { battle = battle, battler = incoming,
                                     previous = outgoing })
  T.eq(state.carry, 0, "switching the Dynamaxed mon out clears the carry")
  T.eq(HPScale.scaleDamage(state, mon, 10), 10,
    "switching the Dynamaxed mon out turns halving off")
end

do -- fainting
  local state, battle, mon = activated()
  HPScale.scaleDamage(state, mon, 3) -- leaves carry = 1
  mon.hp = 0
  Dynamax.onFainted(state, { battle = battle, battler = battle.player })
  T.eq(state.carry, 0, "fainting clears the pending carry, not just state.mon")
  T.eq(HPScale.scaleDamage(state, mon, 10), 10,
    "fainting turns halving off")
end

do -- battle end (the forget() path, not finish())
  local state, battle, mon = activated()
  HPScale.scaleDamage(state, mon, 3) -- leaves carry = 1
  Dynamax.onBattleEnded(state)
  T.eq(state.carry, 0, "the battle ending clears the carry, not just state.mon")
  T.eq(HPScale.scaleDamage(state, mon, 10), 10,
    "the battle ending turns halving off")
end

do -- battle start clears a record left behind by anything that went wrong
  local state = Dynamax.new()
  state.mon, state.carry = { species = "GHOST" }, 1
  Dynamax.onBattleStarted(state)
  T.eq(state.carry, 0, "a fresh battle start clears a stale carry too")
  T.eq(HPScale.scaleDamage(state, state.mon, 10), 10,
    "a fresh battle start carries no stale multiplier forward")
end

-- ---------------------------------------------------------------------
-- The OHKO gate: blocks a Dynamaxed target outright, ahead of and without
-- needing the base gate's own immunity/speed checks; falls through to that
-- REAL base gate -- required straight from the engine, not stubbed -- for
-- everyone else.
-- ---------------------------------------------------------------------
local TypeChart = require("src.battle.TypeChart")
TypeChart.load({ type_chart = { matchups = {}, types = {} } }) -- neutral chart: never immune

local function ohkoCtx(userSpeed, targetSpeed, targetMon)
  return {
    battle = { data = {} },
    move = { type = "NORMAL" },
    user = { curStats = { speed = userSpeed }, stages = {}, mon = { status = nil } },
    target = { curStats = { speed = targetSpeed }, stages = {},
              curTypes = { "NORMAL" }, mon = targetMon },
  }
end

do
  local state = { mon = nil, carry = 0 }
  local target = { hp = 100 }

  -- Not Dynamaxed, user faster: the base gate's own two checks pass through.
  local ok, msg = HPScale.ohkoGate(state, ohkoCtx(100, 50, target))
  T.eq(ok, true, "a faster user against a non-Dynamaxed target still succeeds")
  T.eq(msg, nil, "with no failure message")

  -- Not Dynamaxed, user slower: the REAL base gate's speed check still fires,
  -- proving delegation reaches the engine's own logic and not a stand-in.
  local ok2, msg2 = HPScale.ohkoGate(state, ohkoCtx(50, 100, target))
  T.eq(ok2, false, "a slower user still fails the base gate's own speed check")
  T.check(msg2 ~= nil, "with the base gate's own failure message")

  -- Dynamaxed target: fails regardless of speed, and does not even need a
  -- real type/user setup to prove it -- the Dynamax check runs first.
  state.mon = target
  local ok3, msg3 = HPScale.ohkoGate(state, ohkoCtx(999, 1, target))
  T.eq(ok3, false, "a Dynamaxed target refuses an OHKO even when faster")
  T.check(msg3 ~= nil, "and says so rather than failing silently")

  -- A DIFFERENT target being Dynamaxed does not block this one.
  state.mon = { hp = 1, unrelated = true }
  local ok4 = HPScale.ohkoGate(state, ohkoCtx(100, 50, target))
  T.eq(ok4, true, "some other mon being Dynamaxed does not block this target")
end

-- ---------------------------------------------------------------------
-- M.install wires exactly what it claims to, through a stand-in `mod` that
-- captures each registration the way tests/battle_forms_maxmoves_test.lua's
-- stubMod does -- proving the WIRING, not just the math functions above.
-- ---------------------------------------------------------------------
do
  local hooks, patches = {}, {}
  local mod = {
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    content = { move_effects = {
      patch = function(_, id, partial) patches[id] = partial end,
    } },
  }
  local state = { mon = nil, carry = 0 }
  HPScale.install(mod, state)

  T.eq(type(hooks["battle.damage"]), "function", "battle.damage is wrapped")
  T.eq(type(hooks["battle.overlay"]), "function", "battle.overlay is wrapped")
  T.eq(type(patches.OHKO_EFFECT), "table", "OHKO_EFFECT is patched")
  T.eq(type(patches.OHKO_EFFECT.gate), "function", "with a replacement gate")

  -- battle.damage: nextFn's result is what gets halved, not the raw ctx.
  local mon = { hp = 50, stats = { hp = 50 } }
  state.mon = mon
  local nextCalls = 0
  local dmg, info = hooks["battle.damage"](function(ctx)
    nextCalls = nextCalls + 1
    T.eq(ctx.target.mon, mon, "the hook hands the real ctx through to nextFn")
    return 10, { crit = true }
  end, { target = { mon = mon } })
  T.eq(nextCalls, 1, "nextFn runs exactly once")
  T.eq(dmg, 5, "and the wrapped damage is halved")
  T.eq(info.crit, true, "with the downstream info table passed through untouched")

  -- battle.overlay: nextFn always runs, even with nothing to draw (no
  -- Dynamax live) and even though the draw call itself needs love.graphics,
  -- which tests.modkit's love stub provides.
  state.mon = nil
  local overlayNextCalls = 0
  hooks["battle.overlay"](function() overlayNextCalls = overlayNextCalls + 1 end,
    { player = nil })
  T.eq(overlayNextCalls, 1, "battle.overlay always calls nextFn, chain or no chain")

  -- OHKO_EFFECT's patched gate, driven the same way BattleState:effectRecord
  -- would find it after the registry merge -- fails against state.mon.
  local target = { hp = 30 }
  state.mon = target
  local gok, gmsg = patches.OHKO_EFFECT.gate(ohkoCtx(999, 1, target))
  T.eq(gok, false, "the installed gate blocks a Dynamaxed target")
  T.check(gmsg ~= nil, "and names a reason")
end

T.finish("battle_forms_hpscale")
