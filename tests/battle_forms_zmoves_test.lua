-- Z-Moves: the roster that gets registered, the crystal that decides which
-- slots it covers, and the single use that takes it back off again.
--
-- Three things this suite is really for.  The first is that a Z-Move must be a
-- REGISTERED record, for the reason the Max Moves must: the battle reads power,
-- type, accuracy, name and PP off data.moves and never off the instance it was
-- handed, so a synthesised Z-Move is a move that cannot be used, drawn or
-- checkpointed.  The second is ONE MOVE, ONCE -- the substitution has to survive
-- the turn it was armed on, survive turns where nothing used it, and end on the
-- turn one of its moves is spent.  The third is that none of it may reach the
-- save: the party Pokemon's move array, every slot in it and the mon's whole
-- key set are compared by identity before and after every unwind path there is.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local ZMoves = dofile(MOD .. "/src/zmoves.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local Shop = dofile(MOD .. "/src/shop.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local ROWS = dofile(MOD .. "/data/zmoves.lua")
local CRYSTALS = dofile(MOD .. "/data/crystals.lua")
local MAXROWS = dofile(MOD .. "/data/maxmoves.lua")

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

local function stubMod(chart)
  local warned = {}
  local buckets = { moves = {}, battle_anims = {}, items = {},
                    item_effects = {} }
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
    log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end,
            error = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
    registered = buckets,
    order = order,
    warned = warned,
  }
end

local function bindZMoves(mod)
  ZMoves.bind({ substitute = Substitute, keyitems = KeyItems, eligibility = E,
                announce = Announce, anim = Anim, log = mod and mod.log })
end

