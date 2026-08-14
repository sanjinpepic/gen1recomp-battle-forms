-- Which manual transformation the cell is showing, which one is armed, which
-- have already been used, and the live battle the cell needs in order to know
-- who is out.  battle.menu_auxiliary hands over only a data-only { kind }, so
-- the battle itself comes from battle.started and is dropped on battle.ended
-- -- which is also what stops a reference outliving the battle that owned it.
--
-- `spent` is battle-scoped and keyed by transformation id, both on purpose.
-- Mega evolution is once per battle per TRAINER, not per Pokemon: having used
-- it, the player cannot mega a second team member, so the flag can never live
-- on a mon.  And every mechanic that will sit beside it carries a limit of its
-- own, so arming a mega must not spend a Dynamax -- which one keyless boolean
-- could not express.
--
-- The armed transformation is always the selected one.  The cell shows exactly
-- one label at a time, so an armed flag sitting behind a label the player
-- cannot see is a change that fires by surprise; selecting away therefore
-- disarms.  With a single transformation registered there is nothing to select
-- away to and the rule never fires.
--
-- The armed flag lives here rather than on the chosen move.  The move handed
-- to turn resolution is a live reference into the party mon's own move-slot
-- array, so a flag written there would land in save data.
local M = {}
local State = {}
State.__index = State

function M.new()
  return setmetatable({ battle = nil, armedId = nil, selectedId = nil,
                        spent = {} }, State)
end

function State:onBattleStarted(ev)
  self.battle = ev and ev.battle or nil
  self.armedId = nil
  self.selectedId = nil
  self.spent = {}
end

function State:onBattleEnded()
  self.battle = nil
  self.armedId = nil
  self.selectedId = nil
  self.spent = {}
end

function State:current() return self.battle end
function State:isArmed() return self.armedId ~= nil end
function State:armed() return self.armedId end
function State:selected() return self.selectedId end
function State:used(id) return self.spent[id] == true end

function State:select(id)
  if self.selectedId == id then return end
  self.selectedId = id
  self.armedId = nil
end

function State:toggle(id)
  if type(id) ~= "string" or self.spent[id] then return false end
  self.selectedId = id
  self.armedId = self.armedId ~= id and id or nil
  return self.armedId == id
end

function State:consume(id)
  self.spent[id] = true
  if self.armedId == id then self.armedId = nil end
end

return M
