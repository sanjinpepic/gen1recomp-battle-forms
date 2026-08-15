-- Terastallization: the first transformation here that changes nothing but the
-- Pokemon's TYPE.
--
-- Everything else in this mod is a form change (mega, primal, the eight
-- condition-driven ones) or a battle state carrying one (Gigantamax).  This is
-- neither.  There is no mon.form, no species record to look up, no sprite to
-- rebuild and no Tera crystal to draw -- Gen 1 has no art for one and this mod
-- ships none -- so the type override is the entire mechanic and the battle
-- message is the only thing that marks it happening, exactly as it was for
-- primal reversion.
--
-- WHERE THE TYPE COMES FROM, which is the decision worth reading.
--
-- The guide keeps a Tera type per Pokemon (`pokemon.teraType`).  A stamp on the
-- mon is a shape this mod already has -- src/eligibility.lua carries a stone or
-- an orb that way -- but nothing here could WRITE one.  A Gen 1 party screen
-- has no field to pick a type in, the battle cell is one row holding one label,
-- and the only other way to set a per-mon value in this engine is an item used
-- on the mon, which would mean eighteen new bag items to express one choice.  A
-- stamp is also save data by definition, so a mechanic that exists only for the
-- length of a battle would be writing into the save to decide what it does.
--
-- The type is therefore a MOD OPTION, read live at activation the way DEBUG
-- TRACE is: the player picks it in the manager, it applies to whichever Pokemon
-- terastallizes, and the next battle can use another one.  Nothing about it is
-- written anywhere.
--
-- Defaulting to the Pokemon's own primary type was the other candidate, and it
-- is what the real games most often give a Pokemon.  It is rejected outright
-- here: a single-typed Pokemon terastallizing into the type it already has
-- changes nothing whatsoever, and this mechanic has no picture, no name change
-- and no stat change to be noticed by instead.
--
-- WHAT THE OVERRIDE MAY TOUCH.  battler.curTypes is seeded from the SPECIES
-- record by reference (BattleState.lua:514, `curTypes = def.types`) -- the same
-- trap curStats has with mon.stats, one table further out: writing
-- curTypes[1] = X would retype every Charizard in the loaded data for the rest
-- of the session, in and out of battle.  So an application ASSIGNS a fresh
-- one-element table and never touches the one it found, and the unwind puts the
-- original table back by reference, which also restores BattleCheckpoint's
-- `curTypesFromDefinition` shortcut (BattleCheckpoint.lua:71) to the answer it
-- gave before.
--
-- That is also what makes the save safe by construction rather than by sweep.
-- Nothing here writes to a mon at all, and a battler dies with the battle that
-- built it, so the single field this mechanic touches cannot outlive the fight.
--
-- DURATION.  The guide's matrix gives Terastallization its own row: it survives
-- switching, where Dynamax ends on one, and it ends on fainting and with the
-- battle.  One per battle per trainer, through the registry's own spent flag.
local M = {}

M.ID = "tera"

-- TERA BLAST's own registered ids, one per type it may become.  Every id
-- wears the mod's name for the reason src/maxmoves.lua's and src/zmoves.lua's
-- do: a collision is a load failure for whichever registers second.
M.PREFIX = "BATTLE_FORMS_TERA_BLAST_"

-- The move's real, permanent identity -- National Dex registers it (Normal,
-- 80 power, special, 100 accuracy, 10 PP) as part of its modern-move catalog,
-- and this file neither invents nor duplicates it.  A Pokemon that knows
-- TERABLAST and never terastallizes plays it exactly as registered: the
-- substitution below only ever touches a slot carrying this exact id, so an
-- unconverted Tera Blast is not a special case, it is simply the case where
-- nothing here ever ran.
M.BASE_MOVE = "TERABLAST"

-- The PP every type variant is registered at, and why 5 rather than 10:
-- the FIGHT menu draws its maximum off the RECORD, and src/substitute.lua's
-- menuPPUps corrects that maximum against TERABLAST's own PP read live from
-- `data.moves` at substitution time -- the same reason src/zmoves.lua's and
-- src/maxmoves.lua's records are 5 rather than their base moves' own PP.
M.RECORD_PP = 5

function M.idFor(typeId) return M.PREFIX .. typeId end

local deps = nil

function M.bind(modules) deps = modules end

