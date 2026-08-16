-- Ultra Burst: the last unimplemented in-battle gimmick, and the only one
-- here gated on three things standing together rather than two.
--
-- The real games ask a Necrozma holding Ultranecrozium Z, a trainer carrying
-- the Z-Power Ring, AND a Pokemon already fused into Dusk Mane or Dawn Wings
-- -- fusion has to have happened first, through src/fusion.lua and an
-- N-Solarizer or an N-Lunarizer, in an earlier battle or the overworld,
-- because fusion items are `battle = false` and cannot be used mid-fight.
-- Three gates, but no new machinery for any of them: the Z-Ring is the one
-- this mod already has (src/keyitems.lua), Ultranecrozium Z stamps the same
-- eligibility.STAMP field a mega stone or a type Z-Crystal does, and "already
-- fused" is answered by asking src/fusion.lua whether the mon carries its own
-- stamp -- nothing here invents a fourth field to track what two existing ones
-- already say between them.
--
-- WHY THE THIRD GATE IS A SEPARATE CHECK RATHER THAN A SECOND PAIRING TABLE.
-- data/ultraburst.lua answers "does this species, holding this item, become
-- this form" the way data/megas.lua does, and that alone would let a PLAIN
-- Necrozma holding Ultranecrozium Z burst -- wrong, because the item's own
-- fine print is the fused state, not the species.  Necrozma stays exactly one
-- key in that table and the fusion check stands beside it instead, which is
-- also what keeps the two mechanics from needing to know about each other:
-- fusion has no idea Ultra Burst exists, and this file needs nothing about
-- fusion beyond the one question src/fusion.lua already answers.
--
-- WHY IT DOES NOT SPEND A SECOND HELD-ITEM SLOT.  A Necrozma is stamped with
-- Ultranecrozium Z the exact way a Charizard is stamped with Charizardite X --
-- through src/stone.lua's PAIRED install, so a fused Necrozma given a Z-Crystal
-- instead loses the crystal that makes Ultra Burst possible, and a Necrozma
-- given a Z-Crystal cannot also be offered a Z-Move for a type it holds no
-- crystal for, because src/zmoves.lua's own catalog carries no entry for
-- ULTRANECROZIUM_Z.  Both follow from the one stamp without a line of code
-- here that mentions Z-Moves at all.
--
-- DURATION.  Like mega evolution and unlike Dynamax: it survives switching
-- out, and ends only on fainting or at the battle's end -- which is also why
-- this needs its own switch-in reapplication rather than resolve.lua's mega
-- path (that one keys off data/megas.lua, and Necrozma is never in it).  On
-- both of those ends, the generic party sweep (src/resolve.lua) and the faint
-- handler already do the right thing without this file's help: they ask
-- src/fusion.lua before touching mon.form at all, and a still-fused Necrozma
-- answers back with its Dusk Mane or Dawn Wings suffix, so an Ultra Necrozma
-- reverts to the fused form it burst FROM, not to a plain Necrozma the fusion
-- never stopped being true of.
local M = {}

M.ID = "ultraburst"

local deps = nil

function M.bind(modules) deps = modules end

-- One record, like Terastallization's and for the same reason: only the
-- player's side can reach the menu cell and the trainer gets one activation a
-- battle, so there is never a second Ultra Burst to track in the same fight.
function M.new()
  return { mon = nil }
end

local function clear(state)
  state.mon = nil
end

