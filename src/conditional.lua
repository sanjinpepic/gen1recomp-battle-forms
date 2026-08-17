-- Condition-driven form changes: the transformations that answer to the
-- battle rather than to the player.
--
-- Mega evolution is a decision and primal reversion is a held item.  These
-- are neither, so like src/primal.lua this module holds no state of its own:
-- every handler is given a battler and asks data/conditional.lua the same
-- question about it from scratch.  That is what makes the reversible rows
-- genuinely reversible -- a Darmanitan can cross its threshold as many times
-- as the fight lasts, because nothing here remembers which side it was on
-- last, and mon.form is read back out of the mon rather than tracked.
--
-- The forms primitive needed no extending for that.  becomeForm derives
-- curStats from the target record and revertForm derives them back from
-- mon.stats and the base species' own record -- neither caches a "before",
-- so A -> B -> A -> B is just four independent derivations.
--
-- Only the applying half lives here.  Unwinding on faint and at battle end is
-- src/resolve.lua's, whose faint handler and party sweep revert whatever form
-- a mon carries and never asked which transformation type put it there.
--
-- Nothing here can reach the mega path.  No species in this table is consulted
-- through data/megas.lua, so no MEGA cell appears for one and src/arm.lua's
-- once-per-battle flag is never touched; and enter() refuses outright to dress
-- a mon that is already wearing some other form, which is what keeps a
-- Greninja's mega safe from its own Battle Bond.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

local function rowFor(mon)
  if not mon or not mon.species then return nil end
  return deps.rows[mon.species]
end

-- mon.form carries the record's `form` suffix, not the record id, so asking
-- whether a mon is already in a row's form has to go through the record.  A
-- record that cannot be resolved answers "no", which puts the decision back on
-- becomeForm's own refusal instead of guessing here.
local function wearing(battle, mon, row)
  local record = battle.data and battle.data.pokemon
    and battle.data.pokemon[row.form]
  local suffix = record and record.form
  return suffix ~= nil and mon.form == suffix
end

