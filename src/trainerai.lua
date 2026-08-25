-- Enemy trainers using the gimmicks the player has unlocked.
--
-- Every manual transformation this mod adds was the player's alone: a trainer
-- with a Key Stone can mega evolve their ace and the gym leader across from
-- them never does. That makes the mod a difficulty REDUCTION and nothing else,
-- and leaves the big fights playing exactly as they did before it was
-- installed.
--
-- WHEN. The player's own key item is the clock. src/keyitems.lua already
-- models the outer tier the real games use -- a mega needs a Key Stone on the
-- TRAINER, a Dynamax rests on the Dynamax Band -- and holding one is already
-- what unlocks the player's access. So the enemy may use a gimmick exactly
-- when the player holds its key item: nothing new is tracked, the gate is per
-- gimmick rather than global, and it moves on its own if those items are ever
-- sold somewhere else.
--
-- WHO. Two tiers, and the engine already draws the line. Its own
-- data/scripts/ai_classes.lua holds eighteen records -- seven Kanto gym
-- leaders plus Giovanni, the Elite Four, Rivals 2 and 3, and four tough
-- ordinary classes -- and exists because those trainers get smarter move
-- choice and item use. Membership is the engine's own statement that a fight
-- is meant to be hard, so it is reused rather than a list of trainer names
-- being maintained here.
--
-- WHICH, and why the seed matters. Availability is very uneven: Tera and
-- Dynamax apply to every species, mega evolution to 86 of them. That sounds
-- like it makes a strict "best fit" safe and it does the opposite -- the Kanto
-- gym aces are precisely the species with famous megas, so best-fit would turn
-- every important fight into a mega evolution. The pick is a weighted roll
-- over what that Pokemon can actually do, seeded from the TRAINER'S ID rather
-- than from the battle RNG.
--
-- That seed is the whole point. A hard fight that does something different on
-- every attempt is arbitrary; one that always does the same thing is a puzzle,
-- and a player who lost to Blaine's Terastallization can come back knowing it
-- is coming. The variation lands ACROSS the roster rather than within one
-- trainer, and costs no authoring.
--
-- WHAT THIS NEVER TOUCHES, which is the part that would break quietly:
--
--   * src/arm.lua. Its State:consume(id) records the once-per-battle limit and
--     holds ONE flag for the battle, not one per side. An enemy activation
--     routed through it would spend the PLAYER'S allowance -- they arm their
--     mega, the gym leader goes first, and their cell is dead for the rest of
--     the fight. This module keeps its own flag instead.
--   * an entry's activate(). That is meant to run at battle.turn_started where
--     src/resolve.lua pairs it with consume; see src/formapi.lua's own note.
--
-- ONLY MEGA EVOLUTION IS WIRED, and the reason is worth stating plainly
-- because it is not obvious from the outside: of the four gimmicks, three keep
-- SINGLE-SLOT per-battle state. zmoves.new(), tera.new() and dynamax.new()
-- each return one { mon = nil, ... } for the whole battle, plus one shared
-- move-substitution object, so an enemy activation landing after the player's
-- overwrites that slot and silently unwinds theirs -- and tera's clear()
-- additionally reaches a global Stellar table that a second instance would not
-- dodge. Mega evolution keeps nothing: it writes a form onto the mon and its
-- internals already take a battler.
--
-- Widening that state from one side to two is a real refactor across three
-- files and is worth doing on its own rather than underneath a new feature.
-- Uncommenting a row in GATE is all this module needs once it is done.
local M = {}

-- ----------------------------------------------------------- the data block
--
-- Everything about WHEN this fires, HOW OFTEN, and ON WHOM is here. Nothing
-- below this block reads a trainer name or an item id.

