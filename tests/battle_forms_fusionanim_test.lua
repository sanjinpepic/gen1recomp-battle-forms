-- The fusion animation: both Pokemon side by side, then merged into one.
-- src/fusionanim.lua's own header has the full reasoning for every decision
-- pinned here; this file proves each of them against the real classes it
-- composes with rather than a stand-in for them, the discipline
-- tests/battle_forms_fusion_test.lua already holds this mechanic to.
--
-- Three tiers, cheapest first: the pure decision (M.justFused), the screen's
-- own timing and lifecycle with no engine underneath it, then the two real
-- dispatches -- the real "item.use" Hooks chain through a real
-- src.ui.BagMenu on Gen 1, and the real Game2:usePartyItem through a real
-- Gen2PartyMenu on Gen 2.  The last two are what would catch the animation
-- being entirely unwired: a suite that only ever calls M.newScreen directly
-- would stay green even if main.lua never called M.install at all.
package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {
  getColor = function() return 1, 1, 1, 1 end,
  setColor = function() end,
  rectangle = function() end,
  print = function() end,
  printf = function() end,
  draw = function() end,
  newQuad = function() return {} end,
  newImage = function(path)
    return { path = path, getDimensions = function() return 24, 24 end,
             getWidth = function() return 24 end,
             getHeight = function() return 24 end }
  end,
  getShader = function() return nil end,
  setShader = function() end,
  getDimensions = function() return 160, 144 end,
  push = function() end, pop = function() end,
  translate = function() end, scale = function() end,
  circle = function() end, clear = function() end,
}
love.math = love.math or {
  random = function(a, b) if b then return a end return a and 1 or 0.5 end,
}
love.filesystem = love.filesystem or {
  load = function() return nil end,
  getInfo = function() return nil end,
  read = function() return nil end,
  write = function() return true end,
  remove = function() return true end,
}
love.timer = love.timer or { getTime = function() return 0 end }

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local FusionAnim = dofile(MOD .. "/src/fusionanim.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local rows = dofile(MOD .. "/data/fusion.lua")
local fuserIndices = dofile(MOD .. "/data/fusers.lua")
local Boxes = require("src.pokemon.Boxes")

local DATA = { pokemon = {
  KYUREM = { name = "KYUREM",
             baseStats = { hp = 125, attack = 130, defense = 90,
                           speed = 95, special = 130 },
             types = { "DRAGON", "ICE" },
             spriteFront = "assets/kyurem_front.png" },
  KYUREM_WHITE = { name = "KYUREM WHITE",
                   baseStats = { hp = 125, attack = 120, defense = 90,
                                 speed = 95, special = 170 },
                   types = { "DRAGON", "ICE" }, form = "WHITE",
                   spriteFront = "assets/kyurem_white_front.png" },
  RESHIRAM = { name = "RESHIRAM",
               baseStats = { hp = 100, attack = 120, defense = 100,
                             speed = 90, special = 150 },
               types = { "DRAGON", "FIRE" },
               spriteFront = "assets/reshiram_front.png" },
} }

local function newMon(species, level)
  local base = DATA.pokemon[species].baseStats
  local mon = { species = species, level = level or 50,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15,
                        special = 15 },
                statExp = {}, hp = 120,
                moves = { { id = "TACKLE", pp = 35 } } }
  mon.stats = { hp = base.hp, attack = base.attack, defense = base.defense,
                speed = base.speed, special = base.special }
  return mon
end

local function newSave(party)
  local save = { party = party, inventory = {}, money = 0,
                 player = { name = "RED" } }
  Boxes.ensure(save)
  return save
end

local recordedErrors = {}
local log = { error = function(_, fmt, ...)
  recordedErrors[#recordedErrors + 1] = string.format(fmt, ...)
end }
log.warn = log.error

Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
              battlerof = Battlerof })

local fusionItemIds = {}
for itemId in pairs(fuserIndices) do fusionItemIds[itemId] = true end

-- =========================================================================
-- Tier 1: the pure decision
-- =========================================================================

