-- The outward-facing API: what this mod tells another mod when a Pokemon
-- stops being what its species record says it is.
--
-- Everything else in tests/ pins behaviour this mod owns end to end. This
-- pins a CONTRACT with code that is not in this repository, which makes two
-- things worth more here than anywhere else:
--
--   * the event NAME and the payload's field names, because a consumer
--     subscribes to a string and reads keys off a table, and renaming
--     either is a silent break in somebody else's mod rather than a failure
--     in this one;
--
--   * that the announcement is fired from the two primitives -- so a
--     mechanic added later cannot apply a form nobody outside hears about
--     -- and that it is fired AFTER the stats and types are written, so a
--     listener reading straight off payload.mon sees the same world the
--     payload describes.
--
-- The last section drives a real form change through the real loader, the
-- real national_dex mod and the real Runtime event bus, and asserts a real
-- subscriber received it. That section is what proves the loader's own emit
-- rule is satisfied: a mod may only emit under its own "mod.<id>." prefix
-- and the loader RAISES on a name that is not (src/mods/Loader.lua's own
-- `_api`), so a wrong prefix here would be a subscriber that never fires,
-- not a test that still passes.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

-- One fresh copy per section: every module below keeps its bind() in a
-- module-level upvalue, and a shared instance would let one section's
-- wiring decide another section's outcome.  Deliberately not named `load`
-- -- the real-loader section at the bottom of this file needs Lua's own
-- global `load` for its filesystem shim.
local function loadModule(name) return dofile(MOD .. "/src/" .. name) end

