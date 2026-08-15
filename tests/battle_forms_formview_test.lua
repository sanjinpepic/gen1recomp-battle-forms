-- The party/summary bug report in the user's own words: "I see unchanged
-- Arceus type in the pokemon team stats view."  A held Flame Plate already
-- gives the battler FIRE typing and a Fire-boosted stat block
-- (src/forms.lua's becomeForm) but the STATS screen reads
-- data.pokemon[mon.species] and shows NORMAL regardless, because
-- mon.species is deliberately never re-keyed.  src/formview.lua closes that
-- gap by drawing the form's numbers over the vanilla ones at draw time --
-- this suite proves it draws the right numbers, on the right rows, for
-- several unrelated form families, that HP and the name are never touched,
-- and above everything else that the mon itself is never written to.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local FormView = dofile(MOD .. "/src/formview.lua")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local Eligibility = dofile(MOD .. "/src/eligibility.lua")
local Stats = require("src.pokemon.Stats")

-- love.graphics is already stubbed globally by tests.modkit
-- (tests/love_stub.lua), the same precondition battle_forms_boxmark_test.lua
-- and battle_forms_hpscale_test.lua rely on.
love = love or _G.love

-- ---------------------------------------------------------------------
-- Fixture data: real pairing tables (data/persistent.lua, data/fusion.lua)
-- extended with a couple of synthetic rows for edge cases no real family in
-- this mod's own roster happens to exercise (a form with NO baseStats, one
-- with NO types, and one that drops a base's second type rather than
-- adding one) -- real species data for everything else, pulled from the
-- actual national dex records this mod ships against (dev/battle_forms_mod/
-- tests/battle_forms_formids_test.lua pins these same ids against the real
-- file), so a family really wired in data/persistent.lua or data/fusion.lua
-- is what is exercised here, not a shape invented for the test.
-- ---------------------------------------------------------------------
local persistentRows = dofile(MOD .. "/data/persistent.lua")
local fusionRows = dofile(MOD .. "/data/fusion.lua")

