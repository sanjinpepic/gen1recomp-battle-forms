-- Max Moves: the roster that gets registered, the ladder that decides which
-- record a move becomes, and the Dynamax that puts them on and takes them off.
--
-- Two things this suite is really for.  The first is that a Max Move must be a
-- REGISTERED record: the battle reads power, type, accuracy, name and PP off
-- data.moves and not off the instance it was handed, so a synthesised Max Move
-- is a move that cannot be used, drawn or checkpointed.  The second is that
-- none of this may reach the save -- the party Pokemon's move array and every
-- slot in it are compared by identity before and after every unwind path there
-- is, the way src/tera.lua's suite compares the battler's types.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local MaxMoves = dofile(MOD .. "/src/maxmoves.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local ROWS = dofile(MOD .. "/data/maxmoves.lua")

-- Red's fifteen, which is what the engine registers on its own; the three
-- modern ones arrive only where National Dex has put a chart over the top.
local RED_TYPES = { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK",
                    "BUG", "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC",
                    "PSYCHIC_TYPE", "ICE", "DRAGON" }
local MODERN_TYPES = { "DARK", "STEEL", "FAIRY" }

local function chartOf(list)
  local chart = {}
  for _, id in ipairs(list) do chart[id] = { name = id, category = "physical" } end
  return chart
end

-- Enough of a mod to register into and read back, plus the one registry
-- src/maxmoves.lua interrogates before it registers anything.
local function stubMod(chart)
  local warned = {}
  local buckets = { moves = {}, battle_anims = {}, move_effects = {} }
  local order = {}
  local content = {}
  for name, bucket in pairs(buckets) do
    content[name] = {
      register = function(_, id, record)
        T.check(bucket[id] == nil, name .. " id registered once: " .. tostring(id))
        bucket[id] = record
        order[#order + 1] = name .. ":" .. id
      end,
    }
  end
  content.type_chart = { get = function(_, id) return chart[id] end }
  return {
    content = content,
    log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
    registered = buckets,
    order = order,
    warned = warned,
  }
end

local function bindMaxMoves(mod, guard)
  MaxMoves.bind({ anim = Anim, announce = Announce, log = mod and mod.log,
                  guard = guard })
end

-- ---------------------------------------------------------------------
-- The ladder.
-- ---------------------------------------------------------------------
do
  -- The seven rungs, at the boundary and either side of it, for a type on the
  -- standard ladder.
  local cases = { { 1, 90 }, { 40, 90 }, { 41, 100 }, { 50, 100 }, { 51, 110 },
                  { 60, 110 }, { 61, 120 }, { 75, 120 }, { 76, 130 },
                  { 85, 130 }, { 86, 140 }, { 100, 140 }, { 101, 150 },
                  { 250, 150 } }
  for _, case in ipairs(cases) do
    T.eq(MaxMoves.powerFor(ROWS, "FIRE", case[1]), case[2],
      ("a %d-power Fire move becomes %d"):format(case[1], case[2]))
  end

  -- Fighting and Poison are a rung lower at every step, which is the one
  -- irregularity in the table.
  local lowered = { { 40, 70 }, { 50, 75 }, { 60, 80 }, { 75, 85 }, { 85, 90 },
                    { 100, 95 }, { 120, 100 } }
  for _, case in ipairs(lowered) do
    T.eq(MaxMoves.powerFor(ROWS, "FIGHTING", case[1]), case[2],
      ("a %d-power Fighting move becomes %d"):format(case[1], case[2]))
    T.eq(MaxMoves.powerFor(ROWS, "POISON", case[1]), case[2],
      ("and so does a %d-power Poison one"):format(case[1]))
  end
  T.eq(MaxMoves.powerFor(ROWS, "FLYING", 100), 140,
    "and no other type is on the lower ladder")
end

-- ---------------------------------------------------------------------
-- Registration: one record per type per rung, and the animation beside it.
-- ---------------------------------------------------------------------
do
  local mod = stubMod(chartOf(RED_TYPES))
  bindMaxMoves(mod)
  local catalog = MaxMoves.install(mod, ROWS)

  local count = 0
  for _ in pairs(mod.registered.moves) do count = count + 1 end
  T.eq(count, 15 * 7 + 1,
    "fifteen types at seven rungs each, plus Max Guard")
  T.eq(#mod.warned, 3,
    "and the three types this chart has no record for are logged, not swallowed")
  T.check(mod.warned[1] ~= nil and mod.warned[1]:find("DARK", 1, true) ~= nil,
    "the first line names the type it could not register")

  local flare = mod.registered.moves[MaxMoves.idFor("MAXFLARE", 90)]
  T.check(flare ~= nil, "MAX FLARE registered at the bottom rung")
  T.eq(flare.id, MaxMoves.idFor("MAXFLARE", 90),
    "the record's id equals the key it was registered under -- the animation "
      .. "row and lastMove are built from the record, the lookup from the key")
  T.eq(flare.name, "MAX FLARE", "with the name the FIGHT menu draws")
  T.eq(flare.type, "FIRE", "the base move's type")
  T.eq(flare.power, 90, "the rung's power")
  T.eq(flare.accuracy, 100, "an accuracy a move record can express")
  T.eq(flare.pp, MaxMoves.RECORD_PP, "the PP the menu's maximum is built from")
  T.eq(flare.effect, "NO_ADDITIONAL_EFFECT", "and a vanilla effect id")
  T.eq(flare.category, nil,
    "with no category, so Gen 1's own type split decides it")
  T.eq(flare.priority, nil, "and no priority")

  T.check(mod.registered.moves[MaxMoves.idFor("MAXKNUCKLE", 70)] ~= nil,
    "Fighting's records are keyed on the lowered powers")
  T.eq(mod.registered.moves[MaxMoves.idFor("MAXKNUCKLE", 130)], nil,
    "and never on a standard one the lower ladder never reaches")

  -- Every move id is also an animation id, because the engine queues the move's
  -- own id as the animation key.
  for id in pairs(mod.registered.moves) do
    T.check(mod.registered.battle_anims[id] ~= nil,
      "an animation is registered for " .. id)
    T.check(#mod.registered.battle_anims[id].seq > 0,
      "with rows in it for " .. id)
  end

  -- Max Guard is a status move and carries the effect record that makes it one.
  local guard = mod.registered.moves[catalog.guard]
  T.check(guard ~= nil, "Max Guard registered")
  T.eq(guard.power, 0, "with no power at all")
  T.eq(guard.effect, MaxMoves.GUARD_EFFECT, "and its own effect")
  T.eq(guard.priority, 4,
    "moving first, because a shield raised after the hit lands does nothing")
  T.check(mod.registered.move_effects[MaxMoves.GUARD_EFFECT] ~= nil,
    "and the effect record exists to be resolved to")
  T.eq(mod.registered.move_effects[MaxMoves.GUARD_EFFECT].kind, "primary",
    "as a primary effect, which is the path a powerless move takes")

  -- Every id wears the mod's name, so a move pack registering MAXFLARE cannot
  -- collide with this one.
  for id in pairs(mod.registered.moves) do
    T.eq(id:sub(1, #MaxMoves.PREFIX), MaxMoves.PREFIX,
      id .. " is namespaced to this mod")
  end
end

-- With the modern chart the other three arrive and nothing is logged.
do
  local all = {}
  for _, id in ipairs(RED_TYPES) do all[#all + 1] = id end
  for _, id in ipairs(MODERN_TYPES) do all[#all + 1] = id end
  local mod = stubMod(chartOf(all))
  bindMaxMoves(mod)
  MaxMoves.install(mod, ROWS)

  local count = 0
  for _ in pairs(mod.registered.moves) do count = count + 1 end
  T.eq(count, 18 * 7 + 1, "all eighteen types at seven rungs each, plus the guard")
  T.eq(#mod.warned, 0, "with nothing to refuse")
  T.check(mod.registered.moves[MaxMoves.idFor("MAXDARKNESS", 110)] ~= nil,
    "and MAX DARKNESS among them")
end

-- A build whose registry offers no `get` leaves the typed Max Moves out rather
-- than taking the mod down with a nil call.
do
  local mod = stubMod({})
  mod.content.type_chart = {}
  bindMaxMoves(mod)
  local catalog = MaxMoves.install(mod, ROWS)
  local count = 0
  for _ in pairs(mod.registered.moves) do count = count + 1 end
  T.eq(count, 1, "only Max Guard, which names no type it had to look up")
  T.eq(catalog.guard ~= nil, true, "and the catalog still answers for it")
end

-- ---------------------------------------------------------------------
-- Which record a move slot becomes.
-- ---------------------------------------------------------------------
local MOVES = {
  EMBER =    { id = "EMBER", name = "EMBER", type = "FIRE", power = 40,
               accuracy = 100, pp = 25, effect = "NO_ADDITIONAL_EFFECT" },
  BODYSLAM = { id = "BODYSLAM", name = "BODY SLAM", type = "NORMAL", power = 85,
               accuracy = 100, pp = 15, effect = "NO_ADDITIONAL_EFFECT" },
  LOWKICK =  { id = "LOWKICK", name = "LOW KICK", type = "FIGHTING", power = 50,
               accuracy = 90, pp = 20, effect = "NO_ADDITIONAL_EFFECT" },
  GROWL =    { id = "GROWL", name = "GROWL", type = "NORMAL", power = 0,
               accuracy = 100, pp = 40, effect = "ATTACK_DOWN1_EFFECT" },
  BITE =     { id = "BITE", name = "BITE", type = "DARK", power = 60,
               accuracy = 100, pp = 25, effect = "NO_ADDITIONAL_EFFECT" },
}

do
  local mod = stubMod(chartOf(RED_TYPES))
  bindMaxMoves(mod)
  local catalog = MaxMoves.install(mod, ROWS)
  local data = { moves = MOVES }

  local ember = MaxMoves.fieldsFor(catalog, data, { id = "EMBER", pp = 25 })
  T.eq(ember.id, MaxMoves.idFor("MAXFLARE", 90),
    "a 40-power Fire move becomes MAX FLARE at 90")
  local slam = MaxMoves.fieldsFor(catalog, data, { id = "BODYSLAM", pp = 15 })
  T.eq(slam.id, MaxMoves.idFor("MAXSTRIKE", 130),
    "an 85-power Normal move becomes MAX STRIKE at 130")
  local kick = MaxMoves.fieldsFor(catalog, data, { id = "LOWKICK", pp = 20 })
  T.eq(kick.id, MaxMoves.idFor("MAXKNUCKLE", 75),
    "and a 50-power Fighting move takes the lower ladder")

  -- Status moves all become the same move whatever their type.
  local growl = MaxMoves.fieldsFor(catalog, data, { id = "GROWL", pp = 40 })
  T.eq(growl.id, catalog.guard, "a move with no power becomes MAX GUARD")

  -- A type with no Max Move leaves the slot alone rather than retyping it.
  T.eq(MaxMoves.fieldsFor(catalog, data, { id = "BITE", pp = 25 }), nil,
    "a Dark move keeps itself where the chart has no Dark type")
  -- ...and gets its Max Move once the chart carries the type.
  local withDark = stubMod(chartOf({ "DARK" }))
  bindMaxMoves(withDark)
  local darkCatalog = MaxMoves.install(withDark, ROWS)
  T.eq(MaxMoves.fieldsFor(darkCatalog, data, { id = "BITE", pp = 25 }).id,
    MaxMoves.idFor("MAXDARKNESS", 110),
    "and becomes MAX DARKNESS where it does")

  -- An id the registry cannot resolve has no power or type to read, so there is
  -- nothing to decide with.
  T.eq(MaxMoves.fieldsFor(catalog, data, { id = "NOSUCHMOVE", pp = 5 }), nil,
    "an unknown move is left alone")
  T.eq(MaxMoves.fieldsFor(catalog, data, nil), nil, "and so is no slot at all")

  -- The synthesised ppUps exists so the FIGHT menu's own maximum formula
  -- (BattleState.lua:5850) reads the BASE move's maximum back.
  local function menuMax(fields, baseId)
    local def = mod.registered.moves[fields.id]
    return def.pp + (fields.ppUps or 0) * math.floor(def.pp / 5), baseId
  end
  T.eq(menuMax(ember), 25, "the menu draws EMBER's own maximum of 25")
  T.eq(menuMax(slam), 15, "and BODY SLAM's of 15")
  T.eq(menuMax(growl), 40, "and GROWL's of 40 behind MAX GUARD")
  local upped = MaxMoves.fieldsFor(catalog, data, { id = "EMBER", pp = 30, ppUps = 1 })
  T.eq(menuMax(upped), 30, "and a PP Up on the slot still shows through")
end

-- ---------------------------------------------------------------------
-- Max Guard's shield.
-- ---------------------------------------------------------------------
do
  local mod = stubMod(chartOf(RED_TYPES))
  local guard = MaxMoves.newGuard()
  bindMaxMoves(mod, guard)
  MaxMoves.install(mod, ROWS)
  local record = mod.registered.move_effects[MaxMoves.GUARD_EFFECT]

  local battler = { isPlayer = true, name = "ZARD" }
  local msgs = record.run({ user = battler })
  T.eq(battler.invulnerable, true, "using Max Guard raises the shield")
  T.eq(guard.battler, battler, "and the record knows whose it is")
  T.eq(#msgs, 1, "with a line to print")
  T.eq(msgs[1], "ZARD\nprotected itself!", "saying what happened")

  MaxMoves.onTurnEnded(guard)
  T.eq(battler.invulnerable, nil, "the shield comes down at the end of the turn")
  T.eq(guard.battler, nil, "and the record lets the battler go")
  MaxMoves.onTurnEnded(guard)
  T.eq(battler.invulnerable, nil, "a second turn ending changes nothing")

  -- Both ends of a battle drop it as well, so nothing can be left standing by a
  -- turn that never ended.
  record.run({ user = battler })
  MaxMoves.onBattleEnded(guard)
  T.eq(battler.invulnerable, nil, "the battle ending takes it down")
  record.run({ user = battler })
  MaxMoves.onBattleStarted(guard)
  T.eq(battler.invulnerable, nil, "and so does the next one starting")

  -- An effect that returns nothing reads to the engine as a refusal and cancels
  -- the animation, so this one always has something to say.
  local nameless = {}
  T.eq(#record.run({ user = nameless }), 1,
    "a battler with no name still gets a line")
  MaxMoves.onTurnEnded(guard)
end

-- ---------------------------------------------------------------------
-- Dynamax puts them on and every unwind path takes them off.
-- ---------------------------------------------------------------------
local DATA = {
  moves = MOVES,
  pokemon = {
    CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                                speed = 100, special = 85 },
                  types = { "FIRE", "FLYING" } },
    CHARIZARD_GMAX = { baseStats = { hp = 78, attack = 84, defense = 78,
                                     speed = 100, special = 85 },
                       types = { "FIRE", "FLYING" }, form = "GMAX" },
    PIDGEY = { baseStats = { hp = 40, attack = 45, defense = 40,
                             speed = 56, special = 35 },
               types = { "NORMAL", "FLYING" } },
  },
}

-- The merge the loader performs, done here by hand: a registered Max Move is a
-- record in `data.moves`, which is where every reader in the battle looks for
-- it (BattleState:moveDef, the FIGHT menu, BattleCheckpoint's validation).
local CATALOG
do
  local mod = stubMod(chartOf(RED_TYPES))
  bindMaxMoves(mod)
  CATALOG = MaxMoves.install(mod, ROWS)
  for id, record in pairs(mod.registered.moves) do MOVES[id] = record end
end

local function newMon(species)
  local def = DATA.pokemon[species]
  return {
    species = species, level = 50, nickname = "ZARD",
    dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
    statExp = {},
    moves = { { id = "EMBER", pp = 25 }, { id = "BODYSLAM", pp = 15 },
              { id = "LOWKICK", pp = 20 }, { id = "GROWL", pp = 40 } },
    hp = 120,
    stats = { hp = 150, attack = def.baseStats.attack,
              defense = def.baseStats.defense, speed = def.baseStats.speed,
              special = def.baseStats.special },
  }
end

local function makeBattle(species)
  local mon = newMon(species or "CHARIZARD")
  local said = {}
  return {
    data = DATA,
    said = said,
    player = { isPlayer = true, mon = mon, name = mon.nickname,
               curStats = mon.stats, curMoves = mon.moves,
               curTypes = DATA.pokemon[mon.species].types },
    game = { save = { party = { mon },
                      inventory = { [KeyItems.DYNAMAX_BAND] = 1 } } },
    enemyParty = {},
    say = function(_, line) said[#said + 1] = line end,
    sayNext = function(_, line) said[#said + 1] = line end,
    animNext = function() end,
    animationsOn = function() return false end,
  }
end

Dynamax.bind({ forms = Forms, gigantamax = { CHARIZARD = "CHARIZARD_GMAX" },
               keyitems = KeyItems, announce = Announce,
               substitute = Substitute,
               maxMoves = function(data)
                 return MaxMoves.picker(CATALOG, data)
               end })

-- Everything the save keeps about this Pokemon's moves, taken as one snapshot
-- so every teardown path below can assert the same thing the same way.
local function saveSnapshot(mon)
  local slots = {}
  for index, slot in ipairs(mon.moves) do
    local keys = {}
    for key, value in pairs(slot) do keys[key] = value end
    slots[index] = { table = slot, keys = keys }
  end
  local monKeys = {}
  for key in pairs(mon) do monKeys[key] = true end
  return { moves = mon.moves, slots = slots, monKeys = monKeys }
end

local function assertSaveUntouched(before, mon, when)
  T.eq(mon.moves, before.moves,
    "the Pokemon's move ARRAY is the same table " .. when)
  T.eq(#mon.moves, #before.slots, "with the same number of slots " .. when)
  for index, snap in ipairs(before.slots) do
    T.eq(mon.moves[index], snap.table,
      ("slot %d is the same table %s"):format(index, when))
    for key, value in pairs(snap.keys) do
      T.eq(mon.moves[index][key], value,
        ("slot %d keeps %s %s"):format(index, key, when))
    end
    for key in pairs(mon.moves[index]) do
      T.check(snap.keys[key] ~= nil,
        ("slot %d gained no key %s %s"):format(index, tostring(key), when))
    end
  end
  for key in pairs(mon) do
    T.check(before.monKeys[key],
      "the Pokemon carries no new key " .. when .. ": " .. tostring(key))
  end
end

-- The moveset a Dynamaxed battler shows, and the proof the battle reads it.
--
-- PIDGEY rather than CHARIZARD, because this is the block that compares the
-- Pokemon's whole key set while the Dynamax is LIVE: a Gigantamax would have
-- put `form` on the mon by then, which is a mark the mod is supposed to make.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("PIDGEY")
  local battler = battle.player
  local mon = battler.mon
  local before = saveSnapshot(mon)

  T.eq(battler.curMoves, mon.moves,
    "precondition: the battler is holding the Pokemon's own array")

  T.eq(entry.activate(battle), true, "the Dynamax happened")
  T.check(battler.curMoves ~= mon.moves,
    "and the battler is no longer holding the Pokemon's array")
  T.eq(battler.curMoves[1].id, MaxMoves.idFor("MAXFLARE", 90),
    "EMBER reads as MAX FLARE")
  T.eq(battler.curMoves[2].id, MaxMoves.idFor("MAXSTRIKE", 130),
    "BODY SLAM as MAX STRIKE")
  T.eq(battler.curMoves[3].id, MaxMoves.idFor("MAXKNUCKLE", 75),
    "LOW KICK as MAX KNUCKLE, on the lower ladder")
  T.eq(battler.curMoves[4].id, CATALOG.guard, "and GROWL as MAX GUARD")
  T.eq(#battler.curMoves, 4, "with the slots still in their own places")

  -- The battle reads the substitutes: this is the exact lookup performMove
  -- makes (BattleState.lua:2349) and the exact test the FIGHT menu's PP check
  -- makes (:1868).
  for index, slot in ipairs(battler.curMoves) do
    T.check(DATA.moves[slot.id] ~= nil or CATALOG.guard == slot.id,
      ("slot %d resolves against the registry"):format(index))
    T.check(slot.pp > 0, ("slot %d reports PP"):format(index))
  end

  -- PP is the party Pokemon's, spent from the party Pokemon's slot.
  T.eq(battler.curMoves[1].pp, 25, "MAX FLARE reports EMBER's remaining PP")
  battler.curMoves[1].pp = battler.curMoves[1].pp - 1
  T.eq(mon.moves[1].pp, 24, "and using it spends EMBER's")
  T.eq(battler.curMoves[1].pp, 24, "which is the same number read back")
  mon.moves[1].pp = 25

  assertSaveUntouched(before, mon, "while Dynamaxed")

  -- Three turns, then the moves come back by identity.
  Dynamax.onTurnEnded(state, { battle = battle })
  T.check(battler.curMoves ~= mon.moves, "still substituted after one turn")
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(battler.curMoves, mon.moves,
    "the clock running out gives back the exact array it took")
  assertSaveUntouched(before, mon, "after the clock ran out")
end

-- A Gigantamax Pokemon gets the same Max Moves.  There is no G-Max move data
-- anywhere in this project to give it anything else -- the move source carries
-- the eighteen Max Moves and Max Guard and no G-Max move at all -- so wiring one
-- would mean inventing it.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player

  entry.activate(battle)
  T.eq(battler.mon.form, "GMAX", "the Gigantamax shape went on")
  T.eq(battler.curMoves[1].id, MaxMoves.idFor("MAXFLARE", 90),
    "and its Fire move is the ordinary MAX FLARE")

  local plain = Dynamax.new()
  local plainEntry = Dynamax.entry(plain)
  local other = makeBattle("PIDGEY")
  plainEntry.activate(other)
  T.eq(other.player.mon.form, nil, "a species with no Gigantamax takes none")
  T.eq(other.player.curMoves[1].id, battler.curMoves[1].id,
    "and gets exactly the same Max Move for the same base move")
end

-- Switching out: read off the battler that LEFT, which is the one holding the
-- substituted array.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local outgoing = battle.player
  local mon = outgoing.mon
  local before = saveSnapshot(mon)
  entry.activate(battle)
  T.check(outgoing.curMoves ~= mon.moves, "substituted")

  local incoming = { isPlayer = true, mon = newMon("PIDGEY"), name = "PIDGE" }
  incoming.curMoves = incoming.mon.moves
  battle.player = incoming
  Dynamax.onBattlerSwitched(state, { battle = battle, battler = incoming,
                                     previous = outgoing })
  T.eq(outgoing.curMoves, mon.moves,
    "switching out gives the array back to the battler that left")
  T.eq(incoming.curMoves, incoming.mon.moves,
    "and never touched the one that came in")
  assertSaveUntouched(before, mon, "after switching out")
end

-- Fainting.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player
  local mon = battler.mon
  local before = saveSnapshot(mon)
  entry.activate(battle)

  mon.hp = 0
  Dynamax.onFainted(state, { battle = battle, battler = battler })
  T.eq(battler.curMoves, mon.moves, "fainting gives the array back")
  mon.hp = 120
  assertSaveUntouched(before, mon, "after fainting")
end

-- The battle ending, with the party sweep in front of it the way main.lua
-- orders them.
do
  Resolve.bind({ registry = Transforms.new(), forms = Forms, eligibility = E,
                 megas = Megaset.select(dofile(MOD .. "/data/megas.lua"),
                                        Megaset.ALL) })
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player
  local mon = battler.mon
  local before = saveSnapshot(mon)
  entry.activate(battle)

  Resolve.onBattleEnded({ battle = battle })
  Dynamax.onBattleEnded(state)
  T.eq(battler.curMoves, mon.moves,
    "the battle ending mid-Dynamax gives the array back")
  T.eq(state.moves.battler, nil,
    "and the substitution holds no battler past the battle that owned it")
  assertSaveUntouched(before, mon, "after the battle ended mid-Dynamax")
end

-- A battle STARTING clears a substitution left behind by anything that went
-- wrong, the same way it clears a stale form.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player
  local mon = battler.mon
  entry.activate(battle)
  Dynamax.onBattleStarted(state)
  T.eq(battler.curMoves, mon.moves, "a new battle starts with nothing substituted")
  T.eq(state.moves.battler, nil, "and holding no battler")
end

-- Without the mechanism bound at all, Dynamax is exactly what it was before Max
-- Moves existed: the state, the clock and the form, and no moveset change.
do
  Dynamax.bind({ forms = Forms, gigantamax = { CHARIZARD = "CHARIZARD_GMAX" },
                 keyitems = KeyItems, announce = Announce })
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player
  T.eq(entry.activate(battle), true, "the Dynamax still happens")
  T.eq(battler.curMoves, battler.mon.moves, "with the moveset untouched")
  T.eq(state.turns, 3, "and a real three-turn state")
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.mon, nil, "that ends on the same clock")
end

-- ---------------------------------------------------------------------
-- Through the real loader.
--
-- Everything above registers into a stub, which proves what this mod ASKS for
-- and nothing about whether the engine will take it.  These records are the
-- first this mod has ever put into `moves`, and two of their fields are checked
-- references the merge resolves after every mod has had its say: `type` into the
-- type chart and `effect` into move_effects, either of which turns into a load
-- error at this mod's api level rather than a quiet miss.  So the whole mod is
-- loaded from a synthesized filesystem and the merged registries are read back
-- the way the game would see them, the way tests/battle_forms_options_test.lua
-- does for the shop.
-- ---------------------------------------------------------------------
do
  local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local body = handle:read("*a")
    handle:close()
    return body
  end

  -- Read out of main.lua's own source rather than mirrored by hand: a hand
  -- mirror is a list that can silently disagree with the list that matters, and
  -- one missing name makes main.lua bail before it installs anything.
  local MAIN = readFile(MOD .. "/main.lua")
  local shipped = { "manifest.json", "main.lua" }
  for _, tree in ipairs({ "src", "data" }) do
    for name in MAIN:gmatch('"(' .. tree .. '/[%w_]+%.lua)"') do
      shipped[#shipped + 1] = name
    end
  end
  T.check(#shipped > 10, "main.lua's sibling list was read back out of its source")

  local files = {
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = "return function() end",
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
    fs = T.sdk.memfs(files), data = T.fixtures.fresh(),
  })
  T.eq(#run.errors, 0, "the mod loads clean with a hundred-odd new move records")

  -- The fixture set is a Red-era chart: fifteen types, so fifteen Max Moves at
  -- seven rungs each and nothing for the three modern ones.
  local chartTypes = 0
  for _ in pairs((run.data.type_chart or {}).types or {}) do
    chartTypes = chartTypes + 1
  end
  T.eq(chartTypes, 15, "precondition: the fixture chart is Red's fifteen types")

  local mine, guard = 0, nil
  for id, record in pairs(run.data.moves) do
    if id:sub(1, #MaxMoves.PREFIX) == MaxMoves.PREFIX then
      mine = mine + 1
      T.eq(record.id, id, id .. "'s record id equals its registry key")
      if id:find("MAXGUARD", 1, true) then guard = record end
    end
  end
  T.eq(mine, 15 * 7 + 1, "and the merged registry carries one record per rung")
  T.check(guard ~= nil, "with Max Guard among them")

  local flare = run.data.moves[MaxMoves.idFor("MAXFLARE", 90)]
  T.check(flare ~= nil, "MAX FLARE survived the merge")
  T.eq(flare.power, 90, "with its power")
  T.eq(flare.type, "FIRE", "and its type resolved against the chart")
  T.eq(run.data.moves[MaxMoves.idFor("MAXDARKNESS", 110)], nil,
    "and no Dark Max Move, because this chart has no Dark type to name")

  -- The effect is a checked reference too: an unresolved one would have failed
  -- the load above, but the record has to actually be there for the move to do
  -- anything.
  T.check((run.data.move_effects or {})[MaxMoves.GUARD_EFFECT] ~= nil,
    "Max Guard's effect record is in the merged registry")

  -- The animation is keyed by the move's own id, which is what the engine
  -- queues (BattleState.lua:3627).  A move with no entry there plays nothing
  -- AND makes no sound.
  local anims = (run.data.battle_anims or {}).moveAnims or {}
  for id in pairs(run.data.moves) do
    if id:sub(1, #MaxMoves.PREFIX) == MaxMoves.PREFIX then
      T.check(anims[id] ~= nil, "an animation is merged in for " .. id)
    end
  end
end

T.finish("battle_forms_maxmoves")