do
  T.eq(FusionAnim.justFused(nil, "RESHIRAM"), true,
    "nil -> species is a fresh fuse")
  T.eq(FusionAnim.justFused("RESHIRAM", nil), false,
    "species -> nil is a split, and stays a message per this file's own "
      .. "header -- nothing new appears on screen to animate")
  T.eq(FusionAnim.justFused(nil, nil), false,
    "nil -> nil is a refusal or an unrelated item")
  T.eq(FusionAnim.justFused("RESHIRAM", "RESHIRAM"), false,
    "no change at all is never a fuse")
end

-- =========================================================================
-- Tier 1: art resolution -- both games read the same seam
-- =========================================================================

FusionAnim.bind({ fusion = Fusion, log = log, itemIds = fusionItemIds })

-- resolveArt reads the fused form off the survivor's OWN stamp
-- (fusion.formIdFor), the identical derived-not-remembered read
-- src/fusion.lua's settle() and M.apply already make -- so every call below
-- stamps the mon first, matching exactly what tryAnimate hands it in the
-- real dispatch (M.resolveArt is only ever called after the fuse itself has
-- already written the stamp).
local function fusedMon(species, partnerSpecies)
  local mon = newMon(species)
  mon[Fusion.STAMP] = partnerSpecies
  return mon
end

do
  local left, right, result =
    FusionAnim.resolveArt(DATA, fusedMon("KYUREM", "RESHIRAM"), "RESHIRAM")
  T.check(left ~= nil and right ~= nil and result ~= nil,
    "all three pictures resolve when every record carries spriteFront")
  T.eq(left.species, "KYUREM", "left is the survivor's own species")
  T.eq(right.species, "RESHIRAM", "right is the partner's own species")
  T.eq(result.species, "KYUREM_WHITE", "the centre picture is the fused form")
end

do
  T.eq(FusionAnim.resolveArt(DATA, nil, "RESHIRAM"), nil,
    "no survivor at all resolves nothing")
  T.eq(FusionAnim.resolveArt(nil, fusedMon("KYUREM", "RESHIRAM"), "RESHIRAM"),
    nil, "no data table resolves nothing")
  T.eq(FusionAnim.resolveArt(DATA, newMon("RESHIRAM"), "RESHIRAM"), nil,
    "an unstamped mon (nothing to derive a form id from) resolves nothing")
end

-- A form with no art degrades to nothing resolved -- the caller's job is to
-- fall back to the plain message rather than draw a blank, per this file's
-- own header.
do
  local thin = { pokemon = {
    KYUREM = { name = "KYUREM", baseStats = DATA.pokemon.KYUREM.baseStats,
               types = DATA.pokemon.KYUREM.types,
               spriteFront = "assets/kyurem_front.png" },
    KYUREM_WHITE = { name = "KYUREM WHITE",
                     baseStats = DATA.pokemon.KYUREM_WHITE.baseStats,
                     types = DATA.pokemon.KYUREM_WHITE.types, form = "WHITE" },
      -- no spriteFront on the fused form
    RESHIRAM = DATA.pokemon.RESHIRAM,
  } }
  T.eq(FusionAnim.resolveArt(thin, fusedMon("KYUREM", "RESHIRAM"), "RESHIRAM"),
    nil, "no picture for the FUSED form refuses the whole animation")
end

do
  local thin = { pokemon = {
    KYUREM = DATA.pokemon.KYUREM, KYUREM_WHITE = DATA.pokemon.KYUREM_WHITE,
    RESHIRAM = { name = "RESHIRAM",
                 baseStats = DATA.pokemon.RESHIRAM.baseStats,
                 types = DATA.pokemon.RESHIRAM.types },
                 -- no spriteFront on the PARTNER
  } }
  T.eq(FusionAnim.resolveArt(thin, fusedMon("KYUREM", "RESHIRAM"), "RESHIRAM"),
    nil, "no picture for the PARTNER refuses the whole animation, not a "
      .. "two-up with a blank on one side")
end

