-- species id -> stone item id -> National Dex form id.
--
-- Keyed on the PAIR rather than the species: Charizard has two megas and the
-- stone is what tells them apart, so a species-keyed table could not express
-- the case that motivated this design.
--
-- The form id MUST be the National Dex record's KEY -- what data.pokemon[...]
-- is indexed by (e.g. CHARIZARD_MEGA_X) -- and never the record's `name`
-- field (e.g. "charizard-mega-x").  Those look interchangeable and are not:
-- a `name` value here compiles fine and passes review, and then every lookup
-- in Forms.becomeForm misses silently.  That exact mistake shipped in 0.2.1.
--
-- This table belongs in national_dex and moves there once the primitive is
-- proven.  It lives here for the trial so that an experimental battle mod
-- cannot force a release of a stable one.
return {
  VENUSAUR  = { VENUSAURITE   = "VENUSAUR_MEGA" },
  CHARIZARD = { CHARIZARDITE_X = "CHARIZARD_MEGA_X",
                CHARIZARDITE_Y = "CHARIZARD_MEGA_Y" },
  BLASTOISE = { BLASTOISINITE = "BLASTOISE_MEGA" },
  ALAKAZAM  = { ALAKAZITE     = "ALAKAZAM_MEGA" },
  GENGAR    = { GENGARITE     = "GENGAR_MEGA" },
}
