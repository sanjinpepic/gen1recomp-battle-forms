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

-- ---------------------------------------------------------------------
-- Item 1(a): the crash-risk class.  On Gen 2, VOLTTACKLE, SPARKLINGARIA,
-- PLAYROUGH and CLANGINGSCALES must NOT patch `effect` at all -- the
-- identical exemption src/dragonascent.lua's own M.install established for
-- Dragon Ascent, verified here by DELIBERATE BREAKAGE: if M.install ever
-- regressed to patching `effect` on Gen 2 for one of these four the way it
-- always has for Gen 1, this block would see a non-nil `effect` and fail.
--
-- Item 1(b): GIGAIMPACT and STONEEDGE repoint at Gold's own differently-
-- named mechanism instead (a raw string comparison in
-- game/src/battle/gen2/Battle.lua, not a move_effects record at all --
-- see M.ROWS' own header).
--
-- Item 1(c): DARKESTLARIAT and SPECTRALTHIEF are refused outright on Gen 2
-- -- no patch, no teaching, named in a warning -- because Gold's dispatch
-- never calls chooseDamage or beforeAccuracy at all.
--
-- Tracks BOTH move patches (unlike stubModGen2 above, which only tracks
-- species patches) and species patches generically (unlike stubMod above,
-- which hardcodes the Gen 1 `learnset` field and would error reading
-- `partial.learnset.__append` off a Gen 2 `levelMoves` patch).
-- ---------------------------------------------------------------------
local function stubModGen2Tracked(opts)
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
        patch = function(_, id, partial) patched.pokemon[id] = partial end,
      },
    },
    log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
    registered = registered, patched = patched, warned = warned,
  }
end

do
  SBM.bind({ gen2 = true })
  local mod = stubModGen2Tracked({ moves = fullMoves(), species = fullSpecies() })
  SBM.install(mod)
  SBM.bind(nil)

  -- The crash-risk class: effectModeled stays honest (the effect genuinely
  -- applies, through battle.damage_dealt), but `effect` is left untouched.
  for _, move in ipairs({ "VOLTTACKLE", "SPARKLINGARIA", "PLAYROUGH",
                          "CLANGINGSCALES" }) do
    T.eq(mod.patched.moves[move].effect, nil,
      move .. " gets no effect patch on Gen 2 -- Gold's dispatch must find "
        .. "nothing registered under its id or the registered run handler "
        .. "would fire before the accuracy roll and crash, the identical "
        .. "hazard src/dragonascent.lua's own 0.55.0 fix closed")
    T.eq(mod.patched.moves[move].effectModeled, true,
      move .. " is still honestly flagged modelled -- the effect DOES "
        .. "apply on Gen 2, just through battle.damage_dealt")
  end

  -- The two repointed rows: a DIFFERENT id from Gen 1's own, matching
  -- exactly what Gold's engine reads by direct string comparison.
  T.eq(mod.patched.moves.GIGAIMPACT.effect, "EFFECT_HYPER_BEAM",
    "GIGAIMPACT points at Gold's own literal, not Gen 1's HYPER_BEAM_EFFECT")
  T.eq(mod.patched.moves.STONEEDGE.effect, "EFFECT_ALWAYS_CRIT",
    "STONEEDGE points at Gold's own crit-ladder literal")
  T.eq(mod.patched.moves.STONEEDGE.highCrit, nil,
    "and no longer patches the highCrit field Gold never reads")
  T.eq(mod.patched.moves.GIGAIMPACT.effectModeled, true,
    "GIGAIMPACT is still flagged modelled -- the recharge genuinely works")
  T.eq(mod.patched.moves.STONEEDGE.effectModeled, true,
    "so is STONEEDGE -- the high crit ratio genuinely works")

  -- The two refused rows: no patch at all, and never taught.
  for _, entry in ipairs({ { move = "DARKESTLARIAT", species = "INCINEROAR" },
                           { move = "SPECTRALTHIEF", species = "MARSHADOW" } }) do
    T.eq(mod.patched.moves[entry.move], nil,
      entry.move .. " is never patched on Gen 2 -- refused outright")
    T.eq(mod.patched.pokemon[entry.species], nil,
      entry.species .. " is taught nothing on Gen 2 -- the identical "
        .. "treatment SPIRITSHACKLE gets on both games")
    local sawWarning = false
    for _, msg in ipairs(mod.warned) do
      if msg:find(entry.move, 1, true) then sawWarning = true end
    end
    T.check(sawWarning, "the refusal names " .. entry.move .. " in a warning")
  end

  -- SUNSTEELSTRIKE and MOONGEISTBEAM: unaffected -- confirmed, not assumed.
  for _, move in ipairs({ "SUNSTEELSTRIKE", "MOONGEISTBEAM" }) do
    T.eq(mod.patched.moves[move].effect, nil,
      move .. " still carries no effect id on Gen 2, exactly as on Gen 1")
    T.eq(mod.patched.moves[move].effectModeled, true,
      move .. " is still flagged modelled on plain damage alone")
  end

  -- The custom effect records for the crash-risk class still register --
  -- an id nothing on Gold's own dispatch ever finds is a harmless dead
  -- entry, the same reasoning src/dragonascent.lua's own M.install gives.
  for _, id in ipairs({ "BATTLE_FORMS_VOLT_TACKLE_EFFECT",
      "BATTLE_FORMS_SPARKLING_ARIA_EFFECT", "BATTLE_FORMS_PLAY_ROUGH_EFFECT",
      "BATTLE_FORMS_CLANGING_SCALES_EFFECT" }) do
    T.check(mod.registered.move_effects[id] ~= nil,
      id .. " is still registered on Gen 2")
  end
  -- DARKESTLARIAT and SPECTRALTHIEF's own records are never registered on
  -- Gen 2 either -- there is no point registering a record for a move this
  -- run never patches or teaches.
  T.check(mod.registered.move_effects.BATTLE_FORMS_DARKEST_LARIAT_EFFECT == nil,
    "DARKESTLARIAT's own record is not registered on a refused Gen 2 row")
  T.check(mod.registered.move_effects.BATTLE_FORMS_SPECTRAL_THIEF_EFFECT == nil,
    "neither is SPECTRALTHIEF's")
