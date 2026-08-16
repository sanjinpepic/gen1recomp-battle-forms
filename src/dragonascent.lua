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
M.LEVEL = 1
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
function M.effectRecord()
  return {
    kind = "secondary",
    run = function(ctx)
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

  local pokemon = mod.content and mod.content.pokemon
  local speciesBase = pokemon and type(pokemon.get) == "function"
    and pokemon:get(M.SPECIES)
  if type(speciesBase) == "table" then
    mod.content.pokemon:patch(M.SPECIES, {
      learnset = { __append = { { level = M.LEVEL, move = M.MOVE } } },
    })
  elseif mod.log then
    mod.log:warn(
      "battle_forms: %s is not a registered species -- national_dex did not "
        .. "carry it, so Dragon Ascent cannot be taught to it this run",
      M.SPECIES)
  end
end

return M
