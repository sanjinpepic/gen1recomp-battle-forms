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
-- to report to still must not silently keep the change.  deps.keyitems is not,
-- and deliberately so -- a gate that may be left out of the deps table is a
-- gate that is silently absent, which is precisely the state this file was in
-- before it had one.
--
-- deps.dragonascent and deps.zcrystals are optional the same way deps.log is:
-- a build where src/dragonascent.lua failed to load degrades to exactly the
-- two-tier gate every mega has always used, rather than taking mega evolution
-- down entirely over the one species that gets a second trigger.
--
-- deps.gen2 branches the whole entry onto Gold's own shape, the same flag
-- src/persistent.lua already reads.  Three things differ and nothing else
-- does -- the label, the once-per-battle bookkeeping and the Key Stone gate
-- above are identical on both games:
--
--   * WHICH ITEM COUNTS.  Gen 1 has no held-item slot, so a Mega Stone is a
--     bag-use stamp read through deps.eligibility.formForMon (mon[STAMP]).
--     Gold has a real one, and src/persistent.lua's own header explains why
--     the real held item is always asked over any stamp where both exist --
--     so the Gen 2 branch reads mon.item, given straight to
--     deps.eligibility.formFor the way src/persistent.lua's own Gen 2 read
--     does, never the stamp.
--   * WHICH PRIMITIVE APPLIES IT.  Gen 2 has no battler wrapper at all
--     (src/battlerof.lua's own header), so deps.forms.becomeForm -- built on
--     curStats/curTypes, fields that do not exist on a bare mon -- would
--     silently write nothing a damage or type check ever reads.
--     deps.gen2forms.becomeForm is the primitive that actually reaches
--     mon.stats and Battle.speciesDef there.
--   * WHAT ELSE ACTIVATING DOES.  Mega Rayquaza's own trigger
--     (deps.dragonascent) is Gen 1 only in this pass -- the exemption is
--     skipped outright on Gen 2 rather than guessed at, so a Gen 2 Rayquaza
--     still needs a Key Stone and a mega stone like every other species
--     until that trigger is ported. The message IS ported: deps.announce.
--     gen2Mega goes through Battle:emit, the same Gen 2 message channel
--     deps.announce.gen2Tera/gen2Primal/gen2UltraBurst already use, because
--     Gold's engine object has neither `say` nor `sayNext` for Gen 1's
--     battle:animNext/animationsOn pair below to reach through either way --
--     see deps.announce.gen2Mega's own header for why there is still no
--     animation to queue after it (Gold has no transformation-flash concept
--     for a mod to reach at all).
local M = {}

M.ID = "mega"

function M.entry(deps)
  return {
    id = M.ID,
    label = "MEGA",

    -- Two tiers, the trainer's before the Pokemon's, exactly as the real games
    -- ask them: no Key Stone means no mega whatever the mon in front is
    -- carrying.  Failing here is how the gate stays silent -- the cell is
    -- simply absent, the same as it is for an ineligible species, rather than
    -- appearing and then refusing.
    --
    -- A stone can also name a form the species table has no record for -- a
    -- wrong id in data/megas.lua, or national_dex data that never loaded -- and
    -- offering the cell then would arm a change Forms.becomeForm can only
    -- refuse.  The record must exist before the menu promises it.
    --
    -- Rayquaza's own trigger is asked FIRST and answers the whole question on
    -- its own when it fires: no Key Stone, no mega stone, refused only by a
    -- held Z-Crystal (src/dragonascent.lua).  It is scoped to exactly one
    -- species by construction -- M.formFor checks mon.species itself -- so
    -- asking it first costs every other mega nothing: for anything that is
    -- not an eligible Rayquaza it answers nil and the two-tier gate below
    -- runs exactly as it always has.
    available = function(battle)
      local mon = deps.battlerof.mon(battle.player)
      local pokemon = battle.data and battle.data.pokemon

      if deps.gen2 then
        if not deps.keyitems.held(battle, deps.keyitems.KEY_STONE) then
          return false
        end
        local formId = deps.eligibility.formFor(deps.megas, mon and mon.species,
                                                 mon and mon.item)
        if not formId then return false end
        return pokemon ~= nil and pokemon[formId] ~= nil
      end

      local exemptForm = deps.dragonascent
        and deps.dragonascent.formFor(deps.eligibility, deps.zcrystals, mon)
      if exemptForm then
        return pokemon ~= nil and pokemon[exemptForm] ~= nil
      end

      if not deps.keyitems.held(battle, deps.keyitems.KEY_STONE) then
        return false
      end
      local formId = deps.eligibility.formForMon(deps.megas, mon)
      if not formId then return false end
      return pokemon ~= nil and pokemon[formId] ~= nil
    end,

    -- Answers whether the battle's one mega was actually spent.  A refusal
    -- must not spend it: the player armed in good faith and nothing happened,
    -- so they keep the option for the rest of the fight.
    activate = function(battle)
      local battler = battle.player
      local mon = deps.battlerof.mon(battler)

      if deps.gen2 then
        local formId = deps.eligibility.formFor(deps.megas, mon and mon.species,
                                                 mon and mon.item)
        if not formId then return false end
        local ok, reason = deps.gen2forms.becomeForm(battle.data, mon, formId)
        if not ok then
          if deps.log then
            deps.log:warn(
              "battle_forms: refused mega for %s -> %s (%s) -- the "
                .. "national_dex record is missing, has no `form` field, or "
                .. "data/megas.lua names the wrong id",
              tostring(mon and mon.species), tostring(formId), tostring(reason))
          end
          return false
        end
        if deps.announce then deps.announce.gen2Mega(battle, mon) end
        return true
      end

      local formId = (deps.dragonascent
          and deps.dragonascent.formFor(deps.eligibility, deps.zcrystals, mon))
        or deps.eligibility.formForMon(deps.megas, mon)
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