do
  local thin = { pokemon = {
    KYUREM = { name = "KYUREM", baseStats = DATA.pokemon.KYUREM.baseStats,
               types = DATA.pokemon.KYUREM.types },
               -- no spriteFront on the SURVIVOR
    KYUREM_WHITE = DATA.pokemon.KYUREM_WHITE, RESHIRAM = DATA.pokemon.RESHIRAM,
  } }
  T.eq(FusionAnim.resolveArt(thin, fusedMon("KYUREM", "RESHIRAM"), "RESHIRAM"),
    nil, "no picture for the SURVIVOR refuses the whole animation")
end

-- =========================================================================
-- Tier 2: the screen's own lifecycle, no engine underneath it
-- =========================================================================

local function fakeStack(pushed)
  local stack = { items = {} }
  function stack:push(s) self.items[#self.items + 1] = s pushed(s) end
  function stack:pop() return table.remove(self.items) end
  function stack:top() return self.items[#self.items] end
  return stack
end

local function entry(species) return { image = { getDimensions = function()
  return 24, 24 end }, trueColor = false, species = species } end

do
  local done = 0
  local stack = fakeStack(function() end)
  local screen = FusionAnim.newScreen({
    game = { stack = stack, input = {} }, gen2 = false,
    left = entry("KYUREM"), right = entry("RESHIRAM"),
    result = entry("KYUREM_WHITE"),
    onDone = function() done = done + 1 end,
  })
  stack:push(screen)
  T.eq(screen.phase, "hold", "starts on the hold beat")

  local total = FusionAnim.HOLD_FRAMES + FusionAnim.MERGE_FRAMES
    + FusionAnim.FLASH_FRAMES + FusionAnim.REVEAL_FRAMES
  for i = 1, total - 1 do
    screen:update(1 / 60)
    T.check(done == 0, "not finished before the last frame (frame " .. i .. ")")
  end
  T.eq(screen.phase, "reveal", "the last frame before completion is reveal")
  screen:update(1 / 60)
  T.eq(done, 1, "onDone fires exactly once when every phase has run its course")
  T.eq(stack:top(), nil, "and the screen popped itself off the real stack")
end

do
  -- Exact phase boundaries, not just the total -- a reordered PHASE_ORDER or
  -- a wrong per-phase frame count would still sum to the same total and pass
  -- the test above alone.
  local stack = fakeStack(function() end)
  local screen = FusionAnim.newScreen({
    game = { stack = stack, input = {} }, gen2 = false,
    left = entry("KYUREM"), right = entry("RESHIRAM"),
    result = entry("KYUREM_WHITE"), onDone = function() end,
  })
  stack:push(screen)
  for _ = 1, FusionAnim.HOLD_FRAMES - 1 do screen:update(1 / 60) end
  T.eq(screen.phase, "hold", "still on hold one frame before its own limit")
  screen:update(1 / 60)
  T.eq(screen.phase, "merge", "then advances to merge")
  for _ = 1, FusionAnim.MERGE_FRAMES do screen:update(1 / 60) end
  T.eq(screen.phase, "flash", "then flash")
  for _ = 1, FusionAnim.FLASH_FRAMES do screen:update(1 / 60) end
  T.eq(screen.phase, "reveal", "then reveal, the fused picture alone")
end

do
  -- A/B skips straight to done from ANY phase -- proven mid-merge, not just
  -- at the start, since a skip that only worked on frame 1 would still pass
  -- a test that only ever presses on frame 1.
  local done = 0
  local stack = fakeStack(function() end)
  local pressed = { a = false }
  local screen = FusionAnim.newScreen({
    game = { stack = stack, input = {
      -- Consumes the edge like the real game.input:wasPressed does, so a
      -- press does not keep re-firing finish() every frame it stays "held"
      -- in the fixture -- the same one-shot contract src/arm.lua and every
      -- other input read in this mod already assumes.
      wasPressed = function(_, key)
        if not pressed[key] then return false end
        pressed[key] = false
        return true
      end,
    } }, gen2 = false,
    left = entry("KYUREM"), right = entry("RESHIRAM"),
    result = entry("KYUREM_WHITE"), onDone = function() done = done + 1 end,
  })
  stack:push(screen)
  for _ = 1, 5 do screen:update(1 / 60) end
  T.eq(screen.phase, "hold", "still mid-animation before any press")
  pressed.a = true
  screen:update(1 / 60)
  T.eq(done, 1, "an A press ends the animation immediately, from any phase")
  T.eq(stack:top(), nil, "and it still pops itself on the skip path")

  -- Finishing twice must never double-pop or double-fire onDone: a stray
  -- update() call after the screen is already off the stack (StateStack:
  -- update only calls the TOP, but a defensive extra call must still be inert)
  screen:update(1 / 60)
  T.eq(done, 1, "a second update after finishing does nothing further")

  -- Calling :finish() a second time directly -- bypassing update() and
  -- input entirely, so this pins Screen:finish's OWN guard rather than
  -- something update()'s own early return could be masking.
  screen:finish()
  T.eq(done, 1, "and calling finish() again directly still does not "
    .. "re-fire onDone")
end

do
  -- draw() must not error in either mode, at every phase, with or without a
  -- picture to show (the flash beat deliberately draws none).
  local stack = fakeStack(function() end)
  for _, gen2 in ipairs({ false, true }) do
    local screen = FusionAnim.newScreen({
      game = { stack = stack, input = {}, data = { gen2Palettes = {} } },
      gen2 = gen2, left = entry("KYUREM"), right = entry("RESHIRAM"),
      result = entry("KYUREM_WHITE"), onDone = function() end,
    })
    for _ = 1, FusionAnim.HOLD_FRAMES + FusionAnim.MERGE_FRAMES
        + FusionAnim.FLASH_FRAMES + FusionAnim.REVEAL_FRAMES do
      local ok = pcall(function() screen:draw() end)
      T.check(ok, "draw() does not error (gen2=" .. tostring(gen2) .. ")")
      screen:update(1 / 60)
    end
  end
end

do
  -- sgbPalettes: Gen 1 answers something (so it is never left to inherit
  -- whatever screen is underneath it); Gen 2 answers nothing at all, since
  -- Game2 never asks and Gold's own classes keep this field absent on purpose.
  local screen1 = FusionAnim.newScreen({ gen2 = false, left = entry("KYUREM"),
    right = entry("RESHIRAM"), result = entry("KYUREM_WHITE") })
  local zones = screen1:sgbPalettes({ data = DATA })
  T.check(zones ~= nil, "Gen 1 answers a palette zone list")

  local screen2 = FusionAnim.newScreen({ gen2 = true, left = entry("KYUREM"),
    right = entry("RESHIRAM"), result = entry("KYUREM_WHITE") })
  T.eq(screen2:sgbPalettes({ data = DATA }), nil,
    "Gen 2 answers nothing -- Game2.lua has no equivalent walk to feed")
end

-- =========================================================================
-- Tier 3a: the real "item.use" Hooks chain and the real BagMenu, Gen 1
-- =========================================================================
--
-- Proves the WIRING, not just the decision: a suite that only ever
-- constructed a screen by hand would stay green even if main.lua never
-- called FusionAnim.install at all.  This drives the real
-- src.mods.Hooks:call the exact way src/ui/BagMenu.lua's own useOn does,
-- with the real Fusion module underneath doing the actual party/box work,
-- proving the chain end to end.

local Hooks = require("src.mods.Hooks")

local function fakeMod(gen2)
  local mod = { items = {}, effects = {}, errors = {}, hooks = Hooks.new() }
  mod.content = {
    items = { register = function(_, id, record) mod.items[id] = record end },
    item_effects = {
      register = function(_, id, record) mod.effects[id] = record end },
  }
  mod.log = { error = function(_, fmt, ...)
    mod.errors[#mod.errors + 1] = string.format(fmt, ...)
  end }
  mod.log.warn = mod.log.error
  return mod
end

local function realStack()
  local stack = { items = {} }
  function stack:push(s) self.items[#self.items + 1] = s end
  function stack:pop() return table.remove(self.items) end
  function stack:top() return self.items[#self.items] end
  return stack
end

-- Drives the real BagMenu the way tests/battle_forms_fusion_test.lua's own
-- Gen 2 section and game/tests/engine/item_use_hook.lua both drive their own
-- real UI class, rather than hand-building a screen and asserting on it.
local Bag = require("src.inventory.Bag")

local function useFusionItemViaBagMenu(mod, itemId, data, save, target)
  local realTextBox = package.loaded["src.render.TextBox"]
  package.loaded["src.render.TextBox"] = {
    new = function(_, text, done) return { textBox = true, text = text, done = done } end,
  }
  package.loaded["src.ui.BagMenu"] = nil
  local BagMenu = require("src.ui.BagMenu")

  -- The real ListMenu reads its rows off the real inventory table (Bag.
  -- order), so the fusion item has to actually be IN the bag for USE to
  -- find a row for it at all -- it is kept, not consumed, so one is enough
  -- for every call this helper makes across a whole do-block.
  if not save.inventory[itemId] then Bag.add(save, itemId, 1) end

  -- Fusion.install registered onto the fake mod's own content.items table
  -- (mod.items), never the real data.items registry a running game would
  -- merge into -- BagMenu.buildItems reads data.items directly, so this
  -- mirrors that merge for exactly the records the test needs.
  data.items = data.items or {}
  for id, record in pairs(mod.items) do data.items[id] = data.items[id] or record end
  data.item_effects = data.item_effects or {}
  for id, record in pairs(mod.effects) do
    data.item_effects[id] = data.item_effects[id] or record
  end

  local Runtime = require("src.mods.Runtime")
  local savedHooks = Runtime.hooks
  Runtime.hooks = mod.hooks

  local game = { data = data, save = save, stack = realStack() }
  local list = BagMenu.new(game, {})
  game.stack:push(list)
  local row
  for i, r in ipairs(list.items) do if r.value == itemId then row = i end end

  -- Straight into useOn's own target picker path via the private useItem
  -- flow: rather than reproduce list navigation input, drive the exposed
  -- onChoose the same way item_use_hook.lua's own probe does, then hand the
  -- target picker its onSwitch directly (needsTarget items open a real
  -- PartyMenu; picking through it is what item_use_hook.lua's own probe
  -- item never had to do, since a Potion needs no target -- a fusion item
  -- does, so the picker is driven for real here).
  list.onChoose(list.items[row], list)
  -- Out of battle the bag offers USE / TOSS first (start_sub_menus.asm),
  -- exactly the submenu game/tests/engine/item_use_hook.lua's own probe
  -- selects through -- BagMenu's onChoose does not call useItem directly.
  local sub = game.stack:top()
  T.check(sub ~= nil and sub.items and sub.items[1] and sub.items[1].onSelect,
    "the USE/TOSS submenu opened for a field bag USE")
  sub.items[1].onSelect()
  local picker = game.stack:top()
  T.check(picker ~= nil and picker.onSwitch ~= nil,
    "USE on a needsTarget fusion item opens the real target picker")
  picker.onSwitch(target, nil)

  Runtime.hooks = savedHooks
  package.loaded["src.render.TextBox"] = realTextBox
  package.loaded["src.ui.BagMenu"] = nil
  return game
end

do
  Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
                battlerof = Battlerof })
  local mod = fakeMod(false)
  Fusion.install(mod, rows, fuserIndices)
  FusionAnim.bind({ fusion = Fusion, log = mod.log, itemIds = fusionItemIds })
  T.eq(FusionAnim.install(mod, false), true, "Gen 1 install reports success")

  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM", 62)
  local save = newSave({ kyurem, reshiram })

  local game = useFusionItemViaBagMenu(mod, "DNA_SPLICERS", DATA, save, kyurem)
  T.eq(kyurem[Fusion.STAMP], "RESHIRAM",
    "the real fusion effect ran through the real BagMenu dispatch")

  local top = game.stack:top()
  T.check(top ~= nil and top.left ~= nil and top.result ~= nil,
    "the animation screen -- not the plain text box -- is what landed on "
      .. "top of the REAL stack after a real bag USE")
  T.eq(top.gen2, false, "built for Gen 1")

  -- Runs it to completion the way a real frame loop would, then confirms the
  -- ordinary message is what is left standing underneath -- proving this
  -- module hands off rather than replaces src/fusion.lua's own two-page text.
  for _ = 1, FusionAnim.HOLD_FRAMES + FusionAnim.MERGE_FRAMES
      + FusionAnim.FLASH_FRAMES + FusionAnim.REVEAL_FRAMES do
    top:update(1 / 60)
  end
  local under = game.stack:top()
  T.check(under ~= nil and under.textBox == true,
    "popping the finished animation reveals the real TextBox underneath")
  T.check(under.text:find("fused", 1, true) ~= nil,
    "carrying src/fusion.lua's own, unmodified message")
end

-- The critical negative: art missing for one participant must fall straight
-- to the plain message, never a screen with a blank in it.
do
  local thinData = { pokemon = {
    KYUREM = DATA.pokemon.KYUREM, KYUREM_WHITE = DATA.pokemon.KYUREM_WHITE,
    RESHIRAM = { name = "RESHIRAM", baseStats = DATA.pokemon.RESHIRAM.baseStats,
                 types = DATA.pokemon.RESHIRAM.types },
  } }
  Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
                battlerof = Battlerof })
  local mod = fakeMod(false)
  Fusion.install(mod, rows, fuserIndices)
  FusionAnim.bind({ fusion = Fusion, log = mod.log, itemIds = fusionItemIds })
  FusionAnim.install(mod, false)

  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  local game = useFusionItemViaBagMenu(mod, "N_SOLARIZER" == nil and "" or "DNA_SPLICERS",
    thinData, save, kyurem)
  T.eq(kyurem[Fusion.STAMP], "RESHIRAM", "the fusion itself still happened")
  local top = game.stack:top()
  T.check(top ~= nil and top.textBox == true,
    "with no picture for the partner, the plain message shows directly -- "
      .. "no animation screen at all")
end

-- Splitting: the reverse direction is deliberately never animated.
do
  Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
                battlerof = Battlerof })
  local mod = fakeMod(false)
  Fusion.install(mod, rows, fuserIndices)
  FusionAnim.bind({ fusion = Fusion, log = mod.log, itemIds = fusionItemIds })
  FusionAnim.install(mod, false)

  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  useFusionItemViaBagMenu(mod, "DNA_SPLICERS", DATA, save, kyurem)
  T.eq(kyurem[Fusion.STAMP], "RESHIRAM", "fused once")

  local game = useFusionItemViaBagMenu(mod, "DNA_SPLICERS", DATA, save, kyurem)
  T.eq(kyurem[Fusion.STAMP], nil, "and separated again on the second use")
  local top = game.stack:top()
  T.check(top ~= nil and top.textBox == true,
    "a split lands the plain message directly, with no animation screen -- "
      .. "this module's own decision, not an accident of missing art")
