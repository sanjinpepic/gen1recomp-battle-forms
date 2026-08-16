-- Gen 2's equivalent of battle_forms_formview_test.lua: proves
-- src/gen2formview.lua draws a persistent form's real types and stats over
-- Gold's own SUMMARY screen, on the right page, in the right tile cells, and
-- that a level-up's own stat recompute (or any other staleness in mon.stats)
-- cannot leave a wrong number on screen -- the overlay recomputes fresh from
-- data.pokemon[formId] on every draw rather than trusting mon.stats.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Gen2FormView = dofile(MOD .. "/src/gen2formview.lua")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local Eligibility = dofile(MOD .. "/src/eligibility.lua")

-- love.graphics is already stubbed globally by tests.modkit
-- (tests/love_stub.lua), the same precondition battle_forms_formview_test.lua
-- relies on.
love = love or _G.love

-- The real engine function, not a fixture guess -- so a drifted assumption
-- about Mon.stats' own math fails here first, the same discipline
-- battle_forms_gen2forms_test.lua uses.
local Mon = require("src.battle.gen2.Mon")

local persistentRows = dofile(MOD .. "/data/persistent.lua")
local fusionRows = dofile(MOD .. "/data/fusion.lua")

-- Gen 2 shape: baseStats splits specialAttack/specialDefense rather than
-- carrying one `special` (src/gen2forms.lua's own header).
local DATA = { pokemon = {
  ROTOM = { name = "ROTOM",
    baseStats = { hp = 50, attack = 50, defense = 77, speed = 91,
                  specialAttack = 95, specialDefense = 95 },
    types = { "ELECTRIC", "GHOST" },
    spriteFront = "assets/generated/sprites/rotom_front.png" },
  -- Four DIFFERENT non-hp values on purpose (real Rotom-Wash repeats 107
  -- twice): a row-order bug that swaps two of the five blue-page cells would
  -- pass silently against equal values, the same reasoning
  -- battle_forms_formview_test.lua's Giratina fixture is built on.
  ROTOM_WASH = { name = "ROTOM", form = "WASH",
    baseStats = { hp = 50, attack = 65, defense = 107, speed = 86,
                  specialAttack = 120, specialDefense = 95 },
    types = { "ELECTRIC", "WATER" },
    spriteFront = "assets/generated/sprites/rotom_wash_front.png" },
  -- A SECOND form of the SAME base species, its own picture -- the pair the
  -- picCache concern is actually about: two forms sharing mon.species would
  -- collide on a cache keyed by species rather than by formId.
  ROTOM_HEAT = { name = "ROTOM", form = "HEAT",
    baseStats = { hp = 50, attack = 65, defense = 107, speed = 86,
                  specialAttack = 120, specialDefense = 95 },
    types = { "ELECTRIC", "FIRE" },
    spriteFront = "assets/generated/sprites/rotom_heat_front.png" },

  -- A single-type base gaining a second type outright -- the vanilla screen
  -- never drew a row 16 at all for the base, and this module has to draw one
  -- where nothing was.
  ZACIAN = { name = "ZACIAN",
    baseStats = { hp = 92, attack = 130, defense = 115, speed = 138,
                  specialAttack = 80, specialDefense = 80 },
    types = { "FAIRY" } },
  ZACIAN_CROWNED = { name = "ZACIAN", form = "CROWNED",
    baseStats = { hp = 92, attack = 150, defense = 115, speed = 148,
                  specialAttack = 80, specialDefense = 80 },
    types = { "FAIRY", "STEEL" } },

  -- The reverse: a two-type base dropping to one -- no real family in this
  -- mod's roster does this (see battle_forms_formview_test.lua's identical
  -- fixture note), so this pair is synthetic, proving the erase path itself.
  TWOTYPE = { name = "TWOTYPE",
    baseStats = { hp = 50, attack = 50, defense = 50, speed = 50,
                  specialAttack = 50, specialDefense = 50 },
    types = { "FIRE", "WATER" } },
  TWOTYPE_SOLO = { name = "TWOTYPE", form = "SOLO",
    baseStats = { hp = 50, attack = 60, defense = 55, speed = 45,
                  specialAttack = 70, specialDefense = 65 },
    types = { "GRASS" } },

  KYUREM = { name = "KYUREM",
    baseStats = { hp = 125, attack = 130, defense = 90, speed = 95,
                  specialAttack = 130, specialDefense = 90 },
    types = { "DRAGON", "ICE" } },
  KYUREM_WHITE = { name = "KYUREM", form = "WHITE",
    baseStats = { hp = 125, attack = 120, defense = 90, speed = 95,
                  specialAttack = 170, specialDefense = 100 },
    types = { "DRAGON", "ICE" } },
  RESHIRAM = { name = "RESHIRAM",
    baseStats = { hp = 100, attack = 120, defense = 100, speed = 90,
                  specialAttack = 150, specialDefense = 120 },
    types = { "DRAGON", "FIRE" } },

  BROKENA = { name = "BROKENA", types = { "NORMAL" },
    baseStats = { hp = 1, attack = 1, defense = 1, speed = 1,
                  specialAttack = 1, specialDefense = 1 } },
  BROKENA_NOTYPES = { name = "BROKENA", form = "X",
    baseStats = { hp = 1, attack = 1, defense = 1, speed = 1,
                  specialAttack = 1, specialDefense = 1 } },
} }

