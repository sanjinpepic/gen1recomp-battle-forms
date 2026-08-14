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
function M.offered(state)
  local out = {}
  local battle = state:current()
  if not battle then return out end
  -- The cell must be on screen exactly when the key is live.  The engine only
  -- fires battle.menu_auxiliary at the command menu with an empty queue
  -- (BattleSafety.inspect), but the draw seams run on every frame regardless
  -- of phase; without this check the cell would appear during messages and
  -- other busy phases where pressing A does nothing.
  if battle.phase ~= "menu" then return out end
  local queue = battle.queue
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

function M.shouldOffer(state)
  return #M.offered(state) > 0
end

-- The entry the cell is currently showing.  Falls back to the first on offer
-- when the selection has gone stale -- the mon it belonged to switched out, a
-- stone was taken away -- because the cell has to name something for as long
-- as it is drawn at all.
function M.selected(state)
  local offered = M.offered(state)
  local id = state:selected()
  for _, entry in ipairs(offered) do
    if entry.id == id then return entry end
  end
  return offered[1]
end

-- The armed marker belongs to the cell rather than to each entry's own label
-- string, so a cell hosting several transformations marks them all the same
-- way and a new mechanic cannot invent its own notation.
function M.label(state)
  local entry = M.selected(state)
  if not entry then return nil end
  if state:armed() == entry.id then return entry.label .. "*" end
  return entry.label
end

-- Whether the cell is a selector right now rather than a plain label, which
-- is what src/menu.lua draws its cycle marker from and what decides whether
-- LEFT/RIGHT cycle -- one predicate, so a cell that says it can be cycled and
-- a cell that can be are the same cell.
--
-- Deliberately NOT folded into label() the way the armed '*' is.  The marker
-- is a font tile, and a tile reached through a string goes via Font.encode,
-- which hands any single non-ASCII character to the TTF in a translated build
-- instead of to the page the glyph lives on.  Keeping it out also means one
-- transformation on offer reaches Font.draw with exactly the string it always
-- has, rather than with a string that happens to come out the same.
function M.cyclable(state)
  return #M.offered(state) > 1
end

-- Moves the selection along the offered list and wraps, so the cell reaches
-- every transformation from every other one.  Nothing to do below two: with a
-- single entry the cell is a label, not a selector, and src/menu.lua leaves
-- LEFT/RIGHT to mean what they have always meant.
function M.cycle(state, step)
  local offered = M.offered(state)
  if #offered < 2 then return end
  local current = M.selected(state)
  local at = 1
  for i, entry in ipairs(offered) do
    if entry == current then at = i end
  end
  state:select(offered[(at - 1 + step) % #offered + 1].id)
end

return M
