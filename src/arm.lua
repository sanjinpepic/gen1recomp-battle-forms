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
--
-- ARMING IS ALSO WHEN A MOVE SUBSTITUTION GOES ON, which is the decision worth
-- reading and the only reason this file knows the registry at all.
--
-- Max Moves and Z-Moves replace the battler's move array, and for two releases
-- they did it at battle.turn_started -- which the engine raises after both
-- actions are already chosen, and the action it raises with is a direct
-- reference to `mon.moves[moveIndex]` captured at the A-press in move select
-- (BattleState.lua:2116-2127).  A substitution there cannot reach the action it
-- would have to replace, so the player got the new moves a turn late: one turn
-- of a three-turn Dynamax spent on the base move, and for a Z-Move a plausible
-- way to spend the battle's one transformation on something that was never
-- selectable.
--
-- The framing was wrong rather than the placement.  The cell lives on the
-- COMMAND menu, so arming already happens before FIGHT is pressed, and every
-- reader of the move list dereferences `curMoves` fresh at the moment it runs --
-- the phase change into move select (BattleState.lua:2070), the input handler
-- (:2084), the A-press that captures the action (:2116), and both layouts'
-- per-frame draw of the names and the PP box (:5825, :5840 and
-- WideBattle.lua:247).  Nothing caches the array or the names anywhere, so a
-- swap made while the cursor is on the cell is already standing when the move
-- list is drawn, and the player can pick a Max Move or a Z-Move on the turn
-- they armed it.
--
-- So the substitution follows the ARMED flag, and it is dispatched from here
-- because this is the one place armedId is written: every way of arming and
-- every way of disarming -- a second A, cycling with LEFT/RIGHT, a battle
-- starting or ending -- reaches the same pair of calls and cannot disagree with
-- itself.  `consume` is the single write that deliberately does NOT dispatch:
-- there the transformation actually activated, and from that moment its own
-- state owns what it put on and unwinds it on its own clock.
local M = {}
local State = {}
State.__index = State

local deps = nil

-- Optional.  The dispatch below is the only thing that needs a registry, and
-- the unit suite drives this state with none -- an arm state that cannot reach
-- an entry simply arms nothing early, which is what this file did before.
function M.bind(modules) deps = modules end

-- `arm` and `disarm` are optional on a registry entry and are always supplied
-- as a pair, which src/transforms.lua refuses a registration over: half of that
-- pair is a moveset left substituted behind a cell showing something else.
local function hook(id, name)
  local registry = deps and deps.registry
  if not registry or type(id) ~= "string" then return nil end
  local entry = registry:get(id)
  local fn = entry and entry[name]
  if type(fn) ~= "function" then return nil end
  return fn
end

-- Run after every write to armedId that is not a consume.  `was` is what the
-- flag held beforehand, and taking that one off BEFORE putting the new one on
-- is the whole of the sharp case: arming Dynamax and then cycling to Z-Move
-- must not leave Max Moves substituted underneath the Z-Move's label.
local function retarget(self, was)
  if was == self.armedId then return end
  local off = hook(was, "disarm")
  if off then off() end
  local on = hook(self.armedId, "arm")
  if on then on(self.battle) end
end

function M.new()
  return setmetatable({ battle = nil, armedId = nil, selectedId = nil,
                        spent = {}, spentAny = false }, State)
end

-- The three entry points below are one write, expressed once: a state that
-- reset four of its five fields on one path and five on another would spend
-- or refund a transformation depending on how the battle was picked up.
local function begin(self, battle)
  local was = self.armedId
  self.battle = battle
  self.armedId = nil
  self.selectedId = nil
  self.spent = {}
  self.spentAny = false
  -- A leftover armed flag is a leftover substitution, and the battler holding
  -- it belongs to a battle that is over.  Dispatched here as well rather than
  -- left to each mechanic's own battle-end teardown, so that the unwind is the
  -- flag's in every case and not the flag's in some and a handler's in others.
  retarget(self, was)
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
  local was = self.armedId
  self.selectedId = id
  self.armedId = nil
  retarget(self, was)
end

function State:toggle(id)
  if type(id) ~= "string" or self.spent[id] then return false end
  local was = self.armedId
  self.selectedId = id
  self.armedId = self.armedId ~= id and id or nil
  retarget(self, was)
  return self.armedId == id
end

function State:consume(id)
  self.spent[id] = true
  self.spentAny = true
  -- Cleared without the dispatch, and that is the whole difference between
  -- spending a transformation and taking it back off again: the activation
  -- happened, so whatever it substituted is now its own state's to unwind on
  -- its own clock -- three turns, a switch, a faint, a use, the battle ending.
  if self.armedId == id then self.armedId = nil end
end

return M
