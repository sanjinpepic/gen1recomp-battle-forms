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

-- Whether mon.form is a suffix ANY of this mod's own pairing tables could
-- have produced for mon.species -- not necessarily the one it is entitled to
-- RIGHT NOW (a stone taken away, a fusion already undone), only whether the
-- shape is this mod's at all.
--
-- WHY THIS EXISTS.  The faint handler and the battle-end sweep below used to
-- assume "fusion and persistent both say this mon is not theirs" meant "so
-- whatever is on mon.form is battle-scoped and safe to clear" -- true for
-- every mechanic this mod has ever shipped, and false the moment a SIBLING
-- mod marks a Pokemon through the identical field for a reason of its own.
-- wild_forms marks caught regional and Minior forms with mon.form, because
-- that is the field the sprite registry reads regardless of which mod set
-- it, and that marker outlives the battle the same way a persistent held-
-- item form does here -- so a party mon carrying one, with no row in any
-- table below, was having it silently deleted at the end of the next battle
-- this mod happened to be loaded for.  A marker this function does not
-- recognise belongs to a mechanic this mod has never heard of and must be
-- left standing; see M.onBattleEnded's and M.onFainted's own headers for
-- where that now matters.
--
-- Every pairing table this mod owns is listed here by the shape it carries,
-- because there is no field on a national_dex record that names which mod's
-- pairing table produced it -- enumeration is the only way to ask "is this
-- ours" at all.  A pairing table added anywhere else in this mod belongs on
-- this list too, or this function quietly starts treating that table's own
-- markers as foreign the moment a species collides with something else that
-- clears them.
local function suffixOf(data, formId)
  local record = data and data.pokemon and data.pokemon[formId]
  local suffix = record and record.form
  return (type(suffix) == "string" and suffix ~= "") and suffix or nil
end

-- species -> item -> formId: megas, primal reversion, the persistent
-- held-item families and Ultra Burst all share this shape (src/eligibility.
-- lua's own M.formFor).
local function fromFlat(rows, species, data, form)
  local byItem = rows and species and rows[species]
  if type(byItem) ~= "table" then return false end
  for _, formId in pairs(byItem) do
    if suffixOf(data, formId) == form then return true end
  end
  return false
end

-- species -> item -> partner species -> formId: fusion's own three-level
-- shape (src/fusion.lua's own M.formIdFor).
local function fromFusion(rows, species, data, form)
  local byItem = rows and species and rows[species]
  if type(byItem) ~= "table" then return false end
  for _, byPartner in pairs(byItem) do
    if type(byPartner) == "table" then
      for _, formId in pairs(byPartner) do
        if suffixOf(data, formId) == form then return true end
      end
    end
  end
  return false
end

local function ownsForm(battle, mon)
  if not mon or not mon.form or not mon.species then return false end
  local data, species, form = battle and battle.data, mon.species, mon.form
  if fromFlat(deps.megas, species, data, form) then return true end
  if fromFlat(deps.primals, species, data, form) then return true end
  if fromFlat(deps.persistentRows, species, data, form) then return true end
  if fromFlat(deps.ultraRows, species, data, form) then return true end
  if fromFusion(deps.fusionRows, species, data, form) then return true end
  -- species -> { form = formId, ... }: src/conditional.lua's one-row-per-
  -- species shape (data/conditional.lua's own header).
  local conditionalRow = deps.conditionalRows and deps.conditionalRows[species]
  if conditionalRow and suffixOf(data, conditionalRow.form) == form then
    return true
  end
  -- species -> formId directly: data/gigantamax.lua's own flattest shape.
  -- Dynamax relies on THIS sweep to take a Gigantamax marker off at battle
  -- end (src/dynamax.lua's own header: "src/resolve.lua has already swept
  -- both parties and reverted every form, so there is nothing left to take
  -- off"), so leaving this table out would silently reopen the identical bug
  -- for every Gigantamax species the moment this fix landed.
  local gigaFormId = deps.gigantamaxRows and deps.gigantamaxRows[species]
  if gigaFormId and suffixOf(data, gigaFormId) == form then return true end
  return false
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
--
-- Both the Gen 2 revert and the Gen 1 blunt clear below are now guarded by
-- ownsForm: a mon whose CURRENT mon.form is not a suffix any table this mod
-- owns could have produced is left standing completely untouched, on both
-- generations -- see ownsForm's own header for why that guard exists at
-- all. Asked before fusion/persistent get a chance to claim the mon, not
-- instead of them: a genuinely fused or persistent mon's marker IS one of
-- ours (persistentRows/fusionRows are both on ownsForm's own list), so this
-- changes nothing about the two claimant branches below -- only the final
-- fallback, and the Gen 2 pre-revert that used to run unconditionally ahead
-- of them.
local function settle(battle, mon)
  if deps.gen2 and deps.gen2forms and ownsForm(battle, mon) then
    deps.gen2forms.revertMon(mon, battle.data)
  end
  if deps.fusion and deps.fusion.settle(battle.data, mon) then return end
  if deps.persistent and deps.persistent.settle(battle.data, mon) then return end
  if not deps.gen2 and ownsForm(battle, mon) then deps.forms.revertMon(mon) end
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

  -- Guarded by ownsForm for the identical reason settle() is: revertForm
  -- resets battler.curStats/curTypes from the BASE species record as well as
  -- clearing mon.form, and a mon fainting with a foreign mod's own form
  -- marker on it is also, very plausibly, standing on that OTHER mod's own
  -- battler-scoped override -- overwriting curStats/curTypes here would
  -- undo that override too, not merely clear a marker.
  local mon = deps.battlerof.mon(ev.battler)
  if ownsForm(battle, mon) then
    deps.forms.revertForm(ev.battler, battle.data, battle)
  end
  -- A fusion is put back for the same reason and more strongly: an appliance
  -- form is what a Rotom looks like, where this one is a Pokemon with another
  -- Pokemon in the PC behind it, and the party menu is exactly where a player
  -- would see it claiming to be plain again.
  if deps.fusion and deps.fusion.settle(battle.data, mon) then return end
  if deps.persistent then
    deps.persistent.settle(battle.data, mon)
  end
end

return M
