-- The registry of manually activated transformations, and the one menu cell
-- that hosts them.
--
-- The second transformation here is synthetic and exists only in this file.
-- Nothing but mega evolution is registered in the shipping mod, so the
-- submenu's multi-row list, the per-transformation spent flags and the label
-- switching would otherwise have no way to be exercised until the mechanic
-- that needs them is written -- which is exactly the wrong time to find out
-- the seam does not work.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local Menu = dofile(MOD .. "/src/menu.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Formmenu = dofile(MOD .. "/src/formmenu.lua")
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
  Formmenu.bind({ overlay = Overlay })
  Menu.bind({ overlay = Overlay, formmenu = Formmenu })
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

-- Both on offer, in registration order, and the list -- not the cell's own
-- label -- is where the player actually sees and picks between them.
do
  local battle, state = setup(false)
  local offered = Overlay.offered(state)
  T.eq(#offered, 2, "both transformations are on offer")
  T.eq(offered[1].id, "mega", "in registration order: mega first")
  T.eq(offered[2].id, "burst", "then the synthetic one")
  T.eq(Overlay.label(state), "FORM",
    "the cell is the generic label until something is armed")

  T.eq(press(battle, state, "left"), true, "left at FIGHT reaches the cell")
  T.eq(Menu.isOnCell(battle), true, "and parks there")

  local opened, action = press(battle, state, "a")
  T.eq(opened, true, "A on the cell opens the list")
  T.eq(action, "open", "and reports it for the confirm sound")
  T.eq(Formmenu.isOpen(battle), true, "which holds both rows")
  T.eq(Formmenu.index(battle), 1, "opening on the first, mega, with nothing armed yet")

  T.eq(press(battle, state, "down"), true, "down in the list is claimed")
  T.eq(Formmenu.index(battle), 2, "and moves the cursor to the second row")
  T.eq(Formmenu.isOpen(battle), true, "the list stays open -- moving the cursor never closes it")
  T.eq(state:isArmed(), false, "and arms nothing by itself")

  press(battle, state, "down")
  T.eq(Formmenu.index(battle), 1, "down wraps back round")
  press(battle, state, "up")
  T.eq(Formmenu.index(battle), 2, "up moves the other way, also wrapping")

  local cancelled, cancelAction = press(battle, state, "b")
  T.eq(cancelled, true, "B cancels the list")
  T.eq(cancelAction, "cancel", "reported for the confirm sound, the same as opening")
  T.eq(Formmenu.isOpen(battle), false, "closing it")
  T.eq(Menu.isOnCell(battle), true, "without leaving the cell")
  T.eq(state:isArmed(), false, "nothing was armed by merely browsing and cancelling")

  T.eq(press(battle, state, "up"), true, "up is still the way back to the grid")
  T.eq(Menu.isOnCell(battle), false, "which is where the cursor goes")
  T.eq(battle.menuIndex, 1, "with the real index left exactly where it was")
end

-- Confirming a row arms that one and nothing else, and resolving fires that
-- one's activation.
do
  local battle, state, registry = setup(false)
  press(battle, state, "left")
  press(battle, state, "a") -- opens on mega
  press(battle, state, "down") -- to burst
  T.eq(Formmenu.index(battle), 2, "precondition: the cursor is on the second row")

  local handled, action = press(battle, state, "a")
  T.eq(handled, true, "A on the row is claimed")
  T.eq(action, "toggle", "and reports the toggle for the confirm sound")
  T.eq(state:armed(), "burst", "A arms the transformation the cursor was on")
  T.eq(Formmenu.isOpen(battle), false, "and the list closes behind it")
  T.eq(Overlay.label(state), "BURST*", "which is what the label marks")

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
  press(battle, state, "a") -- opens on mega
  press(battle, state, "a") -- confirms it
  T.eq(state:armed(), "mega", "precondition: armed while standing on the cell")
  T.eq(battle.menuIndex, 1, "precondition: the real index is still FIGHT")

  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(Overlay.shouldOffer(state), false, "the cell empties under the cursor")

  T.eq(press(battle, state, "a"), false,
    "the next frame is handed straight back to vanilla")
  T.eq(Menu.isOnCell(battle), false, "with the cursor no longer on a cell that is gone")
  T.eq(battle.menuIndex, 1, "and back on the real cell it left from")
  T.eq(Overlay.label(state), nil, "and no label left to draw either")

  -- Every direction, not just the one that happened to be pressed: a stranded
  -- cursor shows as a frame claimed by a cell that is not drawn.
  for _, dir in ipairs({ "left", "right", "up", "down", "a" }) do
    T.eq(press(battle, state, dir), false,
      dir .. " on the vanished cell is left to vanilla")
    T.eq(Menu.isOnCell(battle), false, "and never puts the cursor back on it")
  end
end

-- Down to one on offer, the list still opens and holds exactly the one row --
-- there was never a reason to special-case the count, since the list is
-- where every count is shown the same way.
do
  local battle, state = setup(false)
  battle.burstReady = false
  T.eq(#Overlay.offered(state), 1, "precondition: only one is on offer")
  press(battle, state, "left")
  T.eq(Menu.isOnCell(battle), true, "the cursor reaches the cell")
  T.eq(press(battle, state, "right"), true, "right leaves the cell, as it always has")
  T.eq(Menu.isOnCell(battle), false, "and leaves the cell, as it always has")
  press(battle, state, "left")
  T.eq(press(battle, state, "left"), true, "left on the cell is claimed")
  T.eq(Menu.isOnCell(battle), true, "and stays put, as it always has")

  press(battle, state, "a")
  T.eq(Formmenu.isOpen(battle), true, "A still opens the list with only one entry")
  T.eq(Formmenu.index(battle), 1, "on its single row")
  press(battle, state, "a")
  T.eq(state:armed(), "mega", "confirming the one row arms it")
end

-- An availability predicate that turns false takes its entry off the list
-- mid-battle, and the default row falls back rather than pointing past the
-- end of what is left.
do
  local battle, state = setup(false)
  press(battle, state, "left")
  press(battle, state, "a")
  press(battle, state, "down")
  T.eq(Formmenu.index(battle), 2, "precondition: the cursor is on the second row")
  press(battle, state, "b") -- cancel, leaving nothing armed or selected
  battle.burstReady = false
  T.eq(#Overlay.offered(state), 1, "the second entry drops off the list")
  T.eq(Overlay.shouldOffer(state), true, "and the cell stays up on the one that is left")
  press(battle, state, "a")
  T.eq(Formmenu.index(battle), 1,
    "re-opening finds a stale row gone and defaults back inside the list")
end

-- Re-opening the list while something is armed starts the cursor there,
-- so switching to a different transformation or disarming the current one
-- are both one A press away rather than requiring the player to hunt for
-- the row that is already active.
do
  local battle, state = setup(false)
  press(battle, state, "left")
  press(battle, state, "a") -- opens on mega
  press(battle, state, "a") -- arms mega
  T.eq(state:armed(), "mega", "precondition: armed on the first one")

  press(battle, state, "a") -- re-open
  T.eq(Formmenu.isOpen(battle), true, "re-opening while armed is allowed")
  T.eq(Formmenu.index(battle), 1, "and starts on the row that is actually armed")

  press(battle, state, "down")
  T.eq(Formmenu.index(battle), 2, "the player can move to a different row")
  local handled, action = press(battle, state, "a")
  T.eq(handled, true, "and confirm it")
  T.eq(action, "toggle", "reported the same way any other confirm is")
  T.eq(state:armed(), "burst", "switching arms the new one")
  T.eq(state:used("mega"), false, "without spending the one that never fired")
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(battle.player.mon.form, nil, "so nothing fires at turn start for mega")
  T.eq(state:used("mega"), false, "and nothing was spent")
end

-- Cancelling out of a re-opened list leaves whatever was armed on entry
-- exactly as it was -- browsing other rows substitutes nothing behind the
-- player's back, and B never has anything of its own to unwind.
do
  local battle, state = setup(false)
  press(battle, state, "left")
  press(battle, state, "a")
  press(battle, state, "a") -- arms mega
  T.eq(state:armed(), "mega", "precondition: mega is armed")
  T.eq(battle.player.mon.form, nil,
    "precondition: arming alone does not change the form yet -- that is turn start's job")

  press(battle, state, "a") -- re-open, cursor defaults to mega (row 1)
  press(battle, state, "down") -- preview burst, row 2 -- nothing armed by this alone
  T.eq(state:armed(), "mega", "merely moving the cursor while browsing disarms nothing")
  press(battle, state, "b") -- cancel
  T.eq(Formmenu.isOpen(battle), false, "the list closes")
  T.eq(state:armed(), "mega", "and mega is still exactly what was armed before the list opened")

  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(battle.player.mon.form, "MEGA_X", "the substitution cancelling did not unwind still fires")
  T.eq(state:used("mega"), true, "mega is what actually spent the battle's one transformation")
  T.eq(state:used("burst"), false, "never burst, which the player only ever previewed")
end

-- A refused activation spends nothing, the same rule mega evolution has
-- always had, applied from the dispatcher so every entry gets it.
do
  local battle, state = setup(true)
  press(battle, state, "left")
  press(battle, state, "a")
  press(battle, state, "down")
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
  press(battle, state, "a") -- opens on mega
  press(battle, state, "a") -- confirms it
  Resolve.onTurnStarted(state, { battle = battle })
  T.eq(state:used("mega"), true, "precondition: one is spent")
  state:onBattleEnded({ battle = battle })
  state:onBattleStarted({ battle = makeBattle() })
  T.eq(state:used("mega"), false, "the next battle starts with every limit reset")
  T.eq(state:used("burst"), false, "including the ones that were never spent")
  T.eq(state:selected(), nil, "and with no selection carried over")
end

T.finish("battle_forms_transforms")
