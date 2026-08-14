-- Where an armed flag becomes a form change, and where any form change is
-- unwound again.  Only the first half is mega evolution's: the faint handler
-- and the battle-end party sweep revert whatever form a mon is carrying and
-- never asked which transformation type put it there, so primal reversion
-- unwinds through them without either half knowing about the other.
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

function M.onTurnStarted(state, ev)
  local battle = ev and ev.battle
  if not battle or not state:isArmed() then return end

  local battler = battle.player
  local mon = battler and battler.mon
  local formId = deps.eligibility.formForMon(deps.megas, mon)
  -- A refusal must not spend the battle's one change: the player armed in
  -- good faith and nothing happened, so they keep the option.
  if not formId then return end

  local ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
  if not ok then
    -- A guard that refuses must say so out loud: this exact silent path
    -- (a mega table pointing at a name field instead of a record key) once
    -- shipped a whole release where arming did nothing and nothing logged.
    if deps.log then
      deps.log:warn(
        "battle_forms: refused mega for %s -> %s (%s) -- the national_dex "
          .. "record is missing, has no `form` field, or data/megas.lua "
          .. "names the wrong id",
        tostring(mon and mon.species), tostring(formId), tostring(reason))
    end
    return
  end
  state:consume()

  -- The form change must not depend on the animation: a player who turned
  -- battle animations off asked for exactly that and still gets the mega.
  if battle.animationsOn and battle:animationsOn() then
    battle:animNext(deps.animId, battler.isPlayer)
  end
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

  local formId = deps.eligibility.formForMon(deps.megas, mon)
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

-- The form is the battle's, not the save's, so the battle ending unwinds it.
--
-- This sweeps the PARTIES rather than the two active battlers, and that is
-- the whole point: a mega survives switching out, so a mon can transform on
-- turn one and be on the bench when the battle ends.  Reverting only what is
-- on the field would leave it permanently transformed in the save.
-- revertMon is a no-op on an untransformed mon, so the sweep can be blunt.
function M.onBattleEnded(ev)
  local battle = ev and ev.battle
  if not battle then return end
  local save = battle.game and battle.game.save
  for _, mon in ipairs(save and save.party or {}) do
    deps.forms.revertMon(mon)
  end
  for _, mon in ipairs(battle.enemyParty or {}) do
    deps.forms.revertMon(mon)
  end
end

-- A faint reverts at once rather than waiting for the battle to end: the mon
-- can be looked at in the party menu before the battle is over, and a revived
-- mon comes back in its base form.
function M.onFainted(ev)
  local battle = ev and ev.battle
  if not battle or not ev.battler then return end
  deps.forms.revertForm(ev.battler, battle.data, battle)
end

return M
