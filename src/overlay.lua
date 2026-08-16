-- What the transformation cell says, and when it says anything at all.
--
-- The decision is kept separate from the drawing so it can be tested without
-- a graphics context.  The battle screen has two entirely separate draw
-- implementations, classic and widescreen, and src/menu.lua patches both --
-- so a decision made inside either one would be a decision made in only half
-- the game.
--
-- WHICH transformations are on offer is the registry's answer; WHEN the cell
-- may appear at all is decided here, because that half is the same for every
-- mechanic that will ever be registered: the command menu, nothing queued, a
-- battle still running.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The entries on offer right now, in registration order.  A fresh table per
-- call rather than one buffer kept between them: the input path and both draw
-- paths ask on the same frame, and none of them may see another's answer
-- change underneath it.
--
-- `uiBattle` is optional and exists for Gen 2 alone.  On Gen 1 one object
-- backs both the phase/queue the menu reads and the battle src/arm.lua
-- caches from battle.started, so `state:current()` already IS the phase
-- source and every caller before src/gen2menu.lua existed left this nil.  On
-- Gen 2 they are two different objects -- src/battlerof.lua's own header
-- says why -- Gold's `phase`/`queue`/`menuIndex` live on the UI
-- src/ui/gen2/BattleState.lua instance, and battle.started's own payload is
-- the ENGINE game/src/battle/gen2/Battle.lua instance (`.player`, `.enemy`,
-- `.data`, `.save`, no `.phase` at all), which is what `state:current()`
-- holds.  src/gen2menu.lua hands its own `self` (the UI object every frame
-- already gives it) in here as `uiBattle` so the phase/queue gate reads the
-- right table; every entry's own `available(battle)` still reads the engine
-- object, unchanged, because that is the shape src/mega.lua and the rest
-- already expect.
function M.offered(state, uiBattle)
  local out = {}
  local battle = state:current()
  if not battle then return out end
  local phaseSource = uiBattle or battle
  -- The cell must be on screen exactly when the key is live.  The engine only
  -- fires battle.menu_auxiliary at the command menu with an empty queue
  -- (BattleSafety.inspect), but the draw seams run on every frame regardless
  -- of phase; without this check the cell would appear during messages and
  -- other busy phases where pressing A does nothing.
  if phaseSource.phase ~= "menu" then return out end
  local queue = phaseSource.queue
  if queue and next(queue) ~= nil then return out end
  -- One manual transformation per battle across all of them: spending any
  -- registered entry takes every entry off the cell for the rest of the fight,
  -- which is the mainline rule -- Sun/Moon let a trainer have a Z-Move or a
  -- mega and not both.
  --
  -- Enforced here rather than a second time in src/arm.lua's toggle, and that
  -- is the point of putting it here at all: arming is only ever reached
  -- through a cell this function decided to draw, so one answer to "may the
  -- player reach this" cannot disagree with itself the way two would.  The
  -- cell simply stops listing anything, the same silent absence a missing key
  -- item already produces.
  --
  -- The per-id check below is a separate rule and stays separate: it is what a
  -- mechanic exempted from this one would still be held to, and it is what
  -- keeps a spent mega spent.
  if state:usedAny() then return out end
  for _, entry in ipairs(deps.registry:all()) do
    if not state:used(entry.id) and entry.available(battle) then
      out[#out + 1] = entry
    end
  end
  return out
end

function M.shouldOffer(state, uiBattle)
  return #M.offered(state, uiBattle) > 0
end

-- The entry the cell is currently showing.  Falls back to the first on offer
-- when the selection has gone stale -- the mon it belonged to switched out, a
-- stone was taken away -- because the cell has to name something for as long
-- as it is drawn at all.
function M.selected(state, uiBattle)
  local offered = M.offered(state, uiBattle)
  local id = state:selected()
  for _, entry in ipairs(offered) do
    if entry.id == id then return entry end
  end
  return offered[1]
end

-- What the cell says before anything is armed.  A category word rather than
-- any one registered entry's name: src/formmenu.lua is where the player
-- actually picks among what is on offer now, so the cell itself no longer
-- has to pre-name one of them, and naming one would be a specific promise a
-- generic word is not -- with two or more offered there was never a
-- principled reason the pre-arm label should be the first one over any
-- other.
local GENERIC_LABEL = "FORM"
M.GENERIC_LABEL = GENERIC_LABEL

-- What the cell says.  Armed beats everything: the cell exists to say what
-- is ABOUT to happen or already has, and once something is armed that is
-- always the more important fact than which ones are merely on offer.
-- Looked up straight off the registry rather than off the offered list, so
-- an entry that armed and then dropped off `offered` (its own predicate
-- turning false while substituted moves are still standing) still gets
-- named correctly instead of the cell falling silent on the one entry that
-- most needs to keep saying what it is.
--
-- The generic label, not any specific entry's, is what src/formmenu.lua's
-- own header on the armed-state decision calls out: replacing a whole word
-- on arming is a far bigger, more legible change than the trailing '*' alone
-- ever was, and it costs the same one cell this mod has ever had.
function M.label(state, uiBattle)
  local armedId = state:armed()
  if armedId then
    local entry = deps and deps.registry and deps.registry:get(armedId)
    if entry then return entry.label .. "*" end
  end
  if #M.offered(state, uiBattle) == 0 then return nil end
  return GENERIC_LABEL
end

return M