-- deps.gen2/deps.gen2forms pick the primitive the exact way every other
-- form-changing module in this mod does. Nothing here needed an eligibility
-- substitution the way mega/primal did -- these forms carry no item and no
-- gate at all, so there is no Gen 1 bag stamp to have been reading in the
-- first place -- the ONLY thing wrong on Gold was the primitive itself:
-- deps.forms.becomeForm/revertForm are built on a battler.mon wrapper Gold's
-- raw mon never has, so `enter`/`leave` silently refused ("no_target") on
-- every one of the eight species this table names, event correctly
-- received, row correctly resolved, primitive finding nothing to write to.
--
-- `source` names the calling handler and `power` is a move_kind check's own
-- move power (nil everywhere else) -- both exist for deps.diag alone, the
-- same reason src/primal.lua's own transform() takes a `source` string.
-- Unlike primal.lua this module went a full release with NO tracing at all,
-- which is exactly what turned the Aegislash report into a guess: the event
-- reached, the row matched, and nothing said why the stance never changed.
local function enter(battle, battler, row, source, power)
  local mon = deps.battlerof.mon(battler)
  -- A conditional form only ever dresses a mon that is in its base form.
  -- Greninja is both a Battle Bond species and an extended mega, so a
  -- knockout can land on a mon that already spent the trainer's one mega for
  -- the battle -- and overwriting that would undo, silently and permanently,
  -- something the player only gets once.
  if mon.form and not wearing(battle, mon, row) then
    if deps.diag then
      deps.diag.conditional(source, battle, mon, row, power, "enter", false,
        "already wearing a different form")
    end
    -- Out loud even with DEBUG TRACE off (project rule #6), unlike every
    -- other refusal this module traces. Those are ordinary no-ops --
    -- `leave`'s own "not currently wearing this row's form" fires on most
    -- triggers most of the time by design. This one is not: under healthy
    -- play, nothing but THIS row's own form is ever set on a species this
    -- table names, so reaching here at all means either a legitimate,
    -- rare protection (a mega'd Greninja's Battle Bond) or exactly the
    -- shape the Aegislash/Draco Plate report turned out to be -- a form
    -- claim belonging to a species this mon is not, left standing by
    -- something outside this mod's own mechanics. Either way there is no
    -- player action behind the refusal for a trace to ever surface
    -- without tracing already switched on, which is what cost a full day
    -- before src/resolve.lua's own M.onBattleStarted started clearing the
    -- second case before it could ever reach here.
    if deps.log then
      deps.log:warn(
        "battle_forms: %s did not enter %s -- it is already wearing a "
          .. "different form (%s). If nothing else in this battle should "
          .. "have put one there, the held item stamped on this Pokemon "
          .. "may have no pairing for its species",
        tostring(mon.species), tostring(row.form), tostring(mon.form))
    end
    return
  end

  local ok, reason
  if deps.gen2 then
    ok, reason = deps.gen2forms.becomeForm(battle.data, mon, row.form)
  else
    ok, reason = deps.forms.becomeForm(battle.data, battler, row.form, battle)
  end
  if deps.diag then
    deps.diag.conditional(source, battle, mon, row, power, "enter", ok, reason)
  end
  if not ok and deps.log then
    -- A guard that refuses must say so out loud.  There is no player action
    -- behind any of these, so a silent refusal would show as a Darmanitan
    -- that simply never enters Zen Mode, with nothing anywhere to say why.
    deps.log:warn(
      "battle_forms: refused conditional form for %s -> %s (%s) -- the "
        .. "national_dex record is missing, has no `form` field, or "
        .. "data/conditional.lua names the wrong id",
      tostring(mon.species), tostring(row.form), tostring(reason))
  end
end

-- Only ever takes off the row's own form.  A mon wearing anything else is
-- wearing it because another transformation type put it there, and unwinding
-- that is not this module's to do.  Not wearing it at all is the common case
-- for every trigger but hp/turn_end (re-checked on a mon that never entered),
-- and traced anyway -- deps.diag.note collapses the repeats to one line, and
-- the alternative is a silent no-op indistinguishable from becomeForm having
-- refused.
local function leave(battle, battler, row, source, power)
  local mon = deps.battlerof.mon(battler)
  if not wearing(battle, mon, row) then
    if deps.diag then
      deps.diag.conditional(source, battle, mon, row, power, "leave", nil,
        "not currently wearing this row's form")
    end
    return
  end
  local ok, reason
  if deps.gen2 then
    ok, reason = deps.gen2forms.revertMon(mon, battle.data)
  else
    ok, reason = deps.forms.revertForm(battler, battle.data, battle)
  end
  if deps.diag then
    deps.diag.conditional(source, battle, mon, row, power, "leave", ok, reason)
  end
end

-- nil means the question cannot be answered -- a mon with no stat block or no
-- current HP -- which is a different answer from "no" and must not be acted on.
local function hpWants(row, mon)
  local max = mon.stats and mon.stats.hp
  if not max or max <= 0 or not mon.hp then return nil end
  if row.minLevel and (mon.level or 0) < row.minLevel then return false end
  local fraction = mon.hp / max
  if row.below then return fraction <= row.below end
  if row.above then return fraction > row.above end
  return nil
end

-- `force` is for a battler that just arrived on the field.  makeBattler is
-- form-blind: mon.form survived the bench but curStats and curTypes came back
-- seeded from the base species, so a mon whose condition still holds needs the
-- override applied again even though it already reads as wearing the form.
local function syncHp(battle, battler, force, source)
  local mon = deps.battlerof.mon(battler)
  local row = rowFor(mon)
  if not row or row.trigger ~= "hp" then return end
  -- A fainting mon is the faint handler's; dressing it on the way down would
  -- be undone a moment later anyway.
  if (mon.hp or 0) <= 0 then return end

  local want = hpWants(row, mon)
  if want == nil then return end
  if want then
    if force or not wearing(battle, mon, row) then
      enter(battle, battler, row, source)
    end
  else
    leave(battle, battler, row, source)
  end
end

-- Both halves of arriving on the field.  An HP row is re-derived from
-- scratch, because the answer can have changed while the mon was benched;
-- every other row is only reapplied, because its trigger is an event that
-- happened once and cannot be asked again.
local function onEnterField(battle, battler, source)
  local mon = deps.battlerof.mon(battler)
  local row = rowFor(mon)
  if not row then return end
  if row.trigger == "hp" then
    syncHp(battle, battler, true, source)
  elseif wearing(battle, mon, row) then
    enter(battle, battler, row, source)
  end
end

-- Both battlers, not just the player's.  Nothing here is the trainer's to
-- carry or to press, so a wild Darmanitan enters Zen Mode on the same terms
-- the player's does.
function M.onBattleStarted(ev)
  local battle = ev and ev.battle
  if not battle then return end
  onEnterField(battle, battle.player, "battle.started player")
  onEnterField(battle, battle.enemy, "battle.started enemy")
end

function M.onBattlerSwitched(ev)
  local battle = ev and ev.battle
  if not battle then return end
  onEnterField(battle, ev.battler, "battler_switched")
end

function M.onMoveUsed(ev)
  local battle = ev and ev.battle
  local user = ev and ev.user
  local mon = deps.battlerof.mon(user)
  local row = battle and rowFor(mon)
  if not row or row.trigger ~= "move_kind" then
    -- A row that matched a DIFFERENT trigger (Darmanitan attacking, say) is
    -- traced too: a silent return here looks identical, from a chair in
    -- front of the game, to the row never being found at all.
    if row and deps.diag then
      deps.diag.conditional("move_used", battle, mon, row, nil, "skip", nil,
        "this row's trigger is " .. tostring(row.trigger) .. ", not move_kind")
    end
    return
  end
  if (mon.hp or 0) <= 0 then return end

  -- Gen 1 has no category field on a move record and splits physical from
  -- special by type, so power is what separates an attack from a stance:
  -- every damaging move has some and every status move has none.
  local power = (ev.move and ev.move.power) or 0
  if power > 0 then
    if wearing(battle, mon, row) then
      if deps.diag then
        deps.diag.conditional("move_used", battle, mon, row, power, "skip",
          nil, "already wearing this row's form")
      end
    else
      enter(battle, user, row, "move_used", power)
    end
  else
    leave(battle, user, row, "move_used", power)
  end
end

function M.onDamageDealt(ev)
  local battle = ev and ev.battle
  if not battle then return end

  local target = ev.target
  local hurt = deps.battlerof.mon(target)
  if hurt and (hurt.hp or 0) > 0 then
    syncHp(battle, target, nil, "damage_dealt hp")
    local row = rowFor(hurt)
    if row and row.trigger == "hit_taken" and (ev.damage or 0) > 0
      and not wearing(battle, hurt, row) then
      enter(battle, target, row, "damage_dealt hit_taken")
    end
  end

  -- The knockout half reads the same payload from the other end.  It fires
  -- after the HP write, so a target sitting at zero is one this hit just
  -- knocked out -- and battle.fainted, the only other candidate, names the
  -- mon that fell but never the one that felled it.
  local user = ev.user
  local dealer = deps.battlerof.mon(user)
  if dealer and hurt and (hurt.hp or 0) <= 0 and (dealer.hp or 0) > 0 then
    local row = rowFor(dealer)
    if row and row.trigger == "knockout_dealt" and not wearing(battle, dealer, row) then
      enter(battle, user, row, "damage_dealt knockout_dealt")
    end
  end
end

local function endOfTurn(battle, battler, source)
  local mon = deps.battlerof.mon(battler)
  local row = rowFor(mon)
  if not row or (mon.hp or 0) <= 0 then return end
  if row.trigger == "hp" then
    -- The catch-up pass.  Gen 1 raises battle.damage_dealt only from the
    -- damaging-move hit loop, so recoil, poison, burn, Leech Seed and a
    -- healing item all move the HP with nothing emitted -- and a threshold
    -- crossed that way would otherwise go unnoticed until the next attack.
    syncHp(battle, battler, nil, source)
  elseif row.trigger == "turn_end" then
    -- Alternates rather than settling: being in one of the two forms at the
    -- close of every round is the whole of the mechanic.
    if wearing(battle, mon, row) then
      leave(battle, battler, row, source)
    else
      enter(battle, battler, row, source)
    end
  end
end

function M.onTurnEnded(ev)
  local battle = ev and ev.battle
  if not battle then return end
  endOfTurn(battle, battle.player, "turn_end player")
  endOfTurn(battle, battle.enemy, "turn_end enemy")
end

return M
