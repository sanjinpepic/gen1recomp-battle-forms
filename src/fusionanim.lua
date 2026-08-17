-- The fusion animation: both Pokemon side by side, then merged into one --
-- the owner's original ask for fusion, unreachable until now for two
-- independent reasons that are both gone.  src/fusion.lua's own header
-- explains WHERE the partner goes and WHAT is written; this file explains
-- HOW a player ever sees it happen, and touches neither.
--
-- REASON ONE, EvolutionState, is still refused.  `EvolutionState:update`
-- unconditionally calls Evolution.apply, which re-keys mon.species -- the one
-- write this mod abandoned in 0.2.1 -- and its sprite lookup is front-only
-- besides, so both halves would draw the same picture.  HANDOFF.md records
-- the reversal in full.  This module owns a screen of its own instead, on
-- both games, and never requires that class.
--
-- REASON TWO was the missing seam.  src/ui/BagMenu.lua's `useOn` used to be a
-- Lua `local`, invisible to any mod, with every result falling through to one
-- unconditional `showMessages` -- a screen pushed from inside the item's own
-- effect callback never drew a frame, because StateStack:update only updates
-- the top of the stack.  The engine now raises "item.use", a Runtime.call
-- seam around that whole dispatch, and this module wraps it rather than
-- capturing it -- `mod.hooks:wrap` chains behind whatever else is already
-- listening, exactly the discipline src/hpscale.lua's own battle.damage wrap
-- keeps, because another mod may want the identical hook.
--
-- ONE HOOK, ONE GAME.  "item.use" only ever fires from src/ui/BagMenu.lua,
-- and BagMenu.lua is Gen 1's own field/battle bag -- Gold's field PACK is a
-- different class (src/ui/gen2/PackMenu.lua) calling straight into
-- Game2:usePartyItem, which dispatches through src/core/gen2/ItemEffects.lua
-- with no Runtime.call anywhere near it (confirmed by reading both files, not
-- assumed from the name).  So Gen 1 composes with a shared hook and Gen 2
-- gets a wrap of its own on Game2:usePartyItem -- an idempotent monkeypatch
-- with a guard flag, the exact technique src/gen2forms.lua, src/gen2menu.lua
-- and src/gen2formview.lua already use for every Gen 2 class this mod
-- touches that the engine gives no hook for at all.  "No engine changes"
-- rules out adding one; it does not rule out the pattern this whole mod
-- already leans on for Gold.
--
-- WHAT COUNTS AS "A FUSION JUST HAPPENED", on both games: `target`/`mon` is
-- the one Pokemon this module ever needs, and `fusion.partnerOf(mon)` before
-- and after the real effect ran is the whole of the test -- nil-to-species is
-- a fuse (animate), species-to-nil is a split (see below), anything else
-- (nil-to-nil on a refusal, species-to-species impossible) is left alone.
-- Nothing here re-derives what src/fusion.lua already decided; it only reads
-- the one field that decision leaves behind.
--
-- SPLITTING STAYS A MESSAGE.  Nothing new appears on a split -- the partner
-- that returns is the exact Pokemon that went in, already drawn everywhere
-- else in the party the instant it lands, and src/boxmark.lua's own F marker
-- disappearing from the PC lists already answers "where did it go" on
-- screen. A second, mirrored animation would double this module's surface
-- for the half of the mechanic that reveals nothing, which is the opposite of
-- what "footprint must not grow" asks of the item this rides on.
--
-- ART, or the plain message.  Three pictures are needed -- the survivor as it
-- stood, the partner's own species, and the fused form -- through the exact
-- seam src/gen2formview.lua already draws forms with: `pokemon.sprite`
-- first, the form record's own `spriteFront` second.  Any one of the three
-- missing (no hook answer, no record, no path) refuses the WHOLE animation
-- rather than drawing two pictures and a blank; the ordinary two-page message
-- src/fusion.lua already wrote is what shows either way, because nothing
-- here ever suppresses or replaces it -- only interposes before it.
local Assets = require("src.render.Assets")

local M = {}

local deps = nil
-- deps: { fusion = <src/fusion.lua>, log = mod.log, itemIds = { [id]=true } }
function M.bind(modules) deps = modules end

--------------------------------------------------------------------------
-- Art resolution
--------------------------------------------------------------------------