local DATA = { pokemon = {
  ARCEUS = { name = "ARCEUS",
    baseStats = { hp = 120, attack = 120, defense = 120, speed = 120, special = 120 },
    types = { "NORMAL" } },
  ARCEUS_FIRE = { name = "ARCEUS", form = "FIRE",
    baseStats = { hp = 120, attack = 120, defense = 120, speed = 120, special = 120 },
    types = { "FIRE" } },

  -- Genesect's Drives are cosmetic only (0.27.0's own commit message): the
  -- form record's types and baseStats are byte-for-byte the base's.  Worth
  -- keeping as its own case because it proves the overlay does the right
  -- (visually unremarkable) thing even when the numbers do not move.
  GENESECT = { name = "GENESECT",
    baseStats = { hp = 71, attack = 120, defense = 95, speed = 99, special = 120 },
    types = { "BUG", "STEEL" } },
  GENESECT_DOUSE = { name = "GENESECT", form = "DOUSE",
    baseStats = { hp = 71, attack = 120, defense = 95, speed = 99, special = 120 },
    types = { "BUG", "STEEL" } },

  -- Rotom's appliances: two types both before and after, but the SECOND
  -- one is replaced rather than kept -- the case a naive "only touch types
  -- when the count changes" implementation would get wrong silently.
  ROTOM = { name = "ROTOM",
    baseStats = { hp = 50, attack = 50, defense = 77, speed = 91, special = 95 },
    types = { "ELECTRIC", "GHOST" } },
  ROTOM_WASH = { name = "ROTOM", form = "WASH",
    baseStats = { hp = 50, attack = 65, defense = 107, speed = 86, special = 107 },
    types = { "ELECTRIC", "WATER" } },

  -- Giratina's Origin Forme: the types are IDENTICAL to the base, only the
  -- stats move (attack and defense trade places) -- proves the type box is
  -- redrawn even when it has nothing new to say.
  GIRATINA = { name = "GIRATINA",
    baseStats = { hp = 150, attack = 100, defense = 120, speed = 90, special = 120 },
    types = { "GHOST", "DRAGON" } },
  GIRATINA_ORIGIN = { name = "GIRATINA", form = "ORIGIN",
    baseStats = { hp = 150, attack = 120, defense = 100, speed = 90, special = 120 },
    types = { "GHOST", "DRAGON" } },

  -- Zacian Crowned: the base is single-type and the form gains a second
  -- type outright -- the vanilla screen never drew a TYPE2 row at all for
  -- the base, and this module has to draw one where nothing was.
  ZACIAN = { name = "ZACIAN",
    baseStats = { hp = 92, attack = 130, defense = 115, speed = 138, special = 80 },
    types = { "FAIRY" } },
  ZACIAN_CROWNED = { name = "ZACIAN", form = "CROWNED",
    baseStats = { hp = 92, attack = 150, defense = 115, speed = 148, special = 80 },
    types = { "FAIRY", "STEEL" } },

  -- Kyurem White, a FUSION form rather than a persistent one -- proves the
  -- module resolves through src/fusion.lua too, not only
  -- src/persistent.lua.
  KYUREM = { name = "KYUREM",
    baseStats = { hp = 125, attack = 130, defense = 90, speed = 95, special = 130 },
    types = { "DRAGON", "ICE" } },
  KYUREM_WHITE = { name = "KYUREM", form = "WHITE",
    baseStats = { hp = 125, attack = 120, defense = 90, speed = 95, special = 170 },
    types = { "DRAGON", "ICE" } },
  RESHIRAM = { name = "RESHIRAM",
    baseStats = { hp = 100, attack = 120, defense = 100, speed = 90, special = 150 },
    types = { "DRAGON", "FIRE" } },

  -- Synthetic rows: no real family in this mod's roster ever drops a
  -- second type, so this one is invented to prove the erase path works at
  -- all rather than only ever being exercised by the "add a type" families
  -- above.
  TWOTYPE = { name = "TWOTYPE",
    baseStats = { hp = 50, attack = 50, defense = 50, speed = 50, special = 50 },
    types = { "FIRE", "WATER" } },
  TWOTYPE_SOLO = { name = "TWOTYPE", form = "SOLO",
    baseStats = { hp = 50, attack = 60, defense = 55, speed = 45, special = 70 },
    types = { "GRASS" } },

  -- A record with no `baseStats` and one with no `types` -- the two ways a
  -- form record can exist and still be unusable, both refused rather than
  -- half-applied (src/forms.lua's becomeForm keeps the identical contract).
  BROKENA = { name = "BROKENA", types = { "NORMAL" }, baseStats = { hp = 1, attack = 1, defense = 1, speed = 1, special = 1 } },
  BROKENA_NOTYPES = { name = "BROKENA", form = "X",
    baseStats = { hp = 1, attack = 1, defense = 1, speed = 1, special = 1 } },
  BROKENB = { name = "BROKENB", types = { "NORMAL" }, baseStats = { hp = 1, attack = 1, defense = 1, speed = 1, special = 1 } },
  BROKENB_NOSTATS = { name = "BROKENB", form = "X", types = { "NORMAL" } },
} }

persistentRows.TWOTYPE = { TEST_ITEM = "TWOTYPE_SOLO" }
persistentRows.BROKENA = { ITEM_A = "BROKENA_NOTYPES" }
persistentRows.BROKENB = { ITEM_B = "BROKENB_NOSTATS" }
persistentRows.GHOSTSPECIES = { ITEM_G = "GHOST_NO_RECORD" }

Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
Fusion.bind({ rows = fusionRows })
FormView.bind({ fusion = Fusion, persistent = Persistent })

-- ---------------------------------------------------------------------
-- Mon fixtures, built through the real mark()/settle() path rather than by
-- hand-setting mon.form -- so a wrong assumption about which suffix a form
-- carries fails here first, not silently inside the module under test.
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
-- M.resolve: the pure lookup, tested apart from any drawing.
-- ---------------------------------------------------------------------
do
  local dvs = { hp = 5, attack = 9, defense = 3, speed = 12, special = 6 }
  local statExp = { hp = 2000, attack = 5000, defense = 100, speed = 0, special = 9000 }
  local arceus = persistentMon("ARCEUS", "FLAME_PLATE", 55,
    { dvs = dvs, statExp = statExp })
  T.eq(arceus.form, "FIRE", "precondition: the mark landed the FIRE suffix")

  local form = FormView.resolve(DATA, arceus)
  T.check(form ~= nil, "an Arceus wearing the Flame Plate resolves a form")
  T.eq(form.types[1], "FIRE", "its resolved type is the Plate's, not NORMAL")
  T.eq(form.types[2], nil, "and it has no second type")
  local expected = Stats.calc(DATA.pokemon.ARCEUS_FIRE, 55, dvs, statExp)
  T.eq(form.stats.attack, expected.attack, "the resolved ATTACK matches "
    .. "Stats.calc on the FORM record with this mon's own level/DVs/EVs")
  T.eq(form.stats.hp, expected.hp,
    "the resolved block even carries an hp figure of its own -- unused by "
      .. "the draw path, but proving the whole block came from Stats.calc "
      .. "rather than a partial copy")
