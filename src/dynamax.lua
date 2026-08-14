-- Dynamax and Gigantamax: the first transformation here that is a battle
-- STATE rather than a form.
--
-- Everything before this was a form change and nothing else.  A mega marks the
-- mon, overrides the battler's stats and types, and is done -- there is no
-- clock, and reverting is the only thing anyone has to remember.  Dynamax
-- carries a turn counter that has to be driven, expire, and be torn down from
-- four directions, and Gigantamax is that same state with a form change laid on
-- top for the species that have one.  So the counter lives here and the form
-- change goes through the same primitive everything else uses; there is no
-- second way to put a form on a mon.
--
-- WHY THIS DOES NOT TOUCH HP, which is the decision worth reading.
--
-- Dynamax multiplies HP in the real games.  It cannot do that safely here.
--
-- There is no battler-scoped max HP to move.  makeBattler seeds `curStats`
-- from `mon.stats` BY REFERENCE (BattleState.lua:513, and BattleCheckpoint
-- records `curStatsFromMon` to preserve that aliasing across a restore), so
-- writing curStats.hp writes the party mon's own stat table -- the save.  And
-- nothing would read it anyway: Damage.lua takes attack/defense/special/speed
-- off curStats and never HP at all, while every max-HP reader in the engine
-- goes to mon.stats.hp directly -- the bar's denominator (BattleState.lua:1035,
-- 3103, 5729), the catch formula (Catching.lua:53), poison and burn residuals
-- (Status.lua:41, 278), recovery moves and Substitute's cost (MoveEffects.lua:
-- 204-212, 283, 451) and the AI's switch and heal thresholds (TrainerAI.lua:
-- 79-81).  Current HP is `mon.hp`, which is where damage lands
-- (BattleState.lua:3794) and what every faint check reads.  Both fields are
-- save data.  There is no third place to put this.
--
-- Writing them anyway fails three ways.  The bar: `shownPx` is computed once,
-- at construction, from mon.stats.hp (BattleState.lua:506), and the engine has
-- already been bitten by moving that denominator mid-battle -- a level-up made
-- the bar SHRINK because the denominator jumped while the shownHP numerator
-- lagged (#224, BattleState.lua:3951-3961), and it needed a hand-driven drain
-- to hide it.  The level-up itself: Experience.lua:82-84 REPLACES mon.stats
-- wholesale on a mid-battle level, so a boost written there is silently
-- discarded and any "restore this afterwards" value we kept is stale the
-- moment it happens.  And the failure mode: mon.form is a MARKER, so a missed
-- unwind is visible and any later revert fixes it, but max HP is a number with
-- nothing to mark it -- a mon left at 150 that started at 100 is
-- indistinguishable from one that grew there, so a single missed unwind is
-- both undetectable and unrepairable, and it compounds every battle.  Stashing
-- the original on the mon to survive a crash would put the recovery record in
-- the save too, which is the same hazard wearing a hat.
--
-- So the HP multiplier is left out and the rest is not.  Three turns, ending
-- on a switch and on a faint, one per battle per trainer, and the Gigantamax
-- shape where there is art for it are all battle-visible and all safe.
--
-- Max Moves and G-Max Moves are out of scope by the same reasoning that keeps
-- them out of the changelog: they replace the mon's moveset for the duration,
-- which is a move-substitution system that Z-Moves would share, and it is not
-- a form change.
local M = {}

M.ID = "dynamax"

-- Three turns, counted at battle.turn_ended.  The activation lands at
-- turn_started, so the mon is Dynamaxed for the turn it was armed on and the
-- two after it, and is ordinary again on the fourth -- the guide's own table.
M.TURNS = 3

local deps = nil

function M.bind(modules) deps = modules end

-- One record, not a table keyed by mon.  Only the player's side can reach the
-- menu cell and the trainer gets one activation per battle, so there is never
-- a second Dynamax to track -- and a single record is also a single thing to
-- drop at battle end, which is what stops a mon reference outliving the battle
-- that owned it.
function M.new()
  return { mon = nil, turns = 0, form = nil }
end

-- Ends the state and takes the Gigantamax shape back off, but only if the mon
-- is still wearing the exact form THIS activation applied.  A mon that mega
-- evolved on top of its Dynamax is wearing the mega now, and stripping that
-- here would undo, silently and permanently, something the player gets once a
-- battle -- the same rule src/conditional.lua follows for the same reason.
--
-- `battler` is the mon's live battler when it has one.  Off the field there is
-- nothing to restore: curStats and curTypes died with the battler the switch
-- discarded, and the next send-out builds them from the base species anyway,
-- so clearing the marker is the whole of the work.
local function finish(state, battle, battler)
  local mon, form = state.mon, state.form
  state.mon, state.turns, state.form = nil, 0, nil
  if not mon then return false end
  if form and mon.form == form then
    if battler and battler.mon == mon then
      deps.forms.revertForm(battler, battle and battle.data, battle)
    else
      deps.forms.revertMon(mon)
    end
  end
  return true
end

-- The battler the state's mon is standing in, or nil when it has left the
-- field.  Identity is compared on the MON: a switch replaces the battler table
-- outright (makeBattler), so the battler that dynamaxed is not the one holding
-- the mon a turn later.
local function onField(state, battle)
  local battler = battle and battle.player
  if battler and battler.mon == state.mon then return battler end
  return nil
end

function M.entry(state)
  return {
    id = M.ID,
    label = "DYNAMAX",

    -- Every species may Dynamax, which is what makes this the first entry with
    -- no eligibility question of its own: there is no stone to carry and no
    -- pairing table to be missing from.  The once-per-battle limit is the
    -- registry's own, applied by src/overlay.lua before this is ever asked.
    available = function(battle)
      local mon = battle.player and battle.player.mon
      return mon ~= nil and mon.species ~= nil
    end,

    -- Always answers true: the state is the mechanic, and it is set here
    -- whether or not a Gigantamax shape could be found to go with it.  A
    -- species with no G-Max record, or one whose record will not resolve,
    -- Dynamaxes plainly rather than not at all.
    activate = function(battle)
      local battler = battle.player
      local mon = battler and battler.mon
      if not mon then return false end

      state.mon = mon
      state.turns = M.TURNS
      state.form = nil

      local formId = deps.gigantamax[mon.species]
      -- Refuses to dress a mon already wearing another transformation's form,
      -- which is the mega-and-primal guard again: overwriting mon.form here
      -- would leave the other mechanic's unwind with nothing to find.  This is
      -- the one refusal that is not logged: it is a decision, not a data
      -- fault, and it fires every time a player megas before Dynamaxing.
      if formId and not mon.form then
        local pokemon = battle.data and battle.data.pokemon
        local ok, reason
        if pokemon and pokemon[formId] then
          ok, reason = deps.forms.becomeForm(battle.data, battler, formId,
                                             battle)
        else
          -- Unlike the mega cell, this one is offered to every species, so
          -- there is no `available` pass to have caught a missing record
          -- before now -- the check has to live here or nowhere.
          reason = "no_record"
        end
        if ok then
          state.form = mon.form
        elseif deps.log then
          -- A guard that refuses must say so out loud: a Gigantamax that
          -- quietly became a plain Dynamax is a mechanic half working, and
          -- half working is what this mod keeps paying for.
          deps.log:warn(
            "battle_forms: refused gigantamax for %s -> %s (%s) -- the "
              .. "national_dex record is missing, has no `form` field, or "
              .. "data/gigantamax.lua names the wrong id; the Dynamax itself "
              .. "still applies",
            tostring(mon.species), tostring(formId), tostring(reason))
        end
      end

      if deps.announce then
        if state.form then
          deps.announce.gigantamax(battle, battler)
        else
          deps.announce.dynamax(battle, battler)
        end
      end
      return true
    end,
  }
end

-- The clock.  battle.turn_ended is the right seam and the engine says so
-- itself: it fires even on the turn a battle is decided, where the residual
-- sweep is skipped, precisely because "mods count turns, not residuals"
-- (BattleState.lua:2576-2585).  Counting anywhere in the move path would miss
-- the turns a mon spent switching, flinching or asleep.
function M.onTurnEnded(state, ev)
  local battle = ev and ev.battle
  if not battle or not state.mon then return end
  state.turns = state.turns - 1
  if state.turns > 0 then return end
  local battler = onField(state, battle)
  finish(state, battle, battler)
  -- Only announced with a battler to name.  Expiry off the field is not
  -- reachable -- a switch and a faint both end this sooner -- and a line with
  -- no name to put in it is worse than the silence announce.lua exists to end.
  if battler and deps.announce then
    deps.announce.dynamaxEnded(battle, battler)
  end
end

-- Switching out ends it.  `previous` is the OUTGOING battler, captured whole
-- before makeBattler replaces it (BattleState.lua:2506-2514 and the four other
-- send-out seams), so the mon that just left is previous.mon -- ev.battler is
-- the one arriving and is the wrong end of this event to read.
--
-- Silent on purpose.  The mon is off the screen by the time this runs and the
-- engine is part-way through its own send-out text; a line about a Pokemon the
-- player is no longer looking at would land in the middle of "Go! X!" and say
-- nothing they need.
function M.onBattlerSwitched(state, ev)
  local mon = ev and ev.previous and ev.previous.mon
  if not mon or state.mon ~= mon then return end
  finish(state, ev.battle, nil)
end

-- Fainting ends it.  src/resolve.lua's faint handler reverts whatever form the
-- mon carries through the same primitive, and it runs first, so by here the
-- marker is usually already gone and finish() only drops the counter.  It is
-- written to be correct in either order anyway: revertMon is a no-op on a mon
-- with no form, and the `mon.form == form` test simply stops matching.
function M.onFainted(state, ev)
  local battler = ev and ev.battler
  local mon = battler and battler.mon
  if not mon or state.mon ~= mon then return end
  finish(state, ev.battle, battler)
end

-- Both ends of a battle clear the record outright rather than through
-- finish(), and the difference matters: at battle end src/resolve.lua has
-- already swept both parties and reverted every form, so there is nothing left
-- to take off -- but the mon REFERENCE is still here, and holding it past the
-- battle is the leak src/arm.lua drops its own battle to avoid.
local function forget(state)
  state.mon, state.turns, state.form = nil, 0, nil
end

M.onBattleStarted = forget
M.onBattleEnded = forget

return M
