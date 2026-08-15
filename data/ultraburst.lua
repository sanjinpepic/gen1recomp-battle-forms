-- Species -> item -> National Dex form id, for Ultra Burst.
--
-- One entry rather than the two-key shape data/fusion.lua needs: Ultranecrozium
-- Z fits Necrozma and nothing else, in whichever of its two fused forms it
-- currently wears, so there is no second axis -- a partner species -- the
-- item's answer could differ across the way a Reshiram and a Zekrom differ
-- under the DNA Splicers.  src/ultraburst.lua checks separately, off
-- src/fusion.lua's own stamp, that the mon is fused with Solgaleo or Lunala
-- at all: a plain Necrozma holding this crystal is refused the same way a
-- Charizard holding a crystal no mega pairs it with is, by the eligibility
-- lookup below simply finding nothing.
--
-- The form id MUST be the National Dex record's KEY, never its `name` field --
-- tests/battle_forms_formids_test.lua holds this table to the same rule
-- data/megas.lua answers to.  NECROZMA_ULTRA has front AND back art under
-- NECROZMA.forms.ULTRA; tests/battle_forms_art_test.lua sweeps this table
-- under the stricter of its two rules, because Ultra Burst survives switching
-- out the way a fusion does and a form with only a front picture would be
-- invisible on the player's own side of the battle for the rest of the fight.
return {
  NECROZMA = { ULTRANECROZIUM_Z = "NECROZMA_ULTRA" },
}