function M.entry(state)
  return {
    id = M.ID,
    -- Seven characters is the whole budget the classic layout leaves a label
    -- once the armed '*' and the cycle marker have taken theirs
    -- (tests/battle_forms_menu_test.lua measures it), and ULTRA BURST is
    -- nowhere near fitting two words into it.  BURST is what is left once MEGA
    -- already claims the mainline's own habit of naming a gimmick by its verb
    -- rather than its noun.
    label = "BURST",

    -- Three tiers rather than mega evolution's two: the trainer's Z-Ring, the
    -- crystal on the Pokemon (folded into the eligibility lookup below, the
    -- same as a mega stone's pairing), and the fused state src/fusion.lua
    -- alone can answer.  Failing any of them is how the gate stays silent --
    -- the cell is simply absent, never present and refusing.
    available = function(battle)
      if not deps.keyitems.held(battle, deps.keyitems.Z_RING) then
        return false
      end
      local mon = deps.battlerof.mon(battle.player)
      if not mon then return false end
      if not deps.fusion.partnerOf(mon) then return false end
      local formId = deps.eligibility.formForMon(deps.rows, mon)
      if not formId then return false end
      local pokemon = battle.data and battle.data.pokemon
      return pokemon ~= nil and pokemon[formId] ~= nil
    end,

    -- Answers whether the battle's one manual transformation was actually
    -- spent.  A refusal must not spend it: the player armed in good faith and
    -- nothing happened, so they keep the option for the rest of the fight.
    activate = function(battle)
      local battler = battle.player
      local mon = deps.battlerof.mon(battler)
      if not mon then return false end
      local formId = deps.eligibility.formForMon(deps.rows, mon)
      if not formId then return false end

      local ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
      if not ok then
        -- A guard that refuses must say so out loud, the way mega evolution's
        -- does for the same shape of mistake: a national_dex record missing,
        -- or data/ultraburst.lua naming the wrong id.
        if deps.log then
          deps.log:warn(
            "battle_forms: refused Ultra Burst for %s -> %s (%s) -- the "
              .. "national_dex record is missing, has no `form` field, or "
              .. "data/ultraburst.lua names the wrong id",
            tostring(mon.species), tostring(formId), tostring(reason))
        end
        return false
      end

      -- Tracked so the switch-in handler below knows which mon, in THIS
      -- battle, actually burst -- a fresh Necrozma sent out later holding the
      -- same crystal, in the same fight, must not be mistaken for the one
      -- that already spent the trainer's one transformation.
      state.mon = mon

      if deps.announce then deps.announce.ultraBurst(battle, battler) end

      -- The form change must not depend on the animation: a player who turned
      -- battle animations off asked for exactly that and still gets it.
      if battle.animationsOn and battle:animationsOn() then
        battle:animNext(deps.animId, battler.isPlayer)
      end
      return true
    end,
  }
end

-- Switching out does NOT end it, the way mega evolution's does not and
-- Dynamax's does.  makeBattler is form-blind and seeds a fresh battler's
-- curStats/curTypes from the base species on every send-out, so the override
-- has to be put back on the mon that already burst -- tracked by identity in
-- `state.mon` rather than re-derived from data/ultraburst.lua's pairing,
-- because the item and the fused state cannot change mid-battle (both are
-- stamped through `battle = false` effects) and the mon leaving the field is
-- therefore the only thing that could end this early.
function M.onBattlerSwitched(state, ev)
  local battle = ev and ev.battle
  local battler = ev and ev.battler
  local mon = deps.battlerof.mon(battler)
  if not battle or not mon or state.mon ~= mon then return end

  local formId = deps.eligibility.formForMon(deps.rows, mon)
  if not formId then
    -- Vanishingly unlikely in a single battle -- the crystal and the fusion
    -- cannot move while the fight is on -- but a guard that refuses must say
    -- so out loud rather than leave a mon showing Ultra Necrozma's picture
    -- with base stats behind it.
    if deps.log then
      deps.log:warn(
        "battle_forms: %s switched in mid-Ultra-Burst but is no longer "
          .. "eligible for it -- stats and types were not reapplied",
        tostring(mon.species))
    end
    return
  end

  local ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
  if not ok and deps.log then
    deps.log:warn(
      "battle_forms: refused to reapply Ultra Burst for %s -> %s (%s) on "
        .. "switch-in", tostring(mon.species), tostring(formId), tostring(reason))
  end
end

-- Fainting ends it (section 8 of the implementation guide).  src/resolve.lua's
-- faint handler runs first and reverts whatever mon.form the mon carries --
-- down to nil and then, since the mon is still fused, straight back up to its
-- Dusk Mane or Dawn Wings suffix through src/fusion.lua's own settle -- so
-- this only has to drop the reference tracking which mon was mid-Ultra-Burst.
function M.onFainted(state, ev)
  local mon = deps.battlerof.mon(ev and ev.battler)
  if not mon or state.mon ~= mon then return end
  clear(state)
end

function M.onBattleStarted(state)
  clear(state)
end

-- The battle ending unwinds it everywhere src/resolve.lua's party sweep
-- already reaches, the same way mega evolution needs nothing here beyond
-- dropping its own tracked mon.
function M.onBattleEnded(state)
  clear(state)
end

return M
