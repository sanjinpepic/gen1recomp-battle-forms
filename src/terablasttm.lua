-- TERA BLAST shipped in 0.27.0 and no player could reach it. National Dex
-- registers TERABLAST (80 power, Special, Normal, 100 accuracy) as part of
-- its 833-move catalog, but it sits in zero learnsets -- not in
-- national.lua, not in the generated learnset shards -- and nothing before
-- this file ever patched it into one. Every one of src/tera.lua's eighteen
-- type variants, its PP handling and its arm/disarm mechanism were built on
-- a move nothing could ever know.
--
-- The real games' fix is TM171, close to universal, and that is the shape
-- taken here: a new bag item, teaching the move through the engine's own
-- machine-item path (game/src/inventory/ItemEffects.lua:508-534 reads
-- `speciesDef.tmhm` for the item's `itemDef.machine.move`) rather than
-- appending straight to `learnset` the way src/dragonascent.lua does --
-- Dragon Ascent is a move Rayquaza simply has by level 1 in the real games,
-- Tera Blast is TM-taught there, and modelling it as a free level-1 move
-- everywhere would invent an acquisition path the source games do not have.
--
-- WHY A PATCH, NOT A REGISTER, for the move and every species. TERABLAST
-- itself is untouched here except for one flag (below) -- national_dex
-- already registers it in full, unconditionally, and a `register` on top of
-- that would throw under the moves registry's own "record" semantics
-- (game/src/mods/Registry.lua:95-97: a duplicate id throws). Every species
-- this file touches is patched too, appending one row to `tmhm` through the
-- `__append` wrapper (game/src/mods/Merge.lua) so a Kanto native's real
-- ROM-extracted TM/HM list keeps every entry it already had -- a bare list
-- there would replace it wholesale, the same trap src/dragonascent.lua's own
-- header names for `learnset`. `extend()` (Merge.lua:38-49) builds the list
-- even where the base carried none at all, which is what lets this patch a
-- national_dex species that has no `tmhm` field of its own (every species
-- past #151 -- national_dex never sets one) exactly the same way it patches
-- a ROM-native's real list.
local M = {}

M.ITEM = "TM171"
M.MOVE = "TERABLAST"
M.NUMBER = 171

-- Priced above a key item (200, which only gates a mechanic) and below a
-- mega stone (4000, a permanent, re-equippable upgrade): this is consumed
-- teaching one Pokemon one move once, which is worth more than a gate and
-- less than something a player keeps moving from mon to mon.
M.PRICE = 3000

-- Every species that is not itself a form pseudo-record may learn Tera
-- Blast by TM, matching how close to universal TM171 is in the real games --
-- a RULE rather than a hand-picked list, so it is reviewable in one line and
-- survives a national_dex data rebuild without maintenance here.
--
-- A FORM record -- one carrying both `baseSpecies` and `form`, national_dex/
-- src/api.lua's own test for one (CHARIZARD_MEGA_X, RAYQUAZA_MEGA and every
-- other alternate-form id national_dex registers) -- is excluded, and not as
-- a hand-picked carve-out: it can never be the thing this teaches. Every
-- transformation this mod makes overrides a battler's stats and types and
-- never touches `mon.species` (src/tera.lua's own header states this
-- plainly), so `target.species` at the teaching item's own check
-- (ItemEffects.lua:510) can never resolve to a form id -- patching one would
-- be a tmhm list nothing in this engine can ever read.
function M.eligible(id, record)
  if type(record) ~= "table" then return false end
  return not (record.baseSpecies and record.form)
end

-- Registers the item, flags the move as honestly modelled, and teaches every
-- eligible species. The item's bag byte is claimed unconditionally, the same
-- rule every other item table in this mod follows (src/keyitems.lua's own
-- header: "an item a save carries has to stay nameable no matter what any
-- gate later says"), but `machine`, the effect flag and every tmhm patch are
-- gated together on TERABLAST actually being a registered move -- each of
-- those three is an `f.id("moves")` reference or a claim about that move,
-- and the loader's own cross-reference pass fails the whole load on a
-- reference that cannot resolve (game/src/mods/Schemas.lua's collectRefs).
-- A build missing TERABLAST -- national_dex disabled, or an older version
-- that predates it -- therefore still gets a TM171 that exists in the bag
-- and simply has nothing behind it: ItemEffects.lua's machine-item check
-- (`if itemDef and itemDef.machine then`) never matches an item with no
-- `machine` field, so using it falls through to an ordinary "no effect"
-- refusal instead of crashing the load.
function M.install(mod, indices)
  local moves = mod.content and mod.content.moves
  local moveBase = moves and type(moves.get) == "function" and moves:get(M.MOVE)
  local moveExists = type(moveBase) == "table"

  local index = indices and indices[M.ITEM]
  if index then
    local record = {
      id = M.ITEM, name = "TM171", index = index, price = M.PRICE,
      needsTarget = true, tossable = true,
    }
    if moveExists then
      record.machine = { kind = "TM", move = M.MOVE, number = M.NUMBER }
    end
    mod.content.items:register(M.ITEM, record)
  elseif mod.log then
    mod.log:error(
      "battle_forms: %s has no bag index -- add it to data/tm171.lua; "
        .. "until then the item cannot exist in a save and TERA BLAST "
        .. "can never be taught to anything", M.ITEM)
  end

  if not moveExists then
    if mod.log then
      mod.log:warn(
        "battle_forms: %s is not a registered move -- national_dex did not "
          .. "carry it, so TM171 has nothing to teach and Terastallization "
          .. "has nothing to substitute this run", M.MOVE)
    end
    return
  end

  -- Terastallization's own type substitution (src/tera.lua) IS Tera Blast's
  -- real modelled effect: the move's own static record cannot express
  -- "becomes the user's Tera type" by itself, which is exactly why
  -- national_dex registered it `effectModeled = false` -- but battle_forms's
  -- substitution performs precisely that change whenever this mod is
  -- loaded. The flag is patched true here for the same reason
  -- src/dragonascent.lua patches an effect onto DRAGONASCENT: national_dex
  -- cannot make this claim itself, because it would lie the instant
  -- battle_forms is absent, and this file can, because the claim cannot be
  -- true here without the very mechanism that makes it true.
  mod.content.moves:patch(M.MOVE, { effectModeled = true })

  local pokemon = mod.content and mod.content.pokemon
  if pokemon and type(pokemon.each) == "function" then
    local taught = 0
    for speciesId, record in pokemon:each() do
      if M.eligible(speciesId, record) then
        mod.content.pokemon:patch(speciesId, {
          tmhm = { __append = { M.MOVE } },
        })
        taught = taught + 1
      end
    end
    if taught == 0 and mod.log then
      mod.log:warn(
        "battle_forms: no species were found to teach %s to -- national_dex "
          .. "registered nothing this run, so TM171 exists in the bag but "
          .. "has nothing it can ever be used on", M.MOVE)
    end
  elseif mod.log then
    mod.log:warn(
      "battle_forms: mod.content.pokemon:each is unavailable -- TERA BLAST "
        .. "cannot be taught to anything this run")
  end
end

return M
