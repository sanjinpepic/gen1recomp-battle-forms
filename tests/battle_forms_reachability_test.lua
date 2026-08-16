-- The guard that was missing when TERA BLAST shipped in 0.27.0: a move a
-- feature requires a Pokemon to already know, checked against whether a
-- fresh game can actually teach it to anything -- not against a test
-- fixture that hands a Pokemon its moveset directly, which is exactly the
-- shape that let both Mega Rayquaza (fixed in 0.29.0) and Terastallization's
-- TERA BLAST substitution (fixed here) ship unreachable while every other
-- suite stayed green.
--
-- The requirement list is read off the feature modules' OWN declared
-- constants (DragonAscent.MOVE/SPECIES, TM.MOVE) rather than typed out a
-- second time here, so a rename in either module cannot silently desync
-- this file from what it is actually checking. Adding a THIRD feature that
-- gates on knowing a move is the whole of teaching this guard about it: one
-- row appended to REQUIREMENTS, reading the new module's own constants the
-- same way.
--
-- Reachability itself is checked the honest way: walk the REAL merged
-- `data.pokemon` registry -- built through the real loader, national_dex
-- stub and all, not asserted against this mod's own patches in isolation --
-- and look for the move in a learnset row or a tmhm entry. Nothing here
-- hands a Pokemon a moveset it would not have from a level-1 party or a
-- Bag full of the items this file's stub sells.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local DragonAscent = dofile(MOD .. "/src/dragonascent.lua")
local TM = dofile(MOD .. "/src/terablasttm.lua")
local SpeciesBaseMoves = dofile(MOD .. "/src/speciesbasemoves.lua")
local SPECIES_Z_ROWS = dofile(MOD .. "/data/speciesz.lua")

-- Every move a battle_forms feature requires a Pokemon to already know, and
-- the species it is scoped to (nil = any species may do). This is the whole
-- surface a future feature has to add itself to.
local REQUIREMENTS = {
  { feature = "Mega Rayquaza's trigger (src/dragonascent.lua)",
    move = DragonAscent.MOVE, species = DragonAscent.SPECIES },
  { feature = "Terastallization's TERA BLAST substitution (src/tera.lua, "
      .. "taught by src/terablasttm.lua's TM171)",
    move = TM.MOVE, species = nil },
}

-- The crystal this file's refusal set names, keyed for a quick lookup below
-- -- src/speciesbasemoves.lua's own REFUSED table, not a second list typed
-- out here, so the two can never quietly disagree about which one it is.
local REFUSED_CRYSTALS = {}
for _, row in ipairs(SpeciesBaseMoves.REFUSED) do
  REFUSED_CRYSTALS[row.crystal] = row
end

-- Whether `move` is reachable for `species` (or for SOME species, if nil)
-- in the merged dataset a fresh game would actually load: a row in its
-- level-up learnset, or the move sitting in its tmhm list -- the two routes
-- this engine actually offers a Pokemon a move through outside a trade or
-- an event, and the same two routes src/dragonascent.lua and
-- src/terablasttm.lua each use.
local function reachable(data, move, species)
  for id, record in pairs(data.pokemon or {}) do
    if type(record) == "table" and (species == nil or id == species) then
      for _, row in ipairs(record.learnset or {}) do
        if row.move == move then return true end
      end
      for _, tm in ipairs(record.tmhm or {}) do
        if tm == move then return true end
      end
    end
  end
  return false
end

-- ---------------------------------------------------------------------
-- The helper itself is not vacuous: a move nothing offers must read as
-- unreachable, or every assertion below would pass for the wrong reason.
-- ---------------------------------------------------------------------
do
  local data = { pokemon = {
    SOMETHING = { learnset = { { level = 1, move = "TACKLE" } }, tmhm = { "CUT" } },
  } }
  T.eq(reachable(data, "NOBODYKNOWSTHIS", nil), false,
    "a move nothing teaches is unreachable")
  T.eq(reachable(data, "TACKLE", nil), true, "a learnset row makes a move reachable")
  T.eq(reachable(data, "CUT", nil), true, "so does a tmhm entry")
  T.eq(reachable(data, "TACKLE", "SOMETHING"), true,
    "reachable for the species it is scoped to")
  T.eq(reachable(data, "TACKLE", "SOMEONE_ELSE"), false,
    "and not reachable for a species that does not carry it, even though "
      .. "some OTHER species does")
end

