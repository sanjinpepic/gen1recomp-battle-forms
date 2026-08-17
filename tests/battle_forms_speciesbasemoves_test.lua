-- The eleven species Z-Crystals' own base moves: ten get a real effect and
-- an honest `effectModeled = true`, one (Spirit Shackle) is refused rather
-- than faked.  Three things this suite exists to prove and none of them for
-- free.
--
-- First, each modelled effect actually computes what it claims to, driven
-- against a fake ctx the same way tests/battle_forms_dragonascent_test.lua
-- drives DragonAscent.effectRecord() -- not merely that a function exists,
-- but that Volt Tackle's recoil is a THIRD of the damage dealt and not
-- RECOIL_EFFECT's generic quarter, that Darkest Lariat's damage calculation
-- genuinely ignores the target's Defense stage and restores it afterward,
-- and so on for the rest.
--
-- Second, that M.install's guarded-patch idiom degrades independently per
-- row and per species the same discipline src/dragonascent.lua and
-- src/terablasttm.lua already hold themselves to -- a missing move refuses
-- the whole row and says so, a missing species (Lycanroc's three formes,
-- most plausibly split by NATIONAL DEX being off) refuses only itself.
--
-- Third, through the real loader: every row lands on the merged registry
-- the way the game would actually see it, and Spirit Shackle is proven
-- UNTOUCHED -- no patch, no teach -- rather than merely undocumented.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local SBM = dofile(MOD .. "/src/speciesbasemoves.lua")

