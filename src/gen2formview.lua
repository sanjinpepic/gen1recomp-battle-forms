-- Gen 2's equivalent of src/formview.lua: draws a persistent (or fused)
-- form's real types and stats over Gold's own SUMMARY screen, the same
-- draw-after-vanilla overlay Gen 1's module uses and for the identical
-- reason -- mon.species is never re-keyed (src/forms.lua's own header, and
-- src/gen2forms.lua's), so data.pokemon[mon.species] is still the BASE
-- species everywhere Gold's own src/ui/gen2/SummaryMenu.lua reads it.
--
-- WHY THIS IS AN OVERLAY AND NOT A READ OF mon.stats.  Gold's blue page
-- prints mon.stats directly (SummaryMenu.lua:532), and src/gen2forms.lua's
-- becomeForm mutates that exact table in place while a form is active in
-- battle -- so during a fight the vanilla draw is already right.  This
-- module exists for every OTHER moment a player opens this screen: a level-
-- up recomputes mon.stats from the BASE species alone (Gold's own growth
-- curve is keyed on mon.species, with no idea a form marker is sitting on
-- the mon), so a Pokemon sitting in the party menu between battles can show
-- stale, un-boosted numbers for a form it is still genuinely wearing, until
-- its next battle reapplies gen2forms.becomeForm and corrects mon.stats
-- again.  Recomputing fresh from data.pokemon[formId] on every draw --
-- exactly what Gen 1's formview.lua already does, for the same reason --
-- sidesteps that staleness rather than chasing every place mon.stats could
-- drift: what this module draws never depends on what mon.stats currently
-- holds.
--
-- TYPES have the same story from a different angle.  Gold's own typeNames()
-- checks mon.types before data.pokemon[mon.species].types
-- (SummaryMenu.lua:391), a field nothing in the engine ever writes -- so it
-- is not a seam this mod can rely on Gold to have populated on its own, and
-- this module does not populate it either (mon.formTypes, the field
-- src/gen2forms.lua's speciesDef wrap reads, is a different field with a
-- different consumer).  It draws over the vanilla TYPE box instead, exactly
-- where Gen 1's module does.
--
-- WHICH MONS THIS EVER FIRES FOR, and in what order two claims are asked --
-- both identical to src/formview.lua's own header, because both modules
-- exist to answer the same question about the same two mechanics
-- (src/persistent.lua, src/fusion.lua) for a screen the other generation
-- happens to draw differently.
local Mon = require("src.battle.gen2.Mon")

local M = {}

local deps = nil
function M.bind(modules) deps = modules end

-- Resolved lazily, at install time, the way src/formview.lua resolves
-- src/render/Font: a draw-only dependency this module treats as a courtesy
-- rather than a hard requirement, so a host that cannot supply it draws the
-- vanilla screen and nothing more rather than failing to load at all.
local Chrome = nil
-- Pulled off the real class at install time rather than hard-coded, so a
-- page renumbering or a TYPE_NAMES addition on the engine side is picked up
-- automatically instead of silently drifting from what this module assumes.
local BluePage, GreenPage, TypeNames = 3, 2, {}

local function record(fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

-- src/resolve.lua's own settle() asks fusion first, then persistent -- see
-- src/formview.lua's identical header for why the order can never actually
-- decide an outcome (no species is both a fusion base and a persistent-form
-- holder) and why matching it here is still the right default to inherit
-- rather than pick arbitrarily.
--
-- Does NOT gate on mon.form the way src/formview.lua's identical Gen 1
-- helper safely does.  On Gen 1 that gate is free: mon.form is set the
-- instant a stamp changes (src/persistent.lua's M.mark runs inside the same
-- bag-use closure that writes the stamp), so a nil mon.form really does mean
-- neither mechanic can have anything to say.  On Gen 2, src/persistent.lua's
-- M.formIdFor also reads mon.item -- the real held-item slot
-- src/ui/gen2/HeldItemMenu.lua's GIVE writes directly, with no event this
-- mod can hook -- so a mon can reach this SUMMARY screen freshly given an
-- item, entitled to a form, with mon.form still nil because nothing has
-- applied it yet (no battle has started since the GIVE).  Gating on mon.form
-- here would draw nothing for exactly that mon, which is the bug report this
-- module exists to fix.  Asking fusion/persistent fresh on every draw is
-- already this module's own design (see the header above on stats/types
-- staleness); the one thing removed is the pre-filter that assumed the
-- answer could only ever be "no" when mon.form was empty.
local function formIdFor(mon)
  if not mon then return nil end
  local id = deps and deps.fusion and deps.fusion.formIdFor(mon)
  if id then return id end
  return deps and deps.persistent and deps.persistent.formIdFor(mon)
end

-- The record itself, shared by M.resolve (types/stats) and the picture below
-- -- both ask the identical formIdFor question of the identical record, and
-- a formId this owns nothing for (no `types`, no `baseStats`, no
-- `spriteFront`) is exactly the case each caller refuses on its own terms
-- rather than half-applying.
local function formRecordFor(data, mon)
  local formId = formIdFor(mon)
  if not formId then return nil end
  local formDef = data and data.pokemon and data.pokemon[formId]
  if type(formDef) ~= "table" then return nil end
  return formId, formDef
end

-- Refuses rather than half-applying, for src/forms.lua's own reason: a form
-- record with no `types` or no `baseStats` would draw nothing meaningful.
-- Quiet rather than logged, matching src/formview.lua's own choice --
-- src/persistent.lua and src/fusion.lua's own settle() already warn out loud
-- on the one case that can leave mon.form pointing at a record like this.
function M.resolve(data, mon)
  local _, formDef = formRecordFor(data, mon)
  if not formDef or type(formDef.types) ~= "table" or formDef.types[1] == nil
      or type(formDef.baseStats) ~= "table" then
    return nil
  end
  return {
    types = formDef.types,
    stats = Mon.stats(formDef.baseStats, mon.dvs, mon.level, mon.statExp),
  }
end

-- ---- the SUMMARY screen's picture ------------------------------------------
--
-- picFor(mon) (SummaryMenu.lua:885-895) reads `def.spriteFront` straight off
-- data.pokemon[mon.species] -- the BASE species, never mon.form -- and raises
-- no hook, so a Giratina in Origin Forme drew its base picture even after
-- 0.43.0 fixed its stats and types on this same screen. Confirmed by driving
-- the real class: drawPanel -> drawUpperHalf -> drawPic -> picFor is the live
-- path (SummaryMenu:draw() is an unused alias, the exact trap 0.38.0's own
-- drawPanel/draw confusion already cost this repo once), so picFor is where
-- the picture is actually decided.
--
-- drawPic, not picFor, is what this module wraps. picFor's own return is
-- just an Image -- the shading decision lives one level up, in drawPic's
-- own call to drawPicBlock, which runs every image it is handed through
-- GbcPalette.with(colors, body) UNCONDITIONALLY.  A four-shade set drawn
-- that way is correct; a full-colour one is crushed to grey, which is
-- exactly the failure National Dex's own src/gen2summary.lua exists to
-- avoid for this identical screen (dev/national_dex_mod/HANDOFF.md's own
-- "true-colour flag" section). Wrapping picFor could not have carried that
-- decision back out to drawPic at all.
--
-- Composes with National Dex's own src/gen2summary.lua, which also wraps
-- SummaryMenu.drawPic for its own (species-level, dex-form-browsing) art.
-- battle_forms declares national_dex a hard dependency
-- (manifest.json:"dependencies"), so the loader always installs national_dex
-- first -- this module's own wrap therefore always ends up OUTERMOST, and it
-- checks whether a battle_forms form applies BEFORE ever falling through to
-- whatever drawPic was before it (national_dex's own wrap, or vanilla),
-- which is what makes the order safe rather than merely usual: a formed mon
-- is decided here regardless of what a sibling mod would otherwise have
-- drawn for the bare species.
local PIC_BOX = 7 * 8
local PIC_ORIGIN_X, PIC_ORIGIN_Y = 0, 0

local GbcPalette, Palettes = nil, nil
-- PartyMenu's own image loader: unlike SummaryMenu (self:picImage, wrapping
-- self.picCache), PartyMenu loads icon images through this module directly
-- (src/ui/gen2/PartyMenu.lua:544, :578) with no instance-level cache method
-- of its own for M.drawIcon to reuse -- resolved lazily at install time the
-- same courtesy way Chrome/GbcPalette/Palettes are.
local Assets = nil

-- src.pokemon.Sprites is the ENGINE'S own module, not a handle onto another
-- mod -- unlike National Dex's own reach for universal_sprites (a plain
-- mod:find closure, because it calls that mod's EXPORT directly), this
-- module never touches the sprite mod by name at all. It fires the shared
-- pokemon.sprite hook and lets whichever mod subscribed to it (or none)
-- answer, so this keeps working unchanged if universal_sprites is ever
-- replaced, renamed or simply absent. Resolved lazily and cached the same
-- courtesy way Chrome is, above.
local function spriteModule()
  local SpritesMod
  return function()
    if SpritesMod ~= nil then return SpritesMod or nil end
    local ok, value = pcall(require, "src.pokemon.Sprites")
    SpritesMod = (ok and type(value) == "table" and type(value.path) == "function")
      and value or false
    return SpritesMod or nil
  end
end

-- Asks the SAME seam the bug report names outright: pokemon.sprite, the hook
-- battle art already fires and universal_sprites already subscribes to
-- (SummaryMenu.lua never raises it on its own). `mon = { form = formSuffix }`
-- is a SYNTHETIC mon carrying only the form -- the identical technique
-- gen2dexlist.lua's own M.spriteArt uses (`mon = form and { form = form } or
-- nil`) -- because the registry keys form art on `ctx.mon.form`
-- (src/registry.lua's formId()), and the REAL mon's own .form can still be
-- nil here (this module's own header on why formIdFor does not gate on it).
--
-- A hook that found nothing for this form answers with the SAME path the
-- base species' own picture already resolves to (Sprites.path's own
-- fallback is `def.spriteFront` off the BASE species, since `species` here
-- is deliberately mon.species, never the compound form id) -- so that exact
-- case is detected and treated as a miss rather than as art, the same
-- "compare against the unformed answer" check National Dex's own resolver
-- makes before trusting a form-specific result.
local function neighbourPath(resolveModule, data, mon, formSuffix)
  local module = resolveModule()
  if not module then return nil end
  local okForm, formPath, trueColor = pcall(module.path, data, mon.species,
    "front", { kind = "summary", mon = { form = formSuffix } })
  if not okForm or type(formPath) ~= "string" or formPath == "" then
    return nil
  end
  local baseDef = data and data.pokemon and data.pokemon[mon.species]
  if baseDef and formPath == baseDef.spriteFront then return nil end
  return formPath, trueColor
end

-- The cart's own blank fill plus a centred, never-enlarged fit -- National
-- Dex's own src/gen2dexlist.lua M.artPlacement's reasoning applies unchanged:
-- the cart's own pics are bottom-pinned to share a ground line at a fixed
-- 5x5/6x6/7x7 tile size, but a sprite set's art arrives at whatever size the
-- dump ships and centring is the honest fit for art whose framing this
-- module does not control.
--
-- Parameterized by origin/box rather than hard-coded to the SUMMARY picture's
-- own 56x56: M.drawIcon below reuses this exact routine to fit the same kind
-- of art (a form record's own full-size spriteFront, or whatever the
-- pokemon.sprite hook answers) into PartyMenu's much smaller 16x16 slot.
-- Fitting DOWN into a small box is the same scale-to-min-ratio math as
-- fitting into a large one; nothing about the routine assumes which
-- direction it is scaling.
--
-- `colors` is the caller's to decide, not this function's: the two callers
-- read genuinely different palettes off the SAME self.palettes table, and
-- picking one here would be right for exactly one of them.  M.drawPic's own
-- SUMMARY picture wants a per-mon palette (Palettes.monColors(self.palettes,
-- mon.species, mon.shiny), the identical source SummaryMenu:drawPicBlock
-- itself reads at SummaryMenu.lua:925) -- but M.drawIcon's own PARTY list
-- icon does not: vanilla PartyMenu:drawIcon shades EVERY row through one
-- shared palette regardless of species (PartyMenu.lua:634-638 -- "Every
-- party icon OAM entry is PAL_OW_RED... for the whole list, species and EGG
-- alike"), read off self.palettes.partyMenu[1].  This function used to
-- compute the SUMMARY picture's own per-mon lookup unconditionally for
-- BOTH callers, which is exactly why a formed mon's list icon drew in a
-- colour nothing else in that list used -- the identical shape of gap
-- 0.44.0 found between picFor (path) and drawPic (shading), one seam over:
-- the icon's own PATH was already right, the step this wrap bypassed was
-- which palette shaded it.
local function drawFormArt(self, mon, image, trueColor, colors, originX, originY, box)
  originX, originY, box = originX or PIC_ORIGIN_X, originY or PIC_ORIGIN_Y,
    box or PIC_BOX
  local G = love.graphics
  local blank = colors and GbcPalette.color(colors, 1) or { 255, 255, 255 }
  G.setColor(blank[1] / 255, blank[2] / 255, blank[3] / 255, 1)
  G.rectangle("fill", originX, originY, box, box)

  local w, h = image:getWidth(), image:getHeight()
  local scale = math.min(box / w, box / h, 1)
  local x = originX + math.floor((box - w * scale) / 2)
  local y = originY + math.floor((box - h * scale) / 2)
  G.setColor(1, 1, 1, 1)
  local function body() G.draw(image, x, y, 0, scale, scale) end
  if trueColor or not (colors and GbcPalette.available()) then
    -- The palette bypass: a four-shade NATIVE set is art the GBC palette is
    -- RIGHT for and arrives through this same seam, so the FLAG decides
    -- rather than the source (National Dex's own src/gen2dexlist.lua
    -- M.unshaded's identical reasoning). Captured and restored rather than
    -- merely cleared, in case a caller further up the draw already has one
    -- bound.
    local previous = G.getShader and G.getShader() or nil
    if G.setShader then G.setShader() end
    local ok, err = pcall(body)
    if G.setShader then G.setShader(previous) end
    if not ok then error(err, 0) end
  else
    GbcPalette.with(colors, body)
  end
  G.setColor(1, 1, 1, 1)
end

-- Runs INSTEAD of vanilla drawPic, never after it -- unlike the types/stats
-- overlay, a picture cannot be corrected by blanking a tile field and
-- reprinting over it; the whole 7x7 block has to be decided before it is
-- drawn once. Skips the same two cases M.drawSummary skips and for the
-- same reason: neither drawEggPage nor the move-detail view ever reaches
-- drawPic at all, so there is nothing for this to override on either, and
-- an unformed Pokemon (or a form this module cannot resolve so much as a
-- picture for) returns false, which leaves the caller to run vanilla
-- exactly as if this module were never installed.
--
-- Cached per menu instance, per form and per shininess -- a menu is reused
-- for a whole party and this asks the neighbour, and the disk, at most once
-- per mon actually looked at rather than once per drawn frame.  Keyed by
-- formId rather than by path, and never through self.picCache: picCache
-- caches vanilla's OWN picFor by path, and this module's art comes from a
-- DIFFERENT resolution (the neighbour, or a form record's own spriteFront)
-- that must never be read back under the base species' picFor cache entry --
-- a stale or wrong picture surviving a screen re-entry is the one thing a
-- shared cache key would risk here.
function M.drawPic(self, resolveModule)
  local mon = self and self.mon
  if not mon or self.moveDetail or mon.isEgg then return false end
  local data = self.game and self.game.data
  local formId, formDef = formRecordFor(data, mon)
  if not formId then return false end

  local cache = self._battleFormsPicCache
  if not cache then cache = {} self._battleFormsPicCache = cache end
  local key = formId .. (mon.shiny and "\1shiny" or "")
  local art = cache[key]
  if art == nil then
    art = false
    local path, trueColor = neighbourPath(resolveModule, data, mon, formDef.form)
    if not path and type(formDef.spriteFront) == "string" and formDef.spriteFront ~= "" then
      path = formDef.spriteFront
      trueColor = nil -- the record's own path: drawn through vanilla's own shaded treatment, not this module's
    end
    if path then
      local image = self:picImage(path)
      if image then art = { image = image, trueColor = trueColor } end
    end
    cache[key] = art
  end
  if not art then return false end

  -- The SUMMARY picture's own per-mon palette, the identical source
  -- vanilla's own drawPicBlock reads (SummaryMenu.lua:925) -- shared by
  -- both branches below, unlike M.drawIcon's own lookup two sections down.
  local colors = self.palettes and mon.species
    and Palettes.monColors(self.palettes, mon.species, mon.shiny) or nil
  if art.trueColor == nil then
    -- The record fallback: reuse vanilla's OWN drawPicBlock rather than
    -- reimplementing it, so a form's picture is padded, backed and shaded
    -- exactly the way every OTHER mon's own picture already is on this
    -- screen -- nothing here ever guesses at that treatment independently.
    self:drawPicBlock(art.image, colors)
  else
    drawFormArt(self, mon, art.image, art.trueColor, colors)
  end
  return true
end

-- ---- the SUMMARY screen ---------------------------------------------------

-- Tile coordinates, not pixels -- Chrome.print and the rectangle blank below
-- both take (or are converted to) the same hlcoord grid every placement list
-- in SummaryMenu.lua is built from.
--
-- PrintMonTypes writes type 1 at (1,15) and type 2 at (1,16)
-- (SummaryMenu.lua:461-463); the widest type names (FIGHTING, ELECTRIC) are
-- eight characters, so an eight-tile field from column 1 clears exactly up to
-- column 9 -- the pink page's own vertical divider (drawVerticalDivider(9))
-- -- without ever touching it.
local TYPE_TX, TYPE_TW = 1, 8
local TYPE1_TY, TYPE2_TY = 15, 16

-- PrintTempMonStats prints each value three columns wide at column 17
-- (SummaryMenu.lua:530-533), two rows apart starting at row 9: attack,
-- defense, specialAttack, specialDefense, speed -- the blue page's own
-- STAT_KEYS order, which this list matches on purpose rather than
-- src/gen2forms.lua's STAT_KEYS (ordered attack/defense/speed/special*
-- there, to mirror Battle:transform's own copy loop) so a row index here
-- always lands on the row the vanilla draw used it for.
local STAT_TX, STAT_TW = 17, 3
local STAT_KEYS = { "attack", "defense", "specialAttack", "specialDefense", "speed" }

-- Blanks a tile-aligned field and, when text is given, reprints it -- the
-- same two-step src/formview.lua's own `paint` does, so a shorter form name
-- can never leave a trailing letter of whatever the vanilla draw put there.
local function paint(tx, ty, tw, th, text)
  local G = love.graphics
  G.setColor(1, 1, 1, 1)
  G.rectangle("fill", tx * 8, ty * 8, tw * 8, (th or 1) * 8)
  if text then Chrome.print(text, tx, ty) end
  G.setColor(1, 1, 1, 1)
end

local function typeName(id)
  if not id then return nil end
  return TypeNames[id] or id
end

-- Runs after the vanilla draw. Skips the move-detail view and an egg mon the
-- same way the vanilla class itself does (SummaryMenu:placements' own
-- dispatch) -- neither ever shows a type or a stat, so there is nothing here
-- to correct on either. Every value comes from M.resolve, so an unformed
-- Pokemon -- or a form this module cannot resolve -- leaves the vanilla draw
-- exactly as it drew it, and nothing here ever writes to the mon.
function M.drawSummary(self)
  local mon = self and self.mon
  if not mon or self.moveDetail or mon.isEgg or not Chrome then return end
  local form = M.resolve(self.game and self.game.data, mon)
  if not form then return end

  if self.page == BluePage then
    for i, key in ipairs(STAT_KEYS) do
      local value = form.stats[key]
      if value then
        paint(STAT_TX, 9 + (i - 1) * 2, STAT_TW, 1, Chrome.number(value, 3))
      end
    end
  elseif self.page ~= GreenPage then
    paint(TYPE_TX, TYPE1_TY, TYPE_TW, 1, typeName(form.types[1]))
    paint(TYPE_TX, TYPE2_TY, TYPE_TW, 1, typeName(form.types[2]))
  end
end

-- ---- the PARTY MENU list icon ----------------------------------------------
--
-- PartyMenu:iconFor(mon) (src/ui/gen2/PartyMenu.lua:534-551) reads a
-- species-keyed ICON_ sheet name off self.icons.species -- never mon.form --
-- so a formed Pokemon's row icon is whatever its BASE species always drew,
-- the identical species-keyed gap the SUMMARY picture had before 0.44.0.
-- iconFor DOES call a hook on the way (pokemon.icon, through
-- src.pokemon.Sprites.iconPath) and that hook is handed the mon -- so its
-- .form rides along -- but the hook exists for a mod supplying a WHOLE
-- REPLACEMENT 16x32 two-frame sheet per icon id, and no mod ships one keyed
-- per FORM: universal_sprites refuses Gen 2 icons outright (its own icons
-- registry wants a sheet NAME, not an image -- see that mod's own notes on
-- this exact gap). So this reads the identical fallback M.drawPic already
-- established for the picture: the form record's own spriteFront, the same
-- art the SUMMARY and battle screens already draw for it, fitted down into
-- the icon's 16x16 slot with the same drawFormArt this module already uses
-- to fit the same kind of art UP into the SUMMARY picture's 56x56 one.
--
-- Runs INSTEAD of vanilla drawIcon, for the reason M.drawPic runs instead of
-- picFor's caller: a still image has no two-frame walk cycle to alternate
-- and no cursor-slide bob of its own to draw underneath and then correct.
-- The held-item marker is the one piece of vanilla's own drawIcon this still
-- reproduces -- a Rotom or a Giratina wearing a persistent form is, by
-- construction, ALSO holding the item that grants it, so losing the marker
-- on exactly the mon this overlay draws would be a regression this module
-- introduced, not one it fixed.  Cached per instance and keyed by form id
-- rather than species, the same discipline M.drawPic's own cache keeps and
-- for the identical reason: two Rotom forms (or a Rotom and a fused
-- Necrozma sharing a base species some day) must never collide on one
-- cached image.
local ICON_BOX = 16

function M.drawIcon(self, mon, px, py, resolveModule)
  if not mon then return false end
  local data = self.game and self.game.data
  local formId, formDef = formRecordFor(data, mon)
  if not formId then return false end

  local cache = self._battleFormsIconCache
  if not cache then cache = {} self._battleFormsIconCache = cache end
  local key = formId .. (mon.shiny and "\1shiny" or "")
  local art = cache[key]
  if art == nil then
    art = false
    local path, trueColor = neighbourPath(resolveModule, data, mon, formDef.form)
    if not path and type(formDef.spriteFront) == "string" and formDef.spriteFront ~= "" then
      path = formDef.spriteFront
      trueColor = nil -- the record's own path: shaded the same way GbcPalette shades everything else here
    end
    if path and Assets then
      local okImage, image = pcall(Assets.image, path)
      if okImage and image then art = { image = image, trueColor = trueColor } end
    end
    cache[key] = art
  end
  if not art then return false end

  -- The party list's own shared palette (game/src/ui/gen2/PartyMenu.lua:
  -- 634-638 -- every row icon shades through PAL_OW_RED regardless of
  -- species), NOT the SUMMARY picture's per-mon Palettes.monColors -- see
  -- drawFormArt's own header for why the two callers cannot share a lookup.
  -- The held-item marker below already read this exact field correctly;
  -- the form's own picture, drawn here, used to read the wrong one.
  local pals = self.palettes and self.palettes.partyMenu
  local iconColors = pals and pals[1] or nil
  drawFormArt(self, mon, art.image, art.trueColor, iconColors, px, py, ICON_BOX)

  -- The held-item marker, reproduced from PartyMenu:drawIcon's own bottom-
  -- left overlay (src/ui/gen2/PartyMenu.lua:602-644): `self.heldMarkerRow`
  -- resolves through the instance's own metatable to the class's static
  -- function exactly as `self:heldMarkerImage()` already does two lines
  -- below it in that file, so this needs no reference to the PartyMenu
  -- class table itself.
  local markerRow = self.heldMarkerRow and self.heldMarkerRow(mon) or nil
  local marker = markerRow and self:heldMarkerImage() or nil
  if marker then
    local G = love.graphics
    local mw, mh = marker:getDimensions()
    local held = G.newQuad(0, markerRow * 8, 8, 8, mw, mh)
    local colors = iconColors
    local function paintMarker()
      G.setColor(1, 1, 1, 1)
      G.draw(marker, held, px, py + 8)
    end
    if colors and GbcPalette and GbcPalette.available() then
      GbcPalette.with(colors, paintMarker)
    else
      paintMarker()
    end
    G.setColor(1, 1, 1, 1)
  end
  return true
end

-- Its own require and its own guards, independent of the SUMMARY screen's:
-- PartyMenu is a different class, so a change to one must not silently take
-- the other down with it.  Called from M.install itself rather than exposed
-- as a second public entry point, because the two screens' fixes are one
-- feature (a formed Pokemon's own picture, wherever this generation draws
-- one) even though they patch two unrelated classes.
local function installPartyIcon(mod, resolveModule)
  local okParty, PartyMenu = pcall(require, "src.ui.gen2.PartyMenu")
  if not okParty or type(PartyMenu) ~= "table" then
    record("gen2formview: require(src.ui.gen2.PartyMenu) failed (%s)",
      tostring(PartyMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.PartyMenu is unavailable -- "
        .. "a Gen 2 formed Pokemon's picture will not show in the party list")
    end
    return false
  end
  if PartyMenu._battleFormsGen2FormViewIcon then
    record("gen2formview: PartyMenu was already patched -- this load "
      .. "wrapped nothing and the wrapper in place belongs to an earlier load")
    return true
  end
  local okAssets, AssetsMod = pcall(require, "src.render.Assets")
  Assets = okAssets and AssetsMod or nil

  if type(PartyMenu.drawIcon) ~= "function" or not GbcPalette or not Palettes
      or not Assets then
    record("gen2formview: install: PartyMenu.drawIcon %s, GbcPalette %s, "
      .. "Palettes %s, Assets %s -- the party list icon fix is disabled",
      type(PartyMenu.drawIcon), tostring(GbcPalette ~= nil),
      tostring(Palettes ~= nil), tostring(Assets ~= nil))
    if mod.log then
      mod.log:error("battle_forms: the party list icon could not be patched "
        .. "(a required class has changed shape) -- a Gen 2 formed "
        .. "Pokemon's list icon will still show its base species")
    end
    return false
  end

  local vanillaDrawIcon = PartyMenu.drawIcon
  PartyMenu._battleFormsGen2FormViewIcon = true
  PartyMenu.drawIcon = function(self, mon, px, py)
    local ok, drew = pcall(M.drawIcon, self, mon, px, py, resolveModule)
    if ok and drew then return end
    if not ok then
      record("gen2formview: PartyMenu.drawIcon overlay failed (%s)", tostring(drew))
    end
    return vanillaDrawIcon(self, mon, px, py)
  end
  record("gen2formview: install: wrapped PartyMenu.drawIcon")
  return true
end

-- pcall the requires, refuse when a shape is not the one expected, guard
-- against a second install patching an already-patched class -- the same
-- discipline src/formview.lua and src/gen2forms.lua both keep. A guard that
-- refuses must say so out loud (project rule #6).
--
-- Wraps drawPanel, not draw -- confirmed against a real, live Gold boot
-- rather than assumed from the class's own shape.  SummaryMenu:draw() is
-- defined as nothing but `self:drawPanel()` (SummaryMenu.lua:1121-1123), and
-- a fixture harness calling SummaryMenu.draw(fakeSelf) directly cannot tell
-- the two apart -- but the real render path never calls :draw() at all: a
-- driver that counted live calls through a full START -> POKeMON -> STATS
-- navigation saw drawPanel invoked on every frame and draw not once, the
-- same way every other Gen 2 screen in this engine (MartMenu, PartyMenu,
-- BoxMenu, ...) is driven through its own drawPanel by whatever owns the
-- frame, with draw (where a class bothers to define one at all) left an
-- unused alias.  Wrapping draw wraps a method the engine never calls, so the
-- earlier version of this file installed cleanly, passed every fixture
-- check, and never painted a single pixel in a real game.
function M.install(mod)
  local okSummary, SummaryMenu = pcall(require, "src.ui.gen2.SummaryMenu")
  if not okSummary or type(SummaryMenu) ~= "table" then
    record("gen2formview: require(src.ui.gen2.SummaryMenu) failed (%s)",
      tostring(SummaryMenu))
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.SummaryMenu is unavailable -- "
        .. "a Gen 2 formed Pokemon's types and stats will not show on the "
        .. "SUMMARY screen")
    end
    return false
  end
  -- Already patched: the STATS/TYPES and picture wraps below are skipped
  -- (SummaryMenu's own idempotency), but PartyMenu below is a DIFFERENT
  -- class this load has not necessarily reached yet -- an early return here
  -- used to skip installPartyIcon on every call after the first, which is
  -- exactly the bug a second M.install (adopt.lua's own re-install path, or
  -- simply two mods sharing this module) would have hit silently.
  -- resolveModule is shared by SummaryMenu's own picture wrap below and by
  -- installPartyIcon at the end -- created once, unconditionally, so an
  -- already-patched SummaryMenu (which skips everything else in this
  -- function) still hands PartyMenu a working one.
  local resolveModule = spriteModule()

  -- Already patched: the STATS/TYPES and picture wraps below are skipped
  -- (SummaryMenu's own idempotency), but PartyMenu below is a DIFFERENT
  -- class this load has not necessarily reached yet -- an early return here
  -- used to skip installPartyIcon on every call after the first, which is
  -- exactly the bug a second M.install (two mods sharing this exact module
  -- version, or a re-install after adoption) would have hit silently.
  local alreadyPatched = SummaryMenu._battleFormsGen2FormView == true
  if alreadyPatched then
    record("gen2formview: SummaryMenu was already patched -- this load "
      .. "wrapped nothing and the wrapper in place belongs to an earlier load")
  elseif type(SummaryMenu.drawPanel) ~= "function" then
    record("gen2formview: SummaryMenu.drawPanel is not a function -- the "
      .. "SUMMARY screen overlay is disabled")
    if mod.log then
      mod.log:error("battle_forms: src.ui.gen2.SummaryMenu.drawPanel has "
        .. "changed shape -- a Gen 2 formed Pokemon's types and stats will "
        .. "not show on the SUMMARY screen")
    end
    return false
  else
    local okChrome, ChromeMod = pcall(require, "src.ui.gen2.Chrome")
    Chrome = okChrome and ChromeMod or nil
    record("gen2formview: install: Chrome %s", okChrome and "resolved"
      or ("unavailable (" .. tostring(ChromeMod) .. ")"))

    BluePage = SummaryMenu.BLUE_PAGE or BluePage
    GreenPage = SummaryMenu.GREEN_PAGE or GreenPage
    TypeNames = SummaryMenu.TYPE_NAMES or {}

    local vanillaDraw = SummaryMenu.drawPanel
    SummaryMenu._battleFormsGen2FormView = true
    SummaryMenu.drawPanel = function(self)
      vanillaDraw(self)
      local ok, err = pcall(M.drawSummary, self)
      if not ok then
        record("gen2formview: SummaryMenu.drawPanel overlay failed (%s)", tostring(err))
      end
    end
    record("gen2formview: install: wrapped SummaryMenu.drawPanel")

    -- The picture (and, below, the party list icon): a courtesy on top of a
    -- courtesy.  GbcPalette/Palettes are needed only to shade the record
    -- fallback and to bypass shading for true-colour art -- draw-only
    -- dependencies in exactly the sense src/formview.lua's own header uses
    -- that word for Font, so their absence disables the picture and icon
    -- fixes alone rather than this module's whole install.
    local okGbc, GbcPaletteMod = pcall(require, "src.render.GbcPalette")
    local okPalettes, PalettesMod = pcall(require, "src.world.gen2.Palettes")
    GbcPalette = okGbc and GbcPaletteMod or nil
    Palettes = okPalettes and PalettesMod or nil

    if type(SummaryMenu.drawPic) ~= "function" or not GbcPalette or not Palettes then
      record("gen2formview: install: SummaryMenu.drawPic %s, GbcPalette %s, "
        .. "Palettes %s -- the picture fix is disabled, types and stats are not",
        type(SummaryMenu.drawPic), tostring(GbcPalette ~= nil), tostring(Palettes ~= nil))
      if mod.log then
        mod.log:error("battle_forms: the SUMMARY screen's picture could not be "
          .. "patched (a required class has changed shape) -- a Gen 2 formed "
          .. "Pokemon's picture will still show its base species")
      end
    else
      local vanillaDrawPic = SummaryMenu.drawPic
      SummaryMenu._battleFormsGen2FormViewPic = true
      SummaryMenu.drawPic = function(self)
        local ok, drew = pcall(M.drawPic, self, resolveModule)
        if ok and drew then return end
        if not ok then
          record("gen2formview: SummaryMenu.drawPic overlay failed (%s)", tostring(drew))
        end
        return vanillaDrawPic(self)
      end
      record("gen2formview: install: wrapped SummaryMenu.drawPic")
    end
  end

  -- The party list icon: a separate class (src/ui/gen2/PartyMenu.lua), so
  -- its own require and its own guards -- a SUMMARY screen that failed above
  -- must not also silently take the party list icon down with it, and vice
  -- versa; see M.drawIcon's own header for what this reads and why.
  installPartyIcon(mod, resolveModule)

  return true
end

return M
