-- The submenu src/menu.lua's cell opens: what row the list starts on, how
-- navigating it does and does not touch arm state, and -- because opening a
-- list on top of a cell that used to arm directly is exactly the kind of
-- change that can look right in isolation and be unreachable in play -- that
-- main.lua actually wires it in, proven through the real, load-patched
-- engine class rather than through a hand-built stand-in.
--
-- What can be proven without love2d is the input decision, never the two
-- draw functions -- src/menu.lua's own suite states the same line, and the
-- same reason applies here.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Formmenu = dofile(MOD .. "/src/formmenu.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")

local function makeInput(pressed)
  return { wasPressed = function(_, btn) return (pressed or {})[btn] == true end }
end

-- ---------------------------------------------------------------------
-- Geometry: plain data, pinned the same way src/menu.lua's own CELL table
-- is.  Both boxes hold at least the five entries src/transforms.lua's own
-- registry ceiling names (MEGA, DYNAMAX, TERA, Z-MOVE, BURST) with a spare
-- row apiece, and both fully cover the vanilla command box they draw over.
-- ---------------------------------------------------------------------
do
  T.eq(Formmenu.BOX.classic.maxRows >= 5, true, "classic holds every shipping entry")
  T.eq(Formmenu.BOX.wide.maxRows >= 5, true, "and so does widescreen")
  T.eq(Formmenu.BOX.classic.box.y + Formmenu.BOX.classic.box.h, 18,
    "the classic box reaches the screen's own last row (18 tiles, 0-17), "
      .. "fully covering the vanilla command box (rows 12-17) it draws over")
  T.eq(Formmenu.BOX.wide.box.y + Formmenu.BOX.wide.box.h, 18,
    "and so does widescreen's, over WideBattle's own command box (rows 13-17)")
  T.eq(Formmenu.BOX.classic.cursor < Formmenu.BOX.classic.label, true,
    "the cursor column sits left of the label, the same order FIGHT's own move list uses")
  T.eq(Formmenu.BOX.wide.cursor < Formmenu.BOX.wide.label, true, "and widescreen's too")
end

-- ---------------------------------------------------------------------
-- isOpen/close on a bare battle: no crash on a battle with nothing set,
-- and close is idempotent.
-- ---------------------------------------------------------------------
do
  T.eq(Formmenu.isOpen(nil), false, "no battle at all is never open")
  T.eq(Formmenu.isOpen({}), false, "a battle that never opened one is not open")
  T.eq(Formmenu.index(nil), nil, "and has no row either")
  local battle = {}
  Formmenu.close(battle) -- never opened; must not throw
  T.eq(Formmenu.isOpen(battle), false, "closing an already-closed list is a no-op")
end

-- ---------------------------------------------------------------------
-- open(): the starting row.  Armed beats a merely remembered selection
-- beats the first entry -- the requirement that re-opening the list while
-- something is armed must show the player what is armed, not the top of
-- the list by default.
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  local function entry(id, label)
    return { id = id, label = label, available = function() return true end,
             activate = function() return true end }
  end
  T.eq(registry:register(entry("alpha", "ALPHA")), true, "alpha registers")
  T.eq(registry:register(entry("beta", "BETA")), true, "beta registers")
  T.eq(registry:register(entry("gamma", "GAMMA")), true, "gamma registers")
  Overlay.bind({ registry = registry })
  Formmenu.bind({ overlay = Overlay })

  local battle = { phase = "menu", queue = {} }
  local state = Arm.new()
  state:onBattleStarted({ battle = battle })

  Formmenu.open(battle, state)
  T.eq(Formmenu.index(battle), 1, "nothing armed or selected: opens on the first row")
  Formmenu.close(battle)

  state:toggle("beta")
  state:toggle("beta") -- arm then disarm: leaves beta merely SELECTED, not armed
  T.eq(state:isArmed(), false, "precondition: beta is selected but not armed")
  T.eq(state:selected(), "beta", "precondition: selection remembers beta")
  Formmenu.open(battle, state)
  T.eq(Formmenu.index(battle), 2, "with nothing armed, opens on the remembered selection")
  Formmenu.close(battle)

  state:toggle("gamma")
  T.eq(state:armed(), "gamma", "precondition: gamma is now armed")
  Formmenu.open(battle, state)
  T.eq(Formmenu.index(battle), 3,
    "armed wins over the earlier selection -- opens on what is actually armed")
  Formmenu.close(battle)

  -- arm.lua's own toggle always sets armedId and selectedId to the same id
  -- together, so the check above cannot by itself tell "armed wins" apart
  -- from "selected wins" -- the two agree in every state toggle can reach.
  -- The requirement is about ARMED specifically (a re-opened list must show
  -- what is actually about to fire, not merely what was last highlighted),
  -- so that is what src/formmenu.lua checks first rather than leaning on
  -- arm.lua's invariant holding forever.  Proven here by breaking the
  -- invariant on purpose, directly on the state's own fields, the only way
  -- to produce a battle where the two genuinely disagree.
  state.armedId, state.selectedId = "gamma", "alpha"
  Formmenu.open(battle, state)
  T.eq(Formmenu.index(battle), 3,
    "with the two forced apart, the armed one still wins over the selected one")
