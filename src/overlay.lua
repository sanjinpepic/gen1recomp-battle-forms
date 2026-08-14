-- What the player is shown, and when.
--
-- The decision is kept separate from the drawing so it can be tested without
-- a graphics context.  battle.overlay fires from both the classic and the
-- widescreen draw paths, which is why the drawing goes through that seam
-- rather than into either layout: the battle screen has two entirely separate
-- draw implementations, and anything drawn outside the seam would appear in
-- only one of them.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

function M.shouldOffer(state)
  local battle = state:current()
  if not battle or state:used() then return false end
  -- The indicator must be on screen exactly when the key is live.  The
  -- engine only fires battle.menu_auxiliary at the command menu with an
  -- empty queue (BattleSafety.inspect), but battle.overlay draws on every
  -- frame regardless of phase; without this check the toggle would appear
  -- during messages and other busy phases where pressing START does nothing.
  if battle.phase ~= "menu" then return false end
  local queue = battle.queue
  if queue and next(queue) ~= nil then return false end
  local mon = battle.player and battle.player.mon
  local formId = deps.eligibility.formForMon(deps.megas, mon)
  if not formId then return false end
  -- A stone can name a form the species table has no record for -- a wrong
  -- id in data/megas.lua, or national_dex data that never loaded -- and
  -- offering the cell then would arm a change Forms.becomeForm can only
  -- refuse.  The record must exist before the menu promises it.
  local pokemon = battle.data and battle.data.pokemon
  return pokemon ~= nil and pokemon[formId] ~= nil
end

function M.label(state)
  return state:isArmed() and "MEGA*" or "MEGA"
end

return M
