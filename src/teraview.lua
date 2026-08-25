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
--- `state` may be ONE state or a LIST of them, and both spellings are live:
--- the player's side passes one, and the boot passes both sides' now that
--- enemy trainers terastallize too (src/trainerai.lua). Resolved by asking
--- which state claims THIS Pokemon, so a tag can never be painted from the
--- other side's Terastallization.
-- A Dynamax has no picture of its own. On Gold it visibly grows instead
-- (src/gen2dynamaxgrow.lua), but Red has no draw-time scaling seam at all --
-- frontSize is read once at ROM-import time and battle.overlay fires after the
-- battler is already drawn -- so a Dynamaxed Pokemon there stands in its own
-- unchanged shape, and once the message scrolled away nothing said it still
-- was one.
--
-- So it borrows this same slot. A Pokemon can only have ONE of the trainer's
-- transformations in a battle (src/arm.lua's shared once-per-battle rule), so
-- a Tera tag and a Dynamax tag can never contend for the space.
--
-- A Gigantamax says GMX rather than DYN: it IS a different shape, the picture
-- already shows that much, and a player looking at an unfamiliar silhouette is
-- exactly who wants to know which of the two they are facing.
local DYNAMAX_TAG, GIGANTAMAX_TAG = "DYN", "GMX"

local MEGA_TAG, ZMOVE_TAG = "MEG", "ZMV"

-- Every mega FORM id, as a set, built once per megas table.
--
-- A transformed Pokemon carries its form id and nothing that says which
-- mechanic put it there -- a Gigantamax, a persistent held-item form and a
-- condition-driven form all set the same field. So "is this a mega" is asked
-- of the pairing table that defines them rather than guessed from the value.
local megaForms, megaFormsFrom = nil, nil
local function megaFormSet(megas)
  if type(megas) ~= "table" then return nil end
  if megaForms and megaFormsFrom == megas then return megaForms end
  local set = {}
  for _, byStone in pairs(megas) do
    if type(byStone) == "table" then
      for _, formId in pairs(byStone) do set[formId] = true end
    end
  end
  megaForms, megaFormsFrom = set, megas
  return set
end

--- The one tag this Pokemon should be wearing, or nil.
---
--- `sources` carries whichever of the five are wired: `tera` and `dynamax` and
--- `zmove` are states (one or a list), `megas` is the pairing table. Asked in
--- a fixed order, which costs nothing to get right because the trainer's
--- once-per-battle rule (src/arm.lua) means a Pokemon can only ever be wearing
--- one of them at a time.
function M.gimmickTagFor(sources, mon)
  if not mon or type(sources) ~= "table" then return nil end
  local tag = M.tagFor(sources.tera, mon)
  if tag then return tag end
  tag = M.dynamaxTagFor(sources.dynamax, mon)
  if tag then return tag end
  if M.zmoveActive(sources.zmove, mon) then return ZMOVE_TAG end
  local set = megaFormSet(sources.megas)
  if set and mon.form and set[mon.form] then return MEGA_TAG end
  return nil
end

--- Whether a Z-Move is standing on this Pokemon. Its state names the mon the
--- same way the other two do.
function M.zmoveActive(states, mon)
  if not mon or not states then return false end
  if states.mon == nil and states[1] ~= nil then
    for _, one in ipairs(states) do
      if M.zmoveActive(one, mon) then return true end
    end
    return false
  end
  return states.mon == mon
end

--- The Dynamax tag for this Pokemon, or nil. `states` is one Dynamax state or
--- a list of them, the same shape tagFor takes.
function M.dynamaxTagFor(states, mon)
  if not mon or not states then return nil end
  if states.mon == nil and states[1] ~= nil then
    for _, one in ipairs(states) do
      local tag = M.dynamaxTagFor(one, mon)
      if tag then return tag end
    end
    return nil
  end
  if states.mon ~= mon then return nil end
  return states.form and GIGANTAMAX_TAG or DYNAMAX_TAG
end

function M.tagFor(state, mon)
  if not mon or not state then return nil end
  if state.mon == nil and state[1] ~= nil then
    for _, one in ipairs(state) do
      local tag = M.tagFor(one, mon)
      if tag then return tag end
    end
    return nil
  end
  if state.mon ~= mon then return nil end
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

function M.draw(state, battle, FontOverride, sources)
  local mon = battle and battle.player and battle.player.mon
  local tag = M.tagFor(state, mon) or M.gimmickTagFor(sources, mon)
  if not tag or not M.visible(battle) then return end
  local wide = false
  local okWide, answer = pcall(battle.wideLayout, battle)
  if okWide then wide = answer and true or false end
  paint(SLOT.x + (wide and WIDE_DX or 0), SLOT.y, tag, FontOverride)
end

-- Whether the ENEMY's HUD block is up and its level slot is free.
--
-- Deliberately its own check rather than the player's: the engine hides that
-- block during the grow-in, the intro slide and the ball throw, and drops the
-- level entirely while a status tag is up. Reading the same fields it reads is
-- what keeps a tag from being painted over a status the engine just decided to
-- show, or onto a HUD that is not on screen.
function M.enemyVisible(battle)
  local enemy = battle and battle.enemy
  if not enemy or enemy.fainted then return false end
  if enemy.shownStatus then return false end
  if (battle.introSlide or 0) ~= 0 or battle.introBalls then return false end
  local okGrow, growing = pcall(battle.growInScale, battle, enemy)
  if okGrow and growing then return false end
  return not battle.safari and not battle.demo
end

--- Red's enemy tag. The slot does not move with the widescreen layout the way
--- the player's does: that offset shifts the PLAYER's HUD block, and the
--- enemy's stays where it is.
function M.drawEnemy(state, battle, FontOverride, sources)
  local mon = battle and battle.enemy and battle.enemy.mon
  local tag = M.tagFor(state, mon) or M.gimmickTagFor(sources, mon)
  if not tag or not M.enemyVisible(battle) then return end
  paint(ENEMY_SLOT.gen1.x, ENEMY_SLOT.gen1.y, tag, FontOverride)
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

--- Gold's enemy tag. `hudCleared("enemy")` and the enemy's own status tag are
--- the two the engine itself branches on before it prints a level there.
function M.drawGen2Enemy(state, uiBattle, FontOverride, sources)
  local engineBattle = uiBattle and uiBattle.battle
  local enemy = engineBattle and engineBattle.enemy
  local tag = M.tagFor(state, enemy) or M.gimmickTagFor(sources, enemy)
  if not tag or not uiBattle then return end
  if uiBattle.showEnemyHud == false then return end
  local okCleared, cleared = pcall(uiBattle.hudCleared, uiBattle, "enemy")
  if okCleared and cleared then return end
  local okTag, statusTag = pcall(uiBattle.statusTag, uiBattle, enemy)
  if okTag and statusTag then return end
  paint(ENEMY_SLOT.gen2.x, ENEMY_SLOT.gen2.y, tag, FontOverride)
end

function M.drawGen2(state, uiBattle, FontOverride, sources)
  local engineBattle = uiBattle and uiBattle.battle
  -- Gold's UI class carries no top-level `.player`; the engine object's own is
  -- a bare mon with no wrapper (src/battlerof.lua's own header).
  local player = engineBattle and engineBattle.player
  local tag = M.tagFor(state, player) or M.gimmickTagFor(sources, player)
  if not tag or not M.gen2Visible(uiBattle) then return end
  paint(SLOT.x, SLOT.y, tag, FontOverride)
end

-- next() first and unconditionally, the discipline every wrap in this mod
-- keeps: an empty chain costs nothing, and a populated one -- another mod's
-- overlay, or src/hpscale.lua's own -- must still run whether or not a
-- Terastallization is live right now.
function M.install(mod, state, gen2, sources)
  mod.hooks:wrap("battle.overlay", function(nextFn, battle)
    nextFn(battle)
    if gen2 then
      M.drawGen2(state, battle, nil, sources)
      M.drawGen2Enemy(state, battle, nil, sources)
    else
      M.draw(state, battle, nil, sources)
      M.drawEnemy(state, battle, nil, sources)
    end
  end)
end

return M
