-- The line a form change prints.
--
-- A transformation here has four ways of being noticed and primal reversion
-- had none of them: no animation (deliberate -- the change lands before there
-- is anything to watch), no name change (correct -- a primal or a mega keeps
-- its species name), and for several days no back sprite either, because one
-- art file was missing.  With every channel silent at once a mechanic that was
-- working looked exactly like one that was not.  A message is the only channel
-- that cannot go missing with a file, which is the whole reason this module
-- exists.
--
-- WHAT ANNOUNCES.  Primal reversion and mega evolution, and nothing else.
--
-- Mega is here even though the player asked for it: the armed marker is gone
-- from the cell by the time the change lands, the cell itself is gone with the
-- battle's one mega spent, and a player who turned battle animations off asked
-- for exactly that and got a mega with no signal at all -- the same four-way
-- silence, reached from the other direction.
--
-- The eight condition-driven forms stay silent, and that is a decision about
-- frequency rather than about importance.  They answer the battle, not the
-- player, and they answer it constantly: Aegislash flips on every move it
-- picks, Morpeko at the close of every round, Darmanitan and Minior each way
-- across a threshold the HP bar crosses more than once in a long fight.  A
-- line apiece would be two prompts a turn for the length of the battle,
-- burying the messages the player is actually reading.  A form change nobody
-- can miss and a form change nobody can read past are the same failure.
local M = {}

-- Strings is the engine's own catalog for text the engine AUTHORS, as opposed
-- to the ROM text romText serves (src/core/Strings.lua), and these two lines
-- are that: pokered has no label for either, so romText would fall straight
-- through to its own fallback.  Going through Strings instead puts them where
-- a translation mod already reaches the engine's battle text.  pcall because
-- engine_internals is a courtesy the host owes the mod, not a guarantee -- with
-- no catalog the format string itself is the line.
local Strings = nil
do
  local ok, module = pcall(require, "src.core.Strings")
  if ok and type(module) == "table" then Strings = module end
end

local function text(fmt, ...)
  if Strings then
    local ok, out = pcall(Strings, fmt, ...)
    if ok and type(out) == "string" then return out end
  end
  local ok, out = pcall(string.format, fmt, ...)
  return ok and out or fmt
end

-- pokered prints "Enemy " before an enemy mon's nickname in battle text
-- (home/text.asm PlaceMoveUsersName) and BattleState's own displayName is a
-- file-local, so the qualifier is rebuilt here through the exact catalog key
-- the engine registers for it -- one translation entry covers both.
--
-- A battler with no name answers nil rather than a placeholder: a line reading
-- "nil's Primal Reversion!" is worse than the silence this module exists to
-- end.
local function displayName(battler)
  local name = battler and battler.name
  if type(name) ~= "string" or name == "" then return nil end
  if battler.isPlayer then return name end
  return text("Enemy %s", name)
end

-- The mainline games' own two lines, cut to the box.  Gen 1 battle text is 18
-- characters a row -- BattleState:drawTextArea prints 8-pixel cells from x=8
-- across a 160-pixel canvas -- and the widest either can render is "Enemy "
-- plus a ten-character nickname plus "'s", which is exactly 18.
local PRIMAL = "%s's\nPrimal Reversion!"
local MEGA = "%s's\nMega Evolution!"

-- say appends to the battle's queue; sayNext inserts at the battle's own
-- insert cursor, the one the engine is using itself.  Which is correct depends
-- entirely on where the caller sits in that queue, so each transformation
-- names its own and no caller has to know the rule.
local function emit(battle, insert, fmt, battler)
  if type(battle) ~= "table" then return false end
  local name = displayName(battler)
  if not name then return false end
  local queue = battle[insert]
  if type(queue) ~= "function" then return false end
  queue(battle, text(fmt, name))
  return true
end

-- Mega evolution resolves from battle.turn_started, which the engine raises
-- with the queue drained and its insert cursor cleared, before it queues the
-- turn's own actions.  sayNext therefore puts this at the head of the turn,
-- and puts it ahead of the animation src/mega.lua inserts straight after --
-- message first, then the animation, the order pokered narrates every move in.
function M.mega(battle, battler)
  return emit(battle, "sayNext", MEGA, battler)
end

-- Primal reversion resolves from the send-out seams, where the engine is
-- itself part-way through inserting the send-out text, the poof and the
-- grow-in through that same cursor -- and where in the queue a stolen cursor
-- lands differs from one send-out site to the next.  Taking it there would put
-- this line ahead of "Go! GROUDON!", so this one appends: say is the only
-- insert that cannot displace a row the engine has not queued yet.  At
-- battle.started -- the case this defect was reported from, where the intro
-- queue is already complete -- appending lands it exactly where the real games
-- print it, after the send-out and before the command menu.
function M.primal(battle, battler)
  return emit(battle, "say", PRIMAL, battler)
end

return M
