-- Which type a particular Pokemon terastallizes into, as a property OF that
-- Pokemon rather than of the mod.
--
-- src/tera.lua's own header argues, at length and correctly for the game it was
-- written against, that this could not be a per-Pokemon value: a Gen 1 party
-- screen has no field to pick a type in, the battle cell is one row holding one
-- label, and an item-per-type would mean eighteen bag items to express one
-- choice.  All of that is still true.  What it concluded from it -- that the
-- type must therefore be a mod option -- is what this file replaces, because
-- there is a third option that header did not consider: not asking anybody.
--
-- DERIVED, NOT STORED, and that is the whole design.  A Pokemon already carries
-- sixteen bits nothing else in this mod reads: four DVs, four bits each,
-- rolled when it was generated and never touched again.  They are per-Pokemon,
-- they are stable for its whole life, and -- the part that matters -- they are
-- real cartridge fields, so they survive a Game Boy .sav export that a stamp of
-- our own could not.  src/persistent.lua spends a long header explaining what
-- an export does to a written marker: it deletes it, with no hook anywhere near
-- the 44-byte struct to notice.  A Charizard exported and re-imported comes back
-- with the same DVs, so it comes back with the same Tera type, and nothing had
-- to be written for that to be true.
--
-- WHAT IS DERIVED FROM THEM.  One of the Pokemon's OWN types, evenly, so a
-- dual-type is an even split between its two and a single-type always gets the
-- one it has.  That is deliberately the opposite of what the option defaulted
-- to (NORMAL), and the reason src/tera.lua gave for that default -- "a Pokemon
-- terastallizing into the type it already has changes nothing whatsoever" -- is
-- answered rather than ignored: it is right about a SINGLE-typed Pokemon and
-- wrong about a dual-typed one, where becoming purely one of your two types
-- drops every weakness the other brought.  A Charizard that teras into Fire
-- stops taking quadruple damage from Rock, and nothing about that is a no-op.
--
-- THE RARE ONE.  Roughly one Pokemon in sixteen gets a type that is not its own
-- at all, drawn from the whole chart.  That is what makes the mechanic worth
-- looking at: a Water Tera Pikachu exists, it is uncommon, and you can tell
-- which one you caught before you ever spend a shard on it.
--
-- WHERE THIS DIVERGES FROM WHAT WAS ASKED, said out loud rather than buried:
-- the brief put the rare off-type on WILD ENCOUNTERS specifically.  Deriving
-- from DVs cannot tell a wild Pokemon from a starter, a gift or a hatched egg,
-- because DVs are all it looks at and every Pokemon has them.  So the one-in-
-- sixteen applies to every Pokemon in the game, not only caught ones.  Making
-- it wild-only would mean marking origin at catch time, which means writing to
-- the save, which gives back the export-survival that is the entire reason this
-- is derived.  The uniform version is the one that costs nothing; if wild-only
-- is wanted anyway, that is a stamp and it is a different decision.
local M = {}

-- The field the Tera Orb writes when a player spends shards to change a
-- Pokemon's type (src/terashop.lua).  Absent on every Pokemon until then, which
-- is why the derivation above is the common case rather than the fallback.
--
-- Same discipline as src/persistent.lua's own stamp: a written value is the
-- override and the derived one is the truth underneath it, so a save that loses
-- the stamp -- an export, an import, a mod uninstall -- degrades to a Pokemon
-- with its original Tera type rather than to one with none.
M.STAMP = "battleFormsTeraType"

-- One Pokemon in this many carries a type that is not its own.
--
-- Sixteen because it wants to be noticeable across a playthrough and not across
-- a route: a player who catches a dozen Pokemon on the way to the second gym
-- should usually have none, and should not be surprised to have one.
M.OFFBEAT_ONE_IN = 16

