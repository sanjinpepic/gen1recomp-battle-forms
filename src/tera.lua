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
-- deps.gen2 branches the PP-correction shape the identical way every other
-- substitution catalog in this mod does: Gold's FIGHT menu draws
-- move.pp/move.maxPp straight off the slot with no PP-Up arithmetic, so
-- src/gen2substitute.lua needs the base move's own real maximum as an
-- absolute number, not a correction meant for a second table Gen 2 never
-- creates.
function M.fieldsFor(catalog, data, slot, typeId)
  if not catalog or not typeId then return nil end
  if type(slot) ~= "table" or slot.id ~= M.BASE_MOVE then return nil end
  local id = catalog.byType[typeId]
  if not id then return nil end

  local def = data and data.moves and data.moves[M.BASE_MOVE]
  if deps and deps.gen2 then
    return { id = id, maxPp = (def and tonumber(def.pp)) or M.RECORD_PP }
  end

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
-- deps.gen2 picks src/gen2substitute.lua over src/substitute.lua for the
-- identical reason every other Gen 2 branch in this mod does: Gold has no
-- `curMoves` array to swap, only the mon's own `moves`, mutated in place.
function M.new()
  local sub = deps and (deps.gen2 and deps.gen2substitute or deps.substitute)
  return { mon = nil, type = nil, was = nil, warned = false, catalog = nil,
           moves = sub and sub.new() or nil }
end