-- Whether the merged type chart carries this type.  Guarded rather than
-- trusted, exactly as src/maxmoves.lua's and src/zmoves.lua's own typeExists
-- do: `get` is a registry courtesy and a build that does not offer it must
-- leave a variant out rather than take the mod down with a nil call.
local function typeExists(mod, typeId)
  local registry = mod.content and mod.content.type_chart
  if not registry or type(registry.get) ~= "function" then return false end
  local ok, record = pcall(registry.get, registry, typeId)
  return ok and record ~= nil
end

-- Registers one TERA BLAST variant per type the running game's chart can
-- resolve, and answers with the catalog M.fieldsFor reads: type -> the id
-- that type substitutes in.  A type the chart has never heard of is skipped
-- and SAID -- registering a move naming an unresolved type would fail the
-- whole mod's load rather than cost one variant, the same rule
-- src/maxmoves.lua's and src/zmoves.lua's installs run on.
--
-- `category` is explicitly "special" on every variant, where the Max Moves
-- and the type Z-Moves deliberately leave it off so Gen 1 decides physical or
-- special by type.  Tera Blast diverges from that on purpose: the real games
-- keep it Special whatever type it becomes, TERABLAST's own registered
-- record already says so, and Gen 1's move schema lets a record's own
-- category win over the type-based fallback -- so keeping it is the more
-- faithful choice here, not an inconsistency with the other two.
function M.install(mod, types)
  local catalog = { byType = {} }
  for _, typeId in ipairs(types or {}) do
    if typeExists(mod, typeId) then
      local id = M.idFor(typeId)
      mod.content.moves:register(id, {
        id = id,
        name = "TERA BLAST",
        type = typeId,
        power = 80,
        category = "special",
        accuracy = 100,
        pp = M.RECORD_PP,
        effect = "NO_ADDITIONAL_EFFECT",
      })
      if deps and deps.anim and deps.anim.teraBlastSeq then
        mod.content.battle_anims:register(id, { seq = deps.anim.teraBlastSeq() })
      end
      catalog.byType[typeId] = id
    elseif deps and deps.log then
      deps.log:warn(
        "battle_forms: no TERA BLAST variant for %s -- this game's merged "
          .. "type chart has no record for that type, which is what a "
          .. "Red-era chart looks like; a Pokemon terastallizing into it "
          .. "keeps TERA BLAST as an ordinary Normal-type attack", tostring(typeId))
    end
  end
  return catalog
end

