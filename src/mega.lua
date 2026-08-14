-- Mega evolution as one entry in the manual-transformation registry, rather
-- than as the menu's only reason to exist.  Everything that is true of megaing
-- and of nothing else lives here: the label the cell reads, whether the mon in
-- front may mega at all, and what happens when its armed flag comes due.
--
-- The activation is called from battle.turn_started, after both actions are
-- chosen and before turn order is decided.  Nothing here runs inside
-- performMove, which is the whole point of that placement: a change that was
-- never a move cannot spend PP, be Disabled, or be picked up by Metronome or
-- Mirror Move.  That guarantee is structural, not a check.
--
-- deps.log is optional: main.lua passes mod.log, but the unit suites bind
-- without one so they can run outside the engine, and a refusal with nowhere
-- to report to still must not silently keep the change.
local M = {}

M.ID = "mega"

function M.entry(deps)
  return {
    id = M.ID,
    label = "MEGA",

    -- A stone can name a form the species table has no record for -- a wrong
    -- id in data/megas.lua, or national_dex data that never loaded -- and
    -- offering the cell then would arm a change Forms.becomeForm can only
    -- refuse.  The record must exist before the menu promises it.
    available = function(battle)
      local mon = battle.player and battle.player.mon
      local formId = deps.eligibility.formForMon(deps.megas, mon)
      if not formId then return false end
      local pokemon = battle.data and battle.data.pokemon
      return pokemon ~= nil and pokemon[formId] ~= nil
    end,

    -- Answers whether the battle's one mega was actually spent.  A refusal
    -- must not spend it: the player armed in good faith and nothing happened,
    -- so they keep the option for the rest of the fight.
    activate = function(battle)
      local battler = battle.player
      local mon = battler and battler.mon
      local formId = deps.eligibility.formForMon(deps.megas, mon)
      if not formId then return false end

      local ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
      if not ok then
        -- A guard that refuses must say so out loud: this exact silent path
        -- (a mega table pointing at a name field instead of a record key)
        -- once shipped a whole release where arming did nothing and nothing
        -- logged.
        if deps.log then
          deps.log:warn(
            "battle_forms: refused mega for %s -> %s (%s) -- the national_dex "
              .. "record is missing, has no `form` field, or data/megas.lua "
              .. "names the wrong id",
            tostring(mon and mon.species), tostring(formId), tostring(reason))
        end
        return false
      end

      -- Announced before the animation is queued, so the line reads first and
      -- the flash follows it.  It is announced at all because the animation is
      -- the only other thing that marks this: the armed marker went with the
      -- cell the moment the battle's one mega was spent, and a player who
      -- turned battle animations off is left with a mega that changed the
      -- stats, the types and the picture without saying anything.
      if deps.announce then deps.announce.mega(battle, battler) end

      -- The form change must not depend on the animation: a player who turned
      -- battle animations off asked for exactly that and still gets the mega.
      if battle.animationsOn and battle:animationsOn() then
        battle:animNext(deps.animId, battler.isPlayer)
      end
      return true
    end,
  }
end

return M
