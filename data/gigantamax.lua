-- species id -> the Gigantamax form that species has.
--
-- The fourth pairing table, and the flattest one.  A mega is keyed by the
-- stone that triggers it and a conditional form by the condition that does;
-- Gigantamax is keyed by nothing at all, because the trigger is the same
-- DYNAMAX cell every species shares and this table only answers "and does
-- this one have a bigger picture to show while it lasts".  A species absent
-- from here still Dynamaxes -- it just does it in its own shape.
--
-- The form id MUST be the National Dex record's KEY -- what data.pokemon[...]
-- is indexed by (e.g. CHARIZARD_GMAX) -- and never the record's `name` field
-- (e.g. "charizard-gmax").  A `name` value here compiles fine and then misses
-- silently in every lookup; tests/battle_forms_formids_test.lua is why that
-- cannot ship again.
--
-- WHAT IS LEFT OUT, and why each one is deliberate.
--
-- Corviknight has a Gigantamax record and only half the art for it: a back
-- picture and no front.  Half an entry is not art.  The rule for every table
-- in this directory is "wire it if it has art", because a form wired without
-- it falls back to the base species' picture and does so quietly -- and this
-- mod has already spent days on a transformation that was working and looked
-- exactly like one that was not.
--
-- Toxtricity and Urshifu each have TWO Gigantamax records, one per persistent
-- base form, and only the default of each pair is here.  Low Key Toxtricity
-- and Rapid Strike Urshifu are separate species records with their own keys,
-- and the form art index files every form under its BASE species' name -- so
-- their Gigantamax art sits under TOXTRICITY and URSHIFU, where a mon whose
-- species is TOXTRICITY_LOW_KEY would never look for it.  Keying those two on
-- the base species would hand half of them the wrong shape; leaving them out
-- gives them a plain Dynamax, which is right rather than merely quiet.
--
-- Every form named here has art under [BASE].forms[FORM] in the form art
-- index, front and back both, and the art suite fails if that stops being
-- true.
return {
  ALCREMIE    = "ALCREMIE_GMAX",
  APPLETUN    = "APPLETUN_GMAX",
  BLASTOISE   = "BLASTOISE_GMAX",
  BUTTERFREE  = "BUTTERFREE_GMAX",
  CENTISKORCH = "CENTISKORCH_GMAX",
  CHARIZARD   = "CHARIZARD_GMAX",
  CINDERACE   = "CINDERACE_GMAX",
  COALOSSAL   = "COALOSSAL_GMAX",
  COPPERAJAH  = "COPPERAJAH_GMAX",
  DREDNAW     = "DREDNAW_GMAX",
  DURALUDON   = "DURALUDON_GMAX",
  EEVEE       = "EEVEE_GMAX",
  FLAPPLE     = "FLAPPLE_GMAX",
  GARBODOR    = "GARBODOR_GMAX",
  GENGAR      = "GENGAR_GMAX",
  GRIMMSNARL  = "GRIMMSNARL_GMAX",
  HATTERENE   = "HATTERENE_GMAX",
  INTELEON    = "INTELEON_GMAX",
  KINGLER     = "KINGLER_GMAX",
  LAPRAS      = "LAPRAS_GMAX",
  MACHAMP     = "MACHAMP_GMAX",
  MELMETAL    = "MELMETAL_GMAX",
  MEOWTH      = "MEOWTH_GMAX",
  ORBEETLE    = "ORBEETLE_GMAX",
  PIKACHU     = "PIKACHU_GMAX",
  RILLABOOM   = "RILLABOOM_GMAX",
  SANDACONDA  = "SANDACONDA_GMAX",
  SNORLAX     = "SNORLAX_GMAX",
  TOXTRICITY  = "TOXTRICITY_AMPED_GMAX",
  URSHIFU     = "URSHIFU_SINGLE_STRIKE_GMAX",
  VENUSAUR    = "VENUSAUR_GMAX",
}
