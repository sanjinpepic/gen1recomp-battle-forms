-- Gen 2's equivalent of battle_forms_menu_test.lua and (its real-loader
-- block) battle_forms_formmenu_test.lua: the battle menu cell on Gold.
--
-- What can be proven without love2d is the input decision (src/gen2menu.lua's
-- handleInput), never the draw half -- the identical split
-- battle_forms_menu_test.lua's own header states, for the identical reason:
-- src/gen2menu.lua's own M.draw only calls Chrome (which is love.graphics
-- underneath).
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Gen2Menu = dofile(MOD .. "/src/gen2menu.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Formmenu = dofile(MOD .. "/src/formmenu.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local function makeInput(pressed)
  return { wasPressed = function(_, btn) return (pressed or {})[btn] == true end }
end

local function eligibleMon()
  return { species = "CHARIZARD", item = "CHARIZARDITE_X", hp = 100,
           dvs = {}, statExp = {}, level = 50 }
end

local hasRecord = { pokemon = { CHARIZARD_MEGA_X = {} } }

-- The trainer's Key Stone, read on Gen 2 off `battle.save` directly --
-- src/keyitems.lua's own header on why -- rather than `battle.game.save` the
-- way every Gen 1 fixture in this mod supplies it.
local function bag()
  return { inventory = { [KeyItems.KEY_STONE] = 1 } }
end

-- The two objects Gen 2 splits where Gen 1 keeps one: `engineBattle`
-- (game/src/battle/gen2/Battle.lua's own shape -- `.player`, `.data`,
-- `.save`, no `.phase`) is what src/arm.lua caches from battle.started and
-- what every registry entry's own `available`/`activate` reads; `uiBattle`
-- (game/src/ui/gen2/BattleState.lua's own shape -- `.phase`, `.menuIndex`,
-- `.queue`, `.game`, `.battle` pointing at the engine object) is what
-- src/gen2menu.lua's wrapped `update` is handed as `self` every frame.
local function makeBattle(menuIndex, pressed, opts)
  opts = opts or {}
  local engineBattle = opts.engineBattle or {
    data = hasRecord, save = bag(), player = eligibleMon(),
  }
  local uiBattle = {
    phase = "menu", menuIndex = menuIndex, queue = {},
    battle = engineBattle, contest = opts.contest, tutorial = opts.tutorial,
    game = { input = makeInput(pressed) },
  }
  return uiBattle, engineBattle
end

local function bindMega()
  local registry = Transforms.new()
  registry:register(Mega.entry({ eligibility = E, megas = megas,
    keyitems = KeyItems, battlerof = Battlerof, gen2 = true,
    gen2forms = Gen2Forms }))
  Overlay.bind({ registry = registry })
  Formmenu.bind({ overlay = Overlay })
  Gen2Menu.bind({ overlay = Overlay, formmenu = Formmenu })
end

-- ---------------------------------------------------------------------
-- No eligible mon: exactly vanilla, at every real index and direction.
-- ---------------------------------------------------------------------
do
  bindMega()
  local state = Arm.new()
  local uiBattle, engineBattle = makeBattle(1, { left = true },
    { engineBattle = { data = hasRecord, save = bag(),
                        player = { species = "PIDGEY", hp = 100 } } })
  state:onBattleStarted({ battle = engineBattle })

  T.eq(Overlay.shouldOffer(state, uiBattle), false,
    "precondition: an ineligible mon offers nothing")
  T.eq(Gen2Menu.handleInput(uiBattle, state), false,
    "an ineligible mon's menu is never claimed")
  T.eq(uiBattle.menuIndex, 1, "menuIndex is untouched")
  T.eq(Gen2Menu.isOnCell(uiBattle), false, "the cursor never leaves the real grid")

  for _, idx in ipairs({ 1, 2, 3, 4 }) do
    for _, dir in ipairs({ "left", "right", "up", "down", "a" }) do
      uiBattle.menuIndex = idx
      uiBattle.game.input = makeInput({ [dir] = true })
      T.eq(Gen2Menu.handleInput(uiBattle, state), false,
        ("index %d + %s stays vanilla when nothing is offered"):format(idx, dir))
    end
  end
end

-- ---------------------------------------------------------------------
-- Eligible: FIGHT (1) and PACK (3) are column 0 and reach the cell; <PK><MN>
-- (2) and RUN (4) do not.  MENU_ACTION's own row-major fill
-- (BattleState.lua:127-131) is what makes odd indices column 0, the same
-- shape src/gen2menu.lua's own `column()` reads.
-- ---------------------------------------------------------------------
do
  bindMega()
  local state = Arm.new()
  local uiBattle, engineBattle = makeBattle(1, {})
  state:onBattleStarted({ battle = engineBattle })
  T.eq(Overlay.shouldOffer(state, uiBattle), true,
    "precondition: an eligible mon offers the cell")
  T.eq(Overlay.label(state, uiBattle), "FORM",
    "precondition: the generic label, unarmed")

  uiBattle.game.input = makeInput({ left = true })
  T.eq(Gen2Menu.handleInput(uiBattle, state), true, "left at FIGHT (column 0) is claimed")
  T.eq(Gen2Menu.isOnCell(uiBattle), true, "the cursor is now on the cell")
  T.eq(uiBattle.menuIndex, 1, "the real index is left exactly where it was")

  uiBattle.game.input = makeInput({ right = true })
  T.eq(Gen2Menu.handleInput(uiBattle, state), true, "right off the cell is claimed")
  T.eq(Gen2Menu.isOnCell(uiBattle), false, "the cursor is back on the real grid")

  uiBattle.menuIndex = 3 -- PACK, also column 0
  uiBattle.game.input = makeInput({ left = true })
  Gen2Menu.handleInput(uiBattle, state)
  T.eq(Gen2Menu.isOnCell(uiBattle), true, "left from PACK also reaches the cell")
  uiBattle.game.input = makeInput({ up = true })
  Gen2Menu.handleInput(uiBattle, state)
  T.eq(Gen2Menu.isOnCell(uiBattle), false, "up off the cell leaves it too")
  T.eq(uiBattle.menuIndex, 3, "back on PACK, unchanged")

  uiBattle.menuIndex = 2 -- <PK><MN>, column 1
  uiBattle.game.input = makeInput({ left = true })
  T.eq(Gen2Menu.handleInput(uiBattle, state), false,
    "left from <PK><MN> moves within the real grid, not onto the cell")
  T.eq(Gen2Menu.isOnCell(uiBattle), false, "<PK><MN> cannot reach the cell directly")
end

-- ---------------------------------------------------------------------
-- A on the cell opens the submenu, confirming the one row arms mega --
-- through the real src/arm.lua toggle, not a hand-called shortcut.
-- ---------------------------------------------------------------------
do
  bindMega()
  local state = Arm.new()
  local uiBattle, engineBattle = makeBattle(1, {})
  state:onBattleStarted({ battle = engineBattle })
  uiBattle.game.input = makeInput({ left = true })
  Gen2Menu.handleInput(uiBattle, state)
  T.eq(Gen2Menu.isOnCell(uiBattle), true, "precondition: cursor parked on the cell")
  T.eq(state:isArmed(), false, "starts disarmed")

  uiBattle.game.input = makeInput({ a = true })
  local opened, openAction = Gen2Menu.handleInput(uiBattle, state)
  T.eq(opened, true, "A on the cell is claimed")
  T.eq(openAction, "open", "and reports the submenu just opened")
  T.eq(Formmenu.isOpen(uiBattle), true, "which is the real, shared list module")

  uiBattle.game.input = makeInput({ a = true })
  local handled, action = Gen2Menu.handleInput(uiBattle, state)
  T.eq(handled, true, "A on the one row is claimed")
  T.eq(action, "toggle", "the wrapper is told this frame armed or disarmed it")
  T.eq(state:isArmed(), true, "A arms the toggle")
  T.eq(Formmenu.isOpen(uiBattle), false, "and the list closes behind it")
  T.eq(uiBattle.phase, "menu", "the phase is untouched -- no turn was taken")

  uiBattle.game.input = makeInput({ a = true })
  Gen2Menu.handleInput(uiBattle, state)
  uiBattle.game.input = makeInput({ a = true })
  Gen2Menu.handleInput(uiBattle, state)
  T.eq(state:isArmed(), false, "a second A disarms it")
end

-- ---------------------------------------------------------------------
-- Guards: a fainted mon, a contest battle and a tutorial battle never claim
-- the frame -- BATTLETYPE_CONTEST and BATTLETYPE_TUTORIAL are refused
-- outright (src/gen2menu.lua's own header on why), and there is no Gen 2
-- equivalent of Gen 1's menuLockedAction/drainHold checks to carry over
-- because a locked or forced-replacement frame is a DIFFERENT phase value
-- on Gold, never "menu".
-- ---------------------------------------------------------------------
do
  bindMega()
  local state = Arm.new()
  local uiBattle, engineBattle = makeBattle(1, { left = true })
  engineBattle.player.hp = 0
  state:onBattleStarted({ battle = engineBattle })
  T.eq(Gen2Menu.handleInput(uiBattle, state), false, "a fainted mon's menu is never claimed")

  local state2 = Arm.new()
  local uiBattle2, engineBattle2 = makeBattle(1, { left = true }, { contest = true })
  state2:onBattleStarted({ battle = engineBattle2 })
  T.eq(Gen2Menu.handleInput(uiBattle2, state2), false,
    "a contest battle's menu is never claimed")

  local state3 = Arm.new()
  local uiBattle3, engineBattle3 = makeBattle(1, { left = true }, { tutorial = true })
  state3:onBattleStarted({ battle = engineBattle3 })
  T.eq(Gen2Menu.handleInput(uiBattle3, state3), false,
    "a tutorial battle's menu is never claimed")
end

-- ---------------------------------------------------------------------
-- The cell vanishing while the cursor is standing on it -- the identical
-- scenario battle_forms_menu_test.lua pins for Gen 1, parked from PACK
-- rather than FIGHT so a cursor returning to the wrong place would be caught.
-- ---------------------------------------------------------------------
do
  bindMega()
  local state = Arm.new()
  local uiBattle, engineBattle = makeBattle(3, {})
  state:onBattleStarted({ battle = engineBattle })
  uiBattle.game.input = makeInput({ left = true })
  Gen2Menu.handleInput(uiBattle, state)
  T.eq(Gen2Menu.isOnCell(uiBattle), true, "precondition: the cursor is parked on the cell")

  state:consume(Mega.ID)
  T.eq(Overlay.shouldOffer(state, uiBattle), false, "the cell empties under the cursor")

  uiBattle.game.input = makeInput({})
  T.eq(Gen2Menu.handleInput(uiBattle, state), false,
    "the very next frame goes straight back to vanilla")
  T.eq(Gen2Menu.isOnCell(uiBattle), false, "with the cursor off the cell that is gone")
  T.eq(uiBattle.menuIndex, 3, "and back on PACK, the real cell it left from")
end

-- ---------------------------------------------------------------------
-- Geometry: the cell's own row/column, and src/formmenu.lua's GEN2_BOX --
-- both numerically Gen 1's CLASSIC layout divided by 8 (pixels -> tiles),
-- because Gold's non-contest command box sits at the identical screen
-- position.  Pinned so a future edit that drifts one from the other is
-- caught here rather than only in a screenshot.
-- ---------------------------------------------------------------------
do
  T.eq(Gen2Menu.CELL.cursor, 9, "the cursor tile sits one left of FIGHT's own column")
  T.eq(Gen2Menu.CELL.label, 10, "the label tile is FIGHT's own column")
  T.eq(Gen2Menu.CELL.row, 15, "the row is the blank spacer between the two menu rows")

  local box = Formmenu.GEN2_BOX
  T.eq(box.box.x, 2, "the list box left edge")
  T.eq(box.box.y, 10, "two rows above the vanilla command box")
  T.eq(box.box.w, 16, "the list box width")
  T.eq(box.box.h, 8, "eight rows tall -- six interior plus the border")
  T.eq(box.cursor, 3, "cursor column, one in from the box border")
  T.eq(box.label, 4, "label column, two in from the box border")
  T.eq(box.rowY0, 11, "first interior row")
  T.eq(box.maxRows, 6, "headroom for a sixth registration")
end

-- ---------------------------------------------------------------------
-- src/keyitems.lua's own Gen 2 read: `battle.save` answers when there is no
-- `battle.game` to hold one, and `battle.game.save` still wins when both are
-- present -- Gen 1 is never asked to fall back to anything.
-- ---------------------------------------------------------------------
do
  T.eq(KeyItems.held({ save = bag() }, KeyItems.KEY_STONE), true,
    "battle.save alone (Gen 2's own engine Battle shape) is read")
  T.eq(KeyItems.held({ save = { inventory = {} } }, KeyItems.KEY_STONE), false,
    "an empty battle.save.inventory holds nothing")
  T.eq(KeyItems.held({ game = { save = bag() } }, KeyItems.KEY_STONE), true,
    "battle.game.save (Gen 1's own shape) still works unchanged")
  T.eq(KeyItems.held({ game = { save = bag() }, save = { inventory = {} } },
    KeyItems.KEY_STONE), true,
    "battle.game.save wins when both are present")
end

-- ---------------------------------------------------------------------
-- src/mega.lua's own Gen 2 branch, direct: the real held item (mon.item)
-- decides, not the Gen 1 bag stamp, and src/gen2forms.lua is the primitive
-- that actually applies it.
-- ---------------------------------------------------------------------
do
  local entry = Mega.entry({ eligibility = E, megas = megas, keyitems = KeyItems,
    battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms })

  local dataWithForm = { pokemon = {
    CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                                 specialAttack = 85, specialDefense = 85 },
                  types = { "FIRE", "FLYING" } },
    CHARIZARD_MEGA_X = { form = "MEGA_X",
      baseStats = { hp = 78, attack = 130, defense = 111, speed = 100,
                    specialAttack = 130, specialDefense = 85 },
      types = { "FIRE", "DRAGON" } },
  } }

  local mon = { species = "CHARIZARD", item = "CHARIZARDITE_X", hp = 100,
                dvs = {}, statExp = {}, level = 50 }
  local battle = { data = dataWithForm, save = bag(), player = mon }

  T.eq(entry.available(battle), true,
    "held CHARIZARDITE_X, Key Stone in the bag, real record: available")

  mon.item = nil
  T.eq(entry.available(battle), false, "no held item: unavailable")

  mon.item = "LEFTOVERS"
  T.eq(entry.available(battle), false, "a held item this table names nothing for: unavailable")

  mon.item = "CHARIZARDITE_X"
  battle.save = { inventory = {} }
  T.eq(entry.available(battle), false, "no Key Stone in the bag: unavailable")

  battle.save = bag()
  T.eq(entry.available(battle), true, "precondition restored: available again")

  local ok = entry.activate(battle)
  T.eq(ok, true, "activation succeeds")
  T.eq(mon.form, "MEGA_X", "the mon is marked with the real form suffix")
  -- The real Gen 2 stat formula, not the raw baseStats numbers -- level 50,
  -- zero DVs/EVs: floor((base*2)*50/100)+5, src/battle/gen2/Mon.lua's own
  -- statValue.
  T.eq(mon.stats.attack, 135, "and its stats are computed from the mega's own base")
  T.eq(mon.stats.defense, 116, "every stat, not just one")

  -- A held item naming no record at all (a wrong id in data/megas.lua, or
  -- national_dex data that never loaded) refuses rather than half-applying.
  local mon2 = { species = "CHARIZARD", item = "CHARIZARDITE_Y", hp = 100,
                 dvs = {}, statExp = {}, level = 50 }
  local battle2 = { data = { pokemon = {} }, save = bag(), player = mon2 }
  T.eq(entry.available(battle2), false,
    "a form the species table has no record for is never offered")
