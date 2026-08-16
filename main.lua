-- Mid-battle form changes.  A form change marks the mon (mon.form) and
-- overrides the active battler's curStats/curTypes, the same shape the
-- engine's own Transform uses -- mon.species is never touched.  Mega
-- evolution is one trigger on that primitive; Primal Reversion and stance
-- changes are the same shape and are why the primitive is not called "mega".
--
-- Nothing here runs inside performMove.  That is the whole point: a mega that
-- resolves outside the move path cannot spend PP, cannot be Disabled and
-- cannot be copied by Metronome, because it was never a move.

-- A mod's own files are not on package.path, so siblings are read and
-- compiled rather than required.  A sibling that fails returns nil and the
-- load carries on -- an assert inside a mod callback takes the whole load
-- down, and a player is better served by a degraded mod than by none.
local function loadSibling(mod, name)
  local source = mod:read(name)
  if not source then
    mod.log:error("%s is missing -- reinstall the mod zip", name)
    return nil
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. name)
  if not chunk then
    mod.log:error("%s failed to compile (%s) -- reinstall the mod zip",
      name, tostring(err))
    return nil
  end
  local ok, result = pcall(chunk)
  if not ok then
    mod.log:error("%s errored while loading (%s)", name, tostring(result))
    return nil
  end
  return result
end

-- Which generation this boot is, the same read national_dex's own
-- src/gen2shape.lua makes and for the identical reason: `generation` is a
-- Gen 2 constant the ROM import stamps, readable in the entry chunk because
-- Gold fills data.gen2Constants before the loader runs, so it answers 2 on
-- Gold and nil on Red/Blue/Yellow with no live battle or save in hand yet.
-- Deliberately NOT require("src.core.GameVersion") for the same reason that
-- file gives: it answers correctly but trips the dev shim's engine-internals
-- warning for something the sanctioned mod API already exposes. Duplicated
-- here rather than reached across the mod boundary -- a mod's own files are
-- the only ones `mod:read` can see, and national_dex's src/gen2shape.lua is
-- a different mod's file.
local function generationOf(mod)
  local ok, value = pcall(function()
    return mod.content.constants:get("generation")
  end)
  if ok and type(value) == "number" then return value end
  return 1
end

-- The type a Terastallization turns a Pokemon into, as the rows the manager
-- draws for it.  The list lives here rather than in src/tera.lua because the
-- options are declared before any sibling is read, so that they reach the
-- settings screen even on a load where a sibling could not be: an option
-- defined out of a file that failed to load is an option a player cannot see.
--
-- Red's fifteen come first and DARK, STEEL and FAIRY last, because those three
-- exist only once National Dex has registered a chart over the top of the
-- cart's own -- and the manager's choice row steps rather than wraps, so the
-- three that may not resolve sit at the far end of it rather than in the middle
-- of it.  Only PSYCHIC differs between what is stored and what is shown: the
-- engine's id for it is PSYCHIC_TYPE.
local TERA_CHOICES = {
  { "NORMAL", "NORMAL" }, { "FIGHTING", "FIGHTING" }, { "FLYING", "FLYING" },
  { "POISON", "POISON" }, { "GROUND", "GROUND" }, { "ROCK", "ROCK" },
  { "BUG", "BUG" }, { "GHOST", "GHOST" }, { "FIRE", "FIRE" },
  { "WATER", "WATER" }, { "GRASS", "GRASS" }, { "ELECTRIC", "ELECTRIC" },
  { "PSYCHIC", "PSYCHIC_TYPE" }, { "ICE", "ICE" }, { "DRAGON", "DRAGON" },
  { "DARK", "DARK" }, { "STEEL", "STEEL" }, { "FAIRY", "FAIRY" },
}

