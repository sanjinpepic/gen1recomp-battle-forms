-- Mega Rayquaza's real trigger: knowing Dragon Ascent rather than holding a
-- stone.  Three things this suite has to prove and none of them for free.
--
-- First, the effect itself: a 120-power hit that lowers the USER's own
-- Defense and Special Defense, landing on the user and not the target, which
-- is the one thing easy to get backwards when a move's own effect reaches
-- for `ctx.user` beside `ctx.target`.
--
-- Second, the trigger: no Key Stone and no mega stone for Rayquaza alone, a
-- refusal for a held Z-Crystal, and -- the sharpest edge -- every OTHER mega
-- still asking both tiers exactly as before. A gate that widened for one
-- species and quietly widened for all of them would be worse than no gate.
--
-- Third, that patching an existing national_dex record from a second mod
-- actually works the way game/src/mods/Registry.lua says it does: `patch`
-- deep-merges onto whatever `register` already put there, and the `__append`
-- wrapper extends a list rather than replacing it -- proven through the real
-- loader, not asserted against a stub that could silently drift from what
-- the engine does.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local DragonAscent = dofile(MOD .. "/src/dragonascent.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)
local crystalIndices = dofile(MOD .. "/data/crystals.lua")
local ultraCrystalIndices = dofile(MOD .. "/data/ultracrystal.lua")

-- ---------------------------------------------------------------------
-- M.knows: read off the Pokemon's own moveset, never the battler's.
-- ---------------------------------------------------------------------
T.eq(DragonAscent.knows({ moves = { { id = "REST" }, { id = "DRAGONASCENT" } } }),
  true, "a moveset carrying the id knows it")
T.eq(DragonAscent.knows({ moves = { { id = "REST" }, { id = "FLY" } } }), false,
  "a moveset without it does not")
T.eq(DragonAscent.knows({ moves = {} }), false, "an empty moveset knows nothing")
T.eq(DragonAscent.knows({}), false, "no moves array at all knows nothing")
T.eq(DragonAscent.knows(nil), false, "no mon at all knows nothing")

-- ---------------------------------------------------------------------
-- M.crystalSet: the eighteen type crystals plus Ultranecrozium Z, and
-- nothing this mod invented for a different family.
-- ---------------------------------------------------------------------
local crystals = DragonAscent.crystalSet(crystalIndices, ultraCrystalIndices)
local count = 0
for _ in pairs(crystals) do count = count + 1 end
T.eq(count, 19, "eighteen type crystals plus Ultranecrozium Z, nineteen ids")
T.eq(crystals.FIRIUM_Z, true, "a type crystal is in the set")
T.eq(crystals.ULTRANECROZIUM_Z, true, "and so is Ultranecrozium Z")
T.eq(crystals.RAYQUAZITE, nil, "a mega stone is not a Z-Crystal")
T.eq(crystals.RED_ORB, nil, "neither is a primal orb")

-- ---------------------------------------------------------------------
-- M.formFor: the trigger's own decision, species by species and item by
-- item -- deliberately exercised standalone before it is wired into the
-- MEGA cell below, so a failure here points straight at the decision and
-- not at the menu plumbing around it.
-- ---------------------------------------------------------------------
local function mon(species, moves, held)
  return { species = species, moves = moves or {}, [E.STAMP] = held }
end

T.eq(DragonAscent.formFor(E, crystals,
  mon("RAYQUAZA", { { id = "DRAGONASCENT" } })), "RAYQUAZA_MEGA",
  "a Rayquaza that knows Dragon Ascent and holds nothing gets the mega form")

T.eq(DragonAscent.formFor(E, crystals,
  mon("RAYQUAZA", { { id = "REST" } })), nil,
  "a Rayquaza that has not learned the move gets nothing")

T.eq(DragonAscent.formFor(E, crystals,
  mon("CHARIZARD", { { id = "DRAGONASCENT" } })), nil,
  "knowing the move means nothing for a species that is not Rayquaza")

T.eq(DragonAscent.formFor(E, crystals,
  mon("RAYQUAZA", { { id = "DRAGONASCENT" } }, "FIRIUM_Z")), nil,
  "a Rayquaza holding a type Z-Crystal is refused, per the Gen 7 rule")

T.eq(DragonAscent.formFor(E, crystals,
  mon("RAYQUAZA", { { id = "DRAGONASCENT" } }, "ULTRANECROZIUM_Z")), nil,
  "and so is one holding Ultranecrozium Z")

-- The withdrawn stone -- still a legal string to be holding, since a stone
-- already in a bag or stamped on a mon before 0.30.0 does not vanish -- is
-- not a Z-Crystal and does not block the trigger either.
T.eq(DragonAscent.formFor(E, crystals,
  mon("RAYQUAZA", { { id = "DRAGONASCENT" } }, "RAYQUAZITE")), "RAYQUAZA_MEGA",
  "holding the withdrawn stone does not block the trigger")

T.eq(DragonAscent.formFor(E, crystals, nil), nil, "no mon at all gets nothing")

-- M.FORM is this file's own literal as of 0.30.0 (data/megas.lua carries no
-- RAYQUAZA row to read it off any longer) -- pinned so a typo here cannot
-- silently repeat the 0.2.1 mistake with nothing left to catch it.
T.eq(DragonAscent.FORM, "RAYQUAZA_MEGA",
  "M.FORM still names the National Dex record's own key")

