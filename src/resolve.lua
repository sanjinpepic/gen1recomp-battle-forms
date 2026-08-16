-- Where an armed flag becomes whatever the armed transformation does, and
-- where any form change is unwound again.  Only the first half belongs to the
-- manual transformations: the faint handler and the battle-end party sweep
-- revert whatever form a mon is carrying and never asked which transformation
-- type put it there, so primal reversion unwinds through them without either
-- half knowing about the other.
--
-- battle.turn_started fires after both actions are chosen and before turn
-- order is decided, which is exactly the real games' placement: the change
-- lands first, then the turn runs with the new form's stats.  Nothing here
-- touches performMove, so there is no path along which a form change could
-- spend PP, be Disabled, or be picked up by Metronome or Mirror Move.  That
-- guarantee is structural, not a check.
--
-- deps.log is optional: main.lua passes mod.log, but the unit suite binds
-- without one so it can run outside the engine, and a refusal with nowhere
-- to log still must not silently keep the change.
local M = {}

local deps = nil

function M.bind(modules)
  deps = modules
end

-- The once-per-battle limit is spent here rather than inside the entry, so
-- every mechanic that ever registers gets the same rule from the same place:
-- an activation that answers false was refused, and a refusal must not spend
-- the flag -- the player armed in good faith and nothing happened, so they
-- keep the option.
function M.onTurnStarted(state, ev)
  local battle = ev and ev.battle
  if not battle then return end
  local entry = deps.registry:get(state:armed())
  if not entry then return end
  if entry.activate(battle) then state:consume(entry.id) end
end

-- A mega switched to the bench and back in gets a brand-new battler from
-- makeBattler, which knows nothing about a mon's `form`: it seeds curStats
-- and curTypes from the base species the same as any ordinary send-out.
-- mon.form itself survived the switch untouched -- it lives on the mon, not
-- the battler -- so the picture comes back right on its own (the sprite
-- registry reads ctx.mon.form regardless of when makeBattler runs); only the
-- stat/type override needs reapplying, through the exact same path that
-- applied it the first time, so it cannot drift from what becomeForm does.
--
-- Gen 2 needs none of this, and asking it is actively wrong rather than
-- merely unnecessary.  There is no battler wrapper and no makeBattler
-- rebuild step at all (src/battlerof.lua's own header) -- mon.stats and
-- mon.formTypes are the mon's own fields for the whole time it is in the
-- party, switch or no switch, so nothing here was ever reset for this
-- function to put back.  Running the Gen 1 logic below anyway would do worse
-- than nothing: `deps.eligibility.formForMon` reads the Gen 1 bag stamp,
-- which src/mega.lua's Gen 2 branch never writes (it reads mon.item
-- instead), so a perfectly fine Gen 2 mega'd mon would find no formId and
-- log a false "no longer eligible" warning on every single switch-in.
function M.onBattlerSwitched(ev)
  if deps.gen2 then return end
  local battle = ev and ev.battle
  local battler = ev and ev.battler
  local mon = deps.battlerof.mon(battler)
  if not battle or not mon or not mon.form then return end

  -- Rayquaza's own trigger stamps no stone at all and, as of 0.30.0, has no
  -- row in data/megas.lua either -- it is asked FIRST, ahead of the table
  -- guard below, for exactly the reason src/mega.lua asks it first: a
  -- species this function never finds in `deps.megas` is not necessarily a
  -- species with no mega, and Rayquaza is the one standing case of that.
  -- Skipping this would find nothing for a Mega Rayquaza that got there
  -- through Dragon Ascent and report it as no longer eligible -- reverting
  -- nothing, but also never reapplying the stat/type override, so it would
  -- come back from the bench with the mega's picture and species and its
  -- BASE stats.
  local formId = deps.dragonascent
    and deps.dragonascent.formFor(deps.eligibility, deps.zcrystals, mon)
  if not formId then
    -- A species this table names no mega for cannot be marked with a mega's
    -- form, so the mark belongs to another transformation type with a
    -- switch-in handler of its own (primal reversion has one).  Reapplying
    -- is not this path's job then, and neither is complaining that it
    -- cannot -- unless Rayquaza's own trigger already answered above.
    if not deps.megas[mon.species] then return end
    formId = deps.eligibility.formForMon(deps.megas, mon)
  end
  if not formId then
    -- The stone was removed, or the mega table changed, between the mon
    -- transforming and this switch-in -- vanishingly unlikely in a single
    -- battle, but a mon left showing mega art with base stats is exactly
    -- the kind of silent mismatch this mod exists to not have.
    if deps.log then
      deps.log:warn(
        "battle_forms: %s switched in still marked form %s but is no "
          .. "longer eligible for it -- stats and types were not reapplied",
        tostring(mon.species), tostring(mon.form))
    end
    return
  end
  deps.forms.becomeForm(battle.data, battler, formId, battle)
end

