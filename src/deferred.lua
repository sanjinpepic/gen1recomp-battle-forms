-- A hold for work that must not run at the moment it is scheduled.
--
-- WHY THIS EXISTS.  Gen 2's own Battle:resolveFaints resolves a knockout and
-- the battle's own end synchronously, inside the same call that computed the
-- turn -- and Battle:endBattle's Runtime.emit("battle.ended") fires there,
-- before the caller has even asked the battle for this turn's queued display
-- events (Battle:takeEvents), let alone before the UI has paced through them
-- one at a time.  src/resolve.lua's battle-end sweep reverts every
-- form-owning Pokemon in both parties the instant that event reaches it, so
-- a Pokemon that just delivered the killing blow while wearing a form (Blade
-- Forme foremost among them) reverts to its base picture and stats before
-- the hit that killed the target has even started animating -- the fight's
-- own outcome, told to the player ahead of the swing that decides it.
--
-- Gen 1 has no such gap and is untouched: BattleState:finish only raises
-- battle.ended once its own message/animation queue (self.queue,
-- self.afterQueue == "finish") has fully drained, so by the time a Gen 1
-- sweep runs, the presentation is already caught up.
--
-- THE FIX IS A HOLD, NOT A DIFFERENT EVENT.  No Runtime event or hook fires
-- once a Gen 2 battle's presentation has actually settled -- battle.ended is
-- the last one there is, win, lose or run -- so there is nothing later to
-- wait for.  What a mod DOES have is core.update (game/src/core/
-- PlatformHooks.lua), the engine's own per-frame tick, wrapped the same
-- composing way src/hpscale.lua already wraps battle.overlay.  A scheduled
-- settle keeps a Pokemon showing whatever it was mid-fight until enough real
-- frame time has passed for the kill's hit flash, HP-bar drain and faint
-- slide to have played out on a native boot, then applies exactly the same
-- revert the sweep would have run immediately -- late enough not to spoil
-- the swing, short enough that a player watching the victory fanfare never
-- notices the party settling a beat after the fight was already decided.
--
-- `dt` accumulates rather than reading a clock, which is what makes this
-- testable with no love.timer in the process at all: a test feeds M.tick(dt)
-- synthetic frame times exactly the way game/tests/modkit/cases/
-- platform_lifecycle_hooks.lua already drives PlatformHooks.update.
local M = {}

-- Comfortably longer than a native Gen 2 knockout's own hit flash, HP-bar
-- drain and faint slide/cry put together, and short enough that nobody
-- watching the victory music would read it as the party menu lagging.
M.HOLD_SECONDS = 1.5

local pending = {}
local installed = false

-- `fn` is the deferred work (a closure over whatever it needs, the same way
-- src/resolve.lua's own settle() closes over `battle` and `mon`); `hold`
-- defaults to M.HOLD_SECONDS so a caller only overrides it when it has a
-- reason to.
function M.schedule(fn, hold)
  pending[#pending + 1] = { fn = fn, remaining = hold or M.HOLD_SECONDS }
end

-- Ticked once per real frame from the core.update wrap below. Two passes
-- rather than one: the first only counts down and decides who is due, the
-- second removes exactly those and runs them -- so a scheduled fn that
-- itself calls M.schedule (a settle that turns around and re-arms something)
-- extends the NEXT tick's queue rather than being iterated mid-removal.
function M.tick(dt)
  if #pending == 0 then return end
  local step = dt or 0
  local kept, due = {}, nil
  for _, entry in ipairs(pending) do
    entry.remaining = entry.remaining - step
    if entry.remaining <= 0 then
      due = due or {}
      due[#due + 1] = entry
    else
      kept[#kept + 1] = entry
    end
  end
  pending = kept
  if due then
    for _, entry in ipairs(due) do entry.fn() end
  end
end

-- Test-only: drops every pending settle without running it, so one battle's
-- suite never bleeds a scheduled revert into the next. Nothing in the
-- shipped mod ever calls this -- a real boot's queue is meant to drain, not
-- be discarded.
function M.reset()
  pending = {}
end

-- Idempotent the way src/zmovemenu.lua's own install is: a second call sets
-- nothing new rather than stacking a second core.update wrap that would tick
-- every pending entry twice per frame.
function M.install(mod)
  if installed then return end
  installed = true
  mod.hooks:wrap("core.update", function(nextFn, game, dt)
    nextFn(game, dt)
    M.tick(dt)
  end)
end

return M