return function(mod)
  -- OFFICIAL is the 48 mega evolutions the mainline games shipped; ALL adds
  -- the 48 more the National Dex data carries that never did.  It gates what
  -- the shelf sells and what a stone is allowed to do -- never which stones
  -- exist, see src/megaset.lua.
  mod.options:define({
    { key = "megas", label = "MEGA EVOLUTIONS", type = "choice",
      default = "official", choices = { { "OFFICIAL", "official" },
                                        { "ALL", "all" } } },
    -- Which type a Terastallization changes the Pokemon into.  It is an option
    -- rather than something carried on the Pokemon because there is nowhere on
    -- a Gen 1 Pokemon a player could set one -- see src/tera.lua -- and NORMAL
    -- rather than the mon's own type because terastallizing into the type you
    -- already are is a mechanic that does nothing at all.
    { key = "tera_type", label = "TERA TYPE", type = "choice",
      default = "NORMAL", choices = TERA_CHOICES },
    -- diagnostic: records why the menu cell and primal reversion did or did
    -- not happen, into mod storage (src/diag.lua).  Off unless a bug is being
    -- chased -- it answers questions a player never has.
    { key = "debug_trace", label = "DEBUG TRACE", type = "choice",
      default = "off",
      choices = { { "OFF", "off" }, { "ON", "on" } } },
  })

  local names = { "src/battlerof.lua", "src/eligibility.lua", "src/forms.lua", "src/megaset.lua",
                  "src/stone.lua", "src/keyitems.lua", "src/shop.lua",
                  "src/arm.lua",
                  "src/transforms.lua", "src/mega.lua", "src/dragonascent.lua",
                  "src/terablasttm.lua", "src/speciesbasemoves.lua",
                  "src/dynamax.lua",
                  "src/substitute.lua", "src/maxmoves.lua", "src/gmaxmoves.lua",
                  "src/tera.lua", "src/zmoves.lua", "src/speciesz.lua",
                  "src/resolve.lua",
                  "src/primal.lua", "src/persistent.lua", "src/fusion.lua",
                  "src/ultraburst.lua",
                  "src/conditional.lua", "src/diag.lua",
                  "src/anim.lua", "src/announce.lua", "src/adopt.lua",
                  "src/overlay.lua", "src/formmenu.lua", "src/menu.lua", "src/boxmark.lua",
                  "src/formview.lua", "src/gen2forms.lua", "src/gen2formview.lua",
                  "src/gen2shop.lua", "src/gen2menu.lua",
                  "src/zmovemenu.lua", "src/hpscale.lua",
                  "data/megas.lua", "data/stones.lua", "data/primals.lua",
                  "data/orbs.lua", "data/keyitems.lua", "data/conditional.lua",
                  "data/gigantamax.lua", "data/maxmoves.lua", "data/gmaxmoves.lua",
                  "data/zmoves.lua", "data/crystals.lua", "data/terablast.lua",
                  "data/tm171.lua",
                  "data/speciesz.lua", "data/speciescrystals.lua",
                  "data/persistent.lua", "data/appliances.lua",
                  "data/fusion.lua", "data/fusers.lua", "data/heldforms.lua",
                  "data/ultraburst.lua", "data/ultracrystal.lua",
                  "data/plates.lua", "data/memories.lua", "data/drives.lua" }
  local m = {}
  for _, name in ipairs(names) do
    m[name] = loadSibling(mod, name)
    if not m[name] then return end
  end

  local megaset = m["src/megaset.lua"]
  local rawMegas = m["data/megas.lua"]
  local indices = m["data/stones.lua"]
  local eligibility = m["src/eligibility.lua"]
  -- Tells a Gen 1 battler wrapper (ev.battler.mon) from a Gen 2 payload,
  -- where ev.battler already IS the mon (game/src/battle/gen2/Battle.lua
  -- :3004).  Bound into every handler below that used to read `.mon` straight
  -- off an event payload or a live `battle.player`/`battle.enemy` field, so
  -- widening the manifest past "gen1" later is not also an audit of every one
  -- of those reads.
  local battlerof = m["src/battlerof.lua"]
  local anim = m["src/anim.lua"]
  local state = m["src/arm.lua"].new()
  local diag = m["src/diag.lua"]

  -- Computed early, ahead of everything below that reads it (starting with
  -- src/keyitems.lua's own registration a few lines down) -- `generation` is
  -- read once here, at load, the way national_dex's own src/gen2shape.lua
  -- reads it, and `gen2` is the flag every Gen 2 branch in this file uses,
  -- never which fields a payload happens to carry (HANDOFF's own Gen 2
  -- trap). src/gen2forms.lua is handed in unconditionally; only the flag
  -- decides whether it is ever called.
  local generation = generationOf(mod)
  local gen2 = generation == 2
  local gen2forms = m["src/gen2forms.lua"]

  for _, pair in ipairs(megaset.problems(rawMegas)) do
    mod.log:error("data/megas.lua: %s carries no officialness marker -- wrap "
      .. "its form id in official() or extended(); until then it is in "
      .. "neither set and its stone does nothing", pair)
  end

  -- Two tables from one source: every pair for registration, the chosen set
  -- for everything that decides whether a mega may happen.
  local allMegas = megaset.select(rawMegas, megaset.ALL)
  local megas = megaset.select(rawMegas, mod.options:get("megas"))

  -- Primal reversion's pairings are never selected between, so the table the
  -- orbs are registered from and the table their effects read are the same
  -- one -- where the mega stones need the full set for the first and the
  -- chosen set for the second.
  local primals = m["data/primals.lua"]
  local orbIndices = m["data/orbs.lua"]

  -- The other tier of item: worn by the trainer rather than stamped on a mon,
  -- and what decides whether a mechanic is on offer at all.  Registered before
  -- either shelf is stocked and unconditionally, because an item a save carries
  -- has to stay nameable no matter what any gate later says about it.
  local keyitems = m["src/keyitems.lua"]
  local keyIndices = m["data/keyitems.lua"]
  -- gen2 takes the dead USE verb off these on Gold: they carry no `use`
  -- effect at all (the gate is a live bag read, src/keyitems.lua's own
  -- M.held), so a USE row that reaches Game2:usePartyItem's data-less
  -- dispatch and does nothing looked like a broken mechanic rather than an
  -- item with no field action to begin with.
  keyitems.install(mod, keyIndices, gen2)

  -- The third family that goes through the same stamp, and the one with no
  -- pairing table: a Z-Crystal fits every species, so what it is checked
  -- against is the moveset in front of it and not the Pokemon carrying it.
  -- Registered unconditionally like the key items and for the same reason --
  -- a crystal for a type this game's chart cannot resolve is still a bag byte
  -- a save has to be able to name.
  local zrows = m["data/zmoves.lua"]
  local crystalIndices = m["data/crystals.lua"]
  local zmoves = m["src/zmoves.lua"]

  -- The species-specific Z-Moves: a second catalog for that same crystal
  -- stamp, keyed on one species (or a small family of forms) rather than on
  -- a type -- so it goes through the PAIRED install below, the way
  -- Ultranecrozium Z does, and not the type crystals' unpaired one.
  local speciesZRows = m["data/speciesz.lua"]
  local speciesZCrystalIndices = m["data/speciescrystals.lua"]
  local speciesz = m["src/speciesz.lua"]

  -- The fourth family through that stamp, and the first whose form outlives the
  -- battle.  Bound before the stones are installed and handed to them, because
  -- a persistent form is DERIVED from the stamp: every write to that field has
  -- to re-derive, or moving an appliance off a Rotom would leave the form on it.
  local persistent = m["src/persistent.lua"]
  local persistentRows = m["data/persistent.lua"]
  local applianceIndices = m["data/appliances.lua"]
  -- Giratina, Palkia, Dialga, Zacian, Zamazenta and Shaymin's items -- a
  -- second indices table because they sell on a different shelf, merged with
  -- the appliances' below into the one table M.install actually needs: rows
  -- above is the WHOLE pairing table, every species at once, so whichever
  -- item any row names has to resolve to a byte somewhere in what install()
  -- is handed.
  local heldFormIndices = m["data/heldforms.lua"]
  -- Arceus's Plates and Silvally's Memories, the two biggest families here at
  -- 17 rows each and the only ones whose indices table answers `false`
  -- rather than a byte -- see data/plates.lua's header for why the shared
  -- byte space could not hold all 34.  Merged into the same persistentIndices
  -- table below exactly like the appliances and the other six: M.install
  -- does not need to know, and does not ask, which of its callers' several
  -- indices tables gave it a real byte and which gave it `false`.
  local plateIndices = m["data/plates.lua"]
  local memoryIndices = m["data/memories.lua"]
  -- Genesect's four Drives, the smallest family here and the only one whose
  -- indices table needed no byteless sentinel: 234-255 sat entirely unused
  -- ahead of it, so data/drives.lua gives all four a real byte the way the
  -- appliances and the other six held forms do.  Merged into the same
  -- persistentIndices table below alongside everything else.
  local driveIndices = m["data/drives.lua"]

  -- Fetched here, ahead of persistent's own bind just below, rather than
  -- beside the rest of the fifth family's setup where it used to sit: the
  -- fifth family (fusion, right below) is not ready to be bound yet -- its
  -- rows and indices are fetched after this point -- but persistent's own
  -- M.mark needs the MODULE TABLE in hand now, to ask it a question before
  -- falling back to clearing mon.form.  See src/persistent.lua's own comment
  -- on M.mark for why: no species was ever supposed to be both a fusion base
  -- and an appliance user, and Ultra Burst made Necrozma both.  The bind call
  -- that actually wires fusion's own deps stays below, with the rest of that
  -- family -- a module table is a valid thing to hold before it is bound,
  -- since nothing calls into it until gameplay starts, well after every bind
  -- in this file has run.
  local fusion = m["src/fusion.lua"]
  -- Gen 2 has no battler wrapper at all -- battle.player/battle.enemy ARE the
  -- mon (src/battlerof.lua's own header) -- so src/persistent.lua's M.apply
  -- cannot call src/forms.lua's becomeForm, which assumes one, on that game.
  -- generation/gen2/gen2forms are computed earlier now (see that block's own
  -- header, above megaset.problems) -- persistent needed nothing before this
  -- point that those depend on, so this bind is still the first place they
  -- are actually consumed.
  persistent.bind({ forms = m["src/forms.lua"], eligibility = eligibility,
                    rows = persistentRows, log = mod.log,
                    price = m["src/stone.lua"].PRICE, battlerof = battlerof,
                    fusion = fusion, gen2forms = gen2forms, gen2 = gen2 })
  -- Patches Battle.speciesDef so a Gen 2 form's types reach damage, AI and
  -- immunity checks (src/gen2forms.lua's own header). Installed only when
  -- this boot actually is Gen 2 -- requiring the module is harmless either
  -- way, but patching a class Gen 1 never runs through would be a wrap this
  -- boot can never exercise.
  if gen2 then gen2forms.install(mod) end

  -- The fifth family, and the only one that does not go through the held-item
  -- stamp at all: a fusion is recorded by which partner went in, and the
  -- partner itself is an ordinary Pokemon in the PC.  Bound beside the
  -- appliances because it derives its form the same way, and deliberately NOT
  -- handed to src/stone.lua below -- moving a stamp has nothing to re-derive
  -- here, and a fused Kyurem given a Z-Crystal must keep its partner.
  local fusionRows = m["data/fusion.lua"]
  local fuserIndices = m["data/fusers.lua"]
  -- gen2/gen2forms: the same pair src/persistent.lua's own M.apply branches
  -- on, and for the identical reason -- Gen 2 has no battler wrapper at all,
  -- so src/forms.lua's becomeForm would find no target and silently apply
  -- nothing to a genuinely fused Necrozma or Kyurem there.  This does NOT by
  -- itself make fusion reachable on Gold: the item that TRIGGERS a fusion
  -- cannot be used there at all (Game2:usePartyItem's own dispatch gap,
  -- confirmed for every mod's Gen 2 field item as of 0.39.0) -- what this
  -- wires is the mechanism a fused mon would need once it exists, the
  -- identical scope src/mega.lua's and src/persistent.lua's own Gen 2
  -- branches already established.
  fusion.bind({ forms = m["src/forms.lua"], rows = fusionRows, log = mod.log,
                price = m["src/stone.lua"].PRICE, battlerof = battlerof,
                gen2 = gen2, gen2forms = gen2forms })

  -- The sixth family, and the only one whose pairing table has a single row:
  -- Ultranecrozium Z fits Necrozma alone.  No option ever gates it, so `all`
  -- and `active` are the same table, the way primal reversion's are -- and it
  -- goes through the PAIRED install rather than the crystals' unpaired one,
  -- which is what refuses it on any species that is not Necrozma.
  local ultraRows = m["data/ultraburst.lua"]
  local ultraCrystalIndices = m["data/ultracrystal.lua"]

  -- Mega Rayquaza's real trigger: the effect that makes Dragon Ascent a real
  -- move, patched onto national_dex's own DRAGONASCENT record, and the one
  -- exemption that lets Rayquaza reach the MEGA cell without either of the
  -- two items every other mega still needs.  Installed unconditionally, the
  -- way every other effect and roster in this file is -- an id nothing
  -- points at is a harmless dead entry, never a reason to fail the load.
  -- `zcrystals` is built from the two indices tables above rather than
  -- data/megas.lua's own set, because a Z-Crystal is what the trigger
  -- refuses Rayquaza for and neither of those tables is a mega stone.
  local dragonascent = m["src/dragonascent.lua"]
  local zcrystals = dragonascent.crystalSet(crystalIndices, ultraCrystalIndices)
  dragonascent.install(mod)

  -- Tera Blast's own reachability fix, beside Dragon Ascent's for the same
  -- reason: both patch a national_dex move and its learners rather than
  -- registering anything of their own, and both exist because a feature
  -- shipped on a move nothing could actually know. TM171 teaches TERABLAST
  -- (data/tm171.lua's own bag byte) to every species that is not itself a
  -- form pseudo-record, and flags the move honestly modelled -- see
  -- src/terablasttm.lua's own header for why that flag can be true here
  -- when national_dex's own registration cannot claim it.
  local terablasttm = m["src/terablasttm.lua"]
  local tmIndices = m["data/tm171.lua"]
  terablasttm.install(mod, tmIndices)

  -- The eleven species Z-Crystals' own base moves, beside Tera Blast's fix
  -- for the same reason: every one of them shipped in 0.27.0 registered
  -- `effectModeled = false`, which national_dex's own MOVES=ALL widening
  -- permanently refuses, so nothing could ever be taught the move each
  -- crystal converts. Ten get a real effect and an honest flag; the
  -- eleventh (Spirit Shackle) is refused rather than faked -- see
  -- src/speciesbasemoves.lua's own header for why.
  m["src/speciesbasemoves.lua"].install(mod)

  -- gen2 decides whether M.items() takes the dead USE verb off a stone, an
  -- orb or Ultranecrozium Z -- see src/stone.lua's own header on M.items
  -- for why: Gold's own PACK dispatcher cannot reach any of these through
  -- USE regardless, so leaving the verb on screen would show a player an
  -- action that silently does nothing.
  m["src/stone.lua"].bind(eligibility, persistent, gen2)
  m["src/stone.lua"].install(mod, allMegas, megas, indices)
  m["src/stone.lua"].install(mod, primals, primals, orbIndices)
  m["src/stone.lua"].install(mod, ultraRows, ultraRows, ultraCrystalIndices)
  -- No option gates a species Z-Crystal either, so `all` and `active` are
  -- the same pairing table, the way Ultranecrozium Z's are.
  local speciesZPairings = speciesz.pairings(speciesZRows)
  m["src/stone.lua"].install(mod, speciesZPairings, speciesZPairings,
                              speciesZCrystalIndices)
  m["src/stone.lua"].installUnpaired(mod, zmoves.crystalIds(zrows),
                                     crystalIndices)
  -- Its own install rather than the stone one, for the single reason
  -- src/persistent.lua gives: a persistent form is the only kind here a player
  -- needs a way to take back off, because it is the only one that changes what
  -- the Pokemon is in the save.  One call registers every row in the pairing
  -- table, appliances and held-item forms alike, against the merged bytes --
  -- M.install itself does not know or care which shelf an item ends up on.
  local persistentIndices = {}
  for itemId, index in pairs(applianceIndices) do persistentIndices[itemId] = index end
  for itemId, index in pairs(heldFormIndices) do persistentIndices[itemId] = index end
  for itemId, index in pairs(plateIndices) do persistentIndices[itemId] = index end
  for itemId, index in pairs(memoryIndices) do persistentIndices[itemId] = index end
  for itemId, index in pairs(driveIndices) do persistentIndices[itemId] = index end
  persistent.install(mod, persistentRows, persistentIndices)
  -- Gold's own two mart shelves for the persistent-form family -- src/shop.lua's
  -- registry patch cannot reach either one (see src/gen2shop.lua's own header
  -- for why), so this wraps MartMenu.inventory instead. Indigo Plateau's table
  -- merges the same four held-form families the Gen 1 lobby counter sells
  -- (heldFormIndices, plateIndices, memoryIndices, driveIndices); Celadon 4F
  -- gets only the appliances, matching M.installAppliances' own Gen 1 shelf.
  -- Gen 1 only -- there is no MartMenu on that boot to patch.
  if gen2 then
    local indigoIndices = {}
    for itemId, index in pairs(heldFormIndices) do indigoIndices[itemId] = index end
    for itemId, index in pairs(plateIndices) do indigoIndices[itemId] = index end
    for itemId, index in pairs(memoryIndices) do indigoIndices[itemId] = index end
    for itemId, index in pairs(driveIndices) do indigoIndices[itemId] = index end
    -- The same counter also gains the Key Stone and this boot's own active
    -- mega stones (the MEGA EVOLUTIONS option's OFFICIAL/ALL set, the same
    -- one src/shop.lua's Gen 1 shelf stocks from -- megaset.stoneIds(megas)).
    -- Mega evolution needs both a trainer item and a Pokemon item, and
    -- neither had a route onto Gold before this pass: a menu cell with
    -- correct code behind it is not a reachable feature if nothing sells
    -- what it requires (HANDOFF's own standing worry about this mod's other
    -- mechanics).  The Tera Orb now joins it too, for the identical reason:
    -- Terastallization needs only the trainer's own item on Gold (no
    -- pairing table, no species gate), so selling it is what turns this
    -- pass's Gen 2 branch into a feature a player can actually reach rather
    -- than code nothing sells the key to.  The Dynamax Band and the Z-Ring
    -- stay off this shelf -- Dynamax needs a move-substitution primitive
    -- this pass does not build, and Ultra Burst (the one mechanic here that
    -- needs the Z-Ring) sits on top of fusion, whose own trigger item
    -- cannot be used on Gold at all (src/fusion.lua's own header) -- selling
    -- either would be a purchase that does nothing.
    indigoIndices[keyitems.KEY_STONE] = keyIndices[keyitems.KEY_STONE]
    indigoIndices[keyitems.TERA_ORB] = keyIndices[keyitems.TERA_ORB]
    for stoneId in pairs(megaset.stoneIds(megas)) do
      indigoIndices[stoneId] = indices[stoneId]
    end
    m["src/gen2shop.lua"].install(mod, applianceIndices, indigoIndices)
  end
  -- Its own install for a stronger version of the appliances' reason: this item
  -- does not stamp the Pokemon it is used on, it moves a second one into the PC.
  fusion.install(mod, fusionRows, fuserIndices)
  -- Before the stones, so the items that make that shelf worth anything are at
  -- the top of it rather than under ninety-odd stones -- key items first, then
  -- the crystals that the last of them needs to do anything, then the five
  -- appliances.
  m["src/shop.lua"].installKeyItems(mod, keyIndices)
  -- TM171, immediately behind the key items and ahead of the crystals: see
  -- src/shop.lua's own comment on M.installTM for why it sits here.
  m["src/shop.lua"].installTM(mod, tmIndices)
  m["src/shop.lua"].installCrystals(mod, crystalIndices)
  -- Ultranecrozium Z, immediately behind the eighteen type crystals: a deep
  -- registry concatenates patches in the order they arrive, and a player
  -- looking for a Z-Crystal should find all nineteen shelved together rather
  -- than hunting a nineteenth one down among the mega stones.
  m["src/shop.lua"].installCrystals(mod, ultraCrystalIndices)
  -- The fourteen species crystals, immediately behind Ultranecrozium Z: a
  -- deep registry concatenates patches in the order they arrive, so the
  -- Celadon shelf reads key items, the eighteen type crystals, Ultranecrozium
  -- Z, then these -- every Z-Crystal this mod sells in one run of the list.
  m["src/shop.lua"].installCrystals(mod, speciesZCrystalIndices)
  m["src/shop.lua"].installAppliances(mod, applianceIndices)
  m["src/shop.lua"].install(mod, indices, megaset.stoneIds(megas))
  m["src/shop.lua"].installOrbs(mod, orbIndices)
  -- Behind the orbs on the Indigo Plateau counter, which is this call's
  -- position rather than anything it does: a deep registry concatenates patches
  -- in the order they arrive.
  m["src/shop.lua"].installFusionItems(mod, fuserIndices)
  -- Behind the fusion items on that same counter, for the same reason as
  -- above -- call order is shelf order.
  m["src/shop.lua"].installHeldForms(mod, heldFormIndices)
  -- The Plates, then the Memories, behind the other six held forms on that
  -- same counter -- call order is shelf order, as everywhere else on this
  -- shelf.  Both tables are entirely `false` (data/plates.lua,
  -- data/memories.lua), so this is where shop.lua's byteless sort path
  -- actually runs rather than merely being reachable.
  m["src/shop.lua"].installPlates(mod, plateIndices)
  m["src/shop.lua"].installMemories(mod, memoryIndices)
  -- The Drives, last on that same counter -- call order is shelf order, as
  -- everywhere else on this shelf.  Unlike the Plates and Memories these carry
  -- real bytes (data/drives.lua), so this is an ordinary run through the
  -- numeric sort path, not the byteless one.
  m["src/shop.lua"].installDrives(mod, driveIndices)
  anim.install(mod)

  -- The battle message a form change prints.  Handed to the two
  -- transformations that announce and to nothing else, so the eight
  -- condition-driven forms cannot start narrating themselves by accident --
  -- see src/announce.lua for why they stay quiet.
  local announce = m["src/announce.lua"]

  -- The Max Move roster, registered before anything can use it and
  -- unconditionally, for the reason the key items are: a battle can hold a move
  -- id and a move id with no record behind it is a battle that cannot be drawn
  -- or saved.  What IS conditional is which types get one -- src/maxmoves.lua
  -- asks the merged chart, because a move naming a type this game has never
  -- heard of would fail the load rather than fail quietly.
  local maxmoves = m["src/maxmoves.lua"]
  local guardState = maxmoves.newGuard()
  maxmoves.bind({ anim = anim, announce = announce, log = mod.log,
                  guard = guardState, substitute = m["src/substitute.lua"] })
  local maxCatalog = maxmoves.install(mod, m["data/maxmoves.lua"])

  -- G-Max Moves: a second, species-aware catalog on the same substitution --
  -- names, types and powers only, no effect of any kind (src/gmaxmoves.lua's
  -- own header says why in full). Installed unconditionally and gated on the
  -- merged type chart exactly like the type roster above, for the identical
  -- reason: a battle can hold a move id and a move id with no record behind
  -- it is a battle that cannot be drawn or saved. The power ladder is not
  -- this file's own -- src/gmaxmoves.lua reads src/maxmoves.lua's live rather
  -- than a second copy of the same seven numbers.
  local gmaxmoves = m["src/gmaxmoves.lua"]
  gmaxmoves.bind({ anim = anim, log = mod.log,
                   substitute = m["src/substitute.lua"], maxmoves = maxmoves })
  local gmaxCatalog = gmaxmoves.install(mod, m["data/gmaxmoves.lua"],
                                        m["data/maxmoves.lua"])

  -- One cell on the command menu hosts every manually activated
  -- transformation there is, because the blank spacer row it draws into is the
  -- only space either battle layout has spare.  Mega evolution is the first
  -- entry rather than a special case: what makes it the only one today is that
  -- it is the only one registered.
  local registry = m["src/transforms.lua"].new()
  -- The arm state reaches the registry for one job: a mechanic that substitutes
  -- moves does it when the player arms the cell rather than when it activates,
  -- and the armed flag is the only place that knows about every way of arming
  -- and every way of disarming.  Bound here rather than at construction because
  -- the state is built before there is a registry to hand it.
  m["src/arm.lua"].bind({ registry = registry })
  -- gen2/gen2forms: the same two values src/persistent.lua's own M.apply
  -- branches on, handed to mega evolution because it is the one manual
  -- transformation this pass wires for Gold -- src/mega.lua's own header on
  -- what the flag changes and what it deliberately still does not (Mega
  -- Rayquaza's own trigger, the announce/animation pair).
  local registered, why = registry:register(m["src/mega.lua"].entry({
    forms = m["src/forms.lua"], eligibility = eligibility, megas = megas,
    keyitems = keyitems, animId = anim.ID, announce = announce,
    log = mod.log, dragonascent = dragonascent, zcrystals = zcrystals,
    battlerof = battlerof, gen2 = gen2, gen2forms = gen2forms }))
  if not registered then
    mod.log:error("battle_forms: mega evolution was refused a place on the "
      .. "battle menu (%s) -- no stone can be armed until that is fixed",
      tostring(why))
  end

  -- The second entry on that cell, and the one that proves it is a cell rather
  -- than a mega with decoration: registered through the same registry and
  -- cycled to with LEFT/RIGHT.  Being registered is also what puts it under the
  -- trainer's one manual transformation per battle, so a player picks this or
  -- the mega and not both.  Dynamax is still handed the forms primitive and its
  -- own pairing table and nothing else, so like primal reversion it has no way
  -- to reach the mega's eligibility.
  --
  -- It is also the only entry handed the move-substitution mechanism, and it is
  -- handed the mechanism rather than the Max Moves: `maxMoves` answers with the
  -- per-slot decision for one battle's merged data, so Dynamax never learns
  -- what a Max Move is and a second consumer -- a Z-Move -- arrives as another
  -- picker rather than as a change here.
  --
  -- `gmaxMoves` is a second, species-aware picker-factory beside `maxMoves`
  -- rather than a change to it -- src/dynamax.lua's own `arm` step asks it
  -- first, on every slot, and `maxMoves` only where it says nothing, the
  -- identical composition src/zmoves.lua already keeps between its type and
  -- species Z-Move catalogs (its own `pickerAny`). Composing the two here
  -- instead would put load-bearing logic in main.lua where nothing can unit
  -- test it; src/dynamax.lua owns the order, and tests/battle_forms_
  -- dynamax_test.lua and tests/battle_forms_gmaxmoves_test.lua both drive it
  -- directly.
  local dynamax = m["src/dynamax.lua"]
  dynamax.bind({ forms = m["src/forms.lua"],
                 gigantamax = m["data/gigantamax.lua"], keyitems = keyitems,
                 announce = announce, log = mod.log,
                 substitute = m["src/substitute.lua"],
                 battlerof = battlerof,
                 maxMoves = function(data)
                   return maxmoves.picker(maxCatalog, data)
                 end,
                 gmaxMoves = function(data, mon)
                   return gmaxmoves.picker(gmaxCatalog, data, mon)
                 end })
  local dynamaxState = dynamax.new()
  local dynaOk, dynaWhy = registry:register(dynamax.entry(dynamaxState))
  if not dynaOk then
    mod.log:error("battle_forms: Dynamax was refused a place on the battle "
      .. "menu (%s) -- the cell falls back to mega evolution alone",
      tostring(dynaWhy))
  end
  -- The HP multiplier Dynamax cannot write: halves incoming damage against
  -- dynamaxState.mon instead, through battle.damage, and repaints the
  -- player's own HP readout to match through battle.overlay.  Installed
  -- unconditionally rather than only when dynaOk, because the registry
  -- refusal above only withholds the menu CELL -- an adopted mid-battle
  -- Dynamax or a future caller of dynamaxState directly would otherwise find
  -- the multiplier missing for a reason that has nothing to do with it.
  m["src/hpscale.lua"].install(mod, dynamaxState)

  -- The third entry, and the first that is not a form change at all: it
  -- overrides the battler's types and marks nothing, so it is handed neither
  -- the forms primitive nor a pairing table.  The chosen type is passed as a
  -- reader rather than a value for the reason the diagnostic's switch is:
  -- changing an option in the manager does not reload the mod, so a value
  -- captured here would only take effect on the next boot.
  -- gen2 changes what the type override writes (mon.formTypes directly,
  -- the field src/gen2forms.lua's speciesDef wrap reads -- Gold's engine
  -- object has no battler.curTypes to assign) and drops the TERA BLAST
  -- substitution entirely: Gen 2 has no curMoves array to swap the way
  -- src/substitute.lua does, the identical reason Dynamax's Max Moves and
  -- Z-Moves stay Red/Blue/Yellow only.  A Terastallization on Gold changes
  -- type and nothing else -- a Pokemon that already knows TERA BLAST keeps
  -- it as a plain Normal-type attack even after terastallizing.
  local tera = m["src/tera.lua"]
  tera.bind({ keyitems = keyitems, announce = announce, log = mod.log,
              substitute = m["src/substitute.lua"], anim = anim,
              battlerof = battlerof, gen2 = gen2,
              chosen = function() return mod.options:get("tera_type") end })
  -- TERA BLAST's own roster: one record per type the running game's chart
  -- can resolve, registered unconditionally like the Max Moves and the
  -- Z-Moves, because a battle can hold a move id and a move id with no
  -- record behind it is a battle that cannot be drawn or saved.
  local teraBlastCatalog = tera.install(mod, m["data/terablast.lua"])
  local teraState = tera.new()
  local teraOk, teraWhy = registry:register(tera.entry(teraState, teraBlastCatalog))
  if not teraOk then
    mod.log:error("battle_forms: Terastallization was refused a place on the "
      .. "battle menu (%s) -- the cell keeps the transformations that did "
      .. "register", tostring(teraWhy))
  end

  -- The fourth entry, and the second consumer of the move-substitution
  -- mechanism -- which is why main.lua did not have to change to accommodate
  -- it beyond these lines: Dynamax was handed the mechanism rather than the Max
  -- Moves, and this arrives as another picker rather than as a change there.
  -- Registered after the roster it substitutes in, and bound to the same
  -- eligibility stamp the mega stones use, because a Pokemon holds one item.
  -- speciesz is bound to the substitute mechanism and its own log line, and
  -- to nothing else -- it never checks the Z-Ring, the trainer's spent flag
  -- or the eligibility stamp itself, all of which src/zmoves.lua's entry
  -- already owns for the type catalog and now asks of this one too.
  speciesz.bind({ substitute = m["src/substitute.lua"], anim = anim,
                   log = mod.log })
  local speciesZCatalog = speciesz.install(mod, speciesZRows)

  zmoves.bind({ substitute = m["src/substitute.lua"], keyitems = keyitems,
                eligibility = eligibility, announce = announce, anim = anim,
                speciesz = speciesz, log = mod.log, battlerof = battlerof })
  local zCatalog = zmoves.install(mod, zrows)
  local zState = zmoves.new()
  local zOk, zWhy = registry:register(
    zmoves.entry(zState, zCatalog, speciesZCatalog))
  if not zOk then
    mod.log:error("battle_forms: Z-Moves were refused a place on the battle "
      .. "menu (%s) -- the cell keeps the transformations that did register",
      tostring(zWhy))
  end

  -- The fifth entry, and the only one gated on three things standing together:
  -- the Z-Ring, Ultranecrozium Z on the mon, and a fusion src/fusion.lua
  -- already made true of it.  Handed that module rather than a pairing table
  -- of its own for the third gate, because "already fused" is a question only
  -- src/fusion.lua's own stamp can answer.
  -- gen2/gen2forms follow fusion's own reasoning exactly, since Ultra Burst
  -- sits on top of it: mon.item (not the Gen 1 bag stamp) decides whether
  -- the crystal is held, on the identical grounds src/mega.lua's Gen 2
  -- branch already reads a mega stone, and gen2forms.becomeForm is the
  -- primitive that actually reaches mon.stats there.  Reachable on Gold only
  -- to the extent fusion itself is -- see src/fusion.lua's own header on
  -- that, cited again at src/ultraburst.lua's own Gen 2 branch.
  local ultraburst = m["src/ultraburst.lua"]
  ultraburst.bind({ forms = m["src/forms.lua"], eligibility = eligibility,
                     fusion = fusion, keyitems = keyitems, rows = ultraRows,
                     animId = anim.ID, announce = announce, log = mod.log,
                     battlerof = battlerof, gen2 = gen2, gen2forms = gen2forms })
  local ultraburstState = ultraburst.new()
  local ultraOk, ultraWhy = registry:register(ultraburst.entry(ultraburstState))
  if not ultraOk then
    mod.log:error("battle_forms: Ultra Burst was refused a place on the "
      .. "battle menu (%s) -- the cell keeps the transformations that did "
      .. "register", tostring(ultraWhy))
  end

  diag.registry(registry, registered, why)

  -- The party sweep and the faint handler are handed the persistent module for
  -- one question: which of the mons they are about to clear are entitled to keep
  -- a form.  Nothing else in resolve.lua changes -- see its own comment on why
  -- asking rather than exempting is what keeps a battle form out of the save.
  -- gen2/gen2forms pick the party-sweep and faint-revert primitive: Gold's
  -- engine Battle object carries `.party`/`.enemyParty` directly and no
  -- `.game` at all, so `battle.game and battle.game.save` -- what this read
  -- before -- was always nil there and the sweep walked zero mons on every
  -- Gen 2 battle; see src/resolve.lua's own header on M.onBattleEnded and
  -- M.onFainted for the full reasoning, including why M.onBattlerSwitched
  -- now refuses outright on Gen 2 instead of running Gen 1's reapply logic.
  --
  -- primals/conditionalRows/persistentRows/fusionRows/ultraRows/
  -- gigantamaxRows are every OTHER pairing table this mod owns, all handed
  -- in so src/resolve.lua's own ownsForm can tell a leftover form this mod
  -- set apart from a marker a SIBLING mod set through the identical
  -- mon.form field -- wild_forms marks caught regional and Minior forms
  -- that way, and they are meant to outlive the battle exactly as a
  -- persistent held-item form here does. Without these the party sweep and
  -- the faint handler could no longer tell the two apart from either
  -- direction: not only would a wild_forms marker have kept getting
  -- deleted, this mod's OWN leftover markers (a benched mega, primal
  -- reversion, a condition-driven form, a Gigantamax) would have stopped
  -- clearing at all, since ownsForm would recognise nothing without them.
  local resolve = m["src/resolve.lua"]
  resolve.bind({ registry = registry, forms = m["src/forms.lua"],
                 eligibility = eligibility, megas = megas, log = mod.log,
                 persistent = persistent, fusion = fusion,
                 dragonascent = dragonascent, zcrystals = zcrystals,
                 battlerof = battlerof, gen2 = gen2, gen2forms = gen2forms,
                 primals = primals, conditionalRows = m["data/conditional.lua"],
                 persistentRows = persistentRows, fusionRows = fusionRows,
                 ultraRows = ultraRows, gigantamaxRows = m["data/gigantamax.lua"] })

  -- Primal reversion is wired beside the mega path, never into it: it is
  -- handed the forms primitive and its own pairing table and nothing else,
  -- so it has no way to reach the armed flag or the once-per-battle limit.
  -- gen2/gen2forms: the real held item (mon.item) rather than the Gen 1 bag
  -- stamp, the identical substitution src/mega.lua's own Gen 2 branch
  -- already makes -- see src/primal.lua's own header on why this was the
  -- whole of a real bug report (a Groudon genuinely holding the Red Orb on
  -- Gold, given through the party ITEM row's real GIVE, was never primal at
  -- all, because eligibility.STAMP is a field GIVE never touches).
  local primal = m["src/primal.lua"]
  primal.bind({ forms = m["src/forms.lua"], eligibility = eligibility,
                primals = primals, log = mod.log, diag = diag,
                announce = announce, battlerof = battlerof,
                gen2 = gen2, gen2forms = gen2forms })

  -- Condition-driven forms are wired the same way and for the same reason:
  -- the forms primitive, their own pairing table, and nothing else.  They
  -- carry no item, so they are not handed eligibility either -- there is no
  -- stamp for them to read.
  -- gen2/gen2forms pick the primitive only -- these carry no item and no
  -- gate, so there was never an eligibility read to substitute the way
  -- mega's and primal's own Gen 2 branches needed; deps.forms.becomeForm's
  -- battler.mon wrapper simply does not exist on Gold, and that alone was
  -- the whole of the Aegislash report.
  -- diag is handed in the same way src/primal.lua's own bind already gets
  -- it -- this module shipped a full release with no diagnostic at all,
  -- which is exactly what left a later report of this same shape (Aegislash
  -- not changing stance) guesswork instead of a one-line answer.
  local conditional = m["src/conditional.lua"]
  conditional.bind({ forms = m["src/forms.lua"],
                     rows = m["data/conditional.lua"], log = mod.log, diag = diag,
                     battlerof = battlerof, gen2 = gen2, gen2forms = gen2forms })

  -- Decision only: overlay says which registered transformations are on offer
  -- and what the cell should call the one it is showing, and the menu cell is
  -- the one thing that draws it.  It owned a START handler and a corner
  -- indicator until 0.2.1; both are gone because the menu cell says the same
  -- thing in the place the player is already looking.
  local overlay = m["src/overlay.lua"]
  overlay.bind({ registry = registry })

  -- The submenu the cell opens: shaped like the FIGHT menu's own move list,
  -- one row per transformation overlay.offered names right now.  Reads the
  -- same offered/label decision overlay.lua already makes rather than
  -- inventing a second one, so the list and the cell it opens from can never
  -- disagree about what is on offer.
  local formmenu = m["src/formmenu.lua"]
  formmenu.bind({ overlay = overlay })

  -- Bound after everything it reads and before anything that reports through
  -- it.  The option is read live rather than captured: changing it in the
  -- manager does not reload the mod (ManagerState:setOption writes
  -- loader.modOptions in place), so a captured value would mean the switch
  -- only ever took effect on the next boot.
  -- dragonascent and zcrystals are the same two values src/mega.lua's own
  -- exemption reads, handed here too so the trace reports the MEGA cell's
  -- real decision for Rayquaza rather than only its stone-based half -- see
  -- src/diag.lua's own header on `trigger()` for why the stone-only version
  -- of this report used to look exactly like a failure for a working mega.
  diag.bind({ mod = mod, registry = registry, overlay = overlay, state = state,
              eligibility = eligibility, megas = megas, keyitems = keyitems,
              dragonascent = dragonascent, zcrystals = zcrystals,
              battlerof = battlerof,
              enabled = function()
                return mod.options:get("debug_trace") == "on"
              end })

  -- Enabling the mod from the manager during a battle means battle.started has
  -- already been and gone, so the arm state below would never learn which
  -- battle it is in and nothing manual would work for the rest of the fight.
  -- Adoption is handed the two send-out handlers rather than the events,
  -- because what it recovers is exactly what a send-out would have applied.
  local adopt = m["src/adopt.lua"]
  adopt.bind({ state = state, primal = primal, conditional = conditional,
               persistent = persistent, fusion = fusion, diag = diag })

  -- The menu cell owns input/draw seams overlay.lua has no hook for
  -- (BattleState.update, BattleState.drawTextArea, WideBattle.draw), which
  -- is why it is a separate module even though it reads the same shouldOffer
  -- decision.  Its update wrapper is also the only place the live battle
  -- reaches this mod without an event, which is why adoption rides it.
  local menu = m["src/menu.lua"]
  menu.bind({ overlay = overlay, formmenu = formmenu, diag = diag, adopt = adopt })
  menu.install(mod, state)

  -- Gold's own battle screen -- a different class from Gen 1's, with its own
  -- geometry and its own fixed 2x2 input grid (src/gen2menu.lua's own header
  -- has the file:line evidence) -- so it is a separate module rather than a
  -- branch inside src/menu.lua, the same reason src/gen2formview.lua is
  -- separate from src/formview.lua.  It reuses src/formmenu.lua's list
  -- unchanged: that module already reads whichever battle it is handed as
  -- `battle`, so no Gen 2 fork of it exists.  Not handed `adopt` -- a mod
  -- enabled mid-battle on Gold loses the cell for that battle only, the same
  -- degraded-not-broken behaviour Gen 1 had before adoption existed; see
  -- src/gen2menu.lua's own header for why wiring it would touch modules
  -- (src/primal.lua, src/conditional.lua) that assume Gen 1's battler shape
  -- and are themselves out of this pass's scope.  Gen 1 only -- there is no
  -- src/ui/gen2/BattleState.lua on that boot to patch.
  if gen2 then
    local gen2menu = m["src/gen2menu.lua"]
    gen2menu.bind({ overlay = overlay, formmenu = formmenu, diag = diag })
    gen2menu.install(mod, state)
  end

  -- The boxed fusion partner's marker: two more engine wraps in the same
  -- style, reaching the PC box lists and the STATS screen reached from them
  -- rather than the battle menu the two above own.  Bound beside them for
  -- the same reason -- diag is what any of these wraps has to report through.
  local boxmark = m["src/boxmark.lua"]
  boxmark.bind({ fusion = fusion, diag = diag })
  boxmark.install(mod)

  -- The same STATS screen, a third reason to reach it: a persistent form or
  -- a fusion changes a Pokemon's types and stats on the battler
  -- (src/forms.lua's becomeForm), and this draws the identical numbers over
  -- the base species' own wherever the STATS screen shows them, so the
  -- party menu and the box screens stop reading a Fire-typed Arceus as
  -- NORMAL.  Bound with both pairing modules for the same reason
  -- src/resolve.lua's own party sweep needs both: nothing else can still be
  -- standing on mon.form once a battle is over.
  local formview = m["src/formview.lua"]
  formview.bind({ fusion = fusion, persistent = persistent, diag = diag })
  formview.install(mod)

  -- Gold's own SUMMARY screen, a separate class with a separate stats layout
  -- (specialAttack/specialDefense as two rows where Gen 1 has one `special`)
  -- -- see src/gen2formview.lua's own header for why an overlay recomputed
  -- fresh from data.pokemon[formId] is what a Gen 2 form needs here, rather
  -- than trusting mon.stats to still hold what src/gen2forms.lua last wrote.
  -- Installed only on a Gen 2 boot, for the reason src/gen2forms.lua's own
  -- install call is: patching a class Gen 1 never draws through would be a
  -- wrap this boot can never exercise.
  local gen2formview = m["src/gen2formview.lua"]
  gen2formview.bind({ fusion = fusion, persistent = persistent, diag = diag })
  if gen2 then gen2formview.install(mod) end

  -- The Z-Move roster's own FIGHT-menu names, drawn in place of whatever
  -- data/zmoves.lua's `name` field spells -- display-time only, so the
  -- registered record (and everything that reads it: the battle text row,
  -- Mimic, a save) still sees the move's real name.  Bound after zmoves.lua's
  -- own install because the id -> short name map is built from the same
  -- roster that call just registered.  Merged with data/speciesz.lua's own
  -- names, which need the identical redraw for the identical reason -- most
  -- of the fourteen real names are as long as the eighteen type Z-Moves'.
  --
  -- data/gmaxmoves.lua's own `menu` names join the same map for the same
  -- reason again: every G-Max Move's real name is at least as long as
  -- "G-MAX WILDFIRE" (fourteen columns), which overflows both layouts the
  -- identical way a Z-Move's real name does. zmovemenu.install can only be
  -- called once -- it sets a guard flag and refuses a second wrap -- so this
  -- is the one map every display name this mod ships has to reach it through.
  local zmovemenu = m["src/zmovemenu.lua"]
  zmovemenu.bind({ diag = diag })
  local zMenuNames = zmoves.menuNames(zrows)
  for id, short in pairs(speciesz.menuNames(speciesZRows)) do
    zMenuNames[id] = short
  end
  for id, short in pairs(gmaxmoves.menuNames(m["data/gmaxmoves.lua"],
                                              m["data/maxmoves.lua"])) do
    zMenuNames[id] = short
  end
  zmovemenu.install(mod, zMenuNames)

  -- Events:emit pcalls the LISTENER, not the calls inside it, so three
  -- handlers sharing one listener meant the first to throw silently cancelled
  -- the two behind it -- and the engine's report for that is a print() the
  -- packaged launcher discards, so the symptom was a mechanic that just
  -- stopped happening.  Each call is guarded on its own now, and says what it
  -- caught.
  --
  -- Guarded rather than split into a listener each, which would isolate them
  -- just as well: Events:on table.sorts the list by priority on every
  -- subscribe and Lua's sort is not stable, so listeners sharing a priority
  -- have no guaranteed order between them where calls in one listener do.
  local function run(what, fn)
    local ok, err = pcall(fn)
    if not ok then diag.fault(what, err) end
  end

  mod.events:on("battle.started", function(ev)
    diag.reached("battle.started", ev)
    run("arm.onBattleStarted", function() state:onBattleStarted(ev) end)
    -- Ahead of the other two send-out handlers, because a persistent form is
    -- the BASELINE the rest are laid over: it is true of the Pokemon before the
    -- battle started and will be after it ends, so it should be standing before
    -- anything asks what the mon is already wearing.  Nothing BREAKS in the
    -- other order -- the handler applies and reconciles nothing, precisely so
    -- that its correctness does not rest on its position -- but a conditional
    -- row refuses a mon already wearing something else, and this is the order in
    -- which that refusal means what it says.
    -- Ahead of the persistent handler for the reason that one leads the rest: a
    -- fusion is the most baseline thing a Pokemon here can be wearing -- it was
    -- true before the battle, will be true after it, and there is a second
    -- Pokemon in the PC behind it.  Nothing breaks in the other order, since no
    -- species is both a fusion base and an appliance user.
    run("fusion.onBattleStarted", function() fusion.onBattleStarted(ev) end)
    run("persistent.onBattleStarted", function() persistent.onBattleStarted(ev) end)
    run("primal.onBattleStarted", function() primal.onBattleStarted(ev) end)
    run("conditional.onBattleStarted", function() conditional.onBattleStarted(ev) end)
    run("dynamax.onBattleStarted", function() dynamax.onBattleStarted(dynamaxState) end)
    run("tera.onBattleStarted", function() tera.onBattleStarted(teraState) end)
    run("maxmoves.onBattleStarted", function() maxmoves.onBattleStarted(guardState) end)
    run("zmoves.onBattleStarted", function() zmoves.onBattleStarted(zState) end)
    -- Ultra Burst never auto-transforms on a send-out -- it is manual, like
    -- mega evolution -- so this only drops a stale mon reference a previous
    -- battle (or an adoption) might have left behind.
    run("ultraburst.onBattleStarted", function() ultraburst.onBattleStarted(ultraburstState) end)
  end)
  mod.events:on("battle.turn_started", function(ev)
    diag.reached("battle.turn_started", ev)
    run("resolve.onTurnStarted", function() resolve.onTurnStarted(state, ev) end)
  end)
  mod.events:on("battle.battler_switched", function(ev)
    diag.reached("battle.battler_switched", ev)
    run("resolve.onBattlerSwitched", function() resolve.onBattlerSwitched(ev) end)
    -- Ahead of the other two for the reason it leads at battle.started, and
    -- here for one more of its own: makeBattler is form-blind, so a mon whose
    -- form is simply true of it needs the stat and type override put back on
    -- every arrival, and it should be back before a conditional row asks what
    -- the mon is wearing.
    run("fusion.onBattlerSwitched", function() fusion.onBattlerSwitched(ev) end)
    run("persistent.onBattlerSwitched", function() persistent.onBattlerSwitched(ev) end)
    run("primal.onBattlerSwitched", function() primal.onBattlerSwitched(ev) end)
    run("conditional.onBattlerSwitched", function() conditional.onBattlerSwitched(ev) end)
    -- After resolve's switch-in reapply, and it has to stay after it: this
    -- reads ev.previous (the mon LEAVING) where resolve reads ev.battler (the
    -- one arriving), so the two never touch the same mon -- but a Dynamax
    -- ending has to clear mon.form before any later handler asks what form the
    -- mon is wearing.
    run("dynamax.onBattlerSwitched", function() dynamax.onBattlerSwitched(dynamaxState, ev) end)
    -- Beside Dynamax's rather than beside resolve's mega path above: Necrozma
    -- is never in data/megas.lua, so resolve's own switch-in reapply has
    -- nothing to say about it and this mechanic has to reapply Ultra Necrozma's
    -- curStats/curTypes itself, tracked by the mon that actually burst rather
    -- than re-derived -- the crystal and the fusion cannot move mid-battle, so
    -- the mon leaving the field is the only thing that could have changed.
    -- Ahead of Terastallization for the reason the comment below gives: that
    -- one is the outermost state there is and has to win if both ever stood on
    -- the same mon, though the shared once-per-battle lock means they never do.
    run("ultraburst.onBattlerSwitched", function() ultraburst.onBattlerSwitched(ultraburstState, ev) end)
    -- Last of the switch handlers, and it has to stay last: a Terastallization
    -- outlives a switch where every other manual transformation here either
    -- ends on one or is reapplied by resolve above, and it is the outermost of
    -- them -- a mon that megaed and then terastallized is the type it chose,
    -- not the type its mega form is.
    -- Beside Dynamax's and reading the same end of the event -- the mon that
    -- LEFT -- because a Z-Move armed on one Pokemon does not follow another one
    -- in.  Before the Terastallization below only because that one is the
    -- outermost state there is and stays last.
    run("zmoves.onBattlerSwitched", function() zmoves.onBattlerSwitched(zState, ev) end)
    run("tera.onBattlerSwitched", function() tera.onBattlerSwitched(teraState, ev) end)
  end)
  -- Subscribing is also what makes these three fire at all: the engine builds
  -- their payloads behind a Runtime.wants check on the exact event name, so an
  -- unsubscribed battle.damage_dealt is never constructed in the first place.
  mod.events:on("battle.move_used", function(ev)
    diag.reached("battle.move_used", ev)
    run("conditional.onMoveUsed", function() conditional.onMoveUsed(ev) end)
    -- The only handler in this mod that reads which move was actually run.  It
    -- marks rather than acts: the move's effect and damage are still ahead of
    -- this event, and the substituted array has to stand until they are done.
    run("zmoves.onMoveUsed", function() zmoves.onMoveUsed(zState, ev) end)
  end)
  mod.events:on("battle.damage_dealt", function(ev)
    diag.reached("battle.damage_dealt", ev)
    run("conditional.onDamageDealt", function() conditional.onDamageDealt(ev) end)
  end)
  mod.events:on("battle.turn_ended", function(ev)
    diag.reached("battle.turn_ended", ev)
    run("conditional.onTurnEnded", function() conditional.onTurnEnded(ev) end)
    run("dynamax.onTurnEnded", function() dynamax.onTurnEnded(dynamaxState, ev) end)
    -- Max Guard's shield lasts the turn it went up.  Guarded on its own like
    -- everything beside it, which is what stops a throw above from leaving a
    -- Pokemon semi-invulnerable for the rest of the battle.
    run("maxmoves.onTurnEnded", function() maxmoves.onTurnEnded(guardState) end)
    -- A Z-Move lasts the turn it was used on, which is the whole of "one move,
    -- once" -- and does nothing at all on a turn it was not used, where a
    -- Dynamax's clock would have ticked.
    run("zmoves.onTurnEnded", function() zmoves.onTurnEnded(zState) end)
  end)
  mod.events:on("battle.fainted", function(ev)
    diag.reached("battle.fainted", ev)
    run("resolve.onFainted", function() resolve.onFainted(ev) end)
    run("dynamax.onFainted", function() dynamax.onFainted(dynamaxState, ev) end)
    run("tera.onFainted", function() tera.onFainted(teraState, ev) end)
    run("zmoves.onFainted", function() zmoves.onFainted(zState, ev) end)
    -- After resolve's own faint handler, which has already reverted mon.form
    -- (and, since the mon is still fused, put its Dusk Mane or Dawn Wings
    -- suffix straight back through src/fusion.lua's settle) -- this only drops
    -- the reference tracking that the mon was mid-Ultra-Burst.
    run("ultraburst.onFainted", function() ultraburst.onFainted(ultraburstState, ev) end)
  end)
  mod.events:on("battle.ended", function(ev)
    diag.reached("battle.ended", ev)
    run("resolve.onBattleEnded", function() resolve.onBattleEnded(ev) end)
    run("arm.onBattleEnded", function() state:onBattleEnded(ev) end)
    -- Beside the arm state's own reset and after the party sweep above, for
    -- the same two reasons: the sweep has already taken every form off, and
    -- what is left to drop is the mon reference, which must not outlive the
    -- battle that owned it.
    run("dynamax.onBattleEnded", function() dynamax.onBattleEnded(dynamaxState) end)
    -- Beside it, and for one reason of its own: this one has a battler to put
    -- back rather than a mon to strip, so it is given the event and not just
    -- the state.
    run("tera.onBattleEnded", function() tera.onBattleEnded(teraState, ev) end)
    run("maxmoves.onBattleEnded", function() maxmoves.onBattleEnded(guardState) end)
    -- Beside them, and for the reason Dynamax's is here: nothing swept the
    -- substituted array, and the battler it is holding must not outlive the
    -- battle that built it.
    run("zmoves.onBattleEnded", function() zmoves.onBattleEnded(zState) end)
    -- Beside them, for the reason Dynamax's is here: resolve's own party sweep
    -- above already reverted every mon.form (a still-fused Necrozma landing
    -- back on its Dusk Mane or Dawn Wings suffix), so this only drops the mon
    -- reference, which must not outlive the battle that owned it.
    run("ultraburst.onBattleEnded", function() ultraburst.onBattleEnded(ultraburstState) end)
    -- After the party sweep above, and it must stay after it: this marks the
    -- battle closed so no later frame can adopt it and re-apply a form to a
    -- mon resolve.onBattleEnded has just reverted.
    run("adopt.onBattleEnded", function() adopt.onBattleEnded(ev) end)
    -- Last, so the flush it performs carries everything the handlers above
    -- had to say about the battle that just ended.
    run("diag.onBattleEnded", function() diag.onBattleEnded(ev) end)
  end)
end