local function clear(state)
  state.mon, state.type, state.was = nil, nil, nil
  state.warned = false
  -- Safe to call blind, and it has to be: this runs on battle start as well as
  -- on every teardown, so a Stellar boost table left standing by a crash or an
  -- adopted battle cannot follow a Pokemon into the next fight.
  if deps and deps.stellar then deps.stellar.clear() end
  -- Safe to call blind, and it has to run here rather than only at the
  -- battler-specific teardown paths below: a battle starting mid-Tera (an
  -- adopted battle, or a state left standing by a crash) must not carry a
  -- stale substitution into whatever battler turns up first.
  local sub = deps and (deps.gen2 and deps.gen2substitute or deps.substitute)
  if sub then sub.restore(state.moves) end
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
--
-- WHERE THE TYPE COMES FROM NOW.  The Pokemon, through src/teratype.lua --
-- derived from its own DVs, or read off the stamp the Tera Orb writes when a
-- player spends shards on it.  This file's own header argues that a per-Pokemon
-- type was impossible on Gen 1, and every constraint it names is still true;
-- what changed is that a Pokemon turned out to already carry sixteen per-mon
-- bits nobody had to ask for.  That header stays as written, because the
-- decision it records was correct for what was available at the time.
--
-- The TERA TYPE option is still read, and now means "override every Pokemon
-- with this one" -- AUTO, its new default, is the derived answer.  Keeping the
-- explicit choices is not indecision: a player testing a matchup, and this
-- mod's own suites, need a way to pin the type without breeding for DVs.
function M.chosenType(battle)
  local id = deps.chosen and deps.chosen() or nil
  if id == "auto" or id == nil or id == "" then
    local mon = deps.battlerof.mon(battle and battle.player)
    local data = battle and battle.data
    -- Spelled out rather than `deps.teratype and deps.teratype.of(...) or nil`:
    -- that form collapses the pair to its first value, so every refusal came
    -- back reasonless and the log line said "no_teratype" whatever had actually
    -- gone wrong.
    local derived, why = nil, "no_teratype"
    if deps.teratype then derived, why = deps.teratype.of(data, mon) end
    if not derived then return nil, why end
    id = derived
  end
  if type(id) ~= "string" or id == "" then return nil, "unset" end
  -- Stellar has no chart record and must not be looked for in one -- it does
  -- not replace the Pokemon's typing at all, it scales damage
  -- (src/stellar.lua).  Answered here so the three chart checks below never see
  -- it and never refuse it as an unknown type.
  if deps.stellar and id == deps.stellar.TYPE then
    return id, deps.stellar.NAME
  end
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
      local mon = deps.battlerof.mon(battle.player)
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
    -- TERA BLAST substitution reached Gold once src/gen2substitute.lua was
    -- proven under three real consumers (Max Moves, the type Z-Moves, the
    -- species Z-Moves) -- the "Gen 1 only" refusal that used to stand here
    -- was written before any of that existed and is closed now rather than
    -- inherited. deps.gen2 picks src/gen2substitute.lua and its own target
    -- (the mon itself, already what `battle.player` IS on Gen 2), the
    -- identical branch src/dynamax.lua's and src/zmoves.lua's own `arm`
    -- already make. Arming still succeeds either way -- Terastallizing
    -- needs no Tera Blast in the moveset at all -- but on Gold that success
    -- now carries a real substitution when the mon knows the move, not a
    -- silent no-op.
    arm = function(battle)
      local sub = deps.gen2 and deps.gen2substitute or deps.substitute
      local battler = battle and battle.player
      local mon = deps.battlerof.mon(battler)
      if not sub or not battler or not state.catalog then return true end
      local id = M.chosenType(battle)
      if id then
        local target = deps.gen2 and mon or battler
        sub.apply(state.moves, target, M.picker(state.catalog, battle.data, id))
      end
      return true
    end,

    -- The other half of that pair, required by src/transforms.lua's own
    -- registration guard the moment `arm` exists.  Undoes whatever the arm
    -- above did, or nothing at all if the mon never carried TERA BLAST --
    -- restore() is safe to call blind either way, on either primitive.
    disarm = function()
      local sub = deps.gen2 and deps.gen2substitute or deps.substitute
      if sub then sub.restore(state.moves) end
    end,

    -- Gen 2 has no battler to hold a curTypes copy on -- mon.formTypes is
    -- the field itself, the one src/gen2forms.lua's Battle.speciesDef wrap
    -- reads (installed unconditionally on a Gen 2 boot, main.lua's own
    -- `if gen2 then gen2forms.install(mod) end`), so this writes directly to
    -- the mon the save owns and relies on that wrap already being in place
    -- rather than calling becomeForm -- there is no form here, only a type,
    -- and gen2forms.becomeForm needs a national_dex record this mechanic has
    -- never had reason to have one.
    activate = function(battle)
      if not battle or not battle.player then return false end
      local mon = deps.battlerof.mon(battle.player)
      if not mon then return false end
      local id, name = M.chosenType(battle)
      if not id then return false end

      -- Stellar changes no typing at all, so it takes neither branch below:
      -- state.was stays nil, nothing is written to curTypes or formTypes, and
      -- the only thing that happens is that damage starts being scaled.  The
      -- announcement still runs, because with no type change and no picture
      -- the line is once again the entire visible event.
      if deps.stellar and id == deps.stellar.TYPE then
        state.mon, state.type, state.was = mon, id, nil
        deps.stellar.begin(mon)
        if deps.announce then
          if deps.gen2 then deps.announce.gen2Tera(battle, mon, name)
          else deps.announce.tera(battle, battle.player, name) end
        end
        return true
      end

      if deps.gen2 then
        state.mon, state.type, state.was = mon, id, mon.formTypes
        mon.formTypes = { id }
        if deps.announce then deps.announce.gen2Tera(battle, mon, name) end
        return true
      end

      local battler = battle.player
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
  local mon = deps.battlerof.mon(battler)
  if not mon or state.mon ~= mon or not state.type then return end

  -- Stellar has no type override to reassert.  Reaching the code below with it
  -- would write { "STELLAR" } into curTypes or formTypes -- a type the chart
  -- has no record for, on a mechanic whose whole definition is that it leaves
  -- the typing alone -- and every matchup for that Pokemon would silently
  -- become neutral for the rest of the battle.
  if deps.stellar and state.type == deps.stellar.TYPE then return end

  -- Gen 2's mon.formTypes lives on the mon rather than a rebuilt battler, so
  -- it survives a switch on its own -- there is nothing here to REBUILD the
  -- way Gen 1's makeBattler forces.  What this reapplies against is a
  -- different hazard: main.lua's own battle.battler_switched ordering runs
  -- fusion's and persistent's own switch-in reapply BEFORE this one, and
  -- either would overwrite mon.formTypes with ITS form's own types if this
  -- mon is also carrying one -- Tera is the outermost layer on Gen 2 exactly
  -- as curTypes makes it the outermost on Gen 1, so this has to reassert on
  -- top of whatever ran first, every time, the same "refreshed on every
  -- switch-in" contract state.was already keeps for Gen 1.
  if deps.gen2 then
    state.was = mon.formTypes
    mon.formTypes = { state.type }
    -- TERA BLAST's own substitution needs no rebuild the way Gen 1's does --
    -- mon.moves is the one true array on Gen 2 and a switch never touches it,
    -- so whatever src/gen2substitute.lua wrote at arm time is still standing
    -- on the mon that just came back. Reapplied anyway, restore-then-apply,
    -- for the identical defensive reason mon.formTypes just was above: no
    -- sibling module writes to mon.moves on a switch-in today, but nothing
    -- here should have to assume that stays true forever, and restore() is
    -- safe to call blind on a substitution that never lapsed.
    if deps.gen2substitute and state.catalog then
      deps.gen2substitute.restore(state.moves)
      local battle = ev and ev.battle
      deps.gen2substitute.apply(state.moves, mon,
        M.picker(state.catalog, battle and battle.data, state.type))
    end
    return
  end

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
  local wasStellar = deps.stellar and state.type == deps.stellar.TYPE
  clear(state)
  -- Nothing to put back, and putting `restore` back would be actively wrong on
  -- Gen 2: that branch assigns unconditionally, so a nil `was` -- which is
  -- what Stellar always has -- would clear a persistent form's own formTypes
  -- that this mechanic never touched.
  if wasStellar then return mon ~= nil end
  if not mon or not battler or deps.battlerof.mon(battler) ~= mon then return false end
  if deps.gen2 then
    -- Unlike Gen 1's battler.curTypes -- seeded from the species record and
    -- never legitimately nil -- a Gen 2 mon with no other claim on it really
    -- should end up back at nil, so this restores unconditionally rather
    -- than only `restore ~= nil`.
    mon.formTypes = restore
    return true
  end
  if restore ~= nil then battler.curTypes = restore end
  return true
end

-- Fainting ends it (section 8).  src/resolve.lua's faint handler runs first and
-- reverts whatever FORM the mon carries, which is never this one -- nothing
-- here marks the mon -- so the two handlers cannot collide over curTypes.
function M.onFainted(state, ev)
  local battler = ev and ev.battler
  local mon = deps.battlerof.mon(battler)
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
  if deps.battlerof.mon(battler) == state.mon then
    finish(state, battler)
  else
    clear(state)
  end
end

function M.onBattleStarted(state)
  clear(state)
end

return M