end

-- ---------------------------------------------------------------------
-- Through the real loader: main.lua's own wiring, exactly the shape
-- battle_forms_formmenu_test.lua uses for Gen 1 -- the assertion an
-- unwired Gen 2 cell (main.lua never binding src/gen2menu.lua, or that
-- module never calling src/gen2menu.lua's own install) would fail.  Also
-- proves the feature is REACHABLE on a real Gold save, not merely working
-- in isolation: the Key Stone and the mega stone both have to actually be
-- for sale, or a mega with correct code behind it is still content nobody
-- can reach (HANDOFF's own standing worry about this mod's other features).
-- ---------------------------------------------------------------------
do
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

  local files = {
    -- The stub declares both generations, unlike battle_forms_formmenu_test.lua's
    -- Gen-1-only one: a dependency with no `games` field defaults to Gen 1 alone
    -- (src/mods/ModTargets.lua's own `legacy()`), which would skip it -- and
    -- battle_forms with it -- on a Gen 2 load.
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0",'
        .. '"entry":"main.lua","games":["gen1","gen2"]}',
    ["mods/national_dex/main.lua"] = "return function() end",
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end

  local data = T.fixtures.fresh()
  -- generationOf(mod) reads mod.content.constants:get("generation"), routed
  -- to data.gen2Constants on a Gen 2 boot (Schemas.lua's own
  -- `constants = "gen2Constants"`) -- the test SDK's own `opts.generation`
  -- drives the LOADER's routing and gating but does not itself populate this
  -- field, so it is seeded by hand the same way a real Gold boot's own
  -- Game2.lua does at load (`self.data.gen2Constants = loadGenerated(...)`).
  data.gen2Constants = { generation = 2 }

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" },
    { fs = T.sdk.memfs(files), data = data, generation = 2 })
  -- Every error here, and there can be hundreds, is one of two pre-existing
  -- gaps HANDOFF.md already documents, neither of them this pass's doing:
  --
  --   * "moves.<id>.effect: unresolved reference to move_effects
  --     'NO_ADDITIONAL_EFFECT'" -- the Gen 2 reference gate HANDOFF.md
  --     calls "still unfixed upstream".  Gen 2's own move_effects
  --     registrant (src/mods/Builtins.lua's `move_effects = { from =
  --     "src.battle.gen2.Battle", ... }`) never registers Gen 1's
  --     NO_ADDITIONAL_EFFECT id, and every move this mod's Max Moves,
  --     Z-Moves, Tera Blast and G-Max Move catalogs register carries that
  --     effect, unconditionally, on both generations, because none of
  --     those catalogs are gated on `gen2`.
  --   * "the text_pointers registry has no Gen 2 target" -- src/shop.lua's
  --     Gen 1 shelves patch `text_pointers`, one of the six registries
  --     Schemas.lua marks as having no Gen 2 home at all (src/gen2shop.lua's
  --     own header on why it wraps MartMenu.inventory instead), and
  --     src/shop.lua's own installs run unconditionally too.
  --
  -- Both are non-fatal -- the load still completes, the cell still
  -- installs, the shop still stocks, every check below still passes -- and
  -- both are out of this task's scope to fix: closing either would mean
  -- widening OTHER mechanics' own Gen 2 support, work this pass does not
  -- touch.  What this assertion pins down is narrower and squarely in
  -- scope -- that nothing about THIS pass's own wiring (src/gen2menu.lua,
  -- src/mega.lua's Gen 2 branch) added a new class of error alongside the
  -- two known ones.
  for _, err in ipairs(run.errors) do
    T.check(err:find("unresolved reference to move_effects", 1, true) ~= nil
      or err:find("text_pointers registry has no Gen 2 target", 1, true) ~= nil,
      "every load error is one of the two known gaps, not a new one: " .. err)
  end

  local BattleState = require("src.ui.gen2.BattleState")
  T.check(BattleState._battleFormsGen2MenuPatched == true,
    "the real Gen 2 BattleState.update was actually wrapped by this load")

  run.data.pokemon = run.data.pokemon or {}
  run.data.pokemon.CHARIZARD = {
    baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                  specialAttack = 85, specialDefense = 85 },
    types = { "FIRE", "FLYING" } }
  run.data.pokemon.CHARIZARD_MEGA_X = {
    baseStats = { hp = 78, attack = 130, defense = 111, speed = 100,
                  specialAttack = 130, specialDefense = 85 },
    types = { "FIRE", "DRAGON" }, form = "MEGA_X" }

  local mon = { species = "CHARIZARD", level = 50, dvs = {}, statExp = {},
                hp = 100, item = "CHARIZARDITE_X" }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100,
                specialAttack = 85, specialDefense = 85 }
  -- The engine battle (game/src/battle/gen2/Battle.lua's own shape) --
  -- `.player` IS the mon, `.save` is what src/keyitems.lua's own Gen 2 read
  -- reaches.
  local engineBattle = { data = run.data,
                          save = { inventory = { [KeyItems.KEY_STONE] = 1 } },
                          player = mon }
  -- The UI screen every frame actually runs through.
  local uiBattle = { phase = "menu", menuIndex = 1, queue = {},
                     battle = engineBattle, game = { input = nil } }

  run.loader.events:emit("battle.started", { battle = engineBattle })

  local function press(button)
    uiBattle.game.input = { wasPressed = function(_, btn) return btn == button end }
    return BattleState.update(uiBattle, 0)
  end

  press("left")
  T.check(uiBattle._battleFormsMenuCell == true,
    "left from FIGHT reached the real cell through the real wrapped update")

  T.check(uiBattle._battleFormsListOpen ~= true, "precondition: the list has not opened")
  press("a")
  T.check(uiBattle._battleFormsListOpen == true,
    "A on the cell opened the real submenu -- the assertion an unwired list "
      .. "(main.lua never binding src/gen2menu.lua, or that module reverting "
      .. "to arming directly) would fail")

  press("a")
  T.check(uiBattle._battleFormsListOpen == false, "confirming the one row closed the real list")
  T.eq(mon.form, nil, "arming alone does not change the form yet -- that is turn start's job")

  run.loader.events:emit("battle.turn_started", { battle = engineBattle })
  T.eq(mon.form, "MEGA_X",
    "and turn start ran the real mega evolution the real submenu armed -- proof "
      .. "the confirm inside the real list dispatched a real arm, through the "
      .. "real src/mega.lua Gen 2 branch, not just a UI-only field flip")
  T.eq(mon.stats.attack, 135, "and the real Gen 2 primitive actually rewrote mon.stats")

  -- Reachability: both items this mechanic needs actually have to be for
  -- sale on a fresh Gold save, or none of the above is reachable outside a
  -- test fixture that hands a Pokemon its item directly.
  local MartMenu = require("src.ui.gen2.MartMenu")
  local INDIGO_PLATEAU_MART_ID = 32
  local indigoShelf = MartMenu.inventory({ lists = {} }, INDIGO_PLATEAU_MART_ID)
  local function has(list, id)
    for _, entry in ipairs(list) do if entry == id then return true end end
    return false
  end
  T.check(has(indigoShelf, "KEY_STONE"),
    "the Key Stone is sold at the Indigo Plateau counter on Gold")
  T.check(has(indigoShelf, "CHARIZARDITE_X") or has(indigoShelf, "CHARIZARDITE_Y"),
    "at least one active mega stone is sold there too")

  run.release()
end

T.finish("battle_forms_gen2menu")
