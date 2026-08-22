-- What a Terastallization looks like while it is standing, which until now was
-- nothing at all.
--
-- src/tera.lua's own header says it plainly: no form, no picture, no name
-- change, no animation, so the battle message is the only thing that marks it
-- happening.  That was defensible when the type was a mod option the player
-- had set themselves -- they knew what they picked.  It stopped being
-- defensible in 0.60.0, when the type became a property OF THE POKEMON derived
-- from its own DVs: a player can now genuinely not know what their Charizard
-- terastallized into, and once the activation text has scrolled away there is
-- nothing on screen that would tell them.
--
-- BUILT THE WAY DYNAMAX'S READOUT IS, deliberately and not by coincidence.
-- src/hpscale.lua paints its scaled HP numbers through `battle.overlay`, a
-- draw-only seam that fires after the engine has already composited the real
-- HUD -- so it repaints over finished pixels, holds no state the draw path can
-- disagree with, and composes with any other mod's overlay rather than
-- replacing it.  Everything below mirrors that file: the same hook, the same
-- next()-first discipline, the same reproduced visibility guards, the same
-- clear-then-draw because Font.draw is a transparent blit that never wipes
-- what it did not cover.
--
-- WHICH SLOT, and why this one is not an invention.  The level.  Both games
-- print it at tile (14,8) -- pixel (112,64) -- and both ALREADY swap that exact
-- slot for a three-character status tag when the Pokemon is poisoned or burned
-- (BattleState.lua's own `if self.player.shownStatus`, and Gold's
-- `self:statusTag(player) or "<LV>"..level`).  So this is a slot the engines
-- themselves treat as showing something other than its default, at a width they
-- themselves chose, rather than a rectangle this mod decided was empty.
--
-- The name row was the other candidate and is rejected: `nameX`
-- (BattleState.lua:5051) right-aligns the nickname into tiles 10-18, so the gap
-- before it exists only for SHORT names and closes exactly when somebody names
-- their Charizard CHARIZARD.  A prefix that collides intermittently, depending
-- on how long a nickname is, is a worse bug than no indicator.
--
-- STATUS WINS.  When a status tag is up this draws nothing, because the engine
-- has already decided that slot belongs to the status -- and being told a
-- Pokemon is paralysed matters more, in the moment, than being reminded what it
-- terastallized into.  The cost is that the tag is invisible on a statused
-- Pokemon, which is stated here rather than discovered later.
local Font = require("src.render.Font")

local M = {}

-- Three letters, because three is what the slot holds on Gold: its gender
-- symbol sits at tile 17 (game/src/ui/gen2/BattleState.lua's own
-- `genderSymbol` print), leaving 14-16.  Gen 1 has room for five there and
-- deliberately does not use it -- one tag that reads the same on both games is
-- worth more than two characters, and a player moving between them should not
-- have to learn a second vocabulary.
--
-- PSN is Poison here and PSN is also the poison STATUS tag on both games.  They
-- cannot appear at once -- a status tag suppresses this one entirely, see the
-- header -- so the collision is never on screen twice, but it is real enough to
-- write down: a player who sees PSN where the level was is looking at a
-- Poison-Tera Pokemon, and a poisoned one shows PSN in the same place for a
-- different reason.  Every other pairing is distinct.
M.CODES = {
  NORMAL = "NRM", FIGHTING = "FGT", FLYING = "FLY", POISON = "PSN",
  GROUND = "GRD", ROCK = "RCK", BUG = "BUG", GHOST = "GHO",
  FIRE = "FIR", WATER = "WTR", GRASS = "GRS", ELECTRIC = "ELC",
  PSYCHIC_TYPE = "PSY", ICE = "ICE", DRAGON = "DRG", DARK = "DRK",
  STEEL = "STL", FAIRY = "FRY",
  -- Stellar is not STL: that is Steel, and the two would be indistinguishable
  -- in the one place either is ever shown.
  STELLAR = "STR",
}

-- Tile (14,8) on both games, which is the same pixel on both -- not a
-- coincidence, the identical GB HUD layout src/hpscale.lua's own slots trace
-- to.  Three tiles wide, matching the status tag the engines print here.
local SLOT = { x = 112, y = 64, w = 24, h = 8 }

-- Gen 1's widescreen path shifts the whole player HUD block right by the same
-- offset src/hpscale.lua's own WIDE_SLOT carries (240 - 88 = 152).
local WIDE_DX = 152

