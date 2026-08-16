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
-- WHY THIS DOES NOT WRITE HP, which is the decision worth reading even
-- though 0.26.0 stopped leaving the multiplier out entirely -- see
-- src/hpscale.lua for how it gets applied without writing anything.
--
-- Dynamax multiplies HP in the real games.  It cannot do that by WRITING
-- max or current HP here, ever, on any path.
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
-- So max and current HP are never written, on any path, full stop.  Three
-- turns, ending on a switch and on a faint, one per battle per trainer, and
-- the Gigantamax shape where there is art for it are all battle-visible and
-- all safe -- and so, since 0.26.0, is the multiplier itself: src/hpscale.lua
-- halves incoming damage against `state.mon` instead of doubling its HP,
-- which is the same survivability by the algebra its own header works
-- through, and repaints the player's own HP readout to match after the real
-- one has already drawn.  It reads `state.mon` for identity and owns one
-- field on this table, `state.carry`, cleared alongside turns/form/mon on
-- every one of the four teardown paths below -- this file never computes a
-- multiplier itself, only carries the record that other module reads.
--
-- MAX MOVES, which arrived after the rest of this and through a mechanism of
-- their own.  A Dynamaxed Pokemon's moves are substituted rather than rewritten:
-- src/substitute.lua replaces the battler's whole `curMoves` array and puts the
-- original back by reference, because the tables inside that array are the party
-- Pokemon's own move records and writing to one is writing to the save.  So the
-- three turns now unwind two things instead of one, on exactly the same four
-- paths, and the substitution is torn down through the same finish() every one
-- of them already went through.
--
-- The two halves happen at different moments, which is the thing to hold on to
-- when reading `activate` below and finding no substitution in it.  The state,
-- the clock and the Gigantamax shape land at battle.turn_started, the placement
-- that keeps a mega from costing a turn.  The MOVES are swapped a step earlier,
-- when the player arms the cell, because the array has to be standing before
-- the FIGHT menu is opened or the turn's action is captured out of the old one
-- -- src/arm.lua dispatches that and says why at length.  So all three turns of
-- a Dynamax are Max Move turns, including the one it was armed on, and a
-- Dynamax armed and then cycled away from takes its Max Moves back off with it.
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
-- `moves` is the substitution's own record and is created here rather than on
-- activation so that every teardown path can hand it to restore() blind,
-- including the ones that run when nothing was ever substituted.
-- `carry` is src/hpscale.lua's field, not this file's -- see the header note
-- above.  Zeroed here and everywhere else `turns`/`form` are, so a caller
-- never has to know it exists to keep it correct.
function M.new()
  return { mon = nil, turns = 0, form = nil, carry = 0,
           moves = deps and deps.substitute and deps.substitute.new() or nil }
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
  state.mon, state.turns, state.form, state.carry = nil, 0, nil, 0
  -- Before the form work and unconditionally.  The substitution holds the
  -- battler it covered, so it needs neither the `battler` argument -- which is
  -- nil on the switch-out path -- nor a live mon to put the original move array
  -- back where it found it.
  if deps.substitute then deps.substitute.restore(state.moves) end
  if not mon then return false end
  if form and mon.form == form then
    if deps.battlerof.mon(battler) == mon then
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
  if deps.battlerof.mon(battler) == state.mon then return battler end
  return nil
end

function M.entry(state)
  return {
    id = M.ID,
    label = "DYNAMAX",

    -- Every species may Dynamax, which is what makes this the only entry whose
    -- whole requirement sits on the trainer: there is no stone to carry and no
    -- pairing table to be missing from, so the Dynamax Band is not the outer of
    -- two tiers the way the Key Stone is -- it is the only tier there is.
    -- Without it nothing Dynamaxes at all, and the cell is simply absent rather
    -- than present and refusing.  The once-per-battle limit is the registry's
    -- own, applied by src/overlay.lua before this is ever asked.
    available = function(battle)
      if not deps.keyitems.held(battle, deps.keyitems.DYNAMAX_BAND) then
        return false
      end
      local mon = deps.battlerof.mon(battle.player)
      return mon ~= nil and mon.species ~= nil
    end,

    -- The Max Moves, put on the moment the cell is armed rather than when the
    -- Dynamax activates: the FIGHT menu the player is about to open reads
    -- `curMoves` as it draws, so this is the last moment a swap is still ahead
    -- of the action being chosen.  Answers whether anything was substituted,
    -- which is nothing to act on here -- a moveset with no Max Move for any of
    -- its types Dynamaxes plainly, exactly as it did before.
    arm = function(battle)
      if not battle or not (deps.substitute and deps.maxMoves) then
        return false
      end
      return deps.substitute.apply(state.moves, battle.player,
                                   deps.maxMoves(battle.data))
    end,

    -- Disarming is the array coming straight back.  Nothing else of a Dynamax
    -- exists yet at this point -- no counter, no form, no mon reference -- so
    -- there is nothing else to undo.
    disarm = function()
      if deps.substitute then deps.substitute.restore(state.moves) end
    end,

    -- Always answers true: the state is the mechanic, and it is set here
    -- whether or not a Gigantamax shape could be found to go with it.  A
    -- species with no G-Max record, or one whose record will not resolve,
    -- Dynamaxes plainly rather than not at all.
    activate = function(battle)
      local battler = battle.player
      local mon = deps.battlerof.mon(battler)
      if not mon then return false end

      state.mon = mon
      state.turns = M.TURNS
      state.form = nil
      -- Always zeroed on a fresh activation, even though every teardown path
      -- already leaves it at zero: the invariant ("no carry without a live
      -- Dynamax") should hold by construction here, not merely by every
      -- other function's discipline.
      state.carry = 0

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

      -- No moveset work here on purpose: the Max Moves went on when the cell
      -- was armed and are already standing.  A Gigantamax that retypes the mon
      -- does not disturb them either way, because a Max Move follows the base
      -- move's type rather than the Pokemon's.
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
  local mon = deps.battlerof.mon(ev and ev.previous)
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
  local mon = deps.battlerof.mon(battler)
  if not mon or state.mon ~= mon then return end
  finish(state, ev.battle, battler)
end

-- Both ends of a battle clear the record outright rather than through
-- finish(), and the difference matters: at battle end src/resolve.lua has
-- already swept both parties and reverted every form, so there is nothing left
-- to take off -- but the mon REFERENCE is still here, and holding it past the
-- battle is the leak src/arm.lua drops its own battle to avoid.
local function forget(state)
  state.mon, state.turns, state.form, state.carry = nil, 0, nil, 0
  -- The substitution is not swept by anything the way a form is, so it is
  -- unwound here as well as in finish().  The battler it is holding is a second
  -- reference that must not outlive the battle either.
  if deps.substitute then deps.substitute.restore(state.moves) end
end

M.onBattleStarted = forget
M.onBattleEnded = forget

return M
