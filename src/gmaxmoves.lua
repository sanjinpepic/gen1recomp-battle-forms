-- G-Max Moves: a second, species-aware picker on the same move-substitution
-- mechanism src/maxmoves.lua's eighteen type rows already own.
--
-- WHY A SEPARATE FILE RATHER THAN A BRANCH INSIDE src/maxmoves.lua.
-- src/speciesz.lua's own header draws the line this follows: the two
-- catalogs answer different questions -- "does this Pokemon's SPECIES carry
-- one of these AND does the move being replaced share its ONE type" against
-- "does this move's TYPE have a record at all" -- and what they share is the
-- substitution mechanism and the fallback order, not the lookup itself.
-- src/dynamax.lua's `arm` step asks THIS catalog first and the ordinary one
-- second, on every slot independently, so a Gigantamax Pokemon's off-type
-- moves still become ordinary Max Moves exactly as they did before this file
-- existed.
--
-- WHY THE POWER LADDER IS ASKED OF src/maxmoves.lua RATHER THAN OWNED HERE.
-- Every G-Max Move but the three data/gmaxmoves.lua's header names uses the
-- identical seven-rung table an ordinary Max Move of the same type would --
-- `deps.maxmoves` is bound for exactly one call, M.powerFor, so this file
-- never carries its own copy of those seven numbers to drift out of step
-- with the ones src/maxmoves.lua already owns, the same live-read choice
-- src/tera.lua makes for Volt Tackle's own type.
--
-- WHY THIS NEVER TOUCHES A STATUS MOVE. A slot with no power is left alone
-- here regardless of species or type, the same refusal src/maxmoves.lua's
-- own M.fieldsFor makes for the identical reason: MAX GUARD is universal,
-- and a G-Max Move only ever stands in for a DAMAGING move of its type in
-- the real games too -- a Gigantamax Rillaboom's own status move still
-- becomes MAX GUARD, never G-MAX DRUM SOLO.
local M = {}

-- Every id this file registers wears the mod's name, for the reason
-- src/maxmoves.lua's and src/speciesz.lua's own do: a collision is a load
-- failure for whichever registers second.
M.PREFIX = "BATTLE_FORMS_"

-- The record PP every G-Max Move is registered at, and why 5 rather than the
-- base move's own -- the identical reason src/maxmoves.lua's RECORD_PP is:
-- the FIGHT menu draws its maximum off the record, and src/substitute.lua's
-- menuPPUps corrects that maximum against the real base move's own PP, read
-- live from `data.moves` at substitution time.
M.RECORD_PP = 5

local deps = nil

function M.bind(modules) deps = modules end