-- Almost every form here is the battle's, not the save's, so the battle ending
-- unwinds it.
--
-- This sweeps the PARTIES rather than the two active battlers, and that is
-- the whole point: a mega survives switching out, so a mon can transform on
-- turn one and be on the bench when the battle ends.  Reverting only what is
-- on the field would leave it permanently transformed in the save.
-- revertMon is a no-op on an untransformed mon, so the sweep can be blunt.
--
-- The one exception gets first refusal rather than an exemption, and that
-- ordering is the whole of how the sweep tells the two kinds apart.  A
-- persistent form is derived from the item stamped on the mon, so
-- src/persistent.lua can be asked what a mon is ENTITLED to wear and can write
-- that over whatever the battle left -- answering true for a mon it claims and
-- false for every other, which is the blunt clear's cue.  Neither branch
-- preserves a marker: one overwrites it from the pairing table and the other
-- deletes it, so a battle form cannot reach the save down either path, and a
-- persistent one cannot be swept away by a mechanic that never heard of it.
-- deps.persistent is optional for the reason deps.log is -- the unit suites
-- bind this module without one -- and its absence is exactly today's behaviour.
--
-- deps.fusion is the second module with that contract and is asked first, which
-- costs nothing and says something: no species is both a fusion base and an
-- appliance user, so the order can never decide an outcome, and asking the
-- strongest claim first is the order to be wrong in if that ever stops being
-- true.  Both answer the same question -- "is this mon's form yours?" -- so the
-- sweep still needs no way of telling a persistent form from a battle one.
-- On Gen 2, mon.stats is a REAL field src/gen2forms.lua's becomeForm writes
-- (Transform's own mutate-in-place precedent, that module's own header),
-- unlike Gen 1 where nothing but a battler-scoped curStats ever moves -- so
-- the blunt clear below has to be Gen 2's own gen2forms.revertMon rather
-- than src/forms.lua's revertMon, which only ever touched mon.form and would
-- leave a battle-ended mega's boosted mon.stats standing in the save
-- forever.  Run FIRST and unconditionally, ahead of asking fusion/persistent
-- whether they claim the mon: reverting to base before re-marking is what
-- gen2formview.lua's own overlay already tolerates (it recomputes fresh from
-- the form record on every draw regardless of what mon.stats currently
-- holds -- see that module's own header), so a mon fusion or persistent DOES
-- claim ends this sweep with mon.stats momentarily at base and its next
-- battle's own M.apply correcting it, the identical "stale until the next
-- battle, always right on screen" contract already established for mega and
-- persistent forms; a mon NEITHER claims ends with mon.stats correctly at
-- base with nothing left to paper over it.
local function settle(battle, mon)
  if deps.gen2 and deps.gen2forms then
    deps.gen2forms.revertMon(mon, battle.data)
  end
  if deps.fusion and deps.fusion.settle(battle.data, mon) then return end
  if deps.persistent and deps.persistent.settle(battle.data, mon) then return end
  if not deps.gen2 then deps.forms.revertMon(mon) end
end

-- The party this sweep walks is read differently per generation because the
-- ENGINE object the Runtime event hands over is shaped differently, not
-- because the concept differs: Gen 1's battle.game.save.party is `.game`
-- indirection this mod's own BattleState wrapper carries; Gen 2's engine
-- Battle (game/src/battle/gen2/Battle.lua) has no `.game` field at all --
-- confirmed against Battle.new's own opts table, `self.party = opts.party`
-- and `self.save = opts.save` set directly, no game object anywhere in
-- between -- so `battle.game and battle.game.save` was always nil there and
-- this sweep silently walked zero mons on every Gen 2 battle before this
-- pass, for every mechanic that relies on it (mega evolution included).
function M.onBattleEnded(ev)
  local battle = ev and ev.battle
  if not battle then return end
  local party, enemyParty
  if deps.gen2 then
    party, enemyParty = battle.party, battle.enemyParty
  else
    local save = battle.game and battle.game.save
    party, enemyParty = save and save.party, battle.enemyParty
  end
  for _, mon in ipairs(party or {}) do
    settle(battle, mon)
  end
  for _, mon in ipairs(enemyParty or {}) do
    settle(battle, mon)
  end
end

-- A faint reverts at once rather than waiting for the battle to end: the mon
-- can be looked at in the party menu before the battle is over, and a revived
-- mon comes back in its base form.
--
-- A persistent form is put back straight afterwards, because for that one the
-- base form is not where a faint should land: the Pokemon is still the
-- appliance form it was before the battle and will still be after it, and the
-- party menu the player is about to open is exactly where they would see it
-- claiming otherwise.  Only the MARKER is restored, not the battler's stat and
-- type override -- the battler is on its way off the field and nothing reads a
-- fainted one's stats, where a becomeForm here would rebuild the picture of a
-- Pokemon in the middle of falling over.
function M.onFainted(ev)
  local battle = ev and ev.battle
  if not battle or not ev.battler then return end

  -- Gen 2: ev.battler already IS the mon (src/battlerof.lua's own header),
  -- and forms.revertForm assumes a battler.mon wrapper that does not exist
  -- there -- it reads `battler.mon`, finds nil, and quietly does nothing,
  -- which is the identical silent no-op this whole file exists to replace
  -- with a real revert.  settle()'s own gen2forms.revertMon call is the
  -- correct primitive here for the same reason M.onBattleEnded's does.
  if deps.gen2 then
    settle(battle, deps.battlerof.mon(ev.battler))
    return
  end

  deps.forms.revertForm(ev.battler, battle.data, battle)
  -- A fusion is put back for the same reason and more strongly: an appliance
  -- form is what a Rotom looks like, where this one is a Pokemon with another
  -- Pokemon in the PC behind it, and the party menu is exactly where a player
  -- would see it claiming to be plain again.
  local mon = deps.battlerof.mon(ev.battler)
  if deps.fusion and deps.fusion.settle(battle.data, mon) then return end
  if deps.persistent then
    deps.persistent.settle(battle.data, mon)
  end
end

return M
