-- type id -> the Max Move a damaging move of that type becomes while its
-- Pokemon is Dynamaxed, and the ladder that turns the base move's power into
-- the Max Move's.
--
-- The fifth pairing table, and the only one keyed on a TYPE rather than on a
-- species: every Fire move becomes the same Max Move whoever is using it, which
-- is what makes eighteen rows cover every moveset in the game.
--
-- WHERE THIS DATA COMES FROM.  The implementation guide this mod follows says
-- nothing about Max Moves beyond listing "moves" and "move power" as things a
-- Dynamax affects, so none of the numbers below are its.  The names are the
-- ones the move data itself carries (`max-flare`, `max-geyser`, ... , and
-- `max-guard` for the status case), spelled the way this game spells a move in
-- the FIGHT menu.  The ladder is the mainline games' own: seven rungs, with
-- Fighting and Poison on a lower one apiece, and it is written as ranges rather
-- than as the discrete base powers the real games list so that a move with a
-- power no cartridge ever printed still lands somewhere sensible.
--
-- The `stem` is the id these become once the mod prefixes them.  It exists
-- because an id has to be unique across every mod in the load and "MAXFLARE" is
-- exactly the id a future move pack would reach for.
--
-- WHAT IS LEFT OUT.  G-Max moves.  Not because Gigantamax is unfinished but
-- because there is no data anywhere in this project to build them from: the
-- move source carries the eighteen Max Moves and Max Guard and stops there, the
-- species records for the Gigantamax forms carry no moves at all, and the
-- engine has never heard of one.  Wiring a table of names with invented powers
-- and invented effects behind them would be this mod making up content rather
-- than modelling it, so a Gigantamax Pokemon uses the ordinary Max Move for
-- each of its types, which is what the real games give one for every type its
-- G-Max move does not cover anyway.
return {
  -- Registration order, so the shelf of registered records is the same from
  -- one run to the next -- a keyed table reorders between runs.
  types = {
    { type = "NORMAL",       stem = "MAXSTRIKE",     name = "MAX STRIKE" },
    { type = "FIGHTING",     stem = "MAXKNUCKLE",    name = "MAX KNUCKLE" },
    { type = "FLYING",       stem = "MAXAIRSTREAM",  name = "MAX AIRSTREAM" },
    { type = "POISON",       stem = "MAXOOZE",       name = "MAX OOZE" },
    { type = "GROUND",       stem = "MAXQUAKE",      name = "MAX QUAKE" },
    { type = "ROCK",         stem = "MAXROCKFALL",   name = "MAX ROCKFALL" },
    { type = "BUG",          stem = "MAXFLUTTERBY",  name = "MAX FLUTTERBY" },
    { type = "GHOST",        stem = "MAXPHANTASM",   name = "MAX PHANTASM" },
    { type = "FIRE",         stem = "MAXFLARE",      name = "MAX FLARE" },
    { type = "WATER",        stem = "MAXGEYSER",     name = "MAX GEYSER" },
    { type = "GRASS",        stem = "MAXOVERGROWTH", name = "MAX OVERGROWTH" },
    { type = "ELECTRIC",     stem = "MAXLIGHTNING",  name = "MAX LIGHTNING" },
    -- The engine's id for the type is PSYCHIC_TYPE and its name is PSYCHIC;
    -- src/tera.lua carries the same exception for the same reason.
    { type = "PSYCHIC_TYPE", stem = "MAXMINDSTORM",  name = "MAX MINDSTORM" },
    { type = "ICE",          stem = "MAXHAILSTORM",  name = "MAX HAILSTORM" },
    { type = "DRAGON",       stem = "MAXWYRMWIND",   name = "MAX WYRMWIND" },
    -- The last three exist only in a game where National Dex has registered a
    -- chart carrying them.  src/maxmoves.lua asks the live chart before it
    -- registers any of these rather than assuming, because a move naming a type
    -- the merged chart has never heard of is a load error for this mod's api
    -- level, not a quiet miss.
    { type = "DARK",         stem = "MAXDARKNESS",   name = "MAX DARKNESS" },
    { type = "STEEL",        stem = "MAXSTEELSPIKE", name = "MAX STEELSPIKE" },
    { type = "FAIRY",        stem = "MAXSTARFALL",   name = "MAX STARFALL" },
  },

  -- Fighting and Poison land a rung lower at every step, which is the one
  -- irregularity in the mainline ladder.
  lowered = { FIGHTING = true, POISON = true },

  -- Read top to bottom; the last rung has no ceiling and takes everything
  -- above the one before it.
  ladder = {
    { upTo = 40,  power = 90,  loweredPower = 70 },
    { upTo = 50,  power = 100, loweredPower = 75 },
    { upTo = 60,  power = 110, loweredPower = 80 },
    { upTo = 75,  power = 120, loweredPower = 85 },
    { upTo = 85,  power = 130, loweredPower = 90 },
    { upTo = 100, power = 140, loweredPower = 95 },
    { upTo = nil, power = 150, loweredPower = 100 },
  },

  -- The status case.  Every move with no power at all becomes this one,
  -- whatever its type, which is why it sits outside the table above.
  guard = { stem = "MAXGUARD", name = "MAX GUARD", type = "NORMAL" },
}