end

do
  T.eq(FormView.resolve(DATA, { species = "PIDGEY" }), nil,
    "a mon with no mon.form at all resolves nothing")
  T.eq(FormView.resolve(DATA, { species = "PIDGEY", form = "MEGA" }), nil,
    "a mon.form neither src/fusion.lua nor src/persistent.lua can vouch "
      .. "for resolves nothing (a mega, a primal, a Gigantamax -- all "
      .. "already stripped by src/resolve.lua's sweep before a screen "
      .. "could ever see them)")
  T.eq(FormView.resolve(DATA, nil), nil, "and a nil mon does not throw")
end

do
  local mon = persistentMon("BROKENA", "ITEM_A")
  T.eq(mon.form, "X", "precondition: the marker landed")
  T.eq(FormView.resolve(DATA, mon), nil,
    "a form record with no `types` refuses rather than drawing a blank")
end

do
  local mon = persistentMon("BROKENB", "ITEM_B")
  T.eq(FormView.resolve(DATA, mon), nil,
    "a form record with no `baseStats` refuses rather than crashing "
      .. "Stats.calc")
end

do
  local mon = { species = "GHOSTSPECIES", form = "whatever" }
  mon[Eligibility.STAMP] = "ITEM_G"
  -- Not run through mark()/settle() on purpose: this is the shape a save
  -- can genuinely carry (the marker survived, the record it points at did
  -- not), and settle() already logs that case loudly elsewhere
  -- (src/persistent.lua's own comment) -- resolve() here should just stay
  -- quiet and draw nothing rather than draw half of something.
  T.eq(FormView.resolve(DATA, mon), nil,
    "a formId with no data.pokemon record at all resolves nothing")
end

-- ---------------------------------------------------------------------
-- The draw wrap: engine classes stubbed the same way
-- battle_forms_boxmark_test.lua stubs them, so nothing here touches the
-- real game/src/ui files.
-- ---------------------------------------------------------------------
local savedLoaded = {}
for _, name in ipairs({ "src.ui.SummaryMenu", "src.render.Font" }) do
  savedLoaded[name] = package.loaded[name]
end

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
  local calls = { drawFont = {}, rects = {} }
  local SummaryMenu = {
    draw = function(self)
      calls.vanillaDraw = (calls.vanillaDraw or 0) + 1
    end,
  }
  local Font = {
    draw = function(text, x, y)
      calls.drawFont[#calls.drawFont + 1] = { text = text, x = x, y = y }
    end,
  }
  package.loaded["src.ui.SummaryMenu"] = SummaryMenu
  package.loaded["src.render.Font"] = Font
  return SummaryMenu, Font, calls
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

local function textAt(calls, x, y)
  for _, c in ipairs(calls.drawFont) do
    if c.x == x and c.y == y then return c.text end
  end
  return nil
end

local function rectAt(calls, x, y)
  for _, r in ipairs(calls.rects) do
    if r.x == x and r.y == y then return r end
  end
  return nil
end

-- ---------------------------------------------------------------------
-- The happy path: an Arceus in FIRE form draws FIRE, not NORMAL, and the
-- form's own ATTACK/DEFENSE/SPEED/SPECIAL, in exactly the cells the
-- vanilla draw already used.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  T.eq(FormView.install(fakeMod()), true, "precondition: install succeeds")

  local arceus = persistentMon("ARCEUS", "FLAME_PLATE", 55)
  local expected = Stats.calc(DATA.pokemon.ARCEUS_FIRE, 55, {}, nil)

  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = arceus, page = 1, game = { data = DATA } })
  end)

  T.eq(calls.vanillaDraw, 1, "the vanilla draw still ran first")
  T.eq(textAt(calls, 88, 80), "FIRE", "TYPE1's value is redrawn as FIRE")
  T.check(rectAt(calls, 88, 80) ~= nil, "and the vanilla NORMAL was blanked "
    .. "first, not just overwritten in place")
  T.eq(textAt(calls, 48, 80), ("%3d"):format(expected.attack),
    "ATTACK is redrawn with the form's own number")
  T.eq(textAt(calls, 48, 96), ("%3d"):format(expected.defense), "so is DEFENSE")
  T.eq(textAt(calls, 48, 112), ("%3d"):format(expected.speed), "so is SPEED")
  T.eq(textAt(calls, 48, 128), ("%3d"):format(expected.special), "so is SPECIAL")

  -- Arceus has one type both before and after: no TYPE2 label or value text
  -- is ever drawn for it. The area may still be blanked (the same harmless
  -- erase a base that DID have two types needs, see the TWOTYPE_SOLO case
  -- below) -- what matters is that no stale or invented text lands there.
  T.eq(textAt(calls, 80, 88), nil, "no TYPE2 label is drawn for a single-type form")
  T.eq(textAt(calls, 88, 96), nil, "and no TYPE2 value either")