-- Whether EVERY species in `list` can already learn `move` -- not merely
-- one of them, since a species Z-Crystal with more than one paired species
-- (Lycanium Z's three Lycanroc formes) is taught the move on every one of
-- them by src/speciesbasemoves.lua, and a guard checking only the first
-- could stay green while the other two shipped unreachable.
local function reachableForAll(data, move, species)
  for _, id in ipairs(species) do
    if not reachable(data, move, id) then return false end
  end
  return true
end

do
  local data = { pokemon = {
    A = { learnset = { { level = 1, move = "MOVE" } } },
    B = { learnset = { { level = 1, move = "MOVE" } } },
    C = { learnset = {} },
  } }
  T.eq(reachableForAll(data, "MOVE", { "A", "B" }), true,
    "reachable when every named species carries it")
  T.eq(reachableForAll(data, "MOVE", { "A", "C" }), false,
    "not reachable when even one of them does not, though another does")
  T.eq(reachableForAll(data, "MOVE", { "A" }), true,
    "a single-species list behaves exactly like reachable() alone")
end

-- ---------------------------------------------------------------------
-- Through the real loader, national_dex stub and all: the same shape every
-- other integration suite in this mod builds, read out of main.lua's own
-- source so a missing sibling shows up as every requirement failing rather
-- than as something about options.
-- ---------------------------------------------------------------------
local function readFile(path)
  local handle = assert(io.open(path, "rb"), "cannot open " .. path)
  local body = handle:read("*a")
  handle:close()
  return body
end

local MAIN = readFile(MOD .. "/main.lua")
local shipped = { "manifest.json", "main.lua" }
for _, tree in ipairs({ "src", "data" }) do
  for name in MAIN:gmatch('"(' .. tree .. '/[%w_]+%.lua)"') do
    shipped[#shipped + 1] = name
  end
end
T.check(#shipped > 10, "main.lua's sibling list was read back out of its source")

-- A national_dex stub carrying everything the two requirements above name,
-- registered the unconditional way national_dex's own code always does
-- (src/moves.lua's header: registration is unconditional, only the
-- WIDENING of a learnset is gated) -- plus RAYQUAZA's REST/FLY/HYPER BEAM
-- learnset rows, so DRAGONASCENT being appended rather than replacing it is
-- provable here too, the same as tests/battle_forms_dragonascent_test.lua's
-- own final block.
local NATIONAL_DEX_BASE = [[
return function(mod)
  mod.content.pokemon:register("RAYQUAZA", {
    id = "RAYQUAZA", name = "Rayquaza", dex = 384,
    types = { "DRAGON", "FLYING" },
    baseStats = { hp = 105, attack = 150, defense = 90, speed = 95, special = 150 },
    catchRate = 45, baseExp = 255, growthRate = "MEDIUM_FAST",
    level1Moves = {},
    learnset = { { level = 54, move = "REST" }, { level = 63, move = "FLY" },
                 { level = 90, move = "HYPER_BEAM" } },
    spriteFront = "assets/sets/placeholder/front.png",
    spriteBack = "assets/sets/placeholder/back.png",
    frontSize = 5,
  })
  mod.content.moves:register("DRAGONASCENT", {
    id = "DRAGONASCENT", name = "Dragon Ascent", type = "FLYING",
    power = 120, accuracy = 100, pp = 5, category = "physical",
    effect = "NO_ADDITIONAL_EFFECT", effectModeled = false,
  })
  mod.content.moves:register("REST", { id = "REST", name = "Rest",
    type = "PSYCHIC_TYPE", power = 0, accuracy = 100, pp = 10,
    effect = "NO_ADDITIONAL_EFFECT" })
  mod.content.moves:register("FLY", { id = "FLY", name = "Fly",
    type = "FLYING", power = 90, accuracy = 95, pp = 15,
    effect = "NO_ADDITIONAL_EFFECT" })
  mod.content.moves:register("HYPER_BEAM", { id = "HYPER_BEAM",
    name = "Hyper Beam", type = "NORMAL", power = 150, accuracy = 90,
    pp = 5, effect = "NO_ADDITIONAL_EFFECT" })
  mod.content.moves:register("TERABLAST", {
    id = "TERABLAST", name = "Tera Blast", type = "NORMAL",
    power = 80, accuracy = 100, pp = 10, category = "special",
    effect = "NO_ADDITIONAL_EFFECT", effectModeled = false,
  })
]]

-- Every species and move data/speciesz.lua's fourteen rows name, generated
-- rather than typed by hand -- the same reason the crystal-rows guard below
-- reads that file directly instead of a second copy of its roster. THREE
-- species (RAICHU_ALOLA, the eight Pikachu cap forms, MEW) are seeded with
-- the tmhm entry that already makes their own crystal work today
-- (ALORAICHIUM_Z/PIKANIUM_Z's THUNDERBOLT, MEWNIUM_Z's PSYCHIC_M -- Mew
-- learns every TM in the real games, TM29 among them), simulating what a
-- real national_dex/cart pairing already provides with NO involvement from
-- src/speciesbasemoves.lua at all. Every other species starts with an EMPTY
-- learnset and tmhm, so passing this guard proves reachability comes from
-- battle_forms's own patch and nothing else.
local ALREADY_REACHABLE = {}
for _, row in ipairs(SPECIES_Z_ROWS) do
  if row.crystal == "ALORAICHIUM_Z" or row.crystal == "PIKANIUM_Z"
     or row.crystal == "MEWNIUM_Z" then
    for _, species in ipairs(row.species) do
      ALREADY_REACHABLE[species] = ALREADY_REACHABLE[species] or {}
      table.insert(ALREADY_REACHABLE[species], row.move)
    end
  end
end

local function crystalRosterLua()
  local seenMove, seenSpecies = {}, {}
  local out = {}
  for _, row in ipairs(SPECIES_Z_ROWS) do
    if not seenMove[row.move] then
      seenMove[row.move] = true
      out[#out + 1] = ('  mod.content.moves:register(%q, { id = %q, '
        .. 'name = %q, type = "NORMAL", power = 90, accuracy = 100, '
        .. 'pp = 10, category = "physical", effect = "NO_ADDITIONAL_EFFECT", '
        .. 'effectModeled = false })\n'):format(row.move, row.move, row.move)
    end
    for _, species in ipairs(row.species) do
      if not seenSpecies[species] then
        seenSpecies[species] = true
        local tmhm = ALREADY_REACHABLE[species]
        local tmhmLua = "{}"
        if tmhm then
          local parts = {}
          for _, move in ipairs(tmhm) do parts[#parts + 1] = ("%q"):format(move) end
          tmhmLua = "{ " .. table.concat(parts, ", ") .. " }"
        end
        out[#out + 1] = ('  mod.content.pokemon:register(%q, { id = %q, '
          .. 'name = %q, dex = 1, types = { "NORMAL" }, baseStats = { '
          .. 'hp = 80, attack = 80, defense = 80, speed = 80, special = 80 }, '
          .. 'catchRate = 45, baseExp = 100, growthRate = "MEDIUM_FAST", '
          .. 'level1Moves = {}, learnset = {}, tmhm = %s, evolutions = {}, '
          .. 'spriteFront = "assets/sets/placeholder/front.png", '
          .. 'spriteBack = "assets/sets/placeholder/back.png", frontSize = 5 })\n')
          :format(species, species, species, tmhmLua)
      end
    end
  end
  return table.concat(out)
end

local NATIONAL_DEX_STUB = NATIONAL_DEX_BASE .. crystalRosterLua() .. "end\n"

local function load()
  local files = {
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = NATIONAL_DEX_STUB,
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end
  return T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
    fs = T.sdk.memfs(files), data = T.fixtures.fresh(),
  })
end

do
  local run = load()
  T.eq(#run.errors, 0, "the mod loads clean against a real RAYQUAZA/DRAGONASCENT/TERABLAST")

  for _, req in ipairs(REQUIREMENTS) do
    T.check(reachable(run.data, req.move, req.species),
      req.feature .. " requires " .. tostring(req.move)
        .. (req.species and (" on " .. req.species) or " on some species")
        .. ", and it must be reachable from a fresh game -- learned by "
        .. "level-up or teachable by a TM/HM -- or the feature built on it "
        .. "is unreachable no matter how correct its own mechanism is")
  end

  -- ---------------------------------------------------------------------
  -- Every one of the fourteen species Z-Crystals' own base move, read
  -- straight off data/speciesz.lua -- the actual crystal roster, not a
  -- second copy of it -- so a fifteenth crystal is covered by this guard
  -- the moment its row is added there, with nothing else to remember.
  -- ---------------------------------------------------------------------
  local checked = 0
  for _, row in ipairs(SPECIES_Z_ROWS) do
    local refusal = REFUSED_CRYSTALS[row.crystal]
    if refusal then
      -- The one deliberate exception, said out loud rather than silently
      -- skipped: src/speciesbasemoves.lua refuses to model Spirit
      -- Shackle's real effect (blocking a switch) rather than fake an
      -- effectModeled flag with nothing behind it, so Decidium Z is
      -- EXPECTED to still be unreachable, and this asserts exactly that
      -- rather than merely not asserting the opposite.
      T.eq(row.move, refusal.move, refusal.crystal .. "'s refusal names "
        .. "the same move data/speciesz.lua's own row does")
      T.eq(reachableForAll(run.data, row.move, row.species), false,
        refusal.crystal .. "'s own move (" .. row.move .. ") is deliberately "
          .. "still unreachable -- " .. refusal.reason)
    else
      checked = checked + 1
      T.check(reachableForAll(run.data, row.move, row.species),
        row.crystal .. " requires " .. row.move .. " on "
          .. table.concat(row.species, "/") .. ", and every one of those "
          .. "species must be able to learn it from a fresh game or the "
          .. "crystal is unreachable no matter how correct its own "
          .. "conversion logic is")
    end
  end
  T.eq(checked, #SPECIES_Z_ROWS - 1,
    "thirteen of the fourteen crystals were checked for real reachability "
      .. "and the fourteenth (the refusal) was checked for the opposite")
end

T.finish("battle_forms_reachability")
