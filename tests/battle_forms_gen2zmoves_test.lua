-- The eighteen type Z-Moves on Gold: the identical arm-at-the-command-menu,
-- spend-on-use, unwind-on-four-paths shape battle_forms_zmoves_test.lua
-- proves for Gen 1, driven here through src/zmoves.lua's own `deps.gen2`
-- branch -- the real src/gen2substitute.lua, never a stand-in.
--
-- What this suite is really for, beyond mirroring the Gen 1 one: proving
-- src/gen2substitute.lua under its SECOND real consumer, alongside
-- src/dynamax.lua's own Max Moves (0.52.0). That primitive's own header
-- promises a second consumer can hold an independent state while the
-- save-write veto still answers for the union of all of them -- this is
-- that promise exercised for real, including the collision case: arming one
-- while the other is live must not corrupt the moveset, and the block near
-- the end of this file proves the mechanism that guarantees it (src/arm.lua's
-- own exclusivity) rather than assuming the primitive alone would catch it.
--
-- Gold has no held-item slot to fake: a crystal reaches a Gen 2 Pokemon
-- through GIVE, which writes `mon.item` directly (src/mega.lua's and
-- src/primal.lua's own Gen 2 branches already read it the same way) -- never
-- `eligibility.stoneOf(mon)`, the Gen 1 bag stamp, which GIVE never touches.
-- That is the whole of the gap this suite exists to close: before this pass
-- src/zmoves.lua's `entry.available`/`entry.arm` read the stamp
-- unconditionally, so a Gold Pokemon genuinely holding a Z-Crystal always
-- read as not holding one.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local ZMoves = dofile(MOD .. "/src/zmoves.lua")
local Gen2Substitute = dofile(MOD .. "/src/gen2substitute.lua")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local MaxMoves = dofile(MOD .. "/src/maxmoves.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local ROWS = dofile(MOD .. "/data/zmoves.lua")
local MAXROWS = dofile(MOD .. "/data/maxmoves.lua")

local RED_TYPES = { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK",
                    "BUG", "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC",
                    "PSYCHIC_TYPE", "ICE", "DRAGON" }

local function chartOf(list)
  local chart = {}
  for _, id in ipairs(list) do chart[id] = { name = id, category = "physical" } end
  return chart
end

local function stubMod(chart)
  local buckets = { moves = {}, battle_anims = {}, move_effects = {} }
  local content = {}
  for name, bucket in pairs(buckets) do
    content[name] = { register = function(_, id, record) bucket[id] = record end }
  end
  content.type_chart = { get = function(_, id) return chart[id] end }
  return { content = content, log = { warn = function() end, error = function() end },
           registered = buckets }
end

local ELECTRIUM, WATERIUM
for _, row in ipairs(ROWS.types) do
  if row.type == "ELECTRIC" then ELECTRIUM = row.crystal end
  if row.type == "WATER" then WATERIUM = row.crystal end
end

local ZCATALOG
do
  local mod = stubMod(chartOf(RED_TYPES))
  ZMoves.bind({ substitute = nil, keyitems = KeyItems, eligibility = E,
                announce = Announce, anim = Anim, battlerof = Battlerof })
  ZCATALOG = ZMoves.install(mod, ROWS)
end

local DATA = { moves = {
  THUNDERBOLT = { id = "THUNDERBOLT", name = "THUNDERBOLT", type = "ELECTRIC",
                  power = 90, pp = 15, accuracy = 100 },
  EMBER = { id = "EMBER", name = "EMBER", type = "FIRE", power = 40, pp = 25,
            accuracy = 100 },
  THUNDERWAVE = { id = "THUNDERWAVE", name = "THUNDERWAVE", type = "ELECTRIC",
                  power = 0, pp = 20, accuracy = 100 },
} }

local function bind(log)
  ZMoves.bind({ substitute = nil, keyitems = KeyItems, eligibility = E,
                announce = Announce, anim = Anim, log = log,
                battlerof = Battlerof, gen2 = true,
                gen2substitute = Gen2Substitute })
end

bind(nil)

local function newMon(crystal)
  local moves = {
    { id = "THUNDERBOLT", pp = 15, maxPp = 15 },
    { id = "EMBER", pp = 25, maxPp = 25 },
    { id = "THUNDERWAVE", pp = 20, maxPp = 20 },
  }
  local mon = { species = "PIKACHU", level = 50, nickname = "SPARKY",
                hp = 100, moves = moves }
  if crystal then mon.item = crystal end
  return mon
end

-- The Gen 2 engine Battle shape (game/src/battle/gen2/Battle.lua): `.player`
-- IS the mon (src/battlerof.lua's own header), `.save` is where
-- src/keyitems.lua's own Gen 2 read reaches, and `.emit`/`.monName` are the
-- message channel src/announce.lua's own gen2Push/gen2Name read.
local function makeBattle(mon, ring)
  local events = {}
  local inventory = {}
  if ring ~= false then inventory[KeyItems.Z_RING] = 1 end
  return {
    data = DATA, player = mon, party = { mon }, enemyParty = {}, events = events,
    save = { inventory = inventory },
    emit = function(_, ev) events[#events + 1] = ev end,
    monName = function(_, m) return m and m.nickname end,
  }
end

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
  T.eq(mon.moves, before.moves, "the move ARRAY is the same table " .. when)
  T.eq(#mon.moves, #before.slots, "with the same number of slots " .. when)
  for index, snap in ipairs(before.slots) do
    T.eq(mon.moves[index], snap.table,
      ("slot %d is the same table %s"):format(index, when))
    for key, value in pairs(snap.keys) do
      T.eq(mon.moves[index][key], value,
        ("slot %d keeps %s %s"):format(index, key, when))
    end
  end
  for key in pairs(mon) do
    T.check(before.monKeys[key],
      "the mon carries no new key " .. when .. ": " .. tostring(key))
  end
end

-- ---------------------------------------------------------------------
-- available(): the Z-Ring off battle.save (src/keyitems.lua's Gen 2 read),
-- the crystal off mon.item (never the Gen 1 stamp).
-- ---------------------------------------------------------------------
do
  local entry = ZMoves.entry(ZMoves.new(), ZCATALOG)

  T.eq(entry.available(makeBattle(newMon(ELECTRIUM))), true,
    "the Z-Ring, a crystal on mon.item, and a move of its type is the whole "
      .. "requirement on Gold too")
  T.eq(entry.available(makeBattle(newMon(ELECTRIUM), false)), false,
    "without the Z-Ring the cell is absent")
  T.eq(entry.available(makeBattle(newMon(nil))), false,
    "without a crystal on mon.item")

  -- The gap this suite exists to close: stamping the Gen 1 field does
  -- NOTHING on Gold, because GIVE never touches it.
  local stamped = newMon(nil)
  stamped[E.STAMP] = ELECTRIUM
  T.eq(entry.available(makeBattle(stamped)), false,
    "the Gen 1 bag stamp is not read on Gold -- only mon.item, which GIVE "
      .. "actually writes")

  local wrongType = newMon(WATERIUM)
  T.eq(entry.available(makeBattle(wrongType)), false,
    "a crystal for a type nothing in the moveset carries offers nothing")
end

-- ---------------------------------------------------------------------
-- Arming: the real primitive, mutating mon.moves in place, never replacing
-- the array or a slot's own table identity.
-- ---------------------------------------------------------------------
do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, ZCATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  local before = saveSnapshot(mon)
  local slot1, slot2, slot3 = mon.moves[1], mon.moves[2], mon.moves[3]

  T.eq(entry.arm(battle), true, "arming answers that it happened")
  T.eq(mon.moves[1], slot1, "slot 1 is the SAME table, mutated in place")
  T.eq(mon.moves[1].id, ZMoves.idFor("GIGAVOLTHAVOC", 175),
    "and its id is the Electric Z-Move's")
  T.eq(mon.moves[1].maxPp, 15,
    "maxPp is THUNDERBOLT's own real maximum, not a ppUps correction -- "
      .. "Gold's FIGHT menu draws move.maxPp straight off the slot")
  T.eq(rawget(mon.moves[1], "ppUps"), nil,
    "and no ppUps field at all -- that correction is Gen 1's own")
  T.eq(mon.moves[2], slot2, "the Fire slot is untouched, same table")
  T.eq(mon.moves[2].id, "EMBER", "and its own id")
  T.eq(mon.moves[3], slot3, "the status slot is untouched too")
  T.eq(#mon.moves, 3, "the array itself was never replaced")

  entry.disarm()
  T.eq(mon.moves[1].id, "THUNDERBOLT", "disarming puts the real id back")
  T.eq(mon.moves[1].maxPp, 15, "and the real maxPp")
  assertSaveUntouched(before, mon, "after disarming")
end

-- ---------------------------------------------------------------------
-- activate(): the real Gen 2 announcement, through battle:emit.
-- ---------------------------------------------------------------------
do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, ZCATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)

  entry.arm(battle)
  T.eq(entry.activate(battle), true, "activating answers that it happened")
  T.eq(battle.events[1].text, "SPARKY\nsurrounded itself",
    "the first page names the mon through battle:emit")
  T.eq(battle.events[2].text, "with its Z-Power!", "and the second page follows")
end

-- ---------------------------------------------------------------------
-- Full cycle: armed, spent on use, restored at turn end -- never before.
-- ---------------------------------------------------------------------
do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, ZCATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  local before = saveSnapshot(mon)

  entry.arm(battle)
  entry.activate(battle)
  local zId = mon.moves[1].id

  ZMoves.onTurnEnded(state)
  T.eq(mon.moves[1].id, zId, "a turn passing with nothing used changes nothing")

  ZMoves.onMoveUsed(state, { user = mon, move = DATA.moves.EMBER, battle = battle })
  ZMoves.onTurnEnded(state)
  T.eq(mon.moves[1].id, zId, "using a different slot does not spend it")

  ZMoves.onMoveUsed(state, { user = mon, move = { id = zId }, battle = battle })
  T.eq(mon.moves[1].id, zId, "the array still stands while the move resolves")
  ZMoves.onTurnEnded(state)
  T.eq(mon.moves[1].id, "THUNDERBOLT",
    "and the real move is back by the end of the turn it was spent on")
  assertSaveUntouched(before, mon, "after the Z-Move was spent")
end

-- ---------------------------------------------------------------------
-- Every other way it ends.
-- ---------------------------------------------------------------------
for _, case in ipairs({
  { "switching out", function(state, battle, mon)
      ZMoves.onBattlerSwitched(state, { battle = battle, previous = mon })
    end },
  { "fainting", function(state, battle, mon)
      ZMoves.onFainted(state, { battle = battle, battler = mon })
    end },
  { "the battle ending", function(state) ZMoves.onBattleEnded(state) end },
  { "a battle starting", function(state) ZMoves.onBattleStarted(state) end },
}) do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, ZCATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  local before = saveSnapshot(mon)

  entry.arm(battle)
  entry.activate(battle)
  T.eq(mon.moves[1].id ~= "THUNDERBOLT", true, "armed before " .. case[1])

  case[2](state, battle, mon)
  T.eq(mon.moves[1].id, "THUNDERBOLT", case[1] .. " puts the real id back")
  T.eq(state.mon, nil, "and drops the mon reference (" .. case[1] .. ")")
  assertSaveUntouched(before, mon, "after " .. case[1])
end

-- ---------------------------------------------------------------------
-- A MID-BATTLE LEVEL-UP while a Z-Move is armed: identity-based restore
-- proven under this second consumer, the same shape
-- battle_forms_gen2dynamax_test.lua proves for Max Moves.
-- ---------------------------------------------------------------------
do
  local state = ZMoves.new()
  local entry = ZMoves.entry(state, ZCATALOG)
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)

  entry.arm(battle)
  local zId = mon.moves[1].id
  local slot2, slot3 = mon.moves[2], mon.moves[3]

  -- Battle:resolveForget drops a brand new table into slot 2; Mon.learnMove
  -- appends a brand new slot 4.  Neither is the object this module snapshotted.
  local freshSlot2 = { id = "WING_ATTACK", pp = 35, maxPp = 35 }
  mon.moves[2] = freshSlot2
  local freshSlot4 = { id = "SWIFT", pp = 20, maxPp = 20 }
  mon.moves[4] = freshSlot4

  entry.disarm()

  T.eq(mon.moves[1].id, "THUNDERBOLT",
    "slot 1's identity survived the level-up and was restored")
  T.eq(mon.moves[2], freshSlot2,
    "slot 2 is left exactly as the level-up put it -- restore does not "
      .. "clobber a table it no longer recognises")
  T.eq(mon.moves[3], slot3, "slot 3, untouched by the level-up, is restored normally")
  T.eq(mon.moves[3].id, "THUNDERWAVE", "back to its real id")
  T.eq(mon.moves[4], freshSlot4, "the appended fourth slot is completely undisturbed")
  T.eq(#mon.moves, 4, "and the array itself was never replaced")
  T.check(zId ~= "THUNDERBOLT", "precondition: arming really did substitute")
end

-- ---------------------------------------------------------------------
-- Two live substitutions, alongside src/dynamax.lua's Max Moves.  The
-- one-transformation-per-battle lock (src/arm.lua) is what prevents both
-- from ever being armed at once -- proven here through the REAL registry and
-- arm state, the same shape battle_forms_zmoves_test.lua's own "Selecting
-- away while armed" block proves for Gen 1, rather than assumed because the
-- primitive alone happens to survive it.
-- ---------------------------------------------------------------------
do
  local maxMod = stubMod(chartOf(RED_TYPES))
  local maxCatalog = MaxMoves.install(maxMod, MAXROWS)
  for id, record in pairs(maxMod.registered.moves) do DATA.moves[id] = record end

  MaxMoves.bind({ anim = Anim, announce = Announce, guard = MaxMoves.newGuard(),
                  gen2 = true })
  Dynamax.bind({ gigantamax = {}, keyitems = KeyItems, announce = Announce,
                 battlerof = Battlerof, gen2 = true, gen2substitute = Gen2Substitute,
                 maxMoves = function(data) return MaxMoves.picker(maxCatalog, data) end })

  local registry = Transforms.new()
  local dynaState, zState = Dynamax.new(), ZMoves.new()
  T.eq(registry:register(Dynamax.entry(dynaState)), true, "Dynamax registers")
  T.eq(registry:register(ZMoves.entry(zState, ZCATALOG)), true,
    "and the Z-Move takes a place of its own on the same cell")
  Overlay.bind({ registry = registry })
  Arm.bind({ registry = registry })

  local arm = Arm.new()
  local mon = newMon(ELECTRIUM)
  local battle = makeBattle(mon)
  battle.save.inventory[KeyItems.DYNAMAX_BAND] = 1
  -- Overlay.offered reads phase/queue off `uiBattle or battle` -- on a real
  -- Gold boot that is the separate UI object src/gen2menu.lua hands in, but
  -- this block is proving the arm-state interaction, not the menu wrap, so
  -- the two fields are set directly here, the same shape
  -- battle_forms_gen2dynamax_test.lua's own collision block uses.
  battle.phase = "menu"
  battle.queue = {}
  arm:onBattleStarted({ battle = battle })
  T.eq(#Overlay.offered(arm), 2, "both are on offer, so the cell cycles")

  arm:toggle(Dynamax.ID)
  T.check(mon.moves[1].id ~= "THUNDERBOLT", "arming Dynamax substitutes Max Moves")
  T.eq(Gen2Substitute.active(dynaState.moves), true,
    "Dynamax's own substitution is live")

  -- Moving the selection to the Z-Move disarms Dynamax FIRST -- the real
  -- mechanism the lock rests on -- so by the time the Z-Move's own arm() runs,
  -- nothing else is standing on this exact mon.moves array.
  arm:select(ZMoves.ID)
  T.eq(Gen2Substitute.active(dynaState.moves), false,
    "selecting away tore Dynamax's own substitution down before anything else ran")
  T.eq(mon.moves[1].id, "THUNDERBOLT",
    "so the array is the real one again, for one instant, between the two")

  arm:toggle(ZMoves.ID)
  T.eq(mon.moves[1].id, ZMoves.idFor("GIGAVOLTHAVOC", 175),
    "and the Z-Move's own arm() substitutes cleanly onto the real array")
  T.eq(Gen2Substitute.active(zState.moves), true, "the Z-Move's own state is live")
  T.eq(Gen2Substitute.active(dynaState.moves), false,
    "while Dynamax's stays inactive -- never both at once")
  T.eq(#mon.moves, 3, "one array, not two substitutions laid over each other")

  -- The reverse crossing, proven the same way.
  arm:select(Dynamax.ID)
  T.eq(Gen2Substitute.active(zState.moves), false,
    "and crossing back the other way tears the Z-Move's own substitution "
      .. "down first in turn")
  arm:toggle(Dynamax.ID)
  T.check(mon.moves[1].id ~= "THUNDERBOLT", "Dynamax arms again over the real array")
  T.eq(Gen2Substitute.active(zState.moves), false,
    "with the Z-Move still inactive")

  -- The battle ending unwinds whichever is still armed but never fired.
  arm:onBattleEnded({ battle = battle })
  T.eq(mon.moves[1].id, "THUNDERBOLT", "the battle ending gives the real array back")
  T.eq(Gen2Substitute.active(dynaState.moves), false, "with nothing left live")
  T.eq(Gen2Substitute.active(zState.moves), false, "on either side")

  bind(nil)
end

-- ---------------------------------------------------------------------
-- Without the mechanism bound at all: a degraded mod, not a broken one.
-- ---------------------------------------------------------------------
do
  ZMoves.bind({ keyitems = KeyItems, eligibility = E, battlerof = Battlerof,
                gen2 = true })
  local state = ZMoves.new()
  T.eq(state.moves, nil, "no substitution record without gen2substitute bound")
  local entry = ZMoves.entry(state, { byCrystal = {}, rows = ROWS })
  T.eq(entry.available(makeBattle(newMon(ELECTRIUM))), false, "and nothing is offered")
  bind(nil)
end

-- ---------------------------------------------------------------------
-- Through the real loader: main.lua's own wiring, not a hand mirror of it.
-- This is the assertion an unwired Gold Z-Move (main.lua never passing
-- gen2/gen2substitute into src/zmoves.lua's own bind, or the crystals never
-- selling on Gold) would fail -- confirmed by deliberate breakage while
-- building this suite: commenting out `gen2substitute =
-- m["src/gen2substitute.lua"]` from zmoves.bind in main.lua reproduces
-- exactly the failure this block exists to catch (the real move slot is
-- never substituted even though entry.arm() answers true from a refusal
-- path with nothing to apply) -- restored immediately afterward and
-- confirmed green again.
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
      '{"id":"national_dex","name":"National Dex","version":"0.0.0",'
        .. '"entry":"main.lua","games":["gen1","gen2"]}',
    ["mods/national_dex/main.lua"] = "return function() end",
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
      or err:find("text_pointers registry has no Gen 2 target", 1, true) ~= nil,
      "every load error is one of the two known gaps, not a new one: " .. err)
  end

  run.data.moves = run.data.moves or {}
  run.data.moves.THUNDERBOLT = { id = "THUNDERBOLT", name = "THUNDERBOLT",
                                 type = "ELECTRIC", power = 90, accuracy = 100,
                                 pp = 15, effect = "NO_ADDITIONAL_EFFECT" }

  local mon = { species = "PIKACHU", level = 50, nickname = "SPARKY",
                hp = 100, item = ELECTRIUM,
                moves = { { id = "THUNDERBOLT", pp = 15, maxPp = 15 } } }
  local engineBattle = { data = run.data,
                          save = { inventory = { Z_RING = 1 } },
                          player = mon, party = { mon }, enemyParty = {},
                          events = {},
                          emit = function(self, ev)
                            self.events[#self.events + 1] = ev
                          end,
                          monName = function(_, m) return m and m.nickname end }

  local zId = ZMoves.idFor("GIGAVOLTHAVOC", 175)
  T.check(run.data.moves[zId] ~= nil,
    "the real Electric Z-Move roster reached the merged registry, at the "
      .. "rung THUNDERBOLT's own 90 power earns")

  local BattleState = require("src.ui.gen2.BattleState")
  T.check(BattleState._battleFormsGen2MenuPatched == true,
    "the real Gen 2 BattleState.update was wrapped for the FORM cell")

  run.loader.events:emit("battle.started", { battle = engineBattle })

  local uiBattle = { phase = "menu", menuIndex = 1, queue = {},
                     battle = engineBattle, game = { input = nil } }
  local function press(button)
    uiBattle.game.input = { wasPressed = function(_, btn) return btn == button end }
    return BattleState.update(uiBattle, 0)
  end

  press("left")
  T.check(uiBattle._battleFormsMenuCell == true,
    "left from FIGHT reached the real cell through the real wrapped update")
  press("a")
  T.check(uiBattle._battleFormsListOpen == true, "A on the cell opened the real submenu")
  press("a")
  T.check(uiBattle._battleFormsListOpen == false, "confirming the one row closed it")

  -- Arming happens the moment the cell is confirmed, a step AHEAD of
  -- activation (src/arm.lua's own header) -- so the real move slot is already
  -- substituted here, proof the confirm inside the real submenu dispatched a
  -- real src/gen2substitute.lua apply through the real src/zmoves.lua Gen 2
  -- branch, not just a UI-only field flip.
  T.eq(mon.moves[1].id, zId,
    "the real move slot was substituted the moment the cell was confirmed, "
      .. "into the real registered Electric Z-Move id")
  T.eq(mon.moves[1].maxPp, 15,
    "carrying THUNDERBOLT's own real maxPp, not a ppUps correction")

  run.loader.events:emit("battle.turn_started", { battle = engineBattle })
  run.loader.events:emit("battle.move_used",
    { battle = engineBattle, user = mon, move = { id = zId } })
  run.loader.events:emit("battle.turn_ended", { battle = engineBattle })
  T.eq(mon.moves[1].id, "THUNDERBOLT",
    "and using it, through the real event chain, restores the real move by "
      .. "the end of that turn")

  -- Reachability: the Z-Ring and every type crystal have to actually be for
  -- sale on a fresh Gold save, the identical requirement
  -- battle_forms_gen2dynamax_test.lua already pins for the Dynamax Band.
  local MartMenu = require("src.ui.gen2.MartMenu")
  local INDIGO_PLATEAU_MART_ID = 32
  local indigoShelf = MartMenu.inventory({ lists = {} }, INDIGO_PLATEAU_MART_ID)
  local function has(list, id)
    for _, entry in ipairs(list) do if entry == id then return true end end
    return false
  end
  T.check(has(indigoShelf, "Z_RING"), "the Z-Ring is sold at the Indigo Plateau counter")
  T.check(has(indigoShelf, ELECTRIUM), ELECTRIUM .. " is sold there too")

  run.release()
end

T.finish("battle_forms_gen2zmoves")
