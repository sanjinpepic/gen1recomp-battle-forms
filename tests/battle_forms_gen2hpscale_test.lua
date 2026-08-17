-- Dynamax's HP multiplier on Gold: the identical halved-damage mechanism
-- battle_forms_hpscale_test.lua proves exact for Gen 1 (M.scaleDamage,
-- M.displayedCurrent/Max) needs no Gen 2 branch of its own at all -- it never
-- reads `battle`, only `state` and a bare mon, so nothing here re-proves the
-- arithmetic.  What Gen 2 needs and this suite exists for: the `battle.damage`
-- ctx shape (a bare mon where Gen 1 hands a battler wrapper --
-- src/battlerof.lua's own header), the `battle.overlay` payload shape (Gold's
-- own UI class carries `.battle.player`, never a top-level `.player` the way
-- Gen 1's single combined object does), and the OHKO gate, which on Gold is a
-- `run` handler rather than Gen 1's separate `gate` field.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local HPScale = dofile(MOD .. "/src/hpscale.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")

-- ---------------------------------------------------------------------
-- battle.damage: src/battlerof.lua reads the mon off ctx.target on EITHER
-- shape -- a Gen 1 wrapper (`{ mon = ... }`) or a Gen 2 bare mon -- with no
-- `gen2` flag needed at the hook itself, because the discriminator is the
-- payload's own shape (battlerof.lua's own header).
-- ---------------------------------------------------------------------
do
  local hooks = {}
  local mod = {
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    content = { move_effects = { patch = function() end } },
  }
  local mon = { hp = 50, stats = { hp = 50 }, species = "PIDGEY" }
  local state = { mon = mon, carry = 0 }
  HPScale.install(mod, state, Battlerof)

  -- Gen 2 ctx.target IS the mon -- game/src/battle/gen2/Battle.lua:1137
  -- hands `target = defender` straight through with no wrapper at all.
  local dmg = hooks["battle.damage"](function() return 10, {} end,
    { target = mon })
  T.eq(dmg, 5, "a bare-mon ctx.target halves through battlerof.mon just like "
    .. "a Gen 1 wrapper's own .mon field")

  -- A bare mon that is NOT the Dynamaxed one passes through whole.
  local other = { hp = 50, stats = { hp = 50 }, species = "RATTATA" }
  local dmg2 = hooks["battle.damage"](function() return 10, {} end,
    { target = other })
  T.eq(dmg2, 10, "a different bare mon is not halved")

  -- The Gen 1 wrapper shape still works unchanged through the same hook.
  local dmg3 = hooks["battle.damage"](function() return 10, {} end,
    { target = { mon = mon } })
  T.eq(dmg3, 5, "and the Gen 1 wrapper shape still halves correctly")
end

-- ---------------------------------------------------------------------
-- The Gen 2 visibility gate: a pure decision, tested without love2d the same
-- way src/gen2menu.lua's own safeToOffer is -- "what can be proven without
-- love2d is the input decision, never the two draw functions" is this
-- codebase's own established line (src/menu.lua's suite, quoted again in
-- tests/battle_forms_zmovemenu_test.lua).
-- ---------------------------------------------------------------------
do
  local function uiBattle(opts)
    opts = opts or {}
    return {
      statusHUDVisible = function() return opts.visible ~= false end,
      showPlayerHud = opts.showPlayerHud ~= false,
      hudCleared = function(_, side) return opts.cleared == side end,
    }
  end

  T.eq(HPScale.gen2PlayerVisible(uiBattle()), true, "the ordinary case is visible")
  T.eq(HPScale.gen2PlayerVisible(uiBattle({ visible = false })), false,
    "statusHUDVisible() false hides the readout")
  T.eq(HPScale.gen2PlayerVisible(uiBattle({ showPlayerHud = false })), false,
    "showPlayerHud false (mid send-out) hides it too")
  T.eq(HPScale.gen2PlayerVisible(uiBattle({ cleared = "player" })), false,
    "hudCleared('player') true (an animation blanking the block) hides it")
  T.eq(HPScale.gen2PlayerVisible(nil), false, "no uiBattle at all is not visible")

  -- A method that raises (a stubbed screen missing one) is survivable rather
  -- than crashing the draw.
  local broken = { statusHUDVisible = function() error("boom") end,
                   showPlayerHud = true, hudCleared = function() return false end }
  T.eq(HPScale.gen2PlayerVisible(broken), false,
    "a raising statusHUDVisible is treated as not visible, not as a crash")
