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
    types = { "ELECTRIC", "GHOST" } },
  -- Four DIFFERENT non-hp values on purpose (real Rotom-Wash repeats 107
  -- twice): a row-order bug that swaps two of the five blue-page cells would
  -- pass silently against equal values, the same reasoning
  -- battle_forms_formview_test.lua's Giratina fixture is built on.
  ROTOM_WASH = { name = "ROTOM", form = "WASH",
    baseStats = { hp = 50, attack = 65, defense = 107, speed = 86,
                  specialAttack = 120, specialDefense = 95 },
    types = { "ELECTRIC", "WATER" } },

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

  Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
end

-- ---------------------------------------------------------------------
-- The draw wrap: the engine class stubbed the same way
-- battle_forms_formview_test.lua stubs Gen 1's, so nothing here touches the
-- real game/src/ui/gen2/SummaryMenu.lua.
-- ---------------------------------------------------------------------
local savedLoaded = {}
for _, name in ipairs({ "src.ui.gen2.SummaryMenu", "src.ui.gen2.Chrome" }) do
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