-- Resolved lazily and cached, the same courtesy src/gen2formview.lua's own
-- spriteModule() keeps: a draw-only dependency this module treats as
-- optional rather than required, so a host where it fails to resolve
-- degrades to no animation instead of failing to load.
local Sprites = nil
local function spriteModule()
  if Sprites ~= nil then return Sprites or nil end
  local ok, value = pcall(require, "src.pokemon.Sprites")
  Sprites = (ok and type(value) == "table" and type(value.path) == "function")
    and value or false
  return Sprites or nil
end

-- A plain species picture -- the survivor as it stood, or the partner's own
-- species -- with no form suffix in play.  Returns image, trueColor or nil.
local function plainArt(sprites, data, species, mon)
  local path, trueColor = sprites.path(data, species, "front",
    { mon = mon, kind = "fusion" })
  if type(path) ~= "string" or path == "" then return nil end
  local ok, image = pcall(Assets.image, path)
  if not ok or not image then return nil end
  return { image = image, trueColor = trueColor, species = species }
end

-- The fused form's own picture. Mirrors src/gen2formview.lua's neighbourPath
-- exactly: the hook first, keyed on the BASE species plus the form's own
-- suffix (a compound form id is not what a sprite set's own registry keys
-- art on), then the form record's own `spriteFront` when the hook answers
-- nothing or answers with the unformed picture -- the same "compare against
-- the unformed answer" check that tells a miss from real art.
local function formArt(sprites, data, baseSpecies, formId)
  local formDef = data.pokemon and data.pokemon[formId]
  if type(formDef) ~= "table" then return nil end

  local suffix = formDef.form
  if type(suffix) == "string" and suffix ~= "" then
    local okForm, path, trueColor = pcall(sprites.path, data, baseSpecies,
      "front", { kind = "fusion", mon = { form = suffix } })
    if okForm and type(path) == "string" and path ~= "" then
      local baseDef = data.pokemon[baseSpecies]
      if not (baseDef and path == baseDef.spriteFront) then
        local ok, image = pcall(Assets.image, path)
        if ok and image then
          return { image = image, trueColor = trueColor, species = formId }
        end
      end
    end
  end

  if type(formDef.spriteFront) == "string" and formDef.spriteFront ~= "" then
    local ok, image = pcall(Assets.image, formDef.spriteFront)
    if ok and image then
      -- trueColor stays nil: the record's own path, exactly the fallback
      -- src/gen2formview.lua's own M.drawPic treats as "shaded like every
      -- other mon's picture on this screen" rather than as true-colour art.
      return { image = image, trueColor = nil, species = formId }
    end
  end
  return nil
end

-- The three pictures this animation needs, or nil if any one of them is
-- unavailable -- refusing the whole animation rather than drawing two
-- pictures and a blank, per this file's own header.
--
-- `survivor` must already carry the stamp the fuse just wrote --
-- fusion.formIdFor(survivor) is what names the fused form, the same
-- derived-not-remembered read every other caller of that function makes, so
-- this never trusts `partnerSpecies` for anything but the partner's own
-- plain picture (the form itself is not derivable from a species string
-- alone -- see src/fusion.lua's own formIdFor for why: one species can pair
-- with two different partners into two different forms).
function M.resolveArt(data, survivor, partnerSpecies)
  if not (data and survivor and partnerSpecies) then return nil end
  local sprites = spriteModule()
  if not sprites then return nil end

  local formId = deps.fusion.formIdFor(survivor)
  if not formId then return nil end

  local left = plainArt(sprites, data, survivor.species, survivor)
  if not left then return nil end
  local right = plainArt(sprites, data, partnerSpecies, nil)
  if not right then return nil end
  local result = formArt(sprites, data, survivor.species, formId)
  if not result then return nil end

  return left, right, result
end

--------------------------------------------------------------------------
-- The decision: did a fuse just happen to this mon?
--------------------------------------------------------------------------

