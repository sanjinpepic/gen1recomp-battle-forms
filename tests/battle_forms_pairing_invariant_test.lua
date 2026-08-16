-- The invariant src/persistent.lua's header used to claim: "No species is
-- both a fusion base and an appliance user, so the two can never be asked
-- about the same Pokemon."  Ultra Burst (0.22.0) broke it -- Necrozma is a
-- fusion base (data/fusion.lua) AND an eligibility.STAMP user
-- (data/ultraburst.lua, through src/stone.lua's PAIRED install) -- and this
-- suite exists so the claim is enforced rather than merely written down.
--
-- It does two things. First, it AUDITS every pairing table this mod owns for
-- a species that is both a key in data/fusion.lua and a key in any table
-- that reaches src/persistent.lua's M.mark: megas, primal reversion, Ultra
-- Burst and the species Z-Crystals (all through src/stone.lua's PAIRED
-- install), and data/persistent.lua's own appliances and held forms (through
-- src/persistent.lua's own install). The audit is computed from the data
-- files themselves rather than a hand-written list of names, so it cannot go
-- stale the way the header's prose claim did.
--
-- Second, for every overlap the audit finds, it drives the REAL item-effect
-- closures -- fusing through src/fusion.lua's own install, then giving the
-- colliding item through whichever of src/stone.lua's or src/persistent.lua's
-- own install actually registers it -- rather than hand-setting mon.form and
-- the stamp fields the way a fixture that never drove this bug always did.
-- That is the shape the bug actually lives in: the interaction between two
-- closures, not either module's own read of a field a test set directly.
--
-- NECROZMA/ULTRANECROZIUM_Z is the one overlap the shipped data has today,
-- and the failure this pins is the 0.35.0 report: giving a fused Necrozma
-- the crystal called src/persistent.lua's M.mark, which could not resolve
-- Necrozma against data/persistent.lua's own table (Necrozma has no row
-- there) and unconditionally cleared mon.form -- wiping the Dusk Mane or
-- Dawn Wings suffix src/fusion.lua had just set, which is why the party
-- sprite fell back to plain Necrozma. Written data-driven rather than pinned
-- to Necrozma by name, so a species added to any pairing table later that
-- repeats the same collision is caught here too, not just reported in a
-- comment nobody re-checks.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Fusion = dofile(MOD .. "/src/fusion.lua")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Speciesz = dofile(MOD .. "/src/speciesz.lua")
local Boxes = require("src.pokemon.Boxes")

local fusionRows = dofile(MOD .. "/data/fusion.lua")
local fuserIndices = dofile(MOD .. "/data/fusers.lua")
local persistentRows = dofile(MOD .. "/data/persistent.lua")
local ultraRows = dofile(MOD .. "/data/ultraburst.lua")
local rawMegas = dofile(MOD .. "/data/megas.lua")
local primalsRows = dofile(MOD .. "/data/primals.lua")
local speciesZRows = dofile(MOD .. "/data/speciesz.lua")
local speciesZPairings = Speciesz.pairings(speciesZRows)
local megas = Megaset.select(rawMegas, Megaset.ALL)

local applianceIndices = dofile(MOD .. "/data/appliances.lua")
local heldFormIndices = dofile(MOD .. "/data/heldforms.lua")
local plateIndices = dofile(MOD .. "/data/plates.lua")
local memoryIndices = dofile(MOD .. "/data/memories.lua")
local driveIndices = dofile(MOD .. "/data/drives.lua")
local persistentIndices = {}
for itemId, index in pairs(applianceIndices) do persistentIndices[itemId] = index end
for itemId, index in pairs(heldFormIndices) do persistentIndices[itemId] = index end
for itemId, index in pairs(plateIndices) do persistentIndices[itemId] = index end
for itemId, index in pairs(memoryIndices) do persistentIndices[itemId] = index end
for itemId, index in pairs(driveIndices) do persistentIndices[itemId] = index end

local stoneIndices = dofile(MOD .. "/data/stones.lua")
local orbIndices = dofile(MOD .. "/data/orbs.lua")
local ultraCrystalIndices = dofile(MOD .. "/data/ultracrystal.lua")
local speciesZCrystalIndices = dofile(MOD .. "/data/speciescrystals.lua")

-- Wired exactly the way main.lua wires the two modules together: persistent
-- is handed fusion so its M.mark can ask the same question
-- src/resolve.lua's own sweep already asks first.
Fusion.bind({ forms = Forms, rows = fusionRows, battlerof = Battlerof })
Persistent.bind({ forms = Forms, eligibility = E, rows = persistentRows,
                  battlerof = Battlerof, fusion = Fusion })
Stone.bind(E, Persistent)

