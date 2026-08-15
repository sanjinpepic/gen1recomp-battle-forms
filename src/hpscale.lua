-- Dynamax's HP multiplier, built the one way it can be built safely.
--
-- src/dynamax.lua's own header spends a long comment on why max and current
-- HP can never be WRITTEN here: both are save data, curStats.hp is read by
-- nothing (Damage.lua and TurnOrder.lua take attack/defense/speed/special
-- off curStats and never HP), and every HP consumer in the engine reads
-- mon.hp / mon.stats.hp directly -- applyDamage (BattleState.lua:3793-3794),
-- ten hardcoded `mon.hp <= 0` faint checks, both HP bar layouts
-- (BattleState.lua:5646,5726-5729, WideBattle.lua:108-115), Status.lua's
-- residuals, MoveEffects.lua's Rest/Substitute/drain, TrainerAI.lua's
-- thresholds, Catching.lua and Experience.lua.  Stats.ensure only clamps
-- mon.hp when mon.stats is absent -- the normal battle case falls straight
-- through -- and GenSave.encodeMon writes both fields with no range check,
-- so a leaked doubled HP round-trips into a real .sav permanently.  That is
-- the whole reason this module exists: it gets the multiplier without ever
-- assigning to either field.
--
-- THE IDENTITY.  Mainline doubles max HP (H -> 2H) and current HP
-- (C -> 2C); a hit of D leaves (2C-D)/2H of the bar, which is C/H - D/2H.
-- Halving D against the UNTOUCHED H and C leaves (C-D/2)/H, which is the
-- same C/H - D/2H.  Identical survivability, identical hit count to KO, and
-- D -- a local returned by Damage.compute, not a field on anything -- is the
-- only number this ever touches.
--
-- Two seams, both already proven and already hookable, neither an HP write:
--   battle.damage   halves what Damage.compute returned before applyDamage
--                   ever reaches mon.hp (BattleState.lua:2389-2397).  This
--                   is also why Counter inherits the scaling for free:
--                   battle.lastDamage is set from this seam's result
--                   (EffectRegistry.lua:203).
--   battle.overlay  draw-only, fires after drawHUDs has already composited
--                   the real bar and the real numbers (BattleState.lua:
--                   5949-5953, WideBattle.lua:374-376) -- so it paints the
--                   doubled readout on top with zero state effect.  Only the
--                   player's own numeric HP text needs it: the bar's WIDTH
--                   is a ratio (hp/maxhp), which doubling both sides leaves
--                   unchanged, and the foe's exact HP is never shown to
--                   begin with.
--
-- The multiplier's own state is not a new record.  It is one more field on
-- src/dynamax.lua's own `state`, `state.carry`, tied to the same `state.mon`
-- identity and cleared by the same four teardown paths that already clear
-- state.mon/turns/form -- onTurnEnded, onBattlerSwitched, onFainted, and the
-- forget() pair at battle start/end.  This module never owns a mon
-- reference of its own; it only reads state.mon for identity and reads and
-- writes state.carry.
--
-- STATUS RESIDUALS ARE DELIBERATELY UNSCALED.  Poison, burn and Leech Seed
-- are computed as a fixed fraction of max HP (stats.hp/16, Status.lua:41,
-- 278) rather than a fixed amount, so their relative severity is identical
-- whether HP is doubled or damage is halved -- 1/16 of an untouched H is the
-- same fraction lost as 1/16 of a doubled 2H would be.  Leaving Status.lua
-- untouched is correct, not an omission; do not "fix" it into this module.
--
-- OHKO MOVES ARE THE ONE GAP battle.damage cannot close.  OHKO_EFFECT sets
-- 65535 directly in chooseDamage and never calls battle:computeDamage
-- (MoveEffects.lua:515-527), so no amount of halving that seam's result
-- touches it. In the mainline games an OHKO move fails outright against a
-- Dynamaxed target, so this module patches OHKO_EFFECT's own `gate` --
-- through mod.content.move_effects, the registry BattleState:effectRecord
-- reads (BattleState.lua:2352-2357) -- to fail before the base gate's
-- immunity/speed checks ever run. Super Fang is correct left alone: it
-- halves the target's CURRENT HP directly (ctx.target.mon.hp / 2,
-- MoveEffects.lua:509-513), which is already a fraction of whatever HP the
-- target has, doubled or not, so scaling it a second time would double-count.
local M = {}

-- Per-hit floor(D/2) drifts from the doubled-HP model it stands in for.
-- Two hits of 3 against a doubled 20 HP mon leave 20-3-3=14, i.e. 7 on this
-- (undoubled) scale -- but two INDEPENDENT floor(3/2) halvings only take
-- 1+1=2 off, leaving 8.  The difference is the half-point each hit drops on
-- the floor.  `state.carry` is that dropped half-point, carried forward
-- into the next hit rather than discarded, which is what makes the sum of
-- every applied halving equal floor(sum of D so far / 2) exactly -- the
-- same number the doubled model's own total would floor down to.  The test
-- suite proves this by induction, not just by example.
--
-- `mon` is the party Pokemon the incoming hit is landing on (ctx.target.mon
-- at the battle.damage seam); halving only ever applies when it is the one
-- `state.mon` names, because only the player's own side can Dynamax here
-- and there is never a second Dynamax to confuse it with.
function M.scaleDamage(state, mon, dmg)
  if not mon or state.mon ~= mon then return dmg end
  local total = dmg + (state.carry or 0)
  local applied = math.floor(total / 2)
  state.carry = total % 2
  return applied
