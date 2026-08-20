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

-- Per-hit floor(D/m) drifts from the scaled-HP model it stands in for.
-- Two hits of 3 against a doubled 20 HP mon leave 20-3-3=14, i.e. 7 on this
-- (unscaled) scale -- but two INDEPENDENT floor(3/2) halvings only take
-- 1+1=2 off, leaving 8.  The difference is the fraction of a point each hit
-- drops on the floor.  `state.carry` is that dropped fraction, carried
-- forward into the next hit rather than discarded, which is what makes the
-- sum of every applied scaling equal floor(sum of D so far / m) exactly --
-- the same number the scaled model's own total would floor down to.  The
-- test suite proves this by induction, not just by example.
--
-- THE MULTIPLIER IS NOW A POKEMON'S OWN, not a constant 2.  A Dynamax Level
-- of L gives (30 + L)/20 (src/dynamaxlevel.lua): level 0 is 30/20 = x1.5 and
-- level 10 is 40/20 = x2, which is exactly what this file did before levels
-- existed.  Kept as two integers rather than one float on purpose -- the
-- carry above is an exact-arithmetic argument, and a float multiplier would
-- let it drift by a point over a long battle in a way nobody could
-- reproduce.
--
-- `carry` is therefore in units of 1/DENOMINATOR of a hit point rather than
-- of a half.  Nothing outside this file reads it, and everything inside it
-- goes through M.numerator, so the change of unit is contained -- but it is
-- why displayedCurrent divides by the denominator where it used to subtract
-- the carry directly.
-- src/dynamaxlevel.lua, handed in by M.install.  Absent it, the answer is the
-- flat x2 this file gave before levels existed -- which is also level 10, so
-- an unbound build is weaker than it looks only in that every Pokemon is at
-- the ceiling rather than at its own level.
local dynamaxlevel = nil

local function numeratorFor(mon)
  if not dynamaxlevel then return 2, 1 end
  return dynamaxlevel.numerator(dynamaxlevel.of(mon)), dynamaxlevel.DENOMINATOR
end

-- `mon` is the party Pokemon the incoming hit is landing on (ctx.target.mon
-- at the battle.damage seam); scaling only ever applies when it is the one
-- `state.mon` names, because only the player's own side can Dynamax here
-- and there is never a second Dynamax to confuse it with.
function M.scaleDamage(state, mon, dmg)
  if not mon or state.mon ~= mon then return dmg end
  local num, den = numeratorFor(mon)
  local total = dmg * den + (state.carry or 0)
  local applied = math.floor(total / num)
  state.carry = total % num
  return applied
end