end

-- ---------------------------------------------------------------------
-- M.onDamageDealt: the real Gen 2 mechanism for the crash-risk class,
-- driven against a fake Battle carrying only the fields
-- game/src/battle/gen2/Battle.lua actually exposes as instance methods
-- (emit, monName, sideOf, random, applyStatus, changeStage, volatile) --
-- the same fidelity tests/battle_forms_dragonascent_test.lua's own fake
-- ctx holds itself to for Gen 1.
-- ---------------------------------------------------------------------
local function fakeGen2Battle(opts)
  opts = opts or {}
  local emitted, applied = {}, {}
  local rngQueue = opts.rng or { 255 } -- default: every chance roll misses
  local rngIndex = 0
  local volatiles = {}
  return {
    emit = function(_, ev) emitted[#emitted + 1] = ev end,
    monName = function(_, mon) return mon.name or "MON" end,
    sideOf = function(_, mon) return mon.side or "player" end,
    random = function(n)
      rngIndex = rngIndex + 1
      local v = rngQueue[rngIndex] or rngQueue[#rngQueue] or (n - 1)
      return v
    end,
    applyStatus = function(_, mon, status)
      applied[#applied + 1] = { mon = mon, status = status }
      if mon.status then return false end
      mon.status = status
      return true
    end,
    changeStage = function(_, mon, stat, delta)
      mon.stages = mon.stages or {}
      mon.stages[stat] = (mon.stages[stat] or 0) + delta
    end,
    volatile = function(_, mon)
      volatiles[mon] = volatiles[mon] or {}
      return volatiles[mon]
    end,
  }, emitted, applied, volatiles
end

-- The outer gate: nothing runs unless bound to Gen 2, the target survived
-- and real damage was dealt -- the identical two-part gate Gen 1's own
-- EffectRegistry.lua applies to every "secondary" effect and
-- src/dragonascent.lua's own onDamageDealt already carries.
do
  local battle, emitted = fakeGen2Battle()
  local user = { name = "USER", hp = 100 }
  local target = { name = "TARGET", hp = 100 }

  SBM.bind(nil)
  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "VOLTTACKLE", damage = 90 })
  T.eq(user.hp, 100, "unbound from Gen 2, onDamageDealt does nothing at all")

  SBM.bind({ gen2 = true })
  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "VOLTTACKLE", damage = 0 })
  T.eq(user.hp, 100, "zero damage dealt: no recoil, no roll")

  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "VOLTTACKLE" })
  T.eq(user.hp, 100, "no damage field at all: refused, not treated as zero")

  local fainted = { name = "TARGET", hp = 0 }
  SBM.onDamageDealt({ battle = battle, user = user, target = fainted,
    moveId = "VOLTTACKLE", damage = 90 })
  T.eq(user.hp, 100, "a fainted target: no recoil either, matching Gen 1's "
    .. "own kind == \"secondary\" gate")

  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "SOMEUNRELATEDMOVE", damage = 90 })
  T.eq(user.hp, 100, "an unrelated move id is left alone entirely")
  SBM.bind(nil)
