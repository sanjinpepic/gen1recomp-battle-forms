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

local deps = nil

function M.bind(modules) deps = modules end

-- One record, like Dynamax's and for the same reasons: only the player's side
-- can reach the menu cell and the trainer gets one activation a battle, so
-- there is never a second Terastallization to track -- and one record is one
-- thing to drop when the battle ends, which is what stops a mon reference
-- outliving the battle that owned it.
--
-- `was` is the curTypes table the battler had before the override, kept by
-- reference so the unwind restores what was there rather than a copy of it.
function M.new()
  return { mon = nil, type = nil, was = nil, warned = false }
end

local function clear(state)
  state.mon, state.type, state.was = nil, nil, nil
  state.warned = false
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

function M.entry(state)
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