-- Records every emit the way the real bus is called: `bus:emit(name, body)`.
local function recorder()
  local bus = { seen = {} }
  function bus:emit(name, body)
    self.seen[#self.seen + 1] = { name = name, body = body }
  end
  function bus:last() return self.seen[#self.seen] end
  return bus
end

local function logger()
  local log = { errors = 0 }
  function log:error() self.errors = self.errors + 1 end
  return log
end

-- ---------------------------------------------------------------------
-- The payload itself, off src/formapi.lua alone.
-- ---------------------------------------------------------------------
do
  local Api = loadModule("formapi.lua")
  local bus = recorder()
  Api.bind({ events = bus, log = logger(), gen2 = false })

  T.eq(Api.APPLIED, "mod.battle_forms.form_applied",
    "the applied event's name is a constant this mod owns")
  T.eq(Api.REVERTED, "mod.battle_forms.form_reverted", "and so is the revert's")
  for _, name in ipairs({ Api.APPLIED, Api.REVERTED }) do
    T.eq(name:sub(1, #"mod.battle_forms."), "mod.battle_forms.",
      "both carry the prefix the loader refuses an emit without: " .. name)
  end

  local mon = { species = "CHARIZARD", form = "MEGA_X" }
  local stats = { hp = 78, attack = 130, defense = 111, speed = 100, special = 130 }
  local types = { "FIRE", "DRAGON" }
  T.eq(Api.applied({ mon = mon, form = "MEGA_X", formId = "CHARIZARD_MEGA_X",
                     stats = stats, types = types, isPlayer = true }), true,
    "an applied form is announced")

  local sent = bus:last()
  T.eq(sent.name, Api.APPLIED, "under the applied name")
  T.eq(sent.body.api, 1, "the payload carries its own shape version")
  T.eq(sent.body.event, "applied", "and says which of the two it is")
  T.eq(sent.body.generation, 1, "and which generation's stat keys it holds")
  T.eq(sent.body.mon, mon, "the live Pokemon is handed over by identity")
  T.eq(sent.body.species, "CHARIZARD", "the base species, which never moves")
  T.eq(sent.body.form, "MEGA_X", "the marker a sprite mod resolves art from")
  T.eq(sent.body.formId, "CHARIZARD_MEGA_X", "and the record it all came from")
  T.eq(sent.body.isPlayer, true, "and whose side it is on, where that is known")
  T.eq(sent.body.stats.attack, 130, "the stats the Pokemon is fighting with")
  T.eq(sent.body.types[2], "DRAGON", "and the types it is fighting as")

  -- A listener normalising a payload for its own use must not be able to
  -- rewrite the Pokemon standing on the field.
  T.neq(sent.body.stats, stats, "stats is a copy, not the live table")
  T.neq(sent.body.types, types, "and so is types")
  sent.body.stats.attack = 1
  sent.body.types[2] = "MUD"
  T.eq(stats.attack, 130, "writing through the payload leaves the real stats alone")
  T.eq(types[2], "DRAGON", "and the real types alone")

  Api.reverted({ mon = mon, form = "MEGA_X", stats = { attack = 84 } })
  T.eq(bus:last().name, Api.REVERTED, "a revert is announced under its own name")
  T.eq(bus:last().body.event, "reverted", "and says so in the payload")
  T.eq(bus:last().body.formId, nil,
    "with no record to name -- the Pokemon went back to its own species")

  local before = #bus.seen
  T.eq(Api.applied({ form = "MEGA_X" }), false, "an announcement with no mon is refused")
  T.eq(Api.reverted({}), false, "on either name")
  T.eq(#bus.seen, before, "and nothing is emitted for one")

  -- The stat key set is the running generation's own, never a fixed list:
  -- Gen 1 collapses the two special stats into one and Gen 2 splits them.
  Api.bind({ events = bus, gen2 = true })
  Api.applied({ mon = mon, form = "BLADE",
                stats = { attack = 150, specialAttack = 50, specialDefense = 150 } })
  T.eq(bus:last().body.generation, 2, "a Gen 2 boot says so")
  T.eq(bus:last().body.stats.specialAttack, 50,
    "and the split stat keys reach a listener untouched")
  T.eq(bus:last().body.stats.specialDefense, 150, "both halves of it")

  -- An unbound module is silent rather than broken: src/forms.lua is
  -- dofile()d bare by half a dozen suites that wire nothing at all, and a
  -- primitive that only applied a form correctly once something had been
  -- bound to it would be a worse primitive.
  Api.bind(nil)
  T.eq(Api.applied({ mon = mon, form = "MEGA_X" }), false,
    "an unbound announcement is a silent no-op, not an error")
end

-- ---------------------------------------------------------------------
-- A refused emit is survived, and complained about exactly once.
--
-- The only way the emit below can fail is a name the loader refuses, which
-- is a constant in src/formapi.lua -- so it fails on every single form
-- change or on none, and a line per form change would bury the log of
-- anyone with a form-heavy party.
-- ---------------------------------------------------------------------
do
  local Api = loadModule("formapi.lua")
  local log = logger()
  local angry = {}
  function angry:emit() error("mods may only emit mod.battle_forms.* events", 0) end
  Api.bind({ events = angry, log = log })

  local mon = { species = "CHARIZARD" }
  T.eq(Api.applied({ mon = mon, form = "MEGA_X" }), false,
    "a refused emit answers false rather than throwing into the form change")
  T.eq(log.errors, 1, "and is complained about")
  Api.applied({ mon = mon, form = "MEGA_X" })
  Api.reverted({ mon = mon, form = "MEGA_X" })
  T.eq(log.errors, 1, "exactly once, however many form changes follow")
end

-- ---------------------------------------------------------------------
-- Through the Gen 1 primitive.
-- ---------------------------------------------------------------------
local GEN1_DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" }, name = "CHARIZARD" },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

local function gen1Battler()
  local mon = { species = "CHARIZARD", level = 50,
                dvs = { hp = 15, attack = 15, defense = 15,
                        speed = 15, special = 15 },
                statExp = {} }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  return { mon = mon, curStats = mon.stats,
           curTypes = GEN1_DATA.pokemon.CHARIZARD.types, isPlayer = true }
end

do
  local Forms = loadModule("forms.lua")
  local heard = {}
  Forms.bind({ api = {
    applied = function(fields) heard[#heard + 1] = { "applied", fields } end,
    reverted = function(fields) heard[#heard + 1] = { "reverted", fields } end,
  } })

  local b = gen1Battler()
  T.eq(Forms.becomeForm(GEN1_DATA, b, "CHARIZARD_MEGA_X"), true,
    "the form change itself still succeeds")
  T.eq(#heard, 1, "and announced itself exactly once")
  T.eq(heard[1][1], "applied", "as an application")
  T.eq(heard[1][2].mon, b.mon, "naming the live Pokemon")
  T.eq(heard[1][2].form, "MEGA_X", "the marker written to it")
  T.eq(heard[1][2].formId, "CHARIZARD_MEGA_X", "and the record it came from")
  T.eq(heard[1][2].isPlayer, true, "Gen 1 has a battler, so the side is known")
  -- Fired AFTER the write, which is the ordering a listener depends on: the
  -- announcement carries the mega's Attack, not the base form's.
  T.eq(heard[1][2].stats, b.curStats, "the block named is the battler's own live one")
  T.check(heard[1][2].stats.attack > 100,
    "carrying the FORM's stats -- the announcement is fired after the write, "
      .. "not before it")
  T.eq(heard[1][2].types[2], "DRAGON", "and the form's typing")

  T.eq(Forms.revertForm(b, GEN1_DATA), true, "the revert succeeds")
  T.eq(#heard, 2, "and announced itself once")
  T.eq(heard[2][1], "reverted", "as a revert")
  T.eq(heard[2][2].form, "MEGA_X", "naming the form that came OFF")
  T.eq(heard[2][2].stats, b.mon.stats,
    "and the block the Pokemon is back to -- announced after the restore, so "
      .. "the payload can never describe a battler that no longer exists")
  T.eq(heard[2][2].stats.attack, 84, "the base numbers, not the mega's")
  T.eq(heard[2][2].types[1], "FIRE", "and the base species' own types")

  T.eq(Forms.revertForm(b, GEN1_DATA), nil, "reverting an unmarked mon is a no-op")
  T.eq(#heard, 2, "and says nothing -- the battle-end sweep is blunt on purpose")

  -- The party sweep's own path: no battler at all, so the block named is
  -- the mon's own, which out of battle is exactly what the Pokemon has.
  local swept = gen1Battler()
  Forms.becomeForm(GEN1_DATA, swept, "CHARIZARD_MEGA_X")
  T.eq(Forms.revertMon(swept.mon), true, "the sweep clears a benched mon")
  T.eq(heard[#heard][1], "reverted", "and announces that too")
  T.eq(heard[#heard][2].stats, swept.mon.stats, "naming the mon's own block")
  T.eq(heard[#heard][2].types, nil,
    "with no types claimed -- there is no battler and no dataset in hand here, "
      .. "and an invented answer is worse than an absent one")

  local refused = gen1Battler()
  local before = #heard
  T.eq(Forms.becomeForm(GEN1_DATA, refused, "NOSUCHFORM"), nil,
    "an unknown record still refuses")
  T.eq(#heard, before, "and a refusal announces nothing -- no form was applied")

  -- Unbound: every suite that dofile()s this primitive bare must keep
  -- working, unchanged.
  local Bare = loadModule("forms.lua")
  local bare = gen1Battler()
  T.eq(Bare.becomeForm(GEN1_DATA, bare, "CHARIZARD_MEGA_X"), true,
    "an unwired primitive applies a form exactly as it always did")
  T.eq(bare.mon.form, "MEGA_X", "marker and all")
  T.eq(Bare.revertForm(bare, GEN1_DATA), true, "and reverts one")
end

-- ---------------------------------------------------------------------
-- Through the Gen 2 primitive.
-- ---------------------------------------------------------------------
local GEN2_DATA = { pokemon = {
  AEGISLASH = { baseStats = { hp = 60, attack = 50, defense = 150,
                              speed = 60, specialAttack = 50,
                              specialDefense = 150 },
                types = { "STEEL", "GHOST" } },
  AEGISLASH_BLADE = { baseStats = { hp = 60, attack = 150, defense = 50,
                                    speed = 60, specialAttack = 150,
                                    specialDefense = 50 },
                      types = { "STEEL", "GHOST" }, form = "BLADE" },
} }

do
  local Gen2Forms = loadModule("gen2forms.lua")
  local Mon2 = require("src.battle.gen2.Mon")
  local heard = {}
  Gen2Forms.bind({ api = {
    applied = function(fields) heard[#heard + 1] = { "applied", fields } end,
    reverted = function(fields) heard[#heard + 1] = { "reverted", fields } end,
  } })

  local mon = { species = "AEGISLASH", level = 50, dvs = {}, statExp = {} }
  mon.stats = Mon2.stats(GEN2_DATA.pokemon.AEGISLASH.baseStats, {}, 50, {})
  local shieldAttack = mon.stats.attack

  T.eq(Gen2Forms.becomeForm(GEN2_DATA, mon, "AEGISLASH_BLADE"), true,
    "the Gen 2 form change still succeeds")
  T.eq(#heard, 1, "and announced itself exactly once")
  T.eq(heard[1][2].form, "BLADE", "naming the marker")
  T.eq(heard[1][2].formId, "AEGISLASH_BLADE", "and the record")
  T.eq(heard[1][2].stats, mon.stats,
    "the block named is mon.stats -- Gen 2 has no curStats layer to override "
      .. "instead (src/gen2forms.lua's own header)")
  T.check(heard[1][2].stats.attack > shieldAttack,
    "carrying the FORM's numbers, so the announcement is fired after the write")
  T.eq(heard[1][2].types, mon.formTypes, "and mon.formTypes, the Gen 2 type seam")
  T.eq(heard[1][2].isPlayer, nil,
    "with no side claimed: Gen 2 has no battler wrapper to read one off, and "
      .. "nil is 'not known here' rather than 'the enemy'")

  T.eq(Gen2Forms.revertMon(mon, GEN2_DATA), true, "the revert succeeds")
  T.eq(heard[2][1], "reverted", "and announces itself")
  T.eq(heard[2][2].form, "BLADE", "naming the form that came off")
  T.eq(heard[2][2].stats.attack, shieldAttack, "with the restored numbers")
  T.eq(heard[2][2].types[1], "STEEL",
    "and the species' own types, read back off the record rather than off "
      .. "mon.formTypes, which is nil by now and was the form's anyway")

  Gen2Forms.becomeForm(GEN2_DATA, mon, "AEGISLASH_BLADE")
  T.eq(Gen2Forms.revertMon(mon), true, "a revert with no dataset still succeeds")
  T.eq(heard[#heard][2].types, nil,
    "and claims no types rather than inventing them -- the same degradation "
      .. "the stat restore itself already makes")

  T.eq(Gen2Forms.revertMon(mon, GEN2_DATA), nil, "an unmarked mon is a no-op")
  local quiet = #heard
  Gen2Forms.revertMon(mon, GEN2_DATA)
  T.eq(#heard, quiet, "and announces nothing")

  local Bare = loadModule("gen2forms.lua")
  local bareMon = { species = "AEGISLASH", level = 50, dvs = {}, statExp = {} }
  bareMon.stats = Mon2.stats(GEN2_DATA.pokemon.AEGISLASH.baseStats, {}, 50, {})
  T.eq(Bare.becomeForm(GEN2_DATA, bareMon, "AEGISLASH_BLADE"), true,
    "an unwired Gen 2 primitive applies a form exactly as it always did")
  T.eq(Bare.revertMon(bareMon, GEN2_DATA), true, "and reverts one")
end

-- ---------------------------------------------------------------------
-- describe(), and the exports table a peer actually holds.
-- ---------------------------------------------------------------------
do
  local Api = loadModule("formapi.lua")
  local resolved = nil
  Api.bind({ events = recorder(), gen2 = false,
             formresolve = { formIdFor = function() return resolved end } })

  T.eq(Api.describe(nil), nil, "describing nothing answers nothing")

  local b = gen1Battler()
  b.mon.form = "MEGA_X"
  b.curStats = { hp = 78, attack = 130, defense = 111, speed = 100, special = 130 }
  b.curTypes = { "FIRE", "DRAGON" }
  resolved = "CHARIZARD_MEGA_X"

  local state = Api.describe(b.mon, b)
  T.eq(state.api, 1, "describe answers in the same shape the events carry")
  T.eq(state.event, "state", "saying it is a reading rather than a change")
  T.eq(state.form, "MEGA_X", "with the marker the mon carries")
  T.eq(state.formId, "CHARIZARD_MEGA_X",
    "and the record asked of src/formresolve.lua rather than derived from the "
      .. "marker -- a Pokemon freshly handed an appliance on Gold is entitled "
      .. "to a form while mon.form is still nil")
  T.eq(state.stats.attack, 130, "the battler's own live block, with a battler in hand")
  T.eq(state.types[2], "DRAGON", "and its live types")
  T.eq(state.isPlayer, true, "and its side")

  -- Out of battle -- a party screen, a PC box -- there is no battler, and
  -- the mon's own block is what the Pokemon actually has.
  local outside = Api.describe(b.mon)
  T.eq(outside.stats.attack, 84, "with no battler, the mon's own block answers")
  T.eq(outside.types, nil, "and no battle typing is claimed")
  T.eq(outside.form, "MEGA_X", "the marker is still the mon's own")

  -- A battler holding a DIFFERENT Pokemon is not this Pokemon's battler,
  -- and its stats must not be reported as though it were.
  local other = gen1Battler()
  T.eq(Api.describe(b.mon, other).stats.attack, 84,
    "a battler wrapping another Pokemon is ignored rather than trusted")

  local mod = { exports = {} }
  T.eq(Api.install(mod), true, "the exports table is published")
  T.eq(mod.exports.api, 1, "carrying the API version a consumer checks")
  T.eq(mod.exports.events.applied, Api.APPLIED,
    "and the event names, so a consumer subscribes to a value it was given "
      .. "rather than to a string it retyped")
  T.eq(mod.exports.events.reverted, Api.REVERTED, "both of them")
  T.eq(type(mod.exports.describe), "function", "describe is callable")
  T.eq(type(mod.exports.formIdFor), "function", "and so is formIdFor")
  T.eq(mod.exports.describe(b.mon, b).stats.attack, 130,
    "the export answers exactly what the module does")
  T.eq(mod.exports.formIdFor(b.mon), "CHARIZARD_MEGA_X", "and resolves a record")

  -- Called with a colon, which is an ordinary Lua slip and not worth a nil
  -- error three frames deep inside this mod -- the loader's own api.find
  -- extends the same courtesy.
  T.eq(mod.exports:describe(b.mon, b).stats.attack, 130,
    "a colon call is tolerated on describe")
  T.eq(mod.exports:formIdFor(b.mon), "CHARIZARD_MEGA_X", "and on formIdFor")

  T.eq(Api.install({}), false, "a mod with no exports table is refused, not crashed")
end

-- ---------------------------------------------------------------------
-- Through the real loader, the real national_dex mod and the real Runtime
-- event bus -- the section that proves a real subscriber in a real other
-- mod hears a real form change.
--
-- The loader refuses, with an error rather than a dropped call, any emit
-- from a mod under a name that does not carry its own "mod.<id>." prefix
-- (src/mods/Loader.lua's own `_api`). Nothing in the sections above could
-- catch a wrong prefix, because every one of them hands src/formapi.lua a
-- bus of this file's own making. This one hands it the real one.
--
-- Aegislash is the vehicle for the same reason battle_forms_conditional_
-- test.lua uses it: it is the one form change reachable from a hand-fired
-- battle.move_used with no menu, no item and no bag byte in the way. The
-- filesystem shim below is that suite's, for its own documented reasons --
-- national_dex's NATIONAL DEX option defaults off, and a Pokemon numbered
-- past 251 does not exist at all with it off.
-- ---------------------------------------------------------------------
do
  local FsIo = require("tests.fs_io")
  local inner = FsIo.new(".")
  local OPTIONS_LUA =
    'return { modOptions = { national_dex = { national_dex = "on" } } }'

  local function readFile(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local body = handle:read("*a")
    handle:close()
    return body
  end
  local BF_MAIN = readFile(MOD .. "/main.lua")
  local bfFiles = {
    ["mods/battle_forms_mod/manifest.json"] = readFile(MOD .. "/manifest.json"),
    ["mods/battle_forms_mod/main.lua"] = BF_MAIN,
  }
  for _, tree in ipairs({ "src", "data" }) do
    for name in BF_MAIN:gmatch('"(' .. tree .. '/[%w_]+%.lua)"') do
      local key = "mods/battle_forms_mod/" .. name
      if not bfFiles[key] then
        bfFiles[key] = assert(readFile(MOD .. "/" .. name), name .. " missing")
      end
    end
  end
  -- The new file has to have arrived through main.lua's own file list, not
  -- through a copy this suite made: a module main.lua never names is a
  -- module that never loads in play.
  T.check(bfFiles["mods/battle_forms_mod/src/formapi.lua"] ~= nil,
    "main.lua's own sibling list names src/formapi.lua, which is the only "
      .. "way the file reaches a real load at all")

  local NATIONAL_DEX_DIR = MOD .. "/../national_dex_mod"
  local function mapNationalDex(path)
    if path == nil then return nil end
    local prefix = "mods/national_dex_mod"
    if path == prefix then return NATIONAL_DEX_DIR end
    if path:sub(1, #prefix + 1) == prefix .. "/" then
      return NATIONAL_DEX_DIR .. path:sub(#prefix + 1)
    end
    return nil
  end

  local written = {}
  local fs = {}
  function fs.read(path)
    if path == "options.lua" then return OPTIONS_LUA end
    if written[path] ~= nil then return written[path] end
    if bfFiles[path] ~= nil then return bfFiles[path] end
    local real = mapNationalDex(path)
    if real then return inner.read(real) end
    return nil
  end
  function fs.write(path, body) written[path] = body return true end
  function fs.load(path)
    if path == "options.lua" then return load(OPTIONS_LUA, path) end
    if bfFiles[path] ~= nil then return load(bfFiles[path], "@" .. path) end
    local real = mapNationalDex(path)
    if real then return inner.load(real) end
    return nil, "no file: " .. tostring(path)
  end
  function fs.getInfo(path)
    if path == "mods" or path == "mods/battle_forms_mod" then
      return { type = "directory" }
    end
    if path == "options.lua" then return { type = "file" } end
    if bfFiles[path] ~= nil then return { type = "file" } end
    local real = mapNationalDex(path)
    if real then return inner.getInfo(real) end
    return nil
  end
  function fs.getDirectoryItems(path)
    if path == "mods" then return { "national_dex_mod", "battle_forms_mod" } end
    if path == "mods/battle_forms_mod" then
      local seen, items = {}, {}
      local prefix = "mods/battle_forms_mod/"
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
  end

  local data = T.fixtures.fresh()
  data.gen2Constants = { generation = 2 }

  local run = T.sdk.loadMods({ "national_dex_mod", "battle_forms_mod" },
    { fs = fs, generation = 2, data = data })

  -- A PEER's own subscription: the real bus, the real event name, taken off
  -- the exports the way a consumer is meant to take it rather than retyped.
  local exports = run.loader.exports and run.loader.exports.battle_forms
  T.check(type(exports) == "table",
    "battle_forms publishes an exports table another mod can find")
  T.eq(exports.api, 1, "carrying the API version")
  T.eq(type(exports.describe), "function", "and a describe() to ask with")

  local applied, reverted = {}, {}
  run.loader.events:on(exports.events.applied,
    function(payload) applied[#applied + 1] = payload end, 0, "peer")
  run.loader.events:on(exports.events.reverted,
    function(payload) reverted[#reverted + 1] = payload end, 0, "peer")

  local aegi = run.data.pokemon and run.data.pokemon.AEGISLASH
  T.check(aegi ~= nil, "AEGISLASH registered on this Gen 2 load")

  local Mon2Real = require("src.battle.gen2.Mon")
  local mon = { species = "AEGISLASH", level = 50, dvs = {}, statExp = {},
                hp = 200 }
  mon.stats = Mon2Real.stats(aegi.baseStats, {}, 50, {})
  local shieldAttack = mon.stats.attack

  local engineBattle = { data = run.data, player = mon,
                         enemy = { species = "AEGISLASH", hp = 1,
                                   stats = { hp = 1 } } }
  run.loader.events:emit("battle.started", { battle = engineBattle })
  T.eq(#applied, 0, "precondition: nothing has been announced yet")

  run.loader.events:emit("battle.move_used", { battle = engineBattle,
    user = mon, target = engineBattle.enemy, move = { power = 35, id = "TACKLE" },
    moveId = "TACKLE", side = "player" })

  T.eq(mon.form, "BLADE", "the real form change happened")
  T.eq(#applied, 1,
    "and a subscriber outside this mod heard it -- the assertion that fails "
      .. "if the emit name loses its prefix, if main.lua stops binding "
      .. "src/formapi.lua, or if either primitive stops announcing")
  local said = applied[1]
  T.eq(said.mon, mon, "naming the live Pokemon")
  T.eq(said.species, "AEGISLASH", "its base species, which never moved")
  T.eq(said.form, "BLADE", "the form marker")
  T.eq(said.formId, "AEGISLASH_BLADE", "and the National Dex record behind it")
  T.eq(said.generation, 2, "on the generation this boot really is")
  T.eq(said.stats.attack, mon.stats.attack,
    "carrying the stats the Pokemon is now fighting with")
  T.check(said.stats.attack > shieldAttack, "which are the Blade's, not the Shield's")
  T.same(said.types, mon.formTypes, "and the typing the damage seam reads")

  -- The same reading, asked rather than heard -- a mod that loaded after
  -- this happened, or a screen drawn long after, has no event to have heard.
  local asked = exports.describe(mon)
  T.eq(asked.form, "BLADE", "describe() answers with the same form")
  T.eq(asked.stats.attack, mon.stats.attack, "and the same stats")
  T.eq(asked.event, "state", "marked as a reading rather than a change")

  run.loader.events:emit("battle.move_used", { battle = engineBattle,
    user = mon, target = engineBattle.enemy, move = { power = 0, id = "SWORDSDANCE" },
    moveId = "SWORDSDANCE", side = "player" })

  T.eq(mon.form, nil, "the real revert happened")
  T.eq(#reverted, 1, "and was heard outside this mod too")
  T.eq(reverted[1].form, "BLADE", "naming the form that came off")
  T.eq(reverted[1].stats.attack, shieldAttack, "with the restored stats")

  run.release()
end

-- ---------------------------------------------------------------------
-- main.lua's own wiring, pinned against its source text the way
-- battle_forms_conditional_test.lua pins conditional.bind's diagnostic: the
-- section above proves the whole chain works on Gen 2, and this catches the
-- half of it Gen 2 alone cannot -- src/forms.lua is the GEN 1 primitive,
-- and a load that stopped handing it the API would go on passing every
-- assertion above.
-- ---------------------------------------------------------------------
do
  local handle = assert(io.open(MOD .. "/main.lua", "rb"))
  local mainSrc = handle:read("*a")
  handle:close()

  local bindCall = mainSrc:match("formapi%.bind%(%{.-%}%)")
  T.check(bindCall ~= nil, "main.lua binds src/formapi.lua")
  T.check(bindCall and bindCall:find("events%s*=%s*mod%.events") ~= nil,
    "handing it the real mod event bus -- without which nothing outside this "
      .. "mod can ever hear a form change")
  T.check(bindCall and bindCall:find("formresolve%s*=%s*formresolve") ~= nil,
    "and src/formresolve.lua, which is what describe() answers formId from")
  T.check(mainSrc:find("formapi%.install%(mod%)") ~= nil,
    "and publishes the exports table")
  T.check(mainSrc:find('m%["src/forms%.lua"%]%.bind%(%{%s*api%s*=%s*formapi%s*%}%)')
    ~= nil, "the Gen 1 primitive is handed the API")
  T.check(mainSrc:find("gen2forms%.bind%(%{%s*api%s*=%s*formapi%s*%}%)") ~= nil,
    "and so is the Gen 2 one")
end

T.finish("battle_forms_formapi")
