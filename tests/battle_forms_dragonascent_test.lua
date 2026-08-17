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
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
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
  T.check(learnsetPatch ~= nil, "RAYQUAZA's Gen 1 learnset is patched")
  T.eq(learnsetPatch.__append[1].level, DragonAscent.LEVEL,
    "at the main series' own level, 75")
  T.eq(learnsetPatch.__append[1].move, DragonAscent.MOVE, "teaching Dragon Ascent")
  T.eq(mod.patched.pokemon[DragonAscent.SPECIES].levelMoves, nil,
    "and nothing is patched onto the Gen 2 field name on an unbound (Gen 1) load")
  T.eq(#mod.warned, 0, "nothing to warn about when both bases exist")
end

-- Bound to Gen 2: the SAME level lands on `levelMoves` instead, the field
-- national_dex's own src/gen2shape.lua actually reshapes RAYQUAZA's record
-- into on a Gold boot -- see M.install's own header for why patching
-- `learnset` there would silently teach a field Mon.movesAtLevel never
-- reads.
do
  DragonAscent.bind({ gen2 = true })
  local mod = stubMod(true, true)
  DragonAscent.install(mod)
  local levelMovesPatch = mod.patched.pokemon[DragonAscent.SPECIES].levelMoves
  T.check(levelMovesPatch ~= nil, "RAYQUAZA's Gen 2 levelMoves is patched")
  T.eq(levelMovesPatch.__append[1].level, DragonAscent.LEVEL,
    "at the same level 75, no per-generation split")
  T.eq(levelMovesPatch.__append[1].move, DragonAscent.MOVE,
    "teaching Dragon Ascent")
  T.eq(mod.patched.pokemon[DragonAscent.SPECIES].learnset, nil,
    "and nothing is patched onto the Gen 1 field name on a Gen 2 load")
  -- The actual 0.55.0 fix. Gold's own move_effects dispatch
  -- (game/src/battle/gen2/Battle.lua:1561-1566) fires ANY registered
  -- record's `run` unconditionally and BEFORE the accuracy roll, then
  -- returns -- so patching DRAGONASCENT's `effect` field to point at this
  -- mod's own record would still swallow the move even though
  -- M.effectRecord's own `run` recognises deps.gen2 and returns {} early:
  -- an empty table is still a handler, and `if handler then ... return end`
  -- fires on that alone. 0.54.0 shipped exactly that patch and that is why
  -- PP was spent and nothing else happened. Leaving `effect` at whatever
  -- national_dex's own gen2 registry set it to (EFFECT_NORMAL_HIT, which no
  -- move_effects record is ever registered under) means the dispatch finds
  -- no handler and the move resolves normally.
  T.eq(mod.patched.moves[DragonAscent.MOVE], nil,
    "on Gen 2, DRAGONASCENT's own effect field is left untouched -- "
      .. "patching it is what let 0.54.0's dispatch swallow the whole move")
  DragonAscent.bind(nil)
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
                      dragonascent = DragonAscent, zcrystals = crystals,
                      battlerof = Battlerof })
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
                             keyitems = KeyItems, animId = "TESTANIM",
                             battlerof = Battlerof })
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
                megas = megas, dragonascent = DragonAscent, zcrystals = crystals,
                battlerof = Battlerof })

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
  T.eq(byMove.DRAGONASCENT, DragonAscent.LEVEL,
    "and DRAGONASCENT was appended at the main series' own level, 75")
  T.eq(rayquaza.baseStats.attack, 150,
    "the species' base stats are untouched -- only `learnset` was patched")

  -- The MEGA cell itself, driven off the merged data the way the real menu
  -- would read it, to prove the whole chain -- registration, patch, cell --
  -- agrees with itself through the actual loader and not just through the
  -- hand-built fixtures above.
  local KeyItemsMod = dofile(MOD .. "/src/keyitems.lua")
  local entry = Mega.entry({ forms = Forms, eligibility = E, megas = megas,
                             keyitems = KeyItemsMod, animId = "TESTANIM",
                             dragonascent = DragonAscent, zcrystals = crystals,
                             battlerof = Battlerof })
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

