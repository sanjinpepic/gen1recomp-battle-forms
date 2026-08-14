-- Bag byte for each stone.
--
-- Gen 1 stores items as byte ids, so a record with no index cannot exist in a
-- save at all -- it will not survive a save/load and no save editor can see
-- it.  Vanilla occupies 1-97 with no gaps; 98 up is free.
--
-- These are permanent.  Changing one silently turns every stone already in a
-- player's bag into a different item, so new stones append and nothing here
-- is ever renumbered.
return {
  VENUSAURITE    = 98,
  CHARIZARDITE_X = 99,
  CHARIZARDITE_Y = 100,
  BLASTOISINITE  = 101,
  ALAKAZITE      = 102,
  GENGARITE      = 103,
}
