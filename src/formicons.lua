-- Party-list icons for a persistent or fused form -- the identical question
-- src/formview.lua and src/gen2formview.lua already ask about types and
-- stats, answered here for the one Pokemon-art seam BOTH games' party lists
-- already run every icon through: src/pokemon/Sprites.lua's iconPath, fired
-- from game/src/ui/PartyMenu.lua (Red, drawIcon:227) and
-- game/src/ui/gen2/PartyMenu.lua (Gold, iconFor:539) alike, through the one
-- shared "pokemon.icon" hook.  One subscription here covers both games --
-- there was previously no fix on either.
--
-- WHY A HOOK, NOT A WRAPPED drawIcon.  0.45.0 through 0.50.0 wrapped Gold's
-- PartyMenu:drawIcon directly: fetch a form's battle art, fit it into the
-- icon's 16x16 slot, look up the party list's own shared palette by hand,
-- suppress the backing fill drawFormArt otherwise paints.  Each of those
-- four steps reimplemented something vanilla drawIcon already does for
-- free, and each produced its own bug in turn (wrong sprite, wrong colour,
-- a stray background block).  Every one of those steps is vanilla's own job
-- the moment something upstream of it answers with the right PATH instead
-- -- Sprites.iconPath's caller already resolves the frame, the quad, the
-- palette (self.palettes.partyMenu[1] on Gold) and the held-item marker on
-- top, because that caller IS drawIcon itself.  So the fix here is a single
-- hook subscription that hands back a path when one is verified to exist,
-- and nothing else: "compose, do not capture" -- every case this module has
-- no verified answer for calls `next(vanillaPath, ctx)`, unchanged.
--
-- WHERE THE ART COMES FROM, AND WHY THIS ASKS FOR IT THE WAY IT DOES.
-- universal_sprites 0.26.0 builds real hand-drawn icons for 28 of this
-- mod's 364 alternate forms and registers each base species' OWN icon into
-- the engine's icons content registry -- but that registry has no form
-- dimension to register a FORM's icon into (its own main.lua says so), so
-- the 28 forms' files sit on disk with no path any hook or export ever
-- names.  There is also no cross-mod filesystem read in this engine's mod
-- API at all: mod:read is sandboxed to a mod's own root (src/mods/
-- SafePath.lua refuses ".."), love.filesystem is denied to every mod
-- outright (src/mods/Sandbox.lua's own BLOCKED_LOVE table), and
-- universal_sprites exports exactly one sprite-resolving function
-- (resolveSprite), which answers from the SPRITE SET a player has picked,
-- never from the icon build -- confirmed by reading dev/main.lua's own icon
-- registration block, which writes only to mod.content.icons and touches no
-- `sets` registry a hook could reach.  So this module cannot ask the sprite
-- mod BY NAME for a form's icon file the way src/gen2formview.lua's own
-- neighbourPath asks for battle art through the pokemon.sprite hook.
--
-- What IS reachable is `vanillaPath` itself: the base species' OWN icon,
-- already resolved by PartyMenu before this hook ever runs.  When
-- universal_sprites supplied it, that path is always "<some directory>/
-- <SPECIES>.png" -- Red's whole-file crop, Gold's two-frame strip -- and a
-- form's OWN file (when the sprite mod built one) sits in the SAME
-- directory, spelled "<SPECIES>_<FORM>.png" (confirmed against that mod's
-- own generated index, dev/data/sprites/generated/icons.lua, current as of
-- its 0.26.0).  So the form's path is one filename away from the base path
-- this hook is handed for free, and this module never trusts the guess on
-- its own say-so: Assets.exists checks the real disk before ever answering
-- with it.  An absent form (any of the other 336), an absent or disabled
-- sprite mod, or a future rebuild that lays the art out differently all
-- fall through to `next` exactly as if this module had never run -- a wrong
-- guess costs nothing worse than the base icon a player would have seen
-- anyway, and the check is what keeps it from ever costing more than that.
local M = {}

local deps = nil
function M.bind(modules) deps = modules end

local function record(fmt, ...)
  local diag = deps and deps.diag
  if diag then pcall(diag.record, fmt, ...) end
end

-- Resolved lazily, at install time: a draw-only dependency this module
-- treats as a courtesy rather than a hard requirement, the same discipline
-- src/formview.lua and src/gen2formview.lua both keep for theirs.
local Assets = nil

-- Identical order, identical reasoning, to src/formview.lua's and
-- src/gen2formview.lua's own formIdFor: fusion is asked first because no
-- species is both a fusion base and a persistent-form holder, so the order
-- can never actually decide an outcome by itself.  Neither gates on
-- mon.form the way src/formview.lua's Gen 1 helper safely can on its own --
-- this module is shared by both games, and Gen 2's own mon.form can lag a
-- fresh item GIVE by a whole battle (src/gen2formview.lua's identical
-- header has the full reasoning); asking fresh every time costs one cheap
-- lookup on an unformed mon's icon and is never wrong on either game.
local function formIdFor(mon)
  if not mon then return nil end
  local id = deps and deps.fusion and deps.fusion.formIdFor(mon)
  if id then return id end
  return deps and deps.persistent and deps.persistent.formIdFor(mon)
end

-- The form suffix a real icon file is named for (e.g. "WASH"), read off the
-- form record's own `.form` field -- the same field every alternate-form
-- species record in data.pokemon carries (national_dex's own generation)
-- and the identical source universal_sprites' own icon build keys its
-- `forms` table by, so a hit here always names the same form the sprite mod
-- would have built art for, never a guess at one.
local function formSuffix(data, formId)
  local formDef = formId and data and data.pokemon and data.pokemon[formId]
  local suffix = formDef and formDef.form
  return type(suffix) == "string" and suffix ~= "" and suffix or nil
end

-- vanillaPath's own directory and species stem, reused verbatim -- this
-- module never invents a mod root or a set folder name of its own, it only
-- ever asks whether the SAME directory the caller already resolved also
-- holds "<species>_<suffix>.png" beside the file that is there.  Refuses
-- outright the moment the stem does not match `species`: a vanilla ROM
-- icon, a different icon mod's own naming, or any path not shaped like
-- universal_sprites' own, so the string surgery below only ever runs on a
-- path this module has reason to believe is that mod's.
local function candidatePath(vanillaPath, species, suffix)
  if type(vanillaPath) ~= "string" or type(species) ~= "string" then
    return nil
  end
  local dir, stem = vanillaPath:match("^(.-)([%w_]+)%.png$")
  if not dir or stem ~= species then return nil end
  return dir .. species .. "_" .. suffix .. ".png"
end

-- The hook body, exported so a test can drive it directly the way
-- src/gen2formview.lua's own M.drawIcon used to be reached, before this
-- module replaced it.  `next` is the rest of the chain (another mod's own
-- pokemon.icon wrap, or Sprites.iconPath's own identity fallback), and
-- every path out of this function that is not a verified real file calls it
-- unchanged rather than answering with a guess.
function M.resolvePath(next, vanillaPath, ctx)
  if type(ctx) ~= "table" then return next(vanillaPath, ctx) end
  local formId = formIdFor(ctx.mon)
  local suffix = formId and formSuffix(ctx.data, formId)
  local candidate = suffix and candidatePath(vanillaPath, ctx.species, suffix)
  if candidate and Assets and Assets.exists(candidate) then
    record("formicons: %s wearing %s -> %s", tostring(ctx.species),
      tostring(suffix), candidate)
    return candidate
  end
  return next(vanillaPath, ctx)
end

-- Idempotency is a FLAG here, not a marker stashed on a patched class -- a
-- hook is a chain any number of subscribers (or this mod, reloaded) can
-- join, and there is no single class this module patches to stamp the way
-- SummaryMenu._battleFormsGen2FormView marks src/gen2formview.lua's own
-- wrap.  A second install must add nothing further to that chain, or every
-- reload after the first would answer the same question twice over.
local installed = false

function M.install(mod)
  if installed then
    record("formicons: already installed -- this load wrapped nothing further")
    return true
  end
  local okAssets, AssetsMod = pcall(require, "src.render.Assets")
  Assets = (okAssets and type(AssetsMod) == "table"
    and type(AssetsMod.exists) == "function") and AssetsMod or nil
  if not Assets then
    record("formicons: src.render.Assets is unavailable or has changed shape (%s)",
      tostring(AssetsMod))
    if mod.log then
      mod.log:error("battle_forms: src.render.Assets is unavailable -- a "
        .. "formed Pokemon's party list icon will show its base species'")
    end
    return false
  end
  mod.hooks:wrap("pokemon.icon", M.resolvePath, 0)
  installed = true
  record("formicons: install: wrapped pokemon.icon")
  return true
end

return M
