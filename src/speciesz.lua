-- The species-specific Z-Moves: a second catalog for the same Z-MOVE cell
-- src/zmoves.lua already owns, keyed on (species, crystal, one named move)
-- rather than on (crystal, type).
--
-- WHY A SEPARATE FILE RATHER THAN A BRANCH INSIDE src/zmoves.lua.  The two
-- catalogs answer different questions -- "does this crystal's TYPE match any
-- damaging move in the set" against "does this crystal's SPECIES match the
-- Pokemon AND does it know this ONE move" -- and mixing both shapes into one
-- fieldsFor would mean every reader learning to tell them apart.  What they
-- share is the menu cell, the Z-Ring gate, the once-per-battle lock and the
-- substitution mechanism itself, and src/zmoves.lua's M.entry is where those
-- live; this file only ever answers "what would this crystal do here", the
-- same shape src/zmoves.lua's own M.fieldsFor already keeps to.
--
-- WHY THE ITEM ITSELF GOES THROUGH src/stone.lua'S PAIRED INSTALL AND NOT
-- THE CRYSTALS' UNPAIRED ONE.  A type Z-Crystal fits every Pokemon -- what it
-- selects is a move type, never a species -- so data/crystals.lua's eighteen
-- go in unpaired.  A species Z-Crystal fits exactly one species (or a small
-- family of forms of it), the same shape Ultranecrozium Z already has, so it
-- is registered the same way: a pairing table (M.pairings below) that
-- src/stone.lua's ordinary M.install refuses on any other species with "It
-- won't have any effect", precisely like a mega stone.
local M = {}

-- Every id this file registers wears the mod's name, for the reason
-- src/zmoves.lua's and src/maxmoves.lua's do: a collision is a load failure
-- for whichever registers second.  No power suffix, unlike the type
-- Z-Moves' ids -- a species Z-Move has one fixed power, not a ladder, so
-- there is only ever one record per stem to name.
M.PREFIX = "BATTLE_FORMS_"

-- The record PP every species Z-Move is registered at, and why 5 rather
-- than the base move's own -- the same reason src/zmoves.lua's RECORD_PP is:
-- the FIGHT menu draws its maximum off the record, and src/substitute.lua's
-- menuPPUps corrects that maximum against the real base move's own PP, read
-- live from `data.moves` at substitution time.
M.RECORD_PP = 5

local deps = nil

function M.bind(modules) deps = modules end

function M.idFor(stem) return M.PREFIX .. stem end