-- The registered id for one row's rung. The power is in the id for the same
-- reason src/maxmoves.lua's own M.idFor keeps it there: the power is what
-- distinguishes one record of a stem from another, and a fixed-power row
-- (see data/gmaxmoves.lua's header) still carries exactly one rung, so its
-- id carries a power suffix the same as every laddered row's does.
function M.idFor(stem, power)
  return M.PREFIX .. stem .. "_" .. tostring(power)
end

-- Whether the merged type chart carries this type -- the same guard
-- src/maxmoves.lua's own typeExists keeps, duplicated rather than shared
-- because every consumer of this pattern (src/maxmoves.lua, src/zmoves.lua,
-- src/tera.lua) keeps its own copy: `get` is a registry courtesy, and a
-- build that does not offer it must leave the G-Max Moves out rather than
-- take the mod down with a nil call.
local function typeExists(mod, typeId)
  local registry = mod.content and mod.content.type_chart
  if not registry or type(registry.get) ~= "function" then return false end
  local ok, record = pcall(registry.get, registry, typeId)
  return ok and record ~= nil
end

-- The power(s) one row registers a record at: the row's own fixed power
-- alone, or every power src/maxmoves.lua's ladder can reach for the row's
-- type -- Fighting's and Poison's own lower rungs included, which is why
-- Machamp's and Garbodor's rows land on the same numbers MAX KNUCKLE and
-- MAX OOZE already do. `fn` is called once per DISTINCT power, the same
-- dedupe src/maxmoves.lua's own M.install keeps: two rungs landing on one
-- number must not fight over one id.
local function forEachPower(row, maxRows, fn)
  if row.power then
    fn(row.power)
    return
  end
  local seen = {}
  local lowered = maxRows.lowered and maxRows.lowered[row.type]
  for _, rung in ipairs(maxRows.ladder) do
    local power = lowered and rung.loweredPower or rung.power
    if not seen[power] then
      seen[power] = true
      fn(power)
    end
  end
end

local function registerMove(mod, id, record)
  mod.content.moves:register(id, record)
  -- One animation per move id, the same reason src/maxmoves.lua's own
  -- registerMove keeps: the id IS the animation key (BattleState.lua:3627
  -- queues `{ anim = move.id }`). Reused rather than a G-Max-specific
  -- sequence -- a G-Max Move is still a Dynamaxed Pokemon's move growing
  -- huge, the same event src/anim.lua's maxMoveSeq already draws.
  if deps and deps.anim then
    mod.content.battle_anims:register(id, { seq = deps.anim.maxMoveSeq() })
  end
end

-- Registers every row this game's merged type chart can resolve and answers
-- with the catalog M.fieldsFor reads: which species carry a G-Max Move, its
-- one type, and the id to reach for a given power.
--
-- A row whose type the chart has no record for is skipped and SAID, the
-- same refusal src/maxmoves.lua's own M.install makes for the identical
-- reason -- a Gigantamax Pokemon of that species still Dynamaxes and still
-- gets the ordinary Max Move for the type in question, because
-- src/dynamax.lua's fallback never learns this catalog refused anything.
function M.install(mod, rows, maxRows)
  local catalog = { bySpecies = {}, maxRows = maxRows }
  for _, row in ipairs(rows) do
    if typeExists(mod, row.type) then
      local rungs = {}
      forEachPower(row, maxRows, function(power)
        local id = M.idFor(row.stem, power)
        rungs[power] = id
        registerMove(mod, id, {
          id = id,
          name = row.name,
          type = row.type,
          power = power,
          -- Never miss in the real games and no field to say so -- the same
          -- shortfall src/maxmoves.lua's own records carry, for the same
          -- reason: the closest a record gets under the faithful ruleset
          -- still leaves the cart's 1-in-256 miss.
          accuracy = 100,
          pp = M.RECORD_PP,
          effect = "NO_ADDITIONAL_EFFECT",
          -- `category` is deliberately absent, matching every other move
          -- roster this mod builds: Gen 1 splits physical from special by
          -- TYPE, and Damage.categoryOf falls through to the type record
          -- when a move does not say (src/maxmoves.lua's own header), which
          -- is what lets Cinderace's, Rillaboom's and Inteleon's fixed-power
          -- rows follow the base move's own category for free, matching the
          -- real games' "physical or special depending on the move it
          -- replaced" rule with no branch of its own.
        })
      end)
      catalog.bySpecies[row.species] = { type = row.type, fixed = row.power,
                                         rungs = rungs }
    elseif deps and deps.log then
      deps.log:warn(
        "battle_forms: no G-Max Move for %s -- this game's merged type "
          .. "chart has no record for %s, which is what a Red-era chart "
          .. "looks like; a Gigantamax %s Dynamaxes with the ordinary Max "
          .. "Move for that type instead",
        tostring(row.stem), tostring(row.type), tostring(row.species))
    end
  end
  return catalog
end

-- The fields a substitute for `slot` should carry, or nil to leave the slot
-- for the ordinary Max Move picker to decide. nil covers five cases: a mon
-- with no species, a species this catalog carries no row for, an id the
-- registry cannot resolve, a move whose type does not match the row's one
-- type, and a status move (power <= 0, which stays MAX GUARD universally).
--
-- deps.gen2 branches the PP correction the identical way src/maxmoves.lua's
-- own M.fieldsFor does, and for the identical reason: Gold's FIGHT menu
-- draws `move.pp`/`move.maxPp` straight off the slot with no PP-Up
-- arithmetic, so this hands src/gen2substitute.lua an absolute `maxPp`
-- rather than a `ppUps` correction meant for a second table Gen 2 never
-- creates.
function M.fieldsFor(catalog, data, mon, slot)
  local entry = mon and mon.species and catalog.bySpecies[mon.species]
  if not entry then return nil end

  local def = data and data.moves and data.moves[slot and slot.id]
  if type(def) ~= "table" or def.type ~= entry.type then return nil end

  local base = tonumber(def.power) or 0
  if base <= 0 then return nil end

  local power = entry.fixed
    or (deps and deps.maxmoves and deps.maxmoves.powerFor(catalog.maxRows, entry.type, base))
  local id = power and entry.rungs[power] or nil
  if not id then return nil end

  if deps and deps.gen2 then
    return { id = id, maxPp = tonumber(def.pp) or M.RECORD_PP }
  end

  -- The same menu-maximum correction src/maxmoves.lua's own M.fieldsFor
  -- carries, and for the identical reason: the FIGHT menu draws a maximum
  -- off the RECORD, and this makes that maximum read back as the base
  -- move's own.
  local ppUps = deps and deps.substitute
    and deps.substitute.menuPPUps(M.RECORD_PP, def.pp, slot.ppUps) or nil
  return { id = id, ppUps = ppUps }
end

-- The per-slot function src/substitute.lua takes. Built per battle because
-- it closes over that battle's merged data and the Dynamaxing mon's own
-- species.
function M.picker(catalog, data, mon)
  return function(slot)
    return M.fieldsFor(catalog, data, mon, slot)
  end
end

-- id -> the FIGHT menu's own short name, the same display-time-only split
-- data/zmoves.lua's and data/speciesz.lua's `menu` fields keep:
-- src/zmovemenu.lua is the only reader, and the registered record's `name`
-- above is still what a save, the battle text row and Mimic all see. Every
-- rung a row can register shares its one display name, the same
-- one-name-per-stem rule src/zmoves.lua's own M.menuNames keeps.
function M.menuNames(rows, maxRows)
  local out = {}
  for _, row in ipairs(rows) do
    if type(row.menu) == "string" and row.menu ~= "" then
      forEachPower(row, maxRows, function(power)
        out[M.idFor(row.stem, power)] = row.menu
      end)
    end
  end
  return out
end

return M
