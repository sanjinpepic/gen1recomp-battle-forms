-- src/deferred.lua: a hold for work that must not run the instant it is
-- scheduled (src/resolve.lua's own Gen 2 battle-end sweep, so a form-owning
-- Pokemon that just delivered the killing blow does not revert to its base
-- picture before the hit that killed the target has animated).
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Deferred = dofile(MOD .. "/src/deferred.lua")
local PlatformHooks = require("src.core.PlatformHooks")

--------------------------------------------------------------------------
-- schedule/tick: the hold itself
--------------------------------------------------------------------------

do
  Deferred.reset()
  local ran = 0
  Deferred.schedule(function() ran = ran + 1 end, 1.0)
  Deferred.tick(0.4)
  T.eq(ran, 0, "not yet due after less than the hold has elapsed")
  Deferred.tick(0.4)
  T.eq(ran, 0, "still not due -- 0.8s of a 1.0s hold")
  Deferred.tick(0.3)
  T.eq(ran, 1, "runs once the accumulated dt clears the hold")
  Deferred.tick(10)
  T.eq(ran, 1, "and never runs a second time for the same schedule")
end

do
  Deferred.reset()
  local order = {}
  Deferred.schedule(function() order[#order + 1] = "a" end, 0.5)
  Deferred.schedule(function() order[#order + 1] = "b" end, 0.5)
  Deferred.tick(0.5)
  T.eq(#order, 2, "two entries due on the same tick both run")
end

do
  Deferred.reset()
  local ran = false
  Deferred.schedule(function() ran = true end)
  T.check(Deferred.HOLD_SECONDS > 0,
    "the default hold is a real, positive duration")
  Deferred.tick(Deferred.HOLD_SECONDS - 0.01)
  T.eq(ran, false, "the default hold is honoured when no hold is passed")
  Deferred.tick(0.02)
  T.eq(ran, true, "and it does eventually run")
end

-- A schedule made from inside a running tick (a settle that turns around and
-- re-arms something) must not be iterated mid-removal -- it lands on the
-- NEXT tick's queue, not skipped and not double-run.
do
  Deferred.reset()
  local reentrant = 0
  Deferred.schedule(function()
    reentrant = reentrant + 1
    Deferred.schedule(function() reentrant = reentrant + 10 end, 0)
  end, 0)
  Deferred.tick(0)
  T.eq(reentrant, 1, "the re-entrant schedule is not run on the same tick")
  Deferred.tick(0)
  T.eq(reentrant, 11, "but is run on the next one")
end

T.eq(Deferred.HOLD_SECONDS >= 1 and Deferred.HOLD_SECONDS <= 3, true,
  "the hold is on the order of a couple of seconds -- long enough to clear a "
    .. "knockout's hit flash, HP-bar drain and faint slide, short enough "
    .. "that a player watching the victory fanfare never notices it")

--------------------------------------------------------------------------
-- install: wired to the real core.update hook, idempotently
--------------------------------------------------------------------------

do
  Deferred.reset()
  local Hooks = require("src.mods.Hooks")
  local Events = require("src.mods.Events")
  local Runtime = require("src.mods.Runtime")
  -- core.update is read off the process-wide Runtime singleton
  -- (game/src/mods/Runtime.lua), which is what PlatformHooks.update's own
  -- ModRuntime.call consults -- installing a bare Hooks instance onto `mod`
  -- without also pointing Runtime at it would wrap a chain nothing reads.
  local mod = { hooks = Hooks.new() }
  Runtime.install(Events.new(), mod.hooks, {})
  Deferred.install(mod)
  local calls = 0
  local fakeGame = { update = function() calls = calls + 1 end }

  local ran = false
  Deferred.schedule(function() ran = true end, 0.5)
  PlatformHooks.update(fakeGame, 0.3)
  T.eq(calls, 1, "vanilla Game:update still runs through the wrap")
  T.eq(ran, false, "not yet due")
  PlatformHooks.update(fakeGame, 0.3)
  T.eq(ran, true, "due after enough real frames have ticked through core.update")

  -- Idempotent: installing again must not double-wrap core.update, or every
  -- pending entry would tick twice as fast as its own hold intends.
  Deferred.install(mod)
  Deferred.reset()
  local ticks = 0
  local counting = { fn = function() ticks = ticks + 1 end, remaining = 0.1 }
  Deferred.schedule(counting.fn, 0.1)
  PlatformHooks.update(fakeGame, 0.1)
  T.eq(ticks, 1, "a second install call did not stack a second core.update wrap")
end

T.finish("battle_forms_deferred")
