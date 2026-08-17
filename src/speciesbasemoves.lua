-- The base moves eleven species Z-Crystals key off, shipped in 0.27.0 and
-- registered by National Dex with `effectModeled = false` -- which its own
-- policy (src/moves.lua's own header there: "only a move whose
-- effectModeled is true may ever reach a learnset") permanently bars from
-- every learnset it builds, MOVES=ALL included.  A crystal whose base move
-- nothing can ever be taught is a crystal a player can never trigger, and
-- that was true of Pikashunium Z, Snorlium Z, Decidium Z, Incinium Z,
-- Primarium Z, Lycanium Z, Mimikium Z, Kommonium Z, Solganium Z, Lunalium Z
-- and Marshadium Z from the moment they shipped.
--
-- WHY PATCHING effectModeled ALONE DOES NOT FIX THIS.  National Dex's own
-- MOVES=ALL widening reads `record.effectModeled` at ITS OWN install time
-- (src/moves.lua: "if record.effectModeled == true then allowed[id] = true
-- end"), which runs before this mod's dependent install ever gets a turn --
-- national_dex loads first, battle_forms depends on it.  Flipping the flag
-- true from here, the way this file does for the ten it actually models,
-- is the honest thing to claim and nothing more: it cannot retroactively
-- add a row to a learnset shard national_dex already decided not to widen.
-- Reachability therefore has to come from THIS file directly patching each
-- species' own `learnset`, exactly the shape src/dragonascent.lua and
-- src/terablasttm.lua already established for the same reason -- a feature
-- built on a move nothing can know is unreachable no matter how correct its
-- mechanism is.
--
-- THE RULE EVERY ROW BELOW IS HELD TO: model the move's real effect, or
-- refuse the move.  A move flagged `effectModeled = true` with no real
-- behaviour behind it is worse than the `false` it replaces, because that
-- flag is the one thing standing between an unmodelled move and a player's
-- learnset -- these eleven are the proof it works, and stubbing one to make
-- a crystal light up would spend that proof to fake a light.  Ten of the
-- eleven have a real effect this engine's move_effects surface can express;
-- one does not, and is refused rather than fabricated -- see SPIRITSHACKLE
-- below.
--
-- SUNSTEELSTRIKE and MOONGEISTBEAM are the one case that needed thinking
-- through rather than assuming.  Their entire real effect beyond ordinary
-- damage is "ignores the target's ability" -- and this engine has no
-- abilities at all, not a partial implementation of them, none.  There is
-- therefore nothing left over for a handler to model: a plain damaging move
-- is not a stub standing in for "ignores abilities" here, it IS the whole
-- of what that clause could ever mean against an ability-less target.  This
-- is a different shape from SPIRITSHACKLE's refusal below, where the
-- missing piece (blocking a switch) is a mechanic this engine's battles
-- genuinely have -- Pokemon switch, Wrap-style trapping exists -- and is
-- merely unreachable from a mod without changing engine code neither this
-- project's rules nor this task allow touching.  "The concept does not
-- exist here" and "the concept exists but nothing lets a mod reach it" are
-- not the same refusal, and only the first licenses calling plain damage a
-- complete model rather than a stub of one.
local M = {}

-- deps.gen2 is read for exactly one thing: which FIELD M.install's own
-- learnset patch has to land in. national_dex's own src/gen2shape.lua folds
-- `learnset` into `levelMoves` for every species it registers on a Gold
-- boot and strips `learnset` outright (its own GEN1_ONLY set), so a species
-- patched here the same way src/dragonascent.lua's own RAYQUAZA patch used
-- to be would silently teach a field Mon.movesAtLevel never reads -- the
-- identical bug that mechanism carried through 0.53.0, found and fixed
-- there first; see M.install's own header for the full reasoning, not
-- repeated here.
local deps = nil
function M.bind(modules) deps = modules end

-- Every id this file registers wears the mod's name, the same discipline
-- src/dragonascent.lua's own EFFECT and src/speciesz.lua's own PREFIX
-- follow: a collision is a load failure for whichever registers second.
M.PREFIX = "BATTLE_FORMS_"

local RomText = require("src.core.RomText")
local Strings = require("src.core.Strings")

-- ---------------------------------------------------------------------
-- VOLT TACKLE (Pikachu, Pikashunium Z).  Real effect: one third of the
-- damage dealt returned as recoil, plus a 10% chance to paralyze the
-- target -- not RECOIL_EFFECT's generic one quarter (Take Down,
-- Double-Edge), which would understate the cost the real move actually
-- charges its own user.
-- ---------------------------------------------------------------------
function M.voltTackleEffect()
  return {
    kind = "secondary",
    afterDamage = function(ctx)
      local recoil = math.max(1, math.floor(ctx.totalDealt / 3))
      ctx.say(RomText(ctx.battle.data, "_HitWithRecoilText",
        "%s's\nhit with recoil!", ctx.displayName(ctx.user)))
      ctx.battle:applyDamage(ctx.user, recoil)
    end,
    -- The same 26/256 (~10%) threshold this engine's own
    -- PARALYZE_SIDE_EFFECT1 already rolls at (game/src/battle/
    -- MoveEffects.lua), reached through ctx.inflict rather than the
    -- private `inflictStatus` local that helper closes over, since that
    -- local is not part of the ctx surface a mod's own effect can reach.
    run = function(ctx)
      if ctx.rng(0, 255) >= 26 then return {} end
      return ctx.inflict(ctx.target, "PAR",
        { moveType = ctx.move.type, secondary = true, source = ctx.move.id })
    end,
  }
end

-- ---------------------------------------------------------------------
-- GIGA IMPACT (Snorlax, Snorlium Z).  Real effect: the user must recharge
-- next turn unless the hit faints its target -- exactly HYPER_BEAM_EFFECT's
-- own rule (game/src/battle/MoveEffects.lua), because that IS Giga Impact's
-- real effect in the source games, not merely a similar one.  Repointing at
-- the engine's own native id rather than reimplementing it is the more
-- honest choice available: it is already the exact mechanism, already
-- tested by every Hyper Beam suite this engine ships, and inventing a
-- second copy of it here would only be an opportunity for the two to drift
-- apart.  No move_effects registration of this file's own follows from
-- that -- HYPER_BEAM_EFFECT is registered unconditionally by the engine
-- itself, not by this mod, so there is nothing to add to the registry.
-- ---------------------------------------------------------------------
M.GIGA_IMPACT_EFFECT_ID = "HYPER_BEAM_EFFECT"

-- ---------------------------------------------------------------------
-- DARKEST LARIAT (Incineroar, Incinium Z).  Real effect: damage that
-- ignores the target's own stat stage changes, positive or negative.  Only
-- the target's Defense stage actually feeds Damage.compute for a physical
-- hit (game/src/battle/Damage.lua's own atk/dfn split), so zeroing that one
-- field for the one damage calculation this handler drives -- and
-- restoring it immediately after, since ctx.target is the live battler
-- table every other stat effect in this codebase already mutates directly
-- (src/dragonascent.lua's changeStage, the engine's own TRANSFORM_EFFECT)
-- -- is the complete, minimal model of "ignores the target's stat
-- changes" for what this engine's damage formula actually reads.
-- ---------------------------------------------------------------------
function M.darkestLariatEffect()
  return {
    kind = "secondary",
    chooseDamage = function(ctx)
      local target = ctx.target
      local stages = target.stages
      local saved = stages and stages.defense
      if stages then stages.defense = nil end
      local dmg, info = ctx.computeDamage()
      if stages then stages.defense = saved end
      return dmg, info
    end,
  }
end

-- ---------------------------------------------------------------------
-- SPARKLING ARIA (Primarina, Primarium Z).  Real effect: cures the
-- target's burn after the hit lands, unconditionally when the target is
-- burned and doing nothing otherwise -- not a chance, and not gated on a
-- substitute, matching HAZE_EFFECT's own unconditional
-- `target.mon.status = nil` (game/src/battle/MoveEffects.lua) for "the
-- target's status is removed" having no substitute check anywhere in this
-- engine's own precedent for that shape of effect.
-- ---------------------------------------------------------------------
function M.sparklingAriaEffect()
  return {
    kind = "secondary",
    run = function(ctx)
      local target = ctx.target
      if target.mon.status ~= "BRN" then return {} end
      target.mon.status = nil
      return { Strings("%s's\nburn was healed!", ctx.displayName(target)) }
    end,
  }
end

-- ---------------------------------------------------------------------
-- STONE EDGE (Lycanroc, all three formes, Lycanium Z).  Real effect: a
-- high critical-hit ratio, and nothing else -- the exact shape
-- game/src/battle/Damage.lua already carries a field for.  `highCrit` on
-- the move record wins over the HIGH_CRIT id list Slash/Karate
-- Chop/Razor Leaf/Crabhammer use (Damage.critRoll: "the move-record
-- highCrit field wins"), so this needs no move_effects handler of its
-- own at all -- the patch below IS the complete model, the same way a
-- Z-Crystal item needs no code beyond its own registration.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- PLAY ROUGH (Mimikyu, Mimikium Z).  Real effect: a 10% chance to lower
-- the target's Attack by one stage after the hit -- the same 26/256
-- threshold Volt Tackle's own paralysis chance above reuses, and the same
-- fromEnemy=false choice this engine's own ATTACK_DOWN_SIDE_EFFECT makes
-- (game/src/battle/MoveEffects.lua's statDownSide): a side effect's own
-- handler never runs MoveHitTest, so it pierces Mist the way every other
-- Gen 1 secondary stat-drop does, with the substitute check taken on
-- explicitly since fromEnemy=false skips changeStage's own one.
-- ---------------------------------------------------------------------
function M.playRoughEffect()
  return {
    kind = "secondary",
    run = function(ctx)
      local target = ctx.target
      if target.substituteHP then return {} end
      if ctx.rng(0, 255) >= 26 then return {} end
      return ctx.changeStage(target, "attack", -1, false)
    end,
  }
end

-- ---------------------------------------------------------------------
-- CLANGING SCALES (Kommo-o, Kommonium Z).  Real effect: the user's own
-- Defense falls one stage after the hit, unconditionally -- the same
-- self-lowering shape src/dragonascent.lua built for Dragon Ascent, one
-- stat instead of two.
-- ---------------------------------------------------------------------
function M.clangingScalesEffect()
  return {
    kind = "secondary",
    run = function(ctx)
      return ctx.changeStage(ctx.user, "defense", -1, false)
    end,
  }
end

-- ---------------------------------------------------------------------
-- SUNSTEEL STRIKE (Solgaleo, Solganium Z) and MOONGEIST BEAM (Lunala,
-- Lunalium Z).  Real effect: ignores the target's ability.  This engine
-- has none, so a plain damaging move is the complete model rather than a
-- stub of one -- see this file's own header for why that is not the same
-- claim SPIRITSHACKLE's refusal below declines to make.  Neither move
-- needs a move_effects handler or a patch beyond the honest flag.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- SPECTRAL THIEF (Marshadow, Marshadium Z).  Real effect: steals every
-- positive stat stage the target is carrying -- across every stage this
-- engine actually tracks (attack, defense, speed, special, accuracy,
-- evasion; STAT_LABEL in game/src/battle/MoveEffects.lua names the same
-- six) -- onto the user, before the hit, and this happens whether or not
-- the move goes on to land.  `beforeAccuracy` is the one stage callback
-- EffectRegistry.runDamaging calls before the accuracy roll
-- (game/src/battle/EffectRegistry.lua: gate, hit count, beforeAccuracy,
-- THEN the accuracy roll), which is exactly that timing -- and it runs
-- unconditionally regardless of what the roll decides afterward, matching
-- the real move.
-- ---------------------------------------------------------------------
local STEALABLE_STAGES = { "attack", "defense", "speed", "special",
                           "accuracy", "evasion" }

function M.spectralThiefEffect()
  return {
    kind = "secondary",
    beforeAccuracy = function(ctx)
      local user, target = ctx.user, ctx.target
      target.stages = target.stages or {}
      user.stages = user.stages or {}
      local stole = false
      for _, stat in ipairs(STEALABLE_STAGES) do
        local amount = target.stages[stat] or 0
        if amount > 0 then
          user.stages[stat] = math.min(6, (user.stages[stat] or 0) + amount)
          target.stages[stat] = 0
          stole = true
        end
      end
      if stole then
        ctx.say(Strings("%s stole\n%s's boosted stats!",
          ctx.displayName(user), ctx.displayName(target)))
      end
    end,
  }
end

-- ---------------------------------------------------------------------
-- SPIRIT SHACKLE (Decidueye, Decidium Z) -- REFUSED, not merely
-- unfinished.  Its real effect beyond ordinary damage is preventing the
-- target from switching out, and unlike SUNSTEELSTRIKE/MOONGEISTBEAM
-- above this is not a concept this engine lacks: Pokemon switch, and
-- Wrap-style multi-turn trapping already exists (TRAPPING_EFFECT,
-- game/src/battle/MoveEffects.lua).  What does not exist is any seam a
-- mod can reach to gate a switch DECISION -- no Runtime event fires
-- before one, unlike battle.damage_dealt or battle.battler_switched
-- (which only reports one after the fact), and Gen 1's own engine
-- (game/src/battle/BattleState.lua) carries no canSwitch/blockSwitch/
-- trapped concept at all, unlike Gen 2's EFFECT_MEAN_LOOK
-- (game/src/battle/gen2/Battle.lua).  Building one would mean patching
-- the party-switch or run-away decision inside game/ itself, which both
-- this task and the project's own standing rule ("nothing may require an
-- engine change") rule out.  Registering Spirit Shackle as plain damage
-- and flagging it effectModeled = true would therefore be exactly the
-- stub this file's header forbids -- switch-blocking is real, reachable
-- in principle, and simply not reachable from here -- so Decidium Z ships
-- 0.36.0 exactly as unreachable as it has been since 0.27.0, and stays
-- named here rather than silently dropped.
-- ---------------------------------------------------------------------
M.REFUSED = {
  { crystal = "DECIDIUM_Z", move = "SPIRITSHACKLE", species = { "DECIDUEYE" },
    reason = "Spirit Shackle's real effect prevents the target switching "
      .. "out, and this Gen 1 engine has no seam a mod can reach to block "
      .. "a switch decision -- building one would be an engine change" },
}

-- Every base move this file actually teaches: the National Dex move id,
-- the species (or, for Lycanroc, every one of its three formes) to append
-- it to at level 1 (src/dragonascent.lua's own precedent for "a Pokemon
-- simply has this move" rather than a TM item, since each of these is a
-- species-crystal pairing exactly like Rayquaza's own), and, where the
-- move needs one, the effect id to patch onto it plus the record to
-- register it under.  A row with neither `effectId` nor `extra` teaches
-- the move as plain damage and flags it modelled on the strength of this
-- file's own header reasoning (SUNSTEELSTRIKE, MOONGEISTBEAM); a row
-- naming `effectId` alone with no `effectRecord` repoints at an
-- ALREADY-registered engine-native effect rather than adding one
-- (GIGAIMPACT); `extra` carries move-record fields beyond `effect` itself
-- (STONEEDGE's `highCrit`).
M.ROWS = {
  { move = "VOLTTACKLE", species = { "PIKACHU" }, level = 1,
    effectId = M.PREFIX .. "VOLT_TACKLE_EFFECT",
    effectRecord = M.voltTackleEffect },
  { move = "GIGAIMPACT", species = { "SNORLAX" }, level = 1,
    effectId = M.GIGA_IMPACT_EFFECT_ID },
  { move = "DARKESTLARIAT", species = { "INCINEROAR" }, level = 1,
    effectId = M.PREFIX .. "DARKEST_LARIAT_EFFECT",
    effectRecord = M.darkestLariatEffect },
  { move = "SPARKLINGARIA", species = { "PRIMARINA" }, level = 1,
    effectId = M.PREFIX .. "SPARKLING_ARIA_EFFECT",
    effectRecord = M.sparklingAriaEffect },
  { move = "STONEEDGE",
    species = { "LYCANROC", "LYCANROC_MIDNIGHT", "LYCANROC_DUSK" }, level = 1,
    extra = { highCrit = true } },
  { move = "PLAYROUGH", species = { "MIMIKYU" }, level = 1,
    effectId = M.PREFIX .. "PLAY_ROUGH_EFFECT",
    effectRecord = M.playRoughEffect },
  { move = "CLANGINGSCALES", species = { "KOMMO_O" }, level = 1,
    effectId = M.PREFIX .. "CLANGING_SCALES_EFFECT",
    effectRecord = M.clangingScalesEffect },
  { move = "SUNSTEELSTRIKE", species = { "SOLGALEO" }, level = 1 },
  { move = "MOONGEISTBEAM", species = { "LUNALA" }, level = 1 },
  { move = "SPECTRALTHIEF", species = { "MARSHADOW" }, level = 1,
    effectId = M.PREFIX .. "SPECTRAL_THIEF_EFFECT",
    effectRecord = M.spectralThiefEffect },
}

-- Registers every custom effect this file needs, patches each move's
-- `effect` (where one of the rows above names a different id from what it
-- already has) and `effectModeled = true`, then teaches the move to every
-- species the row names -- each guarded independently on that base actually
-- existing, read back live off the merged registry the same way
-- src/dragonascent.lua's own M.install is, and for the same reason: an
-- unguarded patch against a missing id does not fail, Registry.lua's
-- fold() folds a missing base to `{}` and merges straight onto it, so a
-- guard that refuses must say so out loud rather than manufacture a
-- partial record.  Species are patched independently of each other
-- (Lycanroc's three formes) so one missing forme -- most plausibly because
-- NATIONAL DEX is off and only some of a family registered -- never holds
-- the other two hostage.
function M.install(mod)
  local moves = mod.content and mod.content.moves
  local pokemon = mod.content and mod.content.pokemon

  for _, row in ipairs(M.ROWS) do
    local moveBase = moves and type(moves.get) == "function"
      and moves:get(row.move)
    if type(moveBase) == "table" then
      if row.effectRecord then
        mod.content.move_effects:register(row.effectId, row.effectRecord())
      end
      local patch = { effectModeled = true }
      if row.effectId then patch.effect = row.effectId end
      if row.extra then
        for key, value in pairs(row.extra) do patch[key] = value end
      end
      mod.content.moves:patch(row.move, patch)

      for _, species in ipairs(row.species) do
        local speciesBase = pokemon and type(pokemon.get) == "function"
          and pokemon:get(species)
        if type(speciesBase) == "table" then
          local field = (deps and deps.gen2) and "levelMoves" or "learnset"
          mod.content.pokemon:patch(species, {
            [field] = { __append = { { level = row.level, move = row.move } } },
          })
        elseif mod.log then
          mod.log:warn(
            "battle_forms: %s is not a registered species -- national_dex "
              .. "did not carry it this run (most likely because NATIONAL "
              .. "DEX is off), so it cannot be taught %s and its own Z-Crystal "
              .. "has no way to reach it", species, row.move)
        end
      end
    elseif mod.log then
      mod.log:warn(
        "battle_forms: %s is not a registered move -- national_dex did not "
          .. "carry it, so its species Z-Crystal has no move to model or "
          .. "teach this run", row.move)
    end
  end
end

return M
