-- The registry of manually activated transformations, and the one menu cell
-- that hosts them.
--
-- The second transformation here is synthetic and exists only in this file.
-- Nothing but mega evolution is registered in the shipping mod, so the cycling,
-- the per-transformation spent flags and the label switching would otherwise
-- have no way to be exercised until the mechanic that needs them is written --
-- which is exactly the wrong time to find out the seam does not work.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local Menu = dofile(MOD .. "/src/menu.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

-- ---------------------------------------------------------------------
-- Registration refuses out loud rather than half-registering.
-- ---------------------------------------------------------------------
do
  local reg = Transforms.new()
  T.eq(reg:count(), 0, "a new registry holds nothing")
  T.eq(reg:get("mega"), nil, "and answers for nothing")

  local complete = { id = "x", label = "X", available = function() return true end,
                     activate = function() return true end }
  local function without(field)
    local copy = {}
    for k, v in pairs(complete) do copy[k] = v end
    copy[field] = nil
    return copy
  end

  for _, case in ipairs({ "id", "label", "available", "activate" }) do
    local ok, why = reg:register(without(case))
    T.eq(ok, false, "an entry with no " .. case .. " is refused")
    T.check(type(why) == "string" and why:find(case, 1, true) ~= nil,
      "and the refusal names " .. case)
  end
  T.eq(reg:register("not a table"), false, "so is something that is not an entry")
  T.eq(reg:count(), 0, "nothing was half-registered by any of that")

  T.eq(reg:register(complete), true, "a complete entry registers")
  T.eq(reg:count(), 1, "and is counted")
  T.eq(reg:get("x"), complete, "and is reachable by its id")

  local ok, why = reg:register({ id = "x", label = "OTHER",
    available = function() return true end, activate = function() return true end })
  T.eq(ok, false, "a second entry under a taken id is refused")
  T.check(why:find("already", 1, true) ~= nil, "and says the id was taken")
  T.eq(reg:count(), 1, "the registry is unchanged by a refusal")
  T.eq(reg:get("x"), complete, "and the entry that held the id still holds it")

  -- arm and disarm are optional, and optional TOGETHER.  A mechanic that swaps
  -- the moveset when the player arms it has to swap it back when they change
  -- their mind, and an entry offering only one half would leave the moves it put
  -- on standing behind a cell showing something else.
  local function pair(arm, disarm)
    return { id = "p" .. tostring(arm) .. tostring(disarm), label = "P",
             available = function() return true end,
             activate = function() return true end,
             arm = arm, disarm = disarm }
  end
  local noop = function() end
  T.eq(reg:register(pair(noop, nil)), false, "arm without disarm is refused")
  T.eq(reg:register(pair(nil, noop)), false, "and disarm without arm")
  local half, halfWhy = reg:register(pair(noop, "not a function"))
  T.eq(half, false, "and a disarm that is not callable")
  T.check(halfWhy:find("arm", 1, true) ~= nil, "the refusal names the pair")
  T.eq(reg:register(pair(noop, noop)), true, "both together register")
  T.eq(reg:register(pair(nil, nil)), true, "and so does neither")
end

-- ---------------------------------------------------------------------
-- Two transformations sharing the one cell.
-- ---------------------------------------------------------------------
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

-- The synthetic one: available when the battle says so, and activating it
-- marks the battle rather than the mon, so nothing it does can be confused
-- with what a mega does.
local bursts = 0
local function burstEntry(refuse)
  return {
    id = "burst",
    label = "BURST",
    available = function(battle) return battle.burstReady == true end,
    activate = function(battle)
      bursts = bursts + 1
      if refuse then return false end
      battle.bursted = true
      return true
    end,
  }
end

local function makeInput(pressed)
  return { wasPressed = function(_, btn) return (pressed or {})[btn] == true end }
end

local function makeBattle()
  local mon = { species = "CHARIZARD", level = 50,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
                statExp = {}, hp = 100, [E.STAMP] = "CHARIZARDITE_X" }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  return {
    phase = "menu", menuIndex = 1, queue = {}, data = DATA,
    burstReady = true,
    player = { isPlayer = true, mon = mon, curStats = mon.stats,
               curTypes = DATA.pokemon.CHARIZARD.types },
    -- The trainer's Key Stone lives here, in the bag src/keyitems.lua reads:
    -- without it the mega cell is not offered at all and every check below
    -- would be about an empty cell rather than about a cell with two entries.
    game = { save = { party = { mon },
                      inventory = { [KeyItems.KEY_STONE] = 1 } },
             input = makeInput({}) },
    enemyParty = {},
    animNext = function() end,
    animationsOn = function() return false end,
  }
end

local function setup(refuse)
  local registry = Transforms.new()
  T.eq(registry:register(Mega.entry({ forms = Forms, eligibility = E,
    megas = megas, keyitems = KeyItems, animId = "TESTANIM",
    battlerof = Battlerof })), true,
    "mega registers first")
  T.eq(registry:register(burstEntry(refuse)), true, "the synthetic one registers second")
  Overlay.bind({ registry = registry })
  Menu.bind({ overlay = Overlay })
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, battlerof = Battlerof })
  local battle = makeBattle()
  local state = Arm.new()
  state:onBattleStarted({ battle = battle })
  return battle, state, registry
