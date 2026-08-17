-- Dynamax and Gigantamax on Gold: the identical three-turn clock and four
-- teardown paths battle_forms_dynamax_test.lua proves for Gen 1, driven here
-- through src/dynamax.lua's own `deps.gen2` branch -- the real
-- src/gen2substitute.lua and src/gen2forms.lua primitives, never a stand-in.
--
-- What this suite is really for, beyond mirroring the Gen 1 one: proving the
-- move-substitution primitive under a REAL consumer for the first time.
-- src/gen2substitute.lua shipped in 0.49.0 wired to nothing; every assertion
-- below that snapshots `mon.moves` before and after a teardown, and the
-- mid-battle-level-up block in particular, is the primitive's own contract
-- exercised by an actual feature rather than by its own unit suite.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local Gen2Substitute = dofile(MOD .. "/src/gen2substitute.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local Deferred = dofile(MOD .. "/src/deferred.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local Gen2Mon = require("src.battle.gen2.Mon")

-- CHARIZARD has a Gigantamax and a mega both, matching the Gen 1 fixture's
-- own reason: the two mechanics have to stay out of each other's way on the
-- same mon.  PIDGEY has neither.  Gen 2 shape: baseStats splits
-- specialAttack/specialDefense (game/src/mods/Schemas.lua's gen2Fields).
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                              specialAttack = 85, specialDefense = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_GMAX = { baseStats = { hp = 78, attack = 84, defense = 78,
                                   speed = 100, specialAttack = 85,
                                   specialDefense = 85 },
                     types = { "FIRE", "FLYING" }, form = "GMAX" },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, specialAttack = 130,
                                     specialDefense = 85 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
  PIDGEY = { baseStats = { hp = 40, attack = 45, defense = 40, speed = 56,
                           specialAttack = 35, specialDefense = 35 },
             types = { "NORMAL", "FLYING" } },
} }

local GIGANTAMAX = { CHARIZARD = "CHARIZARD_GMAX" }

local DVS = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 }

local function newMon(species)
  local def = DATA.pokemon[species]
  local mon = {
    species = species, level = 50, nickname = "ZARD",
    dvs = { hp = DVS.hp, attack = DVS.attack, defense = DVS.defense,
            speed = DVS.speed, special = DVS.special },
    statExp = {},
    moves = { { id = "EMBER", pp = 25, maxPp = 25 } },
    hp = 120,
  }
  mon.stats = Gen2Mon.stats(def.baseStats, mon.dvs, mon.level, mon.statExp)
  return mon
end

