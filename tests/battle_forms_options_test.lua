-- The MEGA EVOLUTIONS option, driven through the real loader.
--
-- The module suites pin down what each piece does with a given set; this one
-- exists because main.lua is what decides WHICH set each piece is handed, and
-- that decision is invisible to them -- handing src/stone.lua the selected
-- table where it wants the full one would leave every other suite green while
-- quietly deleting item records a save depends on.  So the whole mod is loaded
-- from a synthesized filesystem, once per setting, and the registries are read
-- back the way the game would see them.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Megaset = dofile(MOD .. "/src/megaset.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local raw = dofile(MOD .. "/data/megas.lua")
local indices = dofile(MOD .. "/data/stones.lua")
local orbIndices = dofile(MOD .. "/data/orbs.lua")
local keyIndices = dofile(MOD .. "/data/keyitems.lua")
local crystalIndices = dofile(MOD .. "/data/crystals.lua")
-- The crystals share the key items' shelf, so the shelf count below has to know
-- how many of them there are; counted rather than written down, because a
-- number written down here would go stale the moment another one is added.
local crystalCount = 0
for _ in pairs(crystalIndices) do crystalCount = crystalCount + 1 end
-- Ultranecrozium Z sells on that same shelf, immediately behind the eighteen,
-- through its own call in main.lua rather than a slot in data/crystals.lua --
-- counted separately for the same reason the eighteen are counted at all.
local ultraCrystalIndices = dofile(MOD .. "/data/ultracrystal.lua")
local ultraCrystalCount = 0
for _ in pairs(ultraCrystalIndices) do ultraCrystalCount = ultraCrystalCount + 1 end
-- The fourteen species crystals sell on that same shelf too, immediately
-- behind Ultranecrozium Z -- counted for the same reason the other two are.
local speciesZCrystalIndices = dofile(MOD .. "/data/speciescrystals.lua")
local speciesZCrystalCount = 0
for _ in pairs(speciesZCrystalIndices) do
  speciesZCrystalCount = speciesZCrystalCount + 1
end
-- The appliances share that shelf too, and are counted for the same reason.
local applianceIndices = dofile(MOD .. "/data/appliances.lua")
local applianceCount = 0
for _ in pairs(applianceIndices) do applianceCount = applianceCount + 1 end
local KeyItems = dofile(MOD .. "/src/keyitems.lua")

local function readFile(path)
  local handle = assert(io.open(path, "rb"), "cannot open " .. path)
  local body = handle:read("*a")
  handle:close()
  return body
end

-- Every sibling main.lua reads, because it reads them all before it installs
-- anything: one missing name and the load bails early, which shows up here as
-- the whole shop being empty rather than as anything about options.
--
-- Read out of main.lua's own source rather than mirrored by hand.  A hand
-- mirror is a list that can silently disagree with the list that matters, and
-- this one did: adding a module used to starve the fixture of it and fail
-- about 200 checks with a symptom nowhere near the cause.
local MAIN = readFile(MOD .. "/main.lua")
local SHIPPED = { "manifest.json", "main.lua" }
for _, tree in ipairs({ "src", "data" }) do
  for name in MAIN:gmatch('"(' .. tree .. '/[%w_]+%.lua)"') do
    SHIPPED[#SHIPPED + 1] = name
  end
end
-- A pattern that stops matching would leave the fixture with nothing but the
-- root files and every check below passing or failing for the wrong reason.
T.check(#SHIPPED > 10, "main.lua's sibling list was read back out of its source")

-- The fixture data set carries no Celadon floor, so the clerk entry this mod
-- extends is seeded onto it -- trimmed to the fields shop.lua reads and
-- writes.  Without a base list there is nothing for the deep merge to
-- concatenate onto, and "the floor keeps its own stock" would pass vacuously.
--
-- Stocked with the fixture set's own items rather than the real floor's:
-- a mart entry is a checked reference into `items`, so naming POKE_DOLL here
-- would only be an unresolved reference against a data set that has never
-- heard of it.  The list is copied per load so no merge can reach back into
-- the constant.
local FLOOR_STOCK = { "FIX_POTION", "FIX_BALL", "FIX_TM" }
local function seedFloor(data)
  local mart = {}
  for i, id in ipairs(FLOOR_STOCK) do mart[i] = id end
  data.text_pointers = data.text_pointers or {}
  data.text_pointers.CeladonMart4F = {
    TEXT_CELADONMART4F_CLERK = {
      label = "CeladonMart4FClerkText",
      mart = mart,
    },
  }
  return data
end

-- `stored` is nil for a fresh install, which is the case that matters most:
-- a player who has never opened the settings screen must get OFFICIAL.
local function load(stored)
  local files = {
    -- battle_forms declares national_dex as a hard dependency and
    -- _enforceDependencies runs before any entry file is compiled, so
    -- something has to answer that id; the real mod is heavyweight and needs
    -- its own options set just to load quietly.
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = "return function() end",
  }
  for _, name in ipairs(SHIPPED) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end
  if stored then
    files["options.lua"] = ('return { modOptions = { battle_forms = '
      .. '{ megas = "%s" } } }'):format(stored)
  end

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
    fs = T.sdk.memfs(files),
    data = seedFloor(T.fixtures.fresh()),
  })
  T.eq(#run.errors, 0, "the mod loads clean with the option "
    .. (stored and ("set to " .. stored) or "never set"))
  return run.data
end

local function martOf(data)
  local floor = data.text_pointers and data.text_pointers.CeladonMart4F
  local clerk = floor and floor.TEXT_CELADONMART4F_CLERK
  return clerk and clerk.mart or {}
end

local official = Megaset.stoneIds(Megaset.select(raw, Megaset.OFFICIAL))

for _, case in ipairs({ { stored = nil, label = "unset", all = false },
                        { stored = "official", label = "OFFICIAL", all = false },
                        { stored = "all", label = "ALL", all = true } }) do
  local data = load(case.stored)

  -- Save safety, and the reason this suite exists.  Whatever the option
  -- says, every WIRED stone keeps its item record and its effect: a stone
  -- can already be in a bag when the option changes, and a bag byte with no
  -- record behind it is a save the game can no longer read back.
  --
  -- RAYQUAZITE is the one deliberate exception: withdrawn from
  -- data/megas.lua in 0.30.0, it keeps its bag byte permanently reserved
  -- (data/stones.lua's own header) but is registered by nothing -- see
  -- tests/battle_forms_stone_test.lua for that behaviour pinned directly.
  local RETIRED = { RAYQUAZITE = true }
  local registered = 0
  for stoneId in pairs(indices) do
    if RETIRED[stoneId] then
      T.eq(data.items and data.items[stoneId], nil,
        stoneId .. " stays unregistered with the option " .. case.label)
    else
      registered = registered + 1
      T.check(data.items and data.items[stoneId] ~= nil,
        stoneId .. " is a registered item with the option " .. case.label)
      T.check(data.item_effects and data.item_effects[stoneId] ~= nil,
        stoneId .. " has its item effect with the option " .. case.label)
    end
  end
  T.eq(registered, 95, "all 95 wired stones were checked with the option "
    .. case.label)

  -- The shelf is where the option is allowed to take a stone away.
  local mart = martOf(data)
  local sold = {}
  for _, id in ipairs(mart) do sold[id] = true end
  T.eq(#mart,
    #FLOOR_STOCK + #KeyItems.ITEMS + crystalCount + ultraCrystalCount
      + speciesZCrystalCount + applianceCount + (case.all and 95 or 47),
    "the Celadon shelf holds the floor's own stock, every key item, every "
      .. "crystal, Ultranecrozium Z, every species crystal, every appliance "
      .. "and " .. (case.all and "every" or "only the official")
      .. " stone with the option " .. case.label)
  for _, id in ipairs(FLOOR_STOCK) do
    T.check(sold[id], "the floor's own stock survives with the option "
      .. case.label)
  end
  T.check(sold.ULTRANECROZIUM_Z,
    "Ultranecrozium Z is sold on the Celadon shelf with the option "
      .. case.label)
  T.check(sold.PIKASHUNIUM_Z,
    "a species Z-Crystal is sold on the Celadon shelf with the option "
      .. case.label)
  T.check(sold.VENUSAURITE,
    "an official stone is sold with the option " .. case.label)
  T.eq(sold.STARMIITE, case.all or nil,
    "an extended stone is sold only under ALL (option " .. case.label .. ")")
  for stoneId in pairs(indices) do
    if not official[stoneId] and not case.all then
      T.check(not sold[stoneId],
        stoneId .. " is off the shelf with the option " .. case.label)
    end
  end

  -- Eligibility, through the effect the engine would actually run: an
  -- extended stone under OFFICIAL refuses the way a stone used on the wrong
  -- species refuses, rather than erroring or half-working.
  local mon = { species = "STARMIE" }
  local outcome = data.item_effects.STARMIITE.use({ target = mon })
  T.eq(outcome, case.all and "kept" or "failed",
    "using STARMIITE on a Starmie with the option " .. case.label)
  T.eq(E.stoneOf(mon), case.all and "STARMIITE" or nil,
    "a refused use leaves the mon unstamped, so nothing can be armed "
      .. "(option " .. case.label .. ")")

  local charizard = { species = "CHARIZARD" }
  T.eq(data.item_effects.CHARIZARDITE_X.use({ target = charizard }), "kept",
    "an official stone still works with the option " .. case.label)

  -- The MEGA EVOLUTIONS option has no say over primal reversion, and the way
  -- to be sure of that is to read the orbs back off the same loaded data set
  -- under all three settings: registered, working, and never on the mega
  -- stones' shelf whatever that shelf is currently holding.
  for orbId in pairs(orbIndices) do
    T.check(data.items and data.items[orbId] ~= nil,
      orbId .. " is a registered item with the option " .. case.label)
    T.check(data.item_effects and data.item_effects[orbId] ~= nil,
      orbId .. " has its item effect with the option " .. case.label)
    T.check(not sold[orbId],
      orbId .. " is not on the Celadon shelf with the option " .. case.label)
  end

  -- The trainer's key items, checked here rather than only in their own suite
  -- because main.lua is what decides they are registered at all and that
  -- decision is invisible to a module test.  Never gated: no option turns one
  -- off, and a bag byte with no record behind it is a save the game can no
  -- longer read back -- the same rule the stones keep.
  for _, itemId in ipairs(KeyItems.ITEMS) do
    T.check(data.items and data.items[itemId] ~= nil,
      itemId .. " is a registered item with the option " .. case.label)
    T.eq(data.items[itemId].index, keyIndices[itemId],
      itemId .. " keeps its permanent bag byte with the option " .. case.label)
    T.check(data.item_effects == nil or data.item_effects[itemId] == nil,
      itemId .. " registers no item effect -- it gates a mechanic, it is not "
        .. "used on anything (option " .. case.label .. ")")
    T.check(sold[itemId],
      itemId .. " is sold on the Celadon shelf with the option " .. case.label)
  end

  -- Ahead of every mega stone on that shelf, whatever the option leaves on it:
  -- a Key Stone under ninety-odd stones is a Key Stone a player never finds.
  local firstStone, lastKey = nil, nil
  for i, id in ipairs(mart) do
    if indices[id] and not firstStone then firstStone = i end
    if keyIndices[id] then lastKey = i end
  end
  T.check(lastKey ~= nil and firstStone ~= nil and lastKey < firstStone,
    "every key item comes before the first mega stone on the shelf with the "
      .. "option " .. case.label)

  local groudon = { species = "GROUDON" }
  T.eq(data.item_effects.RED_ORB.use({ target = groudon }), "kept",
    "the Red Orb assigns itself to a Groudon with the option " .. case.label)
  T.eq(E.stoneOf(groudon), "RED_ORB",
    "and stamps it, which is all a primal reversion ever needs "
      .. "(option " .. case.label .. ")")

  -- The one item family that writes a form into the save, exercised through the
  -- real load rather than a fixture: main.lua has to have bound the persistent
  -- module to the item effect, or the stamp would land with no marker beside it
  -- and the Rotom would only be its appliance form inside a battle.
  do
    -- The harness loads against fixture data with no National Dex records in
    -- it, and the marker is read off the record's own `form` field, so the one
    -- record this check needs is supplied here.  Everything else below is the
    -- real registration.
    data.pokemon.ROTOM_WASH = data.pokemon.ROTOM_WASH
      or { baseStats = { hp = 50, attack = 65, defense = 107,
                         speed = 86, special = 107 },
           types = { "ELECTRIC", "WATER" }, form = "WASH" }
    local rotom = { species = "ROTOM" }
    T.eq(data.item_effects.WASHING_MACHINE.use({ data = data, target = rotom }),
      "kept",
      "the washing machine assigns itself to a Rotom with the option "
        .. case.label)
    T.eq(E.stoneOf(rotom), "WASHING_MACHINE",
      "and stamps it (option " .. case.label .. ")")
    T.eq(rotom.form, "WASH",
      "and marks the form out of battle, which is what reaches the save "
        .. "(option " .. case.label .. ")")
    T.eq(rotom.species, "ROTOM",
      "without ever touching the species (option " .. case.label .. ")")
    T.eq(data.item_effects.WASHING_MACHINE.use({ data = data, target = rotom }),
      "kept", "and using it again is the way back (option " .. case.label .. ")")
    T.eq(rotom.form, nil,
      "which leaves the save exactly as it found it (option "
        .. case.label .. ")")
  end

  local lobby = data.text_pointers and data.text_pointers.IndigoPlateauLobby
  local lobbyMart = lobby and lobby.TEXT_INDIGOPLATEAULOBBY_CLERK
    and lobby.TEXT_INDIGOPLATEAULOBBY_CLERK.mart or {}
  local atLobby = {}
  for _, id in ipairs(lobbyMart) do atLobby[id] = true end
  T.check(atLobby.RED_ORB and atLobby.BLUE_ORB,
    "both orbs are sold at the Indigo Plateau lobby with the option "
      .. case.label)
  for _, itemId in ipairs(KeyItems.ITEMS) do
    T.check(not atLobby[itemId],
      itemId .. " is not on the Indigo Plateau counter with the option "
        .. case.label)
  end
end

T.finish("battle_forms_options")