-- Sixteen bits off the DVs and the species, one independently seeded pass per
-- decision.
--
-- THREE HASHES RATHER THAN THREE SLICES OF ONE, and the reason is a bug this
-- file's own suite caught before it shipped.  The first version built one
-- accumulator -- DVs packed into sixteen bits, then `h = h * 31 + byte` over
-- the species -- and read the three decisions out of different bit ranges of
-- it.  In a `h * 31 + x` chain the LAST input mixed dominates the low bits, and
-- the packed DV word contributes nothing at all to the bottom eight when speed
-- and special are both zero, because the word is then a multiple of 256 and 31
-- preserves that.  So for any such Pokemon the low bits depended only on the
-- species: every Bulbasaur with speed=special=0 terastallized into Grass,
-- across all 256 remaining spreads, and the "even split between its two types"
-- this whole file promises simply did not happen there.
--
-- Seeding a fresh pass per decision removes the failure mode rather than
-- tuning it: each answer is a function of every input bit, so no decision can
-- be steered by which slice of one number it happened to be handed.  The two
-- multiply-and-fold rounds at the end are what carry the high bits back down
-- into the low ones, which a bare multiply never does -- multiplying by an odd
-- constant leaves bit i of the product depending only on bits 0..i.
--
-- Arithmetic rather than the `bit` library on purpose: this runs inside the mod
-- sandbox on two engines, every intermediate here stays far below 2^53 so the
-- doubles are exact, and plain multiply-and-modulo cannot depend on which
-- engine loaded.
-- A Pokemon with no DVs at all hashes on its species alone rather than being
-- refused.  Every Pokemon the two engines generate has them (Stats.randomDVs
-- runs at creation on both), so this is the malformed case -- but refusing it
-- would take the TERA cell off the menu for a Pokemon the player is looking
-- at, with nothing on screen to say why, and src/tera.lua's own header is
-- explicit that an absent cell must never be the answer to a question nobody
-- can see.  A species-only answer is deterministic, is always one of that
-- Pokemon's own types, and is right often enough that nobody has to know.
local function hashWith(seed, mon)
  local dvs = (mon and type(mon.dvs) == "table") and mon.dvs or {}

  local h = seed
  h = (h * 31 + (tonumber(dvs.attack) or 0) % 16) % 65536
  h = (h * 31 + (tonumber(dvs.defense) or 0) % 16) % 65536
  h = (h * 31 + (tonumber(dvs.speed) or 0) % 16) % 65536
  h = (h * 31 + (tonumber(dvs.special) or 0) % 16) % 65536

  local species = type(mon.species) == "string" and mon.species or ""
  for i = 1, #species do
    h = (h * 31 + species:byte(i)) % 65536
  end

  -- 40503 is the odd integer nearest 2^16 divided by the golden ratio, the
  -- ordinary Fibonacci-hashing multiplier at this width.  The fold after each
  -- multiply is the half that matters here.
  for _ = 1, 2 do
    h = (h * 40503) % 65536
    h = (h + math.floor(h / 256)) % 65536
  end
  return h
end

-- Every type id the RUNNING game's merged chart can resolve, in a stable order.
--
-- Read off the chart rather than from a list of our own for the reason
-- src/tera.lua's own typesOf gives: the engine registers Red's fifteen, and
-- DARK, STEEL and FAIRY exist only once National Dex has registered a chart
-- over the top.  A list of eighteen written here would promise three types the
-- chart may never have heard of.
--
-- Sorted because `pairs` reorders between runs and this feeds a modulo: an
-- unsorted list would give the same Pokemon a different rare type on every
-- boot, which is the one thing a derived value must never do.
function M.chartTypes(data)
  local chart = data and data.type_chart
  local types = chart and chart.types
  if type(types) ~= "table" then return nil end
  local out = {}
  for id in pairs(types) do out[#out + 1] = id end
  if #out == 0 then return nil end
  table.sort(out)
  return out
end

-- The Pokemon's own types, filtered to what the chart can actually resolve.
--
-- The BASE species record, never a form's.  A Rotom that has been through four
-- appliances is one Pokemon and has one Tera type the whole time; deriving from
-- whatever form it currently wears would let a held item silently change it,
-- which is exactly the "recalculated during battle" failure the brief rules
-- out.
function M.own(data, mon)
  local species = mon and mon.species
  local record = species and data and data.pokemon and data.pokemon[species]
  local types = record and record.types
  if type(types) ~= "table" then return nil end
  local chart = data and data.type_chart and data.type_chart.types
  local out = {}
  for _, id in ipairs(types) do
    if type(id) == "string" and (not chart or chart[id]) then
      out[#out + 1] = id
    end
  end
  if #out == 0 then return nil end
  return out
end

-- The Pokemon's Tera type, or nil with a reason.
--
-- Order is the brief's own: a written override wins, then the derivation.  The
-- override is validated against the live chart rather than trusted, because a
-- stamp written while National Dex was on can outlive it being switched off --
-- and a Tera type naming a type the chart cannot resolve would arm a change
-- that cannot be made, which src/tera.lua already refuses to do out loud.
function M.of(data, mon)
  if not mon then return nil, "no_mon" end

  local stamped = mon[M.STAMP]
  if type(stamped) == "string" and stamped ~= "" then
    local chart = data and data.type_chart and data.type_chart.types
    if chart and not chart[stamped] then return nil, "stamp_unknown_type" end
    return stamped, "stamp"
  end

  -- Three separately seeded passes, one per decision.  The seeds are arbitrary
  -- odd constants and only have to differ; see hashWith's header for why this
  -- is three hashes rather than three slices of one.
  local rare = hashWith(0x9E37, mon)
  local pick = hashWith(0x85EB, mon)
  local offbeat = hashWith(0xC2B2, mon)

  local own = M.own(data, mon)
  if not own then return nil, "no_types" end

  rare = rare % M.OFFBEAT_ONE_IN

  if rare == 0 then
    local all = M.chartTypes(data)
    if all then
      return all[(offbeat % #all) + 1], "offbeat"
    end
    -- No resolvable chart at all: fall through to the mon's own types rather
    -- than refuse.  A Pokemon with no Tera type is a cell that vanishes for a
    -- reason the player cannot see, and its own type is always answerable.
  end

  return own[(pick % #own) + 1], "own"
end

return M