-- The engine Battle shape (game/src/battle/gen2/Battle.lua): `.player` IS
-- the mon (src/battlerof.lua's own header), `.save` is where
-- src/keyitems.lua's own Gen 2 read reaches, and `.emit`/`.monName` are the
-- message channel src/announce.lua's own gen2Push/gen2Name read.
local function makeBattle(species)
  local mon = newMon(species or "CHARIZARD")
  local events = {}
  local battle = {
    data = DATA, player = mon, party = { mon }, enemyParty = {},
    events = events,
    save = { inventory = { [KeyItems.DYNAMAX_BAND] = 1 } },
    emit = function(_, ev) events[#events + 1] = ev end,
    monName = function(_, m) return m and m.nickname end,
  }
  return battle
end

local function bind(log)
  Dynamax.bind({ gigantamax = GIGANTAMAX, keyitems = KeyItems,
                 announce = Announce, log = log, battlerof = Battlerof,
                 gen2 = true, gen2forms = Gen2Forms,
                 gen2substitute = Gen2Substitute })
end

bind(nil)

-- A whole battle's worth of HP/stat facts, taken as one snapshot so every
-- teardown path can assert the same thing the same way -- the identical
-- discipline battle_forms_dynamax_test.lua's own hpSnapshot keeps, plus
-- `moves` here: Gen 2's own gen2forms.becomeForm never touches HP either
-- (that module's own header), so nothing about this changes across games.
local function snapshotOf(mon)
  return { hp = mon.hp, maxHp = mon.stats.hp, moveObjects = {
    mon.moves[1] } }
end

local function assertUntouched(before, mon, when)
  T.eq(mon.hp, before.hp, "current hp is unchanged " .. when)
  T.eq(mon.stats.hp, before.maxHp, "max hp is unchanged " .. when)
  T.eq(mon.moves[1], before.moveObjects[1],
    "the move slot is the SAME table, never replaced, " .. when)
end

-- ---------------------------------------------------------------------
-- The registry entry: available() reads the Dynamax Band off battle.save
-- (src/keyitems.lua's own Gen 2 read), exactly as the Gen 1 suite proves for
-- battle.game.save.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)

  T.eq(entry.available(makeBattle("PIDGEY")), true,
    "a species with no Gigantamax is still offered a Dynamax on Gold")
  T.eq(entry.available(makeBattle("CHARIZARD")), true,
    "and so is one with a Gigantamax")

  local banded = makeBattle("CHARIZARD")
  banded.save.inventory = {}
  T.eq(entry.available(banded), false, "no Dynamax Band, no Dynamax, on Gold too")
  banded.save.inventory = { [KeyItems.DYNAMAX_BAND] = 1 }
  T.eq(entry.available(banded), true, "buying the Band mid-save works the same way")
end

-- ---------------------------------------------------------------------
-- Three turns, then revert -- through the real gen2forms primitive.
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local mon = battle.player
  local before = snapshotOf(mon)

  T.eq(entry.activate(battle), true, "activating answers that it happened")
  T.eq(mon.species, "CHARIZARD", "the species is untouched")
  T.eq(mon.form, "GMAX", "a Gigantamax species takes the G-Max form")
  T.eq(state.turns, 3, "and the clock starts at three")
  T.eq(battle.events[1].text, "ZARD\nGigantamaxed!", "and it announces itself")
  assertUntouched(before, mon, "on activating")
  T.check(mon.stats.attack > DATA.pokemon.CHARIZARD.baseStats.attack,
    "mon.stats was actually recomputed from the Gigantamax record")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.turns, 2, "one turn down")
  T.eq(mon.form, "GMAX", "still Gigantamaxed after the first turn")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.turns, 1, "two turns down")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(mon.form, nil, "the third turn ending takes the form back off")
  T.eq(state.mon, nil, "and drops the mon reference")
  T.eq(state.turns, 0, "and the clock")
  T.eq(state.form, nil, "and the form it was holding")
  T.eq(battle.events[2].text, "ZARD's\nDynamax ended!",
    "and it says the Dynamax ended")
  assertUntouched(before, mon, "after the clock ran out")
  T.same(mon.stats,
    Gen2Mon.stats(DATA.pokemon.CHARIZARD.baseStats, mon.dvs, mon.level, mon.statExp),
    "mon.stats is real again -- recomputed off the base species, exactly the "
      .. "way gen2forms.revertMon does it")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.turns, 0, "a turn after the end changes nothing")
  T.eq(mon.form, nil, "and puts no form back on")
end

-- A species with no Gigantamax Dynamaxes plainly.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("PIDGEY")
  local mon = battle.player
  local before = snapshotOf(mon)

  T.eq(entry.activate(battle), true, "a plain Dynamax still happens")
  T.eq(mon.form, nil, "and marks no form at all")
  T.eq(state.mon, mon, "the state holds the mon")
  T.eq(battle.events[1].text, "ZARD\nDynamaxed!",
    "and announces a Dynamax, not a Gigantamax")
  assertUntouched(before, mon, "on a plain Dynamax")

  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(state.mon, nil, "and it ends on the same three-turn clock")
  assertUntouched(before, mon, "after a plain Dynamax ended")
end

-- ---------------------------------------------------------------------
-- Ends early on switching out, read off ev.previous (already the bare mon on
-- Gen 2 -- src/battlerof.lua's own header).
-- ---------------------------------------------------------------------
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local outgoing = battle.player
  local before = snapshotOf(outgoing)
  entry.activate(battle)
  T.eq(outgoing.form, "GMAX", "Gigantamaxed on turn one")

  local incoming = newMon("PIDGEY")
  battle.player = incoming
  Dynamax.onBattlerSwitched(state, { battle = battle, battler = incoming,
                                     previous = outgoing })
  T.eq(outgoing.form, nil, "switching out takes the G-Max form off the mon that left")
  T.eq(state.mon, nil, "and ends the state")
  assertUntouched(before, outgoing, "after switching out")
  T.eq(incoming.form, nil, "and never touches the mon that came in")
end

-- ---------------------------------------------------------------------
-- Ends on fainting -- and resolve.lua's own Gen 2 faint path (settle(),
-- which calls gen2forms.revertMon directly, not deferred) gets there first,
-- exactly as the Gen 1 suite proves for src/resolve.lua's own onFainted.
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  Resolve.bind({ registry = registry, battlerof = Battlerof, gen2 = true,
                 gen2forms = Gen2Forms, gigantamaxRows = GIGANTAMAX })
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local mon = battle.player
  entry.activate(battle)
  T.eq(mon.form, "GMAX", "precondition: Gigantamaxed")

  Resolve.onFainted({ battle = battle, battler = mon })
  T.eq(mon.form, nil, "resolve's Gen 2 faint handler reverted it first")
  Dynamax.onFainted(state, { battle = battle, battler = mon })
  T.eq(state.mon, nil, "and Dynamax still ends its own state behind it")
  T.eq(mon.form, nil, "without putting anything back on the mon")