persistentRows.TWOTYPE = { TEST_ITEM = "TWOTYPE_SOLO" }
persistentRows.BROKENA = { ITEM_A = "BROKENA_NOTYPES" }

Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
Fusion.bind({ rows = fusionRows })
Gen2FormView.bind({ fusion = Fusion, persistent = Persistent })

-- ---------------------------------------------------------------------
-- Mon fixtures, built through the real mark()/settle() path -- Gen 2's own
-- bare-mon shape, no battler wrapper.
-- ---------------------------------------------------------------------
local function persistentMon(species, itemId, level, extra)
  local m = { species = species, level = level or 50, dvs = {}, statExp = {} }
  for k, v in pairs(extra or {}) do m[k] = v end
  m[Eligibility.STAMP] = itemId
  Persistent.mark(DATA, m)
  return m
end

local function fusionMon(species, partnerSpecies, level, extra)
  local m = { species = species, level = level or 50, dvs = {}, statExp = {} }
  for k, v in pairs(extra or {}) do m[k] = v end
  m[Fusion.STAMP] = partnerSpecies
  Fusion.mark(DATA, m)
  return m
end

-- ---------------------------------------------------------------------
-- M.resolve: the pure lookup.
-- ---------------------------------------------------------------------
do
  local dvs = { hp = 5, attack = 9, defense = 3, speed = 12, special = 6 }
  local statExp = { hp = 2000, attack = 5000, defense = 100, speed = 0, special = 9000 }
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE", 55,
    { dvs = dvs, statExp = statExp })
  T.eq(rotom.form, "WASH", "precondition: the mark landed the WASH suffix")

  local form = Gen2FormView.resolve(DATA, rotom)
  T.check(form ~= nil, "a Rotom holding the Washing Machine resolves a form")
  T.eq(form.types[1], "ELECTRIC", "its first type carries over")
  T.eq(form.types[2], "WATER", "its second type is the form's, not GHOST")
  local expected = Mon.stats(DATA.pokemon.ROTOM_WASH.baseStats, dvs, 55, statExp)
  T.eq(form.stats.defense, expected.defense,
    "the resolved DEFENSE matches Mon.stats on the FORM record with this "
      .. "mon's own level/DVs/EVs")
  T.eq(form.stats.hp, expected.hp,
    "the resolved block even carries an hp figure -- unused by the draw "
      .. "path, but proving the whole block came from Mon.stats rather than "
      .. "a partial copy")
end

do
  T.eq(Gen2FormView.resolve(DATA, { species = "PIDGEY" }), nil,
    "a mon with no mon.form at all resolves nothing")
  T.eq(Gen2FormView.resolve(DATA, { species = "PIDGEY", form = "MEGA" }), nil,
    "a mon.form neither src/fusion.lua nor src/persistent.lua can vouch for "
      .. "resolves nothing")
  T.eq(Gen2FormView.resolve(DATA, nil), nil, "and a nil mon does not throw")
end

do
  local mon = persistentMon("BROKENA", "ITEM_A")
  T.eq(mon.form, "X", "precondition: the marker landed")
  T.eq(Gen2FormView.resolve(DATA, mon), nil,
    "a form record with no `types` refuses rather than drawing a blank")
end

-- ---------------------------------------------------------------------
-- The real held-item slot alone, with no mod hook ever having touched
-- mon.form: src/ui/gen2/HeldItemMenu.lua's GIVE writes mon.item directly
-- and fires no event this mod can see, so a mon can reach the SUMMARY
-- screen holding an entitling item while mon.form is still nil -- exactly
-- the bug report this file's own module exists to fix. The local
-- formIdFor this module resolves through must not gate on mon.form
-- already being set, or the overlay would draw nothing for precisely this
-- case.
-- ---------------------------------------------------------------------
do
  Persistent.bind({ eligibility = Eligibility, rows = persistentRows, gen2 = true })
  local given = { species = "ROTOM", level = 50, dvs = {}, statExp = {},
                  item = "WASHING_MACHINE" }
  T.eq(given.form, nil, "precondition: nothing has ever marked this mon")

  local form = Gen2FormView.resolve(DATA, given)
  T.check(form ~= nil,
    "a Rotom merely HOLDING the appliance resolves a form on the SUMMARY "
      .. "screen even though mon.form was never set")
  T.eq(form.types[2], "WATER", "and it is the held item's own form")

  Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
end