-- gimmick id -> the key item the PLAYER must be holding for the enemy to use
-- it. src/keyitems.lua owns these ids.
M.GATE = {
  mega = "KEY_STONE",
  zmove = "Z_RING",
  dynamax = "DYNAMAX_BAND",
  tera = "TERA_ORB",
  -- The other three are blocked on the same thing, and it is not a small
  -- thing: zmoves.new(), tera.new() and dynamax.new() each return a
  -- SINGLE-SLOT record -- one { mon = ... } for the battle, plus one shared
  -- move-substitution object. An enemy activation after the player's
  -- overwrites that slot and silently unwinds theirs. Mega evolution is the
  -- only one of the four with no such state: it writes a form onto the mon and
  -- keeps nothing per battle.
  -- zmove   = "Z_RING",         -- blocked: zmoves.new() is single-slot
  -- dynamax = "DYNAMAX_BAND",   -- blocked: dynamax.new() is single-slot
  -- tera    = "TERA_ORB",       -- blocked: tera.new() is single-slot, and its
  --                                clear() also reaches the global Stellar table
}

-- Relative weight in the roll, over the gimmicks the ace can actually do.
-- The rare-and-flashy are weighted DOWN rather than up: a mega is already the
-- rarest thing on the list and would otherwise crowd out everything else on
-- exactly the aces that have one.
M.DEFAULT_WEIGHTS = { mega = 1, zmove = 1, dynamax = 3, tera = 3 }

-- How hard each gimmick actually hits, for the fights that should not be
-- rolling dice at all.
--
-- A gym leader, an Elite Four member or a rival is meant to be the wall the
-- player prepares for, so those take the STRONGEST thing their ace can do
-- rather than a weighted pick among them. The weights below still govern
-- ordinary trainers, where variety is the point and a bug catcher pulling the
-- single best gimmick every time would be exhausting.
--
-- The order is a judgement and is meant to be edited: a Dynamax doubles the
-- Pokemon's HP as well as boosting its moves, so it survives longest and hits
-- hardest across a whole fight; a mega evolution is a permanent stat and
-- typing change for the battle; a Z-Move is one enormous hit and then nothing;
-- a Terastallization moves typing around without adding a point of stat.
M.STRENGTH = { dynamax = 4, mega = 3, zmove = 2, tera = 1 }

-- trainer id -> a gimmick id it always uses, for a set piece worth authoring.
-- Empty on purpose: the seeded roll already spreads the eighteen across the
-- roster, and a table with a line per trainer is a table that goes stale.
M.OVERRIDE = {}

-- How often a trainer WITHOUT an AI class qualifies. One in four.
M.CHANCE_ONE_IN = 4

-- What holding ONE key item unlocks for the enemy.
--
--   "any"         -- holding any of the four opens all four. The reading is
--                    that the player has entered the era where trainers do
--                    this sort of thing, rather than that they licensed one
--                    specific mechanic.
--   "per_gimmick" -- each item opens only its own. Perfectly symmetric, and
--                    the reason it is not the default: the Key Stone is
--                    almost always the first item a player gets, so the whole
--                    early game would be mega evolutions and nothing else --
--                    and mega evolution reaches 86 species, which on Gold
--                    means ten of the fourteen gym leaders and Elite Four
--                    still cannot do anything at all.
--
-- Either way a gimmick is only ever offered where the ace can actually use
-- it, so "any" cannot produce a transformation that does not happen.
M.GATE_MODE = "any"

-- ------------------------------------------------------------------ the ace
--
-- Highest level, ties broken toward the LATER party slot -- which is where the
-- ace already sits in every trainer's roster, so the tie-break is the roster's
-- own opinion rather than ours.
function M.aceOf(party)
  if type(party) ~= "table" then return nil end
  local best, bestLevel = nil, -1
  for index = 1, #party do
    local mon = party[index]
    local level = type(mon) == "table" and tonumber(mon.level) or nil
    if level and level >= bestLevel then best, bestLevel = mon, level end
  end
  return best
end

