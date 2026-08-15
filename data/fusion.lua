-- base species -> item id -> PARTNER species -> National Dex form id.
--
-- One level deeper than every other pairing table here, and that level is the
-- whole mechanic.  data/megas.lua answers "this species with this item becomes
-- this form"; a fusion cannot be asked that, because Kyurem holding the DNA
-- Splicers is White Kyurem beside a Reshiram and Black Kyurem beside a Zekrom.
-- The partner is not a condition on the change, it is half of what the change
-- IS -- so it is a key in the table rather than a check somewhere else.
--
-- Necrozma is the one family whose two forms are told apart by the item as
-- well, which is why it has two item keys with one partner each: the
-- N-Solarizer only ever takes a Solgaleo and the N-Lunarizer only ever a
-- Lunala.  Kyurem and Calyrex each have one item and two partners, so when
-- both partners are in the party something has to choose between them --
-- src/fusion.lua takes the first in PARTY ORDER, which is the only ordering a
-- player can see and rearrange without a screen this mod would have to invent.
--
-- The form id MUST be the National Dex record's KEY, never its `name` field --
-- the mistake that shipped in 0.2.1 and that tests/battle_forms_formids_test.lua
-- exists to make impossible.  All six have front AND back art under
-- [BASE].forms.[SUFFIX]; tests/battle_forms_art_test.lua sweeps this table
-- under the stricter of its two rules, because a fused Pokemon carries its form
-- until the player splits it and a form with only a front picture is invisible
-- on the player's own side of the battle.
--
-- The partner species listed here are also the only species this mod will ever
-- take out of a party, which is why they are written out one by one rather than
-- derived from anything.
return {
  KYUREM = {
    DNA_SPLICERS = {
      RESHIRAM = "KYUREM_WHITE",
      ZEKROM   = "KYUREM_BLACK",
    },
  },
  NECROZMA = {
    N_SOLARIZER = { SOLGALEO = "NECROZMA_DUSK" },
    N_LUNARIZER = { LUNALA   = "NECROZMA_DAWN" },
  },
  CALYREX = {
    REINS_OF_UNITY = {
      GLASTRIER = "CALYREX_ICE",
      SPECTRIER = "CALYREX_SHADOW",
    },
  },
}
