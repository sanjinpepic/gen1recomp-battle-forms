-- Bug report: a level-75 Gold Rayquaza, holding no item, knowing
-- REST/FLY/HURRICANE/DRAGONASCENT (the exact `{ id = "DRAGONASCENT", pp = 5,
-- maxPp = 5 }` slot shape a real send-out produces) never offers the MEGA
-- cell, even though the player owns the Key Stone (irrelevant here --
-- Rayquaza's own trigger needs neither a Key Stone nor a held stone) and
-- Dragon Ascent works as a move in play.
--
-- Every OTHER suite covering this exemption (battle_forms_dragonascent_test.
-- lua included) proves the MECHANISM against a hand-built `data.pokemon`
-- fixture that already carries RAYQUAZA_MEGA, or against a national_dex
-- STUB standing in for the real mod. Neither can tell "the exemption is
-- wired wrong" from "the real generated national_dex data never reaches
-- data.pokemon on a Gold boot the way the fixture assumes it does" -- and
-- HANDOFF.md's own history has exactly that shape of bug (National Dex's
-- Gold registration silently dropping 1238 species until 0.27.1). This file
-- boots the REAL national_dex_mod (its own generated national.lua, its own
-- src/gen2shape.lua reshaping) and the REAL battle_forms_mod together,
-- generation = 2, NATIONAL DEX turned on the way a player who wants Mega
-- Rayquaza has to turn it on, and asks the real, merged data.pokemon
-- whether RAYQUAZA_MEGA actually landed -- then drives src/mega.lua's own
-- `available`/`activate` against a mon shaped exactly like the report.
--
-- GameVersion.set("gold") matters as much as `generation = 2` does: the
-- loader's own _gateGeneration reads GameVersion.get() to decide whether a
-- mod's manifest.games claim covers the running game, and a harness that
-- sets the loader's generation flag without also setting GameVersion falls
-- back to whatever game a PRIOR require("src.core.GameVersion") in this
-- process left standing -- silently skipping every mod whose manifest was
-- never marked with the legacy gen2compat fallback, with no error and no
-- log line, which is exactly the shape this file's own first draft chased
-- as a phantom "battle_forms doesn't load" bug before finding the real
-- cause was a missing GameVersion.set call in the test, not in the mod.
--
-- battle_forms's own files are read directly (plain io.open, not
-- tests/fs_io.lua's directory listing) rather than aliased straight onto
-- disk the way national_dex_mod is below: fs_io.lua's Windows directory
-- probe self-renames a path to itself to tell a file from a folder, which
-- fails with "Permission denied" against a directory any other process
-- (an editor, a watcher, this very checkout's own tooling) merely has open
-- -- observed directly against this mod's own directory while it was being
-- edited. Reading each file's bytes never touches that probe at all.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local GameVersion = require("src.core.GameVersion")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local NATIONAL_DEX_DIR = MOD .. "/../national_dex_mod"

local function readFile(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local body = handle:read("*a")
  handle:close()
  return body
end

local ndManifest = readFile(NATIONAL_DEX_DIR .. "/manifest.json")
if not ndManifest then
  print("battle_forms_rayquaza_gen2_real: SKIPPED -- " .. NATIONAL_DEX_DIR
    .. " not found; check out national_dex_mod alongside battle_forms_mod "
    .. "to boot the real dependency this suite needs")
  os.exit(0)
end

-- A real Gold boot always calls GameVersion.set before building its loader
-- (src/core/Game2.lua), the same as the save editor's own bootstrap
-- (tools/save-editor/App.lua). "gold" is the only Gen 2 entry
-- GameVersion.ORDER carries in this checkout.
GameVersion.set("gold")

-- The real ROM-extracted data, not a fixture -- Rayquaza (dex 384) and its
-- mega are never part of it either way (Red tops out at 151, Gold's own
-- cart at 251), so this only matters for keeping the merge target shaped
-- the way a real boot's would be.
local Data = require("src.core.Data")
Data:load()

-- HANDOFF's own documented gap: the test SDK does not populate
-- data.gen2Constants from opts.generation, but battle_forms's own
-- generationOf(mod) (main.lua) reads ONLY mod.content.constants:get(
-- "generation") -- no second signal the way national_dex's own
-- src/gen2shape.lua has grown one. Leaving this unseeded would make
-- battle_forms think it is loading on Gen 1 regardless of what
-- T.sdk.loadMods({ generation = 2 }) tells the loader itself, and every
-- assertion below would be exercising the wrong branch of src/mega.lua.
Data.gen2Constants = { generation = 2 }

-- battle_forms's own manifest-declared file list, read the same way
-- tests/battle_forms_dragonascent_test.lua's own real-loader block does:
-- out of main.lua's own source rather than typed out a second time here, so
-- a file main.lua stops loading (or gains one) cannot silently desync this
-- suite from what a real boot actually reads.
local MAIN = readFile(MOD .. "/main.lua")
local BF_MANIFEST = readFile(MOD .. "/manifest.json")
local bfFiles = {
  ["mods/battle_forms/manifest.json"] = BF_MANIFEST,
  ["mods/battle_forms/main.lua"] = MAIN,
}
for _, tree in ipairs({ "src", "data" }) do
  for name in MAIN:gmatch('"(' .. tree .. '/[%w_]+%.lua)"') do
    local key = "mods/battle_forms/" .. name
    if not bfFiles[key] then
      bfFiles[key] = assert(readFile(MOD .. "/" .. name), name .. " missing")
    end
  end
end

-- NATIONAL DEX defaults to OFF (national_dex_mod's own main.lua) --
-- wild_forms_reachability_test.lua's own header is the precedent for why an
-- untouched install registers no beyond-251 species at all, Rayquaza
-- included. A player who wants Mega Rayquaza has turned this on; this test
-- reproduces that installed state, not a fresh one.
local ENCODED_OPTIONS = [[return {
  mods = { national_dex = true, battle_forms = true },
  modOptions = { national_dex = { national_dex = "on", type_chart = "modern" } },
}]]

-- national_dex_mod is read straight off disk (its generated national.lua
-- alone is tens of thousands of lines; mirroring the reachability suites'
-- own technique of aliasing the real directory rather than copying it byte
-- for byte into a table). battle_forms_mod is served out of the in-memory
-- `bfFiles` table built above instead, for the Windows directory-probe
-- reason this file's own header explains.
local function fs()
  local inner = FsIo.new(".")
  local function mapNationalDex(path)
    if path == nil then return nil end
    local prefix = "mods/national_dex"
    if path == prefix then return NATIONAL_DEX_DIR end
    if path:sub(1, #prefix + 1) == prefix .. "/" then
      return NATIONAL_DEX_DIR .. path:sub(#prefix + 1)
    end
    return nil
  end
  return {
    read = function(path)
      if path == "options.lua" then return ENCODED_OPTIONS end
      if bfFiles[path] ~= nil then return bfFiles[path] end
      local real = mapNationalDex(path)
      if real then return inner.read(real) end
      return nil
    end,
    load = function(path)
      if path == "options.lua" then return load(ENCODED_OPTIONS, "@options.lua") end
      if bfFiles[path] ~= nil then return load(bfFiles[path], "@" .. path) end
      local real = mapNationalDex(path)
      if real then return inner.load(real) end
      return nil, "no file: " .. tostring(path)
    end,
    getInfo = function(path)
      if path == "options.lua" then return { type = "file" } end
      if path == "mods" or path == "mods/battle_forms" then
        return { type = "directory" }
      end
      if bfFiles[path] ~= nil then return { type = "file" } end
      local real = mapNationalDex(path)
      if real then return inner.getInfo(real) end
      return nil
    end,
    getDirectoryItems = function(path)
      if path == "mods" then return { "national_dex", "battle_forms" } end
      if path == "mods/battle_forms" then
        local seen, items = {}, {}
        local prefix = "mods/battle_forms/"
        for key in pairs(bfFiles) do
          if key:sub(1, #prefix) == prefix then
            local child = key:sub(#prefix + 1):match("^[^/]+")
            if child and not seen[child] then
              seen[child] = true
              items[#items + 1] = child
            end
          end
        end
        table.sort(items)
        return items
      end
      local real = mapNationalDex(path)
      if real then return inner.getDirectoryItems(real) end
      return {}
    end,
    write = function() return true end,
  }
end

local run = T.sdk.loadMods({ "national_dex", "battle_forms" },
  { data = Data, fs = fs(), generation = 2 })
T.eq(run.mods.battle_forms and run.mods.battle_forms.state, "loaded",
  "battle_forms actually loaded on this Gen 2 boot ("
    .. tostring(run.mods.battle_forms and run.mods.battle_forms.skipReason
      or run.mods.battle_forms and run.mods.battle_forms.failure
      or "not discovered at all") .. ")")
-- Two documented, pre-existing sources of noise, neither a registration
-- failure: the engine-side unresolved-reference gate (HANDOFF.md's own
-- measurement, currently 1361 -- Schemas.GEN1 gates six registries and
-- growth_rates/evolution_methods are not among them) and src/shop.lua's own
-- text_pointers registration, which every other real-loader Gen 2 suite in
-- this mod (battle_forms_conditional_test.lua, battle_forms_gen2menu_test.
-- lua, ...) already filters for the identical reason: Schemas has no Gen 2
-- target for that registry at all.
local unexpected = {}
for _, message in ipairs(run.errors) do
  if not message:find("unresolved reference", 1, true)
      and not message:find("text_pointers registry has no Gen 2 target", 1, true) then
    unexpected[#unexpected + 1] = message
  end
end
T.eq(#unexpected, 0,
  "the real pair loads with no error beyond the two documented, pre-existing "
    .. "classes of Gen 2 noise (" .. tostring(unexpected[1]) .. ")")

-- ---------------------------------------------------------------------
-- The precondition the whole bug report rests on: is RAYQUAZA_MEGA even in
-- the merged data.pokemon a real battle reads?
-- ---------------------------------------------------------------------
local rayquazaMega = run.data.pokemon.RAYQUAZA_MEGA
T.check(rayquazaMega ~= nil,
  "RAYQUAZA_MEGA reaches the merged data.pokemon on a real Gen 2 boot with "
    .. "NATIONAL DEX on -- not merely present in national.lua's own source")
if rayquazaMega then
  T.eq(rayquazaMega.form, "MEGA", "carrying its form suffix")
  T.eq(rayquazaMega.baseSpecies, "RAYQUAZA", "and its base species")
end

local rayquaza = run.data.pokemon.RAYQUAZA
T.check(rayquaza ~= nil, "RAYQUAZA itself registers too")
if rayquaza then
  T.check(rayquaza.levelMoves ~= nil,
    "reshaped to Gold's own levelMoves field, not the untranslated learnset "
      .. "src/dragonascent.lua's own patch would otherwise miss")
  local sawDragonAscent = false
  for _, row in ipairs(rayquaza.levelMoves or {}) do
    if row.move == "DRAGONASCENT" and row.level == 75 then sawDragonAscent = true end
  end
  T.check(sawDragonAscent,
    "and its own levelMoves row carries DRAGONASCENT at level 75, the real "
      .. "output of src/dragonascent.lua's patch against the real reshaped "
      .. "record")
end

-- ---------------------------------------------------------------------
-- The player's exact reported state, driven through the real registered
-- src/mega.lua entry: level 75, no held item, no battleFormsStone stamp,
-- REST/FLY/HURRICANE/DRAGONASCENT with the real slot shape a send-out
-- produces.
-- ---------------------------------------------------------------------
local Mega = dofile(MOD .. "/src/mega.lua")
local DragonAscent = dofile(MOD .. "/src/dragonascent.lua")
local Eligibility = dofile(MOD .. "/src/eligibility.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local crystalIndices = dofile(MOD .. "/data/crystals.lua")
local ultraCrystalIndices = dofile(MOD .. "/data/ultracrystal.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.OFFICIAL)

DragonAscent.bind({ gen2 = true })
local zcrystals = DragonAscent.crystalSet(crystalIndices, ultraCrystalIndices)

local entry = Mega.entry({ eligibility = Eligibility, megas = megas,
                           keyitems = KeyItems, dragonascent = DragonAscent,
                           zcrystals = zcrystals, battlerof = Battlerof,
                           gen2 = true, gen2forms = Gen2Forms, announce = Announce })

local rayquazaMon = {
  species = "RAYQUAZA", level = 75, item = nil,
  moves = {
    { id = "REST", pp = 10, maxPp = 10 },
    { id = "FLY", pp = 15, maxPp = 15 },
    { id = "HURRICANE", pp = 10, maxPp = 10 },
    { id = "DRAGONASCENT", pp = 5, maxPp = 5 },
  },
  dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
  statExp = {}, stats = { hp = 105, attack = 150, defense = 90, speed = 95,
                          specialAttack = 150, specialDefense = 90 },
  hp = 200, maxHp = 200,
}
T.check(rayquazaMon.battleFormsStone == nil, "precondition: no bag stamp either")

local battle = setmetatable({
  data = run.data, player = rayquazaMon,
  game = { save = { inventory = {} } }, events = {},
}, { __index = require("src.battle.gen2.Battle") })

T.eq(entry.available(battle), true,
  "the MEGA cell is offered for the player's exact reported Rayquaza -- "
    .. "level 75, no item, no stamp, knowing Dragon Ascent, against the "
    .. "REAL data the real loader produced")

T.eq(entry.activate(battle), true, "and arming it actually transforms")
T.eq(rayquazaMon.form, "MEGA", "into Mega Rayquaza")
T.check(rayquazaMon.stats.attack > 150,
  "with Mega Rayquaza's own (higher) Attack written onto mon.stats")

run.release()
T.finish("battle_forms_rayquaza_gen2_real")