-- ---------------------------------------------------------------------
-- The REAL, unstubbed game/src/ui/gen2/SummaryMenu.lua, constructed and
-- drawn exactly the way game/src/ui/gen2/PartyMenu.lua's own openStats()
-- pushes it (party + index, never `mon` directly) -- the "hand-built
-- fixture passes while the real screen does nothing" trap has already cost
-- this repo twice (0.38.0's draw/drawPanel alias, and the Gen 2 menu cell),
-- so this section exists to make a third occurrence here impossible rather
-- than assumed away. Gen2FormView.install patches the module-global class,
-- so this must install before anything below stubs it out from under this
-- test.
-- ---------------------------------------------------------------------
do
  -- gen2 = true: the real held-item read (mon.item), the same precondition
  -- the "held item alone" section above states plainly is the whole reason
  -- this module's formIdFor does not gate on mon.form.
  Persistent.bind({ eligibility = Eligibility, rows = persistentRows, gen2 = true })
  local RealSummaryMenu = require("src.ui.gen2.SummaryMenu")
  T.eq(Gen2FormView.install({ log = nil }), true,
    "install succeeds against the real engine class")

  local mon = { species = "ROTOM", level = 50, dvs = {}, statExp = {},
                hp = 50, item = "WASHING_MACHINE", moves = {} }
  local save = { party = { mon } }
  local game = { data = DATA, save = save }

  -- PartyMenu:openStats() pushes { party = self.party, index = self.index },
  -- and mon.form is deliberately never set here -- src/ui/gen2/
  -- HeldItemMenu.lua's real GIVE writes only mon.item and fires no event
  -- this mod can hook, so a mon can reach this screen freshly given the
  -- item with mon.form still nil (this file's own header, above).
  local summary = RealSummaryMenu.new(game, { party = save.party, index = 1 })
  T.eq(summary.mon, mon, "the real constructor resolves party[index] to the live mon")
  T.eq(mon.form, nil,
    "precondition: SummaryMenu.new alone never marks the mon (Mon.refreshStats "
      .. "recomputes mon.stats/mon.types from the BASE species and touches "
      .. "neither mon.item nor mon.form)")

  local prints = {}
  local Chrome = require("src.ui.gen2.Chrome")
  local realPrint = Chrome.print
  Chrome.print = function(text, tx, ty)
    prints[#prints + 1] = { text = text, tx = tx, ty = ty }
    return realPrint(text, tx, ty)
  end
  local function printedAt(tx, ty)
    for i = #prints, 1, -1 do
      if prints[i].tx == tx and prints[i].ty == ty then return prints[i].text end
    end
    return nil
  end

  local okPink, errPink = pcall(function() summary:drawPanel() end)
  Chrome.print = realPrint
  T.check(okPink, "the real drawPanel runs without error on the pink page: "
    .. tostring(errPink))
  T.eq(printedAt(1, 15), "ELECTRIC", "TYPE1 through the real class")
  T.eq(printedAt(1, 16), "WATER",
    "TYPE2 through the real class reads the form's own WATER, not base GHOST -- "
      .. "the exact number the bug report says is wrong outside battle")

  prints = {}
  summary.page = 3 -- SummaryMenu.BLUE_PAGE
  Chrome.print = function(text, tx, ty)
    prints[#prints + 1] = { text = text, tx = tx, ty = ty }
    return realPrint(text, tx, ty)
  end
  local okBlue, errBlue = pcall(function() summary:drawPanel() end)
  Chrome.print = realPrint
  T.check(okBlue, "the real drawPanel runs without error on the blue page: "
    .. tostring(errBlue))
  local expectedDefense = tostring(Mon.stats(DATA.pokemon.ROTOM_WASH.baseStats,
    mon.dvs, mon.level, mon.statExp).defense)
  T.eq((printedAt(17, 11) or ""):gsub("^%s+", ""), expectedDefense,
    "DEFENSE through the real class reads the form's own number, not base -- "
      .. "the exact number the bug report says is wrong outside battle")

  -- The picture: no sprite mod is loaded in this test at all (no
  -- pokemon.sprite subscriber), so this drives the record fallback -- the
  -- part of the fix that needs no neighbour to work. A test that would
  -- catch the picture being entirely unwired: reverting
  -- src/gen2formview.lua's own drawPic wrap makes this fail by drawing
  -- ROTOM's own spriteFront instead of ROTOM_WASH's.
  local drawnImages = {}
  local realDraw = love.graphics.draw
  love.graphics.draw = function(image, ...)
    drawnImages[#drawnImages + 1] = image
    return realDraw(image, ...)
  end
  local okPic, errPic = pcall(function() summary:drawPanel() end)
  love.graphics.draw = realDraw
  T.check(okPic, "the real drawPanel runs without error while drawing the "
    .. "picture: " .. tostring(errPic))

  local sawFormPic, sawBasePic = false, false
  for _, image in ipairs(drawnImages) do
    if image and image.path == DATA.pokemon.ROTOM_WASH.spriteFront then
      sawFormPic = true
    end
    if image and image.path == DATA.pokemon.ROTOM.spriteFront then
      sawBasePic = true
    end
  end
  T.check(sawFormPic,
    "the real drawPanel drew Rotom-Wash's OWN picture -- the bug report "
      .. "this pass fixes: a Giratina holding the Griseous Orb kept showing "
      .. "base Giratina on this exact screen even after 0.43.0 fixed its "
      .. "stats and types")
  T.check(not sawBasePic,
    "and never drew the base species' own picture instead")

  -- picCache concerns, driven against the real class: a second party member
  -- with no form at all must not inherit Rotom-Wash's cached picture, a
  -- FRESH screen re-entered on the formed mon must still show its own form
  -- (not a stale miss cached from the moment it had none), and switching
  -- within one OPEN screen must not leak either way.
  local plainMon = { species = "PIDGEY", level = 5, dvs = {}, statExp = {}, hp = 20 }
  save.party[2] = plainMon

  local function drawnPaths(fn)
    local seen = {}
    local realDraw2 = love.graphics.draw
    love.graphics.draw = function(image, ...)
      if image and image.path then seen[image.path] = true end
      return realDraw2(image, ...)
    end
    local ok, err = pcall(fn)
    love.graphics.draw = realDraw2
    T.check(ok, "drawPanel ran without error: " .. tostring(err))
    return seen
  end

  -- Re-entering on the plain party slot: a brand-new SummaryMenu instance,
  -- exactly like PartyMenu:openStats() pushing a fresh screen.
  local plainSummary = RealSummaryMenu.new(game, { party = save.party, index = 2 })
  local plainPaths = drawnPaths(function() plainSummary:drawPanel() end)
  T.check(not plainPaths[DATA.pokemon.ROTOM_WASH.spriteFront],
    "a fresh screen on an unformed party member never shows Rotom-Wash's "
      .. "cached picture")

  -- Re-entering on the FORMED mon again -- a second fresh instance, so this
  -- proves the fix works from cold on every open, not only on the first.
  local reentered = RealSummaryMenu.new(game, { party = save.party, index = 1 })
  local reenteredPaths = drawnPaths(function() reentered:drawPanel() end)
  T.check(reenteredPaths[DATA.pokemon.ROTOM_WASH.spriteFront],
    "re-entering the screen on the formed mon still shows its own picture")

  -- Switching within ONE open screen, both directions.
  summary.index, summary.mon = 2, plainMon
  local switchedAway = drawnPaths(function() summary:drawPanel() end)
  T.check(not switchedAway[DATA.pokemon.ROTOM_WASH.spriteFront],
    "switching to the unformed slot in the SAME screen drops the form picture")

  summary.index, summary.mon = 1, mon
  local switchedBack = drawnPaths(function() summary:drawPanel() end)
  T.check(switchedBack[DATA.pokemon.ROTOM_WASH.spriteFront],
    "and switching back shows the form picture again, from the same cache")

  -- The exact collision the picCache warning names: TWO DIFFERENT forms of
  -- the SAME base species (both ROTOM) in one party. A cache keyed by
  -- mon.species rather than by formId would answer the second Rotom with
  -- the first one's picture.
  local heatMon = { species = "ROTOM", level = 50, dvs = {}, statExp = {},
                    hp = 50, item = "MICROWAVE_OVEN", moves = {} }
  save.party[3] = heatMon
  summary.index, summary.mon = 3, heatMon
  local heatPaths = drawnPaths(function() summary:drawPanel() end)
  T.check(heatPaths[DATA.pokemon.ROTOM_HEAT.spriteFront],
    "a second Rotom wearing a DIFFERENT appliance shows ITS OWN picture")
  T.check(not heatPaths[DATA.pokemon.ROTOM_WASH.spriteFront],
    "never the first Rotom's Wash picture, even though both are species ROTOM")

  summary.index, summary.mon = 1, mon
  local backToWash = drawnPaths(function() summary:drawPanel() end)
  T.check(backToWash[DATA.pokemon.ROTOM_WASH.spriteFront],
    "and switching back to the Wash Rotom shows its own picture again, "
      .. "unaffected by the Heat Rotom having populated the same cache")
  T.check(not backToWash[DATA.pokemon.ROTOM_HEAT.spriteFront],
    "not the Heat Rotom's picture")

  -- The neighbour path: a real pokemon.sprite hook, the SAME seam
  -- src/animation.lua's own battle path fires and universal_sprites
  -- subscribes to, standing in for the sprite mod. Answers with a
  -- form-specific path and marks itself true-colour, proving this module
  -- reaches the neighbour at all and prefers its answer over the record.
  --
  -- The true-colour/native shading SPLIT itself is not asserted here:
  -- GbcPalette.available() reads love.graphics.newShader, which the
  -- headless love stub does not provide, so GbcPalette.with is never
  -- reachable from EITHER branch in this harness and a call count could not
  -- tell them apart. What IS asserted -- the shader being explicitly
  -- cleared -- only ever happens from this module's own drawFormArt, never
  -- from vanilla drawPicBlock, so it still proves the neighbour's own
  -- drawing path ran rather than the record fallback's.
  do
    local Runtime = require("src.mods.Runtime")
    local Hooks = require("src.mods.Hooks")
    local savedHooks = Runtime.hooks
    local hooks = Hooks.new()
    Runtime.hooks = hooks
    local unwrap = hooks:wrap("pokemon.sprite", function(next, path, ctx)
      if ctx.kind == "summary" and ctx.mon and ctx.mon.form == "WASH" then
        ctx.trueColor = true
        return "assets/sets/testpack/front/ROTOM_WASH.png"
      end
      return next(path, ctx)
    end, 0, "test_sprite_pack")

    local realSetShader = love.graphics.setShader
    local shaderClears = 0
    love.graphics.setShader = function(...)
      if select("#", ...) == 0 then shaderClears = shaderClears + 1 end
      return realSetShader and realSetShader(...)
    end

    -- A FRESH instance, not the `summary` reused above: that one already
    -- cached the record fallback for ROTOM_WASH while no hook was installed,
    -- and this module's own per-instance cache (by design, see M.drawPic's
    -- own header) would keep answering with that stale hit rather than
    -- asking the neighbour again.
    local hookedSummary = RealSummaryMenu.new(game, { party = save.party, index = 1 })
    local neighbourPaths = drawnPaths(function() hookedSummary:drawPanel() end)

    love.graphics.setShader = realSetShader
    unwrap()
    Runtime.hooks = savedHooks

    T.check(neighbourPaths["assets/sets/testpack/front/ROTOM_WASH.png"],
      "the hook's own form-specific path was drawn, in preference to "
        .. "Rotom-Wash's own record spriteFront")
    T.check(not neighbourPaths[DATA.pokemon.ROTOM_WASH.spriteFront],
      "and the record's own path was not also drawn")
    T.check(shaderClears > 0,
      "the true-colour answer went through this module's own unshaded "
        .. "draw, not vanilla's drawPicBlock, which never touches the shader")
  end

  Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
end

-- ---------------------------------------------------------------------
-- The draw wrap: the engine class stubbed the same way
-- battle_forms_formview_test.lua stubs Gen 1's, so nothing here touches the
-- real game/src/ui/gen2/SummaryMenu.lua.
-- ---------------------------------------------------------------------
local savedLoaded = {}
for _, name in ipairs({ "src.ui.gen2.SummaryMenu", "src.ui.gen2.Chrome",
    "src.render.GbcPalette", "src.world.gen2.Palettes" }) do
  savedLoaded[name] = package.loaded[name]
end

local PINK_PAGE, GREEN_PAGE, BLUE_PAGE = 1, 2, 3

local function fakeMod()
  local logged = {}
  return {
    log = {
      error = function(_, fmt, ...) logged[#logged + 1] =
        { level = "error", msg = fmt:format(...) } end,
      warn = function(_, fmt, ...) logged[#logged + 1] =
        { level = "warn", msg = fmt:format(...) } end,
    },
    logged = logged,
  }
end

local function stubEngine()
  local calls = { prints = {}, rects = {} }
  local SummaryMenu = {
    PINK_PAGE = PINK_PAGE, GREEN_PAGE = GREEN_PAGE, BLUE_PAGE = BLUE_PAGE,
    TYPE_NAMES = { PSYCHIC_TYPE = "PSYCHIC" },
    drawPanel = function(self)
      calls.vanillaDraw = (calls.vanillaDraw or 0) + 1
    end,
  }
  local Chrome = {
    print = function(text, tx, ty)
      calls.prints[#calls.prints + 1] = { text = text, tx = tx, ty = ty }
    end,
    number = function(value, width)
      local text = tostring(math.floor(value or 0))
      local pad = math.max(0, (width or 0) - #text)
      return (" "):rep(pad) .. text
    end,
  }
  package.loaded["src.ui.gen2.SummaryMenu"] = SummaryMenu
  package.loaded["src.ui.gen2.Chrome"] = Chrome
  return SummaryMenu, Chrome, calls
end

local realRectangle = love.graphics.rectangle
local function withRectSpy(calls, fn)
  love.graphics.rectangle = function(mode, x, y, w, h)
    calls.rects[#calls.rects + 1] = { mode = mode, x = x, y = y, w = w, h = h }
  end
  local ok, err = pcall(fn)
  love.graphics.rectangle = realRectangle
  if not ok then error(err, 0) end
end

local function printAt(calls, tx, ty)
  for _, c in ipairs(calls.prints) do
    if c.tx == tx and c.ty == ty then return c.text end
  end
  return nil
end

local function rectAt(calls, px, py)
  for _, r in ipairs(calls.rects) do
    if r.x == px and r.y == py then return r end
  end
  return nil
end

-- ---------------------------------------------------------------------
-- The happy path, on the pink page (types): Rotom-Wash draws ELECTRIC/WATER,
-- not ELECTRIC/GHOST, in exactly the tile cells the vanilla draw uses.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  T.eq(Gen2FormView.install(fakeMod()), true, "precondition: install succeeds")

  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")

  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = rotom, page = PINK_PAGE, game = { data = DATA } })
  end)

  T.eq(calls.vanillaDraw, 1, "the vanilla draw still ran first")
  T.eq(printAt(calls, 1, 15), "ELECTRIC", "TYPE1 is redrawn, unchanged")
  T.eq(printAt(calls, 1, 16), "WATER",
    "TYPE2's value is redrawn as WATER, not left as vanilla's GHOST")
  T.check(rectAt(calls, 8, 120) ~= nil,
    "TYPE1's tile field (1,15) was blanked first, not just overwritten in place")
  T.check(rectAt(calls, 8, 128) ~= nil, "and so was TYPE2's (1,16)")
end

-- ---------------------------------------------------------------------
-- The blue page (stats): the form's own numbers land in the five value
-- cells, two rows apart starting at row 9, exactly as SummaryMenu.lua's own
-- bluePlacements lays them out.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE", 55)
  local expected = Mon.stats(DATA.pokemon.ROTOM_WASH.baseStats, {}, 55, nil)

  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = rotom, page = BLUE_PAGE, game = { data = DATA } })
  end)

  local function trimmed(n) return tostring(n) end
  T.eq((printAt(calls, 17, 9) or ""):gsub("^%s+", ""), trimmed(expected.attack),
    "ATTACK is redrawn with the form's own number")
  T.eq((printAt(calls, 17, 11) or ""):gsub("^%s+", ""), trimmed(expected.defense),
    "so is DEFENSE")
  T.eq((printAt(calls, 17, 13) or ""):gsub("^%s+", ""), trimmed(expected.specialAttack),
    "so is SPCL.ATK")
  T.eq((printAt(calls, 17, 15) or ""):gsub("^%s+", ""), trimmed(expected.specialDefense),
    "so is SPCL.DEF")
  T.eq((printAt(calls, 17, 17) or ""):gsub("^%s+", ""), trimmed(expected.speed),
    "so is SPEED")

  -- No type text is drawn on the blue page at all.
  T.eq(printAt(calls, 1, 15), nil, "no TYPE1 is drawn on the blue page")
end

-- ---------------------------------------------------------------------
-- Adding a second type where the base had one (Zacian -> Zacian Crowned).
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local zacian = persistentMon("ZACIAN", "RUSTED_SWORD")
  T.eq(zacian.form, "CROWNED", "precondition: the marker landed")

  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = zacian, page = PINK_PAGE, game = { data = DATA } })
  end)

  T.eq(printAt(calls, 1, 15), "FAIRY", "TYPE1 stays FAIRY")
  T.eq(printAt(calls, 1, 16), "STEEL", "TYPE2 is now drawn as STEEL")
