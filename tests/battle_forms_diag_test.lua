-- The DEBUG TRACE diagnostic: what it says, and what it costs when it is off.
--
-- Two of these checks are worth more than the rest.  The first is that the
-- option off produces literally nothing -- no storage write, no log line --
-- because a diagnostic that costs anything when nobody asked for it is a
-- regression dressed as a feature.  The second is the throttle: every seam
-- this module hangs off runs on every frame, so "one line per state" and "one
-- line per frame" differ by several hundred megabytes an hour.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Logger = require("src.core.Logger")

-- The diagnostic batches its writes and empties them on a timer, so this suite
-- owns the clock: with love's stub reporting no time at all, the timer would
-- never come due and nothing would reach storage to be read back.  A clock
-- that moves on every reading empties the buffer after each line, which is
-- what makes the assertions below able to name the line they are about.
T.love.timer = T.love.timer or {}
local clock = 0
T.love.timer.getTime = function()
  clock = clock + 10
  return clock
end

local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)
local primals = dofile(MOD .. "/data/primals.lua")

local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
  GROUDON = { baseStats = { hp = 100, attack = 150, defense = 140,
                            speed = 90, special = 100 },
              types = { "GROUND" } },
  GROUDON_PRIMAL = { baseStats = { hp = 100, attack = 180, defense = 160,
                                   speed = 90, special = 150 },
                     types = { "GROUND", "FIRE" }, form = "PRIMAL" },
} }

local function newMon(species, held)
  return { species = species, level = 50, [E.STAMP] = held, hp = 100,
           dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
           statExp = {},
           stats = { hp = 100, attack = 100, defense = 100, speed = 100,
                     special = 100 } }
end

