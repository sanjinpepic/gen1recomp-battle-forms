-- Which manual transformation the cell is showing, which one is armed, which
-- have already been used, and the live battle the cell needs in order to know
-- who is out.  battle.menu_auxiliary hands over only a data-only { kind }, so
-- the battle itself comes from battle.started and is dropped on battle.ended
-- -- which is also what stops a reference outliving the battle that owned it.
--
-- `spent` is battle-scoped and keyed by transformation id, both on purpose.
-- Mega evolution is once per battle per TRAINER, not per Pokemon: having used
-- it, the player cannot mega a second team member, so the flag can never live
-- on a mon.  The key is what keeps one mechanic's limit from being another's:
-- a spent mega stays spent on its own terms whatever else the battle does.
--
-- `spentAny` is the coarser rule laid over those: the mainline games give a
-- trainer ONE manual transformation per battle across all of them, the way
-- Sun/Moon ruled Z-Moves against Mega Evolution, so megaing costs the battle's
-- Dynamax as well as its mega.  Recorded here and enforced in src/overlay.lua,
-- where every other reason the cell is absent is already decided -- see that
-- file for why it is decided there and not here as well.
--
-- Two flags rather than one because they answer different questions and a
-- mechanic exempt from the second would still owe the first.
--
-- Neither reaches primal reversion or the condition-driven forms.  Those are
-- not in the registry and nothing consumes on their behalf, so a Groudon
-- reverting costs the trainer nothing and cannot be costed anything.
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
                        spent = {}, spentAny = false }, State)
end

-- The three entry points below are one write, expressed once: a state that
-- reset four of its five fields on one path and five on another would spend
-- or refund a transformation depending on how the battle was picked up.
local function begin(self, battle)
  self.battle = battle
  self.armedId = nil
  self.selectedId = nil
  self.spent = {}
  self.spentAny = false
end

function State:onBattleStarted(ev)
  begin(self, ev and ev.battle or nil)
end

function State:onBattleEnded()
  begin(self, nil)
end

-- Taking over a battle that started before the mod was enabled (src/adopt.lua).
-- Refusing a battle already held is the whole of the idempotence guarantee:
-- everything spent in this battle was spent through a cell that could only be
-- drawn once this same battle was cached here, so a state already holding it
-- has history worth keeping, and clearing that is how a trainer would be handed
-- a second mega.  A state holding some OTHER battle is holding a stale
-- reference whose spent flags belong to a fight that is over.
function State:adopt(battle)
  if not battle or self.battle == battle then return false end
  begin(self, battle)
  return true
end

function State:current() return self.battle end
function State:isArmed() return self.armedId ~= nil end
function State:armed() return self.armedId end
function State:selected() return self.selectedId end
function State:used(id) return self.spent[id] == true end

-- Whether this battle's one manual transformation has already gone, whichever
-- one it was.  Asked of the whole state rather than of an id, because the
-- answer is the same for every id there is.
function State:usedAny() return self.spentAny end

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
  self.spentAny = true
  if self.armedId == id then self.armedId = nil end
end

return M