-- The fields a substitute for `slot` should carry, or nil to leave the slot
-- alone.  nil covers three cases and all three are the same answer: this is
-- not the TERA BLAST slot, the chosen type has no variant in this catalog,
-- or the catalog was never built at all (a build with no Tera Blast rows
-- bound, which src/tera.lua's own unit suite exercises on purpose).
function M.fieldsFor(catalog, data, slot, typeId)
  if not catalog or not typeId then return nil end
  if type(slot) ~= "table" or slot.id ~= M.BASE_MOVE then return nil end
  local id = catalog.byType[typeId]
  if not id then return nil end

  local def = data and data.moves and data.moves[M.BASE_MOVE]
  local ppUps = deps and deps.substitute and def
    and deps.substitute.menuPPUps(M.RECORD_PP, def.pp, slot.ppUps) or nil
  return { id = id, ppUps = ppUps }
end

-- The per-slot function src/substitute.lua takes.  Built per activation
-- because it closes over the type that activation resolved to.
function M.picker(catalog, data, typeId)
  return function(slot)
    return M.fieldsFor(catalog, data, slot, typeId)
  end
end

-- One record, like Dynamax's and for the same reasons: only the player's side
-- can reach the menu cell and the trainer gets one activation a battle, so
-- there is never a second Terastallization to track -- and one record is one
-- thing to drop when the battle ends, which is what stops a mon reference
-- outliving the battle that owned it.
--
-- `was` is the curTypes table the battler had before the override, kept by
-- reference so the unwind restores what was there rather than a copy of it.
--
-- `moves` is the TERA BLAST substitution's own record, created here rather
-- than on arming so that every teardown path can hand it to restore() blind,
-- including the ones that run when nothing was ever substituted -- the same
-- contract src/zmoves.lua's `moves` field keeps.  `catalog` is stashed by
-- M.entry below rather than threaded through every handler's signature,
-- because unlike a Z-Move's substitution -- which ends on switching out --
-- this one has to be rebuilt on every switch-IN too, from handlers that only
-- ever receive `state`.
function M.new()
  return { mon = nil, type = nil, was = nil, warned = false, catalog = nil,
           moves = deps and deps.substitute and deps.substitute.new() or nil }
end

local function clear(state)
  state.mon, state.type, state.was = nil, nil, nil
  state.warned = false
  -- Safe to call blind, and it has to run here rather than only at the
  -- battler-specific teardown paths below: a battle starting mid-Tera (an
  -- adopted battle, or a state left standing by a crash) must not carry a
  -- stale substitution into whatever battler turns up first.
  if deps and deps.substitute then deps.substitute.restore(state.moves) end
end

-- Every type id the RUNNING game can resolve, which is not a fixed list.  The
-- engine registers Red's fifteen; DARK, STEEL and FAIRY exist only once
-- National Dex registers a chart over the top of them, which it does with its
-- own NATIONAL DEX or TYPE CHART option and not otherwise.  Reading the merged
-- chart rather than a list of our own is the only way this cannot promise a
-- type the type chart has never heard of.
local function typesOf(battle)
  local chart = battle and battle.data and battle.data.type_chart
  return chart and chart.types or nil
end

-- The chosen type and the name to print for it, or nil and why not.  The name
-- comes off the chart record because the id and the name differ for exactly one
-- type -- PSYCHIC_TYPE prints as PSYCHIC -- and a message reading
-- "PSYCHIC_TYPE type!" would be this mod showing its own plumbing.
function M.chosenType(battle)
  local id = deps.chosen and deps.chosen() or nil
  if type(id) ~= "string" or id == "" then return nil, "unset" end
  local types = typesOf(battle)
  if not types then return nil, "no_chart" end
  local record = types[id]
  if not record then return nil, "unknown_type" end
  local name = type(record) == "table" and record.name or nil
  return id, type(name) == "string" and name ~= "" and name or id
end

-- A guard that refuses must say so out loud, and this one refuses in the way
-- that looks from a chair exactly like every other absent cell: the player has
-- the Tera Orb, and the cell is not there because the type they picked does not
-- exist in this game.  Once per battle, because `available` is asked on every
-- drawn frame.
local function refuse(state, reason)
  if state.warned then return end
  state.warned = true
  if not deps.log then return end
  deps.log:warn(
    "battle_forms: TERA TYPE is %s, which this game has no type record for "
      .. "(%s) -- DARK, STEEL and FAIRY exist only once National Dex "
      .. "registers a chart, so the cell stays away rather than arming a "
      .. "change that cannot be made",
    tostring(deps.chosen and deps.chosen()), tostring(reason))
end

-- `catalog` is TERA BLAST's own -- M.install's answer -- and optional: a test
-- exercising only the type override, or a build where no Tera Blast rows were
-- bound, hands nothing and gets a Terastallization that changes type and
-- leaves every move exactly as it found it, which is also correct: a
-- Pokemon with no catalog to check against simply has no TERA BLAST slot
-- this file can ever match.
function M.entry(state, catalog)
  state.catalog = catalog
  return {
    id = M.ID,
    -- Seven characters is the whole budget the classic layout leaves a label
    -- once the armed '*' and the cycle marker have taken theirs
    -- (tests/battle_forms_menu_test.lua measures it), and TERASTALLIZE is
    -- nowhere near fitting.  TERA is what the games' own shorthand calls it.
    label = "TERA",

    -- Like Dynamax and unlike mega evolution, every species may do this, so the
    -- trainer's own item is not the outer of two tiers -- it is the only tier
    -- there is, and without it nothing terastallizes and the cell is simply
    -- absent rather than present and refusing.  The chosen type is checked here
    -- as well, for the reason mega checks its form record here: the menu must
    -- not promise a change the activation can only refuse.
    available = function(battle)
      if not deps.keyitems.held(battle, deps.keyitems.TERA_ORB) then
        return false
      end
      local mon = battle.player and battle.player.mon
      if not mon or not mon.species then return false end
      local id, why = M.chosenType(battle)
      if not id then
        refuse(state, why)
        return false
      end
      return true
    end,

    -- TERA BLAST's type substitution goes on here, at the same seam
    -- src/zmoves.lua's does and for the same reason: the FIGHT menu reads
    -- `curMoves` fresh the moment it draws, so a slot's id has to already be
    -- the tera-typed variant by the time the player opens the menu, not by
    -- the time turn_started runs and the choice has already been captured by
    -- reference.  Unlike a Z-Move this never gates the arming itself --
    -- Terastallizing needs no Tera Blast in the moveset at all, so a mon that
    -- does not know it simply arms with nothing to substitute, exactly as it
    -- would if this whole catalog did not exist.
    arm = function(battle)
      local battler = battle and battle.player
      if not deps.substitute or not battler or not state.catalog then return true end
      local id = M.chosenType(battle)
      if id then
        deps.substitute.apply(state.moves, battler, M.picker(state.catalog, battle.data, id))
      end
      return true
    end,

    -- The other half of that pair, required by src/transforms.lua's own
    -- registration guard the moment `arm` exists.  Undoes whatever the arm
    -- above did, or nothing at all if the mon never carried TERA BLAST --
    -- src/substitute.lua's restore() is safe to call blind either way.
    disarm = function()
      if deps.substitute then deps.substitute.restore(state.moves) end
    end,

    activate = function(battle)
      local battler = battle.player
      local mon = battler and battler.mon
      if not mon then return false end
      local id, name = M.chosenType(battle)
      if not id then return false end

      state.mon, state.type, state.was = mon, id, battler.curTypes
      battler.curTypes = { id }

      -- Announced because there is nothing else at all to notice: no form, no
      -- picture, no name change, and no animation.  The line names the type
      -- for the same reason -- the type IS the change, and a message that
      -- only said it happened would leave the player to work out what it did
      -- from the damage numbers.
      if deps.announce then deps.announce.tera(battle, battler, name) end
      return true
    end,
  }
end

-- Switching out does NOT end it, which is the whole difference between this and
-- Dynamax at the same seam.  A switch builds a brand-new battler through
-- makeBattler, which seeds curTypes from the base species and knows nothing
-- about any of this, so the override is applied again to the mon arriving --
-- ev.battler, where Dynamax reads ev.previous because it is watching for the
-- mon that LEFT.
--
-- Silent on purpose: the mon has just been sent out and the engine is part-way
-- through its own send-out text, and this is a state that never lapsed rather
-- than one being entered again.
function M.onBattlerSwitched(state, ev)
  local battler = ev and ev.battler
  local mon = battler and battler.mon
  if not mon or state.mon ~= mon or not state.type then return end
  state.was = battler.curTypes
  battler.curTypes = { state.type }

  -- TERA BLAST reapplies for the same reason curTypes just did: curMoves is
  -- rebuilt from mon.moves on every send-out (makeBattler is form-blind, and
  -- move-blind the same way), so the substitution standing on the battler
  -- that left is gone with it.  restore() first, unconditionally: it is safe
  -- to call blind on a state that was never applied, and on one still
  -- pointing at the discarded battler it releases that association -- without
  -- it, apply() below would refuse on the grounds that a substitution is
  -- already standing, when what is actually standing is stale.
  if deps.substitute and state.catalog then
    deps.substitute.restore(state.moves)
    local battle = ev and ev.battle
    deps.substitute.apply(state.moves, battler,
      M.picker(state.catalog, battle and battle.data, state.type))
  end
end

-- Puts the battler's own types back, and only when the battler in hand is
-- holding the mon this state is about.  Off the field there is nothing to
-- restore: curTypes died with the battler the switch discarded, and the next
-- send-out builds it from the species again.
local function finish(state, battler)
  local restore = state.was
  local mon = state.mon
  clear(state)
  if not mon or not battler or battler.mon ~= mon then return false end
  if restore ~= nil then battler.curTypes = restore end
  return true
end

-- Fainting ends it (section 8).  src/resolve.lua's faint handler runs first and
-- reverts whatever FORM the mon carries, which is never this one -- nothing
-- here marks the mon -- so the two handlers cannot collide over curTypes.
function M.onFainted(state, ev)
  local battler = ev and ev.battler
  local mon = battler and battler.mon
  if not mon or state.mon ~= mon then return end
  finish(state, battler)
end

-- The battle ending unwinds it, on the field and off.  There is no party sweep
-- to do beside src/resolve.lua's: that one exists because a form marks the mon
-- and would otherwise reach the save, and this mechanic marks nothing -- so
-- restoring the battler still standing there and dropping the mon reference is
-- the whole of the work.
function M.onBattleEnded(state, ev)
  local battler = ev and ev.battle and ev.battle.player
  if battler and battler.mon == state.mon then
    finish(state, battler)
  else
    clear(state)
  end
end

function M.onBattleStarted(state)
  clear(state)
end

return M
