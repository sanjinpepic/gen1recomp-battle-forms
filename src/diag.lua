-- Opt-in diagnostic for the things that fail invisibly (DEBUG TRACE, off by
-- default).
--
-- Two failures made this necessary and they share a shape: a mechanic simply
-- stops happening, with nothing anywhere saying why.  A missing menu cell
-- looks the same from a chair in front of the game whichever of four things
-- went wrong -- the patch never installed, mega evolution never registered,
-- the engine is calling draw and update functions other than the ones that
-- were wrapped, or all of that worked and the decision says no.  A Groudon
-- that never turns primal looks the same whether its event never arrived, its
-- handler threw, or becomeForm refused.  Each has a different fix and none of
-- them is visible without asking, so this asks -- and answers in the order the
-- code runs, so reading the log top to bottom walks the path the mechanic
-- does.
--
-- WHERE IT LANDS, AND WHY NOT mod.log.  mod.log reaches src/core/Logger.lua,
-- which is a print() and a 200-line ring buffer nothing reads; the packaged
-- launcher is fused from the GUI-subsystem LOVE binary and swallows stdout
-- entirely, so a player has no way to see a printed line at all.  That is also
-- why the engine's own report for a throwing listener (src/mods/Events.lua)
-- has never reached anybody.  mod.storage is a file a player can open in a
-- text editor:
--
--   <save>/mod_storage/<game>/<playthrough>/battle_forms/trace/0001.lua
--
-- mod.log keeps the one job it is good at: saying out loud that the
-- diagnostic itself was refused, which is the single failure the file cannot
-- report because there is no file.
--
-- Storage belongs to a playthrough, and that is why the load-time findings are
-- RECORDED rather than written.  The mod's entry function runs before there is
-- a playthrough to write into, and a player chasing this will more often turn
-- the option on after that function has already run and gone -- so those lines
-- are held and go out with the first batch that finds somewhere to put them,
-- instead of being lost either way.
--
-- Throttling is the design, not a detail: the seams this watches run every
-- frame, and a line per frame would fill a disk and tell nobody anything.  A
-- wrapper or an event reports the first time it is reached in a battle and
-- never again; the menu decision reports only when its answer CHANGES, and
-- stops after a fixed number of changes in one battle.
local M = {}

local PREFIX = "trace"
local MAX_BYTES = 64 * 1024
local BATCH = 25
-- The tail of a battle is the interesting part, and a buffer that only emptied
-- every BATCH lines would leave it unwritten until the next one.
local FLUSH_SECONDS = 2
-- Enough for a long fight's worth of switches and phase changes, few enough
-- that a decision oscillating on some future engine cannot run away.
local MENU_CHANGES = 20

local deps = nil
local pending, size, batch = {}, 0, 0
local dead, cleared, lastFlush = false, false, 0
-- Held load-time findings.  Formatting a fixed handful of short strings once
-- per boot is the entire cost this module has while the option is off, and it
-- buys the one report that cannot be produced on demand later.
local held = {}
-- Per-battle throttles.  `scope` is keyed by the battle object the notes are
-- about; `session` is the battle the event throttles belong to and exists
-- separately because an event payload need not carry a battle at all, and
-- keying off a nil would let one payload shape reset another's counters.
local scope, session, reached, faulted = nil, nil, {}, {}

function M.bind(modules) deps = modules end

function M.enabled()
  return deps ~= nil and type(deps.enabled) == "function"
    and deps.enabled() == true
end

local function now()
  return (love and love.timer and love.timer.getTime and love.timer.getTime())
    or 0
end

-- One battle per set of files: the previous session's records go before the
-- first line of this one is written, so a log is never two runs deep.
local function clear(game)
  local keys = deps.mod.storage:list(game, PREFIX)
  if type(keys) ~= "table" then return end
  for _, key in ipairs(keys) do deps.mod.storage:delete(game, key) end
end

local function flush()
  if dead or #pending == 0 then return end
  local mod = deps and deps.mod
  local game = mod and mod.game
  if not game then return end
  if not cleared then
    if not pcall(clear, game) then return end
    cleared = true
  end
  batch = batch + 1
  local key = ("%s/%04d"):format(PREFIX, batch)
  local ok, written, code = pcall(mod.storage.write, mod.storage, game, key,
    { lines = pending })
  if not (ok and written) then
    batch = batch - 1
    -- A playthrough that is not identified yet is not a failure: the title
    -- session has nowhere to write and the lines are still wanted once a save
    -- is loaded.  Anything else is a real refusal, and a refusal that said
    -- nothing would leave a player staring at an empty folder wondering
    -- whether the option does anything.
    if ok and code ~= "not_in_playthrough" then
      dead = true
      if mod.log then
        mod.log:error("battle_forms: DEBUG TRACE could not write its "
          .. "diagnostic (%s) and has stopped for this session",
          tostring(code))
      end
    end
    return
  end
  pending = {}
  lastFlush = now()
end

