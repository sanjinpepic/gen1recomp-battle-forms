-- species id -> stone item id -> National Dex form id.
--
-- Keyed on the PAIR rather than the species: Charizard has two megas and the
-- stone is what tells them apart, so a species-keyed table could not express
-- the case that motivated this design.
--
-- This table belongs in national_dex and moves there once the primitive is
-- proven.  It lives here for the trial so that an experimental battle mod
-- cannot force a release of a stable one.
return {
  VENUSAUR  = { VENUSAURITE   = "venusaur-mega" },
  CHARIZARD = { CHARIZARDITE_X = "charizard-mega-x",
                CHARIZARDITE_Y = "charizard-mega-y" },
  BLASTOISE = { BLASTOISINITE = "blastoise-mega" },
  ALAKAZAM  = { ALAKAZITE     = "alakazam-mega" },
  GENGAR    = { GENGARITE     = "gengar-mega" },
}
