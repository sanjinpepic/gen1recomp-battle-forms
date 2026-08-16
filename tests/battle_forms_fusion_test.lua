-- The only thing in this mod that takes a Pokemon off a player.
--
-- Most of this suite is about the refusals rather than the mechanic, and that
-- is the right proportion: a check that a Kyurem fuses is nearly free, where
-- the checks that matter are the ones proving that a refused fusion left the
-- party byte-for-byte as it found it and that the Reshiram is somewhere real
-- afterwards.  Every path below that ends in "failed" is asserted to have moved
-- NOTHING -- not the party, not the boxes, not either Pokemon.
--
-- The partner is compared BY IDENTITY throughout.  A Reshiram of the right
-- species and level is not the same thing as the Reshiram that went in, and a
-- suite that compared fields would pass on a mechanic that quietly handed back
-- a different Pokemon.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local Stone = dofile(MOD .. "/src/stone.lua")
local Shop = dofile(MOD .. "/src/shop.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local rows = dofile(MOD .. "/data/fusion.lua")
local fuserIndices = dofile(MOD .. "/data/fusers.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)
local Boxes = require("src.pokemon.Boxes")
local Party = require("src.pokemon.Party")

-- Alakazam and its mega ride along so the battle-scoped half of the mod can be
-- exercised on the SAME sweep as the fused half: a sweep that keeps everything
-- is as broken as one that keeps nothing.
local DATA = { pokemon = {
  KYUREM = { name = "KYUREM",
             baseStats = { hp = 125, attack = 130, defense = 90,
                           speed = 95, special = 130 },
             types = { "DRAGON", "ICE" } },
  KYUREM_WHITE = { name = "KYUREM WHITE",
                   baseStats = { hp = 125, attack = 120, defense = 90,
                                 speed = 95, special = 170 },
                   types = { "DRAGON", "ICE" }, form = "WHITE" },
  KYUREM_BLACK = { name = "KYUREM BLACK",
                   baseStats = { hp = 125, attack = 170, defense = 100,
                                 speed = 95, special = 120 },
                   types = { "DRAGON", "ICE" }, form = "BLACK" },
  RESHIRAM = { name = "RESHIRAM",
               baseStats = { hp = 100, attack = 120, defense = 100,
                             speed = 90, special = 150 },
               types = { "DRAGON", "FIRE" } },
  ZEKROM = { name = "ZEKROM",
             baseStats = { hp = 100, attack = 150, defense = 120,
                           speed = 90, special = 120 },
             types = { "DRAGON", "ELECTRIC" } },
  NECROZMA = { name = "NECROZMA",
               baseStats = { hp = 97, attack = 107, defense = 101,
                             speed = 79, special = 127 },
               types = { "PSYCHIC" } },
  NECROZMA_DUSK = { name = "NECROZMA DUSK",
                    baseStats = { hp = 97, attack = 157, defense = 127,
                                  speed = 77, special = 113 },
                    types = { "PSYCHIC" }, form = "DUSK" },
  SOLGALEO = { name = "SOLGALEO",
               baseStats = { hp = 137, attack = 137, defense = 107,
                             speed = 97, special = 113 },
               types = { "PSYCHIC" } },
  LUNALA = { name = "LUNALA",
             baseStats = { hp = 137, attack = 113, defense = 89,
                           speed = 97, special = 137 },
             types = { "PSYCHIC", "GHOST" } },
  ALAKAZAM = { name = "ALAKAZAM",
               baseStats = { hp = 55, attack = 50, defense = 45,
                             speed = 120, special = 135 },
               types = { "PSYCHIC" } },
  ALAKAZAM_MEGA = { name = "ALAKAZAM",
                    baseStats = { hp = 55, attack = 50, defense = 65,
                                  speed = 150, special = 175 },
                    types = { "PSYCHIC" }, form = "MEGA" },
} }

local function newMon(species, level)
  local base = DATA.pokemon[species].baseStats
  local mon = { species = species, level = level or 50,
                dvs = { hp = 15, attack = 15, defense = 15,
                        speed = 15, special = 15 },
                statExp = {}, hp = 120,
                moves = { { id = "TACKLE", pp = 35 } } }
  mon.stats = { hp = base.hp, attack = base.attack, defense = base.defense,
                speed = base.speed, special = base.special }
  return mon
end

local function newSave(party)
  local save = { party = party, inventory = {} }
  Boxes.ensure(save)
  return save
end

local function battlerFor(mon, isPlayer)
  return { isPlayer = isPlayer, mon = mon, curStats = mon.stats,
           curTypes = DATA.pokemon[mon.species].types }
end

local function makeBattle(save, enemyMon)
  return {
    data = DATA, phase = "menu", queue = {},
    player = battlerFor(save.party[1], true),
    enemy = enemyMon and battlerFor(enemyMon, false) or nil,
    game = { save = save },
    enemyParty = enemyMon and { enemyMon } or {},
  }
end

-- A log that remembers, because several guards below are required to be loud
-- and a silent refusal is exactly the failure they exist to prevent.
local function recorder()
  local lines = {}
  local log = {}
  log.warn = function(_, fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
  log.error = log.warn
  return lines, log
end

local messages, log = recorder()
Fusion.bind({ forms = Forms, rows = rows, log = log, price = Stone.PRICE,
              battlerof = Battlerof })
Resolve.bind({ forms = Forms, eligibility = E, megas = megas, fusion = Fusion,
               battlerof = Battlerof })

local function fakeMod()
  local mod = { items = {}, effects = {}, errors = {} }
  mod.content = {
    items = { register = function(_, id, record) mod.items[id] = record end },
    item_effects = {
      register = function(_, id, record) mod.effects[id] = record end },
  }
  mod.log = { error = function(_, fmt, ...)
    mod.errors[#mod.errors + 1] = string.format(fmt, ...)
  end }
  return mod
end

local installed = fakeMod()
Fusion.install(installed, rows, fuserIndices)
local splicers = installed.effects.DNA_SPLICERS.use
local solarizer = installed.effects.N_SOLARIZER.use
local lunarizer = installed.effects.N_LUNARIZER.use

-- Counts every Pokemon the save holds anywhere.  The single most important
-- assertion in this file: whatever a fusion or a refusal does, this number may
-- never go down.
local function population(save)
  local n = #save.party
  for _, box in ipairs(Boxes.ensure(save)) do n = n + #box end
  return n
end

local function inBoxes(save, mon)
  for b, box in ipairs(Boxes.ensure(save)) do
    for i, other in ipairs(box) do
      if other == mon then return b, i end
    end
  end
  return nil
end

local function inParty(save, mon)
  for i, other in ipairs(save.party) do
    if other == mon then return i end
  end
  return nil
end

-- ------- the data table says what it means ---------------------------

do
  T.eq(rows.KYUREM.DNA_SPLICERS.RESHIRAM, "KYUREM_WHITE",
    "Reshiram under the DNA Splicers makes White Kyurem")
  T.eq(rows.KYUREM.DNA_SPLICERS.ZEKROM, "KYUREM_BLACK",
    "and Zekrom, the same item, makes Black Kyurem -- which is why the partner "
      .. "is a key rather than a check")
  for itemId, index in pairs(fuserIndices) do
    T.check(index > 222,
      itemId .. "'s byte continues past the appliances rather than reusing one")
  end
  local count = 0
  for _ in pairs(fuserIndices) do count = count + 1 end
  T.eq(count, 4, "four fusion items ship")
end

-- ------- the derivation ----------------------------------------------

do
  local mon = newMon("KYUREM")
  T.eq(Fusion.formIdFor(mon), nil, "an unfused Kyurem is entitled to nothing")
  mon[Fusion.STAMP] = "RESHIRAM"
  T.eq(Fusion.formIdFor(mon), "KYUREM_WHITE",
    "the form is derived from which partner went in, not remembered")
  mon[Fusion.STAMP] = "ZEKROM"
  T.eq(Fusion.formIdFor(mon), "KYUREM_BLACK",
    "and follows the partner rather than the item")
  mon[Fusion.STAMP] = "SOLGALEO"
  T.eq(Fusion.formIdFor(mon), nil,
    "a partner this species has no pairing with entitles it to nothing")
  T.eq(Fusion.formIdFor(newMon("ALAKAZAM")), nil,
    "and a species with no pairings at all is not this module's")
end

-- ------- the item registers the way the others do --------------------

do
  T.eq(#installed.errors, 0, "a complete index table installs without complaint")
  for itemId in pairs(fuserIndices) do
    local record = installed.items[itemId]
    T.check(record ~= nil, itemId .. " is registered as an item")
    T.eq(record.index, fuserIndices[itemId], "with its permanent bag byte")
    T.eq(record.price, Stone.PRICE, "priced like the other form items")
    T.eq(record.needsTarget, true, "and used on a Pokemon rather than the bag")
    local effect = installed.effects[itemId]
    T.check(effect ~= nil, itemId .. " registers an item effect")
    T.eq(effect.battle, false,
      itemId .. " is refused mid-battle by the engine before it can reach the "
        .. "party -- a battle holds direct references to party mons")
  end
end

do
  local mod = fakeMod()
  Fusion.install(mod, rows, { DNA_SPLICERS = 223 })
  T.check(mod.items.DNA_SPLICERS ~= nil, "the indexed one registers")
  T.eq(mod.items.N_SOLARIZER, nil, "an unindexed one does not")
  T.eq(#mod.errors, 3, "and each refusal is reported")
  T.check(mod.errors[1]:find("data/fusers.lua", 1, true) ~= nil,
    "naming the file to fix it in")
end

-- ------- fusing ------------------------------------------------------

do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM", 62)
  local save = newSave({ kyurem, reshiram })
  local before = population(save)

  local result, msgs = splicers({ data = DATA, save = save, target = kyurem })
  T.eq(result, "kept", "the DNA Splicers are not used up")
  T.eq(population(save), before, "and no Pokemon went anywhere but a box")
  T.eq(#save.party, 1, "the party is one shorter")
  T.eq(save.party[1], kyurem, "and the Kyurem is what stayed in it")
  T.eq(inParty(save, reshiram), nil, "the Reshiram left the party")
  T.check(inBoxes(save, reshiram) ~= nil,
    "and is in the PC -- the same table, not a copy")

  T.eq(kyurem[Fusion.STAMP], "RESHIRAM", "the Kyurem records which partner")
  T.eq(kyurem.form, "WHITE", "and carries the marker out of battle, in the save")
  T.eq(reshiram[Fusion.HELD], "KYUREM", "and the partner records what it is in")
  -- One message page, not two: the "went into the PC!" line was cut, since
  -- src/boxmark.lua already marks the boxed partner with an F on screen
  -- (the WITHDRAW/RELEASE lists and its own STATS screen), so the player
  -- has a durable, always-visible answer to "where did it go" rather than a
  -- textbox they had to have read once.
  T.check(msgs and #msgs == 1, "one message page -- the fusion itself, not "
    .. "where the partner went")
  T.check(msgs[1]:find("PC", 1, true) == nil,
    "and it says nothing about the PC")

  T.eq(kyurem.species, "KYUREM", "the species was never touched")
  T.eq(kyurem.stats.special, 130, "nor the stat block, which is still the base's")
  T.eq(reshiram.level, 62, "and the partner kept its level")
  T.eq(reshiram.moves[1].pp, 35, "its PP")
  T.eq(reshiram.stats.attack, 120, "and its stats")
end

-- Party order is what chooses when one item has two possible partners, which is
-- the whole of how a player picks without a screen this mod would have to
-- invent.
do
  local kyurem, reshiram, zekrom = newMon("KYUREM"), newMon("RESHIRAM"), newMon("ZEKROM")
  local save = newSave({ kyurem, zekrom, reshiram })
  splicers({ data = DATA, save = save, target = kyurem })
  T.eq(kyurem[Fusion.STAMP], "ZEKROM",
    "the first eligible partner in PARTY ORDER is the one taken")
  T.eq(kyurem.form, "BLACK", "so reordering the party is how a player chooses")
  T.eq(inParty(save, reshiram) ~= nil, true, "and the other one is left alone")
  T.eq(reshiram[Fusion.HELD], nil, "entirely untouched")
end

-- Necrozma's two forms are told apart by the ITEM as well, so neither item can
-- reach the other's partner.
do
  local necrozma, solgaleo = newMon("NECROZMA"), newMon("SOLGALEO")
  local save = newSave({ necrozma, solgaleo })
  T.eq(lunarizer({ data = DATA, save = save, target = necrozma }), "failed",
    "the N-Lunarizer will not take a Solgaleo")
  T.eq(#save.party, 2, "and moved nothing")
  T.eq(solarizer({ data = DATA, save = save, target = necrozma }), "kept",
    "where the N-Solarizer will")
  T.eq(necrozma.form, "DUSK", "making the Dusk Mane form")
end

-- ------- the refusals, which are the point ---------------------------

local function unchanged(save, label)
  local party = {}
  for i, mon in ipairs(save.party) do party[i] = mon end
  local boxed = {}
  for b, box in ipairs(Boxes.ensure(save)) do
    boxed[b] = {}
    for i, mon in ipairs(box) do boxed[b][i] = mon end
  end
  return function()
    T.eq(#save.party, #party, label .. ": the party is the same length")
    for i, mon in ipairs(party) do
      T.eq(save.party[i], mon, label .. ": party slot " .. i .. " is the same "
        .. "Pokemon, by identity")
    end
    for b, box in ipairs(boxed) do
      T.eq(#Boxes.ensure(save)[b], #box, label .. ": box " .. b .. " is the "
        .. "same length")
      for i, mon in ipairs(box) do
        T.eq(Boxes.ensure(save)[b][i], mon,
          label .. ": box " .. b .. " slot " .. i .. " is the same Pokemon")
      end
    end
  end
end

do
  local kyurem = newMon("KYUREM")
  local save = newSave({ kyurem, newMon("ALAKAZAM") })
  local check = unchanged(save, "no partner")
  local result = splicers({ data = DATA, save = save, target = kyurem })
  T.eq(result, "failed", "with no partner in the party the item refuses")
  T.eq(kyurem[Fusion.STAMP], nil, "and records nothing")
  T.eq(kyurem.form, nil, "and marks nothing")
  check()
end

do
  local zam = newMon("ALAKAZAM")
  local save = newSave({ zam, newMon("RESHIRAM") })
  local check = unchanged(save, "wrong species")
  T.eq(splicers({ data = DATA, save = save, target = zam }), "failed",
    "the item on a species it has no pairing for is refused")
  T.eq(zam[Fusion.STAMP], nil, "and records nothing")
  check()
end

do
  T.eq(splicers({ data = DATA, save = newSave({}) }), "failed",
    "and with no target at all")
  local kyurem = newMon("KYUREM")
  T.eq(splicers({ data = DATA, target = kyurem }), "failed",
    "and with no save to read a party out of")
  T.eq(kyurem[Fusion.STAMP], nil, "which records nothing either")
end

-- The blackout guard.  Blackout is keyed on Party.firstHealthy rather than on
-- party size, so a party that is not empty and has nothing able to fight is a
-- soft-lock reached outside battle, where nothing exists to recover from it.
do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  kyurem.hp = 0
  local save = newSave({ kyurem, reshiram })
  local check = unchanged(save, "last healthy partner")
  local result, msgs = splicers({ data = DATA, save = save, target = kyurem })
  T.eq(result, "failed",
    "fusing the party's only healthy Pokemon into a fainted one is refused")
  T.check(msgs[1]:find("healthy", 1, true) ~= nil, "and says why")
  T.eq(kyurem[Fusion.STAMP], nil, "nothing was recorded")
  check()
  T.eq(Party.firstHealthy(save.party), reshiram,
    "and the party still has something that can fight")
end

do
  -- The same fainted base is fine as soon as something else can fight, which
  -- proves the guard is about the party rather than about the base's HP.
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  kyurem.hp = 0
  local save = newSave({ kyurem, reshiram, newMon("ALAKAZAM") })
  T.eq(splicers({ data = DATA, save = save, target = kyurem }), "kept",
    "a fainted base fuses when the party keeps a fighter")
  T.eq(kyurem.form, "WHITE", "and the fusion happened")
end

-- Every box full.  The engine's own Boxes.deposit answers nil, and the partner
-- goes back into the exact party slot it came out of.
do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram, newMon("ALAKAZAM") })
  for b = 1, Boxes.COUNT do
    for _ = 1, Boxes.CAPACITY do
      table.insert(Boxes.ensure(save)[b], newMon("ALAKAZAM"))
    end
  end
  local before = population(save)
  local check = unchanged(save, "PC full")
  local result, msgs = splicers({ data = DATA, save = save, target = kyurem })
  T.eq(result, "failed", "with every box full the fusion is refused")
  T.check(msgs[1]:find("PC", 1, true) ~= nil, "and says why")
  T.eq(population(save), before, "no Pokemon was lost between the two lists")
  T.eq(save.party[2], reshiram,
    "and the partner went back into the exact slot it came out of")
  T.eq(reshiram[Fusion.HELD], nil, "carrying no tag from the attempt")
  T.eq(kyurem[Fusion.STAMP], nil, "and the base records nothing")
  check()
end

-- A pairing whose record the running data cannot resolve.  Nothing moves,
-- because a boxed Reshiram with a Kyurem that looks entirely unchanged is a
-- player asking where their Pokemon went.
do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  local check = unchanged(save, "unresolvable form")
  local before = #messages
  local thin = { pokemon = { KYUREM = DATA.pokemon.KYUREM,
                             RESHIRAM = DATA.pokemon.RESHIRAM } }
  T.eq(splicers({ data = thin, save = save, target = kyurem }), "failed",
    "a form with no record refuses the fusion outright")
  T.check(#messages > before, "and says so out loud")
  T.check(messages[#messages]:find("KYUREM_WHITE", 1, true) ~= nil,
    "naming the form it could not resolve")
  T.check(messages[#messages]:find("data/fusion.lua", 1, true) ~= nil,
    "and the table to fix it in")
  check()
end

-- A partner already inside another fusion is skipped rather than taken again.
-- Two survivors pointing at one Pokemon is the shape from which something
-- eventually goes missing.
do
  local kyurem, other, reshiram = newMon("KYUREM"), newMon("KYUREM"), newMon("RESHIRAM")
  reshiram[Fusion.HELD] = "KYUREM"
  local save = newSave({ kyurem, other, reshiram })
  local check = unchanged(save, "partner already spoken for")
  T.eq(splicers({ data = DATA, save = save, target = kyurem }), "failed",
    "a withdrawn partner that is still inside a fusion is not taken again")
  check()
end

-- ------- splitting ---------------------------------------------------

do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM", 62)
  local save = newSave({ kyurem, reshiram })
  splicers({ data = DATA, save = save, target = kyurem })
  local before = population(save)

  local result, msgs = splicers({ data = DATA, save = save, target = kyurem })
  T.eq(result, "kept", "using the same item again separates them")
  T.eq(population(save), before, "with nothing gained or lost")
  T.eq(inParty(save, reshiram) ~= nil, true,
    "the very same Reshiram is back in the party, by identity")
  T.eq(inBoxes(save, reshiram), nil, "and out of the PC")
  T.eq(reshiram.level, 62, "at the level it went in with")
  T.eq(reshiram.moves[1].pp, 35, "with its PP")
  T.eq(reshiram.stats.attack, 120, "and its stats")
  T.eq(reshiram[Fusion.HELD], nil, "and the tag is gone")
  T.eq(kyurem[Fusion.STAMP], nil, "the Kyurem records no partner")
  T.eq(kyurem.form, nil, "and the marker went with it, so the save is clean")
  -- One message page, not two: the "came back from the PC!" line was cut,
  -- for the same reason 0.28.0 cut fusing's "went into the PC!" line --
  -- src/boxmark.lua's F marker is gone from the WITHDRAW and RELEASE lists
  -- the moment the withdraw happens, which already answers "where is it
  -- now" on screen, durably, rather than in a line printed once and gone.
  T.check(msgs and #msgs == 1, "one message page -- the separation itself, "
    .. "not where the partner came from")
  T.check(msgs[1]:find("PC", 1, true) == nil,
    "and it says nothing about the PC")
end

-- The right one of two, which is the whole reason the partner is tagged at all.
do
  local kyurem = newMon("KYUREM")
  local mine, stranger = newMon("RESHIRAM", 62), newMon("RESHIRAM", 8)
  local save = newSave({ kyurem, mine })
  table.insert(Boxes.ensure(save)[1], stranger)
  splicers({ data = DATA, save = save, target = kyurem })
  splicers({ data = DATA, save = save, target = kyurem })
  T.eq(inParty(save, mine) ~= nil, true,
    "the Reshiram that went in is the one that comes back")
  T.check(inBoxes(save, stranger) ~= nil,
    "and an unrelated Reshiram in the same box is left where it was")
  T.eq(stranger.level, 8, "untouched")
end

do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  splicers({ data = DATA, save = save, target = kyurem })
  for _ = 1, Party.MAX - 1 do table.insert(save.party, newMon("ALAKAZAM")) end
  T.eq(#save.party, Party.MAX, "the party is full")
  local check = unchanged(save, "party full on split")
  local result, msgs = splicers({ data = DATA, save = save, target = kyurem })
  T.eq(result, "failed", "so the separation is refused")
  T.check(msgs[1]:find("full", 1, true) ~= nil, "and says why")
  T.eq(kyurem[Fusion.STAMP], "RESHIRAM", "the pair is exactly as it was")
  T.eq(kyurem.form, "WHITE", "still wearing its form")
  T.eq(reshiram[Fusion.HELD], "KYUREM", "and the partner still tagged")
  check()
end

-- The partner released, traded, or lost to a cartridge round trip.  The fusion
-- is undone anyway: refusing would leave the player holding a Pokemon they
-- could never separate, and the missing one is no less missing for it.
do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  splicers({ data = DATA, save = save, target = kyurem })
  local box = select(1, inBoxes(save, reshiram))
  table.remove(Boxes.ensure(save)[box], 1)
  local before = #messages

  local result, msgs = splicers({ data = DATA, save = save, target = kyurem })
  T.eq(result, "kept", "the separation still happens")
  T.eq(kyurem[Fusion.STAMP], nil, "the fusion is undone")
  T.eq(kyurem.form, nil, "and the marker with it")
  T.check(msgs[2]:find("wasn't", 1, true) ~= nil,
    "and the player is told the other Pokemon was not there")
  T.check(#messages > before, "and it is reported")
  T.check(messages[#messages]:find("released, traded", 1, true) ~= nil,
    "naming what can have happened to it")
end

-- ------- in battle ---------------------------------------------------

do
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  splicers({ data = DATA, save = save, target = kyurem })
  local battle = makeBattle(save)
  Fusion.onBattleStarted({ battle = battle })
  T.eq(kyurem.form, "WHITE", "the marker it arrived with is still on it")
  T.eq(battle.player.curStats.special > kyurem.stats.special, true,
    "and the battler took the form's stats, computed rather than stored")
  T.eq(kyurem.stats.special, 130, "while the mon's own block is left alone")
end

do
  -- makeBattler is form-blind, so a mon coming back from the bench arrives with
  -- base stats and needs the override put back.
  local kyurem = newMon("KYUREM")
  kyurem[Fusion.STAMP] = "ZEKROM"
  kyurem.form = "BLACK"
  local save = newSave({ kyurem })
  local fresh = battlerFor(kyurem, true)
  Fusion.onBattlerSwitched({ battle = makeBattle(save), battler = fresh })
  T.eq(fresh.curStats.attack > kyurem.stats.attack, true,
    "switching in reapplies the form's stats")
end

do
  -- A fusion is the baseline a battle form is laid over, not something that
  -- outranks one.
  local kyurem = newMon("KYUREM")
  kyurem[Fusion.STAMP] = "RESHIRAM"
  kyurem.form = "GMAX"
  local battler = battlerFor(kyurem, true)
  Fusion.apply(makeBattle(newSave({ kyurem })), battler)
  T.eq(kyurem.form, "GMAX", "a form some other mechanic applied is not overwritten")
end

-- ------- the sweep ---------------------------------------------------

do
  local kyurem, zam = newMon("KYUREM"), newMon("ALAKAZAM")
  kyurem[Fusion.STAMP] = "RESHIRAM"
  kyurem.form = "WHITE"
  zam[E.STAMP] = "ALAKAZITE"
  local save = newSave({ kyurem, zam })
  local battle = makeBattle(save)

  Forms.becomeForm(DATA, battlerFor(zam, true), "ALAKAZAM_MEGA", nil)
  T.eq(zam.form, "MEGA", "the Alakazam megaed")

  Resolve.onBattleEnded({ battle = battle })
  T.eq(zam.form, nil, "the battle form did NOT survive the sweep")
  T.eq(kyurem.form, "WHITE", "the fusion did, on the very same sweep")
  T.eq(kyurem[Fusion.STAMP], "RESHIRAM", "with its partner still recorded")
  T.eq(kyurem.species, "KYUREM", "and the species untouched either way")
end

do
  -- The sweep OVERWRITES rather than merely sparing, so a battle form standing
  -- on a fused Pokemon cannot ride out on it.
  local kyurem = newMon("KYUREM")
  kyurem[Fusion.STAMP] = "ZEKROM"
  kyurem.form = "MEGA"
  Resolve.onBattleEnded({ battle = makeBattle(newSave({ kyurem })) })
  T.eq(kyurem.form, "BLACK",
    "a battle form left on a fused Pokemon is replaced, not kept")
end

do
  -- An orphan: a marker with no pair behind it, which is the shape a cartridge
  -- round trip leaves.  The send-out handler deliberately reconciles nothing,
  -- so the battle-END sweep is what takes it off.
  local kyurem = newMon("KYUREM")
  kyurem.form = "WHITE"
  local battle = makeBattle(newSave({ kyurem }))
  Fusion.onBattleStarted({ battle = battle })
  T.eq(kyurem.form, "WHITE", "the send-out handler reconciles nothing")
  T.eq(battle.player.curStats.special, kyurem.stats.special,
    "and applies nothing, so an orphan is a wrong picture and never wrong stats")
  Resolve.onBattleEnded({ battle = battle })
  T.eq(kyurem.form, nil, "and the party sweep is what takes the orphan off")
end

do
  local kyurem = newMon("KYUREM")
  kyurem[Fusion.STAMP] = "RESHIRAM"
  kyurem.form = "WHITE"
  local battle = makeBattle(newSave({ kyurem }))
  Resolve.onFainted({ battle = battle, battler = battle.player })
  T.eq(kyurem.form, "WHITE",
    "a fainted fused Pokemon keeps its marker -- the party menu is open next")
end

do
  T.eq(Fusion.settle(DATA, newMon("ALAKAZAM")), false,
    "a mon with no fusion is not this module's to settle")
  local kyurem = newMon("KYUREM")
  kyurem[Fusion.STAMP] = "RESHIRAM"
  T.eq(Fusion.settle(DATA, kyurem), true, "and a fused one is")
  T.eq(Fusion.settle(DATA, nil), false, "and no mon at all is refused")
end

do
  -- A pairing the running data cannot resolve clears the marker and keeps the
  -- fusion, because the pair still names the form and it returns the moment the
  -- record does.
  local before = #messages
  local kyurem = newMon("KYUREM")
  kyurem[Fusion.STAMP] = "RESHIRAM"
  kyurem.form = "WHITE"
  local claimed = Fusion.settle({ pokemon = { KYUREM = DATA.pokemon.KYUREM } },
                                kyurem)
  T.eq(claimed, true, "the module still claims the Pokemon")
  T.eq(kyurem.form, nil, "but refuses to vouch for a form it cannot resolve")
  T.eq(kyurem[Fusion.STAMP], "RESHIRAM", "leaving the pair itself intact")
  T.check(#messages > before, "and says so out loud")
end

-- ------- through the save --------------------------------------------

do
  -- The save format is a schema-less Lua-literal writer that re-emits whatever
  -- keys it finds, so a by-value copy is what a save and a reload do.  Both
  -- halves are plain strings, which is the whole reason this is a copy and not
  -- a nested Pokemon.
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  splicers({ data = DATA, save = save, target = kyurem })

  local copy = {}
  for k, v in pairs(kyurem) do copy[k] = v end
  T.eq(type(copy[Fusion.STAMP]), "string",
    "what the survivor carries is a string, not a Pokemon")
  T.eq(copy[Fusion.STAMP], "RESHIRAM", "which round-trips by value")
  T.eq(copy.form, "WHITE", "and so does the marker")
  T.eq(Fusion.formIdFor(copy), "KYUREM_WHITE",
    "so a reloaded Pokemon is still its fused form")

  local boxedCopy = {}
  for k, v in pairs(reshiram) do boxedCopy[k] = v end
  T.eq(boxedCopy[Fusion.HELD], "KYUREM",
    "and the partner's tag is a string too, which is why a box round-trip "
      .. "keeps it")
  T.eq(boxedCopy.species, "RESHIRAM",
    "the partner is an ordinary boxed Pokemon in every other respect")
end

do
  -- What a Game Boy .sav export actually leaves.  GenSave.lua rebuilds both
  -- party and box mons from fixed offsets, so both mod fields are dropped --
  -- but the partner itself is in a box, and boxes go through the same
  -- encodeMon the party does, so it comes back as a Reshiram.  Nothing is lost
  -- that using the item again does not restore.
  local kyurem, reshiram = newMon("KYUREM"), newMon("RESHIRAM")
  local save = newSave({ kyurem, reshiram })
  splicers({ data = DATA, save = save, target = kyurem })
  local box = select(1, inBoxes(save, reshiram))

  kyurem[Fusion.STAMP] = nil
  kyurem.form = nil
  reshiram[Fusion.HELD] = nil

  T.eq(Fusion.formIdFor(kyurem), nil, "the reimported Kyurem is plain")
  T.eq(Boxes.ensure(save)[box][1], reshiram,
    "and the Reshiram is still in the PC, which is the whole point of putting "
      .. "it there")
  T.eq(#save.party, 1, "the party is as it was")

  local battle = makeBattle(save)
  Fusion.onBattleStarted({ battle = battle })
  T.eq(kyurem.form, nil, "it stays plain when it battles")
  Resolve.onBattleEnded({ battle = battle })
  T.eq(kyurem.form, nil, "and after")

  -- And the two can simply be put back together.
  table.insert(save.party, table.remove(Boxes.ensure(save)[box], 1))
  T.eq(splicers({ data = DATA, save = save, target = kyurem }), "kept",
    "the ceiling on the damage is fusing them again")
  T.eq(kyurem.form, "WHITE", "which works exactly as it did the first time")
end

-- ------- the shelf ---------------------------------------------------

do
  local Registry = require("src.mods.Registry")
  local Schemas = require("src.mods.Schemas")
  local base = { IndigoPlateauLobby = { TEXT_INDIGOPLATEAULOBBY_CLERK = {
    label = "IndigoPlateauLobbyClerkText",
    mart = { "POKE_DOLL", "FULL_RESTORE" },
  } } }
  local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
  reg.base = function() return base end
  local mod = { content = { text_pointers = {
    patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
  } } }

  Shop.installFusionItems(mod, fuserIndices)
  local mart = reg:get("IndigoPlateauLobby").TEXT_INDIGOPLATEAULOBBY_CLERK.mart
  local sells = {}
  for _, id in ipairs(mart) do sells[id] = true end
  T.check(sells.POKE_DOLL, "the counter still sells what it always did")
  local count = 0
  for itemId in pairs(fuserIndices) do
    T.check(sells[itemId], itemId .. " is on the shelf")
    count = count + 1
  end
  T.eq(#mart, 2 + count, "and nothing else was added to it")
  local last = nil
  for _, id in ipairs(mart) do
    local index = fuserIndices[id]
    if index then
      T.check(last == nil or index > last, id .. " stands in bag-byte order")
      last = index
    end
  end
end

-- ---------------------------------------------------------------------
-- Gen 2: M.apply is the one place this module ever touches a Pokemon's
-- stats and types in battle, and it is Gen 1 only today -- `battler.mon` is
-- nil for a raw Gen 2 mon, so becomeForm always refused, silently, with the
-- fusion's own marker (mon.form, already correct -- src/fusion.lua's M.mark
-- runs at fuse/split time regardless of generation) left standing over base
-- stats and base types for the rest of every battle.  This mirrors
-- src/persistent.lua's own Gen 2 branch exactly, because it is the same
-- primitive for the same reason.
--
-- NOTE ON REACHABILITY, established by reading rather than a live boot (this
-- environment cannot drive one): the fusion ITEM itself cannot be triggered
-- on Gold. `Game2:usePartyItem` calls `ItemEffects.partyAction(itemId)` with
-- no `data` argument (game/src/core/Game2.lua:683), so it can only resolve
-- the engine's own built-in item_effects table -- confirmed already, in a
-- real Gold boot, for every mod's Gen 2 field item regardless of what it
-- registers (CHANGELOG.md's own 0.39.0 entry). DNA_SPLICERS is never in
-- that built-in table, so `action` comes back nil and `usePartyItem`
-- returns before it ever opens the party picker -- no message, nothing.
-- Unlike a persistent form, GIVE cannot stand in for this: a persistent form
-- only needs the mon to HOLD the item, where fusion needs an ACTION (move a
-- second Pokemon into the PC, write two markers) that nothing but a working
-- USE effect can perform. So this proves the MECHANISM is correct and ready
-- -- for a save a debug tool or a future engine fix could produce a fused
-- Gen 2 mon from -- without claiming a player can reach it on Gold today.
-- ---------------------------------------------------------------------
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local Mon2 = require("src.battle.gen2.Mon")

local GEN2_DATA = { pokemon = {
  KYUREM = DATA.pokemon.KYUREM, KYUREM_WHITE = DATA.pokemon.KYUREM_WHITE,
} }
GEN2_DATA.pokemon.KYUREM.baseStats = { hp = 125, attack = 130, defense = 90,
  speed = 95, specialAttack = 130, specialDefense = 90 }
GEN2_DATA.pokemon.KYUREM_WHITE.baseStats = { hp = 125, attack = 120,
  defense = 90, speed = 95, specialAttack = 170, specialDefense = 100 }

local function gen2Kyurem()
  local mon = { species = "KYUREM", level = 50, dvs = {}, statExp = {} }
  mon.stats = Mon2.stats(GEN2_DATA.pokemon.KYUREM.baseStats, {}, 50, {})
  return mon
end

do
  Fusion.bind({ forms = Forms, rows = rows, log = nil, price = Stone.PRICE,
                battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms })

  local kyurem = gen2Kyurem()
  kyurem[Fusion.STAMP] = "RESHIRAM"
  Fusion.mark(GEN2_DATA, kyurem)
  T.eq(kyurem.form, "WHITE", "precondition: the marker is set the same way on both games")

  local baseAttack = kyurem.stats.attack
  local battle = { data = GEN2_DATA, player = kyurem, save = { inventory = {} } }
  Fusion.onBattleStarted({ battle = battle })
  T.check(kyurem.stats.attack ~= baseAttack,
    "M.apply on Gen 2 rewrites the real mon.stats field, through gen2forms.becomeForm")
  T.same(kyurem.formTypes, GEN2_DATA.pokemon.KYUREM_WHITE.types,
    "and populates mon.formTypes, the type-resolution seam gen2forms.install reads")

  -- Switching in reapplies it, exactly like a persistent form: Gen 2 has
  -- no battler rebuild, but src/resolve.lua's own switch-in path is a
  -- deliberate no-op on Gen 2 (nothing needed rebuilding), so fusion's OWN
  -- onBattlerSwitched is what a real send-out actually goes through.
  kyurem.stats.attack = baseAttack
  kyurem.formTypes = nil
  Fusion.onBattlerSwitched({ battle = battle, battler = kyurem })
  T.check(kyurem.stats.attack ~= baseAttack,
    "and the same reapplication runs from battle.battler_switched")

  -- Refuses rather than half-applies, the identical contract every other
  -- primitive in this mod keeps -- proven against a data table with no
  -- KYUREM_WHITE record.
  local barren = gen2Kyurem()
  barren[Fusion.STAMP] = "RESHIRAM"
  local emptyBattle = { data = { pokemon = { KYUREM = GEN2_DATA.pokemon.KYUREM } },
                         player = barren, save = { inventory = {} } }
  Fusion.onBattleStarted({ battle = emptyBattle })
  T.eq(barren.stats.attack, baseAttack,
    "a missing record on Gen 2 leaves the real stats field untouched")
end

T.finish("battle_forms_fusion")
