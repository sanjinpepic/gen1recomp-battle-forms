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
function M.onBattlerSwitched(ev)
  local battle = ev and ev.battle
  local battler = ev and ev.battler
  local mon = battler and battler.mon
  if not battle or not mon or not mon.form then return end
  -- A species this table names no mega for cannot be marked with a mega's
  -- form, so the mark belongs to another transformation type with a switch-in
  -- handler of its own (primal reversion has one).  Reapplying is not this
  -- path's job then, and neither is complaining that it cannot.
  if not deps.megas[mon.species] then return end

  -- Rayquaza's own trigger stamps no stone at all, so the ordinary
  -- stone-based lookup below would find nothing for a Mega Rayquaza that
  -- got there through Dragon Ascent and report it as no longer eligible --
  -- reverting nothing, but also never reapplying the stat/type override, so
  -- it would come back from the bench with the mega's picture and species
  -- and its BASE stats. Asked first, the same order src/mega.lua checks in.
  local formId = (deps.dragonascent
      and deps.dragonascent.formFor(deps.megas, deps.eligibility,
        deps.zcrystals, mon))
    or deps.eligibility.formForMon(deps.megas, mon)
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
local function settle(battle, mon)
  if deps.fusion and deps.fusion.settle(battle.data, mon) then return end
  if deps.persistent and deps.persistent.settle(battle.data, mon) then return end
  deps.forms.revertMon(mon)
end

function M.onBattleEnded(ev)
  local battle = ev and ev.battle
  if not battle then return end
  local save = battle.game and battle.game.save
  for _, mon in ipairs(save and save.party or {}) do
    settle(battle, mon)
  end
  for _, mon in ipairs(battle.enemyParty or {}) do
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
  deps.forms.revertForm(ev.battler, battle.data, battle)
  -- A fusion is put back for the same reason and more strongly: an appliance
  -- form is what a Rotom looks like, where this one is a Pokemon with another
  -- Pokemon in the PC behind it, and the party menu is exactly where a player
  -- would see it claiming to be plain again.
  if deps.fusion and deps.fusion.settle(battle.data, ev.battler.mon) then return end
  if deps.persistent then
    deps.persistent.settle(battle.data, ev.battler.mon)
  end
end

return M