-- The tag for a type, or nil for one this table has no code for -- a type
-- registered by another mod, which must degrade to drawing nothing rather than
-- to drawing a truncated guess.
function M.codeFor(typeId)
  if type(typeId) ~= "string" then return nil end
  return M.CODES[typeId]
end

-- What to paint for this mon, or nil.  Separated from the drawing for
-- src/overlay.lua's own reason: a decision made inside a draw function is a
-- decision that cannot be tested without a graphics context.
function M.tagFor(state, mon)
  if not mon or not state or state.mon ~= mon then return nil end
  return M.codeFor(state.type)
end

local function paint(x, y, text, F)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", x, y, SLOT.w, SLOT.h)
  love.graphics.setColor(0, 0, 0, 1)
  ;(F or Font).draw(text, x, y)
end

-- The same visibility rule both Gen 1 draw paths already apply to the player's
-- HUD block, reproduced rather than read off a shared flag for the reason
-- src/hpscale.lua's own playerHudVisible gives: battle.overlay fires after both
-- draw functions have returned, with none of their locals left to ask.
--
-- The status check is this file's own addition and is the header's "status
-- wins": `shownStatus` is the field Gen 1 branches on before choosing between
-- the status label and the level, so reading the same field is what keeps this
-- from painting over a status the engine just decided to show.
function M.visible(battle)
  if not (battle and battle.player) then return false end
  if battle.player.shownStatus then return false end
  local ok, shown = pcall(battle.statusHUDVisible, battle)
  if not (ok and shown) then return false end
  return not battle.safari and not battle.demo and not battle.showPlayerBack
    and (battle.introSlide or 0) == 0
end

function M.draw(state, battle, FontOverride)
  local mon = battle and battle.player and battle.player.mon
  local tag = M.tagFor(state, mon)
  if not tag or not M.visible(battle) then return end
  local wide = false
  local okWide, answer = pcall(battle.wideLayout, battle)
  if okWide then wide = answer and true or false end
  paint(SLOT.x + (wide and WIDE_DX or 0), SLOT.y, tag, FontOverride)
end

-- ---- Gen 2 -------------------------------------------------------------
--
-- Gold has no widescreen battle path at all, so there is one slot rather than a
-- classic/wide pair -- the identical shape src/hpscale.lua's own Gen 2 half
-- has, and for the identical reason.
--
-- `uiBattle` is the UI screen, never the engine battle: statusHUDVisible,
-- showPlayerHud and hudCleared are methods and fields on that class.  Each is
-- pcall'd so a stubbed or reshaped screen degrades this overlay to painting
-- nothing rather than taking a draw frame down with it.
function M.gen2Visible(uiBattle)
  if not uiBattle then return false end
  local okVisible, visible = pcall(uiBattle.statusHUDVisible, uiBattle)
  if not (okVisible and visible) then return false end
  if not uiBattle.showPlayerHud then return false end
  local okCleared, cleared = pcall(uiBattle.hudCleared, uiBattle, "player")
  if okCleared and cleared then return false end
  -- Gold's own status tag takes this slot the same way Gen 1's does, through a
  -- method rather than a field.  A screen that does not offer it is treated as
  -- having no status up, which is the permissive answer on purpose: the worst
  -- case is a tag drawn over a level, where refusing would mean a mechanic that
  -- silently stops showing itself.
  local player = uiBattle.battle and uiBattle.battle.player
  local okTag, tag = pcall(uiBattle.statusTag, uiBattle, player)
  if okTag and tag then return false end
  return true
end

function M.drawGen2(state, uiBattle, FontOverride)
  local engineBattle = uiBattle and uiBattle.battle
  -- Gold's UI class carries no top-level `.player`; the engine object's own is
  -- a bare mon with no wrapper (src/battlerof.lua's own header).
  local tag = M.tagFor(state, engineBattle and engineBattle.player)
  if not tag or not M.gen2Visible(uiBattle) then return end
  paint(SLOT.x, SLOT.y, tag, FontOverride)
end

-- next() first and unconditionally, the discipline every wrap in this mod
-- keeps: an empty chain costs nothing, and a populated one -- another mod's
-- overlay, or src/hpscale.lua's own -- must still run whether or not a
-- Terastallization is live right now.
function M.install(mod, state, gen2)
  mod.hooks:wrap("battle.overlay", function(nextFn, battle)
    nextFn(battle)
    if gen2 then
      M.drawGen2(state, battle)
    else
      M.draw(state, battle)
    end
  end)
end

return M