-- species -> crystal -> true, the pairing-table shape src/stone.lua's
-- ordinary M.install (and src/eligibility.lua's formFor underneath it) both
-- already understand -- built from this file's own rows rather than kept as
-- a second, hand-written table that could silently drift out of step with
-- them.
function M.pairings(rows)
  local out = {}
  for _, row in ipairs(rows) do
    for _, species in ipairs(row.species) do
      out[species] = out[species] or {}
      out[species][row.crystal] = true
    end
  end
  return out
end

-- Every crystal this file names, in the data's own order -- an array for the
-- same reason src/zmoves.lua's M.crystalIds is: pairs() over a keyed table
-- would reorder the shelf between runs.
function M.crystalIds(rows)
  local out = {}
  for _, row in ipairs(rows) do out[#out + 1] = row.crystal end
  return out
end

-- id -> the FIGHT menu's own short name, the same display-time-only split
-- data/zmoves.lua's `menu` field keeps: src/zmovemenu.lua is the only
-- reader, and the registered record's `name` above is still what a save,
-- the battle text row and Mimic all see.
function M.menuNames(rows)
  local out = {}
  for _, row in ipairs(rows) do
    if type(row.menu) == "string" and row.menu ~= "" then
      out[M.idFor(row.stem)] = row.menu
    end
  end
  return out
end

-- Registers the roster and answers with the catalog M.fieldsFor reads:
-- which crystal converts which move, for which species, into which id.
--
-- A row whose named base move has no registered record is skipped and
-- SAID, the same class of refusal src/zmoves.lua's install runs for an
-- unresolved type: this game's move registry does not describe the move the
-- crystal needs, so there is nothing to derive a type or a name from, and
-- the crystal is still registered by the caller either way (through
-- src/stone.lua's paired install) -- an item a save carries has to stay
-- nameable whatever this file could build from it.
--
-- The registered record's own TYPE is read live off the base move rather
-- than duplicated into data/speciesz.lua, the same choice src/tera.lua makes
-- for TERA BLAST's PP: Volt Tackle is Electric, so Catastropika is too, and
-- a future change to Volt Tackle's own type is followed rather than copied
-- out of step.
function M.install(mod, rows)
  local catalog = { byCrystal = {} }
  local moves = mod.content and mod.content.moves
  for _, row in ipairs(rows) do
    local base = moves and type(moves.get) == "function" and moves:get(row.move)
    if type(base) == "table" and type(base.type) == "string" then
      local id = M.idFor(row.stem)
      mod.content.moves:register(id, {
        id = id,
        name = row.name,
        type = base.type,
        power = row.power,
        accuracy = 100,
        pp = M.RECORD_PP,
        effect = "NO_ADDITIONAL_EFFECT",
      })
      if deps and deps.anim then
        mod.content.battle_anims:register(id, { seq = deps.anim.zMoveSeq() })
      end
      local species = {}
      for _, sp in ipairs(row.species) do species[sp] = true end
      catalog.byCrystal[row.crystal] = { move = row.move, id = id, species = species }
    elseif deps and deps.log then
      deps.log:warn(
        "battle_forms: no species Z-Move for %s -- this game's move registry "
          .. "has no record for %s, so %s is still sold and still stamps its "
          .. "one species but nothing it holds will convert",
        tostring(row.crystal), tostring(row.move), tostring(row.crystal))
    end
  end
  return catalog
end

-- The fields a substitute for `slot` should carry under `crystal`, given the
-- mon carrying it, or nil to leave the slot alone.  nil covers four cases:
-- a crystal this catalog never built a record for, a mon whose species is
-- not the one this crystal fits, a slot that is not the one named move, and
-- (implicitly, through the base-move check) a mon that knows the move but
-- not on the matching type -- which cannot actually happen, since the
-- record's own type is read off that exact move, but is left as a plain
-- id comparison rather than a type comparison because id already implies it.
-- deps.gen2 branches the PP-correction shape the identical way
-- src/maxmoves.lua's and src/zmoves.lua's own M.fieldsFor already do:
-- Gold's FIGHT menu draws move.pp/move.maxPp straight off the slot with no
-- PP-Up arithmetic, so what src/gen2substitute.lua needs here is the base
-- move's own real maximum as an absolute number, not a correction meant for
-- a second table Gen 2 never creates.
function M.fieldsFor(catalog, data, mon, slot, crystal)
  local entry = catalog.byCrystal[crystal]
  if not entry then return nil end
  if not mon or not entry.species[mon.species] then return nil end
  if type(slot) ~= "table" or slot.id ~= entry.move then return nil end

  local def = data and data.moves and data.moves[entry.move]
  if deps and deps.gen2 then
    return { id = entry.id, maxPp = (def and tonumber(def.pp)) or M.RECORD_PP }
  end

  local ppUps = deps and deps.substitute and def
    and deps.substitute.menuPPUps(M.RECORD_PP, def.pp, slot.ppUps) or nil
  return { id = entry.id, ppUps = ppUps }
end

-- The per-slot function src/substitute.lua takes.  Built per activation
-- because it closes over the mon and the crystal that activation resolved.
function M.picker(catalog, data, mon, crystal)
  return function(slot)
    return M.fieldsFor(catalog, data, mon, slot, crystal)
  end
end

-- Whether this battler has anything for that crystal to convert -- asked by
-- src/zmoves.lua's `available` alongside its own wouldConvert, for the
-- reason mega evolution asks whether its form record exists: the menu must
-- not promise a change the activation can only refuse.
function M.wouldConvert(catalog, data, mon, battler, crystal)
  for _, slot in ipairs(battler and battler.curMoves or {}) do
    if type(slot) == "table" and M.fieldsFor(catalog, data, mon, slot, crystal) then
      return true
    end
  end
  return false
end

return M
