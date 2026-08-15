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
-- WHAT USED TO BE LEFT OUT, and no longer is.  This file once refused the
-- species-specific Z-Moves outright on the grounds that every one of them
-- keyed off a base move Gen 1 did not have.  That premise stopped being true
-- once National Dex 0.15.0 registered all 833 modern moves -- fourteen of
-- them are now built in data/speciesz.lua and src/speciesz.lua, sharing this
-- same Z-MOVE cell as a second catalog.  A status move under a crystal also
-- used to keep itself and nothing more; it still keeps itself -- the field
-- below still refuses to substitute one, on purpose -- but src/zmoves.lua now
-- adds the one bonus this engine can build without inventing a ruling: a
-- status move that already raises the user's own stat raises every other
-- stat by one stage as well.  See src/zmoves.lua's own Z-STATUS section for
-- why only that shape and not the real games' full bonus table.
--
-- A NOTE ON THE NAMES, because it is the one place this data does not fit the
-- screen.  A Gen 1 move name is twelve characters and the layouts are built for
-- it: the classic FIGHT menu gives a name thirteen columns before it reaches
-- the move box's own border (BattleState.lua's moveSelect draw: names at
-- x=48, the box border at x=152) and the widescreen grid gives twelve before
-- WideBattle.lua's fitName starts truncating it with an ellipsis (drawMoveGrid's
-- own budget: 96px at the font's flat 8px advance).  Thirteen of these
-- eighteen names are longer than that -- NEVER-ENDING NIGHTMARE is
-- twenty-two -- so the classic layout ran them into the border and the wide
-- one truncated them past recognition.
--
-- `menu` is the fix, and it is DISPLAY ONLY: src/zmoves.lua never registers
-- it as anything, `name` above is still what src/zmoves.lua's M.install
-- hands the engine and what a save, the battle text row and Mimic all still
-- see.  Only src/zmovemenu.lua reads `menu`, and only to redraw the FIGHT
-- menu's own two name cells over top of whatever `name` just drew there --
-- the same display-time-not-data split National Dex keeps between a
-- registered name and how a dex page casts it.  Every row carries one, even
-- the two whose own `name` already fit, so the invariant every row's `menu`
-- is checked against is one invariant rather than a rule with exceptions.
return {
  -- Registration order, so the shelf of registered records and the shelf of
  -- crystals are both the same from one run to the next -- a keyed table
  -- reorders between runs.  It is the type chart's own order, which is also the
  -- order the crystals' bag bytes were handed out in.
  types = {
    { type = "NORMAL",   crystal = "NORMALIUM_Z",
      stem = "BREAKNECKBLITZ",       name = "BREAKNECK BLITZ",
      menu = "SWIFT BLITZ" },
    { type = "FIGHTING", crystal = "FIGHTINIUM_Z",
      stem = "ALLOUTPUMMELING",      name = "ALL-OUT PUMMELING",
      menu = "TOTAL PUMMEL" },
    { type = "FLYING",   crystal = "FLYINIUM_Z",
      stem = "SUPERSONICSKYSTRIKE",  name = "SUPERSONIC SKYSTRIKE",
      menu = "SKYSTRIKE" },
    { type = "POISON",   crystal = "POISONIUM_Z",
      stem = "ACIDDOWNPOUR",         name = "ACID DOWNPOUR",
      menu = "ACID SHOWER" },
    { type = "GROUND",   crystal = "GROUNDIUM_Z",
      stem = "TECTONICRAGE",         name = "TECTONIC RAGE",
      menu = "EARTH RAGE" },
    { type = "ROCK",     crystal = "ROCKIUM_Z",
      stem = "CONTINENTALCRUSH",     name = "CONTINENTAL CRUSH",
      menu = "STONE CRUSH" },
    { type = "BUG",      crystal = "BUGINIUM_Z",
      stem = "SAVAGESPINOUT",        name = "SAVAGE SPIN-OUT",
      menu = "SPIN-OUT" },
    { type = "GHOST",    crystal = "GHOSTIUM_Z",
      stem = "NEVERENDINGNIGHTMARE", name = "NEVER-ENDING NIGHTMARE",
      menu = "NIGHTMARE" },
    { type = "FIRE",     crystal = "FIRIUM_Z",
      stem = "INFERNOOVERDRIVE",     name = "INFERNO OVERDRIVE",
      menu = "OVERDRIVE" },
    { type = "WATER",    crystal = "WATERIUM_Z",
      stem = "HYDROVORTEX",          name = "HYDRO VORTEX",
      menu = "HYDRO VORTEX" },
    { type = "GRASS",    crystal = "GRASSIUM_Z",
      stem = "BLOOMDOOM",            name = "BLOOM DOOM",
      menu = "BLOOM DOOM" },
    { type = "ELECTRIC", crystal = "ELECTRIUM_Z",
      stem = "GIGAVOLTHAVOC",        name = "GIGAVOLT HAVOC",
      menu = "VOLT HAVOC" },
    -- The engine's id for the type is PSYCHIC_TYPE and its name is PSYCHIC;
    -- data/maxmoves.lua and src/tera.lua carry the same exception.
    { type = "PSYCHIC_TYPE", crystal = "PSYCHIUM_Z",
      stem = "SHATTEREDPSYCHE",      name = "SHATTERED PSYCHE",
      menu = "PSYCHE BREAK" },
    { type = "ICE",      crystal = "ICIUM_Z",
      stem = "SUBZEROSLAMMER",       name = "SUBZERO SLAMMER",
      menu = "ICE SLAMMER" },
    { type = "DRAGON",   crystal = "DRAGONIUM_Z",
      stem = "DEVASTATINGDRAKE",     name = "DEVASTATING DRAKE",
      menu = "GRAND DRAKE" },
    -- The last three exist only in a game where National Dex has registered a
    -- chart carrying them.  src/zmoves.lua asks the live chart before it
    -- registers any of these, because a move naming a type the merged chart has
    -- never heard of is a load error for this mod's api level, not a quiet miss
    -- -- and their crystals are registered either way, because an item a save
    -- carries has to stay nameable whatever the chart says.
    { type = "DARK",     crystal = "DARKINIUM_Z",
      stem = "BLACKHOLEECLIPSE",     name = "BLACK HOLE ECLIPSE",
      menu = "DARK ECLIPSE" },
    { type = "STEEL",    crystal = "STEELIUM_Z",
      stem = "CORKSCREWCRASH",       name = "CORKSCREW CRASH",
      menu = "SPIRAL CRASH" },
    { type = "FAIRY",    crystal = "FAIRIUM_Z",
      stem = "TWINKLETACKLE",        name = "TWINKLE TACKLE",
      menu = "STAR TACKLE" },
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