end

-- The doubled-scale numbers the overlay paints over the real ones.  Current
-- HP is corrected for a pending carry so it always equals what the doubled
-- model itself would show -- 2*mon.hp alone overshoots by the carry, since
-- that half-point has been counted toward mon.hp's own reduction but not
-- yet subtracted off (scaleDamage's own comment works the arithmetic).
-- Both answer nil when `mon` is not the one currently Dynamaxed, which is
-- the overlay's own signal to paint nothing.
function M.displayedCurrent(state, mon)
  if not mon or state.mon ~= mon then return nil end
  return 2 * mon.hp - (state.carry or 0)
end

function M.displayedMax(state, mon)
  if not mon or state.mon ~= mon then return nil end
  return 2 * mon.stats.hp
end

-- Required at load time like src/forms.lua's Stats and src/fusion.lua's
-- Boxes/Party -- this mod already carries the engine_internals permission
-- these reach through, and a lazy pcall buys nothing here: OHKO_EFFECT's
-- own gate is read once, at require time, as the thing this module's patch
-- wraps rather than replaces.
local MoveEffects = require("src.battle.MoveEffects")
local RomText = require("src.core.RomText")

local baseOhkoGate = MoveEffects.full.OHKO_EFFECT.gate

-- OHKO_EFFECT's own gate (immune types, a faster target) is untouched --
-- this only adds a third reason to fail, and it is checked FIRST: the real
-- games refuse an OHKO outright against a Dynamaxed target regardless of
-- type or speed, so a Dynamaxed target never even reaches the other two
-- checks. "_ButItFailedText" rather than a bespoke line because Gen 1 has
-- no ROM text of its own for "no effect against a Dynamaxed target" and
-- reusing the label the speed-gate failure already prints is exactly what
-- OHKO_EFFECT's own gate does for its own two reasons.
function M.ohkoGate(state, ctx)
  local target = ctx and ctx.target and ctx.target.mon
  if target and state.mon == target then
    return false, RomText(ctx.battle.data, "_ButItFailedText", "But, it failed!")
  end
  return baseOhkoGate(ctx)
end

local Font = require("src.render.Font")

-- Pixel slots the vanilla numeric HP readout already reserves for the
-- player's own "%3d/%3d" text -- BattleState.lua:5726 (classic, (88,80))
-- and WideBattle.lua:113-115 (wide, x + tw*8 - 64 with x=184 tw=15 -> 240,
-- y+24 with y=56 -> 80).  64px wide because that is what the WIDE layout's
-- own `- 64` already reserves from the panel's right edge (184 + 15*8 = 304,
-- the surface's own width) -- reused here rather than re-derived so the
-- clear rectangle can never undershoot the real text it is painting over.
local SLOT_W, SLOT_H = 64, 8
local CLASSIC_SLOT = { x = 88, y = 80 }
local WIDE_SLOT = { x = 240, y = 80 }

-- The same visibility rule both draw paths already apply to the player's
-- HUD block before printing that text (BattleState.lua:5714-5715,
-- WideBattle.lua:92-93 via drawHUDs' own guard) -- reproduced rather than
-- read off a shared flag because battle.overlay fires after both draw
-- functions have already returned, with none of their locals left to ask.
local function playerHudVisible(battle)
  return battle ~= nil and battle.player ~= nil and battle:statusHUDVisible()
    and not battle.safari and not battle.demo and not battle.showPlayerBack
    and (battle.introSlide or 0) == 0
end

-- Blanks the vanilla text back to box white, then draws the doubled reading
-- over it -- the same two-step drawTextArea's own MoveSelectionMenu cell
-- wipe uses (BattleState.lua "Wipe each cell back to box white first, the
-- way a tilemap write does"), because Font.draw is a transparent blit and
-- never clears what it did not overwrite.
local function paint(x, y, text)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", x, y, SLOT_W, SLOT_H)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(text, x, y)
end

-- battle.overlay's own draw.  Nothing here ever runs for the enemy: only
-- the player's side can reach the Dynamax cell (src/dynamax.lua's own
-- header), and the enemy's HP bar never prints a number to begin with.
function M.draw(state, battle)
  local mon = battle and battle.player and battle.player.mon
  local cur = M.displayedCurrent(state, mon)
  if not cur or not playerHudVisible(battle) then return end
  local text = ("%3d/%3d"):format(cur, M.displayedMax(state, mon))
  local slot = battle:wideLayout() and WIDE_SLOT or CLASSIC_SLOT
  paint(slot.x, slot.y, text)
end

-- Wires the two hooks and the one content patch into a live mod.  Bound to
-- src/dynamax.lua's own `state` rather than a record of this module's own,
-- for the reason the header gives: there is only ever one Dynamax to track,
-- and it is already tracked.
function M.install(mod, state)
  mod.hooks:wrap("battle.damage", function(nextFn, ctx)
    local dmg, info = nextFn(ctx)
    local target = ctx and ctx.target and ctx.target.mon
    return M.scaleDamage(state, target, dmg), info
  end)

  mod.hooks:wrap("battle.overlay", function(nextFn, battle)
    -- next() first and unconditionally: an empty chain costs nothing, but a
    -- populated one (another mod's own sparkle, or a future overlay of this
    -- one's) must still run whether or not a Dynamax is live right now.
    nextFn(battle)
    M.draw(state, battle)
  end)

  mod.content.move_effects:patch("OHKO_EFFECT", {
    gate = function(ctx) return M.ohkoGate(state, ctx) end,
  })
end

return M