local function fakeMod()
  local mod = { items = {}, effects = {}, errors = {} }
  mod.content = {
    items = { register = function(_, id, record) mod.items[id] = record end },
    item_effects = {
      register = function(_, id, record) mod.effects[id] = record end },
  }
  mod.log = { error = function(_, fmt, ...)
    mod.errors[#mod.errors + 1] = string.format(fmt, ...)
  end }
  return mod
end

-- Every table this mod stamps a Pokemon through and then calls
-- src/persistent.lua's M.mark from -- src/stone.lua's PAIRED install for
-- four of them, src/persistent.lua's own install for the fifth.
local STAMP_TABLES = {
  { name = "megas", pairing = megas, indices = stoneIndices, viaStone = true },
  { name = "primal reversion", pairing = primalsRows, indices = orbIndices,
    viaStone = true },
  { name = "Ultra Burst", pairing = ultraRows, indices = ultraCrystalIndices,
    viaStone = true },
  { name = "species Z-Crystals", pairing = speciesZPairings,
    indices = speciesZCrystalIndices, viaStone = true },
  { name = "appliances and held forms", pairing = persistentRows,
    indices = persistentIndices, viaStone = false },
}

-- ------- the audit -----------------------------------------------------

-- Every species that is a fusion base (a key in data/fusion.lua) AND a key
-- in one of the tables above.  Computed from the data files themselves, not
-- a hand-written list -- that is what makes it an audit rather than a note.
local overlaps = {}
for species in pairs(fusionRows) do
  for _, stampTable in ipairs(STAMP_TABLES) do
    if stampTable.pairing[species] then
      overlaps[#overlaps + 1] = { species = species, stampTable = stampTable }
    end
  end
end

T.check(#overlaps > 0, "the audit found at least one overlap to exercise -- "
  .. "if this ever reads zero, the reconciliation below is untested; find a "
  .. "species that still collides (Necrozma/Ultra Burst does today) before "
  .. "trusting a green run of this file")

do
  local named = {}
  for _, overlap in ipairs(overlaps) do
    named[#named + 1] = overlap.species .. " / " .. overlap.stampTable.name
  end
  table.sort(named)
  T.eq(table.concat(named, ", "), "NECROZMA / Ultra Burst",
    "the only overlap the shipped data carries today is the one this bug "
      .. "report was about -- if this fails because the list is now longer, "
      .. "the loop below already covers the new one too")
end

-- ------- the reconciliation, driven for every overlap found ------------

local function firstFusionPairing(species)
  for itemId, byPartner in pairs(fusionRows[species]) do
    for partnerSpecies, formId in pairs(byPartner) do
      return itemId, partnerSpecies, formId
    end
  end
end

local function firstOtherItem(pairing, species)
  for itemId in pairs(pairing[species]) do return itemId end
end

local function newMon(species)
  return { species = species, level = 50, hp = 100,
           dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
           statExp = {}, moves = {} }
end

for _, overlap in ipairs(overlaps) do
  local species = overlap.species
  local stampTable = overlap.stampTable

  local fuseItemId, partnerSpecies, formId = firstFusionPairing(species)
  local otherItemId = firstOtherItem(stampTable.pairing, species)
  local otherFormId = stampTable.pairing[species][otherItemId]

  -- A minimal national_dex fixture: only what src/fusion.lua's settle and
  -- src/persistent.lua's settle actually read (a `form` suffix on the fused
  -- record) -- this suite is about which field survives, not about stats or
  -- art, both of which are pinned elsewhere (tests/battle_forms_art_test.lua,
  -- tests/battle_forms_formids_test.lua).
  local DATA = { pokemon = { [formId] = { form = "FUSEDFORM" } } }
  if type(otherFormId) == "string" then
    DATA.pokemon[otherFormId] = { form = "OTHERFORM" }
  end

  local base, partner = newMon(species), newMon(partnerSpecies)
  local save = { party = { base, partner }, inventory = {} }
  Boxes.ensure(save)

  local fusionMod = fakeMod()
  Fusion.install(fusionMod, fusionRows, fuserIndices)
  local fuseUse = fusionMod.effects[fuseItemId].use
  local result = fuseUse({ data = DATA, save = save, target = base })
  T.eq(result, "kept", stampTable.name .. ": " .. species .. " fuses with "
    .. partnerSpecies .. " through the real item effect")
  T.eq(base.form, "FUSEDFORM", stampTable.name .. ": " .. species
    .. " carries the fused marker before the collision")
  T.eq(base[Fusion.STAMP], partnerSpecies, stampTable.name
    .. ": and the fusion stamp names the partner")

  local otherMod = fakeMod()
  if stampTable.viaStone then
    Stone.install(otherMod, stampTable.pairing, stampTable.pairing,
                  stampTable.indices)
  else
    Persistent.install(otherMod, stampTable.pairing, stampTable.indices)
  end
  T.eq(#otherMod.errors, 0, stampTable.name
    .. ": the colliding item installs without complaint")
  local otherUse = otherMod.effects[otherItemId].use
  otherUse({ data = DATA, target = base })

  -- The bug, pinned as a fact: giving the colliding item must not wipe the
  -- fusion's marker.  src/persistent.lua's M.mark has to ask src/fusion.lua
  -- before it falls back to clearing mon.form -- the same order
  -- src/resolve.lua's own sweep already uses and cites as "the order to be
  -- wrong in if that invariant ever stops being true."  It just did.
  T.eq(base.form, "FUSEDFORM", stampTable.name .. ": giving " .. species
    .. " " .. otherItemId .. " must not wipe the fusion's marker")
  T.eq(base[Fusion.STAMP], partnerSpecies, stampTable.name
    .. ": the fusion itself -- which item is still stamped, and to whom -- "
    .. "is untouched by the collision")
end

T.finish("battle_forms_pairing_invariant")