-- ---------------------------------------------------------------------
-- The data table itself.
-- ---------------------------------------------------------------------
do
  T.eq(#ROWS.types, 18, "one row per type, which is every type there is")

  local seenType, seenStem, seenCrystal = {}, {}, {}
  for _, row in ipairs(ROWS.types) do
    T.check(not seenType[row.type], row.type .. " appears once")
    T.check(not seenStem[row.stem], row.stem .. " is a stem of its own")
    T.check(not seenCrystal[row.crystal], row.crystal .. " unlocks one type")
    seenType[row.type], seenStem[row.stem], seenCrystal[row.crystal] = true, true, true
    T.check(CRYSTALS[row.crystal] ~= nil,
      row.crystal .. " has a bag byte, without which it cannot be in a save")
    -- The name is what the FIGHT menu and the battle text print, so it has to
    -- be the move's own name and not the id wearing spaces.
    T.check(row.name:find("_", 1, true) == nil,
      row.name .. " is written as a name rather than as an id")
  end

  local indexed = 0
  for crystal in pairs(CRYSTALS) do
    indexed = indexed + 1
    T.check(seenCrystal[crystal], crystal .. " is indexed and is also a row")
  end
  T.eq(indexed, 18, "and there are exactly as many bytes as rows")

  -- The ids this file registers share src/maxmoves.lua's prefix, so the stems
  -- are the only thing keeping the two rosters apart.  A collision would be a
  -- load failure for whichever registered second.
  local maxStems = { [MAXROWS.guard.stem] = true }
  for _, row in ipairs(MAXROWS.types) do maxStems[row.stem] = true end
  for _, row in ipairs(ROWS.types) do
    T.check(not maxStems[row.stem],
      row.stem .. " is not also a Max Move stem")
  end

  -- The ladder never falls as base power rises, and its last rung takes
  -- everything: a base power with no rung under it would be a move that could
  -- not be converted at all.
  local previous = 0
  for _, rung in ipairs(ROWS.ladder) do
    T.check(rung.power >= previous, "the ladder never steps down")
    previous = rung.power
  end
  T.eq(ROWS.ladder[#ROWS.ladder].upTo, nil, "and the last rung has no ceiling")
end

-- ---------------------------------------------------------------------
-- The ladder.
-- ---------------------------------------------------------------------
do
  T.eq(ZMoves.powerFor(ROWS, 40), 100, "a weak move lands on the first rung")
  T.eq(ZMoves.powerFor(ROWS, 55), 100, "and so does one exactly on its ceiling")
  T.eq(ZMoves.powerFor(ROWS, 60), 120, "one over steps up")
  T.eq(ZMoves.powerFor(ROWS, 90), 175, "a strong move lands high")
  T.eq(ZMoves.powerFor(ROWS, 100), 180, "a hundred has a rung of its own")
  T.eq(ZMoves.powerFor(ROWS, 120), 190, "and so does the rung above it")
  T.eq(ZMoves.powerFor(ROWS, 150), 200, "and everything above the last ceiling")
  T.eq(ZMoves.powerFor(ROWS, 255), 200,
    "including a power no cartridge ever printed")
end

-- ---------------------------------------------------------------------
-- Registration: one record per type per rung, with an animation beside it.
-- ---------------------------------------------------------------------
local CATALOG
do
  local mod = stubMod(chartOf(RED_TYPES))
  bindZMoves(mod)
  CATALOG = ZMoves.install(mod, ROWS)

  local rungs = {}
  for _, rung in ipairs(ROWS.ladder) do rungs[rung.power] = true end
  local rungCount = 0
  for _ in pairs(rungs) do rungCount = rungCount + 1 end

  local moves = 0
  for id, record in pairs(mod.registered.moves) do
    moves = moves + 1
    T.eq(record.id, id, id .. "'s record id equals its registry key")
    T.eq(record.accuracy, 100, "and it is registered at full accuracy")
    T.eq(record.pp, ZMoves.RECORD_PP, "with the record PP the menu formula wants")
    T.eq(record.effect, "NO_ADDITIONAL_EFFECT", "and no effect of its own")
    T.eq(record.category, nil,
      "and no category, so Gen 1 decides physical or special by type")
    T.check(record.power > 0, "a Z-Move always has power")
    T.check(mod.registered.battle_anims[id] ~= nil,
      "an animation is registered under " .. id .. ", which is the anim key")
  end
  T.eq(moves, #RED_TYPES * rungCount,
    "one record per rung per type this game's chart carries")

  -- The three modern types are absent and SAID to be absent: nothing
  -- downstream would ever notice a type that failed to register, because the
  -- cell is offered off the crystal and not off the roster.
  for _, typeId in ipairs(MODERN_TYPES) do
    local found = false
    for _, line in ipairs(mod.warned) do
      if line:find(typeId, 1, true) then found = true end
    end
    T.check(found, "the missing " .. typeId .. " Z-Move is reported")
  end
  T.eq(#mod.warned, #MODERN_TYPES, "and nothing else is")

  local electric
  for _, row in ipairs(ROWS.types) do
    if row.type == "ELECTRIC" then electric = row end
  end
  local havoc = mod.registered.moves[ZMoves.idFor(electric.stem, 175)]
  T.check(havoc ~= nil, "the Electric Z-Move registered")
  T.eq(havoc.name, electric.name, "under the move data's own name")
  T.eq(havoc.type, "ELECTRIC", "and its own type")
  T.eq(havoc.power, 175, "at the rung its id names")
  T.eq(CATALOG.byCrystal[electric.crystal].type, "ELECTRIC",
    "and the catalog reaches it through the crystal that unlocks it")
end

-- With the modern chart the other three arrive and nothing is logged.
do
  local all = {}
  for _, id in ipairs(RED_TYPES) do all[#all + 1] = id end
  for _, id in ipairs(MODERN_TYPES) do all[#all + 1] = id end
  local mod = stubMod(chartOf(all))
  bindZMoves(mod)
  local catalog = ZMoves.install(mod, ROWS)
  T.eq(#mod.warned, 0, "a modern chart leaves nothing to warn about")
  for _, row in ipairs(ROWS.types) do
    T.check(catalog.byCrystal[row.crystal] ~= nil,
      row.crystal .. " unlocks a type on a modern chart")
  end
end

-- A build whose registry offers no `get` leaves the roster out rather than
-- taking the mod down with a nil call.
do
  local mod = stubMod({})
  mod.content.type_chart = {}
  bindZMoves(mod)
  local catalog = ZMoves.install(mod, ROWS)
  T.eq(next(catalog.byCrystal), nil, "no chart courtesy, no Z-Moves")
  T.eq(next(mod.registered.moves), nil, "and nothing registered")
end

-- ---------------------------------------------------------------------
-- Which slots a crystal covers.
-- ---------------------------------------------------------------------
local DATA = { moves = {
  THUNDERBOLT  = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90, pp = 15 },
  THUNDERSHOCK = { id = "THUNDERSHOCK", type = "ELECTRIC", power = 40, pp = 30 },
  THUNDERWAVE  = { id = "THUNDERWAVE", type = "ELECTRIC", power = 0, pp = 20 },
  EMBER        = { id = "EMBER", type = "FIRE", power = 40, pp = 25 },
  GROWL        = { id = "GROWL", type = "NORMAL", power = 0, pp = 40 },
} }

local ELECTRIUM, FIRIUM, FAIRIUM
for _, row in ipairs(ROWS.types) do
  if row.type == "ELECTRIC" then ELECTRIUM = row.crystal end
  if row.type == "FIRE" then FIRIUM = row.crystal end
  if row.type == "FAIRY" then FAIRIUM = row.crystal end
end

do
  local bolt = ZMoves.fieldsFor(CATALOG, DATA, { id = "THUNDERBOLT", pp = 15 },
                                ELECTRIUM)
  T.check(bolt ~= nil, "a damaging move of the crystal's type converts")
  T.eq(bolt.id, ZMoves.idFor("GIGAVOLTHAVOC", 175),
    "into the rung its base power earns")

  local shock = ZMoves.fieldsFor(CATALOG, DATA, { id = "THUNDERSHOCK", pp = 30 },
                                 ELECTRIUM)
  T.eq(shock.id, ZMoves.idFor("GIGAVOLTHAVOC", 100),
    "a weaker move of the same type converts to a weaker rung")

  T.eq(ZMoves.fieldsFor(CATALOG, DATA, { id = "EMBER", pp = 25 }, ELECTRIUM),
    nil, "a move of another type keeps itself")
  T.eq(ZMoves.fieldsFor(CATALOG, DATA, { id = "THUNDERWAVE", pp = 20 },
                        ELECTRIUM),
    nil, "and so does a status move of the crystal's own type")
  T.eq(ZMoves.fieldsFor(CATALOG, DATA, { id = "NOSUCHMOVE", pp = 5 }, ELECTRIUM),
    nil, "a move the registry cannot resolve converts to nothing")
  T.eq(ZMoves.fieldsFor(CATALOG, DATA, { id = "EMBER", pp = 25 }, FAIRIUM),
    nil, "and a crystal for a type this chart has never heard of converts nothing")
  T.eq(ZMoves.fieldsFor(CATALOG, DATA, { id = "EMBER", pp = 25 }, "NOT_A_CRYSTAL"),
    nil, "as does something that is not a crystal at all")

  -- The FIGHT menu draws a maximum off the record, so the substitute carries
  -- the correction that makes it read the base move's own maximum back.
  T.eq(bolt.ppUps, 15 - ZMoves.RECORD_PP,
    "the substitute reports the base move's PP maximum to the menu")
  local upped = ZMoves.fieldsFor(CATALOG, DATA,
                                 { id = "THUNDERBOLT", pp = 24, ppUps = 3 },
                                 ELECTRIUM)
  T.eq(upped.ppUps, 15 + 3 * 3 - ZMoves.RECORD_PP,
    "and a PP-upped slot's maximum, not the record's")
  T.eq(rawget(bolt, "pp"), nil,
    "and no PP of its own -- that is the slot's, and only the slot's")
end

-- ---------------------------------------------------------------------
-- The battle: arming, using, and every path that takes it back off.
-- ---------------------------------------------------------------------
ZMoves.bind({ substitute = Substitute, keyitems = KeyItems, eligibility = E,
              announce = Announce, anim = Anim, log = nil })

local function newMon(crystal)
  local moves = {
    { id = "THUNDERBOLT", pp = 15 },
    { id = "EMBER", pp = 25 },
    { id = "THUNDERWAVE", pp = 20 },
  }
  local mon = { species = "PIKACHU", hp = 100, moves = moves }
  if crystal then mon[E.STAMP] = crystal end
  return mon
end

local function makeBattle(mon, ring)
  local battler = { isPlayer = true, name = "PIKACHU", mon = mon,
                    curMoves = mon.moves }
  local inventory = {}
  if ring ~= false then inventory[KeyItems.Z_RING] = 1 end
  return {
    phase = "menu", queue = {}, data = DATA, player = battler,
    game = { save = { inventory = inventory, party = { mon } } },
    say = function(self, line) self.said[#self.said + 1] = line end,
    sayNext = function(self, line) self.said[#self.said + 1] = line end,
    said = {},
  }
end

-- Everything the save keeps about this Pokemon, taken as one snapshot so every
-- teardown path below asserts the same thing the same way.
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

-- ------- when the cell is offered -------------------------------------
do
  local entry = ZMoves.entry(ZMoves.new(), CATALOG)
  T.eq(entry.id, "zmove", "the entry has its own id")
  T.eq(entry.label, "Z-MOVE", "and the label the cell draws")

  T.eq(entry.available(makeBattle(newMon(ELECTRIUM))), true,
    "a Z-Ring, a crystal and a move of its type is the whole requirement")
  T.eq(entry.available(makeBattle(newMon(ELECTRIUM), false)), false,
    "without the Z-Ring the cell is simply absent")
  T.eq(entry.available(makeBattle(newMon(nil))), false,
    "and without a crystal on the Pokemon")
  T.eq(entry.available(makeBattle(newMon(FIRIUM))), true,
    "a crystal whose type the moveset does carry is offered")

  -- The menu must not promise a change the activation can only refuse, which
  -- is the whole reason `available` reads the moveset at all.
  local statusOnly = newMon(ELECTRIUM)
  statusOnly.moves = { { id = "THUNDERWAVE", pp = 20 }, { id = "GROWL", pp = 40 } }
  local battle = makeBattle(statusOnly)
  battle.player.curMoves = statusOnly.moves
  T.eq(entry.available(battle), false,
    "a crystal with nothing to convert is not offered")

  local wrongType = newMon(FAIRIUM)
  T.eq(entry.available(makeBattle(wrongType)), false,
    "nor is one for a type this game's chart never registered")
end

-- ------- arming, and what the battler shows afterwards -----------------
do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  local battler = battle.player
  local before = saveSnapshot(mon)

  T.eq(entry.activate(battle), true, "arming answers that it happened")
  T.check(battler.curMoves ~= mon.moves,
    "the battler is holding an array the battle owns")
  T.eq(battler.curMoves[1].id, ZMoves.idFor("GIGAVOLTHAVOC", 175),
    "with the Electric slot converted")
  T.eq(battler.curMoves[2], mon.moves[2],
    "the Fire slot is the SAME table, so its PP was never rerouted")
  T.eq(battler.curMoves[3], mon.moves[3], "and so is the status slot")
  assertSaveUntouched(before, mon, "while a Z-Move is armed")

  -- PP is the one field that still reaches the mon, because spending a turn of
  -- that move is exactly what happened.
  T.eq(battler.curMoves[1].pp, 15, "the substitute reads the slot's PP")
  battler.curMoves[1].pp = battler.curMoves[1].pp - 1
  T.eq(mon.moves[1].pp, 14, "and spending it spends the slot")
  mon.moves[1].pp = 15

  T.eq(battle.said[1], "PIKACHU\nsurrounded itself", "the first page is queued")
  T.eq(battle.said[2], "with its Z-Power!", "and the second says what happened")

  -- A turn on which nothing was used changes nothing: there is no clock here.
  ZMoves.onTurnEnded(state)
  T.check(battler.curMoves ~= mon.moves,
    "a turn passing does not take a Z-Move away")

  -- A move that is not the Z-Move does not spend it either.
  ZMoves.onMoveUsed(state, { user = battler, move = DATA.moves.EMBER })
  ZMoves.onTurnEnded(state)
  T.check(battler.curMoves ~= mon.moves,
    "and neither does using another slot")

  -- The Z-Move itself does, at the end of the turn it was used on rather than
  -- in the middle of it.
  ZMoves.onMoveUsed(state,
    { user = battler, move = { id = ZMoves.idFor("GIGAVOLTHAVOC", 175) } })
  T.check(battler.curMoves ~= mon.moves,
    "the array still stands while the move is resolving")
  ZMoves.onTurnEnded(state)
  T.eq(battler.curMoves, mon.moves,
    "and the Pokemon's own array is back by the end of that turn")
  assertSaveUntouched(before, mon, "after the Z-Move was spent")

  -- One move, once: nothing re-arms itself.
  ZMoves.onMoveUsed(state,
    { user = battler, move = { id = ZMoves.idFor("GIGAVOLTHAVOC", 175) } })
  ZMoves.onTurnEnded(state)
  T.eq(battler.curMoves, mon.moves, "and a second use finds nothing to end")
end

-- A Z-Move used by somebody else's Pokemon does not spend this one.
do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  entry.activate(battle)

  ZMoves.onMoveUsed(state, { user = { mon = newMon(ELECTRIUM) },
                             move = { id = ZMoves.idFor("GIGAVOLTHAVOC", 175) } })
  ZMoves.onTurnEnded(state)
  T.check(battle.player.curMoves ~= mon.moves,
    "another battler's Z-Move is not this battler's")
end

-- ------- every other way it ends --------------------------------------
for _, case in ipairs({
  { "switching out", function(state, battle, mon)
      ZMoves.onBattlerSwitched(state, { battle = battle,
                                        previous = battle.player })
    end },
  { "fainting", function(state, battle)
      ZMoves.onFainted(state, { battle = battle, battler = battle.player })
    end },
  { "the battle ending", function(state) ZMoves.onBattleEnded(state) end },
  { "a battle starting", function(state) ZMoves.onBattleStarted(state) end },
}) do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  local before = saveSnapshot(mon)

  T.eq(entry.activate(battle), true, "armed before " .. case[1])
  case[2](state, battle, mon)
  T.eq(battle.player.curMoves, mon.moves,
    case[1] .. " puts the Pokemon's own array back")
  T.eq(state.mon, nil, "and holds no mon reference afterwards (" .. case[1] .. ")")
  assertSaveUntouched(before, mon, "after " .. case[1])
end

-- Switching a DIFFERENT Pokemon out leaves this one armed: the event names the
-- battler that left, and it is not this one.
do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, CATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  entry.activate(battle)
  ZMoves.onBattlerSwitched(state, { battle = battle,
                                    previous = { mon = newMon(ELECTRIUM) } })
  T.check(battle.player.curMoves ~= mon.moves,
    "somebody else leaving the field is not this Pokemon leaving it")
end

-- Without the mechanism bound at all there is no roster, no cell and nothing
-- to unwind -- a degraded mod rather than a broken one.
do
  ZMoves.bind({ keyitems = KeyItems, eligibility = E })
  local state = ZMoves.new()
  T.eq(state.moves, nil, "no substitution record without the mechanism")
  local entry = ZMoves.entry(state, { byCrystal = {}, rows = ROWS })
  T.eq(entry.available(makeBattle(newMon(ELECTRIUM))), false,
    "and nothing is offered")
  ZMoves.bind({ substitute = Substitute, keyitems = KeyItems, eligibility = E,
                announce = Announce, anim = Anim })
end

-- ---------------------------------------------------------------------
-- The registry, and the trainer's one transformation per battle.
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)
  local state = ZMoves.new()
  T.eq(registry:register(Mega.entry({ eligibility = E, megas = megas,
                                      keyitems = KeyItems, forms = Forms })),
    true, "mega evolution registers first, as it ships")
  T.eq(registry:register(ZMoves.entry(state, CATALOG)), true,
    "and the Z-Move takes a place of its own on the same cell")

  Overlay.bind({ registry = registry })
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas })

  local arm = Arm.new()
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  arm:onBattleStarted({ battle = battle })

  local offered = Overlay.offered(arm)
  T.eq(#offered, 1, "only the Z-Move is on offer -- there is no mega stone here")
  T.eq(offered[1].id, ZMoves.ID, "and it is the entry this file registered")

  T.eq(arm:toggle(ZMoves.ID), true, "arming the cell marks it")
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(arm:used(ZMoves.ID), true, "resolving spends the Z-Move")
  T.eq(arm:usedAny(), true, "and the trainer's one transformation with it")
  T.eq(#Overlay.offered(arm), 0,
    "so the cell is empty for the rest of the battle")

  -- A refusal must not spend it: the player armed in good faith.
  local refused = Arm.new()
  local bare = makeBattle(newMon(nil))
  refused:onBattleStarted({ battle = bare })
  refused:toggle(ZMoves.ID)
  Resolve.onTurnStarted(refused, { battle = bare })
  T.eq(refused:used(ZMoves.ID), false, "a refused activation spends nothing")
  T.eq(refused:usedAny(), false, "and leaves the battle's transformation intact")
end

-- ---------------------------------------------------------------------
-- The crystals as bag items, and the shelf they stand on.
-- ---------------------------------------------------------------------
do
  local mod = stubMod(chartOf(RED_TYPES))
  Stone.bind(E)
  Stone.installUnpaired(mod, ZMoves.crystalIds(ROWS), CRYSTALS)

  T.eq(#mod.warned, 0, "a complete index table installs without complaint")
  local count = 0
  for _, crystal in ipairs(ZMoves.crystalIds(ROWS)) do
    count = count + 1
    local record = mod.registered.items[crystal]
    T.check(record ~= nil, crystal .. " is registered as an item")
    T.eq(record.index, CRYSTALS[crystal], "with its permanent bag byte")
    T.eq(record.price, Stone.PRICE, "and the price a stone and an orb sell for")
    T.eq(record.name, crystal:gsub("_", " "), "and a readable name")
    T.eq(record.needsTarget, true, "it is used on a Pokemon")
    T.check(mod.registered.item_effects[crystal] ~= nil, "through an effect")
    T.eq(mod.registered.item_effects[crystal].battle, false,
      "which is a field decision rather than a battle action")
  end
  T.eq(count, 18, "all eighteen were checked")

  -- Every species may carry one, which is the whole difference between this
  -- and a mega stone: there is no pairing table to be missing from.
  local use = mod.registered.item_effects[ELECTRIUM].use
  local mon = { species = "MAGIKARP" }
  T.eq(use({ target = mon }), "kept", "a crystal is kept rather than consumed")
  T.eq(E.stoneOf(mon), ELECTRIUM, "and stamps the Pokemon it was used on")

  -- One stamp, so a crystal replaces a mega stone rather than joining it --
  -- which is the held-item slot the real games have.
  mon[E.STAMP] = "CHARIZARDITE_X"
  use({ target = mon })
  T.eq(E.stoneOf(mon), ELECTRIUM,
    "a Pokemon holds one item: the crystal takes the stone's place")
  T.eq(use({ target = nil }), "failed", "and nothing to use it on is refused")

  -- An id with no byte cannot exist in a Gen 1 save, so it is refused aloud.
  local bare = stubMod(chartOf(RED_TYPES))
  Stone.installUnpaired(bare, { "NOSUCHIUM_Z" }, CRYSTALS)
  T.eq(bare.registered.items.NOSUCHIUM_Z, nil, "an unindexed crystal is not registered")
  T.eq(#bare.warned, 1, "and the refusal is reported")
  T.check(bare.warned[1]:find("data/crystals.lua", 1, true) ~= nil,
    "naming the file to fix it in")
end

-- The shelf, through the real registry: the crystals join the key items at the
-- head of the Celadon floor and the floor's own stock survives underneath.
do
  local Registry = require("src.mods.Registry")
  local Schemas = require("src.mods.Schemas")
  local keyIndices = dofile(MOD .. "/data/keyitems.lua")

  local base = { CeladonMart4F = { TEXT_CELADONMART4F_CLERK = {
    label = "CeladonMart4FClerkText",
    mart = { "POKE_DOLL", "FIRE_STONE" },
  } } }
  local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
  reg.base = function() return base end
  local mod = { content = { text_pointers = {
    patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
  } } }

  Shop.installKeyItems(mod, keyIndices)
  Shop.installCrystals(mod, CRYSTALS)

  local mart = reg:get("CeladonMart4F").TEXT_CELADONMART4F_CLERK.mart
  T.eq(#mart, 2 + #KeyItems.ITEMS + 18,
    "the floor's own stock, the key items and every crystal")
  T.eq(mart[1], "POKE_DOLL", "the floor's own stock stays at the front")
  T.eq(mart[3], KeyItems.KEY_STONE, "the key items come next, by bag byte")
  T.eq(mart[3 + #KeyItems.ITEMS], "NORMALIUM_Z",
    "and the crystals behind them, in the order their bytes were handed out")
  T.eq(mart[#mart], "FAIRIUM_Z", "down to the last one")
end

-- ---------------------------------------------------------------------
-- Through the real loader.
--
-- Everything above registers into a stub, which proves what this mod ASKS for
-- and nothing about whether the engine will take it.  `type` is a checked
-- reference the merge resolves after every mod has had its say, and an
-- unresolved one is a load ERROR at this mod's api level rather than a quiet
-- miss -- so the whole mod is loaded from a synthesized filesystem and the
-- merged registries are read back the way the game would see them.
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
  T.eq(#run.errors, 0, "the mod loads clean with both rosters registered")

  local stems = {}
  for _, row in ipairs(ROWS.types) do stems[row.stem] = row end
  local rungs = {}
  for _, rung in ipairs(ROWS.ladder) do rungs[rung.power] = true end
  local rungCount = 0
  for _ in pairs(rungs) do rungCount = rungCount + 1 end

  local mine = 0
  for id, record in pairs(run.data.moves) do
    local stem = id:match("^" .. ZMoves.PREFIX .. "(%u+)")
    local row = stem and stems[stem]
    if row then
      mine = mine + 1
      T.eq(record.type, row.type, id .. "'s type resolved against the chart")
      T.check((run.data.battle_anims or {}).moveAnims[id] ~= nil,
        "and its animation is merged in under the same id")
    end
  end
  -- The fixture set is a Red-era chart, so fifteen types get a roster.
  T.eq(mine, #RED_TYPES * rungCount,
    "the merged registry carries one Z-Move record per rung per resolvable type")

  local fairy
  for _, row in ipairs(ROWS.types) do
    if row.type == "FAIRY" then fairy = row end
  end
  T.eq(run.data.moves[ZMoves.idFor(fairy.stem, 200)], nil,
    "and no Fairy Z-Move, because this chart has no Fairy type to name")

  -- The items are the other half: a crystal that failed to register would be a
  -- bag byte an existing save could no longer resolve.
  for _, crystal in ipairs(ZMoves.crystalIds(ROWS)) do
    T.check(run.data.items[crystal] ~= nil,
      crystal .. " survived the merge even where its type did not")
    T.check(run.data.item_effects[crystal] ~= nil, "with its effect beside it")
  end
  T.check(run.data.items[KeyItems.Z_RING] ~= nil, "and so did the Z-Ring")
end

T.finish("battle_forms_zmoves")