end

-- VOLT TACKLE: recoil always lands on a real hit; paralysis only on the
-- 26/256 roll, on the TARGET, through the real applyStatus primitive.
do
  local battle = fakeGen2Battle({ rng = { 0 } })
  local user = { name = "USER", hp = 100 }
  local target = { name = "TARGET", hp = 100 }
  SBM.bind({ gen2 = true })
  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "VOLTTACKLE", damage = 90 })
  T.eq(user.hp, 70, "recoil is one third of 90 damage dealt, off the USER")
  T.eq(target.status, "paralyze", "a roll under 26 paralyzes the TARGET, "
    .. "Gold's own spelling of the status")
  SBM.bind(nil)
end

do
  local battle = fakeGen2Battle({ rng = { 255 } })
  local user = { name = "USER", hp = 100 }
  local target = { name = "TARGET", hp = 100 }
  SBM.bind({ gen2 = true })
  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "VOLTTACKLE", damage = 5 })
  T.eq(user.hp, 99, "5 damage dealt never floors recoil to zero (1 minimum)")
  T.eq(target.status, nil, "a roll of 255 (>= 26) never paralyzes")
  SBM.bind(nil)
end

-- SPARKLING ARIA: cures a burn unconditionally, leaves every other status
-- (or no status) alone.
do
  local battle = fakeGen2Battle()
  local user = { name = "USER", hp = 100 }
  local burned = { name = "TARGET", hp = 100, status = "burn" }
  SBM.bind({ gen2 = true })
  SBM.onDamageDealt({ battle = battle, user = user, target = burned,
    moveId = "SPARKLINGARIA", damage = 40 })
  T.eq(burned.status, nil, "a burned target is cured")

  local poisoned = { name = "TARGET", hp = 100, status = "poison" }
  SBM.onDamageDealt({ battle = battle, user = user, target = poisoned,
    moveId = "SPARKLINGARIA", damage = 40 })
  T.eq(poisoned.status, "poison", "a poisoned target keeps its own status")
  SBM.bind(nil)
end

-- PLAY ROUGH: a 10% chance to drop the target's Attack, refused outright
-- behind a live Substitute -- read off `battle:volatile`, the same field
-- Gold's own dealDamage checks for the identical mechanic.
do
  local battle = fakeGen2Battle({ rng = { 0 } })
  local user = { name = "USER", hp = 100 }
  local target = { name = "TARGET", hp = 100 }
  SBM.bind({ gen2 = true })
  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "PLAYROUGH", damage = 40 })
  T.eq(target.stages.attack, -1, "a roll under 26 drops Attack one stage")

  local subVolBattle, _, _, volatiles = fakeGen2Battle({ rng = { 0 } })
  local subTarget = { name = "TARGET", hp = 100 }
  volatiles[subTarget] = { substitute = 20 }
  SBM.onDamageDealt({ battle = subVolBattle, user = user, target = subTarget,
    moveId = "PLAYROUGH", damage = 40 })
  T.eq(subTarget.stages, nil,
    "a target behind a live Substitute is never touched, even on a landing roll")
  SBM.bind(nil)