-- ---------------------------------------------------------------------
-- Through national_dex's OWN reshaping code (src/gen2shape.lua), not a
-- mirror of it: this is what the previous test block cannot catch, because
-- its NATIONAL_DEX_STUB registers a species directly rather than reshaping
-- one the way a real Gold boot does. The player's own report was exactly
-- this gap -- src/gen2shape.lua's GEN1_ONLY set drops `learnset` from a
-- reshaped record entirely, and Mon.movesAtLevel reads only `levelMoves` --
-- so a suite that never drives gen2shape's own M.record could stay green
-- while Mega Rayquaza's Gen 2 trigger patched a field nothing ever reads.
-- ---------------------------------------------------------------------
do
  local Gen2Shape = dofile(MOD .. "/../national_dex_mod/src/gen2shape.lua")

  -- A representative Gen 1-shaped source record, the exact shape national_dex
  -- generates RAYQUAZA in (learnset + level1Moves + baseStats.special) --
  -- more than four learnset rows below level 75 on purpose, so the FIFO
  -- push-out Mon.movesAtLevel actually performs has something to prove
  -- rather than trivially fitting every move in four slots regardless of
  -- append order.
  local rayquazaSource = {
    id = "RAYQUAZA", name = "Rayquaza", dex = 384,
    types = { "DRAGON", "FLYING" },
    baseStats = { hp = 105, attack = 150, defense = 90, speed = 95, special = 150 },
    catchRate = 45, baseExp = 255, growthRate = "MEDIUM_FAST",
    level1Moves = { "TWISTER" },
    learnset = { { level = 20, move = "AIR_CUTTER" },
                 { level = 35, move = "DRAGON_DANCE" },
                 { level = 54, move = "REST" },
                 { level = 63, move = "FLY" },
                 { level = 90, move = "HYPER_BEAM" } },
    frontSize = 5,
  }

  -- What national_dex would actually register on a Gold boot: no `learnset`
  -- (stripped by GEN1_ONLY), a fresh `levelMoves` in its place.
  local reshaped = Gen2Shape.record(rayquazaSource)
  T.eq(reshaped.learnset, nil,
    "gen2shape strips `learnset` entirely, exactly as its own GEN1_ONLY set says")
  T.check(type(reshaped.levelMoves) == "table",
    "and folds level1Moves + learnset into `levelMoves` instead")

  -- battle_forms's own patch, bound to Gen 2, against that real reshaped
  -- record -- proving the fix lands where national_dex's own code actually
  -- put the data, not where this mod merely assumes it did.
  local patched = { pokemon = {} }
  local stubMod2 = {
    content = {
      moves = {
        get = function(_, id) return { id = id, power = 120, type = "FLYING" } end,
        patch = function() end,
      },
      pokemon = {
        get = function(_, id) return id == "RAYQUAZA" and reshaped or nil end,
        patch = function(_, id, partial) patched.pokemon[id] = partial end,
      },
      move_effects = { register = function() end },
    },
  }
  DragonAscent.bind({ gen2 = true })
  DragonAscent.install(stubMod2)
  DragonAscent.bind(nil)

  local levelMovesPatch = patched.pokemon.RAYQUAZA.levelMoves
  T.check(levelMovesPatch ~= nil,
    "the patch lands on levelMoves, the field national_dex's own reshaping "
      .. "actually produced")
  T.eq(levelMovesPatch.__append[1].level, 75, "at level 75")
  T.eq(levelMovesPatch.__append[1].move, "DRAGONASCENT", "teaching Dragon Ascent")

  -- Merge levelMoves + the appended row by hand (Registry.lua's own
  -- __append semantics, done inline here rather than pulling in the whole
  -- mod loader for one list concat) and hand the merged record to Gold's
  -- REAL Mon.movesAtLevel -- the same function every level-up and every
  -- freshly caught Pokemon on Gold actually calls.
  local merged = {}
  for _, row in ipairs(reshaped.levelMoves) do merged[#merged + 1] = row end
  for _, row in ipairs(levelMovesPatch.__append) do merged[#merged + 1] = row end
  T.eq(#merged, 7, "level1Moves' TWISTER plus five learnset rows plus DRAGONASCENT")

  local Mon = require("src.battle.gen2.Mon")
  local movesAt75 = Mon.movesAtLevel({ levelMoves = merged }, 75, {})
  local ids = {}
  for _, m in ipairs(movesAt75) do ids[m.id] = true end
  T.eq(#movesAt75, 4, "the engine's own four-move cap, exactly as any species")
  T.check(ids.DRAGONASCENT,
    "a level-75 Rayquaza knows Dragon Ascent on Gold, even with five other "
      .. "learnset moves below that level competing for the same four slots")
  T.check(not ids.TWISTER,
    "TWISTER (level1Moves, the oldest) is exactly what got pushed out -- "
      .. "proof this is testing the real push-out rule and not four moves "
      .. "fitting by accident")

  -- The identical guarantee on Gen 1, through the engine's own
  -- Pokemon.movesAtLevel, over the SAME source shape (learnset +
  -- level1Moves, untouched by gen2shape).
  local Pokemon = require("src.pokemon.Pokemon")
  local gen1Merged = { level1Moves = rayquazaSource.level1Moves, learnset = {} }
  for _, row in ipairs(rayquazaSource.learnset) do
    gen1Merged.learnset[#gen1Merged.learnset + 1] = row
  end
  gen1Merged.learnset[#gen1Merged.learnset + 1] = { level = 75, move = "DRAGONASCENT" }
  local gen1MovesAt75 = Pokemon.movesAtLevel(gen1Merged, 75)
  local gen1Has = {}
  for _, id in ipairs(gen1MovesAt75) do gen1Has[id] = true end
  T.eq(#gen1MovesAt75, 4, "the same four-move cap on Gen 1")
  T.check(gen1Has.DRAGONASCENT,
    "and the same guarantee on Gen 1: a level-75 Rayquaza knows Dragon "
      .. "Ascent there too")
  T.check(not gen1Has.TWISTER, "with the same oldest move pushed out")
end

-- ---------------------------------------------------------------------
-- Gen 2: Mega Rayquaza's own arming path (no Key Stone, no held item, the
-- identical exemption Gen 1 has), its own message channel, switching, and
-- the post-hit stat drop routed around Gold's early move_effects dispatch.
-- ---------------------------------------------------------------------
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local Announce = dofile(MOD .. "/src/announce.lua")

local GEN2_DATA = { pokemon = {
  RAYQUAZA = { baseStats = { hp = 105, attack = 150, defense = 90, speed = 95,
                             specialAttack = 150, specialDefense = 90 },
              types = { "DRAGON", "FLYING" }, name = "RAYQUAZA" },
  RAYQUAZA_MEGA = { baseStats = { hp = 105, attack = 180, defense = 100,
                                  speed = 115, specialAttack = 180,
                                  specialDefense = 100 },
                    types = { "DRAGON", "FLYING" }, form = "MEGA",
                    name = "RAYQUAZA" },
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                              specialAttack = 85, specialDefense = 85 },
                types = { "FIRE", "FLYING" }, name = "CHARIZARD" },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, specialAttack = 130,
                                     specialDefense = 85 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X",
                       name = "CHARIZARD" },
} }

-- A COPY of the species' own baseStats, never the same table: becomeForm's
-- own applyStats mutates mon.stats in place (src/gen2forms.lua's own
-- header), and aliasing it straight to GEN2_DATA's fixture record would
-- corrupt that shared record the moment a form change ran, which is a bug
-- in this test fixture rather than in the primitive it is proving.
local function copyStats(stats)
  local out = {}
  for k, v in pairs(stats) do out[k] = v end
  return out
end

local function gen2Mon(species, moves, item)
  local stats = copyStats(GEN2_DATA.pokemon[species].baseStats)
  return { species = species, level = 70, item = item, moves = moves or {},
           dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
           statExp = {}, stats = stats, hp = stats.hp, maxHp = stats.hp }
end

local function gen2Entry(log)
  return Mega.entry({ eligibility = E, megas = megas, keyitems = KeyItems,
                      log = log, dragonascent = DragonAscent, zcrystals = crystals,
                      battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms,
                      announce = Announce })
end

-- Rayquaza, knowing Dragon Ascent, holding nothing, no Key Stone in the
-- bag: the cell is offered and activates, exactly as on Gen 1 -- and now
-- says so, through the Gen 2 message channel.
do
  local entry = gen2Entry(nil)
  local rayquazaMon = gen2Mon("RAYQUAZA", { { id = "DRAGONASCENT" } })
  local battle = setmetatable({
    data = GEN2_DATA, player = rayquazaMon,
    game = { save = { inventory = {} } }, events = {},
  }, { __index = require("src.battle.gen2.Battle") })

  T.eq(entry.available(battle), true,
    "Rayquaza's own trigger needs no Key Stone on Gen 2 either")
  T.eq(entry.activate(battle), true, "and activates")
  T.eq(rayquazaMon.form, "MEGA", "into Mega Rayquaza")
  T.check(rayquazaMon.stats.attack > GEN2_DATA.pokemon.RAYQUAZA.baseStats.attack,
    "with the mega's own stats, written straight onto mon.stats")
  local events = battle:takeEvents()
  T.eq(#events, 1, "the mega evolution message was announced")
  T.eq(events[1].text, "RAYQUAZA's\nMega Evolution!",
    "in the mainline games' own words, through the Gen 2 channel")
end

-- Every OTHER Gen 2 mega: the exemption must not have loosened the ordinary
-- gate.  A Charizard with no Key Stone in the bag is refused; with a Key
-- Stone and its own mega stone, it works exactly as before this feature
-- existed.
do
  local entry = gen2Entry(nil)
  local noKeyStone = gen2Mon("CHARIZARD", {}, "CHARIZARDITE_X")
  local battle1 = { data = GEN2_DATA, player = noKeyStone,
                    game = { save = { inventory = {} } } }
  T.eq(entry.available(battle1), false,
    "a Charizard on Gen 2 still needs the Key Stone -- the exemption is "
      .. "Rayquaza's alone")

  local both = gen2Mon("CHARIZARD", {}, "CHARIZARDITE_X")
  local battle2 = { data = GEN2_DATA, player = both,
                    game = { save = { inventory = { [KeyItems.KEY_STONE] = 1 } } } }
  T.eq(entry.available(battle2), true,
    "with a Key Stone in the bag and the stone held on the mon, exactly as "
      .. "before this feature existed")
end

-- Switching out and back in: Gen 2 has no makeBattler rebuild step at all
-- (Battle:switch, game/src/battle/gen2/Battle.lua:3452-3483, only
-- reassigns self.player/self.playerIndex), so the mon that comes back is
-- literally the SAME table with mon.stats and mon.form untouched -- the
-- property src/resolve.lua's own M.onBattlerSwitched header cites for why
-- Gen 2 needs no reapply logic at all, Rayquaza included.
do
  local registry = Transforms.new()
  registry:register(gen2Entry(nil))
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                megas = megas, dragonascent = DragonAscent, zcrystals = crystals,
                battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms })

  local rayquazaMon = gen2Mon("RAYQUAZA", { { id = "DRAGONASCENT" } })
  Gen2Forms.becomeForm(GEN2_DATA, rayquazaMon, "RAYQUAZA_MEGA")
  local beforeSwitch = { attack = rayquazaMon.stats.attack, form = rayquazaMon.form }

  Resolve.onBattlerSwitched({ battle = { data = GEN2_DATA, player = rayquazaMon },
                              battler = rayquazaMon })
  T.eq(rayquazaMon.stats.attack, beforeSwitch.attack,
    "switching back in on Gen 2 leaves Mega Rayquaza's stats exactly as "
      .. "they were -- no stone-keyed reapply runs, or was needed, to lose")
  T.eq(rayquazaMon.form, beforeSwitch.form,
    "and its form marker exactly as it was")
end

-- The general case the guard actually protects, made concrete. Rayquaza's
-- own case above happens to no-op even with the guard removed --
-- deps.forms.becomeForm reads battler.mon, nil on a raw Gen 2 mon, and
-- returns "no_target" harmlessly -- but an ORDINARY Gen 2 mega (no
-- dragonascent exemption to short-circuit through) falls all the way to
-- deps.eligibility.formForMon, which reads the Gen 1 bag STAMP a Gen 2 mega
-- never writes (src/mega.lua's own Gen 2 branch reads mon.item instead), so
-- it finds no formId and logs the exact false "no longer eligible" warning
-- this guard's own comment describes. Confirmed by deliberate breakage
-- while building this suite: removing the early `if deps.gen2 then return
-- end` reproduces that warning here (Rayquaza's own case stays silent
-- either way, which is why this second case exists) -- restored immediately
-- afterward.
do
  local logged = {}
  local registry = Transforms.new()
  registry:register(gen2Entry(nil))
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                megas = megas, dragonascent = DragonAscent, zcrystals = crystals,
                battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms,
                log = { warn = function(_, fmt, ...)
                  logged[#logged + 1] = fmt:format(...)
                end } })

  local charMon = gen2Mon("CHARIZARD", {}, "CHARIZARDITE_X")
  Gen2Forms.becomeForm(GEN2_DATA, charMon, "CHARIZARD_MEGA_X")
  local before = { attack = charMon.stats.attack, form = charMon.form }

  Resolve.onBattlerSwitched({ battle = { data = GEN2_DATA, player = charMon },
                              battler = charMon })
  T.eq(charMon.stats.attack, before.attack,
    "an ordinary Gen 2 mega's stats are untouched by switching too")
  T.eq(charMon.form, before.form, "and its form marker too")
  T.eq(#logged, 0,
    "and no false \"no longer eligible\" warning is logged -- the guard "
      .. "this case exists to pin")
end

-- ---------------------------------------------------------------------
-- Dragon Ascent's post-hit stat drop, Gold's own route to it.  Gold
-- dispatches a registered move_effects record's `run` unconditionally and
-- before the accuracy roll (game/src/battle/gen2/Battle.lua:1561-1566), so
-- M.effectRecord's own `run` -- the Gen 1 mechanism proven above -- has to
-- refuse itself there rather than fire early with the wrong ctx shape.
-- ---------------------------------------------------------------------
DragonAscent.bind({ gen2 = true })

-- Simulates exactly the call shape Gold's own dispatch makes: the BATTLE
-- instance handed positionally where a Gen 1 ctx table would be. Before
-- this guard existed, `ctx.changeStage` read off a bare Battle instance was
-- nil, and calling it errored outright rather than merely misbehaving.
do
  local record = DragonAscent.effectRecord()
  local msgs = record.run({})
  T.same(msgs, {},
    "on Gen 2, the shared registry's own run does nothing rather than "
      .. "reading ctx.user/ctx.changeStage off a battle-engine instance")
end

do
  local RealBattle = require("src.battle.gen2.Battle")
  local user = gen2Mon("RAYQUAZA", { { id = "DRAGONASCENT" } })
  local foe = gen2Mon("CHARIZARD", {})
  local battle = setmetatable({
    data = GEN2_DATA, player = user, enemy = foe,
    stages = { player = RealBattle.newStages(), enemy = RealBattle.newStages() },
    events = {},
  }, { __index = RealBattle })

  DragonAscent.onDamageDealt({ battle = battle, user = user, target = foe,
                               moveId = "DRAGONASCENT", damage = 90 })
  T.eq(battle.stages.player.defense, -1, "Defense fell one stage on the user")
  T.eq(battle.stages.player.specialDefense, -1,
    "and Special Defense fell one stage too")
  T.check(#battle:takeEvents() > 0,
    "and the engine's own stat-drop message was queued through changeStage")
end

-- Gated on real damage: a move that merely connected for 0 (a Substitute
-- soak reads through here on Gen 1 too, opts.damage 0) drops nothing.
do
  local RealBattle = require("src.battle.gen2.Battle")
  local user = gen2Mon("RAYQUAZA", { { id = "DRAGONASCENT" } })
  local foe = gen2Mon("CHARIZARD", {})
  local battle = setmetatable({
    data = GEN2_DATA, player = user, enemy = foe,
    stages = { player = RealBattle.newStages(), enemy = RealBattle.newStages() },
    events = {},
  }, { __index = RealBattle })
  DragonAscent.onDamageDealt({ battle = battle, user = user, target = foe,
                               moveId = "DRAGONASCENT", damage = 0 })
  T.eq(battle.stages.player.defense, 0, "no damage, no drop")
end

-- Gated on the target surviving, the identical rule Gen 1's own
-- EffectRegistry.lua applies to every "secondary" effect.
do
  local RealBattle = require("src.battle.gen2.Battle")
  local user = gen2Mon("RAYQUAZA", { { id = "DRAGONASCENT" } })
  local foe = gen2Mon("CHARIZARD", {})
  foe.hp = 0
  local battle = setmetatable({
    data = GEN2_DATA, player = user, enemy = foe,
    stages = { player = RealBattle.newStages(), enemy = RealBattle.newStages() },
    events = {},
  }, { __index = RealBattle })
  DragonAscent.onDamageDealt({ battle = battle, user = user, target = foe,
                               moveId = "DRAGONASCENT", damage = 90 })
  T.eq(battle.stages.player.defense, 0,
    "a Dragon Ascent that faints its target drops nothing, matching Gen 1")
end

-- A move that is not Dragon Ascent, and a build with the module unbound
-- (Gen 1, or a load where M.bind was never called), touch nothing.
do
  local RealBattle = require("src.battle.gen2.Battle")
  local user = gen2Mon("RAYQUAZA", { { id = "DRAGONASCENT" } })
  local foe = gen2Mon("CHARIZARD", {})
  local battle = setmetatable({
    data = GEN2_DATA, player = user, enemy = foe,
    stages = { player = RealBattle.newStages(), enemy = RealBattle.newStages() },
    events = {},
  }, { __index = RealBattle })
  DragonAscent.onDamageDealt({ battle = battle, user = user, target = foe,
                               moveId = "EXTREMESPEED", damage = 90 })
  T.eq(battle.stages.player.defense, 0, "a different move drops nothing")

  DragonAscent.bind({ gen2 = false })
  DragonAscent.onDamageDealt({ battle = battle, user = user, target = foe,
                               moveId = "DRAGONASCENT", damage = 90 })
  T.eq(battle.stages.player.defense, 0,
    "unbound from Gen 2, onDamageDealt does nothing -- Gen 1's own effect "
      .. "record already does this job through EffectRegistry")
  DragonAscent.bind({ gen2 = true })
end

-- ---------------------------------------------------------------------
-- The end-to-end proof: the REAL M.install, folded over a base DRAGONASCENT
-- record the way national_dex's own gen2 registry actually shapes it
-- (registry_gen2.lua: effect = "EFFECT_NORMAL_HIT", not NO_ADDITIONAL_EFFECT
-- and not this mod's own effect id), driven through Gold's REAL
-- Battle:useMove dispatch (game/src/battle/gen2/Battle.lua:1337 onward,
-- the exact function whose :1561-1566 dispatch swallowed the move in
-- 0.54.0). This is the player's own bug, reproduced and fixed against the
-- real classes rather than a stand-in for them: before 0.55.0's fix this
-- block fails on every assertion below the `useMove` call -- PP is spent,
-- the wild Pokemon's HP does not move, and the stat drop never applies,
-- because the patched `effect` field points at a registered handler whose
-- `run` returns an empty table and Gold's own dispatch treats that as
-- "handled" regardless.
-- ---------------------------------------------------------------------
do
  local RealBattle = require("src.battle.gen2.Battle")
  local RealMon = require("src.battle.gen2.Mon")
  local Runtime = require("src.mods.Runtime")

  -- The base record exactly as national_dex's own gen2 registry carries it.
  local BASE_DRAGONASCENT = { id = "DRAGONASCENT", name = "Dragon Ascent",
    power = 120, accuracy = 100, pp = 5, category = "physical",
    type = "FLYING", effect = "EFFECT_NORMAL_HIT" }

  local patched = { moves = {} }
  local installMod = {
    content = {
      move_effects = { register = function() end },
      moves = {
        get = function(_, id)
          return id == DragonAscent.MOVE and BASE_DRAGONASCENT or nil
        end,
        patch = function(_, id, partial) patched.moves[id] = partial end,
      },
      pokemon = { get = function() return nil end, patch = function() end },
    },
  }
  DragonAscent.install(installMod)

  -- Fold the patch over the base exactly the way Registry.lua's own fold()
  -- would for the one field this patch ever touches -- proving the fix
  -- through what M.install actually produced, not through a hand-picked
  -- effect id.
  local effectiveEffect = BASE_DRAGONASCENT.effect
  local movePatch = patched.moves[DragonAscent.MOVE]
  if movePatch and movePatch.effect then effectiveEffect = movePatch.effect end

  local TYPES = {
    DRAGON = { id = "DRAGON", index = 26, category = "physical" },
    FLYING = { id = "FLYING", index = 2, category = "physical" },
    NORMAL = { id = "NORMAL", index = 0, category = "physical" },
  }
  local data = {
    pokemon = {
      growthRates = { GROWTH_MEDIUM_FAST = { numerator = 1, denominator = 1,
        squared = 0, linear = 0, constant = 0 } },
      RAYQUAZA = { id = "RAYQUAZA", name = "RAYQUAZA",
        baseStats = { hp = 105, attack = 150, defense = 90, speed = 95,
          specialAttack = 150, specialDefense = 90 },
        types = { "DRAGON", "FLYING" }, growthRate = "GROWTH_MEDIUM_FAST" },
      -- Deliberately overtuned HP/Defense/Sp.Def relative to Rayquaza's
      -- attack: the effect's own gate refuses to drop stats when the hit
      -- faints its target (matching Gen 1's identical rule), so this fixture
      -- has to SURVIVE a 120-power STAB hit for that gate to be provably
      -- uninvolved in the assertions below, rather than accidentally
      -- satisfied by a one-hit kill.
      SNORLAX = { id = "SNORLAX", name = "SNORLAX",
        baseStats = { hp = 500, attack = 110, defense = 400, speed = 30,
          specialAttack = 65, specialDefense = 400 },
        types = { "NORMAL", "NORMAL" }, growthRate = "GROWTH_MEDIUM_FAST" },
    },
    moves = { DRAGONASCENT = { id = "DRAGONASCENT", name = "Dragon Ascent",
      power = 120, accuracy = 100, pp = 5, category = "physical",
      type = "FLYING", effect = effectiveEffect } },
    type_chart = { types = TYPES, matchups = {} },
    items = {},
    -- The merged registry the real loader would build, carrying this mod's
    -- own record under its own id regardless of whether anything points at
    -- it -- M.install registers it unconditionally.
    gen2MoveEffects = { [DragonAscent.EFFECT] = DragonAscent.effectRecord() },
  }

  local perfect = { attack = 15, defense = 15, speed = 15, special = 15 }
  perfect.hp = RealMon.hpDV(perfect)
  local player = RealMon.new(data, "RAYQUAZA", 75,
    { dvs = perfect, moves = { { id = "DRAGONASCENT", pp = 5, maxPp = 5 } } })
  local wild = RealMon.new(data, "SNORLAX", 100, { dvs = perfect, moves = {} })

  local received = {}
  local FakeEvents = { listeners = { ["battle.damage_dealt"] = true } }
  function FakeEvents:emit(name, payload)
    if name == "battle.damage_dealt" then
      received[#received + 1] = payload
      DragonAscent.onDamageDealt(payload)
    end
  end
  local savedEvents, savedHooks = Runtime.events, Runtime.hooks
  Runtime.install(FakeEvents, Runtime.hooks, {})

  local ok, battle = pcall(function()
    local b = RealBattle.new({ data = data, party = { player }, wild = wild,
      random = function() return 0 end })
    b:useMove(player, wild, "DRAGONASCENT")
    return b
  end)

  Runtime.install(savedEvents, savedHooks, nil)

  T.check(ok, "the real dispatch runs without erroring: " .. tostring(battle))
  T.eq(player.moves[1].pp, 4, "Dragon Ascent still spends its own PP")
  T.check(wild.hp < wild.maxHp,
    "and now actually deals damage -- the exact symptom the player "
      .. "reported (\"pp is used but no move happens\") is gone")
  T.check(wild.hp > 0, "and the target survives, so the stat-drop gate "
    .. "below is provably not satisfied merely by a one-hit KO")
  T.eq(#received, 1, "battle.damage_dealt fired once, off the real hit")
  T.eq(battle.stages.player.defense, -1,
    "the self-lowering effect still applies, through battle.damage_dealt "
      .. "rather than through move_effects")
  T.eq(battle.stages.player.specialDefense, -1, "both halves of it")
end

T.finish("battle_forms_dragonascent")