end

-- ---------------------------------------------------------------------
-- handleInput(): navigation wraps, never touches arm state, and only A
-- commits.  Driven with a real, hooked registry so the "arm/disarm are real
-- operations" claim is provable rather than asserted -- the same technique
-- tests/battle_forms_arm_test.lua's own hooked block uses.
-- ---------------------------------------------------------------------
do
  local log = {}
  local function hooked(id, label)
    return { id = id, label = label, available = function() return true end,
             activate = function() return true end,
             arm = function() log[#log + 1] = id .. ":arm" end,
             disarm = function() log[#log + 1] = id .. ":disarm" end }
  end
  local registry = Transforms.new()
  registry:register(hooked("alpha", "ALPHA"))
  registry:register(hooked("beta", "BETA"))
  Overlay.bind({ registry = registry })
  Formmenu.bind({ overlay = Overlay })
  Arm.bind({ registry = registry })

  local battle = { phase = "menu", queue = {}, game = { input = makeInput({}) } }
  local state = Arm.new()
  state:onBattleStarted({ battle = battle })
  Formmenu.open(battle, state)
  T.eq(Formmenu.index(battle), 1, "precondition: opens on the first row")

  battle.game.input = makeInput({ down = true })
  T.eq(Formmenu.handleInput(battle, state), true, "down is claimed")
  T.eq(Formmenu.index(battle), 2, "and moves to the second row")
  T.eq(#log, 0, "moving the cursor arms nothing")

  battle.game.input = makeInput({ down = true })
  Formmenu.handleInput(battle, state)
  T.eq(Formmenu.index(battle), 1, "down wraps back round past the last row")

  battle.game.input = makeInput({ up = true })
  Formmenu.handleInput(battle, state)
  T.eq(Formmenu.index(battle), 2, "up wraps the other way, past the first row")
  T.eq(#log, 0, "still nothing armed by navigation alone")

  -- A confirms the highlighted row -- a real arm, with the real side effect.
  battle.game.input = makeInput({})
  local handled, action = Formmenu.handleInput(battle, state) -- no button this frame
  T.eq(handled, true, "an empty frame is still claimed")
  T.eq(Formmenu.index(battle), 2, "and a frame with nothing pressed moves nothing")
  T.eq(action, nil, "and reports no action -- nothing for a sound to mark")

  battle.game.input = makeInput({ a = true })
  handled, action = Formmenu.handleInput(battle, state)
  T.eq(handled, true, "A is claimed")
  T.eq(action, "toggle", "and reports the toggle")
  T.eq(state:armed(), "beta", "which really armed the highlighted row")
  T.eq(table.concat(log, " "), "beta:arm", "through the real arm hook")
  T.eq(Formmenu.isOpen(battle), false, "and the list closes on confirm")

  -- B cancels without touching what is already armed: browsing a re-opened
  -- list must never unwind a substitution the player never asked to change.
  log = {}
  Formmenu.open(battle, state)
  T.eq(Formmenu.index(battle), 2, "re-opening starts on the armed row")
  battle.game.input = makeInput({ up = true })
  Formmenu.handleInput(battle, state) -- preview alpha
  T.eq(Formmenu.index(battle), 1, "the cursor moved to preview the other row")
  T.eq(state:armed(), "beta", "but nothing armed changed from merely looking")
  T.eq(#log, 0, "and no hook fired for a press that never happened")

  battle.game.input = makeInput({ b = true })
  handled, action = Formmenu.handleInput(battle, state)
  T.eq(handled, true, "B is claimed")
  T.eq(action, "cancel", "and reports the cancel")
  T.eq(Formmenu.isOpen(battle), false, "closing the list")
  T.eq(state:armed(), "beta",
    "with beta still armed exactly as it was before the list reopened -- "
      .. "cancelling never has anything of its own to unwind")
  T.eq(#log, 0, "confirmed by the hook log: neither arm nor disarm ran for the cancel")
end

-- ---------------------------------------------------------------------
-- Defensive edges: no game.input at all, and the offered list emptying
-- out from under an open list (the mon carrying the last entry's item
-- switched out while the player was browsing).
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  local available = true
  registry:register({ id = "only", label = "ONLY",
                       available = function() return available end,
                       activate = function() return true end })
  Overlay.bind({ registry = registry })
  Formmenu.bind({ overlay = Overlay })

  local battle = { phase = "menu", queue = {} }
  local state = Arm.new()
  state:onBattleStarted({ battle = battle })
  Formmenu.open(battle, state)

  T.eq(Formmenu.handleInput(battle, state), true,
    "no battle.game.input at all is still claimed rather than erroring")

  available = false
  battle.game = { input = makeInput({}) }
  T.eq(Formmenu.handleInput(battle, state), true,
    "an offered count of zero is still claimed")
  T.eq(Formmenu.isOpen(battle), false,
    "but the list closes itself rather than drawing zero rows")
end

-- ---------------------------------------------------------------------
-- Through the real loader: main.lua's own wiring, not a hand mirror of it.
--
-- Every check above proves src/formmenu.lua correct in isolation, bound by
-- hand exactly the way src/menu.lua's own test binds it -- and that is
-- precisely the shape of the bug this session's brief calls out: a menu
-- test built its own name map and passed even though the real merge never
-- happened, and only failed once driven through the real, load-patched
-- engine class.  The equivalent risk here is main.lua never actually
-- wiring `formmenu` into `menu.bind`, or src/menu.lua's on-cell branch
-- quietly reverting to arming directly on A -- both would leave every test
-- above green while a real battle never opens a list at all.
--
-- So this block loads the real main.lua through the SDK, requires the real
-- game/src/battle/BattleState.lua (a Lua module singleton through
-- package.loaded, the same fact tests/battle_forms_gmaxmoves_test.lua's own
-- real-loader block relies on), and drives A/A/turn-start through it
-- exactly as a player would -- proving the list opens AND that confirming a
-- row really arms mega evolution, through Resolve's own turn-start
-- dispatch, not through a hand-called `state:toggle`.
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
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = "return function() end",
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" },
    { fs = T.sdk.memfs(files), data = T.fixtures.fresh() })
  T.eq(#run.errors, 0, "the mod loads clean")

  local BattleState = require("src.battle.BattleState")
  T.check(BattleState._battleFormsMenuPatched == true,
    "the real BattleState.update was actually wrapped by this load")

  -- National Dex is stubbed (see tests/battle_forms_load_test.lua's own
  -- header on why), so the species records mega evolution and its
  -- eligibility gate both read have to be supplied here, the same shape
  -- tests/battle_forms_transforms_test.lua's own makeBattle uses.
  run.data.pokemon = run.data.pokemon or {}
  run.data.pokemon.CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                                               speed = 100, special = 85 },
                                 types = { "FIRE", "FLYING" } }
  run.data.pokemon.CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130,
                                                       defense = 111, speed = 100,
                                                       special = 130 },
                                        types = { "FIRE", "DRAGON" }, form = "MEGA_X" }

  local E = dofile(MOD .. "/src/eligibility.lua")
  local KeyItems = dofile(MOD .. "/src/keyitems.lua")
  local mon = { species = "CHARIZARD", level = 50,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
                statExp = {}, hp = 100, [E.STAMP] = "CHARIZARDITE_X" }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  local battle = {
    phase = "menu", menuIndex = 1, queue = {}, data = run.data,
    player = { isPlayer = true, mon = mon, curStats = mon.stats,
               curTypes = run.data.pokemon.CHARIZARD.types },
    game = { save = { party = { mon }, inventory = { [KeyItems.KEY_STONE] = 1 } },
             input = { wasPressed = function() return false end } },
    -- BattleState:tickFx is a real method on a real instance; this fixture is
    -- a plain table standing in for one, the same way
    -- tests/battle_forms_adopt_test.lua's own makeBattle adds the handful of
    -- methods the wrapped update actually calls rather than building a whole
    -- BattleState.
    tickFx = function() end,
  }

  run.loader.events:emit("battle.started", { battle = battle })

  local function press(button)
    battle.game.input = { wasPressed = function(_, btn) return btn == button end }
    return BattleState.update(battle, 0)
  end

  press("left")
  T.check(battle._battleFormsMenuCell == true,
    "left from FIGHT reached the real cell through the real wrapped update")

  T.check(battle._battleFormsListOpen ~= true,
    "precondition: the list has not opened yet")
  press("a")
  T.check(battle._battleFormsListOpen == true,
    "A on the cell opened the real submenu -- this is the assertion an "
      .. "unwired list (main.lua never binding formmenu, or src/menu.lua "
      .. "reverting to arming directly on A) would fail: handleInput would "
      .. "either error inside the pcall and fall through to vanilla, or "
      .. "arm mega immediately without ever setting this field")

  press("a")
  T.check(battle._battleFormsListOpen == false,
    "confirming the one row closed the real list")
  T.eq(battle.player.mon.form, nil,
    "arming alone does not change the form yet -- that is turn start's job")

  run.loader.events:emit("battle.turn_started", { battle = battle })
  T.eq(battle.player.mon.form, "MEGA_X",
    "and turn start ran the real mega evolution the real submenu armed -- "
      .. "proof the confirm inside the real list dispatched a real arm, not "
      .. "just a UI-only field flip")

  run.release()
end

T.finish("battle_forms_formmenu")
