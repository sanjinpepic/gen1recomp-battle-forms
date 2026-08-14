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
-- WHAT ANNOUNCES.  Primal reversion, mega evolution, Dynamax at both ends of
-- its three turns, Terastallization, and Max Guard.  Nothing else.
--
-- Mega is here even though the player asked for it: the armed marker is gone
-- from the cell by the time the change lands, the cell itself is gone with the
-- battle's one mega spent, and a player who turned battle animations off asked
-- for exactly that and got a mega with no signal at all -- the same four-way
-- silence, reached from the other direction.
--
-- Terastallization is the strongest case of all: no form, no picture, no name
-- change and no animation, so the message is not one of four channels but the
-- only one there is -- and it takes two pages rather than one because naming
-- the type is half of what it has to say and no eighteen-character row holds
-- both halves.
--
-- Dynamax announces at both ends because it is the only transformation here
-- that ENDS on its own.  A mega lasts the battle, so its one line is the whole
-- story; a Dynamax quietly stops being a Dynamax three turns later, and for a
-- species with no Gigantamax shape there is no picture change at either end to
-- notice it by.  The expiry line is what makes the clock visible at all.
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

-- The Dynamax three take the verb rather than the possessive, which is what
-- the real games print and also what keeps them inside the same 18-character
-- row: "Gigantamaxed!" is 13, and "Enemy " plus a ten-character nickname is
-- already the full width on the line above it.
local DYNAMAX = "%s\nDynamaxed!"
local GIGANTAMAX = "%s\nGigantamaxed!"
local DYNAMAX_END = "%s's\nDynamax ended!"

-- Two pages, because the longest type name is eight characters and no row that
-- also carries "Terastallized" has eight to spare.  The second page is where
-- the mechanic actually is: the type change is the whole effect and nothing on
-- screen shows it.
local TERA = "%s\nTerastallized!"
local TERA_TYPE = "It became the\n%s type!"

-- say appends to the battle's queue; sayNext inserts at the battle's own
-- insert cursor, the one the engine is using itself.  Which is correct depends
-- entirely on where the caller sits in that queue, so each transformation
-- names its own and no caller has to know the rule.
local function push(battle, insert, line)
  if type(battle) ~= "table" then return false end
  local queue = battle[insert]
  if type(queue) ~= "function" then return false end
  queue(battle, line)
  return true
end

local function emit(battle, insert, fmt, battler)
  local name = displayName(battler)
  if not name then return false end
  return push(battle, insert, text(fmt, name))
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

-- Dynamax and Gigantamax resolve from battle.turn_started beside mega
-- evolution and take the cursor for the same reason: the queue is drained and
-- the insert cursor cleared, so this lands at the head of the turn rather than
-- behind the turn's own actions.
function M.dynamax(battle, battler)
  return emit(battle, "sayNext", DYNAMAX, battler)
end

function M.gigantamax(battle, battler)
  return emit(battle, "sayNext", GIGANTAMAX, battler)
end

-- Terastallization resolves from battle.turn_started beside those, and takes
-- the cursor for the same reason.  The two pages go in on consecutive sayNext
-- calls, which is what keeps them in order: each call advances the insert
-- cursor, so the second lands behind the first rather than in front of it.
--
-- The type name is allowed to be missing and the first page still goes out.  A
-- chart record with no name is a broken chart, not a reason to swallow the one
-- notice this mechanic has.
function M.tera(battle, battler, typeName)
  if not emit(battle, "sayNext", TERA, battler) then return false end
  if type(typeName) ~= "string" or typeName == "" then return true end
  return push(battle, "sayNext", text(TERA_TYPE, typeName))
end

-- The expiry is the other case entirely.  It resolves from battle.turn_ended,
-- where the engine has already queued this round's residual damage and its
-- messages through the very cursor sayNext would steal -- taking it there
-- would print the Dynamax ending BEFORE the poison that ended the turn.
-- Appending is the only insert that cannot displace a row already queued.
function M.dynamaxEnded(battle, battler)
  return emit(battle, "say", DYNAMAX_END, battler)
end

-- Max Guard is the one line here that is RETURNED rather than queued, and it
-- has to be: it is printed from inside a move effect's `run`, and the engine
-- takes that function's messages and queues them itself
-- (BattleState.lua:3707-3717).  Pushing a copy through say or sayNext as well
-- would print the line twice.
--
-- "protected itself!" is seventeen characters, one inside the eighteen a battle
-- row holds, which is why the name gets the row above it to itself.
-- This is also the one line that must never answer nil, which is why it has a
-- nameless form where every other line here would rather stay silent: an effect
-- that hands the engine no messages at all reads as a refusal
-- (primaryEffectFailed, BattleState.lua:3570) and cancels the move's animation,
-- so a battler with no name would turn Max Guard into a move that visibly did
-- nothing rather than one that quietly said less.
local MAX_GUARD = "%s\nprotected itself!"
local MAX_GUARD_UNNAMED = "It protected\nitself!"

function M.maxGuard(battler)
  local name = displayName(battler)
  if not name then return MAX_GUARD_UNNAMED end
  return text(MAX_GUARD, name)
end

return M