-- A recording stand-in for the mod facade: storage collects the batches the
-- real one would write to disk, log collects what would reach the launcher.
local function fakeMod()
  local self = { batches = {}, logged = {}, option = "off" }
  self.game = { id = "test" }
  self.storage = {
    list = function() return {} end,
    delete = function() return true end,
    write = function(_, _, key, value)
      self.batches[#self.batches + 1] = { key = key, lines = value.lines }
      return true
    end,
  }
  local function log(fmt, ...)
    self.logged[#self.logged + 1] = select("#", ...) > 0
      and string.format(fmt, ...) or fmt
  end
  self.log = { info = function(_, ...) log(...) end,
               warn = function(_, ...) log(...) end,
               error = function(_, ...) log(...) end }
  return self
end

-- Every line written so far, in order, flattened out of the batches.
local function linesOf(mod)
  local out = {}
  for _, batch in ipairs(mod.batches) do
    for _, line in ipairs(batch.lines) do out[#out + 1] = line end
  end
  return out
end

local function countMatching(mod, pattern)
  local hits = 0
  for _, line in ipairs(linesOf(mod)) do
    if line:find(pattern, 1, true) then hits = hits + 1 end
  end
  return hits
end

local function firstMatching(mod, pattern)
  for _, line in ipairs(linesOf(mod)) do
    if line:find(pattern, 1, true) then return line end
  end
  return nil
end

-- A whole diagnostic, freshly compiled, wired to a fresh recorder.  dofile
-- rather than one shared module because every throttle in it is module state:
-- two cases sharing an instance would each be testing the other's leftovers.
local function newDiag(mod)
  local Diag = dofile(MOD .. "/src/diag.lua")
  local Overlay = dofile(MOD .. "/src/overlay.lua")
  local Arm = dofile(MOD .. "/src/arm.lua")
  local registry = Transforms.new()
  local registered, why = registry:register(Mega.entry({ eligibility = E,
    megas = megas, keyitems = KeyItems }))
  Overlay.bind({ registry = registry })
  local state = Arm.new()
  Diag.bind({ mod = mod, registry = registry, overlay = Overlay, state = state,
              eligibility = E, megas = megas, keyitems = KeyItems,
              enabled = function() return mod.option == "on" end })
  return { diag = Diag, overlay = Overlay, state = state, registry = registry,
           registered = registered, why = why }
end

local function eligibleBattle()
  local mon = newMon("CHARIZARD", "CHARIZARDITE_X")
  return { phase = "menu", queue = {}, data = DATA, menuIndex = 1,
           player = { mon = mon, isPlayer = true },
           game = { save = { inventory = { [KeyItems.KEY_STONE] = 1 } },
                    input = { wasPressed = function() return false end } } }
end

-- ---------------------------------------------------------------------
-- Off by default, and free.  Everything the diagnostic exposes is driven
-- here with the option off; nothing may be written and nothing logged.
-- ---------------------------------------------------------------------
do
  local mod = fakeMod()
  local kit = newDiag(mod)
  local battle = eligibleBattle()

  T.eq(kit.diag.enabled(), false, "the diagnostic is off unless asked for")

  kit.diag.registry(kit.registry, kit.registered, kit.why)
  kit.diag.record("install: something worth knowing")
  kit.diag.reached("battle.started", { battle = battle })
  kit.state:onBattleStarted({ battle = battle })
  kit.diag.note(battle, "update", "wrapper: BattleState.update ran")
  for _ = 1, 200 do kit.diag.menu(battle) end
  kit.diag.primal("battle.started player", battle, battle.player.mon,
    "GROUDON_PRIMAL", true, nil)
  kit.diag.onBattleEnded()

  T.eq(#mod.batches, 0, "nothing is written to storage while the option is off")
  T.eq(#mod.logged, 0, "and nothing is logged either")
end

-- ---------------------------------------------------------------------
-- A throw is not a diagnostic.  It is reported whether or not the option
-- is on, because the engine catches it and everything the handler had
-- left to do simply did not happen.
-- ---------------------------------------------------------------------
do
  local mod = fakeMod()
  local kit = newDiag(mod)

  kit.diag.fault("primal.onBattleStarted", "something blew up")
  T.eq(#mod.logged, 1, "a throwing handler is reported with the option off")
  T.check(mod.logged[1]:find("primal.onBattleStarted", 1, true) ~= nil,
    "and the report names the handler that threw")
  T.check(mod.logged[1]:find("something blew up", 1, true) ~= nil,
    "and carries the error")

  kit.diag.fault("primal.onBattleStarted", "again")
  T.eq(#mod.logged, 1, "a handler throwing every frame is reported once")
end

-- ---------------------------------------------------------------------
-- Question 2: did mega register?  Held from load time and written out
-- with the first batch that has somewhere to go, because the entry
-- function runs before there is a playthrough to write into.
-- ---------------------------------------------------------------------
do
  local mod = fakeMod()
  local kit = newDiag(mod)
  kit.diag.registry(kit.registry, kit.registered, kit.why)

  T.eq(#mod.batches, 0, "a load-time finding is not written when it is made")

  mod.option = "on"
  kit.diag.onBattleEnded()
  T.check(firstMatching(mod, "registry: 1 registered [mega]") ~= nil,
    "the registry's count and ids reach the log once there is somewhere "
      .. "to put them")

  local refused = Transforms.new()
  local mod2 = fakeMod()
  mod2.option = "on"
  local kit2 = newDiag(mod2)
  kit2.diag.registry(refused, false, "label must be a non-empty string")
  kit2.diag.onBattleEnded()
  T.check(firstMatching(mod2, "registry: 0 registered []") ~= nil,
    "an empty registry says so")
  T.check(firstMatching(mod2, "mega refused: label must be a non-empty string")
    ~= nil, "and carries the refusal reason register handed back")
end

-- ---------------------------------------------------------------------
-- Question 4: why is the cell not offered -- and once per state, never
-- per frame.
-- ---------------------------------------------------------------------
do
  local mod = fakeMod()
  mod.option = "on"
  local kit = newDiag(mod)
  local battle = eligibleBattle()
  kit.state:onBattleStarted({ battle = battle })

  for _ = 1, 500 do kit.diag.menu(battle) end
  T.eq(countMatching(mod, "menu: "), 1,
    "five hundred identical frames produce one line")

  local line = firstMatching(mod, "menu: ")
  T.check(line:find("armState=this battle", 1, true) ~= nil,
    "the line says whose battle the arm state is holding")
  T.check(line:find("phase=menu", 1, true) ~= nil, "and the phase")
  T.check(line:find("queueEmpty=true", 1, true) ~= nil, "and the queue")
  T.check(line:find("species=CHARIZARD", 1, true) ~= nil, "and the species")
  T.check(line:find("stone=CHARIZARDITE_X", 1, true) ~= nil, "and the stamp")
  T.check(line:find("form=CHARIZARD_MEGA_X", 1, true) ~= nil,
    "and the form the stamp resolves to")
  T.check(line:find("record=true", 1, true) ~= nil,
    "and whether that form has a record in the battle's species table")
  T.check(line:find("keys[KEY_STONE=true DYNAMAX_BAND=false TERA_ORB=false]",
      1, true) ~= nil,
    "and which of the trainer's key items are in the bag, which is the one "
      .. "reason for an absent cell that nothing else in this line explains")
  T.check(line:find("used[mega=false]", 1, true) ~= nil,
    "and whether each registered transformation is already spent")
  T.check(line:find("offered=1", 1, true) ~= nil,
    "and how many entries are actually on offer")

  battle.phase = "messages"
  for _ = 1, 50 do kit.diag.menu(battle) end
  T.eq(countMatching(mod, "menu: "), 2, "a change of answer produces one more")
  T.check(firstMatching(mod, "phase=messages") ~= nil,
    "and the new line carries the new answer")

  -- The failure this exists for: the arm state holding no battle at all
  -- means the cell asks about nothing, however healthy the battle is.
  local mod2 = fakeMod()
  mod2.option = "on"
  local kit2 = newDiag(mod2)
  kit2.diag.menu(eligibleBattle())
  local starved = firstMatching(mod2, "menu: ")
  T.check(starved:find("armState=none", 1, true) ~= nil,
    "an arm state that never cached a battle is named as such")
  T.check(starved:find("offered=0", 1, true) ~= nil,
    "and nothing is on offer, which is the cell being absent")
end

-- ---------------------------------------------------------------------
-- Which events are reached at all.  battle.started missing while
-- move_used arrives is the whole answer to a mechanic that never runs.
-- ---------------------------------------------------------------------
do
  local mod = fakeMod()
  mod.option = "on"
  local kit = newDiag(mod)
  local battle = eligibleBattle()

  for _ = 1, 20 do kit.diag.reached("battle.started", { battle = battle }) end
  T.eq(countMatching(mod, "event: battle.started reached"), 1,
    "an event reports the first time it is delivered and not again")
  T.check(firstMatching(mod, "payload battle present") ~= nil,
    "and says whether the payload carried a battle")

  for _ = 1, 20 do kit.diag.reached("battle.move_used", { battle = battle }) end
  T.eq(countMatching(mod, "event: battle.move_used reached"), 1,
    "each event name is throttled on its own")

  kit.diag.reached("battle.turn_ended", {})
  T.check(firstMatching(mod, "battle.turn_ended reached, payload battle MISSING")
    ~= nil, "a payload with no battle on it is called out")

  local second = eligibleBattle()
  kit.diag.reached("battle.started", { battle = second })
  T.eq(countMatching(mod, "event: battle.started reached"), 2,
    "the next battle starts the throttles over")
end

-- ---------------------------------------------------------------------
-- Primal reversion, through the real module: every refusal point says
-- which one it was.
-- ---------------------------------------------------------------------
do
  local mod = fakeMod()
  mod.option = "on"
  local kit = newDiag(mod)
  local Primal = dofile(MOD .. "/src/primal.lua")
  local Forms = dofile(MOD .. "/src/forms.lua")
  Primal.bind({ forms = Forms, eligibility = E, primals = primals,
                diag = kit.diag })

  local mon = newMon("GROUDON", "RED_ORB")
  local battle = { data = DATA, player = { mon = mon, isPlayer = true } }
  Primal.onBattleStarted({ battle = battle })

  T.eq(mon.form, "PRIMAL", "precondition: the reversion actually happened")
  local line = firstMatching(mod, "primal: battle.started player")
  T.check(line ~= nil, "the handler that ran is named")
  T.check(line:find("species=GROUDON", 1, true) ~= nil, "with the species")
  T.check(line:find("stone=RED_ORB", 1, true) ~= nil, "the stamp read off it")
  T.check(line:find("form=GROUDON_PRIMAL", 1, true) ~= nil,
    "the form data/primals.lua resolved")
  T.check(line:find("record=true", 1, true) ~= nil,
    "whether that record exists in the battle's species table")
  T.check(line:find("became=true", 1, true) ~= nil, "and what becomeForm said")

  T.check(firstMatching(mod, "primal: battle.started enemy") ~= nil,
    "the empty enemy side is reported too, so a handler that ran on nobody "
      .. "is not mistaken for one that never ran")

  -- A record the species table has no entry for is the refusal that shipped
  -- silently for a whole release; becomeForm's own reason has to survive.
  local mod2 = fakeMod()
  mod2.option = "on"
  local kit2 = newDiag(mod2)
  local Primal2 = dofile(MOD .. "/src/primal.lua")
  Primal2.bind({ forms = dofile(MOD .. "/src/forms.lua"), eligibility = E,
                 primals = primals, diag = kit2.diag })
  local orphan = newMon("GROUDON", "RED_ORB")
  Primal2.onBattleStarted({ battle = { data = { pokemon = {} },
                                       player = { mon = orphan } } })
  local refusal = firstMatching(mod2, "primal: battle.started player")
  T.check(refusal:find("record=false", 1, true) ~= nil,
    "a missing species record is stated")
  T.check(refusal:find("no_record", 1, true) ~= nil,
    "and becomeForm's own refusal reason comes through")

  -- An ineligible mon is a different answer from a refused one, and the
  -- difference is the whole point of reporting the early returns.
  local mod3 = fakeMod()
  mod3.option = "on"
  local kit3 = newDiag(mod3)
  local Primal3 = dofile(MOD .. "/src/primal.lua")
  Primal3.bind({ forms = dofile(MOD .. "/src/forms.lua"), eligibility = E,
                 primals = primals, diag = kit3.diag })
  Primal3.onBattleStarted({ battle = { data = DATA,
    player = { mon = newMon("GROUDON", nil) } } })
  T.check(firstMatching(mod3, "no pairing in data/primals.lua") ~= nil,
    "an unstamped mon is reported as having no pairing, not as a refusal")

  -- Repeated switch-ins of the same mon answering the same way are one
  -- finding, not one line per switch.
  local mod4 = fakeMod()
  mod4.option = "on"
  local kit4 = newDiag(mod4)
  local Primal4 = dofile(MOD .. "/src/primal.lua")
  Primal4.bind({ forms = dofile(MOD .. "/src/forms.lua"), eligibility = E,
                 primals = primals, diag = kit4.diag })
  local switcher = newMon("GROUDON", "RED_ORB")
  local switchBattle = { data = DATA }
  for _ = 1, 10 do
    Primal4.onBattlerSwitched({ battle = switchBattle,
      battler = { mon = switcher, isPlayer = true } })
  end
  T.eq(countMatching(mod4, "primal: battler_switched"), 1,
    "ten switch-ins answering the same way produce one line")
end

-- ---------------------------------------------------------------------
-- Question 1 and question 3, through src/menu.lua's real install: what
-- was wrapped, and whether the wrappers are the functions the engine
-- calls.  The engine classes are stubbed into package.loaded so nothing
-- here patches the real ones.
-- ---------------------------------------------------------------------
local savedLoaded = {}
for _, name in ipairs({ "src.battle.BattleState", "src.battle.WideBattle",
                        "src.render.Font", "src.core.Sound" }) do
  savedLoaded[name] = package.loaded[name]
end

local function stubEngine(withWide)
  local BattleState = { update = function() end,
                        drawTextArea = function() end,
                        tickFx = function() end }
  package.loaded["src.battle.BattleState"] = BattleState
  package.loaded["src.render.Font"] = { draw = function() end,
                                        drawCode = function() end }
  package.loaded["src.core.Sound"] = { play = function() end }
  local WideBattle = withWide and { draw = function() end } or nil
  package.loaded["src.battle.WideBattle"] = WideBattle
  return BattleState, WideBattle
end

do
  local mod = fakeMod()
  mod.option = "on"
  local kit = newDiag(mod)
  local Menu = dofile(MOD .. "/src/menu.lua")
  Menu.bind({ overlay = kit.overlay, diag = kit.diag })
  local BattleState, WideBattle = stubEngine(true)

  T.eq(Menu.install(mod, kit.state), true, "precondition: install succeeds")
  kit.diag.onBattleEnded()

  T.check(firstMatching(mod, "install: BattleState resolved, no earlier patch")
    ~= nil, "install says the guard was clear when it ran")
  T.check(firstMatching(mod, "install: Font resolved") ~= nil,
    "and whether the font the cell prints through resolved")
  T.check(firstMatching(mod,
    "install: wrapped BattleState.update and BattleState.drawTextArea") ~= nil,
    "and which functions it wrapped")
  T.check(firstMatching(mod, "install: WideBattle.draw wrapped") ~= nil,
    "and that the widescreen draw path was wrapped too")

  -- Question 3: the wrappers are what the engine calls, said once.
  local battle = eligibleBattle()
  kit.state:onBattleStarted({ battle = battle })
  for _ = 1, 100 do BattleState.update(battle, 0) end
  T.eq(countMatching(mod, "wrapper: BattleState.update ran"), 1,
    "a hundred frames of the patched update produce one note")

  for _ = 1, 100 do BattleState.drawTextArea(battle) end
  T.eq(countMatching(mod, "wrapper: BattleState.drawTextArea ran"), 1,
    "and a hundred draws produce one more")

  for _ = 1, 100 do WideBattle.draw(battle) end
  T.eq(countMatching(mod, "wrapper: WideBattle.draw ran"), 1,
    "and the widescreen path reports separately, since a cell can be "
      .. "missing in one layout and present in the other")

  T.check(countMatching(mod, "menu: ") >= 1,
    "the patched update is also where the cell's decision is read")
end

do
  -- The install that finds the guard already set is the one that has to say
  -- so: it wraps nothing, and the wrappers already in place answer to an
  -- arm state this load will never update.
  local mod = fakeMod()
  mod.option = "on"
  local kit = newDiag(mod)
  local Menu = dofile(MOD .. "/src/menu.lua")
  Menu.bind({ overlay = kit.overlay, diag = kit.diag })
  local BattleState = stubEngine(true)
  BattleState._battleFormsMenuPatched = true

  T.eq(Menu.install(mod, kit.state), true,
    "a second install still reports success, as it always has")
  kit.diag.onBattleEnded()
  T.check(firstMatching(mod, "install: BattleState was already patched") ~= nil,
    "but says out loud that it wrapped nothing")
  T.check(firstMatching(mod, "close over an earlier load's arm state") ~= nil,
    "and why that is the cell's problem and not a harmless duplicate")
end

do
  -- Widescreen missing is survivable and separately reported: the classic
  -- layout keeps its cell and only the wide one loses it.
  local mod = fakeMod()
  mod.option = "on"
  local kit = newDiag(mod)
  local Menu = dofile(MOD .. "/src/menu.lua")
  Menu.bind({ overlay = kit.overlay, diag = kit.diag })
  stubEngine(false)
  package.loaded["src.battle.WideBattle"] = { draw = "not a function" }

  T.eq(Menu.install(mod, kit.state), true, "install carries on without it")
  kit.diag.onBattleEnded()
  T.check(firstMatching(mod, "install: WideBattle.draw has no draw function")
    ~= nil, "and names what was wrong with it")
end

for name, value in pairs(savedLoaded) do package.loaded[name] = value end
package.loaded["src.battle.WideBattle"] = savedLoaded["src.battle.WideBattle"]

-- ---------------------------------------------------------------------
-- The wiring change this shipped with: Events:emit pcalls the LISTENER,
-- so three handlers in one listener used to mean the first to throw
-- cancelled the two behind it.  Driven through the real loader and the
-- real event bus, because the guard being in the right place is the
-- whole claim and main.lua is where it lives.
-- ---------------------------------------------------------------------
do
  local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local body = handle:read("*a")
    handle:close()
    return body
  end

  local MAIN = readFile(MOD .. "/main.lua")
  local files = {
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = "return function() end",
    ["mods/battle_forms_mod/manifest.json"] = readFile(MOD .. "/manifest.json"),
    ["mods/battle_forms_mod/main.lua"] = MAIN,
  }
  for _, tree in ipairs({ "src", "data" }) do
    for name in MAIN:gmatch('"(' .. tree .. '/[%w_]+%.lua)"') do
      files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
    end
  end

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
    fs = T.sdk.memfs(files), data = T.fixtures.fresh() })
  T.eq(#run.errors, 0, "the mod loads clean with the diagnostic in it")

  -- resolve.onBattlerSwitched runs before primal's on the same event and is
  -- made to throw on its first read of mon.form; primal must still revert
  -- the Groudon behind it.
  local reads = 0
  local mon = setmetatable(newMon("GROUDON", "RED_ORB"), {
    __index = function(_, key)
      if key ~= "form" then return nil end
      reads = reads + 1
      if reads == 1 then error("deliberate throw from the first handler") end
      return nil
    end })
  local battler = { mon = mon, isPlayer = true, curStats = mon.stats,
                    curTypes = DATA.pokemon.GROUDON.types }

  local before = #Logger.history
  run.loader.events:emit("battle.battler_switched",
    { battle = { data = DATA }, battler = battler })

  T.eq(mon.form, "PRIMAL",
    "a handler throwing no longer cancels the handlers behind it in the "
      .. "same listener")

  local said = false
  for i = before + 1, #Logger.history do
    if Logger.history[i]:find("resolve.onBattlerSwitched", 1, true) then
      said = true
    end
  end
  T.check(said, "and the throw is reported by name rather than swallowed")

  run.release()
end

T.finish("battle_forms_diag")
