-- Max Moves: the first consumer of src/substitute.lua, and the first thing this
-- mod registers into the battle's move registry.
--
-- WHY THESE ARE REGISTERED RECORDS RATHER THAN TABLES BUILT PER BATTLE, which
-- is the decision the whole shape of this file follows from.
--
-- A battler may carry a move instance whose id the registry has never heard of,
-- and the engine will not crash on one -- but it will not USE it either:
-- performMove looks the instance up with `self.data.moves[moveInst.id]` and
-- returns on a miss, logging "unknown move instance" and spending the turn on
-- nothing (BattleState.lua:2349, 3583-3588).  Everything that decides what a
-- move DOES reads the record and not the instance -- Damage.compute takes power,
-- type and accuracy off it (Damage.lua:114-124, 218-227), the FIGHT menu draws
-- its name and PP maximum off it (BattleState.lua:5827-5851), and
-- BattleCheckpoint refuses to restore a battle holding a move id the registry
-- cannot resolve (BattleCheckpoint.lua:94-103).  So a synthesised Max Move would
-- be a move that cannot be used, drawn or saved.
--
-- And because power lives on the RECORD, "the Max Move's power derives from the
-- base move's" cannot be expressed by one record per type.  It is expressed by
-- one record per type per rung of the ladder: seven rungs, so eighteen types
-- come to a hundred and twenty-six records plus Max Guard.  That is the price of
-- a fixed move registry and it is paid once, at load.
--
-- WHAT IS NOT REGISTERED.  A type the running game has no record for.  The move
-- schema declares `type` as a reference into the type chart and the merge turns
-- an unresolved one into a load ERROR at this mod's api level, so registering
-- MAX DARKNESS in a game whose chart stops at Red's fifteen types would not
-- cost a Dark Max Move -- it would cost the whole mod.  The chart is therefore
-- asked, per type, before anything is registered, exactly as src/tera.lua asks
-- it before offering a Tera type.  A type with no Max Move leaves those slots
-- holding their own move for the duration, which is visible but honest.
local M = {}

-- Every id this file registers wears the mod's name.  "MAXFLARE" is precisely
-- the id a future move pack would reach for, and a collision is a load failure
-- for whichever of the two registers second.
M.PREFIX = "BATTLE_FORMS_"

-- The effect record Max Guard runs.  Registered here rather than borrowed
-- because nothing in Gen 1 protects: the closest the cart has is a
-- semi-invulnerable Fly or Dig, which is the flag this reuses.
M.GUARD_EFFECT = M.PREFIX .. "MAX_GUARD_EFFECT"

-- The PP every Max Move record carries, and the reason it is 5 rather than
-- anything more plausible.
--
-- A Max Move has no PP of its own -- it spends the slot's, which is what
-- src/substitute.lua's alias arranges -- but the FIGHT menu still draws a
-- MAXIMUM, and it takes that from the record.  With the record at 5 the menu's
-- formula reduces to `5 + ppUps`, so the correction the substitute has to carry
-- is a whole number rather than a rounded one; src/substitute.lua's menuPPUps
-- works it out and says why.
M.RECORD_PP = 5

local deps = nil

function M.bind(modules) deps = modules end

-- The registered id for a rung.  The power is in the id because the power is
-- what distinguishes one record of a type from another.
function M.idFor(stem, power)
  return M.PREFIX .. stem .. "_" .. tostring(power)
end

-- The Max Move power a base power of `basePower` earns for a move of `typeId`.
function M.powerFor(rows, typeId, basePower)
  local lowered = rows.lowered and rows.lowered[typeId] or false
  for _, rung in ipairs(rows.ladder) do
    if rung.upTo == nil or basePower <= rung.upTo then
      return lowered and rung.loweredPower or rung.power
    end
  end
  return nil
end

-- Whether the merged type chart carries this type.  Guarded rather than trusted:
-- `get` is a registry courtesy and a build that does not offer it must leave the
-- Max Moves out rather than take the mod down with a nil call.
local function typeExists(mod, typeId)
  local registry = mod.content and mod.content.type_chart
  if not registry or type(registry.get) ~= "function" then return false end
  local ok, record = pcall(registry.get, registry, typeId)
  return ok and record ~= nil