end

-- ---------------------------------------------------------------------
-- The unwind leaves nothing on the mon, and nothing survives the battle --
-- Gen 2's own battle-end sweep is DEFERRED (src/deferred.lua's own header:
-- Battle:resolveFaints fires battle.ended synchronously, before the turn's
-- own display events have even been taken off the battle), so this proves
-- the same "nothing survives" guarantee across that hold rather than
-- assuming an immediate sweep the way Gen 1's own onBattleEnded gets.
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  Resolve.bind({ registry = registry, battlerof = Battlerof, gen2 = true,
                 gen2forms = Gen2Forms, gigantamaxRows = GIGANTAMAX,
                 deferred = Deferred })
  Deferred.reset()
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local mon = battle.player

  local keysBefore = {}
  for k in pairs(mon) do keysBefore[k] = true end

  entry.activate(battle)
  T.eq(mon.form, "GMAX", "Gigantamaxed")

  Resolve.onBattleEnded({ battle = battle })
  T.eq(mon.form, "GMAX", "the sweep is deferred -- not reverted the same frame")
  Dynamax.onBattleEnded(state)
  T.eq(state.mon, nil, "but Dynamax's own state ends immediately regardless")
  T.eq(state.turns, 0, "with the clock cleared")

  Deferred.tick(Deferred.HOLD_SECONDS + 0.1)
  T.eq(mon.form, nil, "and the deferred sweep took the form off once it ran")

  for k in pairs(mon) do
    T.check(keysBefore[k], "the mon carries no new key after the unwind: " .. tostring(k))
  end
  for k in pairs(keysBefore) do
    T.check(mon[k] ~= nil, "and lost none of its own: " .. tostring(k))
  end
  T.eq(rawget(mon, "form"), nil, "and `form` is absent, not merely falsy")
end

-- A battle STARTING clears a record left behind by anything that went wrong.
do
  local state = Dynamax.new()
  state.mon, state.turns, state.form = { species = "GHOST" }, 2, "GMAX"
  Dynamax.onBattleStarted(state)
  T.eq(state.mon, nil, "a new battle starts holding no mon")
  T.eq(state.turns, 0, "and no clock")
  T.eq(state.form, nil, "and no form")
end