-- The scaled numbers the overlay paints over the real ones.  Current HP is
-- corrected for a pending carry so it always equals what the scaled model
-- itself would show -- num/den * mon.hp alone overshoots by the carry, since
-- that fraction has been counted toward mon.hp's own reduction but not yet
-- subtracted off (scaleDamage's own comment works the arithmetic).
-- Both answer nil when `mon` is not the one currently Dynamaxed, which is
-- the overlay's own signal to paint nothing.
function M.displayedCurrent(state, mon)
  if not mon or state.mon ~= mon then return nil end
  local num, den = numeratorFor(mon)
  return math.floor((mon.hp * num - (state.carry or 0)) / den)
end

function M.displayedMax(state, mon)
  if not mon or state.mon ~= mon then return nil end
  local num, den = numeratorFor(mon)
  return math.floor(mon.stats.hp * num / den)
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

-- ---- Gen 2 -------------------------------------------------------------
--
-- Gold has no widescreen battle path at all, so there is one slot rather
-- than a classic/wide pair. Its own numeric HP text ends at pixel 144
-- (Chrome.printRight's own tile 18, game/src/ui/gen2/BattleState.lua:3279)
-- on the SAME row Gen 1's own CLASSIC_SLOT prints (y = 80, tile row 10) --
-- not a coincidence, both trace to the identical GB HUD layout.  64px wide
-- for the same reason src/hpscale.lua's own SLOT_W is: the worst realistic
-- case is a two-digit current and a two-digit maximum ("40/40", 5 monospace
-- characters, 40px), comfortably inside a slot this size with room to
-- spare, and Gold's own PP-Up-free model (game/src/battle/gen2/Mon.lua
-- carries no ppUps field at all) never pushes a Max Move's substituted
-- `maxPp` past the base move's own real maximum, which tops out at 40 on
-- any move this game's own data carries.
local GEN2_SLOT = { x = 144 - SLOT_W, y = 80 }

-- The visibility rule BattleState:drawHud already applies to the player's
-- own HUD block before it prints anything there
-- (game/src/ui/gen2/BattleState.lua:3265-3269) -- reproduced rather than
-- read off a shared flag for the identical reason Gen 1's own
-- playerHudVisible is: battle.overlay fires after drawHud has already
-- returned, with none of its locals left to ask.  `uiBattle` is the UI
-- screen (src/gen2menu.lua's own `self`), not the engine battle --
-- `statusHUDVisible`/`showPlayerHud`/`hudCleared` are methods and fields on
-- that class, never on game/src/battle/gen2/Battle.lua.  Wrapped in pcall:
-- a stubbed or reshaped screen missing one of these must degrade the
-- overlay to "paint nothing" rather than take a draw frame down.
function M.gen2PlayerVisible(uiBattle)
  if not uiBattle then return false end
  local okVisible, visible = pcall(uiBattle.statusHUDVisible, uiBattle)
  if not (okVisible and visible) then return false end
  if not uiBattle.showPlayerHud then return false end
  local okCleared, cleared = pcall(uiBattle.hudCleared, uiBattle, "player")
  if okCleared and cleared then return false end
  return true
end

-- battle.overlay's own draw, Gold-shaped.  `uiBattle.battle.player` rather
-- than `uiBattle.player` -- Gold's UI class carries no top-level `.player`
-- field at all, only `.battle.player` (the engine object's own, a bare mon
-- with no wrapper -- src/battlerof.lua's own header). `FontOverride` exists
-- so a test can drive this without swapping package.loaded; production
-- calls it with none and gets the module's own real Font.
function M.drawGen2(state, uiBattle, FontOverride)
  local F = FontOverride or Font
  local engineBattle = uiBattle and uiBattle.battle
  local mon = engineBattle and engineBattle.player
  local cur = M.displayedCurrent(state, mon)
  if not cur or not M.gen2PlayerVisible(uiBattle) then return end
  local text = ("%d/%d"):format(cur, M.displayedMax(state, mon))
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", GEN2_SLOT.x, GEN2_SLOT.y, SLOT_W, SLOT_H)
  love.graphics.setColor(0, 0, 0, 1)
  F.draw(text, GEN2_SLOT.x, GEN2_SLOT.y)
end

-- Gold's own OHKO gate.  Battle.MOVE_EFFECTS.EFFECT_OHKO
-- (game/src/battle/gen2/Battle.lua:2250-2277) is a full `run` handler, not a
-- separate `gate` field the way Gen 1's OHKO_EFFECT carries one -- Fissure
-- and Horn Drill's own level/speed checks and their own miss text live
-- INSIDE that one function, so there is nothing to compose AHEAD of the
-- way M.ohkoGate composes ahead of Gen 1's base gate. This wraps the whole
-- `run` instead: refuses outright and says so when the target is the
-- Dynamaxed mon (the real games refuse an OHKO against a Dynamaxed target
-- regardless of type, level or speed), and delegates to `baseRun` --
-- captured from the real class BEFORE this module's own patch reaches the
-- registry, exactly the way M.ohkoGate's own `baseOhkoGate` is captured --
-- for every other case.
function M.ohkoRunGen2(state, baseRun)
  return function(battleSelf, attacker, defender, def, moveId, locked)
    if defender and state.mon == defender then
      if battleSelf and battleSelf.markMissed then
        pcall(battleSelf.markMissed, battleSelf)
      end
      if battleSelf and battleSelf.emit then
        pcall(battleSelf.emit, battleSelf,
          { kind = "message", text = "But, it failed!" })
      end
      return
    end
    return baseRun(battleSelf, attacker, defender, def, moveId, locked)
  end
end

-- Wires the two hooks and the content patch(es) into a live mod. Bound to
-- src/dynamax.lua's own `state` rather than a record of this module's own,
-- for the reason the header gives: there is only ever one Dynamax to track,
-- and it is already tracked.
--
-- `battlerof` reads ctx.target on EITHER shape with no `gen2` branch needed
-- at this one hook -- battle.damage's payload IS the discriminator
-- (src/battlerof.lua's own header), so the single wrap below already covers
-- both games.  `gen2` decides only which DRAW path and which OHKO patch to
-- install, because those two genuinely differ: Gold's UI class shape for
-- the draw, and Gold's own EFFECT_OHKO id and `run`-only shape for the
-- gate. Gen 1's own OHKO_EFFECT patch still installs unconditionally --
-- that id is simply never dispatched on a Gen 2 boot, the identical
-- harmless-elsewhere shape every other Gen-1-only registration in this mod
-- already has.
function M.install(mod, state, battlerof, gen2, levelModule)
  dynamaxlevel = levelModule
  mod.hooks:wrap("battle.damage", function(nextFn, ctx)
    local dmg, info = nextFn(ctx)
    local target = ctx and ctx.target
    local mon = battlerof and battlerof.mon(target)
      or (target and target.mon)
    return M.scaleDamage(state, mon, dmg), info
  end)

  mod.hooks:wrap("battle.overlay", function(nextFn, battle)
    -- next() first and unconditionally: an empty chain costs nothing, but a
    -- populated one (another mod's own sparkle, or a future overlay of this
    -- one's) must still run whether or not a Dynamax is live right now.
    nextFn(battle)
    if gen2 then
      M.drawGen2(state, battle)
    else
      M.draw(state, battle)
    end
  end)

  mod.content.move_effects:patch("OHKO_EFFECT", {
    gate = function(ctx) return M.ohkoGate(state, ctx) end,
  })

  if gen2 then
    local okBattle, GenBattle = pcall(require, "src.battle.gen2.Battle")
    local baseRun = okBattle and type(GenBattle) == "table"
      and type(GenBattle.MOVE_EFFECTS) == "table"
      and GenBattle.MOVE_EFFECTS.EFFECT_OHKO
    if type(baseRun) == "function" then
      mod.content.move_effects:patch("EFFECT_OHKO", {
        run = M.ohkoRunGen2(state, baseRun),
      })
    elseif mod.log then
      mod.log:error(
        "battle_forms: src.battle.gen2.Battle.MOVE_EFFECTS.EFFECT_OHKO is "
          .. "unavailable -- an OHKO move will not fail against a "
          .. "Dynamaxed target on Gold")
    end
  end
end

return M