end

-- ---------------------------------------------------------------------
-- The reverse: a form with fewer types than the base it draws over --
-- proving the erase path itself, not just its absence of use.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local mon = persistentMon("TWOTYPE", "TEST_ITEM")
  T.eq(mon.form, "SOLO", "precondition: the marker landed")

  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = mon, page = PINK_PAGE, game = { data = DATA } })
  end)

  T.eq(printAt(calls, 1, 15), "GRASS", "TYPE1 becomes the form's only type")
  T.eq(printAt(calls, 1, 16), nil, "no TYPE2 text is drawn")
  local erased = rectAt(calls, 8, 128)
  T.check(erased ~= nil,
    "but the TYPE2 cell IS blanked, erasing whatever the base's own WATER "
      .. "would otherwise still show")
end

-- ---------------------------------------------------------------------
-- A fusion form (Kyurem White), proving src/fusion.lua's own formIdFor is
-- consulted, not only src/persistent.lua's.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local kyurem = fusionMon("KYUREM", "RESHIRAM", 60)
  T.eq(kyurem.form, "WHITE", "precondition: the fusion marker landed")

  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = kyurem, page = PINK_PAGE, game = { data = DATA } })
  end)

  T.eq(printAt(calls, 1, 15), "DRAGON", "TYPE1 unchanged")
  T.eq(printAt(calls, 1, 16), "ICE", "TYPE2 unchanged")
