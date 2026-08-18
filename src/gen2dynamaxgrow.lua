-- Gold's "grow instead": a Dynamaxed Pokemon with no Gigantamax picture
-- gets a bigger one rather than standing there looking untouched.
--
-- Gen 2 only, by construction rather than by a `gen2` flag this file reads:
-- it patches `src.ui.gen2.BattleState`, a class Red never draws through, so
-- main.lua's own `if gen2 then` gate is what keeps this off a Gen 1 boot --
-- the identical discipline src/gen2menu.lua, src/gen2movemenu.lua and
-- src/gen2forms.lua already hold for the same reason. Red has no draw-time
-- scaling seam at all (`frontSize` is read only at ROM-import time and
-- never reaches the draw, and `battle.overlay` fires after the engine has
-- already drawn the battler), so growing a Gen 1 Dynamax needs an engine
-- hook this mod does not have and is out of scope here.
--
-- WHERE THE GROWTH ACTUALLY LIVES, and why not `BgEffects.picSize`.  That
-- field is the real engine's own grow/shrink facility
-- (`BATTLE_BG_EFFECT_SHOW_MON`/`ENTER_MON`/`RETURN_MON`,
-- game/src/battle/gen2/BgEffects.lua:503-520) and `runPicResize`
-- (:473-501) writes it from `PIC_RESIZE` (:460-471), whose every entry is a
-- box-SIZE INDEX, not a magnification: `PIC_RESIZE_TILES`
-- (game/src/ui/gen2/BattleState.lua:580) maps 0/1/2 to the player's own
-- 6x6/4x4/2x2 BG squares and 3/4/5 to the enemy's 7x7/5x5/3x3, and no
-- script ever writes an index past "the mon's own box, at 1x" -- every one
-- of them is a SHRINK (returning to the ball) or its reverse (entering the
-- field), never a size larger than normal. It is also only ever read while
-- `self.anim` is a live AnimRunner: `BattleState:animPicState` answers nil
-- the instant that runner clears (BattleState.lua:1181-1192), which is most
-- of a battle -- true for the handful of frames a send-out or return script
-- plays, false for the three whole turns a Dynamax needs to stay big
-- through. So holding a battler enlarged cannot live in `picSize` at all:
-- there is no larger-than-normal index to write, and even a same-sized one
-- would vanish within a few frames of whatever resize script set it ending.
--
-- `BattleState:picScale` (BattleState.lua:551-557) is the seam actually
-- read on every draw, animation running or not, and the class's own
-- comment already describes it composing with a live resize script rather
-- than competing with one: "the pic's own scale ... composed with whatever
-- square BattleBGEffect_RunPicResizeScript has the mon drawn at this
-- frame" (BattleState.lua:659-661), the multiplication actually performed
-- at :665-666 (`scale = scale * (resized / boxTiles)`). Wrapping picScale
-- rather than writing picSize is therefore not a workaround, it is being
-- one more source into a multiplier the engine already composes multiple
-- sources into -- `battle_sprite_scales` first, then a species'
-- `battleScaleFront`/`battleScaleBack`, now this. THE PRECEDENCE against a
-- real battle animation: the resize script always gets the last word,
-- because it multiplies AFTER picScale returns and this module never
-- touches `picSize` at all -- a Dynamaxed mon returning to its ball still
-- shrinks through the identical 6x6/4x4/2x2 steps, just shrinking away from
-- a bigger starting size, and the two mechanisms can never corrupt each
-- other because neither ever writes the field the other reads.
--
-- THE SCALE ITSELF, derived from the box/HUD geometry
-- (BattleState.lua:568-580) rather than guessed. Boxes: player 6x6 tiles at
-- (16,48) -> 48x48px; enemy 7x7 at (96,0) -> 56x56px, front pics padded
-- bottom-first and pinned to the box's own corner once they exceed it
-- (BattleState.lua:646-654). Neighbouring HUD text: the enemy block clears
-- (1,0) 4 rows x 11 cols -> x 8-96, y 0-32 (BattleState.lua:3218-3225),
-- sitting flush against the enemy pic box's own left edge with NO gap; the
-- player block clears (9,7) 5 rows x 11 cols -> x 72-160, y 56-96
-- (:3255-3265). `drawPic`'s own growth math centres horizontally and grows
-- upward from the ground line (:668-674: `px += floor(w*(1-scale)/2)`,
-- `py += floor(h*(1-scale))`), so the two things that can go wrong at a
-- large enough scale are the enemy pic sliding left into its own HUD block
-- and either side's pic sliding above the top of the screen (y < 0, which
-- LOVE simply does not draw rather than distorting anything).
--
-- At SCALE = 1.15: a TYPICAL pic (48x48, the player's back-pic size and a
-- common front-pic one) grows with zero encroachment either way -- the
-- enemy case lands its left edge exactly on x=96, its own HUD block's
-- right edge, and its top edge exactly on y=0, the screen's own top; the
-- player case leaves roughly 5px of clearance on both the HUD side and the
-- top of the screen, since nothing else is drawn in the sky above its box.
-- Only the single largest vanilla front pic, Onix (56x56, filling its 7x7
-- box exactly with no padding), gives up a few pixels either way: about 5px
-- into the enemy HUD block and about 9px cropped off the top of the
-- screen -- an edge case for the one species that already draws oddly at
-- 1x, not the common case, and cropping (LOVE drawing nothing past y=0)
-- rather than corruption. A rounder number like 1.2 or 1.25 was tried
-- against the same arithmetic and pushed the TYPICAL case into the same
-- few-pixel overlap Onix alone pays at 1.15, which is what settled it.
local M = {}

