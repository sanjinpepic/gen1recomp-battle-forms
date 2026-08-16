-- Ultra Burst: the last unimplemented in-battle gimmick, and the one gated on
-- three things standing together -- the Z-Ring, Ultranecrozium Z on the mon,
-- and a fusion src/fusion.lua already made true of it -- rather than the two
-- every other gated mechanic here checks.
--
-- Half of this suite is about the three gates refusing independently (no cell
-- promised when any one of them is missing), and the other half is about the
-- unwind landing on the FUSED baseline rather than on a plain Necrozma: Ultra
-- Burst reverts to whichever of Dusk Mane or Dawn Wings it burst from, because
-- the fusion itself never stopped being true, and only src/fusion.lua's own
-- settle -- already wired into src/resolve.lua -- can say so.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local UltraBurst = dofile(MOD .. "/src/ultraburst.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Menu = dofile(MOD .. "/src/menu.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local Tera = dofile(MOD .. "/src/tera.lua")
local ZMoves = dofile(MOD .. "/src/zmoves.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local ultraRows = dofile(MOD .. "/data/ultraburst.lua")
local fusionRows = dofile(MOD .. "/data/fusion.lua")
local zRows = dofile(MOD .. "/data/zmoves.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)

local DATA = { pokemon = {
  NECROZMA = { name = "NECROZMA",
               baseStats = { hp = 97, attack = 107, defense = 101,
                             speed = 79, special = 127 },
               types = { "PSYCHIC" } },
  NECROZMA_DUSK = { name = "NECROZMA DUSK",
                    baseStats = { hp = 97, attack = 157, defense = 127,
                                  speed = 77, special = 113 },
                    types = { "PSYCHIC" }, form = "DUSK" },
  NECROZMA_DAWN = { name = "NECROZMA DAWN",
                    baseStats = { hp = 97, attack = 113, defense = 89,
                                  speed = 79, special = 137 },
                    types = { "PSYCHIC", "GHOST" }, form = "DAWN" },
  NECROZMA_ULTRA = { name = "NECROZMA ULTRA",
                     baseStats = { hp = 97, attack = 167, defense = 97,
                                   speed = 129, special = 167 },
                     types = { "PSYCHIC", "DRAGON" }, form = "ULTRA" },
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

local function newMon(opts)
  opts = opts or {}
  local mon = { species = "NECROZMA", level = 60,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
                statExp = {}, hp = 250,
                moves = { { id = "CONFUSION", pp = 25 } } }
  mon.stats = { hp = 97, attack = 107, defense = 101, speed = 79, special = 127 }
  if opts.fused then mon[Fusion.STAMP] = opts.fused end
  if opts.crystal then mon[E.STAMP] = opts.crystal end
  return mon
end

local function battlerFor(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, name = mon.species,
           curStats = mon.stats, curTypes = DATA.pokemon[mon.species].types }
end

local function makeInput(pressed)
  return { wasPressed = function(_, btn) return (pressed or {})[btn] == true end }
end

local function makeBattle(mon, bag)
  local battle = {
    phase = "menu", menuIndex = 1, queue = {}, data = DATA,
    player = battlerFor(mon, true),
    game = { save = { party = { mon }, inventory = bag or {} },
             input = makeInput({}) },
    enemyParty = {},
    animationsOn = function() return false end,
  }
  battle.say = function(self, line)
    self.queue[#self.queue + 1] = { text = line }
  end
  battle.sayNext = function(self, line)
    self.nextInsert = (self.nextInsert or 0) + 1
    table.insert(self.queue, self.nextInsert, { text = line })
  end
  battle.animNext = function(self, name)
    self.nextInsert = (self.nextInsert or 0) + 1
    table.insert(self.queue, self.nextInsert, { anim = name })
  end
  return battle
end

local function makeLog()
  local lines = {}
  return { warn = function(_, fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end,
           error = function(_, fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end },
         lines
end

local function bind(log)
  Fusion.bind({ forms = Forms, rows = fusionRows, log = log,
                battlerof = Battlerof })
  UltraBurst.bind({ forms = Forms, eligibility = E, fusion = Fusion,
                     keyitems = KeyItems, rows = ultraRows,
                     animId = Anim.ID, announce = Announce, log = log,
                     battlerof = Battlerof })
end

local ZRING = { [KeyItems.Z_RING] = 1 }

-- ---------------------------------------------------------------------
-- The three gates, refusing independently and silently.
-- ---------------------------------------------------------------------
do
  bind(nil)
  local entry = UltraBurst.entry(UltraBurst.new())

  local burstReady = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  T.eq(entry.available(makeBattle(burstReady, ZRING)), true,
    "all three gates satisfied: the cell is offered")

  local noRing = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  T.eq(entry.available(makeBattle(noRing, {})), false,
    "no Z-Ring: refused even though the mon is fused and holding the crystal")

  local noCrystal = newMon({ fused = "SOLGALEO" })
  T.eq(entry.available(makeBattle(noCrystal, ZRING)), false,
    "no Ultranecrozium Z: refused even with the Z-Ring and the fusion")

  local plainCrystal = newMon({ fused = "SOLGALEO", crystal = "PSYCHIUM_Z" })
  T.eq(entry.available(makeBattle(plainCrystal, ZRING)), false,
    "a type Z-Crystal is not Ultranecrozium Z: still refused")

  local notFused = newMon({ crystal = "ULTRANECROZIUM_Z" })
  T.eq(entry.available(makeBattle(notFused, ZRING)), false,
    "not yet fused: a plain Necrozma holding the crystal is refused")

  local dawnFused = newMon({ fused = "LUNALA", crystal = "ULTRANECROZIUM_Z" })
  T.eq(entry.available(makeBattle(dawnFused, ZRING)), true,
    "Dawn Wings (fused with Lunala) is offered exactly as Dusk Mane is")

  local charizard = { species = "CHARIZARD", level = 50,
                      dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
                      statExp = {}, [E.STAMP] = "ULTRANECROZIUM_Z" }
  charizard.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  T.eq(entry.available(makeBattle(charizard, ZRING)), false,
    "some other species holding the crystal is refused -- it pairs with "
      .. "Necrozma alone")
end

-- ---------------------------------------------------------------------
-- Activation: the form, the stats, the types, the message and the animation.
-- ---------------------------------------------------------------------
do
  bind(nil)
  local state = UltraBurst.new()
  local entry = UltraBurst.entry(state)
  local mon = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local battle = makeBattle(mon, ZRING)

  T.eq(entry.activate(battle), true, "activation succeeds")
  T.eq(mon.form, "ULTRA", "the mon is marked with the ULTRA form")
  T.eq(mon.species, "NECROZMA", "the species is never touched")
  T.check(battle.player.curStats.attack > mon.stats.attack,
    "curStats follow Ultra Necrozma's own, higher, base attack")
  T.eq(battle.player.curTypes[2], "DRAGON", "curTypes follow it too")
  T.eq(mon.stats.attack, 107, "the save's own stat block is untouched")

  T.eq(#battle.queue, 2, "the two-page message is queued")
  T.eq(battle.queue[1].text, "NECROZMA\nregained its true",
    "the first page reads the mainline games' own opening")
  T.eq(battle.queue[2].text, "power through\nUltra Burst!",
    "and the second finishes the sentence")
  for _, page in ipairs(battle.queue) do
    for line in (page.text .. "\n"):gmatch("([^\n]*)\n") do
      T.check(#line <= 18, "'" .. line .. "' fits the 18-character battle row")
    end
  end

  -- Animations off by default in this fixture; on, it queues the shared
  -- form-change id the way mega evolution's activation does.
  local animated = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local animBattle = makeBattle(animated, ZRING)
  animBattle.animationsOn = function() return true end
  local queued = {}
  animBattle.animNext = function(_, id) queued[#queued + 1] = id end
  UltraBurst.entry(UltraBurst.new()).activate(animBattle)
  T.eq(#queued, 1, "battle animations on: the change queues its animation")
  T.eq(queued[1], Anim.ID, "and it is the shared form-change id")

  local noAnim = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local noAnimBattle = makeBattle(noAnim, ZRING)
  UltraBurst.entry(UltraBurst.new()).activate(noAnimBattle)
  T.eq(#noAnimBattle.queue, 2, "animations off: the change still happens")
end

-- A missing national_dex record refuses out loud, the same shape of mistake
-- mega evolution's own refusal guards against.
do
  local log, lines = makeLog()
  bind(log)
  local state = UltraBurst.new()
  local entry = UltraBurst.entry(state)
  local mon = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local battle = makeBattle(mon, ZRING)
  battle.data = { pokemon = { NECROZMA = DATA.pokemon.NECROZMA } }

  T.eq(entry.available(battle), false,
    "available also refuses -- the menu must not promise what activation cannot do")
  T.eq(entry.activate(battle), false, "a missing record refuses the activation")
  T.eq(mon.form, nil, "and marks nothing")
  T.eq(#lines, 1, "the refusal is logged")
  T.check(lines[1]:find("NECROZMA_ULTRA", 1, true) ~= nil,
    "naming the form id that could not be found")
end

-- ---------------------------------------------------------------------
-- Interaction: holding Ultranecrozium Z must not also offer a Z-Move.
-- ---------------------------------------------------------------------
do
  local function chartOf(list)
    local chart = {}
    for _, id in ipairs(list) do chart[id] = { name = id, category = "special" } end
    return chart
  end
  local chart = chartOf({ "PSYCHIC_TYPE" })
  local mod = {
    content = {
      moves = { register = function() end },
      battle_anims = { register = function() end },
      type_chart = { get = function(_, id) return chart[id] end },
    },
    log = nil,
  }
  local catalog = ZMoves.install(mod, zRows)
  ZMoves.bind({ substitute = Substitute, keyitems = KeyItems, eligibility = E,
                announce = Announce, anim = Anim, log = nil,
                battlerof = Battlerof })

  local mon = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  mon.moves = { { id = "CONFUSION", pp = 25 } }
  local battlerData = { moves = { CONFUSION = { type = "PSYCHIC_TYPE", power = 50 } } }
  local battler = { isPlayer = true, mon = mon, curMoves = mon.moves }

  T.eq(ZMoves.wouldConvert(catalog, battlerData, battler, "ULTRANECROZIUM_Z"),
    false, "Ultranecrozium Z converts nothing -- it is not one of the "
      .. "eighteen type crystals src/zmoves.lua's catalog carries")

  local zEntry = ZMoves.entry(ZMoves.new(), catalog)
  local battle = makeBattle(mon, ZRING)
  battle.data = { moves = battlerData.moves, pokemon = DATA.pokemon }
  T.eq(zEntry.available(battle), false,
    "so the Z-MOVE cell is never offered to a Necrozma holding it, even with "
      .. "the Z-Ring and a damaging move of a type this game can Z-convert")

  -- And the reverse holds too: holding a type crystal instead of Ultranecrozium
  -- Z takes the BURST cell away, because the one held-item stamp can only ever
  -- name one item.
  bind(nil)
  local burstEntry = UltraBurst.entry(UltraBurst.new())
  local typeCrystalMon = newMon({ fused = "SOLGALEO", crystal = "PSYCHIUM_Z" })
  T.eq(burstEntry.available(makeBattle(typeCrystalMon, ZRING)), false,
    "a Necrozma holding a type crystal is not offered Ultra Burst either")
end

-- ---------------------------------------------------------------------
-- Duration: survives switching out, unlike Dynamax.
-- ---------------------------------------------------------------------
do
  bind(nil)
  local state = UltraBurst.new()
  local mon = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local battle = makeBattle(mon, ZRING)
  UltraBurst.entry(state).activate(battle)
  T.eq(mon.form, "ULTRA", "precondition: burst")

  -- A fresh battler for another Pokemon takes the field -- unrelated, and the
  -- state must not touch it.
  local otherMon = { species = "CHARIZARD", level = 50,
                     dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
                     statExp = {} }
  otherMon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  local otherBattler = battlerFor(otherMon, true)
  UltraBurst.onBattlerSwitched(state, { battle = battle, battler = otherBattler })
  T.eq(otherBattler.curStats.attack, 84,
    "switching a different mon in is untouched by the Ultra Necrozma state")

  -- makeBattler is form-blind, so the mon coming BACK gets a fresh battler
  -- seeded from the base species -- exactly what a real send-out hands back.
  local returned = { isPlayer = true, mon = mon, curStats = mon.stats,
                     curTypes = DATA.pokemon.NECROZMA.types }
  UltraBurst.onBattlerSwitched(state, { battle = battle, battler = returned })
  T.check(returned.curStats.attack > mon.stats.attack,
    "switching the burst mon back in reapplies Ultra Necrozma's curStats")
  T.eq(returned.curTypes[2], "DRAGON", "and its curTypes")
end

-- ---------------------------------------------------------------------
-- The unwind: fainting and the battle ending land on the FUSED baseline, not
-- on a plain Necrozma -- because the fusion never stopped being true and only
-- src/fusion.lua's settle (wired into src/resolve.lua) can say so.
-- ---------------------------------------------------------------------
do
  bind(nil)
  Resolve.bind({ registry = Transforms.new(), forms = Forms, eligibility = E,
                 megas = megas, fusion = Fusion, battlerof = Battlerof })
  local state = UltraBurst.new()
  local mon = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local battle = makeBattle(mon, ZRING)
  local battler = battle.player
  UltraBurst.entry(state).activate(battle)
  T.eq(mon.form, "ULTRA", "precondition: burst")

  Resolve.onFainted({ battle = battle, battler = battler })
  UltraBurst.onFainted(state, { battler = battler })
  T.eq(mon.form, "DUSK",
    "fainting reverts Ultra Burst back to the fused form it came from, not "
      .. "to a plain Necrozma -- the fusion is still true of the mon")
  T.eq(state.mon, nil, "and the module's own tracked mon is dropped")
end

do
  bind(nil)
  Resolve.bind({ registry = Transforms.new(), forms = Forms, eligibility = E,
                 megas = megas, fusion = Fusion, battlerof = Battlerof })
  local state = UltraBurst.new()
  local mon = newMon({ fused = "LUNALA", crystal = "ULTRANECROZIUM_Z" })
  local battle = makeBattle(mon, ZRING)
  UltraBurst.entry(state).activate(battle)
  T.eq(mon.form, "ULTRA", "precondition: burst, this time from Dawn Wings")

  -- The party sweep, exactly as src/resolve.lua runs it at battle.ended --
  -- benched or not, every mon in the party is settled.
  Resolve.onBattleEnded({ battle = battle })
  UltraBurst.onBattleEnded(state)
  T.eq(mon.form, "DAWN",
    "the battle ending reverts to Dawn Wings, the fused form Lunala made true")
  T.eq(state.mon, nil, "and drops the tracked mon")
end

-- A battle starting clears whatever a previous one (or an adoption) left.
do
  bind(nil)
  local state = UltraBurst.new()
  local mon = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local battle = makeBattle(mon, ZRING)
  UltraBurst.entry(state).activate(battle)
  UltraBurst.onBattleStarted(state)
  T.eq(state.mon, nil, "a battle starting clears the previous mon reference")
end

-- ---------------------------------------------------------------------
-- The shared once-per-battle lock, and that a refusal spends nothing.
-- ---------------------------------------------------------------------
do
  bind(nil)
  local registry = Transforms.new()
  T.eq(registry:register(Mega.entry({ forms = Forms, eligibility = E,
    megas = megas, keyitems = KeyItems, animId = "TESTANIM",
    battlerof = Battlerof })), true,
    "mega registers")
  local burstState = UltraBurst.new()
  T.eq(registry:register(UltraBurst.entry(burstState)), true,
    "and so does Ultra Burst")
  Overlay.bind({ registry = registry })
  Menu.bind({ overlay = Overlay })
  Resolve.bind({ registry = registry, forms = Forms, eligibility = E,
                 megas = megas, fusion = Fusion, battlerof = Battlerof })

  local mon = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local bag = { [KeyItems.KEY_STONE] = 1, [KeyItems.Z_RING] = 1 }
  local battle = makeBattle(mon, bag)
  local armState = Arm.new()
  armState:onBattleStarted({ battle = battle })
  T.eq(#Overlay.offered(armState), 1,
    "only Ultra Burst is on offer -- Necrozma has no mega pairing")

  armState:toggle("ultraburst")
  Resolve.onTurnStarted(armState, { battle = battle })
  T.eq(mon.form, "ULTRA", "arming it bursts at turn start")
  T.eq(armState:used("ultraburst"), true, "which spends its own limit")
  T.eq(armState:usedAny(), true, "and the battle's one transformation with it")

  -- A refusal (missing record) spends nothing, dispatched the same way every
  -- other entry's refusal is.
  local log, lines = makeLog()
  bind(log)
  local refusing = UltraBurst.new()
  local registry2 = Transforms.new()
  registry2:register(UltraBurst.entry(refusing))
  Resolve.bind({ registry = registry2, forms = Forms, eligibility = E,
                 megas = megas, fusion = Fusion, battlerof = Battlerof })
  local mon2 = newMon({ fused = "SOLGALEO", crystal = "ULTRANECROZIUM_Z" })
  local battle2 = makeBattle(mon2, ZRING)
  battle2.data = { pokemon = { NECROZMA = DATA.pokemon.NECROZMA } }
  local armState2 = Arm.new()
  armState2:onBattleStarted({ battle = battle2 })
  armState2:toggle("ultraburst")
  Resolve.onTurnStarted(armState2, { battle = battle2 })
  T.eq(mon2.form, nil, "a refused activation changes nothing")
  T.eq(armState2:used("ultraburst"), false,
    "and does not spend the battle's one transformation")
end

-- ---------------------------------------------------------------------
-- The label fits the cell, the same arithmetic tests/battle_forms_menu_test
-- pins for every shipping label.
-- ---------------------------------------------------------------------
do
  local GLYPH = 8
  local ARMED = 1
  local budget = Menu.CELL.classic.cycle - Menu.CELL.classic.label
  local label = UltraBurst.entry(UltraBurst.new()).label
  T.eq(label, "BURST", "the cell reads BURST")
  T.check((#label + ARMED) * GLYPH <= budget,
    "which fits the classic layout's " .. budget .. " pixels armed")
  T.check(#label <= 7,
    "and is inside the seven characters that budget is worth at all")
end

T.finish("battle_forms_ultraburst")
