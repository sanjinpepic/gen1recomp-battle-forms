-- src/formicons.lua: a formed Pokemon's PARTY LIST icon, on both games, via
-- one shared pokemon.icon hook subscription rather than a wrapped drawIcon.
-- This suite drives the REAL, hook-augmented engine classes
-- (game/src/ui/PartyMenu.lua's free-function drawIcon on Red,
-- game/src/ui/gen2/PartyMenu.lua's method on Gold) rather than hand-built
-- stand-ins, because a fixture that reimplements drawIcon's own quad/
-- palette/marker logic could pass while the real class does something else
-- entirely -- the exact trap this repo has hit before (see
-- battle_forms_gen2formview_test.lua's own header on drawPanel vs draw).
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local FormIcons = dofile(MOD .. "/src/formicons.lua")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local FormResolve = dofile(MOD .. "/src/formresolve.lua")
local Eligibility = dofile(MOD .. "/src/eligibility.lua")

-- love.graphics/love.filesystem are already stubbed globally by
-- tests.modkit (tests/love_stub.lua); love.filesystem.write is this suite's
-- own hand on "what exists on disk", the same in-memory table
-- src.render.Assets.exists reads through love.filesystem.getInfo.
love = love or _G.love

local Runtime = require("src.mods.Runtime")
local Hooks = require("src.mods.Hooks")

local persistentRows = dofile(MOD .. "/data/persistent.lua")
local fusionRows = dofile(MOD .. "/data/fusion.lua")

-- Real national-dex shape: every alternate-form record carries its own
-- `.form` suffix (confirmed against dev/national_dex_mod/data/species/
-- generated/national.lua's own ROTOM_WASH entry, `form = "WASH"`), the
-- field src/formicons.lua's own formSuffix() reads to name the icon file.
local DATA = { pokemon = {
  ROTOM = { name = "ROTOM", form = nil,
    baseStats = { hp = 50, attack = 50, defense = 77, speed = 91,
                  specialAttack = 95, specialDefense = 95 },
    types = { "ELECTRIC", "GHOST" } },
  ROTOM_WASH = { name = "ROTOM", form = "WASH",
    baseStats = { hp = 50, attack = 65, defense = 107, speed = 86,
                  specialAttack = 120, specialDefense = 95 },
    types = { "ELECTRIC", "WATER" } },
  ROTOM_HEAT = { name = "ROTOM", form = "HEAT",
    baseStats = { hp = 50, attack = 65, defense = 107, speed = 86,
                  specialAttack = 120, specialDefense = 95 },
    types = { "ELECTRIC", "FIRE" } },
  -- A form record with no `.form` field at all -- the shape an older or
  -- unrelated pairing table's target could carry -- proving the suffix
  -- lookup refuses rather than guessing "" or nil-concatenating.
  BROKENA = { name = "BROKENA", types = { "NORMAL" },
    baseStats = { hp = 1, attack = 1, defense = 1, speed = 1,
                  specialAttack = 1, specialDefense = 1 } },
  BROKENA_NOFORM = { name = "BROKENA",
    baseStats = { hp = 1, attack = 1, defense = 1, speed = 1,
                  specialAttack = 1, specialDefense = 1 } },
} }
persistentRows.BROKENA = { ITEM_A = "BROKENA_NOFORM" }

Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
Fusion.bind({ rows = fusionRows })
FormResolve.bind({ fusion = Fusion, persistent = Persistent })
FormIcons.bind({ resolve = FormResolve })

local function persistentMon(species, itemId, level, extra)
  local m = { species = species, level = level or 50, dvs = {}, statExp = {} }
  for k, v in pairs(extra or {}) do m[k] = v end
  m[Eligibility.STAMP] = itemId
  Persistent.mark(DATA, m)
  return m
end

local function fakeMod(hooks)
  local logged = {}
  return {
    log = {
      error = function(_, fmt, ...) logged[#logged + 1] =
        { level = "error", msg = fmt:format(...) } end,
      warn = function(_, fmt, ...) logged[#logged + 1] =
        { level = "warn", msg = fmt:format(...) } end,
    },
    logged = logged,
    hooks = { wrap = function(_, name, callback, priority)
      return hooks:wrap(name, callback, priority, "battle_forms")
    end },
  }
end

-- ---------------------------------------------------------------------
-- The one real install this suite performs on the shared FormIcons module,
-- against a Hooks chain of its own (never the process-wide Runtime.hooks,
-- so this suite's subscription cannot collide with, or outlive, any other
-- test file's).  Every later section either drives THIS installed hook
-- (Runtime.hooks pointed at it) or asks src/formicons.lua's own pure
-- M.resolvePath directly, with no install involved at all.
-- ---------------------------------------------------------------------
local hooks = Hooks.new()
local mainMod = fakeMod(hooks)
T.eq(FormIcons.install(mainMod), true, "install resolves the real Assets module and wraps pokemon.icon")
T.eq(#(hooks.chains["pokemon.icon"] or {}), 1, "exactly one link joined the chain")

-- ---------------------------------------------------------------------
-- Idempotency: a second install call on the SAME module adds nothing
-- further -- there is no class to stamp a marker on the way
-- src/gen2formview.lua's own wraps do, so this is the flag itself, proven
-- against the real chain rather than only inferred from the flag's name.
-- ---------------------------------------------------------------------
do
  T.eq(FormIcons.install(mainMod), true, "a second install still reports success")
  T.eq(#(hooks.chains["pokemon.icon"] or {}), 1, "and adds no second link")
end

-- ---------------------------------------------------------------------
-- M.resolvePath, exercised directly: the pure decision, with a `next` this
-- suite controls so a pass-through case can be told apart from a real
-- answer without any hook, class or love stub in the loop at all.
-- ---------------------------------------------------------------------
local function ranNext(vanillaPath, ctx)
  local calls = 0
  local function next(path, c)
    calls = calls + 1
    return path
  end
  local result = FormIcons.resolvePath(next, vanillaPath, ctx)
  return result, calls
end

do
  local result, calls = ranNext("assets/sets/icons/PIDGEY.png",
    { species = "PIDGEY", mon = { species = "PIDGEY" }, data = DATA })
  T.eq(result, "assets/sets/icons/PIDGEY.png", "an unformed mon answers next's own path")
  T.eq(calls, 1, "and next() was actually called -- this is a pass-through, not a guess")
end

do
  local result, calls = ranNext("assets/sets/icons/ROTOM.png",
    { species = "ROTOM", mon = nil, data = DATA })
  T.eq(calls, 1, "a nil mon falls straight through to next")
  T.eq(result, "assets/sets/icons/ROTOM.png", "unchanged")
end

do
  -- No file registered under the derived candidate name -- the ordinary
  -- "this form has no real icon" case, true for 336 of this mod's 364.
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  local result, calls = ranNext("assets/sets/icons/ROTOM.png",
    { species = "ROTOM", mon = rotom, data = DATA })
  T.eq(calls, 1, "a candidate that does not exist on disk still falls through to next")
  T.eq(result, "assets/sets/icons/ROTOM.png", "unchanged")
end

do
  -- The positive case, proven with the real Assets.exists reading the real
  -- love.filesystem stub rather than a mocked existence check.
  love.filesystem.write("assets/sets/icons/ROTOM_WASH.png", "fake-png-bytes")
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  local result, calls = ranNext("assets/sets/icons/ROTOM.png",
    { species = "ROTOM", mon = rotom, data = DATA })
  T.eq(result, "assets/sets/icons/ROTOM_WASH.png",
    "a form with a verified real icon file answers with ITS OWN path")
  T.eq(calls, 0, "and next() was never called -- this is a real answer, not a fallback")
end

do
  -- The guard the header describes: a path that does not end in
  -- "<species>.png" is not this module's own naming convention (a vanilla
  -- ROM icon, a different icon mod's own file), so the string surgery must
  -- refuse rather than build a candidate from an unrelated filename.  A file
  -- is deliberately planted at the WRONG-directory candidate this guard
  -- must reject (cache/ROTOM_WASH.png) as well as the right one, so this
  -- fails if the stem check is ever dropped and the existence check alone
  -- is left to carry it -- the existence check would happily confirm the
  -- wrong-directory guess too.
  love.filesystem.write("assets/sets/icons/ROTOM_WASH.png", "fake-png-bytes")
  love.filesystem.write("cache/ROTOM_WASH.png", "should never be read either")
  local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
  local result, calls = ranNext("cache/pokeicon_0479.png",
    { species = "ROTOM", mon = rotom, data = DATA })
  T.eq(calls, 1, "a vanilla-shaped path (not \"<species>.png\") is refused, not guessed from")
  T.eq(result, "cache/pokeicon_0479.png", "unchanged")
end

do
  -- A form record with no `.form` field: formSuffix has nothing to name a
  -- file with, so this refuses rather than building "BROKENA_nil.png".
  love.filesystem.write("assets/sets/icons/BROKENA_nil.png", "should never be read")
  local mon = persistentMon("BROKENA", "ITEM_A")
  local result, calls = ranNext("assets/sets/icons/BROKENA.png",
    { species = "BROKENA", mon = mon, data = DATA })
  T.eq(calls, 1, "a form record with no .form suffix falls through to next")
  T.eq(result, "assets/sets/icons/BROKENA.png", "unchanged")
end

do
  local result, calls = ranNext("assets/sets/icons/ROTOM.png", "not-a-table")
  T.eq(calls, 1, "a non-table ctx does not throw and falls through to next")
  T.eq(result, "assets/sets/icons/ROTOM.png", "unchanged")
end

-- ---------------------------------------------------------------------
-- Gold: the real, hook-augmented game/src/ui/gen2/PartyMenu.lua, driven
-- through PartyMenu:drawIcon exactly as the live party list calls it.
-- Runtime.hooks is pointed at this suite's own already-installed chain for
-- the rest of the file.
-- ---------------------------------------------------------------------
local savedHooks = Runtime.hooks
Runtime.hooks = hooks

do
  love.filesystem.write("assets/sets/icons_gen2/ROTOM_WASH.png", "fake-png-bytes")
  love.filesystem.write("assets/sets/icons_gen2/ROTOM_HEAT.png", "fake-png-bytes")

  local seenColors = {}
  package.loaded["src.render.GbcPalette"] = {
    available = function() return true end,
    color = function(colors, i) return (colors and colors[i]) or { 255, 255, 255 } end,
    with = function(colors, body) seenColors[#seenColors + 1] = colors; body() end,
  }

  local RealPartyMenu = require("src.ui.gen2.PartyMenu")
  local PARTY_COLORS = { { 10, 20, 30 }, { 40, 50, 60 }, { 70, 80, 90 }, { 100, 110, 120 } }
  local markerImage = { path = "held-marker", getDimensions = function() return 16, 8 end }

  local function partyMenu()
    return setmetatable({
      game = { data = DATA },
      icons = {
        species = { ROTOM = "SHEET_ROTOM", PIDGEY = "SHEET_PIDGEY" },
        icons = {
          SHEET_ROTOM = { image = "assets/sets/icons_gen2/ROTOM.png" },
          SHEET_PIDGEY = { image = "assets/sets/icons_gen2/PIDGEY.png" },
        },
        heldItem = { image = "marker.png" },
      },
      iconCache = {},
      clock = 0,
      palettes = { partyMenu = { PARTY_COLORS } },
      heldMarkerImage = function() return markerImage end,
    }, RealPartyMenu)
  end

  local function drawnPaths(fn)
    local seen = {}
    local realDraw = love.graphics.draw
    love.graphics.draw = function(image, ...)
      if image and image.path then seen[image.path] = true end
      if image == markerImage then seen["<marker>"] = true end
      return realDraw(image, ...)
    end
    local fillRects = 0
    local realRect = love.graphics.rectangle
    love.graphics.rectangle = function(mode, ...)
      if mode == "fill" then fillRects = fillRects + 1 end
      return realRect and realRect(mode, ...)
    end
    local ok, err = pcall(fn)
    love.graphics.draw = realDraw
    love.graphics.rectangle = realRect
    if not ok then error(err, 0) end
    return seen, fillRects
  end

  do
    local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
    rotom.item = "WASHING_MACHINE"
    local self = partyMenu()
    seenColors = {}
    local seen, fillRects = drawnPaths(function()
      RealPartyMenu.drawIcon(self, rotom, 0, 0)
    end)
    T.check(seen["assets/sets/icons_gen2/ROTOM_WASH.png"],
      "vanilla PartyMenu:drawIcon drew Rotom-Wash's OWN real icon sheet -- "
        .. "the bug report src/gen2formview.lua's own removed hack used to fix")
    T.check(not seen["assets/sets/icons_gen2/ROTOM.png"],
      "and never the base species' own icon")
    T.check(seen["<marker>"],
      "the held-item marker still drew -- vanilla's own drawIcon, not this "
        .. "module, owns that seam")
    T.eq(fillRects, 0,
      "no backing rectangle was painted -- vanilla drawIcon never fills one "
        .. "behind a row icon, and nothing here wraps drawIcon to add one")
    T.check(#seenColors > 0, "GbcPalette.with actually ran")
    T.eq(seenColors[#seenColors], PARTY_COLORS,
      "shaded with the party list's own shared palette "
        .. "(self.palettes.partyMenu[1]) -- vanilla's own read, not a colour "
        .. "this module supplied")
  end

  do
    -- Two DIFFERENT forms of the SAME base species, back to back on one
    -- instance: proves the answer is keyed off the mon actually drawn, not
    -- cached or confused between rows.
    local wash = persistentMon("ROTOM", "WASHING_MACHINE")
    local heat = persistentMon("ROTOM", "MICROWAVE_OVEN")
    local self = partyMenu()
    local seen = drawnPaths(function()
      RealPartyMenu.drawIcon(self, wash, 0, 0)
      RealPartyMenu.drawIcon(self, heat, 16, 0)
    end)
    T.check(seen["assets/sets/icons_gen2/ROTOM_WASH.png"], "the first row drew Wash's icon")
    T.check(seen["assets/sets/icons_gen2/ROTOM_HEAT.png"], "the second row drew Heat's icon")
  end

  do
    -- A form with no real icon built for it: vanilla draws the base
    -- species' own icon, untouched -- no battle-art fallback of any kind.
    local plain = { species = "PIDGEY", level = 5, dvs = {}, statExp = {} }
    local self = partyMenu()
    local seen = drawnPaths(function() RealPartyMenu.drawIcon(self, plain, 0, 0) end)
    T.check(seen["assets/sets/icons_gen2/PIDGEY.png"],
      "an ordinary Pokemon still draws its own base icon, unaffected by this hook")
  end

  -- ---------------------------------------------------------------------
  -- The player's own report: a held-item form's party icon stays the base
  -- species until the Pokemon is thrown into a battle, because
  -- src/ui/gen2/HeldItemMenu.lua's real GIVE writes mon.item directly and
  -- fires no event this mod can hook (src/persistent.lua's own header on
  -- M.formIdFor), so mon.form is never set outside a battle. Every other
  -- case in this section used persistentMon(), which calls Persistent.mark
  -- and so ALWAYS leaves mon.form set -- none of them, and no case anywhere
  -- else in this file, actually drove the Gen 2 mon.item-first read with
  -- mon.form left nil, which is the one shape a fresh GIVE actually
  -- produces. This is that case, and it is what src/formresolve.lua's own
  -- "never gate on mon.form" guarantee exists to cover.
  -- ---------------------------------------------------------------------
  do
    Persistent.bind({ eligibility = Eligibility, rows = persistentRows, gen2 = true })
    local freshlyGiven = { species = "ROTOM", level = 50, dvs = {}, statExp = {},
                           item = "WASHING_MACHINE" }
    T.eq(freshlyGiven.form, nil,
      "precondition: nothing has ever marked this mon -- a bare GIVE, no battle yet")
    T.eq(freshlyGiven[Eligibility.STAMP], nil,
      "and the Gen 1 bag stamp was never written either -- mon.item is the "
        .. "only claim this mon carries")

    local self = partyMenu()
    local seen = drawnPaths(function()
      RealPartyMenu.drawIcon(self, freshlyGiven, 0, 0)
    end)
    T.check(seen["assets/sets/icons_gen2/ROTOM_WASH.png"],
      "the party icon shows Rotom-Wash on sight, with no battle needed first "
        .. "-- the exact gap the player reported")
    T.check(not seen["assets/sets/icons_gen2/ROTOM.png"],
      "and never falls back to the base species merely because mon.form was nil")

    Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
  end

  -- ---------------------------------------------------------------------
  -- The regression this hook exists to catch: a form WITH a real icon must
  -- never silently draw the base species' instead.  Proven both ways --
  -- with the hook installed (passes) and with it removed, simulating
  -- exactly what a silent-fallback bug would look like (the same assertion
  -- fails), so this is not a vacuous check.
  -- ---------------------------------------------------------------------
  do
    local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
    local self = partyMenu()
    local seen = drawnPaths(function() RealPartyMenu.drawIcon(self, rotom, 0, 0) end)
    T.check(seen["assets/sets/icons_gen2/ROTOM_WASH.png"],
      "with the hook installed, Rotom-Wash's own icon is what actually drew")
  end
  do
    -- Same mon, same instance shape, hook chain emptied -- the state a
    -- silent fallback (a broken candidate match, a hook that never
    -- installed) would leave behind.
    Runtime.hooks = Hooks.new()
    local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
    local self = partyMenu()
    local seen = drawnPaths(function() RealPartyMenu.drawIcon(self, rotom, 0, 0) end)
    T.check(not seen["assets/sets/icons_gen2/ROTOM_WASH.png"],
      "with no pokemon.icon subscriber, the SAME mon falls back to the base "
        .. "species' icon -- proving the positive assertion above is not "
        .. "vacuously true")
    T.check(seen["assets/sets/icons_gen2/ROTOM.png"], "and draws the base icon instead")
    Runtime.hooks = hooks
  end

  package.loaded["src.render.GbcPalette"] = nil
end

-- ---------------------------------------------------------------------
-- Red: the free-function game/src/ui/PartyMenu.lua drawIcon, the same
-- pokemon.icon seam through a different caller (src/ui/PartyMenu.lua:227).
-- Gen 1 had NO fix at all before this module -- src/formview.lua's own
-- header says so outright ("the party list draws a nickname, a level and
-- an HP bar and nothing else... no second seam to wrap for it", referring
-- to the STATS overlay; the icon itself was simply never addressed).
-- ---------------------------------------------------------------------
do
  love.filesystem.write("assets/sets/icons/ROTOM_WASH.png", "fake-png-bytes")

  local RealPartyMenu = require("src.ui.PartyMenu")

  local function drawnPaths(fn)
    local seen = {}
    local realDraw = love.graphics.draw
    love.graphics.draw = function(image, ...)
      if image and image.path then seen[image.path] = true end
      return realDraw(image, ...)
    end
    local ok, err = pcall(fn)
    love.graphics.draw = realDraw
    if not ok then error(err, 0) end
    return seen
  end

  do
    local rotom = persistentMon("ROTOM", "WASHING_MACHINE")
    local game = { data = { pokemon = DATA.pokemon, icons = {
      bySpecies = { ROTOM = { image = "assets/sets/icons/ROTOM.png" } },
    } } }
    local seen = drawnPaths(function()
      RealPartyMenu.drawIcon(game, rotom, 0, 0, false, 0)
    end)
    T.check(seen["assets/sets/icons/ROTOM_WASH.png"],
      "Red's own party list drew Rotom-Wash's real icon file, whole, at its "
        .. "own size -- the same gap Gold had, now closed on both games by "
        .. "the one hook subscription")
    T.check(not seen["assets/sets/icons/ROTOM.png"], "and never the base species' own icon")
  end

  do
    local plain = { species = "PIDGEY", level = 5, dvs = {}, statExp = {} }
    local game = { data = { pokemon = DATA.pokemon, icons = {
      bySpecies = { PIDGEY = { image = "assets/sets/icons/PIDGEY.png" } },
    } } }
    local seen = drawnPaths(function()
      RealPartyMenu.drawIcon(game, plain, 0, 0, false, 0)
    end)
    T.check(seen["assets/sets/icons/PIDGEY.png"],
      "an ordinary Pokemon on Red still draws its own base icon")
  end
end

Runtime.hooks = savedHooks

-- ---------------------------------------------------------------------
-- The install-time guard: a host with no src.render.Assets at all disables
-- this module rather than failing with a raw require error, and says so.
-- A FRESH load of the module -- the shared `FormIcons` above is already
-- installed, and its own `installed` flag would skip this check entirely.
-- ---------------------------------------------------------------------
do
  local FreshFormIcons = dofile(MOD .. "/src/formicons.lua")
  FreshFormIcons.bind({ resolve = FormResolve })
  local savedAssets = package.loaded["src.render.Assets"]
  -- A shape src.render.Assets has changed into, not a require failure:
  -- simpler to stub deterministically than fighting require's own "loop or
  -- previous error loading module" caching of a genuinely failed load, and
  -- M.install's own guard (`type(Assets.exists) ~= "function"`) refuses on
  -- exactly this shape for exactly the same reason either way.
  package.loaded["src.render.Assets"] = {}
  local freshHooks = Hooks.new()
  local mod = fakeMod(freshHooks)
  T.eq(FreshFormIcons.install(mod), false,
    "install refuses when src.render.Assets has no exists() to check against")
  T.eq(#(freshHooks.chains["pokemon.icon"] or {}), 0, "and wraps nothing")
  local found = false
  for _, line in ipairs(mod.logged) do
    if line.msg:find("battle_forms:", 1, true) then found = true end
  end
  T.check(found, "and says so out loud (project rule 6)")
  package.loaded["src.render.Assets"] = savedAssets
end

T.finish("battle_forms_formicons")