-- ----------------------------------------------------------------- the seed
--
-- A trainer id to a number, stably.
--
-- djb2 rather than the more usual FNV-1a, and deliberately: FNV wants a
-- bitwise xor, `~` is not an operator in the 5.1 dialect LuaJIT speaks, and
-- pulling in `bit` for one hash would be a dependency for nothing.
-- Multiply-and-add spreads perfectly well over a roster of eighteen.
--
-- Kept under 2^31 at every step so each stays an exact double, the same reason
-- src/outbreak.lua's own generator is: a hash that has silently lost precision
-- gives a spread nobody can reproduce from the inputs.
function M.seedFor(trainerId)
  if type(trainerId) ~= "string" or trainerId == "" then return 0 end
  -- A rematch is the SAME trainer. Gold numbers its repeat encounters --
  -- CLAIR1, CLAIR2 -- and seeding on the raw id would have given a leader a
  -- different gimmick the second time the player met them, which is exactly
  -- the re-rolling this seed exists to prevent. The trailing number goes.
  trainerId = (trainerId:gsub("%d+$", ""))
  if trainerId == "" then return 0 end
  local hash = 5381
  for index = 1, #trainerId do
    hash = (hash * 33 + trainerId:byte(index)) % 2147483648
  end
  return hash
end

-- --------------------------------------------------------------- the choice
--
-- `candidates` is the list of gimmick ids this Pokemon can actually do, in a
-- stable order. Answers one of them, or nil for an empty list.
--
-- Seeded from the trainer rather than rolled, so the same trainer always
-- reaches for the same thing. Two trainers whose ids differ land differently
-- because the hash does, which is what spreads the eighteen without anybody
-- writing the spread down.
function M.choose(candidates, trainerId, weights)
  if type(candidates) ~= "table" or #candidates == 0 then return nil end
  weights = weights or M.DEFAULT_WEIGHTS
  local total = 0
  for _, id in ipairs(candidates) do
    total = total + (tonumber(weights[id]) or 1)
  end
  if total <= 0 then return candidates[1] end
  local roll = M.seedFor(trainerId) % total
  for _, id in ipairs(candidates) do
    roll = roll - (tonumber(weights[id]) or 1)
    if roll < 0 then return id end
  end
  return candidates[#candidates]
end

--- The hardest-hitting of a candidate list, by M.STRENGTH. Ties -- and any
--- gimmick the table has no rank for -- fall back to the list's own order,
--- which is M.ORDER and therefore stable.
function M.strongest(candidates)
  if type(candidates) ~= "table" or #candidates == 0 then return nil end
  local best, bestRank = nil, -1
  for _, id in ipairs(candidates) do
    local rank = tonumber(M.STRENGTH[id]) or 0
    if rank > bestRank then best, bestRank = id, rank end
  end
  return best
end

-- ----------------------------------------------------------------- the tier
--
-- A trainer the engine gave an AI class to always qualifies; anything else
-- rolls. `rng` is the caller's -- the battle's own on the real path, a scripted
-- one in the suite -- and is asked for a number in [1, n].
function M.qualifies(hasAiClass, rng)
  if hasAiClass then return true end
  if type(rng) ~= "function" then return false end
  local ok, roll = pcall(rng, 1, M.CHANCE_ONE_IN)
  return ok and roll == 1
end

-- -------------------------------------------------------------- the whole of it
--
-- Pure: plain tables in, a gimmick id or nil out. No battle, no registry, no
-- engine. `ctx` carries
--
--   party        the enemy's party
--   trainerId    the trainer's own id, for the seed and the override
--   hasAiClass   whether the engine gave this trainer an AI class
--   unlocked     item id -> true, the key items the PLAYER holds
--   canDo        function(mon, gimmickId) -> boolean
--   weights      optional, defaults to DEFAULT_WEIGHTS
--   rng          function(lo, hi)
--
-- Answers `nil, reason` when nothing should happen, so a trace can say which
-- of the four gates stopped it rather than only that nothing did.
function M.decide(ctx)
  if type(ctx) ~= "table" then return nil, "no context" end
  local ace = M.aceOf(ctx.party)
  if not ace then return nil, "no ace" end
  if not M.qualifies(ctx.hasAiClass, ctx.rng) then return nil, "not this trainer" end

  local unlocked = type(ctx.unlocked) == "table" and ctx.unlocked or {}
  local canDo = type(ctx.canDo) == "function" and ctx.canDo or function() return false end

  -- An override still has to pass the gate and the eligibility check. A forced
  -- mega on a species with no mega form is an authoring mistake, and honouring
  -- it would mean announcing a transformation that cannot happen.
  local forced = ctx.trainerId and M.OVERRIDE[ctx.trainerId]
  if forced then
    local item = M.GATE[forced]
    local open = item ~= nil and unlocked[item]
    if not open and item ~= nil and M.GATE_MODE == "any" then
      for _, other in pairs(M.GATE) do
        if unlocked[other] then open = true break end
      end
    end
    if open and canDo(ace, forced) then return forced, ace end
    return nil, "override unavailable"
  end

  -- Stable order, so the roll is reproducible: GATE is a keyed table and
  -- iterating it directly would reorder between runs.
  -- Under "any", one key item is the whole key: the gate asks whether the
  -- player holds ANY of the four rather than this gimmick's own.
  local anyHeld = false
  if M.GATE_MODE == "any" then
    for _, item in pairs(M.GATE) do
      if unlocked[item] then anyHeld = true break end
    end
  end

  local candidates = {}
  for _, id in ipairs(M.ORDER) do
    local item = M.GATE[id]
    local open = item ~= nil and (anyHeld or unlocked[item])
    if open and canDo(ace, id) then
      candidates[#candidates + 1] = id
    end
  end
  if #candidates == 0 then return nil, "nothing unlocked or nothing it can do" end
  -- A fight the engine itself marks as hard takes the strongest thing on
  -- offer; everything else rolls. Variety belongs on the routes, not in the
  -- fight the player came prepared for.
  if ctx.hasAiClass then return M.strongest(candidates), ace end
  return M.choose(candidates, ctx.trainerId, ctx.weights), ace
end

-- The order GATE is walked in. Written out rather than derived, because
-- pairs() over GATE would reorder between runs and take the seeded roll --
-- the one thing that has to be reproducible -- with it.
M.ORDER = { "mega", "zmove", "dynamax", "tera" }

-- ==========================================================================
-- The application half.  Everything above is a pure decision; everything
-- below turns one into a form on the enemy's side of the field.
-- ==========================================================================

local deps = nil

--- `megas`, `eligibility`, `forms`/`gen2forms`, `battlerof`, `keyitems`,
--- `gen2` and `log`.  Every one optional at the point of use, because this
--- module is dofile()d bare by its own suite.
function M.bind(modules) deps = modules end

--- Which mega form a species takes when nobody is holding a stone.
---
--- The pairing table is species -> STONE -> form, and the stone is what tells
--- Charizard X from Charizard Y.  An enemy has no stone: engine trainer
--- parties are the ROM's own data and carry no mod items, so the choice has to
--- be made here or the feature never fires for the six species that have two.
---
--- Seeded from the trainer for the same reason the gimmick is: Blaine's
--- Charizard is always the same mega, so the fight can be learned rather than
--- re-rolled.  The stone ids are SORTED first -- pairs() over the inner table
--- would reorder between runs and take the reproducibility with it.
---
--- A form whose record the running game cannot resolve is skipped rather than
--- returned.  data/megas.lua's own header records what happens otherwise: a
--- form id that is not a `data.pokemon` key compiles fine, passes review, and
--- then misses silently inside becomeForm.  That shipped once already.
function M.megaFormFor(megas, species, pokemon, trainerId)
  if type(megas) ~= "table" or not species then return nil end
  local byStone = megas[species]
  if type(byStone) ~= "table" then return nil end
  local stones = {}
  for stone in pairs(byStone) do stones[#stones + 1] = stone end
  if #stones == 0 then return nil end
  table.sort(stones)
  local usable = {}
  for _, stone in ipairs(stones) do
    local formId = byStone[stone]
    if formId and (pokemon == nil or pokemon[formId] ~= nil) then
      usable[#usable + 1] = formId
    end
  end
  if #usable == 0 then return nil end
  return usable[(M.seedFor(trainerId) % #usable) + 1]
end

--- The `canDo` decide() asks for, closed over the running game's data.
--- Answers only what this slice can actually perform: a mega whose form record
--- resolves.  Z-Moves join it when their eligibility is wired; tera and
--- dynamax when their single-slot state is widened.
function M.canDoFor(pokemon, trainerId, pokemonData)
  return function(mon, gimmickId)
    if not mon then return false end
    -- The same bar the player's own cell keeps: a species that may never use a
    -- transformation may not have one used FOR it either.
    if deps and deps.eligibility and deps.eligibility.barredFromGimmicks
      and deps.eligibility.barredFromGimmicks(mon) then return false end
    if gimmickId == "mega" then
      if not (deps and deps.megas) then return false end
      return M.megaFormFor(deps.megas, mon.species, pokemon, trainerId) ~= nil
    end
    -- Terastallization and Dynamax apply to EVERY species -- there is no
    -- per-species table to consult -- so the only question is whether this
    -- boot wired the mechanic at all.
    if gimmickId == "tera" then
      return (deps and deps.entries and deps.entries.tera) ~= nil
    end
    if gimmickId == "dynamax" then
      return (deps and deps.entries and deps.entries.dynamax) ~= nil
    end
    -- A Z-Move needs a crystal ON THE POKEMON, and an enemy carries none. One
    -- is resolved from its own best damaging move and stamped at activation,
    -- so this is offered exactly when such a crystal exists -- never on the
    -- strength of the entry merely being wired, which would let the roll pick
    -- a Z-Move that then refused and wasted the trainer's turn silently.
    if gimmickId == "zmove" then
      if not (deps and deps.entries and deps.entries.zmove and deps.zrows) then
        return false
      end
      return M.crystalForMon(deps.zrows, pokemonData, mon) ~= nil
    end
    return false
  end
end

--- One battle's worth of "has the enemy trainer spent theirs".
---
--- Its own flag rather than src/arm.lua's, and that is the whole point: arm.lua
--- holds ONE once-per-battle flag for the battle rather than one per side, so
--- spending it here would take the PLAYER'S allowance with it.
function M.newState() return { used = false } end

--- The hook.  Shaped like src/resolve.lua's own onTurnStarted, and fired from
--- the same event, so the transformation lands in the rhythm the player's
--- already does -- before moves, after the turn opens.
---
--- Answers the gimmick it performed, or nil and a reason.  Every read is
--- guarded: a battle that cannot answer one of these questions is a battle
--- where nothing happens, never one that raises inside a turn.
function M.onTurnStarted(state, ev, options)
  if type(state) ~= "table" or state.used then return nil, "spent" end
  if options and options.enabled == false then return nil, "off" end
  local battle = ev and ev.battle
  if not battle then return nil, "no battle" end
  -- Red's BattleState sets `kind` to "trainer" or "wild"; Gold's Battle sets
  -- NO SUCH FIELD -- every `kind` in that class is a damage kind or an action
  -- kind, unrelated to this. Testing it directly rejected every single Gold
  -- battle at the first gate, so the feature could not fire on that game at
  -- all. The trainer record is the thing both games agree on: a wild battle
  -- has none.
  if not battle.trainer then return nil, "not a trainer" end
  if battle.kind ~= nil and battle.kind ~= "trainer" then
    return nil, "not a trainer"
  end
  if not (deps and deps.battlerof) then return nil, "unbound" end

  -- The two games name this differently and the difference is silent: Red's
  -- BattleState stores the trainer record under `id` (OPP_BROCK), while Gold's
  -- gen2/Battle stores the class under `classId`/`class`. Reading only `id`
  -- meant every Gold battle exited here as "no trainer id" and the feature
  -- did nothing on that game at all, with nothing logged.
  local trainer = battle.trainer
  local trainerId = trainer and (trainer.id or trainer.classId or trainer.class
                                 or trainer.aiClass)
  if type(trainerId) ~= "string" then return nil, "no trainer id" end

  -- The enemy standing on the field has to BE the ace: a trainer whose ace is
  -- still in the party spends nothing, and gets to spend it when it arrives.
  local battler = battle.enemy
  local mon = deps.battlerof.mon(battler)
  if not mon then return nil, "no enemy mon" end
  local ace = M.aceOf(battle.enemyParty)
  if ace and ace ~= mon then return nil, "not the ace" end

  local unlocked = {}
  if deps.keyitems and deps.keyitems.held then
    for _, item in ipairs(deps.keyitems.ITEMS or {}) do
      local ok, held = pcall(deps.keyitems.held, battle, item)
      if ok and held then unlocked[item] = true end
    end
  end

  local pokemon = battle.data and battle.data.pokemon
  local pick, why = M.decide({
    party = battle.enemyParty, trainerId = trainerId,
    hasAiClass = (options and options.hasAiClass) or false,
    unlocked = unlocked, canDo = M.canDoFor(pokemon, trainerId, battle.data),
    rng = battle.rng,
  })
  if not pick then
    -- Once per battle, not per turn: this is a diagnosis aid, not a trace, and
    -- a line every turn would bury the one that matters. Logged rather than
    -- silent because "the enemy did nothing" is indistinguishable on screen
    -- from "the enemy declined", and telling those apart by playing is
    -- exactly what has cost two rounds of blind fixes already.
    if deps.log and not state.said then
      state.said = true
      deps.log:info("battle_forms: no enemy gimmick for %s (%s) -- ace=%s "
        .. "aiClass=%s unlocked=%s", tostring(trainerId), tostring(why),
        tostring(mon and mon.species),
        tostring(options and options.hasAiClass),
        tostring(next(unlocked) ~= nil))
    end
    return nil, why
  end

  -- --- the three that run through their own entry -------------------------
  --
  -- Their activate() closures do real work -- announcing, substituting the
  -- move array, seeding the state, handling both generations -- and
  -- reimplementing any of it here would be a fork that silently diverges the
  -- first time one of them is fixed. So the ENTRY is used, built in main.lua
  -- against the ENEMY's own state, and handed a view of the battle whose
  -- `player` slot holds the enemy's battler.
  --
  -- That view is a proxy rather than a copy: reads fall through to the real
  -- battle and writes land on it, so a message queued during activation is
  -- queued on the battle the player is actually looking at. Safe because the
  -- announcements key off the BATTLER they are handed rather than off
  -- battle.player -- announce.displayName puts "Enemy " in front of a battler
  -- whose isPlayer is false, and the text box was sized for exactly that.
  local entry = deps.entries and deps.entries[pick]
  if entry then
    if pick == "zmove" then
      local crystal = M.crystalForMon(deps.zrows, battle.data, mon)
      if not crystal then return nil, "no crystal" end
      -- Where a held item lives differs by game: Gold has a real item slot,
      -- Red has none and this mod stamps its own field (src/eligibility.lua's
      -- own header on why a side table keyed by mon is impossible there).
      -- Transient either way -- an enemy party is rebuilt from trainer data
      -- every battle and is never saved.
      if deps.gen2 then
        mon.item = crystal
      elseif deps.eligibility and deps.eligibility.STAMP then
        mon[deps.eligibility.STAMP] = crystal
      end
    end

    if pick == "tera" then
      -- Chosen, never derived. src/tera.lua reads the type through
      -- teratype.of(), which prefers a stamp on the Pokemon over the DV
      -- derivation -- so stamping first is how a considered type reaches an
      -- unchanged mechanic. The stamp is transient: an enemy party is rebuilt
      -- from trainer data every battle and is never saved.
      local typeId = M.teraTypeFor(battle.data, battle.enemyParty, mon, trainerId)
      if not typeId then return nil, "no tera type" end
      if deps.teratype and deps.teratype.STAMP then
        mon[deps.teratype.STAMP] = typeId
      end
    end

    local view = setmetatable({}, {
      __index = function(_, key)
        if key == "player" then return battler end
        return battle[key]
      end,
      __newindex = function(_, key, value) battle[key] = value end,
    })

    -- Arming first where the mechanic has an arm step: that is where the two
    -- move-substituting mechanics swap the move array, and the player's own
    -- path does it when the cell is armed rather than when it fires.
    if type(entry.arm) == "function" then pcall(entry.arm, view) end
    local ok, applied = pcall(entry.activate, view)
    if not (ok and applied) then
      if type(entry.disarm) == "function" then pcall(entry.disarm, view) end
      if deps.log then
        deps.log:warn("battle_forms: enemy %s refused for %s", tostring(pick),
          tostring(mon.species))
      end
      return nil, "refused"
    end
    state.used = true
    return pick, mon
  end

  if pick == "mega" then
    local formId = M.megaFormFor(deps.megas, mon.species, pokemon, trainerId)
    if not formId then return nil, "no form" end
    local forms = deps.gen2 and deps.gen2forms or deps.forms
    if not (forms and forms.becomeForm) then return nil, "no form engine" end
    local ok, reason = forms.becomeForm(battle.data, mon, formId)
    if ok and deps.announce then
      -- AFTER the form actually changed, never before: announcing first and
      -- then failing would print a transformation that did not happen. And it
      -- must be announced at all -- a sprite that silently becomes a different
      -- Pokemon mid-battle is exactly the quiet wrongness this project keeps
      -- paying for, and the player has no other way to know what they are now
      -- facing.
      --
      -- TWO CHANNELS, one per game, and they are not interchangeable. Red's
      -- announce.mega takes a BATTLER and queues through push; Gold's
      -- announce.gen2Mega takes a MON and goes through Battle:emit, which is
      -- an entirely different path (src/mega.lua's own note on why). Calling
      -- only Red's meant a Gold mega evolution changed the sprite and printed
      -- nothing -- the transformation happened and the Pokemon simply
      -- attacked, which is how it survived a playtest.
      --
      -- Each names its own side correctly: Red's displayName puts "Enemy " in
      -- front of a battler whose isPlayer is false, and Gold's gen2Name asks
      -- the engine's own monName.
      if deps.gen2 then
        if deps.announce.gen2Mega then
          pcall(deps.announce.gen2Mega, battle, mon)
        end
      elseif deps.announce.mega then
        pcall(deps.announce.mega, battle, battler)
      end
    end
    if not ok then
      if deps.log then
        deps.log:warn("battle_forms: enemy mega refused for %s -> %s (%s)",
          tostring(mon.species), tostring(formId), tostring(reason))
      end
      -- A refusal must NOT spend the flag, the same rule src/resolve.lua keeps
      -- for the player: nothing happened, so the trainer keeps the option.
      return nil, "refused"
    end
    state.used = true
    return pick, formId
  end

  return nil, "unhandled gimmick"
end

-- ------------------------------------------------------ the enemy's Tera type
--
-- The PLAYER's Tera type is derived from their Pokemon's own DVs
-- (src/teratype.lua), which is right for them -- it is a fact about a Pokemon
-- they raised. For an enemy it would be effectively random, and a random type
-- is frequently WORSE than the typing the Pokemon already has: a
-- Terastallization that downgrades its user is a threat on paper and a gift in
-- practice.
--
-- So the enemy's is chosen, in three steps, none of which can pick a type the
-- Pokemon has no use for:
--
--   1. THE TRAINER'S BRAND, if the ace can actually use it. The brand is not a
--      table of gym types -- it is the most common type across the trainer's
--      OWN party, so Clair's three Dragonair and a Kingdra make Dragon and
--      Morty's Gastly line makes Ghost. Self-maintaining, needs no authoring,
--      and works for ordinary trainers too. Taken only when the ace knows a
--      damaging move of that type, so it buys real STAB rather than a costume.
--   2. THE TYPE OF ITS STRONGEST DAMAGING MOVE, which guarantees the
--      Terastallization boosts the thing it most wants to do.
--   3. ITS OWN PRIMARY TYPE, which can never be a downgrade.
--
-- Ties are broken by the trainer seed, so this stays as stable per trainer as
-- every other choice here.

--- The most common type across a party, or nil. Ties go to the type of the
--- earliest Pokemon holding one, so the answer does not depend on table order.
function M.brandOf(data, party)
  if type(party) ~= "table" then return nil end
  local count, order, seen = {}, {}, 0
  for _, mon in ipairs(party) do
    local record = mon and mon.species and data and data.pokemon
      and data.pokemon[mon.species]
    local types = record and record.types
    if type(types) == "table" then
      for _, id in ipairs(types) do
        if type(id) == "string" and id ~= "" then
          if count[id] == nil then seen = seen + 1; order[id] = seen end
          count[id] = (count[id] or 0) + 1
        end
      end
    end
  end
  local best, bestCount = nil, 0
  for id, n in pairs(count) do
    if n > bestCount or (n == bestCount and best and order[id] < order[best]) then
      best, bestCount = id, n
    end
  end
  return best
end

--- The type of the strongest damaging move this Pokemon knows, or nil.
--- Move records are the running game's, so a move the game cannot resolve is
--- simply skipped rather than assumed to be anything.
function M.bestMoveType(data, mon)
  local moves = mon and mon.moves
  if type(moves) ~= "table" then return nil end
  local best, bestPower = nil, 0
  for _, id in ipairs(moves) do
    local record = id and data and data.moves and data.moves[id]
    local power = record and tonumber(record.power) or 0
    local kind = record and record.type
    if power > bestPower and type(kind) == "string" and kind ~= "" then
      best, bestPower = kind, power
    end
  end
  return best
end

--- Whether this Pokemon knows a damaging move of `typeId`.
function M.knowsTypedMove(data, mon, typeId)
  local moves = mon and mon.moves
  if type(moves) ~= "table" or type(typeId) ~= "string" then return false end
  for _, id in ipairs(moves) do
    local record = id and data and data.moves and data.moves[id]
    if record and record.type == typeId
      and (tonumber(record.power) or 0) > 0 then return true end
  end
  return false
end

--- The Z-Crystal for a type, from data/zmoves.lua's own rows, or nil.
---
--- An enemy carries no crystal -- engine trainer parties are the ROM's own
--- data and hold no mod items -- so one is resolved from the ace's own best
--- damaging move and stamped before the mechanic is asked. The same reading
--- the Key Stone gets: a trainer who owns the ring equipped their ace for it.
function M.crystalFor(zrows, typeId)
  if type(zrows) ~= "table" or type(typeId) ~= "string" then return nil end
  for _, row in ipairs(zrows) do
    if type(row) == "table" and row.type == typeId then return row.crystal end
  end
  return nil
end

--- The crystal this Pokemon would be given, or nil when it has no damaging
--- move whose type has one.
function M.crystalForMon(zrows, data, mon)
  local best = M.bestMoveType(data, mon)
  if not best then return nil end
  return M.crystalFor(zrows, best)
end

--- The three steps above, in order. Answers a type id, or nil when the running
--- game cannot tell us enough to make any of them -- in which case nothing
--- should terastallize, because "some type" is exactly the arbitrary outcome
--- this function exists to avoid.
function M.teraTypeFor(data, party, mon, trainerId)
  if not mon then return nil end
  local brand = M.brandOf(data, party)
  if brand and M.knowsTypedMove(data, mon, brand) then return brand end
  local best = M.bestMoveType(data, mon)
  if best then return best end
  local record = mon.species and data and data.pokemon and data.pokemon[mon.species]
  local own = record and record.types
  if type(own) == "table" and own[1] then
    -- Seeded rather than always the first, so a dual-type ace is not
    -- deterministically its primary across the whole roster.
    return own[(M.seedFor(trainerId) % #own) + 1]
  end
  return nil
end

return M
