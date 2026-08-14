-- Primal reversion: the transformation nobody has to ask for.
--
-- Everything mega evolution needs -- a menu cell, an armed flag, one change
-- per battle per trainer -- this does without.  A Groudon holding the Red Orb
-- simply IS Primal Groudon the moment it is on the field, so there is no
-- state in this module at all: it answers the two events that put a mon on
-- the field and asks the same question of each battler it is handed.
--
-- Having no state is what makes the two transformation types independent
-- rather than merely separate.  A primal mon never touches src/arm.lua, so it
-- cannot spend the trainer's one mega for the battle; it is never in
-- data/megas.lua, so src/overlay.lua never offers it a MEGA cell; and because
-- the limit it would have to consume does not exist here, Groudon and Kyogre
-- can both revert in the same fight.
--
-- Only the entering half lives here.  Unwinding on faint and at battle end is
-- src/resolve.lua's, whose faint handler and party sweep revert any form on
-- any mon and were never mega-specific.
--
-- No animation, deliberately.  The mega animation exists to mark a change the
-- player watches happen mid-battle; this change has already happened by the
-- time there is anything to watch.  battle.started fires before the send-out
-- queue plays, and becomeForm rebuilds the battle picture itself on a
-- switch-in, so the mon is never drawn in its base form for an animation to
-- change it away from.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- becomeForm is idempotent, which is what makes this safe to call on every
-- switch-in without asking first whether the mon is already reverted: a
-- primal mon coming back from the bench arrives on the fresh, form-blind
-- battler makeBattler hands back, and needs exactly the same override applied
-- exactly the same way as one entering for the first time.
--
-- `source` names the handler and the battler so the diagnostic can tell "the
-- switch-in handler never ran" from "it ran and found no pairing"; deps.diag
-- is optional for the same reason deps.log is, and every early return reports
-- because each of them is a different reason for a Groudon that stays
-- ordinary.
local function transform(battle, battler, source)
  local mon = battler and battler.mon
  if not mon then
    if deps.diag then
      deps.diag.primal(source, battle, nil, nil, nil, "no mon on the battler")
    end
    return
  end
  local formId = deps.eligibility.formForMon(deps.primals, mon)
  if not formId then
    if deps.diag then
      deps.diag.primal(source, battle, mon, nil, nil,
        "no pairing in data/primals.lua for this species and stone")
    end
    return
  end

  -- Asked BEFORE becomeForm, and asked of the record rather than of the id,
  -- because mon.form carries the record's `form` suffix.  becomeForm being
  -- idempotent is what makes this handler safe to run on every switch-in and
  -- on adoption, but it also means a successful call is not the same thing as
  -- a change -- and a message on every reapplication would print "GROUDON's
  -- Primal Reversion!" each time an already-primal Groudon came back from the
  -- bench.
  local record = battle.data and battle.data.pokemon
    and battle.data.pokemon[formId]
  local already = record ~= nil and record.form ~= nil
    and mon.form == record.form

  local ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
  if deps.diag then
    deps.diag.primal(source, battle, mon, formId, ok, reason)
  end
  -- The real games print a line for this one, and it is the only signal it
  -- has: there is no animation by design and a primal keeps its species name,
  -- so before this the whole mechanic rested on one back sprite being present.
  if ok and not already and deps.announce then
    deps.announce.primal(battle, battler)
  end
  if not ok and deps.log then
    -- A guard that refuses must say so out loud.  There is no player action
    -- behind a primal reversion, so a silent refusal here would show as a
    -- Groudon that is simply never primal, with nothing anywhere to say why.
    deps.log:warn(
      "battle_forms: refused primal for %s -> %s (%s) -- the national_dex "
        .. "record is missing, has no `form` field, or data/primals.lua "
        .. "names the wrong id",
      tostring(mon.species), tostring(formId), tostring(reason))
  end
end

-- Both battlers, not just the player's.  The orb is the mon's own, the way a
-- held item is, so a trainer's Groudon reverts on the same terms the player's
-- does -- where the mega path is player-only because only the player can arm
-- one.
--
-- `ev.source` renames the two attempts for the diagnostic and nothing else.
-- src/adopt.lua calls this handler directly for a battle that started before
-- the mod existed, and a trace line claiming battle.started for an attempt
-- battle.started never made would answer the wrong question.
function M.onBattleStarted(ev)
  local battle = ev and ev.battle
  if not battle then return end
  local source = ev.source or "battle.started"
  transform(battle, battle.player, source .. " player")
  transform(battle, battle.enemy, source .. " enemy")
end

function M.onBattlerSwitched(ev)
  local battle = ev and ev.battle
  if not battle then return end
  transform(battle, ev.battler, "battler_switched")
end

return M
