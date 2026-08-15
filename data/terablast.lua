-- The eighteen types a Terastallization may turn TERA BLAST into, in the
-- same order and under the same engine ids TERA_CHOICES (main.lua) and
-- data/zmoves.lua's `types` list already use.  Not a copy of either: this
-- file names nothing but the type, because TERA BLAST never changes name or
-- power -- see src/tera.lua's header for why a type is the whole of it.
--
-- WHERE THE BASE MOVE COMES FROM.  National Dex registers TERABLAST itself
-- (Normal, 80 power, special, 100 accuracy, 10 PP) as part of its 833-move
-- catalog -- this file does not invent it and does not duplicate its stats.
-- Every row below only says which type variant to build; the registered
-- variants carry the record PP src/zmoves.lua's and src/maxmoves.lua's own
-- do (5, for the same reason: the FIGHT menu draws its PP maximum off the
-- record, and src/substitute.lua's menuPPUps corrects that maximum against
-- TERABLAST's own PP read live from `data.moves` at substitution time, so a
-- change to it upstream is followed rather than copied out of step.
--
-- Red's fifteen come first and DARK, STEEL and FAIRY last, matching
-- TERA_CHOICES: those three exist only once National Dex has registered a
-- chart over the cart's own, and src/tera.lua already refuses a Tera type the
-- running game's chart cannot resolve before any of this is reached.
return {
  "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST",
  "FIRE", "WATER", "GRASS", "ELECTRIC",
  -- The engine's id for Psychic is PSYCHIC_TYPE; src/tera.lua, data/zmoves.lua
  -- and data/maxmoves.lua all carry the same exception.
  "PSYCHIC_TYPE",
  "ICE", "DRAGON",
  "DARK", "STEEL", "FAIRY",
}