M.SCALE = 1.15

-- `states` is a list of src/dynamax.lua-shaped records (`.mon`, `.form`),
-- read live and owned by nobody here -- the identical read-only
-- relationship src/hpscale.lua already keeps with this same table. That is
-- also why teardown needs nothing of its own: the four paths that already
-- clear `state.mon` (onTurnEnded, onBattlerSwitched, onFainted, and
-- forget() at battle start/end) end the growth in the same instant they
-- end everything else src/dynamax.lua was holding, with no fifth path to
-- remember.
--
-- A list rather than a single record so a future second state -- an enemy
-- Dynamax, whenever one exists -- is one more entry in main.lua's own
-- array and nothing here would need to change: this function never reads
-- `battle.player`, only whether `mon` equals SOME tracked state's own
-- `.mon`, so it already treats both sides identically. Today there is
-- exactly one state in that array, matching src/dynamax.lua's own header
-- ("only the player's own side can Dynamax here").
--
-- The gate is `mon.form`, not `state.form`. src/dynamax.lua's own
-- `activate` sets state.form only when it WINS the Gigantamax slot (`ok`
-- true from becomeForm); a species with no Gigantamax record, one whose
-- record is missing or misnamed (refused, `deps.log:warn`'d, and the
-- Dynamax still applies plainly), and a mon that Dynamaxed while ALREADY
-- wearing another mechanic's form (that block is skipped outright once
-- `mon.form` is non-nil) all leave state.form nil -- but only the first two
-- are "nothing better to show"; the third is standing there in its mega
-- picture, which very much is one, and must not also grow. `mon.form`
-- tells the three apart where `state.form` cannot, because it is nil in
-- exactly the first two.
function M.scaleFor(states, mon)
  if not (states and mon) then return nil end
  for _, state in ipairs(states) do
    if state and state.mon == mon then
      if mon.form then return nil end
      return M.SCALE
    end
  end
  return nil
end

-- Wraps the real `src.ui.gen2.BattleState.picScale`, the same
-- monkey-patch-with-idempotency-flag shape src/gen2menu.lua and
-- src/gen2movemenu.lua already use on this identical class -- guarded by
-- its own flag (`_battleFormsDynamaxGrowPatched`) rather than either of
-- theirs, so all three wraps stack instead of colliding. A missing or
-- reshaped class refuses outright and logs through mod.log, the CLAUDE.md
-- rule every other engine_internals patch in this mod already follows: a
-- guard that refuses must say so out loud rather than silently drawing
-- every Dynamax at its ordinary size.
function M.install(mod, states)
  local okState, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not okState or type(BattleState) ~= "table" then
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BattleState is unavailable -- "
        .. "a Dynamax with no Gigantamax picture will not grow on Gold")
    end
    return false
  end
  if BattleState._battleFormsDynamaxGrowPatched then
    return true
  end
  if type(BattleState.picScale) ~= "function" then
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.BattleState.picScale has "
        .. "changed shape -- a Dynamax with no Gigantamax picture will not "
        .. "grow on Gold")
    end
    return false
  end

  local vanilla = BattleState.picScale
  BattleState._battleFormsDynamaxGrowPatched = true
  BattleState.picScale = function(self, path, mon, back)
    local base = vanilla(self, path, mon, back)
    local scale = M.scaleFor(states, mon)
    if scale then return base * scale end
    return base
  end
  return true
end

return M
