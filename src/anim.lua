-- The form-change animation.
--
-- Screen effects only, deliberately: an effect row needs no tilesheet and no
-- subanimation, so this ships without art and cannot become a vector for
-- anyone else's.  Custom sprite work would mean registering subanim: and
-- tilesheet: records, which is a licensing decision before it is a technical
-- one.
--
-- animNext takes this id the same way it takes POOF_ANIM on send-out: the id
-- is only a lookup key and nothing checks it against a move, which is what
-- makes a non-move animation possible at all.
local M = {}

M.ID = "BATTLE_FORMS_CHANGE"

function M.install(mod)
  mod.content.battle_anims:register(M.ID, {
    seq = {
      { effect = "SE_LIGHT_SCREEN_PALETTE" },
      -- Flashing the mon's own pic rather than only the screen: the thing
      -- that changed is the Pokemon, so that is what should be lit.
      { effect = "SE_FLASH_MON_PIC" },
      { effect = "SE_FLASH_SCREEN_LONG" },
      { effect = "SE_RESET_SCREEN_PALETTE" },
    },
  })
end

-- The Max Move animations, built here rather than in src/maxmoves.lua so that
-- every animation this mod ships stays in the file that decided none of them
-- may need art.  A move with no battle_anims record of its own is not an error
-- -- AnimPlayer warns once and plays nothing -- but it is also SILENT, because
-- the animation rows are what carry a move's sound (BattleState.lua:1275-1285
-- takes the row sounds and skips the single-sound fallback whenever the player
-- started), so a Max Move without one of these would land with no picture and
-- no noise at all.
--
-- A fresh table per call: a registry keeps what it is handed, and one sequence
-- shared by twenty ids is one table twenty records could be mutated through.
--
-- `sound` names a MOVE whose sound to borrow, which is the row format the
-- engine's own animations use (AnimPlayer.lua:459-463, BattleState.lua:2783).
-- Borrowing the cart's own sound table costs nothing and ships nothing;
-- inventing a sound would mean shipping audio.
function M.maxMoveSeq()
  return {
    { effect = "SE_DARK_SCREEN_PALETTE" },
    { effect = "SE_DARK_SCREEN_FLASH", sound = "EXPLOSION" },
    { effect = "SE_SHAKE_SCREEN" },
    { effect = "SE_RESET_SCREEN_PALETTE" },
  }
end

-- Max Guard is a status move and reads as one: the screen lights rather than
-- darkens, the Pokemon itself flashes, and nothing shakes.
function M.maxGuardSeq()
  return {
    { effect = "SE_LIGHT_SCREEN_PALETTE" },
    { effect = "SE_FLASH_MON_PIC", sound = "HARDEN" },
    { effect = "SE_RESET_SCREEN_PALETTE" },
  }
end

return M