end

-- ---------------------------------------------------------------------
-- HP is never drawn by this module at all -- it lives in the HP bar, a
-- separate seam this module does not reach.  Proven by checking no Font
-- call or rectangle ever lands on the HP number's own cell (96,32) or the
-- HP bar's row.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local arceus = persistentMon("ARCEUS", "FLAME_PLATE")
  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = arceus, page = 1, game = { data = DATA } })
  end)
  T.eq(textAt(calls, 96, 32), nil,
    "the HP numbers cell (SummaryMenu.lua's own %3d/%3d at 96,32) is never touched")
  for _, r in ipairs(calls.rects) do
    T.check(not (r.y >= 24 and r.y < 40),
      "no rectangle lands on the HP bar's own row (y=24..40)")
  end
end

-- ---------------------------------------------------------------------
-- Adding a second type where the base had one (Zacian -> Zacian Crowned):
-- the label AND the value are drawn, where vanilla drew neither.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local zacian = persistentMon("ZACIAN", "RUSTED_SWORD")
  T.eq(zacian.form, "CROWNED", "precondition: the marker landed")

  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = zacian, page = 1, game = { data = DATA } })
  end)

  T.eq(textAt(calls, 88, 80), "FAIRY", "TYPE1 stays FAIRY")
  T.eq(textAt(calls, 80, 88), "TYPE2/", "a TYPE2 label is now drawn")
  T.eq(textAt(calls, 88, 96), "STEEL", "with STEEL as its value")
end

-- ---------------------------------------------------------------------
-- The reverse: a form with fewer types than the record it is drawn over
-- would have had. No real family in this mod's roster does this (see the
-- fixture's own comment), so this is the synthetic TWOTYPE/TWOTYPE_SOLO
-- pair -- proving the erase path itself, not just its absence of use.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local mon = persistentMon("TWOTYPE", "TEST_ITEM")
  T.eq(mon.form, "SOLO", "precondition: the marker landed")

  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = mon, page = 1, game = { data = DATA } })
  end)

  T.eq(textAt(calls, 88, 80), "GRASS", "TYPE1 becomes the form's only type")
  T.eq(textAt(calls, 80, 88), nil, "no TYPE2 label is drawn")
  T.eq(textAt(calls, 88, 96), nil, "no TYPE2 value is drawn")
  local erased = rectAt(calls, 80, 88)
  T.check(erased ~= nil, "but the TYPE2 area IS blanked, erasing whatever "
    .. "a base with two types would otherwise still show")
  T.eq(erased.w, 72, "wide enough to cover both the label and the value column")
  T.eq(erased.h, 16, "and tall enough to cover both rows")
end