end

-- ---------------------------------------------------------------------
-- The green page (item/moves) never draws types or stats and is left alone.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = rotom, page = GREEN_PAGE, game = { data = DATA } })
  end)
  T.eq(#calls.prints, 0, "no overlay text is drawn on the green page")
  T.eq(#calls.rects, 0, "and nothing is blanked either")
end

-- ---------------------------------------------------------------------
-- The move-detail view and an egg mon are both skipped, the same gates the
-- vanilla class itself applies before it ever reaches a type or a stat.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = rotom, page = BLUE_PAGE, moveDetail = true, game = { data = DATA } })
  end)
  T.eq(#calls.prints, 0, "no overlay is drawn while the move-detail view is open")
end

do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  rotom.isEgg = true
  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = rotom, page = PINK_PAGE, game = { data = DATA } })
  end)
  T.eq(#calls.prints, 0, "no overlay is drawn for an egg")
end

-- ---------------------------------------------------------------------
-- An ordinary Pokemon, no form at all, draws nothing extra -- and neither
-- does a nil mon.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  withRectSpy(calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
      mon = { species = "PIDGEY" }, page = PINK_PAGE, game = { data = DATA } })
  end)
  T.eq(#calls.prints, 0, "an unformed Pokemon gets no overlay")
  T.eq(#calls.rects, 0, "and nothing is blanked")

  calls.prints, calls.rects = {}, {}
  local ok = pcall(withRectSpy, calls, function()
    package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({ mon = nil, page = PINK_PAGE,
      game = { data = DATA } })
  end)
  T.check(ok, "a nil mon does not throw")
  T.eq(#calls.prints, 0, "and draws nothing")
end

-- ---------------------------------------------------------------------
-- Nothing is written to the mon: the whole table is byte-identical before
-- and after a full pink-page-then-blue-page draw.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())

  local mons = {
    persistentMon("ROTOM", "WASHING_MACHINE", 55,
      { dvs = { attack = 9 }, statExp = { special = 9000 } }),
    persistentMon("ZACIAN", "RUSTED_SWORD"),
    fusionMon("KYUREM", "RESHIRAM", 60),
    persistentMon("TWOTYPE", "TEST_ITEM"),
    { species = "PIDGEY", level = 5 },
  }

  for _, mon in ipairs(mons) do
    local before = {}
    for k, v in pairs(mon) do before[k] = v end
    local beforeCount = 0
    for _ in pairs(mon) do beforeCount = beforeCount + 1 end

    for _, page in ipairs({ PINK_PAGE, BLUE_PAGE }) do
      withRectSpy(calls, function()
        package.loaded["src.ui.gen2.SummaryMenu"].drawPanel({
          mon = mon, page = page, game = { data = DATA } })
      end)
    end

    local afterCount = 0
    for k, v in pairs(mon) do
      afterCount = afterCount + 1
      T.eq(v, before[k],
        tostring(mon.species) .. "." .. tostring(k)
          .. " is byte-identical after a full draw")
    end
    T.eq(afterCount, beforeCount,
      tostring(mon.species) .. " gained no new key from being drawn")
  end
end

-- ---------------------------------------------------------------------
-- Idempotency: a second install wraps nothing further.
-- ---------------------------------------------------------------------
do
  local SummaryMenu = stubEngine()
  local vanillaDraw = SummaryMenu.drawPanel

  T.eq(Gen2FormView.install(fakeMod()), true, "first install succeeds")
  T.check(SummaryMenu.drawPanel ~= vanillaDraw, "SummaryMenu.drawPanel was wrapped")

  local wrappedDraw = SummaryMenu.drawPanel
  T.eq(Gen2FormView.install(fakeMod()), true, "a second install still reports success")
  T.eq(SummaryMenu.drawPanel, wrappedDraw, "and wraps SummaryMenu.drawPanel no further")
end

-- ---------------------------------------------------------------------
-- The picture's own install-time guards, isolated from drawPanel's: a
-- SummaryMenu with no drawPic (or with GbcPalette/Palettes unavailable)
-- still gets its types/stats overlay -- the picture fix alone is disabled,
-- said out loud, and nothing about the rest of this module's install fails.
-- ---------------------------------------------------------------------
do
  local SummaryMenu = stubEngine()
  -- stubEngine's own SummaryMenu carries no drawPic at all.
  local mod = fakeMod()
  T.eq(Gen2FormView.install(mod), true,
    "install still succeeds: drawPanel's own overlay does not need a picture seam")
  T.check(SummaryMenu._battleFormsGen2FormView, "the types/stats wrap still installed")
  T.check(not SummaryMenu._battleFormsGen2FormViewPic,
    "but the picture wrap did not, since SummaryMenu.drawPic never existed")
  local found = false
  for _, line in ipairs(mod.logged) do
    if line.msg:find("battle_forms:", 1, true)
        and line.msg:find("picture", 1, true) then found = true end
  end
  T.check(found, "and mod.log is told specifically about the picture, not just "
    .. "a generic install failure")
end

do
  local SummaryMenu = stubEngine()
  SummaryMenu.drawPic = function() end
  package.loaded["src.render.GbcPalette"] = nil
  package.preload["src.render.GbcPalette"] = function() error("no shader module") end
  local mod = fakeMod()
  T.eq(Gen2FormView.install(mod), true,
    "a missing GbcPalette still leaves the rest of install successful")
  T.check(not SummaryMenu._battleFormsGen2FormViewPic,
    "the picture wrap refuses without a palette module to shade or bypass with")
  package.preload["src.render.GbcPalette"] = nil
end

-- ---------------------------------------------------------------------
-- The picture wrap itself, fully stubbed: installs once, wraps no further
-- on a second call, and a draw-time failure inside it falls back to vanilla
-- drawPic rather than leaving the screen blank.
-- ---------------------------------------------------------------------
do
  local function stubEnginePic()
    local SummaryMenu, Chrome, calls = stubEngine()
    calls.vanillaDrawPic = 0
    SummaryMenu.drawPic = function(self)
      calls.vanillaDrawPic = calls.vanillaDrawPic + 1
    end
    package.loaded["src.render.GbcPalette"] = {
      available = function() return false end,
      color = function(colors, i) return (colors and colors[i]) or { 255, 255, 255 } end,
      with = function(_, body) body() end,
    }
    package.loaded["src.world.gen2.Palettes"] = {
      monColors = function() return nil end,
    }
    return SummaryMenu, Chrome, calls
  end

  local SummaryMenu, _, calls = stubEnginePic()
  T.eq(Gen2FormView.install(fakeMod()), true, "precondition: install succeeds")
  T.check(SummaryMenu._battleFormsGen2FormViewPic, "the picture wrap installed this time")
  local wrappedPic = SummaryMenu.drawPic
  T.eq(Gen2FormView.install(fakeMod()), true, "a second install still succeeds")
  T.eq(SummaryMenu.drawPic, wrappedPic, "and wraps SummaryMenu.drawPic no further")

  -- No game.data at all -- formRecordFor has nothing to read a species out
  -- of -- must still leave the screen showing SOMETHING: vanilla's own
  -- drawPic, exactly the fallback drawPanel's own overlay already
  -- guarantees for the identical precondition.
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  local ok = pcall(SummaryMenu.drawPic, { mon = rotom, game = nil })
  T.check(ok, "a missing game/game.data does not throw")
  T.eq(calls.vanillaDrawPic, 1, "and vanilla drawPic still ran")
end

-- ---------------------------------------------------------------------
-- Composition with a mod that has ALREADY wrapped SummaryMenu.drawPic --
-- standing in for National Dex's own src/gen2summary.lua, which draws its
-- OWN (species-level, form-blind) sprite-mod art for a mon this module
-- never asked about. battle_forms declares national_dex a hard dependency
-- (manifest.json), so the loader always installs national_dex first and
-- this module's own wrap always ends up OUTERMOST -- this pins the part of
-- that arrangement that is actually load-bearing: a formed mon is decided
-- HERE regardless of what the wrapped-over implementation would have drawn,
-- and an unformed one is left to whatever that implementation does, National
-- Dex's own art included.
-- ---------------------------------------------------------------------
do
  local SummaryMenu = stubEngine()
  local otherModCalls = 0
  -- Stands in for national_dex's own gen2summary.lua: draws SOMETHING for
  -- every mon it is asked about, formed or not, since its own resolver has
  -- no idea what a battle_forms form is.
  SummaryMenu.drawPic = function(self)
    otherModCalls = otherModCalls + 1
  end
  package.loaded["src.render.GbcPalette"] = {
    available = function() return false end,
    color = function() return { 255, 255, 255 } end,
    with = function(_, body) body() end,
  }
  package.loaded["src.world.gen2.Palettes"] = { monColors = function() return nil end }

  T.eq(Gen2FormView.install(fakeMod()), true,
    "installs cleanly on top of another mod's own drawPic wrap")

  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  local drawn = {}
  local realDraw2 = love.graphics.draw
  love.graphics.draw = function(image, ...)
    if image and image.path then drawn[image.path] = true end
    return realDraw2(image, ...)
  end
  local okDraw = pcall(SummaryMenu.drawPic, { mon = rotom, game = { data = DATA },
    picImage = function(_, path) return path and { path = path } or nil end,
    drawPicBlock = function(self2, image) love.graphics.draw(image, 0, 0) end })
  love.graphics.draw = realDraw2
  T.check(okDraw, "drawing a formed mon over the wrapped-over implementation "
    .. "does not throw")
  T.check(drawn[DATA.pokemon.ROTOM_WASH.spriteFront],
    "a formed mon is decided by THIS module, never reaching the "
      .. "wrapped-over implementation")
  T.eq(otherModCalls, 0,
    "the other mod's own drawPic never even runs for a formed mon")

  otherModCalls, drawn = 0, {}
  local okPlain = pcall(SummaryMenu.drawPic,
    { mon = { species = "PIDGEY" }, game = { data = DATA } })
  T.check(okPlain, "an unformed mon does not throw either")
  T.eq(otherModCalls, 1,
    "but an unformed mon falls through to whatever drew before this "
      .. "module installed -- National Dex's own species-level art included")
end

-- ---------------------------------------------------------------------
-- A guard that refuses must say so out loud (project rule #6).
-- ---------------------------------------------------------------------
do
  stubEngine()
  package.loaded["src.ui.gen2.SummaryMenu"] = { drawPanel = "not a function" }
  local mod = fakeMod()
  T.eq(Gen2FormView.install(mod), false,
    "a SummaryMenu.drawPanel that is not a function refuses rather than patching it")
  local found = false
  for _, line in ipairs(mod.logged) do
    if line.msg:find("battle_forms:", 1, true) then found = true end
  end
  T.check(found, "and says so through mod.log")
end

do
  stubEngine()
  package.loaded["src.ui.gen2.SummaryMenu"] = nil
  package.preload["src.ui.gen2.SummaryMenu"] = function() error("no such module") end
  local mod = fakeMod()
  T.eq(Gen2FormView.install(mod), false, "an unrequireable SummaryMenu refuses cleanly")
  local found = false
  for _, line in ipairs(mod.logged) do
    if line.msg:find("battle_forms:", 1, true) then found = true end
  end
  T.check(found, "and says so")
  package.preload["src.ui.gen2.SummaryMenu"] = nil
end

-- ---------------------------------------------------------------------
-- A DRAW-TIME failure inside the overlay never takes the vanilla draw down
-- with it.
-- ---------------------------------------------------------------------
do
  local SummaryMenu, _, calls = stubEngine()
  Gen2FormView.install(fakeMod())
  local ok = pcall(SummaryMenu.drawPanel, { mon = persistentMon("ROTOM", "WASHING_MACHINE"),
    page = PINK_PAGE, game = nil })
  T.check(ok, "a missing game/game.data does not throw")
  T.eq(calls.vanillaDraw, 1, "and the vanilla draw still ran")
end

for name, value in pairs(savedLoaded) do package.loaded[name] = value end

T.finish("battle_forms_gen2formview")
