-- Mega Rayquaza's trigger: knowing Dragon Ascent, not a stone.
--
-- data/megas.lua's header tells the longer history -- an invented RAYQUAZITE
-- stone stood in for this from this mod's early versions until 0.30.0, when
-- wild_forms placed a wild Rayquaza and the stand-in was withdrawn.  This is
-- now the ONLY trigger, and it teaches the move as well as modelling its
-- effect: national_dex cannot flag DRAGONASCENT `effectModeled = true` on the
-- strength of an effect that lives in a mod it does not depend on, because
-- that flag would then lie whenever battle_forms is absent.  So both halves
-- live here, where the claim is always true.
--
-- WHY A PATCH AND NOT A REGISTER, for both the move and the species.
-- DRAGONASCENT and RAYQUAZA are already registered by national_dex --
-- unconditionally, never gated by the MOVES option, only the WIDENING of a
-- learnset is -- so a `register` here would be a load error under the moves
-- and pokemon registries' own "record" semantics
-- (game/src/mods/Registry.lua:95-97: a duplicate id throws).  `patch` deep-
-- merges instead, regardless of that "record" semantics -- Registry.lua's own
-- fold() runs the merge branch for every patch op, record registry or not --
-- so patching `effect` alone leaves DRAGONASCENT's power, accuracy, type and
-- PP exactly as national_dex set them, and appending one row to `learnset`
-- through the `__append` wrapper (game/src/mods/Merge.lua) leaves Rayquaza's
-- REST/FLY/HYPER BEAM rows standing rather than replacing them -- a bare list
-- there would replace wholesale.  Both patches are ops appended to the same
-- id's history, folded at read time over national_dex's own `register`, so
-- there is nothing here for the two mods' registrations to collide over.
--
-- WHY MOVES=ALL IS NOT RELIED ON.  DRAGONASCENT already sits in Rayquaza's
-- learnset shard at level 1 (data/moves/generated/learnsets/007.lua), but
-- national_dex only ever admits that shard's rows when the player has opted
-- into MOVES=ALL, which is not the default -- so leaning on it would leave
-- Mega Rayquaza unreachable out of the box.  Patching the learnset directly,
-- from here, needs no option at all.
local M = {}

-- deps.gen2 is the one thing M.effectRecord's own `run` and M.onDamageDealt
-- below both read; every other function in this file is generation-agnostic
-- (M.knows, M.crystalSet, M.formFor, M.install all read a mon or a registry,
-- never a battle). Optional, like every deps table in this mod's own
-- convention: a build that never calls M.bind (the unit suite covering the
-- effect record and the roster/species patches, none of which are Gen 2
-- questions) gets exactly the Gen 1 behaviour this file always had.
local deps = nil
function M.bind(modules) deps = modules end

