-- Picking up a battle that was already under way.
--
-- Everything manual keys off the live battle src/arm.lua caches, and that
-- cache is filled from battle.started -- an event that has already been and
-- gone by the time a player enables the mod from the mod manager mid-fight.
-- The armed state then reads `none` for the rest of that battle: no MEGA cell,
-- and no primal reversion for a mon that was sent out before the mod existed.
-- It is what a player reports as "it worked one boot and now doesn't", and a
-- trace of a real install caught it exactly -- the mod arriving at a battle
-- already at phase=messages, then every menu decision reading armState=none
-- until the battle ended.
--
-- The battle is reachable without the event.  BattleState.update is wrapped
-- already (src/menu.lua) and is handed the live battle as `self` on every
-- frame, so adoption needs no new patch, no new subscription and no clock of
-- its own: it is one question asked on a seam that was already running, ahead
-- of everything on that seam that reads the arm state.
--
-- battle.started stays the primary path.  Adoption is keyed on the arm state
-- not already holding this exact battle, so a normal boot adopts nothing at
-- all -- the event fires during BattleState:enter and every frame afterwards
-- answers "already ours" in one comparison.  That same comparison is what
-- makes adopting twice a no-op, which matters more than it looks: the second
-- adoption would be the one to hand the trainer a second mega.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- A BattleState exists before it has sides -- the constructor runs, the intro
-- slides, and battle.started only fires once the send-out queue is built -- so
-- a battle that cannot answer these is one the event is about to cover
-- anyway.
local function live(battle)
  return type(battle) == "table" and battle.data ~= nil
    and (battle.player ~= nil or battle.enemy ~= nil)
end

-- Marked on the battle instance rather than remembered in this module: a
-- module-level reference to a finished battle would outlive it, which is the
-- exact thing src/arm.lua drops its own cache to avoid.  The engine pops the
-- battle off the stack before it emits battle.ended, so in practice no frame
-- follows -- but re-adopting a finished battle would re-apply a form to a
-- party mon src/resolve.lua has just swept clean, and that one writes into the
-- save.
function M.onBattleEnded(ev)
  local battle = ev and ev.battle
  if type(battle) == "table" then battle._battleFormsOver = true end
end

-- What adoption re-runs, and what it deliberately leaves lost.
--
-- The two send-out handlers are asked again, by hand, for the mons already on
-- the field.  Both are RE-DERIVATIONS rather than replays: a mon holding the
-- Red Orb simply is Primal Groudon while it is out, and an HP-driven
-- conditional row is a reading of the HP bar -- both are as true now as they
-- were at the send-out that happened without us, so applying them late is not
-- catching up on a missed event, it is answering a question that was never
-- asked.  Primal announces when it lands, because a mid-battle sprite and stat
-- change with nothing said is the defect this mod just finished fixing.
--
-- Nothing else is recovered, and conditional.onBattleStarted is what draws
-- that line for free: an event-triggered row is only re-applied to a mon that
-- already wears it, and a mon adopted mid-battle wears nothing.  So an
-- Aegislash that attacked before the mod loaded stays in its shield form until
-- its next move, a Mimikyu whose disguise should already be broken arrives
-- whole, and Morpeko resumes alternating from the next end of turn.  Those
-- triggers are events, not states; the mod was not there to see them and
-- inventing them after the fact would be fiction, not recovery.
--
-- The turn's mega is lost the same way and for a better reason: adoption never
-- touches the spent flags, so the battle's one mega is still unspent and the
-- cell appears at the next command menu -- but a player who has already chosen
-- this turn's action does not get to arm it retroactively.
function M.consider(battle)
  if not live(battle) or battle._battleFormsOver then return false end
  if not deps.state:adopt(battle) then return false end

  if deps.diag then
    pcall(deps.diag.adopted, battle)
  end

  -- Guarded separately, for the reason main.lua guards its event handlers
  -- separately: one of these throwing must not cancel the other, and this one
  -- runs from inside a wrapped engine function where a throw would take the
  -- frame's update with it.
  local ev = { battle = battle, source = "adopt" }
  local ok, err = pcall(deps.primal.onBattleStarted, ev)
  if not ok and deps.diag then deps.diag.fault("adopt.primal", err) end
  ok, err = pcall(deps.conditional.onBattleStarted, ev)
  if not ok and deps.diag then deps.diag.fault("adopt.conditional", err) end
  return true
end

return M