-- before/after are what fusion.partnerOf(mon) answered around the real
-- effect running.  Only nil -> species counts; species -> nil is a split
-- (see this file's own header on why that stays a message), and nil -> nil
-- or an unchanged species is a refusal or an unrelated item.
function M.justFused(before, after)
  return before == nil and type(after) == "string" and after ~= ""
end

--------------------------------------------------------------------------
-- The screen
--------------------------------------------------------------------------

local Screen = {}
Screen.__index = Screen
Screen.isOpaque = true

-- Frame counts, exported so a test can compute exact phase boundaries rather
-- than guessing them. Short on purpose: this is new content riding an item
-- nobody has to sit through twice, not a recreation of the cart's own
-- 368-frame evolution movie.
M.HOLD_FRAMES = 50
M.MERGE_FRAMES = 40
M.FLASH_FRAMES = 10
M.REVEAL_FRAMES = 40

local PHASE_ORDER = { "hold", "merge", "flash", "reveal" }
local PHASE_FRAMES = { hold = M.HOLD_FRAMES, merge = M.MERGE_FRAMES,
                        flash = M.FLASH_FRAMES, reveal = M.REVEAL_FRAMES }

-- opts: game, gen2, left, right, result (each { image, trueColor, species }),
-- colors (Gen 2 shading palette, may be nil), onDone
function M.newScreen(opts)
  opts = opts or {}
  local self = setmetatable({}, Screen)
  self.game = opts.game
  self.gen2 = opts.gen2 and true or false
  self.left = opts.left
  self.right = opts.right
  self.result = opts.result
  self.colors = opts.colors
  self.onDone = opts.onDone
  self.phase = "hold"
  self.t = 0
  self.finished = false
  return self
end

-- Pops itself off the live stack (if it is still on it -- a test may drive
-- one that was never pushed at all) and hands off exactly once. Called both
-- from a normal phase timeout and from a skip press, so both paths end in
-- the identical place.
function Screen:finish()
  if self.finished then return end
  self.finished = true
  local stack = self.game and self.game.stack
  if stack and stack.top and stack:top() == self and stack.pop then
    stack:pop()
  end
  local onDone = self.onDone
  self.onDone = nil
  if onDone then onDone() end
end

function Screen:update(_dt)
  if self.finished then return end
  local input = self.game and self.game.input
  if input and input.wasPressed
      and (input:wasPressed("a") or input:wasPressed("b")) then
    return self:finish()
  end
  self.t = self.t + 1
  local limit = PHASE_FRAMES[self.phase]
  if limit and self.t >= limit then
    local nextPhase
    for i, name in ipairs(PHASE_ORDER) do
      if name == self.phase then nextPhase = PHASE_ORDER[i + 1] end
    end
    if nextPhase then
      self.phase, self.t = nextPhase, 0
    else
      self:finish()
    end
  end
end

-- Whole-screen colorization for Gen 1's SGB packet -- optional (Game.lua
-- only asks a state that defines this at all), but leaving it undefined
-- would hand our own picture whatever zone the screen UNDER us specifies
-- (Game.lua:564-575, "the topmost state that knows its palette owns the
-- screen"), which is wrong rather than merely plain. Gen 2 never asks:
-- Game2.lua has no equivalent walk at all, colour there is GbcPalette on the
-- pixels themselves (src/mods/Gen2Compat.lua's own "sgbPalettes must stay
-- ABSENT" note for Gold-side classes), so this returns nothing on that game.
function Screen:sgbPalettes(game)
  if self.gen2 then return nil end
  local P = require("src.render.PaletteFX")
  local species = (self.phase == "reveal") and self.result.species
    or self.left.species
  local c = species and P.monPal(game.data, species)
  if c then return { P.whole(c) } end
  return { P.wholeNamed(game.data, "MEWMON") }
end

--------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------

local SCREEN_W, SCREEN_H = 160, 144
local GROUND_Y = 100
local LEFT_X, RIGHT_X, CENTER_X = 44, 116, 80

local function lerp(a, b, t) return a + (b - a) * t end

-- Bottom-anchored, centred on cx -- the same "pad into the box, feet on one
-- line" placement src/ui/EvolutionState.lua and EvolutionAnim both use, so a
-- 40px Cyndaquil and a 56px Onix share a ground line here too.
local function place(image, cx, groundY)
  local w, h = image:getDimensions()
  return cx - math.floor(w / 2), groundY - h
end

local GbcPalette = nil
local function gbcPalette()
  if GbcPalette ~= nil then return GbcPalette or nil end
  local ok, value = pcall(require, "src.render.GbcPalette")
  GbcPalette = (ok and type(value) == "table") and value or false
  return GbcPalette or nil
end

-- entry: { image, trueColor, species } or nil (a phase may have nothing to
-- show, e.g. the flash beat's silhouette gap).
function Screen:drawEntry(entry, cx)
  if not entry then return end
  local G = love.graphics
  local x, y = place(entry.image, cx, GROUND_Y)
  G.setColor(1, 1, 1, 1)

  if self.gen2 then
    local palette = gbcPalette()
    if entry.trueColor or not (palette and palette.available and palette.available()) then
      G.draw(entry.image, x, y)
    else
      palette.with(self.colors, function() G.draw(entry.image, x, y) end)
    end
    return
  end

  G.draw(entry.image, x, y)
  if entry.trueColor then
    local w, h = entry.image:getDimensions()
    require("src.render.PaletteFX").markTrueColor(x, y, w, h)
  end
end

function Screen:draw()
  local G = love.graphics
  if self.gen2 then
    local ok, Chrome = pcall(require, "src.ui.gen2.Chrome")
    if ok and Chrome.clear then Chrome.clear() end
  else
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)
  end
  G.setColor(1, 1, 1, 1)

  if self.phase == "hold" or self.phase == "merge" then
    local t = self.phase == "merge"
      and math.min(1, self.t / math.max(1, M.MERGE_FRAMES)) or 0
    self:drawEntry(self.left, lerp(LEFT_X, CENTER_X, t))
    self:drawEntry(self.right, lerp(RIGHT_X, CENTER_X, t))
  elseif self.phase == "flash" then
    -- deliberately blank: the same silhouette gap the cart's own evolution
    -- flash uses to sell "becoming something else" rather than "swapping a
    -- picture"
  else -- reveal
    self:drawEntry(self.result, CENTER_X)
  end
  G.setColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------
-- Palette lookup for Gen 2 shading (record-fallback art only; true-colour
-- art bypasses this the same way src/gen2formview.lua's drawFormArt does)
--------------------------------------------------------------------------

local function gen2Colors(game, mon)
  local okP, Palettes = pcall(require, "src.world.gen2.Palettes")
  if not okP then return nil end
  local palettes = game.data and game.data.gen2Palettes
  if not palettes then return nil end
  local ok, colors = pcall(Palettes.monColors, palettes, mon.species, mon.shiny)
  if not ok then return nil end
  return colors
end

--------------------------------------------------------------------------
-- Try to animate: shared by both games' wraps below.  Returns true if a
-- screen was pushed (the caller's onDone will fire later, from the screen's
-- own finish()); false means nothing was pushed and the caller must run its
-- own follow-up (the message) itself, right now.
--------------------------------------------------------------------------

local function tryAnimate(game, survivor, before, gen2, onDone)
  local after = deps.fusion.partnerOf(survivor)
  if not M.justFused(before, after) then return false end
  local data = game and game.data
  if not data then return false end
  local left, right, result = M.resolveArt(data, survivor, after)
  if not left then return false end
  local colors = gen2 and gen2Colors(game, survivor) or nil
  game.stack:push(M.newScreen({ game = game, gen2 = gen2, left = left,
    right = right, result = result, colors = colors, onDone = onDone }))
  return true
end

--------------------------------------------------------------------------
-- Gen 1: wrap the shared item.use hook.  Composes rather than captures --
-- nextFn always runs, exactly once, and this only decides what happens
-- after it has -- so a mod ahead of or behind this one in the chain sees
-- the identical outcome it would without this file installed.
--------------------------------------------------------------------------

local function installGen1(mod)
  mod.hooks:wrap("item.use", function(nextFn, game, battle, id, target, list,
                                       moveIndex, picker)
    if not (target and deps.itemIds[id]) then
      return nextFn(game, battle, id, target, list, moveIndex, picker)
    end
    local before = deps.fusion.partnerOf(target)
    nextFn(game, battle, id, target, list, moveIndex, picker)
    -- The message (if any) is already on the stack by now -- vanillaUseOn's
    -- own "kept"/"failed" branches always push it before returning.  Pushing
    -- our screen on top, isOpaque, is what makes it draw first and the
    -- message draw the instant this one pops: StateStack:draw only paints
    -- from the highest isOpaque state up.
    local ok, err = pcall(tryAnimate, game, target, before, false, nil)
    if not ok and deps.log then
      deps.log:error("battle_forms: the fusion animation failed to run (%s) "
        .. "-- the ordinary fusion message still showed", tostring(err))
    end
  end)
end

--------------------------------------------------------------------------
-- Gen 2: Game2:usePartyItem has no hook at all (this file's own header), so
-- this wraps the class method the same idempotent way src/gen2forms.lua,
-- src/gen2menu.lua and src/gen2formview.lua already wrap classes the engine
-- gives no seam for.  Every item id but our four is untouched: `vanilla` runs
-- unconditionally for them, first line, no branch of this wrap's own logic
-- ever reached.
--
-- WHY THIS DUPLICATES A FEW LINES OF DISPATCH rather than patching
-- Game2:say the way an armed-flag/instance-patch design would.
-- Game2:usePartyItem opens its own party picker and returns immediately --
-- the actual effect and message do not happen until the player chooses a
-- mon, arbitrarily many frames later -- so there is no single return value
-- or synchronous window this wrap could snapshot around. Re-running exactly
-- the two calls a fusion item's own dispatch collapses to (ItemEffects.
-- partyAction, then, on a choice, ItemEffects.useOnMon) keeps `mon` in scope
-- directly, the same way Gen 1's own `target` argument already is, rather
-- than reaching for a global flag on `self` that some unrelated `self:say`
-- firing in the same window could trip. `result.used` is always false for a
-- fusion item on every game (src/fusion.lua's own header on M.install), so
-- the two outcomes this reimplements -- print the text, or refuse before the
-- picker even opens -- are the whole of what `finish()` inside
-- Game2:usePartyItem ever does for one.
--------------------------------------------------------------------------

local function installGen2(mod)
  local okGame2, Game2 = pcall(require, "src.core.Game2")
  if not okGame2 or type(Game2) ~= "table" then
    if deps.log then
      deps.log:error("battle_forms: src.core.Game2 is unavailable -- the "
        .. "fusion animation is disabled on Gold; the plain message still "
        .. "shows")
    end
    return false
  end
  if Game2._battleFormsFusionAnim then return true end
  if type(Game2.usePartyItem) ~= "function" then
    if deps.log then
      deps.log:error("battle_forms: Game2.usePartyItem has changed shape -- "
        .. "the fusion animation is disabled on Gold; the plain message "
        .. "still shows")
    end
    return false
  end
  local okEffects, ItemEffects = pcall(require, "src.core.gen2.ItemEffects")
  local okScreens, Screens = pcall(require, "src.ui.Screens")
  if not (okEffects and okScreens) then
    if deps.log then
      deps.log:error("battle_forms: a required Gen 2 module is unavailable "
        .. "-- the fusion animation is disabled on Gold; the plain message "
        .. "still shows")
    end
    return false
  end

  local vanilla = Game2.usePartyItem
  Game2._battleFormsFusionAnim = true
  Game2.usePartyItem = function(self, itemId)
    if not deps.itemIds[itemId] then return vanilla(self, itemId) end
    local action = ItemEffects.partyAction(itemId, self.data)
    if not action then return vanilla(self, itemId) end
    local party = (self.save and self.save.party) or {}
    if #party == 0 then return vanilla(self, itemId) end

    Screens.push(self, "Gen2PartyMenu", {
      prompt = "useItem",
      onCancel = function() self.stack:pop() end,
      onChoose = function(_, mon)
        self.stack:pop()
        local before = deps.fusion.partnerOf(mon)
        local result = ItemEffects.useOnMon(itemId, mon, self.data)
        -- Mirrors Game2:usePartyItem's own `finish` for the one action a
        -- fusion item ever names -- see this function's own header for why
        -- `used` never comes back true here, kept anyway so a future item
        -- sharing this dispatch is not silently mishandled.
        if result.used then self:consumeItem(itemId) end
        local function say() self:say(result.text) end
        local ok, animated = pcall(tryAnimate, self, mon, before, true, say)
        if not ok then
          if deps.log then
            deps.log:error("battle_forms: the fusion animation failed to "
              .. "run (%s) -- the ordinary fusion message still showed",
              tostring(animated))
          end
          animated = false
        end
        if not animated then say() end
      end,
    })
  end
  return true
end

--------------------------------------------------------------------------
-- Wires whichever half applies. gen2 picks the branch the same way every
-- other Gen 2-aware install call in main.lua does; the other branch is never
-- even attempted, so a Gen 1 boot never patches a Game2 that does not exist
-- and a Gen 2 boot never wraps a hook nothing on that game ever calls.
--------------------------------------------------------------------------

function M.install(mod, gen2)
  if gen2 then return installGen2(mod) end
  installGen1(mod)
  return true
end

return M