end

local function press(battle, state, button)
  battle.game.input = makeInput({ [button] = true })
  return Menu.handleInput(battle, state)
end

-- Both on offer, in registration order, and the cell opens on the first.
do
  local battle, state = setup(false)
  local offered = Overlay.offered(state)
  T.eq(#offered, 2, "both transformations are on offer")
  T.eq(offered[1].id, "mega", "in registration order: mega first")
  T.eq(offered[2].id, "burst", "then the synthetic one")
  T.eq(Overlay.label(state), "MEGA", "the cell opens on the first of them")
  -- The label alone cannot say the cell holds a second one, so the cell says
  -- it separately.  Before this the only way to learn Dynamax was on the cell
  -- was to press a direction there was no reason to press.
  T.eq(Overlay.cyclable(state), true, "and says out loud that it can be cycled")

  T.eq(press(battle, state, "left"), true, "left at FIGHT reaches the cell")
  T.eq(Menu.isOnCell(battle), true, "and parks there")

  T.eq(press(battle, state, "right"), true, "right on the cell is claimed")
  T.eq(Menu.isOnCell(battle), true, "and does not leave it while there is more than one")
  T.eq(Overlay.label(state), "BURST", "right cycles to the next transformation")

  press(battle, state, "right")
  T.eq(Overlay.label(state), "MEGA", "and wraps back round")
  press(battle, state, "left")
  T.eq(Overlay.label(state), "BURST", "left cycles the other way, also wrapping")

  T.eq(press(battle, state, "up"), true, "up is still the way back to the grid")
  T.eq(Menu.isOnCell(battle), false, "which is where the cursor goes")
  T.eq(battle.menuIndex, 1, "with the real index left exactly where it was")
end

-- Arming arms the selected one and nothing else, and resolving fires that
-- one's activation.
do
  local battle, state, registry = setup(false)
  press(battle, state, "left")
  press(battle, state, "right")
  T.eq(Overlay.label(state), "BURST", "precondition: the cell is showing the second one")

  local handled, action = press(battle, state, "a")
  T.eq(handled, true, "A on the cell is claimed")
  T.eq(action, "toggle", "and reports the toggle for the confirm sound")
  T.eq(state:armed(), "burst", "A arms the transformation the cell was showing")
  T.eq(Overlay.label(state), "BURST*", "which is what the label marks")
  T.eq(Overlay.cyclable(state), true, "and an armed cell still shows it can be cycled")

  local before = bursts
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(bursts, before + 1, "turn start runs the armed transformation's activation")
  T.eq(battle.bursted, true, "which did its own work")
  T.eq(battle.player.mon.form, nil, "and did not run mega evolution's")
  T.eq(state:used("burst"), true, "the one that fired is spent")
  T.eq(state:used("mega"), false, "and the one that did not is untouched")
  T.eq(state:usedAny(), true, "but the battle's one manual transformation is gone")

  -- One per battle across all of them, which is the 0.14.0 rule: using either
  -- costs the player the other for the rest of the fight.  The mega has lost
  -- neither its own flag nor its eligibility -- it has lost the cell.
  T.eq(registry:get("mega").available(battle), true,
    "the mega is still perfectly eligible")
  T.eq(#Overlay.offered(state), 0, "and yet nothing at all is on offer")
  T.eq(Overlay.shouldOffer(state), false, "so the cell is gone for the battle")
  T.eq(Overlay.label(state), nil, "with no label left to draw")
  T.eq(Overlay.cyclable(state), false, "and the cycle marker gone with it")

  -- Nothing can be armed through a cell that is not there, and nothing was
  -- left armed behind it either.
  T.eq(press(battle, state, "left"), false, "the cell cannot be reached again")
  T.eq(state:isArmed(), false, "nothing is armed")
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(battle.player.mon.form, nil, "so the next turn start changes no form")
  T.eq(state:used("mega"), false, "and the mega's own flag is still unspent")
end

-- The cursor at the moment the cell vanishes under it.  Spending the armed
-- transformation empties the cell mid-battle, and the frame the cursor is
-- parked there is the one most likely to strand it: src/menu.lua clears
-- _battleFormsMenuCell on the same frame it stops claiming input, so vanilla
-- resumes on the real index the cursor left from.
do
  local battle, state = setup(false)
  press(battle, state, "left")
  T.eq(Menu.isOnCell(battle), true, "precondition: the cursor is on the cell")
  press(battle, state, "a")
  T.eq(state:armed(), "mega", "precondition: armed while standing on it")
  T.eq(battle.menuIndex, 1, "precondition: the real index is still FIGHT")

  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(Overlay.shouldOffer(state), false, "the cell empties under the cursor")

  T.eq(press(battle, state, "a"), false,
    "the next frame is handed straight back to vanilla")
  T.eq(Menu.isOnCell(battle), false, "with the cursor no longer on a cell that is gone")
  T.eq(battle.menuIndex, 1, "and back on the real cell it left from")
  T.eq(Overlay.cyclable(state), false, "the cycle marker went with the cell")
  T.eq(Overlay.label(state), nil, "and so did the label")

  -- Every direction, not just the one that happened to be pressed: a stranded
  -- cursor shows as a frame claimed by a cell that is not drawn.
  for _, dir in ipairs({ "left", "right", "up", "down", "a" }) do
    T.eq(press(battle, state, dir), false,
      dir .. " on the vanished cell is left to vanilla")
    T.eq(Menu.isOnCell(battle), false, "and never puts the cursor back on it")
  end
end

-- Down to one on offer, the cell is the 0.7.0 cell again: right leaves it
-- rather than cycling, because there is nothing to cycle to.
do
  local battle, state = setup(false)
  battle.burstReady = false
  T.eq(#Overlay.offered(state), 1, "precondition: only one is on offer")
  T.eq(Overlay.cyclable(state), false, "so the cell carries no cycle marker")
  press(battle, state, "left")
  T.eq(Menu.isOnCell(battle), true, "the cursor reaches the cell")
  T.eq(press(battle, state, "right"), true, "right is claimed")
  T.eq(Menu.isOnCell(battle), false, "and leaves the cell, as it always has")
  press(battle, state, "left")
  T.eq(press(battle, state, "left"), true, "left on the cell is claimed")
  T.eq(Menu.isOnCell(battle), true, "and stays put, as it always has")
end

-- An availability predicate that turns false takes its entry off the cell
-- mid-battle, and the selection falls back rather than showing nothing.
do
  local battle, state = setup(false)
  press(battle, state, "left")
  press(battle, state, "right")
  T.eq(Overlay.label(state), "BURST", "precondition: the second one is selected")
  T.eq(Overlay.cyclable(state), true, "precondition: and the cell is a selector")
  battle.burstReady = false
  T.eq(Overlay.label(state), "MEGA",
    "a selection that stops being offered falls back to what is left")
  T.eq(Overlay.shouldOffer(state), true, "and the cell stays up")
  -- A key item gate can turn false between turns, so the marker has to be
  -- read off the offer each frame rather than latched when the cell appeared:
  -- a cell still promising LEFT/RIGHT with nothing to cycle to is the same
  -- lie as a cell hiding that it has two, pointed the other way.
  T.eq(Overlay.cyclable(state), false, "without the cycle marker it no longer earns")
end

-- Cycling away disarms: the cell shows one label, so an armed flag hiding
-- behind another one would fire without ever having been visible.
do
  local battle, state = setup(false)
  press(battle, state, "left")
  press(battle, state, "a")
  T.eq(state:armed(), "mega", "precondition: armed on the first one")
  press(battle, state, "right")
  T.eq(state:isArmed(), false, "cycling to the next one disarms")
  T.eq(Overlay.label(state), "BURST", "and the cell shows the new one unmarked")
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(battle.player.mon.form, nil, "so nothing fires at turn start")
  T.eq(state:used("mega"), false, "and nothing was spent")
end

-- A refused activation spends nothing, the same rule mega evolution has
-- always had, applied from the dispatcher so every entry gets it.
do
  local battle, state = setup(true)
  press(battle, state, "left")
  press(battle, state, "right")
  press(battle, state, "a")
  T.eq(state:armed(), "burst", "precondition: the refusing one is armed")
  local before = bursts
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(bursts, before + 1, "its activation ran")
  T.eq(battle.bursted, nil, "and declined to do anything")
  T.eq(state:used("burst"), false, "so its once-per-battle limit is not spent")
  T.eq(#Overlay.offered(state), 2, "and it is still on the cell")
end

-- A battle ending clears every flag, not just the first one's.
do
  local battle, state = setup(false)
  press(battle, state, "left")
  press(battle, state, "a")
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(state:used("mega"), true, "precondition: one is spent")
  state:onBattleEnded({ battle = battle })
  state:onBattleStarted({ battle = makeBattle() })
  T.eq(state:used("mega"), false, "the next battle starts with every limit reset")
  T.eq(state:used("burst"), false, "including the ones that were never spent")
  T.eq(state:selected(), nil, "and with no selection carried over")
end

T.finish("battle_forms_transforms")