-- ---------------------------------------------------------------------
-- The effect: lands on the USER, lowers Defense and Special one stage each,
-- and is registered on the post-damage ("secondary") path rather than the
-- pure-status ("primary") one, which is what makes EffectRegistry.lua run
-- it at all for a 120-power move.
-- ---------------------------------------------------------------------
do
  local record = DragonAscent.effectRecord()
  T.eq(record.kind, "secondary",
    "a damaging move's own effect must not be \"primary\" -- that path is "
      .. "reserved for power-0 moves and never fires for this one "
      .. "(BattleState.lua:3693 checks move.power == 0 first)")
  T.eq(type(record.run), "function", "and it carries a run function")

  local calls = {}
  local user = { name = "RAYQUAZA", stages = {} }
  local target = { name = "FOE", stages = {} }
  local ctx = {
    user = user, target = target,
    changeStage = function(who, stat, delta, fromEnemy)
      calls[#calls + 1] = { who = who, stat = stat, delta = delta, fromEnemy = fromEnemy }
      who.stages[stat] = (who.stages[stat] or 0) + delta
      return { ("%s's %s fell!"):format(who.name, stat) }
    end,
  }
  local msgs = record.run(ctx)

  T.eq(#calls, 2, "exactly two stat changes are made")
  for _, call in ipairs(calls) do
    T.eq(call.who, user, "every stat change lands on the USER, not the target")
    T.eq(call.fromEnemy, false,
      "self-inflicted, so it is never blocked by the user's own Mist or Substitute")
  end
  local stats = { calls[1].stat, calls[2].stat }
  table.sort(stats)
  T.eq(stats[1], "defense", "one of the two drops is Defense")
  T.eq(stats[2], "special",
    "the other is Special -- Gen 1's one stage covering both Sp. Atk and "
      .. "Sp. Def, which is what \"lowers Special Defense\" becomes here")
  T.eq(user.stages.defense, -1, "Defense actually fell one stage")
  T.eq(user.stages.special, -1, "and Special fell one stage")
  T.eq(target.stages.defense, nil, "the TARGET's stages were never touched")
  T.eq(target.stages.special, nil, "not even the one this move shares a name with")
  T.eq(#msgs, 2, "both lines are returned for the engine to print")
end

-- ---------------------------------------------------------------------
-- M.install: registers the effect unconditionally, patches the move and the
-- species only when each already exists, and warns rather than
-- manufacturing a partial record when one does not.
-- ---------------------------------------------------------------------
local function stubMod(hasMove, hasSpecies)
  local registered = { move_effects = {} }
  local patched = { moves = {}, pokemon = {} }
  local warned = {}
  return {
    content = {
      move_effects = {
        register = function(_, id, record) registered.move_effects[id] = record end,
      },
      moves = {
        get = function(_, id)
          return hasMove and { id = id, power = 120, type = "FLYING" } or nil
        end,
        patch = function(_, id, partial) patched.moves[id] = partial end,
      },
      pokemon = {
        get = function(_, id)
          return hasSpecies and { id = id, learnset = {} } or nil
        end,
        patch = function(_, id, partial) patched.pokemon[id] = partial end,
      },
    },
    log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
    registered = registered, patched = patched, warned = warned,
  }
end

do
  local mod = stubMod(true, true)
  DragonAscent.install(mod)
  T.check(mod.registered.move_effects[DragonAscent.EFFECT] ~= nil,
    "the effect is registered")
  T.eq(mod.registered.move_effects[DragonAscent.EFFECT].kind, "secondary",
    "under its own kind")
  T.eq(mod.patched.moves[DragonAscent.MOVE].effect, DragonAscent.EFFECT,
    "DRAGONASCENT is patched to point at it")
  local learnsetPatch = mod.patched.pokemon[DragonAscent.SPECIES].learnset
  T.check(learnsetPatch ~= nil, "RAYQUAZA's learnset is patched")
  T.eq(learnsetPatch.__append[1].level, DragonAscent.LEVEL, "at level 1")
  T.eq(learnsetPatch.__append[1].move, DragonAscent.MOVE, "teaching Dragon Ascent")
  T.eq(#mod.warned, 0, "nothing to warn about when both bases exist")
end

do
  local mod = stubMod(false, true)
  DragonAscent.install(mod)
  T.eq(mod.patched.moves[DragonAscent.MOVE], nil,
    "no move base to patch means no patch is sent at all")
  T.check(mod.patched.pokemon[DragonAscent.SPECIES] ~= nil,
    "the species patch still goes ahead independently")
  T.eq(#mod.warned, 1, "the missing move is reported")
  T.check(mod.warned[1]:find("DRAGONASCENT", 1, true) ~= nil,
    "naming the move it could not find")
end

do
  local mod = stubMod(true, false)
  DragonAscent.install(mod)
  T.check(mod.patched.moves[DragonAscent.MOVE] ~= nil,
    "the move patch still goes ahead independently")
  T.eq(mod.patched.pokemon[DragonAscent.SPECIES], nil,
    "no species base to patch means no patch is sent at all")
  T.eq(#mod.warned, 1, "the missing species is reported")
  T.check(mod.warned[1]:find("RAYQUAZA", 1, true) ~= nil,
    "naming the species it could not find")
end

do
  local mod = stubMod(false, false)
  DragonAscent.install(mod)
  T.check(mod.registered.move_effects[DragonAscent.EFFECT] ~= nil,
    "the effect registers regardless -- a dead entry is harmless")
  T.eq(#mod.warned, 2, "and both refusals are reported")
end

-- ---------------------------------------------------------------------
-- Wired into the MEGA cell: Rayquaza's own trigger asks neither tier's
-- question, every other mega still asks both, and a held Z-Crystal refuses
-- Rayquaza specifically.
-- ---------------------------------------------------------------------
local KeyItems = dofile(MOD .. "/src/keyitems.lua")

local DATA = { pokemon = {
  RAYQUAZA = { baseStats = { hp = 105, attack = 150, defense = 90,
                             speed = 95, special = 150 },
              types = { "DRAGON", "FLYING" } },
  RAYQUAZA_MEGA = { baseStats = { hp = 105, attack = 180, defense = 100,
                                  speed = 115, special = 180 },
                    types = { "DRAGON", "FLYING" }, form = "MEGA" },
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

local function makeBattle(species, moves, held, inventory)
  local m = mon(species, moves, held)
  m.level = 70
  m.dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 }
  m.statExp = {}
  m.stats = DATA.pokemon[species].baseStats
  return {
    phase = "menu", menuIndex = 1, queue = {}, data = DATA,
    player = { isPlayer = true, mon = m, curStats = m.stats,
               curTypes = DATA.pokemon[species].types },
    game = { save = { party = { m }, inventory = inventory or {} } },
    enemyParty = {},
    animNext = function() end,
    animationsOn = function() return false end,
  }
end

local function entryFor(log)
  return Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                      keyitems = KeyItems, animId = "TESTANIM", log = log,
                      dragonascent = DragonAscent, zcrystals = crystals })
end

-- Rayquaza, knowing Dragon Ascent, holding nothing, trainer carrying no Key
-- Stone at all: the cell is offered anyway.
do
  local entry = entryFor(nil)
  local battle = makeBattle("RAYQUAZA", { { id = "DRAGONASCENT" } }, nil, {})
  T.eq(entry.available(battle), true,
    "Rayquaza's own trigger needs no Key Stone")
  T.eq(entry.activate(battle), true, "and activates")
  T.eq(battle.player.mon.form, "MEGA", "into Mega Rayquaza")
  T.check(battle.player.curStats.attack > DATA.pokemon.RAYQUAZA.baseStats.attack,
    "with the mega's own stats")
end

-- The same Rayquaza holding a Z-Crystal: refused, per the Gen 7 rule, and
-- the ordinary stone path finds nothing either since a Z-Crystal is not a
-- mega stone -- so the cell is not offered at all.
do
  local entry = entryFor(nil)
  local battle = makeBattle("RAYQUAZA", { { id = "DRAGONASCENT" } },
    "FIRIUM_Z", {})
  T.eq(entry.available(battle), false,
    "a Rayquaza holding a Z-Crystal is not offered the cell")
end

-- A Rayquaza that has NOT learned Dragon Ascent has no path to the cell any
-- longer.  Through 0.29.0 this fell back to the ordinary two-tier gate,
-- because RAYQUAZITE still paired with the mega in data/megas.lua; 0.30.0
-- withdrew that row, so the fallback now finds nothing for RAYQUAZA at all,
-- Key Stone or not, byte 172 already in the bag or not.
do
  local entry = entryFor(nil)
  local noKeyStone = makeBattle("RAYQUAZA", { { id = "REST" } }, "RAYQUAZITE", {})
  T.eq(entry.available(noKeyStone), false,
    "no move, no Key Stone: not offered, as ever")

  local withKeyStone = makeBattle("RAYQUAZA", { { id = "REST" } }, "RAYQUAZITE",
    { [KeyItems.KEY_STONE] = 1 })
  T.eq(entry.available(withKeyStone), false,
    "a Key Stone plus the withdrawn stone is no longer enough -- "
      .. "data/megas.lua carries no pairing for either to resolve through")
end

-- Every OTHER mega: the exemption must not have loosened anything.  A
-- Charizard knowing Dragon Ascent (it cannot in the real data, but the
-- gate must not even ask) still needs both a Key Stone and its own stone.
do
  local entry = entryFor(nil)
  local noKeyStone = makeBattle("CHARIZARD", { { id = "DRAGONASCENT" } },
    "CHARIZARDITE_X", {})
  T.eq(entry.available(noKeyStone), false,
    "a Charizard knowing Dragon Ascent still needs the Key Stone -- the "
      .. "exemption is Rayquaza's alone")

  local noStone = makeBattle("CHARIZARD", { { id = "DRAGONASCENT" } }, nil,
    { [KeyItems.KEY_STONE] = 1 })
  T.eq(entry.available(noStone), false,
    "and still needs its own mega stone even with the Key Stone in the bag")

  local both = makeBattle("CHARIZARD", {}, "CHARIZARDITE_X",
    { [KeyItems.KEY_STONE] = 1 })
  T.eq(entry.available(both), true,
    "with both, exactly as before this feature existed")
end

-- Without the module bound at all (a build that failed to load
-- src/dragonascent.lua), mega evolution must degrade to exactly its old
-- behaviour rather than throw.
do
  local entry = Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                             keyitems = KeyItems, animId = "TESTANIM" })
  local battle = makeBattle("RAYQUAZA", { { id = "DRAGONASCENT" } }, nil, {})
  T.eq(entry.available(battle), false,
    "with no dragonascent module bound, Rayquaza is held to the ordinary gate")
end

-- ---------------------------------------------------------------------
-- Switching out and back in: the exact bug this feature could have shipped.
-- resolve.lua's own switch-in reapply used to ask ONLY the stone-based
-- eligibility, so a Mega Rayquaza that got there through Dragon Ascent
-- (holding no stone) would come back from the bench with the mega's
-- picture and species but its BASE stats and types -- the same silent
-- mismatch data/megas.lua's own header already warns a wrong form id
-- produces, from a different cause.
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  registry:register(entryFor(nil))
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                megas = megas, dragonascent = DragonAscent, zcrystals = crystals })

  local battle = makeBattle("RAYQUAZA", { { id = "DRAGONASCENT" } }, nil, {})
  battle.player.mon.form = "MEGA"
  -- The fresh, form-blind battler makeBattler would actually hand back on
  -- switch-in: base curStats/curTypes even though the mon is still marked.
  battle.player.curStats = battle.player.mon.stats
  battle.player.curTypes = DATA.pokemon.RAYQUAZA.types

  Resolve.onBattlerSwitched({ battle = battle, battler = battle.player })
  T.check(battle.player.curStats.attack > DATA.pokemon.RAYQUAZA.baseStats.attack,
    "switching back in reapplies Mega Rayquaza's own stats with no stone held")
  T.eq(battle.player.curTypes, DATA.pokemon.RAYQUAZA_MEGA.types,
    "and its own types")
end

-- ---------------------------------------------------------------------
-- Through the real loader: a national_dex STUB that registers RAYQUAZA and
-- DRAGONASCENT the shape the real mod does -- unconditionally, the way
-- src/moves.lua's own comment says registration always is -- and then
-- battle_forms loaded for real behind it, so the merged registries are read
-- back the way the game would see them rather than asserted against a stub
-- of battle_forms's own patches. This is what proves `patch` does not fight
-- `register`: the effect lands on DRAGONASCENT without disturbing its power,
-- accuracy, type or PP, and the learnset gains Dragon Ascent without losing
-- REST, FLY or HYPER BEAM -- the exact two things a wholesale-replacing
-- patch (a bare list instead of `__append`, or patching the whole record
-- instead of one field) would have gotten wrong.
-- ---------------------------------------------------------------------
do
  local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local body = handle:read("*a")
    handle:close()
    return body
  end

  -- Read out of main.lua's own source rather than mirrored by hand, the way
  -- tests/battle_forms_maxmoves_test.lua's own loader block does.
  local MAIN = readFile(MOD .. "/main.lua")
  local shipped = { "manifest.json", "main.lua" }
  for _, tree in ipairs({ "src", "data" }) do
    for name in MAIN:gmatch('"(' .. tree .. '/[%w_]+%.lua)"') do
      shipped[#shipped + 1] = name
    end
  end
  T.check(#shipped > 10, "main.lua's sibling list was read back out of its source")

  local ok = false
  for _, name in ipairs(shipped) do
    if name == "src/dragonascent.lua" then ok = true end
  end
  T.check(ok, "src/dragonascent.lua is one of the files main.lua actually loads")

  local NATIONAL_DEX_STUB = [[
return function(mod)
  mod.content.pokemon:register("RAYQUAZA", {
    id = "RAYQUAZA", name = "Rayquaza", dex = 384,
    types = { "DRAGON", "FLYING" },
    baseStats = { hp = 105, attack = 150, defense = 90, speed = 95, special = 150 },
    catchRate = 45, baseExp = 255, growthRate = "MEDIUM_FAST",
    level1Moves = {},
    learnset = { { level = 54, move = "REST" }, { level = 63, move = "FLY" },
                 { level = 90, move = "HYPER_BEAM" } },
    spriteFront = "assets/sets/placeholder/front.png",
    spriteBack = "assets/sets/placeholder/back.png",
    frontSize = 5,
  })
  mod.content.pokemon:register("RAYQUAZA_MEGA", {
    id = "RAYQUAZA_MEGA", name = "Rayquaza", dex = 384, form = "MEGA",
    types = { "DRAGON", "FLYING" },
    baseStats = { hp = 105, attack = 180, defense = 100, speed = 115, special = 180 },
    catchRate = 45, baseExp = 255, growthRate = "MEDIUM_FAST",
    level1Moves = {}, learnset = {},
    spriteFront = "assets/sets/placeholder/front.png",
    spriteBack = "assets/sets/placeholder/back.png",
    frontSize = 5,
  })
  mod.content.moves:register("DRAGONASCENT", {
    id = "DRAGONASCENT", name = "Dragon Ascent", type = "FLYING",
    power = 120, accuracy = 100, pp = 5, category = "physical",
    effect = "NO_ADDITIONAL_EFFECT", effectModeled = false,
  })
  mod.content.moves:register("REST", { id = "REST", name = "Rest",
    type = "PSYCHIC_TYPE", power = 0, accuracy = 100, pp = 10,
    effect = "NO_ADDITIONAL_EFFECT" })
  mod.content.moves:register("FLY", { id = "FLY", name = "Fly",
    type = "FLYING", power = 90, accuracy = 95, pp = 15,
    effect = "NO_ADDITIONAL_EFFECT" })
  mod.content.moves:register("HYPER_BEAM", { id = "HYPER_BEAM",
    name = "Hyper Beam", type = "NORMAL", power = 150, accuracy = 90,
    pp = 5, effect = "NO_ADDITIONAL_EFFECT" })
end
]]

  local files = {
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = NATIONAL_DEX_STUB,
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
    fs = T.sdk.memfs(files), data = T.fixtures.fresh(),
  })
  T.eq(#run.errors, 0, "the mod loads clean against a real RAYQUAZA/DRAGONASCENT")

  local dragonAscent = run.data.moves.DRAGONASCENT
  T.check(dragonAscent ~= nil, "DRAGONASCENT survived the merge")
  T.eq(dragonAscent.effect, DragonAscent.EFFECT,
    "and now points at this mod's own effect")
  T.eq(dragonAscent.power, 120, "with national_dex's own power untouched")
  T.eq(dragonAscent.accuracy, 100, "accuracy untouched")
  T.eq(dragonAscent.type, "FLYING", "type untouched")
  T.eq(dragonAscent.pp, 5, "PP untouched")
  T.eq(dragonAscent.category, "physical", "and category untouched -- the "
    .. "patch touched exactly one field")

  local effectRecord = run.data.move_effects[DragonAscent.EFFECT]
  T.check(effectRecord ~= nil, "the effect record is in the merged registry")
  T.eq(effectRecord.kind, "secondary", "under its own kind")

  local rayquaza = run.data.pokemon.RAYQUAZA
  T.check(rayquaza ~= nil, "RAYQUAZA survived the merge")
  T.eq(#rayquaza.learnset, 4,
    "the three national_dex rows plus the one this mod appended")
  local byMove = {}
  for _, row in ipairs(rayquaza.learnset) do byMove[row.move] = row.level end
  T.eq(byMove.REST, 54, "REST is still there, at its own level")
  T.eq(byMove.FLY, 63, "so is FLY")
  T.eq(byMove.HYPER_BEAM, 90, "so is HYPER BEAM")
  T.eq(byMove.DRAGONASCENT, 1, "and DRAGONASCENT was appended at level 1")
  T.eq(rayquaza.baseStats.attack, 150,
    "the species' base stats are untouched -- only `learnset` was patched")

  -- The MEGA cell itself, driven off the merged data the way the real menu
  -- would read it, to prove the whole chain -- registration, patch, cell --
  -- agrees with itself through the actual loader and not just through the
  -- hand-built fixtures above.
  local KeyItemsMod = dofile(MOD .. "/src/keyitems.lua")
  local entry = Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                             keyitems = KeyItemsMod, animId = "TESTANIM",
                             dragonascent = DragonAscent, zcrystals = crystals })
  local liveMon = { species = "RAYQUAZA", level = 70,
                    dvs = { hp = 15, attack = 15, defense = 15, speed = 15,
                           special = 15 },
                    statExp = {}, moves = { { id = "DRAGONASCENT", pp = 5 } },
                    stats = rayquaza.baseStats }
  local liveBattle = {
    phase = "menu", menuIndex = 1, queue = {}, data = run.data,
    player = { isPlayer = true, mon = liveMon, curStats = liveMon.stats,
               curTypes = rayquaza.types },
    game = { save = { party = { liveMon }, inventory = {} } },
    enemyParty = {}, animNext = function() end, animationsOn = function() return false end,
  }
  T.eq(entry.available(liveBattle), true,
    "against the real merged data.pokemon, the cell is offered with no items at all")
end

T.finish("battle_forms_dragonascent")