end

-- CLANGING SCALES: unconditional self Defense drop, no roll at all.
do
  local battle = fakeGen2Battle({ rng = { 255 } })
  local user = { name = "USER", hp = 100 }
  local target = { name = "TARGET", hp = 100 }
  SBM.bind({ gen2 = true })
  SBM.onDamageDealt({ battle = battle, user = user, target = target,
    moveId = "CLANGINGSCALES", damage = 30 })
  T.eq(user.stages.defense, -1,
    "the USER's own Defense falls one stage, unconditionally -- a maximal "
      .. "roll (255) changes nothing because no roll is ever made")
  T.eq(target.stages, nil, "the target is never touched")
  SBM.bind(nil)
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

-- ---------------------------------------------------------------------
-- The end-to-end proof, Gen 2: the REAL M.install output driven through
-- Gold's REAL Battle:useMove dispatch (game/src/battle/gen2/Battle.lua),
-- the identical technique tests/battle_forms_dragonascent_test.lua's own
-- tail uses for DRAGONASCENT.  Before this version's fix, VOLTTACKLE's own
-- patched `effect` pointed at a registered handler carrying `run`, and
-- Gold's dispatch (`local handler = effectRecord and effectRecord.run; if
-- handler then handler(self, attacker, defender, def, moveId, sureHit);
-- return end`) would call it with Gold's own positional arguments instead
-- of the Gen 1 ctx table `run` is built for -- `ctx.rng`/`ctx.inflict`
-- answer nil on that shape and the resulting call errors outright, the
-- identical crash Dragon Ascent's own 0.54.0 report already proved for the
-- identical reason.  This block proves the crash is gone AND that the real
-- mechanism (recoil, paralysis, recharge) actually applies through
-- battle.damage_dealt.
-- ---------------------------------------------------------------------
do
  local RealBattle = require("src.battle.gen2.Battle")
  local RealMon = require("src.battle.gen2.Mon")
  local Runtime = require("src.mods.Runtime")

  local BASE_VOLTTACKLE = { id = "VOLTTACKLE", name = "Volt Tackle",
    power = 120, accuracy = 100, pp = 15, category = "physical",
    type = "ELECTRIC", effect = "EFFECT_NORMAL_HIT" }
  local BASE_GIGAIMPACT = { id = "GIGAIMPACT", name = "Giga Impact",
    power = 150, accuracy = 90, pp = 5, category = "physical",
    type = "NORMAL", effect = "EFFECT_NORMAL_HIT" }

  local patched = { moves = {} }
  local installMod = {
    content = {
      move_effects = { register = function() end },
      moves = {
        get = function(_, id)
          if id == "VOLTTACKLE" then return BASE_VOLTTACKLE end
          if id == "GIGAIMPACT" then return BASE_GIGAIMPACT end
          return nil
        end,
        patch = function(_, id, partial) patched.moves[id] = partial end,
      },
      pokemon = { get = function() return nil end, patch = function() end },
    },
  }
  SBM.bind({ gen2 = true })
  SBM.install(installMod)
  SBM.bind(nil)

  -- VOLTTACKLE must come back with no `effect` patch at all -- proof the
  -- real M.install output, not a hand-picked id, is what reaches Gold's
  -- dispatch with nothing registered under it.
  T.eq(patched.moves.VOLTTACKLE and patched.moves.VOLTTACKLE.effect, nil,
    "the real M.install output patches no effect onto VOLTTACKLE on Gen 2")
  T.eq(patched.moves.GIGAIMPACT.effect, "EFFECT_HYPER_BEAM",
    "and the real output repoints GIGAIMPACT at Gold's own literal")

  local function effective(base, id)
    local p = patched.moves[id]
    return (p and p.effect) or base.effect
  end

  local TYPES = {
    ELECTRIC = { id = "ELECTRIC", index = 12, category = "special" },
    NORMAL = { id = "NORMAL", index = 0, category = "physical" },
  }
  local data = {
    pokemon = {
      growthRates = { GROWTH_MEDIUM_FAST = { numerator = 1, denominator = 1,
        squared = 0, linear = 0, constant = 0 } },
      -- Overtuned defensively, the same reason SNORLAX below is: PIKACHU is
      -- also the GIGAIMPACT block's own defending target, and a one-hit KO
      -- there would satisfy the recharge check's own gate by accident
      -- rather than proving the recharge volatile is genuinely set.  Its own
      -- role as VOLTTACKLE's attacker never reads these defensive numbers.
      PIKACHU = { id = "PIKACHU", name = "PIKACHU",
        baseStats = { hp = 400, attack = 55, defense = 400, speed = 90,
          specialAttack = 50, specialDefense = 400 },
        types = { "ELECTRIC", "ELECTRIC" }, growthRate = "GROWTH_MEDIUM_FAST" },
      -- Overtuned defensively so a 120-power STAB Volt Tackle cannot one-hit
      -- it -- the recoil/paralysis gate below has to see a REAL survivor,
      -- not an accidental KO.
      SNORLAX = { id = "SNORLAX", name = "SNORLAX",
        baseStats = { hp = 500, attack = 110, defense = 400, speed = 30,
          specialAttack = 65, specialDefense = 400 },
        types = { "NORMAL", "NORMAL" }, growthRate = "GROWTH_MEDIUM_FAST" },
    },
    moves = {
      VOLTTACKLE = { id = "VOLTTACKLE", name = "Volt Tackle", power = 120,
        accuracy = 100, pp = 15, category = "physical", type = "ELECTRIC",
        effect = effective(BASE_VOLTTACKLE, "VOLTTACKLE") },
      GIGAIMPACT = { id = "GIGAIMPACT", name = "Giga Impact", power = 150,
        accuracy = 90, pp = 5, category = "physical", type = "NORMAL",
        effect = effective(BASE_GIGAIMPACT, "GIGAIMPACT") },
    },
    type_chart = { types = TYPES, matchups = {} },
    items = {},
    -- The merged registry the real loader would build, carrying this file's
    -- own record under its own id regardless of whether anything points at
    -- it -- M.install registers it unconditionally, exactly as
    -- src/dragonascent.lua's own does.
    gen2MoveEffects = {
      [SBM.PREFIX .. "VOLT_TACKLE_EFFECT"] = SBM.voltTackleEffect(),
    },
  }

  local perfect = { attack = 15, defense = 15, speed = 15, special = 15 }
  perfect.hp = RealMon.hpDV(perfect)
  local player = RealMon.new(data, "PIKACHU", 50,
    { dvs = perfect, moves = { { id = "VOLTTACKLE", pp = 15, maxPp = 15 } } })
  local foe = RealMon.new(data, "SNORLAX", 50, { dvs = perfect, moves = {} })

  local received = {}
  local FakeEvents = { listeners = { ["battle.damage_dealt"] = true } }
  function FakeEvents:emit(name, payload)
    if name == "battle.damage_dealt" then
      received[#received + 1] = payload
      SBM.onDamageDealt(payload)
    end
  end
  local savedEvents, savedHooks = Runtime.events, Runtime.hooks
  Runtime.install(FakeEvents, Runtime.hooks, {})
  SBM.bind({ gen2 = true })

  local ok, battle = pcall(function()
    local b = RealBattle.new({ data = data, party = { player }, wild = foe,
      random = function() return 0 end })
    b:useMove(player, foe, "VOLTTACKLE")
    return b
  end)

  T.check(ok, "VOLTTACKLE's real dispatch runs without erroring: "
    .. tostring(battle))
  if ok then
    T.eq(player.moves[1].pp, 14, "Volt Tackle still spends its own PP")
    T.check(foe.hp < foe.maxHp, "and deals real damage through the ordinary "
      .. "accuracy-then-damage path -- nothing short-circuited it")
    T.check(foe.hp > 0, "the target survives, so the recoil/paralysis gate "
      .. "below is not merely satisfied by a one-hit KO")
    T.eq(#received, 1, "battle.damage_dealt fired once, off the real hit")
    T.check(player.hp < player.maxHp,
      "and the real recoil landed on the real attacker's own HP, through "
        .. "M.onDamageDealt rather than the crashed early-dispatch path")
    T.eq(foe.status, "paralyze",
      "and the real 26/256 roll (forced to land, random always 0) "
        .. "paralyzed the real target through battle:applyStatus")
  end

  -- GIGAIMPACT: a fresh battle, same real classes -- the recharge volatile
  -- Gold's own next-turn check reads (Battle.lua's own `if vol.recharge
  -- then ... end`), set only by the direct string comparison this mod's
  -- repoint now satisfies.
  local attacker = RealMon.new(data, "SNORLAX", 50,
    { dvs = perfect, moves = { { id = "GIGAIMPACT", pp = 5, maxPp = 5 } } })
  local target = RealMon.new(data, "PIKACHU", 50, { dvs = perfect, moves = {} })
  local okGiga, gigaBattle = pcall(function()
    local b = RealBattle.new({ data = data, party = { attacker }, wild = target,
      random = function() return 0 end })
    b:useMove(attacker, target, "GIGAIMPACT")
    return b
  end)
  Runtime.install(savedEvents, savedHooks, nil)
  SBM.bind(nil)

  T.check(okGiga, "GIGAIMPACT's real dispatch runs without erroring: "
    .. tostring(gigaBattle))
  if okGiga then
    T.check(target.hp < target.maxHp, "Giga Impact deals real damage")
    T.check(target.hp > 0, "the target survives -- the recharge check below "
      .. "is not merely reached by a KO's own early return")
    local vol = gigaBattle:volatile(attacker)
    T.eq(vol.recharge, true,
      "and the real EFFECT_HYPER_BEAM string comparison set the real "
        .. "recharge volatile Gold's own next-turn check reads -- the "
        .. "recharge genuinely applies, not merely the damage")
  end

  -- STONEEDGE: the real Damage.criticalLevel, spied on through the real
  -- Battle:hitOnce dispatch -- proof that patching `effect =
  -- "EFFECT_ALWAYS_CRIT"` genuinely reaches Gold's own crit-ladder rule
  -- (highCritMove raising it two rungs, Damage.CRITICAL_CHANCES[2] == 4)
  -- rather than the `highCrit` move-record field Gold never reads at all.
  if ok then
    local Damage = require("src.battle.gen2.Damage")
    local realCriticalLevel = Damage.criticalLevel
    local seenHighCrit
    Damage.criticalLevel = function(opts)
      seenHighCrit = opts.highCritMove
      return realCriticalLevel(opts)
    end
    local okCrit = pcall(function()
      battle:hitOnce(player, foe,
        { id = "STONEEDGE", type = "NORMAL", power = 80,
          effect = "EFFECT_ALWAYS_CRIT" }, {})
    end)
    Damage.criticalLevel = realCriticalLevel
    T.check(okCrit, "STONEEDGE's real hitOnce dispatch runs without erroring")
    T.eq(seenHighCrit, true,
      "and EFFECT_ALWAYS_CRIT genuinely reaches Damage.criticalLevel as "
        .. "highCritMove -- the real +2 crit-ladder rungs, not a value "
        .. "read off a highCrit field nothing in Battle.lua consults")
  end
end

-- ---------------------------------------------------------------------
-- DARKESTLARIAT and SPECTRALTHIEF, through the real loader on Gen 2: never
-- patched, never taught -- proven by absence through the real merge, the
-- same discipline the Gen 1 block above holds SPIRITSHACKLE to.
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

  local function moveRow(id, type_, power, category)
    return ('  mod.content.moves:register("%s", { id = "%s", name = "%s", '
      .. 'type = "%s", power = %d, accuracy = 100, pp = 10, category = "%s", '
      .. 'effect = "NO_ADDITIONAL_EFFECT", effectModeled = false })\n')
      :format(id, id, id, type_, power, category)
  end

  local function speciesRow(id)
    return ('  mod.content.pokemon:register("%s", { id = "%s", name = "%s", '
      .. 'dex = 1, types = { "NORMAL" }, baseStats = { hp = 80, attack = 80, '
      .. 'defense = 80, speed = 80, special = 80, specialAttack = 80, '
      .. 'specialDefense = 80 }, catchRate = 45, '
      .. 'baseExp = 100, growthRate = "MEDIUM_FAST", levelMoves = {}, '
      .. 'evolutions = {}, '
      .. 'spriteFront = "assets/sets/placeholder/front.png", '
      .. 'spriteBack = "assets/sets/placeholder/back.png", picSize = 5 })\n')
      :format(id, id, id)
  end

  local body = "return function(mod)\n"
  for _, row in ipairs(SBM.ROWS) do
    body = body .. moveRow(row.move, "NORMAL", 90, "physical")
    for _, species in ipairs(row.species) do
      body = body .. speciesRow(species)
    end
  end
  body = body .. "end\n"

  local files = {
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0",'
        .. '"entry":"main.lua","games":["gen1","gen2"]}',
    ["mods/national_dex/main.lua"] = body,
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end

  local data = T.fixtures.fresh()
  data.gen2Constants = { generation = 2 }
  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" },
    { fs = T.sdk.memfs(files), data = data, generation = 2 })
  for _, err in ipairs(run.errors) do
    T.check(err:find("unresolved reference to move_effects", 1, true) ~= nil
      or err:find("text_pointers registry has no Gen 2 target", 1, true) ~= nil
      -- HANDOFF.md's own documented gap: Schemas.GEN1 gates six registries
      -- and growth_rates is not among them, so a fixture species (this
      -- block's own INCINEROAR/MARSHADOW/PIKACHU/etc, none of which the
      -- real national_dex data ships in this synthetic mod) naming a
      -- growth rate this synthetic stub never registers is flagged the
      -- same way -- unrelated to this row's own effect wiring.
      or err:find("unresolved reference to growth_rates", 1, true) ~= nil,
      "every load error is one of the three known Gen 2 gaps, not a new one: "
        .. err)
  end

  local darkestLariat = run.data.moves.DARKESTLARIAT
  T.check(darkestLariat ~= nil,
    "DARKESTLARIAT itself still survived the merge -- national_dex "
      .. "registered it, this mod simply never patches it on Gen 2")
  T.eq(darkestLariat.effectModeled, false,
    "and is still flagged unmodelled, exactly as national_dex left it")
  local incineroar = run.data.pokemon.INCINEROAR
  T.check(incineroar ~= nil, "INCINEROAR survived the merge too")
  T.eq(#incineroar.levelMoves, 0,
    "but was taught nothing -- Incinium Z stays as unreachable on Gold as "
      .. "Decidium Z is on both games")

  local spectralThief = run.data.moves.SPECTRALTHIEF
  T.check(spectralThief ~= nil, "SPECTRALTHIEF itself still survived the merge")
  T.eq(spectralThief.effectModeled, false, "and is still flagged unmodelled")
  local marshadow = run.data.pokemon.MARSHADOW
  T.check(marshadow ~= nil, "MARSHADOW survived the merge too")
  T.eq(#marshadow.levelMoves, 0, "but was taught nothing on Gold")

  -- Every OTHER row's species IS taught, through the real merge -- the
  -- refusal is narrow, not a Gen 2-wide failure to teach anything at all.
  local pikachu = run.data.pokemon.PIKACHU
  T.check(pikachu ~= nil, "PIKACHU survived the merge")
  local taughtVoltTackle = false
  for _, learn in ipairs(pikachu.levelMoves) do
    if learn.move == "VOLTTACKLE" then taughtVoltTackle = true end
  end
  T.check(taughtVoltTackle,
    "and IS taught VOLTTACKLE through levelMoves, the real Gen 2 field")

  run.release()
end

T.finish("battle_forms_speciesbasemoves")
