-- The fusion partner boxed in the PC (src/fusion.lua's M.HELD) reads as an
-- ordinary Pokemon everywhere the engine draws one, so a player can RELEASE
-- it by accident with no way back for the fusion it silently ends.  This
-- suite proves the marker that says otherwise: where it appears, where it
-- does not, that it writes nothing, and that a shape the engine no longer
-- offers is refused out loud rather than patched over.
--
-- Two engine seams, tested the way src/menu.lua's own wraps are tested
-- elsewhere in this project (battle_forms_diag_test.lua, battle_forms_adopt_
-- test.lua): the real classes are stubbed into package.loaded so nothing here
-- patches the actual game/src/ui files, and the wrapped functions are called
-- directly to prove the wrapper is what the engine would actually reach.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Boxmark = dofile(MOD .. "/src/boxmark.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")

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

local function firstLogged(mod, needle)
  for _, line in ipairs(mod.logged) do
    if line.msg:find(needle, 1, true) then return line end
  end
  return nil
end

Boxmark.bind({ fusion = Fusion })

-- ---------------------------------------------------------------------
-- The engine classes this module reaches, stubbed so nothing here touches
-- the real game/src/ui files -- the same technique battle_forms_diag_test.lua
-- and battle_forms_adopt_test.lua use for src/menu.lua's own wraps.
-- ---------------------------------------------------------------------
local savedLoaded = {}
for _, name in ipairs({ "src.ui.ListMenu", "src.ui.SummaryMenu",
                        "src.render.Font", "src.pokemon.Boxes" }) do
  savedLoaded[name] = package.loaded[name]
end

local function stubEngine()
  local calls = { drawFont = {} }
  local ListMenu = {
    new = function(game, title, items, opts)
      return { game = game, title = title, items = items, opts = opts }
    end,
  }
  local SummaryMenu = {
    draw = function(self) calls.vanillaSummaryDraw = (calls.vanillaSummaryDraw or 0) + 1 end,
  }
  local Font = {
    draw = function(text, x, y)
      calls.drawFont[#calls.drawFont + 1] = { text = text, x = x, y = y }
    end,
  }
  package.loaded["src.ui.ListMenu"] = ListMenu
  package.loaded["src.ui.SummaryMenu"] = SummaryMenu
  package.loaded["src.render.Font"] = Font
  package.loaded["src.pokemon.Boxes"] = require("src.pokemon.Boxes")
  return ListMenu, SummaryMenu, Font, calls
end

-- love.graphics is already stubbed globally by tests.modkit (tests/love_stub.lua)
love = love or _G.love

local function fusedMon(species, into)
  return { species = species, [Fusion.HELD] = into }
end

local function box(...)
  local out = {}
  for i, mon in ipairs({ ... }) do out[i] = mon end
  return out
end

local function saveWithBox(boxContents)
  return { boxes = { boxContents }, currentBox = 1, party = {} }
end

-- ---------------------------------------------------------------------
-- The box lists: WITHDRAW and RELEASE mark a fused partner's row; DEPOSIT
-- (which never lists one -- a fusion partner is never in the party) is left
-- alone even if handed one by mistake, because the field on the item is
-- read generically and a marker on the wrong kind of list would be a lie
-- about what the row is.
-- ---------------------------------------------------------------------
do
  local ListMenu = stubEngine()
  T.eq(Boxmark.install(fakeMod()), true, "precondition: install succeeds")

  local partner = fusedMon("RESHIRAM", "KYUREM_WHITE")
  local plain = { species = "PIDGEY" }
  local save = saveWithBox(box(plain, partner))

  for _, kind in ipairs({ "pc_box_withdraw", "pc_box_release" }) do
    local items = { { label = "PIDGEY :L5", value = 1 },
                     { label = "RESHIRAM :L50", value = 2 } }
    local menu = ListMenu.new({ save = save }, "BOX 1", items, { kind = kind })
    T.eq(items[1].right, nil, kind .. ": an unfused box mon carries no marker")
    T.eq(items[2].right, Boxmark.GLYPH,
      kind .. ": the fused partner's row is marked")
    T.check(menu ~= nil, kind .. ": the vanilla constructor still ran")
    T.eq(menu.items, items, kind .. ": and got the same items table")
  end

  local items = { { label = "RESHIRAM :L50", value = 1 } }
  local depositSave = { boxes = {}, currentBox = 1,
                        party = { partner } }
  ListMenu.new({ save = depositSave }, "PARTY (DEPOSIT)", items,
    { kind = "pc_box_deposit" })
  T.eq(items[1].right, nil,
    "DEPOSIT lists the party, not a box, and is never marked")
end

-- ---------------------------------------------------------------------
-- Nothing is written. The marker is item.right on a fresh table ListMenu
-- itself owns; the boxed Pokemon's own keys are untouched.
-- ---------------------------------------------------------------------
do
  local ListMenu = stubEngine()
  Boxmark.install(fakeMod())

  local partner = fusedMon("RESHIRAM", "KYUREM_WHITE")
  local before = {}
  for k, v in pairs(partner) do before[k] = v end
  local save = saveWithBox(box(partner))
  local items = { { label = "RESHIRAM :L50", value = 1 } }
  ListMenu.new({ save = save }, "BOX 1", items, { kind = "pc_box_release" })

  for k, v in pairs(before) do
    T.eq(partner[k], v, "the boxed mon keeps " .. tostring(k) .. " unchanged")
  end
  local grew = false
  for k in pairs(partner) do if before[k] == nil then grew = true end end
  T.check(not grew, "and gained no new key of its own")
end

-- ---------------------------------------------------------------------
-- Malformed input never crashes the constructor -- a game without save,
-- without boxes, or an item with no numeric value all fall through to the
-- vanilla behaviour, because a marker is not worth a menu that fails to open.
-- ---------------------------------------------------------------------
do
  local ListMenu = stubEngine()
  Boxmark.install(fakeMod())

  local items = { { label = "X", value = 1 } }
  local ok1 = pcall(ListMenu.new, { }, "BOX 1", items, { kind = "pc_box_release" })
  T.check(ok1, "no game.save at all does not throw")
  T.eq(items[1].right, nil, "and marks nothing")

  local ok2 = pcall(ListMenu.new, { save = saveWithBox(box()) }, "BOX 1",
    items, { kind = "pc_box_release" })
  T.check(ok2, "an empty box does not throw")

  local weirdItems = { { label = "X" } }
  local ok3 = pcall(ListMenu.new,
    { save = saveWithBox(box(fusedMon("RESHIRAM", "KYUREM_WHITE"))) },
    "BOX 1", weirdItems, { kind = "pc_box_release" })
  T.check(ok3, "an item with no numeric value does not throw")
  T.eq(weirdItems[1].right, nil, "and is left alone")
end

-- ---------------------------------------------------------------------
-- The STATS screen, reached from either box list's submenu -- the obvious
-- neighbouring place a boxed mon is drawn, and the one this suite exists to
-- make sure was not skipped.
-- ---------------------------------------------------------------------
do
  local _, SummaryMenu, Font, calls = stubEngine()
  T.eq(Boxmark.install(fakeMod()), true, "precondition: install succeeds")

  local partner = fusedMon("RESHIRAM", "KYUREM_WHITE")
  SummaryMenu.draw({ mon = partner, page = 1 })
  T.eq(calls.vanillaSummaryDraw, 1, "the vanilla draw still ran first")
  T.eq(#calls.drawFont, 1, "one extra glyph is drawn for a fused partner")
  T.eq(calls.drawFont[1].text, Boxmark.GLYPH, "the same marker as the box list")

  -- The free two-tile gap on the dex-number row (status_screen.asm's own
  -- DrawLineBox never reaches it): the "No." + dex number ends at x=48 and
  -- the line box's leftward run does not start until x=64.
  T.eq(calls.drawFont[1].x, 48, "drawn where nothing else is")
  T.eq(calls.drawFont[1].y, 56, "on the dex-number row")

  calls.drawFont = {}
  SummaryMenu.draw({ mon = { species = "PIDGEY" }, page = 1 })
  T.eq(#calls.drawFont, 0, "an ordinary mon gets no marker")

  calls.drawFont = {}
  SummaryMenu.draw({ mon = partner, page = 2 })
  T.eq(#calls.drawFont, 1,
    "the header carrying the dex number is shared with page 2, so the "
      .. "marker follows it there rather than vanishing on the flip")

  calls.drawFont = {}
  SummaryMenu.draw({ mon = nil, page = 1 })
  T.eq(#calls.drawFont, 0, "no mon at all draws no marker and does not throw")
end

-- ---------------------------------------------------------------------
-- Idempotency: a second install (a mod reloaded, or somehow loaded twice)
-- wraps nothing and still reports success, the same contract src/menu.lua's
-- own install keeps.
-- ---------------------------------------------------------------------
do
  local ListMenu, SummaryMenu = stubEngine()
  local vanillaNew, vanillaDraw = ListMenu.new, SummaryMenu.draw

  T.eq(Boxmark.install(fakeMod()), true, "first install succeeds")
  T.check(ListMenu.new ~= vanillaNew, "ListMenu.new was wrapped")
  T.check(SummaryMenu.draw ~= vanillaDraw, "SummaryMenu.draw was wrapped")

  local wrappedNew, wrappedDraw = ListMenu.new, SummaryMenu.draw
  local mod2 = fakeMod()
  T.eq(Boxmark.install(mod2), true, "a second install still reports success")
  T.eq(ListMenu.new, wrappedNew, "and wraps ListMenu.new no further")
  T.eq(SummaryMenu.draw, wrappedDraw, "nor SummaryMenu.draw")
end

-- ---------------------------------------------------------------------
-- A guard that refuses must say so out loud (project rule #6): a shape the
-- engine no longer offers builds nothing rather than something fragile, and
-- the refusal is reported through mod.log so it is visible without DEBUG
-- TRACE.
-- ---------------------------------------------------------------------
do
  stubEngine()
  package.loaded["src.ui.ListMenu"] = { new = "not a function" }
  local mod = fakeMod()
  T.eq(Boxmark.install(mod), false,
    "a ListMenu.new that is not a function refuses rather than patching it")
  T.check(firstLogged(mod, "battle_forms:") ~= nil,
    "and says so through mod.log")
end

do
  stubEngine()
  package.loaded["src.ui.ListMenu"] = nil
  package.preload["src.ui.ListMenu"] = function() error("no such module") end
  local mod = fakeMod()
  T.eq(Boxmark.install(mod), false,
    "an unrequireable ListMenu refuses cleanly")
  T.check(firstLogged(mod, "battle_forms:") ~= nil, "and says so")
  package.preload["src.ui.ListMenu"] = nil
end

do
  stubEngine()
  package.loaded["src.ui.SummaryMenu"] = { draw = "not a function" }
  local mod = fakeMod()
  T.eq(Boxmark.install(mod), false,
    "a SummaryMenu.draw that is not a function refuses rather than patching it")
  T.check(firstLogged(mod, "battle_forms:") ~= nil, "and says so through mod.log")
end

-- ---------------------------------------------------------------------
-- Atomic: a marker that stood in the box list and not on the STATS screen
-- reached from it (or the other way round) is worse than none, so a failure
-- on either half undoes the other rather than leaving a half-built marker.
-- ---------------------------------------------------------------------
do
  local ListMenu = stubEngine()
  local vanillaNew = ListMenu.new
  package.loaded["src.ui.SummaryMenu"] = { draw = "not a function" }
  local mod = fakeMod()

  T.eq(Boxmark.install(mod), false,
    "the whole install fails when either half cannot be wrapped")
  T.eq(ListMenu.new, vanillaNew,
    "the box list wrap that DID succeed was reverted rather than left "
      .. "standing alone")
  T.eq(ListMenu._battleFormsBoxMarked, nil,
    "and its guard flag was cleared, so a later fix can install cleanly")
end

for name, value in pairs(savedLoaded) do package.loaded[name] = value end

T.finish("battle_forms_boxmark")
