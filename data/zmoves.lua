-- type id -> the Z-Crystal that unlocks it, the Z-Move a damaging move of that
-- type becomes while that crystal is held, and the ladder that turns the base
-- move's power into the Z-Move's.
--
-- The sixth pairing table, and the second keyed on a TYPE rather than on a
-- species.  Like data/maxmoves.lua it covers every moveset in the game with
-- eighteen rows, and unlike it, each row also names the item that turns the row
-- on: a Z-Crystal is per type, so the crystal a Pokemon carries is the whole of
-- the choice about which of its moves may become a Z-Move.
--
-- WHERE THIS DATA COMES FROM.  Section 9 of the implementation guide gives the
-- shape and one example -- Thunderbolt becoming Gigavolt Havoc "depending on
-- the relevant Z-Crystal" -- and no roster, no powers and no items, so the
-- names below are the move source's own and the numbers are not the guide's.
-- The upstream move data carries all eighteen, each split into a physical and a
-- special record; the split is dropped here because Gen 1 decides physical from
-- special by TYPE and not per move, so one record per type is what this game
-- can actually express.  It carries no power for any of them -- every one of the
-- thirty-six is null -- so the ladder is the mainline games' own, written as
-- ranges rather than as the discrete base powers they list, the same way
-- data/maxmoves.lua is.
--
-- WHAT IS LEFT OUT.  The species-specific Z-Moves -- the ones behind a crystal
-- only one Pokemon can hold.  Every one of them keys off a base move Gen 1 does
-- not have, so wiring them would mean inventing both the trigger and the
-- Pokemon it belongs to, and the crystal would be unusable in this game even
-- once bought.  Z-status moves are left out for a related reason: a status move
-- under a crystal does not become a move in the real games, it adds an effect to
-- the one already there, and there is no record shape here that says so.  A
-- status move therefore keeps itself, which is visible and honest.
--
-- A NOTE ON THE NAMES, because it is the one place this data does not fit the
-- screen.  A Gen 1 move name is twelve characters and the layouts are built for
-- it: the FIGHT menu gives a name thirteen before it reaches the box border and
-- the battle text row holds eighteen including "used " and "!".  Thirteen of
-- these eighteen names are longer than that -- NEVER-ENDING NIGHTMARE is
-- twenty-two -- so the widescreen layout truncates them with the engine's own
-- ellipsis and the classic one runs them into the border.  They are shipped as
-- the move data spells them anyway: a shortened Z-Move name would be a name this
-- project made up, which is the one thing worse than a name that does not fit.
return {
  -- Registration order, so the shelf of registered records and the shelf of
  -- crystals are both the same from one run to the next -- a keyed table
  -- reorders between runs.  It is the type chart's own order, which is also the
  -- order the crystals' bag bytes were handed out in.
  types = {
    { type = "NORMAL",   crystal = "NORMALIUM_Z",
      stem = "BREAKNECKBLITZ",       name = "BREAKNECK BLITZ" },
    { type = "FIGHTING", crystal = "FIGHTINIUM_Z",
      stem = "ALLOUTPUMMELING",      name = "ALL-OUT PUMMELING" },
    { type = "FLYING",   crystal = "FLYINIUM_Z",
      stem = "SUPERSONICSKYSTRIKE",  name = "SUPERSONIC SKYSTRIKE" },
    { type = "POISON",   crystal = "POISONIUM_Z",
      stem = "ACIDDOWNPOUR",         name = "ACID DOWNPOUR" },
    { type = "GROUND",   crystal = "GROUNDIUM_Z",
      stem = "TECTONICRAGE",         name = "TECTONIC RAGE" },
    { type = "ROCK",     crystal = "ROCKIUM_Z",
      stem = "CONTINENTALCRUSH",     name = "CONTINENTAL CRUSH" },
    { type = "BUG",      crystal = "BUGINIUM_Z",
      stem = "SAVAGESPINOUT",        name = "SAVAGE SPIN-OUT" },
    { type = "GHOST",    crystal = "GHOSTIUM_Z",
      stem = "NEVERENDINGNIGHTMARE", name = "NEVER-ENDING NIGHTMARE" },
    { type = "FIRE",     crystal = "FIRIUM_Z",
      stem = "INFERNOOVERDRIVE",     name = "INFERNO OVERDRIVE" },
    { type = "WATER",    crystal = "WATERIUM_Z",
      stem = "HYDROVORTEX",          name = "HYDRO VORTEX" },
    { type = "GRASS",    crystal = "GRASSIUM_Z",
      stem = "BLOOMDOOM",            name = "BLOOM DOOM" },
    { type = "ELECTRIC", crystal = "ELECTRIUM_Z",
      stem = "GIGAVOLTHAVOC",        name = "GIGAVOLT HAVOC" },
    -- The engine's id for the type is PSYCHIC_TYPE and its name is PSYCHIC;
    -- data/maxmoves.lua and src/tera.lua carry the same exception.
    { type = "PSYCHIC_TYPE", crystal = "PSYCHIUM_Z",
      stem = "SHATTEREDPSYCHE",      name = "SHATTERED PSYCHE" },
    { type = "ICE",      crystal = "ICIUM_Z",
      stem = "SUBZEROSLAMMER",       name = "SUBZERO SLAMMER" },
    { type = "DRAGON",   crystal = "DRAGONIUM_Z",
      stem = "DEVASTATINGDRAKE",     name = "DEVASTATING DRAKE" },
    -- The last three exist only in a game where National Dex has registered a
    -- chart carrying them.  src/zmoves.lua asks the live chart before it
    -- registers any of these, because a move naming a type the merged chart has
    -- never heard of is a load error for this mod's api level, not a quiet miss
    -- -- and their crystals are registered either way, because an item a save
    -- carries has to stay nameable whatever the chart says.
    { type = "DARK",     crystal = "DARKINIUM_Z",
      stem = "BLACKHOLEECLIPSE",     name = "BLACK HOLE ECLIPSE" },
    { type = "STEEL",    crystal = "STEELIUM_Z",
      stem = "CORKSCREWCRASH",       name = "CORKSCREW CRASH" },
    { type = "FAIRY",    crystal = "FAIRIUM_Z",
      stem = "TWINKLETACKLE",        name = "TWINKLE TACKLE" },
  },

  -- Read top to bottom; the last rung has no ceiling and takes everything above
  -- the one before it.  There is no lowered row the way data/maxmoves.lua has
  -- one for Fighting and Poison -- the mainline Z-Move ladder is the same for
  -- every type.
  ladder = {
    { upTo = 55,  power = 100 },
    { upTo = 65,  power = 120 },
    { upTo = 75,  power = 140 },
    { upTo = 85,  power = 160 },
    { upTo = 95,  power = 175 },
    { upTo = 100, power = 180 },
    { upTo = 110, power = 185 },
    { upTo = 125, power = 190 },
    { upTo = 130, power = 195 },
    { upTo = nil, power = 200 },
  },
}
