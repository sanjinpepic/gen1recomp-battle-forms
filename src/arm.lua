-- Armed state, and the live battle the toggle needs in order to know who is
-- out.  battle.menu_auxiliary hands over only a data-only { kind }, so the
-- battle itself comes from battle.started and is dropped on battle.ended --
-- which is also what stops a reference outliving the battle that owned it.
--
-- `spent` is battle-scoped on purpose.  Mega evolution is once per battle per
-- TRAINER, not per Pokemon: having used it, the player cannot mega a second
-- team member, so this flag can never live on a mon.
--
-- The armed flag lives here rather than on the chosen move.  The move handed
-- to turn resolution is a live reference into the party mon's own move-slot
-- array, so a flag written there would land in save data.
local M = {}
local State = {}
State.__index = State

function M.new()
  return setmetatable({ battle = nil, armed = false, spent = false }, State)
end

function State:onBattleStarted(ev)
  self.battle = ev and ev.battle or nil
  self.armed = false
  self.spent = false
end

function State:onBattleEnded()
  self.battle = nil
  self.armed = false
  self.spent = false
end

function State:current() return self.battle end
function State:isArmed() return self.armed end
function State:used() return self.spent end

function State:toggle()
  if self.spent then return false end
  self.armed = not self.armed
  return self.armed
end

function State:consume()
  self.armed = false
  self.spent = true
end

return M