end

-- ---------------------------------------------------------------------
-- M.drawGen2: reads `uiBattle.battle.player`, never a top-level `.player`
-- (Gold's UI class has no such field -- only game/src/ui/gen2/BattleState.lua's
-- own `self.battle.player`), and paints nothing when the mon is not the
-- Dynamaxed one or the readout is not visible.
-- ---------------------------------------------------------------------
do
  local mon = { hp = 61, stats = { hp = 90 } }
  local state = { mon = mon, carry = 0 }
  local painted = {}
  local Font = { draw = function(text, x, y) painted[#painted + 1] =
    { text = text, x = x, y = y } end }

  local function visibleUi(player)
    return {
      battle = { player = player },
      statusHUDVisible = function() return true end,
      showPlayerHud = true,
      hudCleared = function() return false end,
    }
  end

  love = love or _G.love

  HPScale.drawGen2(state, visibleUi(mon), Font)
  T.eq(#painted, 1, "a live, visible Dynamax paints exactly once")
  T.eq(painted[1].text, "122/180", "the doubled current/max reading")

  painted = {}
  HPScale.drawGen2(state, visibleUi({ hp = 61, stats = { hp = 90 } }), Font)
  T.eq(#painted, 0, "a different mon (even identical numbers) paints nothing")

  painted = {}
  local hidden = visibleUi(mon)
  hidden.statusHUDVisible = function() return false end
  HPScale.drawGen2(state, hidden, Font)
  T.eq(#painted, 0, "an invisible HUD paints nothing even for the real mon")

  painted = {}
  HPScale.drawGen2(state, { battle = {} }, Font)
  T.eq(#painted, 0, "no player mon at all paints nothing")
end

-- ---------------------------------------------------------------------
-- The OHKO gate, Gold-shaped: a full `run` handler (Battle.MOVE_EFFECTS'
-- own signature) rather than Gen 1's separate `gate` field -- Fissure and
-- Horn Drill's own immunity/level/speed checks live INSIDE that one
-- function on Gen 2, so there is no separate gate to compose ahead of; this
-- wraps the whole `run` instead, delegating to the captured original for
-- everyone the Dynamax check does not refuse.
-- ---------------------------------------------------------------------
do
  local calls = {}
  local baseRun = function(battleSelf, attacker, defender, def, moveId, locked)
    calls[#calls + 1] = { attacker = attacker, defender = defender }
    return "base-ran"
  end
  local state = { mon = nil, carry = 0 }
  local wrapped = HPScale.ohkoRunGen2(state, baseRun)

  local target = { hp = 40 }
  local attacker = { hp = 100 }
  local emitted = {}
  local missed = 0
  local battleSelf = {
    markMissed = function() missed = missed + 1 end,
    emit = function(_, ev) emitted[#emitted + 1] = ev end,
  }

  -- Not Dynamaxed: delegates straight to the real base run, untouched.
  local out = wrapped(battleSelf, attacker, target, { id = "FISSURE" }, "FISSURE", false)
  T.eq(out, "base-ran", "a non-Dynamaxed target reaches the real base run")
  T.eq(#calls, 1, "exactly once")
  T.eq(#emitted, 0, "and nothing of this wrapper's own is emitted")
  T.eq(missed, 0, "nor is markMissed called by this wrapper")

  -- Dynamaxed target: refused outright, base run never called.
  state.mon = target
  local out2 = wrapped(battleSelf, attacker, target, { id = "FISSURE" }, "FISSURE", false)
  T.eq(out2, nil, "a Dynamaxed target's OHKO returns nothing -- refused")
  T.eq(#calls, 1, "the real base run was never reached this time")
  T.eq(missed, 1, "markMissed was called, matching the base run's own miss shape")
  T.eq(#emitted, 1, "and a message was emitted")
  T.eq(emitted[1].text, "But, it failed!", "the real games' own OHKO-vs-Dynamax line")

  -- A DIFFERENT target being Dynamaxed does not block this one.
  state.mon = { hp = 1, unrelated = true }
  local out3 = wrapped(battleSelf, attacker, target, { id = "FISSURE" }, "FISSURE", false)
  T.eq(out3, "base-ran", "some other mon being Dynamaxed does not refuse this target")

  -- Survives a battleSelf missing either method rather than raising.
  state.mon = target
  local ok = pcall(wrapped, {}, attacker, target, { id = "FISSURE" }, "FISSURE", false)
  T.check(ok, "a battleSelf with neither markMissed nor emit does not throw")
end

-- ---------------------------------------------------------------------
-- M.install, Gen 2: wires the EFFECT_OHKO patch only when told to, captures
-- the real vanilla run from game/src/battle/gen2/Battle.lua (not a stand-in),
-- and leaves Gen 1's own OHKO_EFFECT patch exactly as it always installs.
-- ---------------------------------------------------------------------
do
  local hooks, patches = {}, {}
  local logged = {}
  local mod = {
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    content = { move_effects = {
      patch = function(_, id, partial) patches[id] = partial end,
    } },
    log = { error = function(_, fmt, ...) logged[#logged + 1] = fmt:format(...) end },
  }
  local state = { mon = nil, carry = 0 }
  HPScale.install(mod, state, Battlerof, true)

  T.eq(type(patches.OHKO_EFFECT), "table",
    "Gen 1's own OHKO_EFFECT patch still installs unconditionally -- it is "
      .. "simply never dispatched on a Gen 2 boot, matching every other "
      .. "Gen-1-only registration in this mod")
  T.eq(type(patches.EFFECT_OHKO), "table", "and Gold's own EFFECT_OHKO is patched too")
  T.eq(type(patches.EFFECT_OHKO.run), "function", "with a replacement run handler")

  local RealBattle = require("src.battle.gen2.Battle")
  T.check(RealBattle.MOVE_EFFECTS.EFFECT_OHKO ~= nil,
    "precondition: the real engine class carries the vanilla handler this "
      .. "install call had to find")

  -- Driven against the REAL vanilla handler's own miss shape: a target at a
  -- higher level than the attacker fails the level check inside EFFECT_OHKO
  -- itself, so this proves delegation reaches the real function rather than
  -- a captured no-op.
  local defender = { hp = 40, level = 60 }
  local attacker = { hp = 100, level = 1 }
  local events = {}
  local battleSelf = setmetatable(
    { events = events }, { __index = RealBattle })
  state.mon = nil
  patches.EFFECT_OHKO.run(battleSelf, attacker, defender,
    { id = "FISSURE", accuracy = 30 }, "FISSURE", false)
  T.check(#events > 0, "the real vanilla EFFECT_OHKO ran and emitted its own message")

  events = {}
  battleSelf = setmetatable({ events = events }, { __index = RealBattle })
  state.mon = defender
  patches.EFFECT_OHKO.run(battleSelf, attacker, defender,
    { id = "FISSURE", accuracy = 30 }, "FISSURE", false)
  T.eq(#events, 1, "a Dynamaxed defender short-circuits to this wrapper's own "
    .. "one message instead")
  T.eq(events[1].text, "But, it failed!", "and it is the Dynamax refusal, not "
    .. "the level gate's own text")
end

do
  local hooks, patches = {}, {}
  local mod = {
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    content = { move_effects = {
      patch = function(_, id, partial) patches[id] = partial end,
    } },
  }
  local state = { mon = nil, carry = 0 }
  HPScale.install(mod, state, Battlerof, false)
  T.eq(patches.EFFECT_OHKO, nil,
    "gen2 = false never touches EFFECT_OHKO at all -- a class Gen 1 never "
      .. "dispatches through is not patched on that boot")
end

T.finish("battle_forms_gen2hpscale")