end

local function registerMove(mod, id, record, seq)
  mod.content.moves:register(id, record)
  -- One animation per move id, because the id IS the animation key
  -- (BattleState.lua:3627 queues `{ anim = move.id }`).  A move with no
  -- sequence to give is still registered: AnimPlayer warns once and plays
  -- nothing, which is a degraded move rather than a broken load.
  if type(seq) == "table" then
    mod.content.battle_anims:register(id, { seq = seq })
  end
end

-- Registers everything and answers with the catalog the substitution reads:
-- which types got a Max Move, and how to reach the right rung for a base move.
--
-- Missing rows are reported rather than skipped quietly.  The DYNAMAX cell is
-- offered to every species and every moveset, so nothing downstream would ever
-- have noticed a type this file failed to register.
function M.install(mod, rows)
  local catalog = { byType = {}, guard = nil, rows = rows }
  local guardRow = rows.guard
  local guardId = M.PREFIX .. guardRow.stem

  mod.content.move_effects:register(M.GUARD_EFFECT, {
    kind = "primary",
    -- Not accuracy-checked: Max Guard does not miss, and the flag it sets is
    -- the engine's own semi-invulnerability -- the one thing in Gen 1 that
    -- makes an incoming move fail without a damage hook (EffectRegistry.lua:
    -- 106).  It is cleared at the end of the turn by M.onTurnEnded, which is
    -- the whole of its duration; a flag left standing would be a Pokemon
    -- nothing could hit for the rest of the battle.
    run = function(ctx)
      local user = ctx.user
      user.invulnerable = true
      if deps and deps.guard then deps.guard.battler = user end
      return { deps and deps.announce and deps.announce.maxGuard(user) or nil }
    end,
  })

  registerMove(mod, guardId, {
    id = guardId,
    name = deps and deps.announcename and deps.announcename.of(guardRow)
      or guardRow.name,
    type = guardRow.type,
    power = 0,
    accuracy = 100,
    pp = M.RECORD_PP,
    effect = M.GUARD_EFFECT,
    -- Max Guard moves first in the real games, and it has to here as well:
    -- a shield that goes up after the attack it was meant to stop has landed
    -- is a move that never does anything.
    priority = 4,
  }, deps and deps.anim and deps.anim.maxGuardSeq() or nil)
  catalog.guard = guardId

  local lowered = rows.lowered or {}
  for _, row in ipairs(rows.types) do
    if typeExists(mod, row.type) then
      local rungs = {}
      for _, rung in ipairs(rows.ladder) do
        local power = lowered[row.type] and rung.loweredPower or rung.power
        if not rungs[power] then
          rungs[power] = M.idFor(row.stem, power)
          registerMove(mod, rungs[power], {
            id = rungs[power],
            name = deps and deps.announcename and deps.announcename.of(row)
              or row.name,
            type = row.type,
            power = power,
            -- Max Moves never miss in the real games and there is no
            -- never-miss field on a move record to say so -- that lives on the
            -- effect, and borrowing Swift's would take its typeless damage with
            -- it.  100 is as close as a record gets, which under the faithful
            -- ruleset still leaves the cart's 1-in-256 miss.
            accuracy = 100,
            pp = M.RECORD_PP,
            effect = "NO_ADDITIONAL_EFFECT",
            -- `category` is deliberately absent.  Gen 1 splits physical from
            -- special by TYPE and Damage.categoryOf falls through to the type
            -- record when a move does not say (Damage.lua:113-124), so leaving
            -- it out is what makes a Max Move follow its type the way every
            -- move on the cart does.
          }, deps and deps.anim and deps.anim.maxMoveSeq() or nil)
        end
      end
      catalog.byType[row.type] = rungs
    elseif deps and deps.log then
      deps.log:warn(
        "battle_forms: no Max Move for %s -- this game's merged type chart has "
          .. "no record for that type, which is what a Red-era chart looks "
          .. "like; moves of that type keep themselves while Dynamaxed",
        tostring(row.type))
    end
  end

  return catalog