end

-- A non-fusion item must never even ask the question: the wrap's own guard
-- on deps.itemIds[id] is what keeps this module from touching anything else
-- src/ui/BagMenu.lua dispatches.
do
  Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
                battlerof = Battlerof })
  local mod = fakeMod(false)
  Fusion.install(mod, rows, fuserIndices)
  FusionAnim.bind({ fusion = Fusion, log = mod.log, itemIds = fusionItemIds })
  FusionAnim.install(mod, false)

  local calls = 0
  mod.hooks:wrap("item.use", function(nextFn, ...)
    calls = calls + 1
    return nextFn(...)
  end, -100) -- runs innermost, right before vanilla, so it only sees a REAL call

  local kyurem = newMon("KYUREM")
  local save = newSave({ kyurem })
  local vanilla = function() end
  mod.hooks:call("item.use", vanilla, { data = DATA }, nil, "POTION", kyurem,
    { close = function() end }, nil, nil)
  T.eq(calls, 1, "an ordinary item still reaches vanilla through the chain")
end

-- =========================================================================
-- Tier 3b: the real Game2:usePartyItem and the real Gen2PartyMenu, Gen 2
-- =========================================================================
--
-- Mirrors tests/battle_forms_fusion_test.lua's own "whole chain" section:
-- the real Game2, the real Gen2PartyMenu, a real A press through it.