local function push(msg)
  pending[#pending + 1] = ("%9.3f  %s"):format(now(), msg)
  size = size + #msg + 12
  if size > MAX_BYTES then
    pending[#pending + 1] = "(diagnostic size cap reached)"
    flush()
    dead = true
    return
  end
  if #pending >= BATCH or (now() - lastFlush) >= FLUSH_SECONDS then flush() end
end

local function emit(fmt, ...)
  if dead or not M.enabled() then return end
  if held then
    local findings = held
    held = nil
    for _, msg in ipairs(findings) do push(msg) end
  end
  local ok, msg = pcall(string.format, fmt, ...)
  push(ok and msg or ("(diagnostic format error) " .. tostring(fmt)))
end

-- A load-time finding, kept whatever the option currently says.  Bounded
-- because its callers run before anything can read the option back, so a
-- caller in a loop could otherwise grow it without limit.
function M.record(fmt, ...)
  if not held or #held >= 32 then return end
  local ok, msg = pcall(string.format, fmt, ...)
  held[#held + 1] = ok and msg or ("(diagnostic format error) " .. tostring(fmt))
end

-- What the menu has to offer before any battle has started.  An empty registry
-- and a registry holding mega both draw exactly no cell when the mon in front
-- is ineligible, so the count has to be stated rather than inferred.
function M.registry(registry, registered, why)
  local ids = {}
  for _, entry in ipairs(registry:all()) do ids[#ids + 1] = entry.id end
  M.record("registry: %d registered [%s]%s", registry:count(),
    table.concat(ids, " "),
    registered and "" or (" -- mega refused: " .. tostring(why)))
end

local function scopeFor(battle)
  if not scope or scope.battle ~= battle then
    scope = { battle = battle, notes = {}, changes = 0, answer = nil }
  end
  return scope
end

-- The first time something happens in a battle, and never again in that
-- battle: what the wrapped seams use to say they are being called at all.
function M.note(battle, key, fmt, ...)
  if not M.enabled() then return end
  local at = scopeFor(battle)
  if at.notes[key] then return end
  at.notes[key] = true
  emit(fmt, ...)
end

-- The first time each subscribed event is delivered in a battle.  An event
-- that never appears here is the whole answer: no handler of ours ran, so
-- nothing downstream of it can be at fault.
function M.reached(name, ev)
  if not M.enabled() then return end
  local battle = ev and ev.battle
  if name == "battle.started" and battle ~= session then
    session, reached, faulted, scope = battle, {}, {}, nil
  end
  if reached[name] then return end
  reached[name] = true
  emit("event: %s reached, payload battle %s", name,
    battle ~= nil and "present" or "MISSING")
end

-- A handler that threw.  Reported through mod.log as well as into the file,
-- and reported whether or not the option is on, because this is an error and
-- not a diagnostic: the engine catches it (src/mods/Events.lua) and everything
-- the handler had left to do simply did not happen.
function M.fault(what, err)
  if faulted[what] then return end
  faulted[what] = true
  local mod = deps and deps.mod
  if mod and mod.log then
    mod.log:error("battle_forms: %s threw (%s) -- whatever it had left to do "
      .. "did not happen; further throws from it this battle are not repeated",
      tostring(what), tostring(err))
  end
  emit("fault: %s threw (%s)", tostring(what), tostring(err))
end

-- Everything the cell's own decision reads, in the order it reads it.  The arm
-- state's cached battle is compared against the one the engine is updating
-- rather than merely tested for nil: the cell asks the state, so a state
-- holding SOME battle that is not this one fails exactly as quietly as one
-- holding none.
local function describe(battle)
  local cached = deps.state:current()
  local where = cached == nil and "none"
    or (cached == battle and "this battle" or "another battle")
  local mon = battle.player and battle.player.mon
  local formId = deps.eligibility.formForMon(deps.megas, mon)
  local pokemon = battle.data and battle.data.pokemon
  local queue = battle.queue
  local spent = {}
  for _, entry in ipairs(deps.registry:all()) do
    spent[#spent + 1] = ("%s=%s"):format(entry.id,
      tostring(deps.state:used(entry.id)))
  end
  return ("menu: armState=%s phase=%s queueEmpty=%s species=%s stone=%s "
    .. "form=%s record=%s used[%s] offered=%d"):format(
    where, tostring(battle.phase),
    tostring(queue == nil or next(queue) == nil),
    tostring(mon and mon.species), tostring(deps.eligibility.stoneOf(mon)),
    tostring(formId),
    tostring(formId ~= nil and pokemon ~= nil and pokemon[formId] ~= nil),
    table.concat(spent, " "), #deps.overlay.offered(deps.state))
end

function M.menu(battle)
  if not M.enabled() or battle == nil then return end
  local at = scopeFor(battle)
  if at.changes > MENU_CHANGES then return end
  local ok, answer = pcall(describe, battle)
  if not ok then
    answer = "menu: the diagnostic could not read the battle ("
      .. tostring(answer) .. ")"
  end
  if answer == at.answer then return end
  at.answer = answer
  at.changes = at.changes + 1
  if at.changes > MENU_CHANGES then
    emit("menu: further changes suppressed for this battle")
    return
  end
  emit("%s", answer)
end

-- One primal reversion attempt, from whichever handler made it.  Deduplicated
-- on the whole answer rather than counted, because the interesting case is a
-- mon switching in repeatedly and being refused the same way every time --
-- which is one finding, not twenty lines of it.
function M.primal(source, battle, mon, formId, became, reason)
  if not M.enabled() then return end
  local pokemon = battle and battle.data and battle.data.pokemon
  local answer = ("primal: %s species=%s stone=%s form=%s record=%s became=%s%s")
    :format(tostring(source), tostring(mon and mon.species),
      tostring(deps.eligibility.stoneOf(mon)), tostring(formId),
      tostring(formId ~= nil and pokemon ~= nil and pokemon[formId] ~= nil),
      tostring(became),
      reason ~= nil and (" (" .. tostring(reason) .. ")") or "")
  M.note(battle, answer, "%s", answer)
end

function M.onBattleEnded()
  emit("battle.ended")
  scope, session, reached, faulted = nil, nil, {}, {}
  flush()
end

return M