M.SPECIES = "RAYQUAZA"
-- The National Dex record's KEY, exactly the discipline data/megas.lua's own
-- header demands of every form id it names -- and never the record's `name`
-- field, the exact mistake (a name instead of a record key) that shipped a
-- whole release of invisible megas in 0.2.1.  Until 0.30.0 this was read off
-- data/megas.lua's own RAYQUAZA row rather than written here, specifically to
-- avoid this literal -- but that row named the withdrawn RAYQUAZITE stone as
-- its key, and withdrawing the stone withdrew the row it was keyed under, so
-- this is now the one place RAYQUAZA_MEGA is named.  tests/
-- battle_forms_formids_test.lua checks it against the real national_dex
-- record the same way it checks every other form id this mod wires.
M.FORM = "RAYQUAZA_MEGA"
M.MOVE = "DRAGONASCENT"
-- The main series' own level -- Rayquaza learns Dragon Ascent at 75, and
-- this mod follows that number rather than inventing a more convenient one,
-- the same restraint applied elsewhere to G-Max effects and Z-Move
-- triggers.  0.30.0 through 0.53.0 taught it at level 1 instead, so the
-- move (and therefore the mega) was available from the moment a Rayquaza
-- existed; a Rayquaza below level 75 now needs to reach it, or learn the
-- move some other way, before Dragon Ascent's own trigger has anything to
-- ask about. Applies identically on both games -- see M.install's own
-- header for why the FIELD it lands in still has to differ.
--
-- `Pokemon.movesAtLevel`/`Mon.movesAtLevel` (game/src/pokemon/Pokemon.lua:
-- 10-30, game/src/battle/gen2/Mon.lua:302-327) both keep only the LAST four
-- distinct moves a walk of the learnset/levelMoves array produces at or
-- below the target level -- array order, not level order.  Since
-- M.install's own `__append` always adds this row after every row
-- national_dex's own registration already carries, it is always the last
-- entry either walk can add for a mon at or above level 75, which is what
-- guarantees a FRESHLY BUILT level-75 Rayquaza (wild_forms places one at
-- Indigo Plateau, level 75, exactly for this reason) always knows Dragon
-- Ascent with no possibility of an earlier move crowding it out -- on
-- either game.  A Rayquaza that instead LEVELS UP into 75 with a full
-- moveset goes through the ordinary interactive learn prompt
-- (BattleState:learnMove/MoveLearnMenu on Gen 1, Gold's own equivalent),
-- exactly as any other move would, and the player may decline it there.
M.LEVEL = 75
-- Wears the mod's name for the reason every other effect id here does: a
-- move pack registering its own DRAGONASCENT effect cannot collide with this
-- one.
M.EFFECT = "BATTLE_FORMS_DRAGON_ASCENT_EFFECT"

-- Whether `mon` already knows Dragon Ascent, read off its own moveset --
-- `mon.moves`, the same array `curMoves` aliases by reference
-- (BattleState.lua:515) -- rather than the battler's current one, so an
-- unrelated substitution (a Z-Move or a Max Move armed on some OTHER cell)
-- can never be mistaken for Rayquaza's own moveset.
function M.knows(mon)
  for _, slot in ipairs(mon and mon.moves or {}) do
    if type(slot) == "table" and slot.id == M.MOVE then return true end
  end
  return false
end

-- Every id a Z-Crystal is registered under: the eighteen type crystals plus
-- Ultranecrozium Z (data/crystals.lua, data/ultracrystal.lua).  The fourteen
-- species Z-Crystals are left out on purpose and not merely forgotten:
-- src/stone.lua's paired install refuses every one of them on any species
-- that is not its own match, and Rayquaza has no row in data/speciesz.lua, so
-- none of the fourteen can ever reach its held-item slot for this check to
-- have to refuse.
function M.crystalSet(crystalIndices, ultraCrystalIndices)
  local out = {}
  for itemId in pairs(crystalIndices or {}) do out[itemId] = true end
  for itemId in pairs(ultraCrystalIndices or {}) do out[itemId] = true end
  return out
end

-- The form id Rayquaza's own trigger resolves to, or nil -- covering every
-- case that is not "a Rayquaza that knows Dragon Ascent and is not holding a
-- Z-Crystal": a Pokemon that is not Rayquaza, a Rayquaza that has not learned
-- the move, and a Rayquaza holding a Z-Crystal, refused per the Gen 7 rule
-- the real games apply.  No Key Stone and no mega stone enter this decision
-- anywhere -- that absence is the whole point of a second trigger, and
-- src/mega.lua is what keeps it from loosening the gate for anything else:
-- this function is asked only about Rayquaza's own cell entry, never folded
-- into src/eligibility.lua's shared formForMon.
--
-- Takes no `megas` argument as of 0.30.0: M.FORM is this file's own literal
-- now, not a lookup into data/megas.lua's pairing table, because that table
-- carries no row for Rayquaza any longer.  Callers still hold a `megas`
-- table for the ordinary two-tier gate this function has nothing to do with
-- (src/mega.lua's fallback, src/resolve.lua's switch-in reapply).
function M.formFor(eligibility, crystals, mon)
  if not mon or mon.species ~= M.SPECIES then return nil end
  if not M.knows(mon) then return nil end
  local held = eligibility.stoneOf(mon)
  if held and crystals and crystals[held] then return nil end
  return M.FORM
end

-- Dragon Ascent's whole modelled effect: the user's own Defense and Special
-- Defense fall one stage after it hits, and nothing else.  Gen 1 has no
-- separate Special Attack/Special Defense -- one `special` stage covers both
-- halves (src/battle/MoveEffects.lua's own STAT_LABEL keys) -- so "lowers
-- Defense and Special Defense" is one drop to `defense` and one to `special`.
--
-- `kind = "secondary"` is what puts this on the post-damage path
-- (EffectRegistry.lua:318-324: any non-"primary" record's `run` fires once a
-- hit has landed and dealt damage, gated on the TARGET surviving it) rather
-- than the pure-status path a power-0 move like Max Guard takes
-- (BattleState.lua:3693: only `kind == "primary"` runs there, and only for a
-- 0-power move).  Dragon Ascent is a 120-power hit, so it has to be the
-- former.
--
-- `ctx.changeStage`'s `fromEnemy` is false on both calls: this is the user
-- lowering its own stats, not an opponent's move reaching through Mist or a
-- substitute, and `fromEnemy` is what gates those.
-- Gold's own move_effects dispatch (game/src/battle/gen2/Battle.lua:
-- 1561-1566) reads this SAME shared registry -- "Same registry NAME Gen 1
-- fills from", that file's own comment at :2702 -- but calls `run` UNCON-
-- DITIONALLY and BEFORE the accuracy roll, handing it positional battle-
-- engine arguments (self, attacker, defender, def, moveId, sureHit) rather
-- than the Gen 1 ctx table this function is built for. Left unguarded, that
-- would fire Dragon Ascent's stat drop on a miss as readily as a hit, and
-- would do it by reading `ctx.user`/`ctx.changeStage` off a Battle instance
-- that has neither field under those names -- `ctx.user` answers nil and
-- the resulting `nil.changeStage` call errors outright, not merely
-- misbehaves. Registering nothing at all was considered and rejected: Gen 1
-- still needs this exact record on the shared registry, and M.install's own
-- header already refuses to let one refusal cascade into a second, unrelated
-- one. So this stays registered for Gen 1 and simply does nothing when
-- Gold's own dispatch reaches it -- M.onDamageDealt below is the real Gen 2
-- mechanism, reached through battle.damage_dealt rather than through this
-- registry at all.
function M.effectRecord()
  return {
    kind = "secondary",
    run = function(ctx)
      if deps and deps.gen2 then return {} end
      local msgs = {}
      for _, line in ipairs(ctx.changeStage(ctx.user, "defense", -1, false)) do
        msgs[#msgs + 1] = line
      end
      for _, line in ipairs(ctx.changeStage(ctx.user, "special", -1, false)) do
        msgs[#msgs + 1] = line
      end
      return msgs
    end,
  }
end

-- Gold's real route to the same effect: battle.damage_dealt, the identical
-- seam src/zmoves.lua's own Z-status bonus already applies through (that
-- module's own header) because it fires once a hit has ACTUALLY landed,
-- after Gold's own move resolution has finished -- the only seam left that
-- can tell "the move connected" from "the move was merely selected" once
-- M.effectRecord's own `run` has refused to answer that question early.
--
-- Gated on the target surviving and on real damage having been dealt, the
-- identical two-part gate Gen 1's own EffectRegistry.lua applies to every
-- kind == "secondary" effect (:319-320, `target.mon.hp > 0 and totalDealt >
-- 0`) including this exact one -- so a Dragon Ascent that faints its target
-- drops nothing here either, matching what this mod already does on Gen 1
-- rather than inventing a more generous rule for the other game.
--
-- Reached by move id alone, the same as the Gen 1 effect record above: the
-- stat drop is a property of the MOVE, not of Rayquaza specifically, so
-- anything that ever uses Dragon Ascent (Transform, Sketch, a future move
-- pack) drops its own Defense and Special Defense too, on both games alike.
--
-- `battle:changeStage(mon, stat, stages)` is Gold's own instance method
-- (game/src/battle/gen2/Battle.lua:1299) -- the same primitive
-- src/zmoves.lua's own applyStatusBonus already calls for the identical
-- reason: it applies the change, clamps it at the cart's own ceiling and
-- emits the cart's own "X's STAT fell!" message all by itself, with no free
-- function to require the way Gen 1's src.battle.MoveEffects is.
function M.onDamageDealt(ev)
  if not (deps and deps.gen2) then return end
  local moveId = ev and (ev.moveId or (ev.move and ev.move.id))
  if moveId ~= M.MOVE then return end
  local battle, user, target = ev.battle, ev.user, ev.target
  if type(battle) ~= "table" or type(battle.changeStage) ~= "function" then
    return
  end
  if type(user) ~= "table" then return end
  if not (type(ev.damage) == "number" and ev.damage > 0) then return end
  if type(target) == "table" and (target.hp or 0) <= 0 then return end
  battle:changeStage(user, "defense", -1)
  battle:changeStage(user, "specialDefense", -1)
end

-- Registers the effect unconditionally, the way every other effect record in
-- this mod is: an id nothing ever points at is a harmless dead entry, and the
-- alternative -- registering it only once the move patch below succeeds --
-- would make one refusal cascade into a second, unrelated one.
--
-- The two patches are each guarded on their base record actually existing,
-- read back live off the merged registry rather than assumed.  Without the
-- guard, a `patch` against an id neither this mod nor national_dex has
-- touched does not fail -- Registry.lua's fold() folds a missing base to `{}`
-- and merges the partial straight on top of it -- so an unguarded patch here
-- would silently manufacture a DRAGONASCENT move with an effect and nothing
-- else, or a RAYQUAZA species with a one-row learnset and no base stats.  A
-- guard that refuses must say so out loud, so each refusal is logged with the
-- id it could not find and why that means this feature cannot exist this run.
function M.install(mod)
  mod.content.move_effects:register(M.EFFECT, M.effectRecord())

  local moves = mod.content and mod.content.moves
  local moveBase = moves and type(moves.get) == "function" and moves:get(M.MOVE)
  if type(moveBase) == "table" then
    mod.content.moves:patch(M.MOVE, { effect = M.EFFECT })
  elseif mod.log then
    mod.log:warn(
      "battle_forms: %s is not a registered move -- national_dex did not "
        .. "carry it, so Dragon Ascent has no move record to attach its "
        .. "effect to and Rayquaza's own mega trigger cannot exist this run",
      M.MOVE)
  end

  -- deps.gen2 picks the FIELD this patch has to land in, not merely a
  -- different value: national_dex's own src/gen2shape.lua folds `learnset`
  -- and `level1Moves` into one `levelMoves` table for every species it
  -- registers on a Gold boot, and lists `learnset` in its own GEN1_ONLY set
  -- -- "written in their Gen 2 spelling below, so they must not also
  -- survive under their Gen 1 name", that file's own comment on exactly why
  -- -- so a reshaped RAYQUAZA record has no `learnset` field at all by the
  -- time this mod's own dependent load ever reaches it (battle_forms
  -- declares national_dex a hard dependency, so it always loads after).
  -- Patching `learnset` there does not fail -- Registry.lua's fold() merges
  -- a patch onto whatever exists, missing key or not -- it silently
  -- manufactures a `learnset` field nothing on Gold ever reads:
  -- game/src/battle/gen2/Mon.lua's own Mon.movesAtLevel walks only
  -- `def.levelMoves`, at every one of its three level-up call sites, and
  -- never once looks at `learnset`.  That was this mod's own bug through
  -- 0.53.0 -- Mega Rayquaza's Gen 2 exemption was wired to a move no Gold
  -- Rayquaza could ever actually know, whatever level it reached.
  local pokemon = mod.content and mod.content.pokemon
  local speciesBase = pokemon and type(pokemon.get) == "function"
    and pokemon:get(M.SPECIES)
  if type(speciesBase) == "table" then
    local field = (deps and deps.gen2) and "levelMoves" or "learnset"
    mod.content.pokemon:patch(M.SPECIES, {
      [field] = { __append = { { level = M.LEVEL, move = M.MOVE } } },
    })
  elseif mod.log then
    mod.log:warn(
      "battle_forms: %s is not a registered species -- national_dex did not "
        .. "carry it, so Dragon Ascent cannot be taught to it this run",
      M.SPECIES)
  end
end

return M