do
  local Game2 = require("src.core.Game2")
  require("src.core.Logger").warn = function() end

  local GEN2_ROSTER = { pokemon = { growthRates = {
    GROWTH_MEDIUM_SLOW = { numerator = 6, denominator = 5, squared = -15,
                            linear = 100, constant = 140 },
  } } }
  GEN2_ROSTER.pokemon.KYUREM = {
    id = "KYUREM", name = "KYUREM", growthRate = "GROWTH_MEDIUM_SLOW",
    types = { "DRAGON", "ICE" },
    baseStats = { hp = 125, attack = 130, defense = 90, speed = 95,
                  specialAttack = 130, specialDefense = 90 },
    spriteFront = "assets/kyurem_front.png",
  }
  GEN2_ROSTER.pokemon.KYUREM_WHITE = {
    id = "KYUREM_WHITE", name = "KYUREM WHITE", form = "WHITE",
    types = { "DRAGON", "ICE" },
    baseStats = { hp = 125, attack = 120, defense = 90, speed = 95,
                  specialAttack = 170, specialDefense = 100 },
    spriteFront = "assets/kyurem_white_front.png",
  }
  GEN2_ROSTER.pokemon.RESHIRAM = {
    id = "RESHIRAM", name = "RESHIRAM", growthRate = "GROWTH_MEDIUM_SLOW",
    types = { "DRAGON", "FIRE" },
    baseStats = { hp = 100, attack = 120, defense = 100, speed = 90,
                  specialAttack = 150, specialDefense = 120 },
    spriteFront = "assets/reshiram_front.png",
  }
  GEN2_ROSTER.gen2MenuGfx = {}
  GEN2_ROSTER.gen2Icons = { species = {}, icons = {} }
  GEN2_ROSTER.audio = { sfx = {}, sfxOrder = {} }
  GEN2_ROSTER.tokens = require("src.render.TextBox").TOKENS
  GEN2_ROSTER.gen2Palettes = {}

  local Mon2 = require("src.battle.gen2.Mon")
  local function gen2RealMon(species, level)
    local def = GEN2_ROSTER.pokemon[species]
    local mon = { species = species, level = level,
                  dvs = { attack = 15, defense = 15, speed = 15, special = 15 },
                  statExp = {}, moves = { { id = "TACKLE", pp = 35 } } }
    mon.stats = Mon2.stats(def.baseStats, mon.dvs, level, mon.statExp)
    mon.maxHp = mon.stats.hp
    mon.hp = mon.stats.hp
    return mon
  end

  local function newInput()
    local input = { pressed = {} }
    function input:press(button) self.pressed[button] = true end
    function input:wasPressed(button)
      if self.pressed[button] then self.pressed[button] = nil return true end
      return false
    end
    function input:isDown() return false end
    return input
  end

  local function newStack()
    return {
      _items = {},
      push = function(self, s) self._items[#self._items + 1] = s end,
      pop = function(self) return table.remove(self._items) end,
      top = function(self) return self._items[#self._items] end,
      clear = function(self) while #self._items > 0 do self:pop() end end,
    }
  end

  local function drive(game, predicate, frames)
    for _ = 1, frames or 600 do
      if predicate() then return true end
      local top = game.stack:top()
      if not top then return predicate() end
      game.input:press("a")
      if top.update then top:update(1 / 60) end
    end
    return predicate()
  end

  local function newHost(inventory, party)
    return setmetatable({
      data = GEN2_ROSTER,
      save = { player = { name = "GOLD" }, party = party,
               inventory = inventory or {}, options = {} },
      options = {}, input = newInput(), stack = newStack(),
    }, { __index = Game2 })
  end

  Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
                battlerof = Battlerof, gen2 = true })
  local realMod = fakeMod(true)
  Fusion.install(realMod, rows, fuserIndices)
  GEN2_ROSTER.items = { DNA_SPLICERS = realMod.items.DNA_SPLICERS }
  GEN2_ROSTER.gen2ItemEffects = { DNA_SPLICERS = realMod.effects.DNA_SPLICERS }

  FusionAnim.bind({ fusion = Fusion, log = realMod.log, itemIds = fusionItemIds })
  T.eq(FusionAnim.install(realMod, true), true, "Gen 2 install reports success")
  T.check(Game2._battleFormsFusionAnim, "Game2.usePartyItem carries the "
    .. "idempotency flag once installed")

  -- A second install must not wrap a second time: the function reference
  -- itself has to be unchanged, not merely "still works" -- a re-wrap that
  -- happened to be harmless today would still be one more layer a future
  -- change could make visible (every other Gen 2 class this mod patches
  -- keeps the identical guard for the identical reason).
  local wrappedOnce = Game2.usePartyItem
  FusionAnim.install(realMod, true)
  T.eq(Game2.usePartyItem, wrappedOnce,
    "a second install call leaves the wrapped method exactly as it was")

  local kyurem = gen2RealMon("KYUREM", 50)
  local reshiram = gen2RealMon("RESHIRAM", 62)
  local host = newHost({ DNA_SPLICERS = 1 }, { kyurem, reshiram })
  Fusion.onSaveReady({ save = host.save })

  host:usePartyItem("DNA_SPLICERS")
  local party = host.stack:top()
  T.check(party ~= nil and party.prompt ~= nil,
    "the real, wrapped Game2:usePartyItem still opens the real Gen2PartyMenu")

  drive(host, function() return host.stack:top() ~= party end)
  T.eq(kyurem[Fusion.STAMP], "RESHIRAM",
    "picking the Kyurem through the real party list fused it for real")

  local top = host.stack:top()
  T.check(top ~= nil and top.left ~= nil and top.result ~= nil,
    "the animation screen landed on top of the REAL Game2 stack, not the "
      .. "plain message directly")
  T.eq(top.gen2, true, "built for Gen 2")

  for _ = 1, FusionAnim.HOLD_FRAMES + FusionAnim.MERGE_FRAMES
      + FusionAnim.FLASH_FRAMES + FusionAnim.REVEAL_FRAMES do
    top:update(1 / 60)
  end
  local under = host.stack:top()
  T.check(under ~= nil and under.pages ~= nil,
    "finishing the animation hands off to the real TextBox with src/fusion."
      .. "lua's own message -- this module never suppressed or replaced it")

  T.check(host.save.inventory.DNA_SPLICERS ~= nil,
    "and the item was not spent, exactly as it is on Gen 1")

  Fusion.onSaveReady({ save = nil })
  Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
                battlerof = Battlerof })
end

-- Gen 2 degrade: a shape drift on Game2.usePartyItem must not crash the
-- load, only disable the animation.
do
  local Game2 = require("src.core.Game2")
  local savedFlag = Game2._battleFormsFusionAnim
  local savedUse = Game2.usePartyItem
  Game2._battleFormsFusionAnim = nil
  Game2.usePartyItem = "not a function"

  local mod = fakeMod(true)
  FusionAnim.bind({ fusion = Fusion, log = mod.log, itemIds = fusionItemIds })
  local ok = FusionAnim.install(mod, true)
  T.eq(ok, false, "a shape drift on Game2.usePartyItem is refused rather "
    .. "than crashing")
  T.check(#mod.errors > 0, "and it says so out loud")

  Game2.usePartyItem = savedUse
  Game2._battleFormsFusionAnim = savedFlag
end

T.finish("battle_forms_fusionanim")