end

-- The fields a substitute for `slot` should carry, or nil to leave the slot
-- alone.  nil covers three cases and all three are the same answer: a move the
-- registry cannot resolve (there is nothing to read a power or a type off), a
-- type with no Max Move in this game, and a rung that failed to register.
--
-- deps.gen2 branches the PP correction the same way src/mega.lua's own entry
-- branches its whole shape: Gold's FIGHT menu draws `move.pp`/`move.maxPp`
-- straight off the slot with no PP-Up arithmetic at all
-- (game/src/ui/gen2/BattleState.lua:3415), where Gen 1's draws a MAXIMUM
-- computed from the record's own PP and a `ppUps` correction
-- (src/substitute.lua's own header). src/gen2substitute.lua writes `maxPp`
-- onto the SAME slot table it mutates in place, so what it needs here is the
-- base move's own real maximum as an absolute number, not a correction meant
-- for a second table Gen 2 never creates.
function M.fieldsFor(catalog, data, slot)
  local def = data and data.moves and data.moves[slot and slot.id]
  if type(def) ~= "table" then return nil end

  local power = tonumber(def.power) or 0
  local id
  if power <= 0 then
    id = catalog.guard
  else
    local rungs = catalog.byType[def.type]
    id = rungs and rungs[M.powerFor(catalog.rows, def.type, power)] or nil
  end
  if not id then return nil end

  if deps and deps.gen2 then
    return { id = id, maxPp = tonumber(def.pp) or M.RECORD_PP }
  end

  -- The base move's own maximum expressed in the units the FIGHT menu's formula
  -- wants, so the menu draws the slot's real remaining PP against the slot's
  -- real maximum.  Shared with the other consumer rather than worked out twice:
  -- two copies of this arithmetic would be two chances to get the menu wrong.
  local ppUps = deps and deps.substitute
    and deps.substitute.menuPPUps(M.RECORD_PP, def.pp, slot.ppUps) or nil
  return { id = id, ppUps = ppUps }
end

-- The per-slot function src/substitute.lua takes.  Built per battle because it
-- closes over that battle's merged data.
function M.picker(catalog, data)
  return function(slot)
    return M.fieldsFor(catalog, data, slot)
  end
end

-- id -> the FIGHT menu's own short name, the display-time-only split
-- data/maxmoves.lua's own `menu` field header describes -- src/gen2movemenu.lua
-- is the one reader, and the registered record's `name` above is still what a
-- save, the battle text row and Mimic all see.  Every rung a row can register
-- shares its one display name, the same one-name-per-row rule
-- src/gmaxmoves.lua's own M.menuNames keeps.
function M.menuNames(rows)
  local out = {}
  local lowered = rows.lowered or {}
  for _, row in ipairs(rows.types) do
    if type(row.menu) == "string" and row.menu ~= "" then
      local seen = {}
      for _, rung in ipairs(rows.ladder) do
        local power = lowered[row.type] and rung.loweredPower or rung.power
        if not seen[power] then
          seen[power] = true
          out[M.idFor(row.stem, power)] = row.menu
        end
      end
    end
  end
  local guardRow = rows.guard
  if guardRow and type(guardRow.menu) == "string" and guardRow.menu ~= "" then
    out[M.PREFIX .. guardRow.stem] = guardRow.menu
  end
  return out
end

-- Max Guard's shield lasts the turn it went up and no longer.  One record, like
-- every other state in this mod, and cleared from three directions so that the
-- flag cannot outlive the turn that set it: the end of the turn, and both ends
-- of the battle.
function M.newGuard()
  return { battler = nil }
end

local function drop(state)
  local battler = state and state.battler
  if state then state.battler = nil end
  if battler then battler.invulnerable = nil end
end

M.onTurnEnded = drop
M.onBattleStarted = drop
M.onBattleEnded = drop

return M