-- ---------------------------------------------------------------------
-- A fake ctx, built with only the fields each handler actually reads --
-- the same shape tests/battle_forms_dragonascent_test.lua's own fake ctx
-- uses for DragonAscent.effectRecord().
-- ---------------------------------------------------------------------
local function fakeCtx(opts)
  opts = opts or {}
  local user = opts.user or { name = "USER", stages = {}, mon = { status = nil } }
  local target = opts.target or { name = "TARGET", stages = {},
                                   mon = { status = opts.targetStatus } }
  local said = {}
  local applied = {}
  local inflicted = {}
  local rngQueue = opts.rng or { 255 } -- default: every chance roll misses
  local rngIndex = 0
  local ctx = {
    user = user, target = target, move = opts.move or { id = "MOVE", type = "NORMAL" },
    totalDealt = opts.totalDealt or 0,
    battle = {
      data = {},
      applyDamage = function(_, who, amount)
        applied[#applied + 1] = { who = who, amount = amount }
      end,
    },
    say = function(text) said[#said + 1] = text end,
    displayName = function(b) return b.name end,
    rng = function(lo, hi)
      rngIndex = rngIndex + 1
      return rngQueue[rngIndex] or rngQueue[#rngQueue] or lo
    end,
    inflict = function(who, status, statusOpts)
      inflicted[#inflicted + 1] = { who = who, status = status, opts = statusOpts }
      return { "inflicted" }
    end,
    changeStage = function(who, stat, delta, fromEnemy)
      who.stages[stat] = (who.stages[stat] or 0) + delta
      return { { who = who, stat = stat, delta = delta, fromEnemy = fromEnemy } }
    end,
    computeDamage = opts.computeDamage or function() return 40, { crit = false, typeMult = 10 } end,
  }
  return ctx, said, applied, inflicted
end

-- ---------------------------------------------------------------------
-- VOLT TACKLE: one third recoil (not RECOIL_EFFECT's one quarter), plus a
-- 10% (26/256) paralysis chance.
-- ---------------------------------------------------------------------
do
  local record = SBM.voltTackleEffect()
  T.eq(record.kind, "secondary", "on the post-damage path, like every other "
    .. "custom effect in this file")
  T.eq(type(record.afterDamage), "function", "recoil is an afterDamage stage")
  T.eq(type(record.run), "function", "and paralysis is a secondary run")

  local ctx, said, applied = fakeCtx({ totalDealt = 90 })
  record.afterDamage(ctx)
  T.eq(#applied, 1, "exactly one recoil application")
  T.eq(applied[1].who, ctx.user, "recoil lands on the USER")
  T.eq(applied[1].amount, 30, "one third of 90 damage dealt, not one quarter (22)")
  T.check(#said >= 1, "a recoil message is printed")

  -- Rounding and the floor of 1: 90/3 = 30 exactly; 5 damage floors to 1.
  local ctx2, _, applied2 = fakeCtx({ totalDealt = 5 })
  record.afterDamage(ctx2)
  T.eq(applied2[1].amount, 1, "recoil never rounds down to zero")
end

do
  local record = SBM.voltTackleEffect()
  -- rng(0,255) < 26 lands paralysis; queue a hit then a miss.
  local hitCtx, _, _, hitInflicted = fakeCtx({ rng = { 0 } })
  local msgs = record.run(hitCtx)
  T.eq(#hitInflicted, 1, "a roll under 26 inflicts paralysis")
  T.eq(hitInflicted[1].who, hitCtx.target, "on the TARGET")
  T.eq(hitInflicted[1].status, "PAR", "specifically paralysis")
  T.eq(hitInflicted[1].opts.secondary, true, "flagged as a secondary side effect")
  T.check(#msgs > 0, "and a message comes back")

  local missCtx, _, _, missInflicted = fakeCtx({ rng = { 255 } })
  record.run(missCtx)
  T.eq(#missInflicted, 0, "a roll of 255 (>= 26) never paralyzes")
end

-- ---------------------------------------------------------------------
-- GIGA IMPACT: repoints at the engine's own native HYPER_BEAM_EFFECT
-- rather than registering a copy of it.
-- ---------------------------------------------------------------------
T.eq(SBM.GIGA_IMPACT_EFFECT_ID, "HYPER_BEAM_EFFECT",
  "Giga Impact's real effect IS Hyper Beam's own, not a lookalike of it")

-- ---------------------------------------------------------------------
-- DARKEST LARIAT: the target's Defense stage is ignored for exactly one
-- damage calculation and restored immediately afterward.
-- ---------------------------------------------------------------------
do
  local record = SBM.darkestLariatEffect()
  T.eq(record.kind, "secondary", "on the post-damage path")
  T.eq(type(record.chooseDamage), "function",
    "the damage calculation itself is what this effect changes")

  local seenDefense
  local target = { name = "TARGET", stages = { defense = 4 }, mon = {} }
  local ctx = fakeCtx({ target = target,
    computeDamage = function()
      seenDefense = target.stages.defense
      return 55, { crit = false, typeMult = 10 }
    end })
  local dmg, info = record.chooseDamage(ctx)
  T.eq(seenDefense, nil,
    "the target's Defense stage reads as nil DURING the damage calculation")
  T.eq(target.stages.defense, 4,
    "and is restored to its real value immediately afterward")
  T.eq(dmg, 55, "the computed damage is returned")
  T.eq(info.typeMult, 10, "and its info table alongside it")
end

-- ---------------------------------------------------------------------
-- SPARKLING ARIA: cures the target's burn unconditionally, does nothing
-- to any other status or to no status at all.
-- ---------------------------------------------------------------------
do
  local record = SBM.sparklingAriaEffect()
  T.eq(record.kind, "secondary", "on the post-damage path")

  local burned = { name = "TARGET", stages = {}, mon = { status = "BRN" } }
  local ctx = fakeCtx({ target = burned })
  local msgs = record.run(ctx)
  T.eq(burned.mon.status, nil, "a burned target is cured")
  T.check(#msgs > 0, "and told so")

  local poisoned = { name = "TARGET", stages = {}, mon = { status = "PSN" } }
  local ctx2 = fakeCtx({ target = poisoned })
  local msgs2 = record.run(ctx2)
  T.eq(poisoned.mon.status, "PSN", "a poisoned target keeps its own status")
  T.eq(#msgs2, 0, "and nothing is said about it")

  local healthy = { name = "TARGET", stages = {}, mon = { status = nil } }
  local ctx3 = fakeCtx({ target = healthy })
  local msgs3 = record.run(ctx3)
  T.eq(healthy.mon.status, nil, "an unstatused target stays that way")
  T.eq(#msgs3, 0, "silently")
end

-- ---------------------------------------------------------------------
-- STONE EDGE: no handler at all -- ROWS carries `extra = { highCrit = true }`
-- and nothing else, since the move record's own field is the complete model.
-- ---------------------------------------------------------------------
do
  local row
  for _, r in ipairs(SBM.ROWS) do
    if r.move == "STONEEDGE" then row = r end
  end
  T.check(row ~= nil, "STONEEDGE has its own row")
  T.eq(row.effectId, nil, "no effect id -- highCrit needs no move_effects record")
  T.eq(row.effectRecord, nil, "and no handler to build one")
  T.eq(row.extra and row.extra.highCrit, true,
    "the move record's own highCrit field is patched true")
  T.eq(#row.species, 3, "all three Lycanroc formes")
end

-- ---------------------------------------------------------------------
-- PLAY ROUGH: a 10% (26/256) chance to lower the target's Attack, piercing
-- Mist the way this engine's own side-effect stat drops already do
-- (fromEnemy=false), but still checked against a substitute directly.
-- ---------------------------------------------------------------------
do
  local record = SBM.playRoughEffect()

  local hitCtx = fakeCtx({ rng = { 0 } })
  local msgs = record.run(hitCtx)
  T.eq(hitCtx.target.stages.attack, -1, "a roll under 26 drops Attack one stage")
  T.check(#msgs > 0, "and a message comes back")

  local missCtx = fakeCtx({ rng = { 255 } })
  record.run(missCtx)
  T.eq(missCtx.target.stages.attack, nil, "a roll of 255 changes nothing")

  local subTarget = { name = "TARGET", stages = {}, mon = {}, substituteHP = 5 }
  local subCtx = fakeCtx({ target = subTarget, rng = { 0 } })
  local subMsgs = record.run(subCtx)
  T.eq(subTarget.stages.attack, nil,
    "a target behind a Substitute is never touched, even on a landing roll")
  T.eq(#subMsgs, 0, "and nothing is said")
end

-- ---------------------------------------------------------------------
-- CLANGING SCALES: unconditional self Defense drop, one stage, no roll.
-- ---------------------------------------------------------------------
do
  local record = SBM.clangingScalesEffect()
  local ctx = fakeCtx({})
  local msgs = record.run(ctx)
  T.eq(ctx.user.stages.defense, -1, "the USER's own Defense falls one stage")
  T.eq(ctx.target.stages.defense, nil, "the target is never touched")
  T.check(#msgs > 0, "and a message comes back")
end

-- ---------------------------------------------------------------------
-- SUNSTEEL STRIKE / MOONGEIST BEAM: no handler, no effect id -- plain
-- damage is the complete model of "ignores abilities" this engine can ever
-- have, since it has none.
-- ---------------------------------------------------------------------
for _, moveId in ipairs({ "SUNSTEELSTRIKE", "MOONGEISTBEAM" }) do
  local row
  for _, r in ipairs(SBM.ROWS) do
    if r.move == moveId then row = r end
  end
  T.check(row ~= nil, moveId .. " has its own row")
  T.eq(row.effectId, nil, moveId .. " carries no effect id")
  T.eq(row.effectRecord, nil, moveId .. " registers no handler")
  T.eq(row.extra, nil, moveId .. " patches no extra fields either")
end

-- ---------------------------------------------------------------------
-- SPECTRAL THIEF: steals every positive stage across the six this engine
-- tracks, caps the theft at +6, leaves a negative or zero stage alone, and
-- fires before the accuracy roll regardless of what it decides.
-- ---------------------------------------------------------------------
do
  local record = SBM.spectralThiefEffect()
  T.eq(type(record.beforeAccuracy), "function",
    "timed before the accuracy roll, so the theft happens even on a miss")

  local user = { name = "USER", stages = { attack = 1 }, mon = {} }
  local target = { name = "TARGET",
    stages = { attack = 2, defense = -1, speed = 0, special = 3,
               accuracy = 1, evasion = 0 }, mon = {} }
  local ctx = fakeCtx({ user = user, target = target })
  record.beforeAccuracy(ctx)

  T.eq(user.stages.attack, 3, "positive Attack (2) is added onto the user's own (1)")
  T.eq(target.stages.attack, 0, "and zeroed on the target")
  T.eq(user.stages.defense, nil, "a NEGATIVE stage is never stolen")
  T.eq(target.stages.defense, -1, "and stays exactly where it was")
  T.eq(user.stages.speed, nil, "a stage of exactly zero is nothing to steal")
  T.eq(user.stages.special, 3, "Special is stolen too")
  T.eq(target.stages.special, 0, "and zeroed")
  T.eq(user.stages.accuracy, 1, "so is accuracy")
  T.eq(user.stages.evasion, nil, "evasion at zero is left alone")

  -- Capped at +6, the same ceiling changeStage's own math.min/max enforces.
  local cappedUser = { name = "USER", stages = { attack = 5 }, mon = {} }
  local cappedTarget = { name = "TARGET", stages = { attack = 4 }, mon = {} }
  local cappedCtx = fakeCtx({ user = cappedUser, target = cappedTarget })
  record.beforeAccuracy(cappedCtx)
  T.eq(cappedUser.stages.attack, 6, "5 + 4 caps at 6 rather than reaching 9")

  -- No positive stage anywhere: no message, and the theft is a silent no-op.
  local flatUser = { name = "USER", stages = {}, mon = {} }
  local flatTarget = { name = "TARGET", stages = {}, mon = {} }
  local flatCtx, said = fakeCtx({ user = flatUser, target = flatTarget })
  record.beforeAccuracy(flatCtx)
  T.eq(#said, 0, "nothing is said when there was nothing to steal")
end

-- ---------------------------------------------------------------------
-- The refusal itself: named, with a reason, and reachable from the roster
-- rather than only from a comment nothing checks.
-- ---------------------------------------------------------------------
T.eq(#SBM.REFUSED, 1, "exactly one of the eleven is refused")
T.eq(SBM.REFUSED[1].crystal, "DECIDIUM_Z", "Decidium Z")
T.eq(SBM.REFUSED[1].move, "SPIRITSHACKLE", "over Spirit Shackle")
T.check(type(SBM.REFUSED[1].reason) == "string" and #SBM.REFUSED[1].reason > 0,
  "and the reason is recorded, not merely implied")

for _, row in ipairs(SBM.ROWS) do
  T.check(row.move ~= "SPIRITSHACKLE",
    "SPIRITSHACKLE never appears in the rows this file actually installs")
end

T.eq(#SBM.ROWS, 10, "ten of the eleven get a real row")

-- ---------------------------------------------------------------------
-- M.install through a stub mod: guarded, per-row and per-species.
-- ---------------------------------------------------------------------
local function stubMod(opts)
  opts = opts or {}
  local registered = { move_effects = {} }
  local patched = { moves = {}, pokemon = {} }
  local warned = {}
  local moveDefs = opts.moves or {}
  local speciesDefs = opts.species or {}
  return {
    content = {
      move_effects = {
        register = function(_, id, record) registered.move_effects[id] = record end,
      },
      moves = {
        get = function(_, id) return moveDefs[id] end,
        patch = function(_, id, partial)
          patched.moves[id] = patched.moves[id] or {}
          for k, v in pairs(partial) do patched.moves[id][k] = v end
        end,
      },
      pokemon = {
        get = function(_, id) return speciesDefs[id] end,
        patch = function(_, id, partial)
          patched.pokemon[id] = patched.pokemon[id] or { learnset = { __append = {} } }
          for _, row in ipairs(partial.learnset.__append) do
            table.insert(patched.pokemon[id].learnset.__append, row)
          end
        end,
      },
    },
    log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
    registered = registered, patched = patched, warned = warned,
  }
end

-- Every base move and every species this file's ROWS name, present: all ten
-- rows go through cleanly.
local function fullMoves()
  local out = {}
  for _, row in ipairs(SBM.ROWS) do
    out[row.move] = { id = row.move, power = 90, type = "NORMAL" }
  end
  return out
end

local function fullSpecies()
  local out = {}
  for _, row in ipairs(SBM.ROWS) do
    for _, species in ipairs(row.species) do
      out[species] = { id = species, learnset = {} }
    end
  end
  return out
end

do
  local mod = stubMod({ moves = fullMoves(), species = fullSpecies() })
  SBM.install(mod)

  T.eq(#mod.warned, 0, "nothing to warn about when every base exists")

  -- The six custom effects register.
  for _, id in ipairs({ "BATTLE_FORMS_VOLT_TACKLE_EFFECT",
      "BATTLE_FORMS_DARKEST_LARIAT_EFFECT", "BATTLE_FORMS_SPARKLING_ARIA_EFFECT",
      "BATTLE_FORMS_PLAY_ROUGH_EFFECT", "BATTLE_FORMS_CLANGING_SCALES_EFFECT",
      "BATTLE_FORMS_SPECTRAL_THIEF_EFFECT" }) do
    T.check(mod.registered.move_effects[id] ~= nil, id .. " is registered")
  end

  T.eq(mod.patched.moves.VOLTTACKLE.effect, "BATTLE_FORMS_VOLT_TACKLE_EFFECT",
    "VOLTTACKLE points at its own effect")
  T.eq(mod.patched.moves.VOLTTACKLE.effectModeled, true, "and is flagged modelled")

  T.eq(mod.patched.moves.GIGAIMPACT.effect, "HYPER_BEAM_EFFECT",
    "GIGAIMPACT points at the engine's own native effect")
  T.check(mod.registered.move_effects.HYPER_BEAM_EFFECT == nil,
    "and this file never registers a copy of it")

  T.eq(mod.patched.moves.STONEEDGE.highCrit, true, "STONEEDGE gets highCrit")
  T.eq(mod.patched.moves.STONEEDGE.effect, nil,
    "and no effect id at all -- there is no handler to point at")
  T.eq(mod.patched.moves.STONEEDGE.effectModeled, true, "but is still flagged modelled")

  T.eq(mod.patched.moves.SUNSTEELSTRIKE.effectModeled, true,
    "SUNSTEELSTRIKE is flagged modelled on plain damage alone")
  T.eq(mod.patched.moves.SUNSTEELSTRIKE.effect, nil, "with no effect id patched in")

  T.eq(mod.patched.pokemon.PIKACHU.learnset.__append[1].move, "VOLTTACKLE",
    "PIKACHU is taught VOLTTACKLE")
  T.eq(mod.patched.pokemon.PIKACHU.learnset.__append[1].level, 1, "at level 1")

  for _, species in ipairs({ "LYCANROC", "LYCANROC_MIDNIGHT", "LYCANROC_DUSK" }) do
    T.eq(mod.patched.pokemon[species].learnset.__append[1].move, "STONEEDGE",
      species .. " is taught STONEEDGE too")
  end

  T.eq(mod.patched.moves.SPIRITSHACKLE, nil,
    "SPIRITSHACKLE is never patched -- it is not one of this file's rows")
  T.eq(mod.patched.pokemon.DECIDUEYE, nil, "and DECIDUEYE is never taught anything")
end

-- Bound to Gen 2: the identical learnset/levelMoves field bug
-- src/dragonascent.lua carried through 0.53.0, and the identical fix --
-- national_dex's own src/gen2shape.lua strips `learnset` from every
-- species it reshapes on a Gold boot, so patching it there would silently
-- teach a field Mon.movesAtLevel never reads.
local function stubModGen2(opts)
  opts = opts or {}
  local patched = { pokemon = {} }
  local moveDefs = opts.moves or {}
  local speciesDefs = opts.species or {}
  return {
    content = {
      move_effects = { register = function() end },
      moves = {
        get = function(_, id) return moveDefs[id] end,
        patch = function() end,
      },
      pokemon = {
        get = function(_, id) return speciesDefs[id] end,
        patch = function(_, id, partial) patched.pokemon[id] = partial end,
      },
    },
    log = { warn = function() end },
    patched = patched,
  }
end

do
  SBM.bind({ gen2 = true })
  local mod = stubModGen2({ moves = fullMoves(), species = fullSpecies() })
  SBM.install(mod)
  SBM.bind(nil)

  local levelMovesPatch = mod.patched.pokemon.PIKACHU.levelMoves
  T.check(levelMovesPatch ~= nil,
    "PIKACHU's Gen 2 levelMoves is patched, not learnset")
  T.eq(levelMovesPatch.__append[1].move, "VOLTTACKLE",
    "still teaching VOLTTACKLE")
  T.eq(levelMovesPatch.__append[1].level, 1, "at the same level as Gen 1")
  T.eq(mod.patched.pokemon.PIKACHU.learnset, nil,
    "and nothing is patched onto the Gen 1 field name on a Gen 2 load")
end

-- A move missing entirely: that row's species are never taught, and it says
-- so once, naming the move -- the same degrade src/dragonascent.lua's own
-- suite pins for a missing DRAGONASCENT.
do
  local moves = fullMoves()
  moves.VOLTTACKLE = nil
  local mod = stubMod({ moves = moves, species = fullSpecies() })
  SBM.install(mod)

  T.eq(mod.patched.moves.VOLTTACKLE, nil, "no move base, no patch")
  T.eq(mod.patched.pokemon.PIKACHU, nil, "and no teaching either")
  T.check(mod.registered.move_effects.BATTLE_FORMS_VOLT_TACKLE_EFFECT == nil,
    "nor is its effect registered")

  local sawWarning = false
  for _, msg in ipairs(mod.warned) do
    if msg:find("VOLTTACKLE", 1, true) then sawWarning = true end
  end
  T.check(sawWarning, "the missing move is named in the warning")

  -- Every OTHER row is unaffected.
  T.eq(mod.patched.moves.GIGAIMPACT.effect, "HYPER_BEAM_EFFECT",
    "a sibling row with its own base present still goes through")
end

-- A species missing (Lycanroc's Midnight forme, say NATIONAL DEX split it
-- from the other two): the move is still patched, the other two formes are
-- still taught, and only the missing one is refused and named.
do
  local species = fullSpecies()
  species.LYCANROC_MIDNIGHT = nil
  local mod = stubMod({ moves = fullMoves(), species = species })
  SBM.install(mod)

  T.check(mod.patched.moves.STONEEDGE ~= nil, "the move patch still goes ahead")
  T.check(mod.patched.pokemon.LYCANROC ~= nil, "the base forme is still taught")
  T.check(mod.patched.pokemon.LYCANROC_DUSK ~= nil, "so is the other forme")
  T.eq(mod.patched.pokemon.LYCANROC_MIDNIGHT, nil,
    "but the missing forme is never patched")

  local sawWarning = false
  for _, msg in ipairs(mod.warned) do
    if msg:find("LYCANROC_MIDNIGHT", 1, true) then sawWarning = true end
  end
  T.check(sawWarning, "and it is named in the warning")
end

-- Every base missing at once: every row refuses, and nothing throws.
do
  local mod = stubMod({})
  SBM.install(mod)
  T.eq(next(mod.patched.moves), nil, "no move base survives means no patches at all")
  T.eq(next(mod.patched.pokemon), nil, "and nothing is taught")
  T.eq(#mod.warned, #SBM.ROWS, "every row warns exactly once, for its missing move")
end

-- ---------------------------------------------------------------------
-- Through the real loader: national_dex registers all ten base moves plus
-- every species they teach, PLUS SPIRITSHACKLE and DECIDUEYE (the eleventh
-- pairing this file refuses) -- and battle_forms loaded for real behind it,
-- so the merged registries are read back the way the game would see them,
-- with the refusal proven by absence rather than assumed.
-- ---------------------------------------------------------------------
do
  local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local body = handle:read("*a")
    handle:close()
    return body
  end

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
    if name == "src/speciesbasemoves.lua" then ok = true end
  end
  T.check(ok, "src/speciesbasemoves.lua is one of the files main.lua actually loads")

  local function moveRow(id, type_, power, category)
    return ('  mod.content.moves:register("%s", { id = "%s", name = "%s", '
      .. 'type = "%s", power = %d, accuracy = 100, pp = 10, category = "%s", '
      .. 'effect = "NO_ADDITIONAL_EFFECT", effectModeled = false })\n')
      :format(id, id, id, type_, power, category)
  end

  local function speciesRow(id)
    return ('  mod.content.pokemon:register("%s", { id = "%s", name = "%s", '
      .. 'dex = 1, types = { "NORMAL" }, baseStats = { hp = 80, attack = 80, '
      .. 'defense = 80, speed = 80, special = 80 }, catchRate = 45, '
      .. 'baseExp = 100, growthRate = "MEDIUM_FAST", level1Moves = {}, '
      .. 'learnset = {}, evolutions = {}, '
      .. 'spriteFront = "assets/sets/placeholder/front.png", '
      .. 'spriteBack = "assets/sets/placeholder/back.png", frontSize = 5 })\n')
      :format(id, id, id)
  end

  local body = "return function(mod)\n"
  for _, row in ipairs(SBM.ROWS) do
    body = body .. moveRow(row.move, "NORMAL", 90, "physical")
    for _, species in ipairs(row.species) do
      body = body .. speciesRow(species)
    end
  end
  -- The refused pairing: registered too, so its absence from the merge is
  -- proof the refusal held rather than an accident of it never existing.
  body = body .. moveRow("SPIRITSHACKLE", "GHOST", 80, "physical")
  body = body .. speciesRow("DECIDUEYE")
  body = body .. "end\n"

  local files = {
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = body,
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
    fs = T.sdk.memfs(files), data = T.fixtures.fresh(),
  })
  T.eq(#run.errors, 0, "the mod loads clean against a real roster of all eleven pairings")

  for _, row in ipairs(SBM.ROWS) do
    local move = run.data.moves[row.move]
    T.check(move ~= nil, row.move .. " survived the merge")
    T.eq(move.effectModeled, true, row.move .. " is flagged honestly modelled")
    for _, species in ipairs(row.species) do
      local record = run.data.pokemon[species]
      T.check(record ~= nil, species .. " survived the merge")
      local taught = false
      for _, learn in ipairs(record.learnset) do
        if learn.move == row.move then taught = true end
      end
      T.check(taught, species .. " is taught " .. row.move .. " through the real loader")
    end
  end

  -- GIGAIMPACT specifically resolves to the engine's own native effect
  -- record, proving the repoint reaches an id this mod never registered.
  local gigaImpact = run.data.moves.GIGAIMPACT
  T.eq(gigaImpact.effect, "HYPER_BEAM_EFFECT", "GIGAIMPACT points at Hyper Beam's own")
  local hyperBeamRecord = run.data.move_effects.HYPER_BEAM_EFFECT
  T.check(hyperBeamRecord ~= nil,
    "and that id resolves to a real record in the merged move_effects registry")
  T.check(type(hyperBeamRecord.afterDamage) == "function",
    "the engine's own native recharge handler, not a stand-in for it")

  -- The refusal: proven by absence through the real merge, not asserted
  -- against a stub of this mod's own patches.
  local spiritShackle = run.data.moves.SPIRITSHACKLE
  T.check(spiritShackle ~= nil, "SPIRITSHACKLE itself still survived the merge -- "
    .. "national_dex registered it, this mod simply never touches it")
  T.eq(spiritShackle.effectModeled, false,
    "and it is still flagged unmodelled, exactly as national_dex left it")
  T.eq(spiritShackle.effect, "NO_ADDITIONAL_EFFECT",
    "with no effect patched onto it")

  local decidueye = run.data.pokemon.DECIDUEYE
  T.check(decidueye ~= nil, "DECIDUEYE survived the merge too")
  T.eq(#decidueye.learnset, 0,
    "but was taught nothing -- Decidium Z stays exactly as unreachable as it "
      .. "was before this version")
end

T.finish("battle_forms_speciesbasemoves")
