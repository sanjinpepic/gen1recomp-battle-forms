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

return M