-- ---------------------------------------------------------------------
-- Rotom's appliances: the type COUNT does not change (two before, two
-- after) but the second type is a different one -- the case a "only touch
-- TYPE2 when the count changes" bug would get wrong.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  T.eq(rotom.form, "WASH", "precondition: the marker landed")

  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = rotom, page = 1, game = { data = DATA } })
  end)

  T.eq(textAt(calls, 88, 80), "ELECTRIC", "TYPE1 is unchanged")
  T.eq(textAt(calls, 88, 96), "WATER",
    "TYPE2's value is redrawn as WATER, not left as vanilla's GHOST")
end

-- ---------------------------------------------------------------------
-- Giratina's Origin Forme: types identical to the base, only the stat
-- block moves.  Proves the type box is still redrawn even with nothing new
-- to say, and that a stat SWAP (attack and defense trade numbers) lands in
-- the right cells rather than each other's.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local giratina = persistentMon("GIRATINA", "GRISEOUS_ORB", 100)
  T.eq(giratina.form, "ORIGIN", "precondition: the marker landed")
  local expected = Stats.calc(DATA.pokemon.GIRATINA_ORIGIN, 100, {}, nil)

  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = giratina, page = 1, game = { data = DATA } })
  end)

  T.eq(textAt(calls, 88, 80), "GHOST", "TYPE1 is redrawn, byte-identical to the base")
  T.eq(textAt(calls, 88, 96), "DRAGON", "so is TYPE2")
  T.eq(textAt(calls, 48, 80), ("%3d"):format(expected.attack),
    "ATTACK carries Origin Forme's own (higher) number")
  T.eq(textAt(calls, 48, 96), ("%3d"):format(expected.defense),
    "DEFENSE carries Origin Forme's own (lower) number -- not swapped with ATTACK")
end

-- ---------------------------------------------------------------------
-- A fusion form (Kyurem White), not a persistent one -- proves
-- src/fusion.lua's own formIdFor is consulted, not only
-- src/persistent.lua's.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local kyurem = fusionMon("KYUREM", "RESHIRAM", 60)
  T.eq(kyurem.form, "WHITE", "precondition: the fusion marker landed")
  local expected = Stats.calc(DATA.pokemon.KYUREM_WHITE, 60, {}, nil)

  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = kyurem, page = 1, game = { data = DATA } })
  end)

  T.eq(textAt(calls, 88, 80), "DRAGON", "TYPE1 unchanged")
  T.eq(textAt(calls, 88, 96), "ICE", "TYPE2 unchanged")
  T.eq(textAt(calls, 48, 128), ("%3d"):format(expected.special),
    "SPECIAL carries White Kyurem's own (higher) number")
end

-- ---------------------------------------------------------------------
-- A cosmetic-only form (Genesect's Douse Drive): the numbers do not move,
-- but the overlay still runs -- proving it draws the identical value
-- rather than skipping the mon because "nothing changed".
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local genesect = persistentMon("GENESECT", "DOUSE_DRIVE")
  T.eq(genesect.form, "DOUSE", "precondition: the marker landed")

  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = genesect, page = 1, game = { data = DATA } })
  end)

  T.eq(textAt(calls, 88, 80), "BUG", "TYPE1 is redrawn even though it did not change")
  T.eq(textAt(calls, 88, 96), "STEEL", "and so is TYPE2")
end