-- ---------------------------------------------------------------------
-- A MID-BATTLE LEVEL-UP while a substitution is live must not corrupt the
-- move list.  This is src/gen2substitute.lua's own identity-based restore
-- (M.restore: "never restores by index alone, only by asking each
-- remembered table 'are you still the exact object sitting at your old
-- index'") proven under a REAL feature for the first time -- 0.49.0 shipped
-- the primitive wired to nothing.
--
-- Mon.learnMove appends a fresh slot at the end when there is room
-- (game/src/battle/gen2/Mon.lua:537-549) -- reproduced here rather than
-- called directly, since it also touches the save's move-teaching side this
-- suite has no reason to drive -- and Battle:resolveForget drops a brand new
-- table into an existing slot when a full moveset's extra move is accepted
-- (Battle.lua:3391-3397).  Both are simulated the same way
-- battle_forms_gen2substitute_test.lua's own suite does: replacing the exact
-- slot object, which is the one thing identity-based restore has to survive.
-- ---------------------------------------------------------------------
do
  local maxCatalog = { byType = {}, guard = "BATTLE_FORMS_MAXGUARD",
                       rows = { ladder = {} } }
  local data = { moves = { EMBER = { id = "EMBER", name = "EMBER",
                                     type = "FIRE", power = 40, pp = 25,
                                     effect = "NO_ADDITIONAL_EFFECT" } } }
  local guardOnly = function(slot)
    -- A minimal picker standing in for src/maxmoves.lua's own: substitutes
    -- every damaging slot into a single fake Max Move id, which is all this
    -- block needs in order to have something live to protect.
    if slot and slot.id then return { id = "BATTLE_FORMS_FAKEMAX", maxPp = 90 } end
    return nil
  end

  Dynamax.bind({ gigantamax = {}, keyitems = KeyItems, announce = Announce,
                 battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms,
                 gen2substitute = Gen2Substitute,
                 maxMoves = function() return guardOnly end })

  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("PIDGEY")
  local mon = battle.player
  mon.moves = { { id = "TACKLE", pp = 35, maxPp = 35 },
               { id = "GROWL", pp = 40, maxPp = 40 },
               { id = "SAND_ATTACK", pp = 15, maxPp = 15 } }
  local slot1, slot2, slot3 = mon.moves[1], mon.moves[2], mon.moves[3]

  T.eq(entry.arm(battle), true, "arming substitutes every slot")
  T.eq(mon.moves[1].id, "BATTLE_FORMS_FAKEMAX", "slot 1 substituted")
  T.eq(mon.moves[2].id, "BATTLE_FORMS_FAKEMAX", "slot 2 substituted")
  T.eq(mon.moves[3].id, "BATTLE_FORMS_FAKEMAX", "slot 3 substituted")
  T.eq(mon.moves[1], slot1, "still the SAME table objects, mutated in place")

  -- The level-up: Battle:resolveForget drops a BRAND NEW table into slot 2
  -- (the player chose to forget GROWL and learn WING_ATTACK over it), and
  -- Mon.learnMove appends a brand new slot 4 (there was room).  Neither of
  -- these is the object this module snapshotted.
  local freshSlot2 = { id = "WING_ATTACK", pp = 35, maxPp = 35 }
  mon.moves[2] = freshSlot2
  local freshSlot4 = { id = "SWIFT", pp = 20, maxPp = 20 }
  mon.moves[4] = freshSlot4

  entry.disarm()

  T.eq(mon.moves[1], slot1, "slot 1's identity survived and was restored")
  T.eq(mon.moves[1].id, "TACKLE", "back to its real id")
  T.eq(mon.moves[1].maxPp, 35, "and its real maxPp")

  T.eq(mon.moves[2], freshSlot2,
    "slot 2 is left EXACTLY as the level-up put it -- restore does not "
      .. "clobber a table it no longer recognises")
  T.eq(mon.moves[2].id, "WING_ATTACK",
    "the newly learned move is not silently overwritten by the move that "
      .. "used to occupy that slot")

  T.eq(mon.moves[3], slot3, "slot 3, untouched by the level-up, is restored normally")
  T.eq(mon.moves[3].id, "SAND_ATTACK", "back to its real id")

  T.eq(mon.moves[4], freshSlot4, "the appended fourth slot is completely undisturbed")
  T.eq(mon.moves[4].id, "SWIFT", "never substituted (it did not exist when arm ran) "
    .. "and never touched by restore")
  T.eq(#mon.moves, 4, "and the array itself was never replaced -- still four slots, "
    .. "the level-up's own append included")

  bind(nil)
end

-- ---------------------------------------------------------------------
-- Once per battle per trainer, and a limit that is its OWN -- the interaction
-- with mega evolution, Gen 2-shaped.
-- ---------------------------------------------------------------------
do
  local registry = Transforms.new()
  local state = Dynamax.new()
  registry:register(Mega.entry({ eligibility = E, megas = megas,
    keyitems = KeyItems, battlerof = Battlerof, gen2 = true,
    gen2forms = Gen2Forms }))
  registry:register(Dynamax.entry(state))
  Resolve.bind({ registry = registry, battlerof = Battlerof, gen2 = true,
                 gen2forms = Gen2Forms, gigantamaxRows = GIGANTAMAX })

  local battle = makeBattle("CHARIZARD")
  battle.player.item = "CHARIZARDITE_X"
  battle.save.inventory[KeyItems.KEY_STONE] = 1
  local arm = Arm.new()
  arm:onBattleStarted({ battle = battle })

  arm:toggle(Dynamax.ID)
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(arm:used(Dynamax.ID), true, "the battle records its one Dynamax")
  T.eq(arm:used(Mega.ID), false, "and spends no mega doing it")
  T.eq(battle.player.form, "GMAX", "the Gigantamax landed")

  T.eq(arm:toggle(Dynamax.ID), false, "a spent Dynamax refuses to arm again")

  T.eq(arm:toggle(Mega.ID), true, "the mega's own flag is untouched by the Dynamax")
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(battle.player.form, "MEGA_X",
    "the mega overwrote the G-Max form -- the same mega-over-Dynamax "
      .. "interaction the Gen 1 suite proves")

  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(battle.player.form, "MEGA_X", "and the Dynamax expiring leaves the mega alone")
  T.eq(state.mon, nil, "while still ending its own state")
end

-- One manual transformation per battle, across both of them, decided by
-- src/overlay.lua exactly as on Gen 1.
do
  local registry = Transforms.new()
  registry:register(Mega.entry({ eligibility = E, megas = megas,
    keyitems = KeyItems, battlerof = Battlerof, gen2 = true,
    gen2forms = Gen2Forms }))
  registry:register(Dynamax.entry(Dynamax.new()))
  Overlay.bind({ registry = registry })
  Resolve.bind({ registry = registry, battlerof = Battlerof, gen2 = true,
                 gen2forms = Gen2Forms, gigantamaxRows = GIGANTAMAX })

  local battle = makeBattle("CHARIZARD")
  battle.player.item = "CHARIZARDITE_X"
  battle.save.inventory[KeyItems.KEY_STONE] = 1
  -- Overlay.offered reads phase/queue off `uiBattle or battle` -- on a real
  -- Gold boot that is the separate UI object src/gen2menu.lua hands in
  -- (src/overlay.lua's own header), but this block is proving the arm-state
  -- interaction, not the menu wrap, so the two fields are set directly on
  -- the engine battle the same way battle_forms_dynamax_test.lua's own
  -- cellBattle() does for Gen 1's single combined object.
  battle.phase = "menu"
  battle.queue = {}
  local arm = Arm.new()
  arm:onBattleStarted({ battle = battle })

  local function labels()
    local out = {}
    for _, entry in ipairs(Overlay.offered(arm)) do out[#out + 1] = entry.label end
    return table.concat(out, ",")
  end
  T.eq(labels(), "MEGA,DYNAMAX", "precondition: both are on the cell")

  arm:toggle(Dynamax.ID)
  Resolve.onTurnStarted(arm, { battle = battle })
  T.eq(labels(), "", "the Dynamax took the mega off the cell with it")
  T.eq(arm:usedAny(), true, "the battle's one manual transformation is gone")
  T.eq(arm:used(Mega.ID), false, "without spending the mega's own flag")
end

-- ---------------------------------------------------------------------
-- Through the real loader: main.lua's own wiring, not a hand mirror of it --
-- the exact shape battle_forms_gen2menu_test.lua uses for mega and
-- Terastallization, extended to Dynamax and Max Moves.  This is the
-- assertion an unwired Gen 2 Dynamax (main.lua never passing
-- gen2substitute/gen2forms into src/dynamax.lua's own bind, or never
-- selling the Dynamax Band on Gold) would fail -- confirmed by deliberate
-- breakage while building this suite: commenting out
-- `gen2substitute = m["src/gen2substitute.lua"]` in main.lua's own
-- dynamax.bind call reproduces exactly the failure this block exists to
-- catch (arming answers true from the registry's own refusal path but the
-- real move list is never substituted, and the DYNAMAX_BAND reachability
-- check fails outright because the item was never sold either) -- restored
-- immediately afterward and confirmed green again.
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
  -- The same two pre-existing, out-of-scope gaps
  -- battle_forms_gen2menu_test.lua's own real-loader block documents and
  -- accepts -- neither is this pass's doing, and both are non-fatal.
  for _, err in ipairs(run.errors) do
    T.check(err:find("unresolved reference to move_effects", 1, true) ~= nil
      or err:find("text_pointers registry has no Gen 2 target", 1, true) ~= nil,
      "every load error is one of the two known gaps, not a new one: " .. err)
  end

  local BattleState = require("src.ui.gen2.BattleState")
  T.check(BattleState._battleFormsGen2MenuPatched == true,
    "the real Gen 2 BattleState.update was wrapped for the FORM cell")
  T.check(BattleState._battleFormsGen2MoveMenuPatched == true,
    "and BattleState.drawPanel was ALSO wrapped for the Max Move FIGHT menu "
      .. "redraw -- the assertion that a second roster failed to register "
      .. "would fail")

  run.data.pokemon = run.data.pokemon or {}
  run.data.pokemon.CHARIZARD = {
    baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                  specialAttack = 85, specialDefense = 85 },
    types = { "FIRE", "FLYING" } }
  run.data.pokemon.CHARIZARD_GMAX = {
    baseStats = { hp = 78, attack = 84, defense = 78, speed = 100,
                  specialAttack = 85, specialDefense = 85 },
    types = { "FIRE", "FLYING" }, form = "GMAX" }
  -- The stubbed national_dex mod above registers nothing at all, so EMBER's
  -- own record -- what src/maxmoves.lua's and src/gmaxmoves.lua's own
  -- M.fieldsFor read to decide power and type -- has to be seeded here the
  -- same way the two species records above are.
  run.data.moves = run.data.moves or {}
  run.data.moves.EMBER = { id = "EMBER", name = "EMBER", type = "FIRE",
                           power = 40, accuracy = 100, pp = 25,
                           effect = "NO_ADDITIONAL_EFFECT" }

  local mon = { species = "CHARIZARD", level = 50, dvs = {}, statExp = {},
                hp = 120, nickname = "ZARD",
                moves = { { id = "EMBER", pp = 25, maxPp = 25 } } }
  mon.stats = { hp = 150, attack = 84, defense = 78, speed = 100,
                specialAttack = 85, specialDefense = 85 }
  local engineBattle = { data = run.data,
                          save = { inventory = { DYNAMAX_BAND = 1 } },
                          player = mon, party = { mon }, enemyParty = {},
                          events = {},
                          emit = function(self, ev)
                            self.events[#self.events + 1] = ev
                          end,
                          monName = function(_, m) return m and m.nickname end }
  local uiBattle = { phase = "menu", menuIndex = 1, queue = {},
                     battle = engineBattle, game = { input = nil } }

  run.loader.events:emit("battle.started", { battle = engineBattle })

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
  -- activation (src/arm.lua's own header) -- so the real move list is
  -- already substituted here, before turn_started has run at all. EMBER (a
  -- 40-power Fire move) on a Gigantamax-eligible Charizard becomes
  -- G-MAX WILDFIRE at 90, the species-aware catalog winning over the
  -- ordinary MAX FLARE -- proof the confirm inside the real list dispatched
  -- a real src/gen2substitute.lua apply through the real
  -- src/dynamax.lua/src/gmaxmoves.lua Gen 2 path, not just a UI-only field
  -- flip.
  T.check(mon.moves[1].id ~= "EMBER",
    "the real move slot was substituted the moment the cell was confirmed")
  T.check(mon.moves[1].id:find("GMAXWILDFIRE", 1, true) ~= nil,
    "specifically into the real G-MAX WILDFIRE catalog entry: "
      .. tostring(mon.moves[1].id))
  T.eq(mon.moves[1].maxPp, 25,
    "and the substituted slot carries EMBER's own real maxPp, not a "
      .. "ppUps correction")

  run.loader.events:emit("battle.turn_started", { battle = engineBattle })
  T.eq(mon.form, "GMAX",
    "turn start ran the real Gigantamax the real submenu armed -- proof the "
      .. "confirm inside the real list dispatched a real arm, through the "
      .. "real src/dynamax.lua Gen 2 branch, not just a UI-only field flip")
  T.check(mon.stats.attack > 84,
    "and the real gen2forms primitive actually rewrote mon.stats for the "
      .. "Gigantamax form")

  -- Reachability: the Dynamax Band has to actually be for sale on a fresh
  -- Gold save, or none of the above is reachable outside a test fixture
  -- that hands the trainer the item directly -- the identical requirement
  -- battle_forms_gen2menu_test.lua already pins for the Key Stone, the Tera
  -- Orb, the Z-Ring and the fusion items.
  local MartMenu = require("src.ui.gen2.MartMenu")
  local INDIGO_PLATEAU_MART_ID = 32
  local indigoShelf = MartMenu.inventory({ lists = {} }, INDIGO_PLATEAU_MART_ID)
  local function has(list, id)
    for _, entry in ipairs(list) do if entry == id then return true end end
    return false
  end
  T.check(has(indigoShelf, "DYNAMAX_BAND"),
    "the Dynamax Band is sold at the Indigo Plateau counter on Gold")

  run.release()
end

bind(nil)

T.finish("battle_forms_gen2dynamax")