-- ---------------------------------------------------------------------
-- Page 2 (EXP and moves) never draws types or stats and is left alone.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  local arceus = persistentMon("ARCEUS", "FLAME_PLATE")
  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = arceus, page = 2, game = { data = DATA } })
  end)
  T.eq(#calls.drawFont, 0, "no overlay text is drawn on page 2")
  T.eq(#calls.rects, 0, "and nothing is blanked either")
end

-- ---------------------------------------------------------------------
-- An ordinary Pokemon, no form at all, draws nothing extra -- and neither
-- does a nil mon, malformed input the engine itself should never produce
-- but a wrapper still has to survive.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())
  withRectSpy(calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({
      mon = { species = "PIDGEY" }, page = 1, game = { data = DATA } })
  end)
  T.eq(#calls.drawFont, 0, "an unformed Pokemon gets no overlay")
  T.eq(#calls.rects, 0, "and nothing is blanked")

  calls.drawFont, calls.rects = {}, {}
  local ok = pcall(withRectSpy, calls, function()
    package.loaded["src.ui.SummaryMenu"].draw({ mon = nil, page = 1, game = { data = DATA } })
  end)
  T.check(ok, "a nil mon does not throw")
  T.eq(#calls.drawFont, 0, "and draws nothing")
end

-- ---------------------------------------------------------------------
-- Nothing is written. The mon's own key set and every value are
-- byte-identical before and after a full page-1 AND page-2 draw, across
-- every family exercised above -- not just "the fields we happened to
-- check", the whole table.
-- ---------------------------------------------------------------------
do
  local _, _, calls = stubEngine()
  FormView.install(fakeMod())

  local mons = {
    persistentMon("ARCEUS", "FLAME_PLATE", 55,
      { dvs = { attack = 9 }, statExp = { special = 9000 } }),
    persistentMon("ZACIAN", "RUSTED_SWORD"),
    persistentMon("ROTOM", "WASHING_MACHINE"),
    persistentMon("GIRATINA", "GRISEOUS_ORB", 100),
    persistentMon("GENESECT", "DOUSE_DRIVE"),
    fusionMon("KYUREM", "RESHIRAM", 60),
    persistentMon("TWOTYPE", "TEST_ITEM"),
    { species = "PIDGEY", level = 5 },
  }

  for _, mon in ipairs(mons) do
    local before = {}
    for k, v in pairs(mon) do before[k] = v end
    local beforeCount = 0
    for _ in pairs(mon) do beforeCount = beforeCount + 1 end

    for _, page in ipairs({ 1, 2 }) do
      withRectSpy(calls, function()
        package.loaded["src.ui.SummaryMenu"].draw({
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
-- Idempotency: a second install wraps nothing further and still reports
-- success, the same contract src/boxmark.lua and src/menu.lua keep.
-- ---------------------------------------------------------------------
do
  local SummaryMenu = stubEngine()
  local vanillaDraw = SummaryMenu.draw

  T.eq(FormView.install(fakeMod()), true, "first install succeeds")
  T.check(SummaryMenu.draw ~= vanillaDraw, "SummaryMenu.draw was wrapped")

  local wrappedDraw = SummaryMenu.draw
  T.eq(FormView.install(fakeMod()), true, "a second install still reports success")
  T.eq(SummaryMenu.draw, wrappedDraw, "and wraps SummaryMenu.draw no further")
end

-- ---------------------------------------------------------------------
-- A guard that refuses must say so out loud (project rule #6).
-- ---------------------------------------------------------------------
do
  stubEngine()
  package.loaded["src.ui.SummaryMenu"] = { draw = "not a function" }
  local mod = fakeMod()
  T.eq(FormView.install(mod), false,
    "a SummaryMenu.draw that is not a function refuses rather than patching it")
  local found = false
  for _, line in ipairs(mod.logged) do
    if line.msg:find("battle_forms:", 1, true) then found = true end
  end
  T.check(found, "and says so through mod.log")
end

do
  stubEngine()
  package.loaded["src.ui.SummaryMenu"] = nil
  package.preload["src.ui.SummaryMenu"] = function() error("no such module") end
  local mod = fakeMod()
  T.eq(FormView.install(mod), false, "an unrequireable SummaryMenu refuses cleanly")
  local found = false
  for _, line in ipairs(mod.logged) do
    if line.msg:find("battle_forms:", 1, true) then found = true end
  end
  T.check(found, "and says so")
  package.preload["src.ui.SummaryMenu"] = nil
end

-- ---------------------------------------------------------------------
-- A DRAW-TIME failure inside the overlay (a malformed self, or a resolve()
-- that somehow throws) never takes the vanilla draw down with it -- the
-- wrapper always calls the vanilla function first and pcalls only its own
-- half.
-- ---------------------------------------------------------------------
do
  local SummaryMenu, _, calls = stubEngine()
  FormView.install(fakeMod())
  -- game.data missing entirely: M.resolve gets nil for `data` and must not
  -- throw trying to index it.
  local ok = pcall(SummaryMenu.draw, { mon = persistentMon("ARCEUS", "FLAME_PLATE"),
    page = 1, game = nil })
  T.check(ok, "a missing game/game.data does not throw")
  T.eq(calls.vanillaDraw, 1, "and the vanilla draw still ran")
end

for name, value in pairs(savedLoaded) do package.loaded[name] = value end

T.finish("battle_forms_formview")
