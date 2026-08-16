-- The trainer's own items, and the gates they hold shut.
--
-- Two things are being pinned here and they pull in opposite directions.  The
-- GATE is conditional: a mechanic with no key item behind it is not offered at
-- all, and is not offered silently.  The REGISTRATION is not conditional under
-- any circumstances, because an item a save is already carrying has to stay
-- nameable however the gate answers -- the rule src/megaset.lua keeps for a
-- switched-off stone, which matters more here since there is no option that
-- could switch a key item off in the first place and therefore no obvious
-- place for the mistake to show up.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Shop = dofile(MOD .. "/src/shop.lua")
local Mega = dofile(MOD .. "/src/mega.lua")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")
local Overlay = dofile(MOD .. "/src/overlay.lua")
local Menu = dofile(MOD .. "/src/menu.lua")
local Arm = dofile(MOD .. "/src/arm.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local Megaset = dofile(MOD .. "/src/megaset.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local megas = Megaset.select(dofile(MOD .. "/data/megas.lua"), Megaset.ALL)
local keyIndices = dofile(MOD .. "/data/keyitems.lua")
local stoneIndices = dofile(MOD .. "/data/stones.lua")
local orbIndices = dofile(MOD .. "/data/orbs.lua")
local crystalIndices = dofile(MOD .. "/data/crystals.lua")
local applianceIndices = dofile(MOD .. "/data/appliances.lua")
local fuserIndices = dofile(MOD .. "/data/fusers.lua")
local heldFormIndices = dofile(MOD .. "/data/heldforms.lua")
local ultraCrystalIndices = dofile(MOD .. "/data/ultracrystal.lua")
local plateIndices = dofile(MOD .. "/data/plates.lua")
local memoryIndices = dofile(MOD .. "/data/memories.lua")
local driveIndices = dofile(MOD .. "/data/drives.lua")

-- ------- the two ids and their bag bytes -----------------------------

T.eq(#KeyItems.ITEMS, 4,
  "four key items ship: one each for mega, Dynamax, Tera and the Z-Move")
T.eq(KeyItems.ITEMS[1], KeyItems.KEY_STONE, "the Key Stone is the first")
T.eq(KeyItems.ITEMS[2], KeyItems.DYNAMAX_BAND, "the Dynamax Band the second")
T.eq(KeyItems.ITEMS[3], KeyItems.TERA_ORB, "the Tera Orb the third")
T.eq(KeyItems.ITEMS[4], KeyItems.Z_RING, "the Z-Ring the fourth")

-- Primal reversion takes no trainer item in the real games either, so there
-- must be nothing here that looks like one waiting to be wired up.
for _, itemId in ipairs(KeyItems.ITEMS) do
  T.check(itemId ~= "RED_ORB" and itemId ~= "BLUE_ORB",
    "primal reversion has no trainer key item and none was invented for it")
end

local named = {}
for _, itemId in ipairs(KeyItems.ITEMS) do
  named[itemId] = true
  T.check(keyIndices[itemId] ~= nil, itemId .. " has a bag index")
end
for itemId in pairs(keyIndices) do
  T.check(named[itemId], itemId .. " is indexed and is also a named key item")
end

-- One bag, eleven tables.  A byte handed out twice would make one item
-- indistinguishable from another in a save, which is unrecoverable rather
-- than merely wrong.  data/plates.lua and data/memories.lua are excluded from
-- this particular loop, not skipped by it: every one of their 34 entries is
-- `false`, and `false` is not a byte, it is the two files' own sentinel for
-- "no byte, on purpose" (see data/plates.lua's header for why) -- feeding
-- them through `seen[index]` would make the SECOND `false` entry this loop
-- ever sees fail as a false collision against the first, which is not the
-- bug this loop exists to catch.  They get their own, narrower check below.
-- data/drives.lua carries real bytes like every table in this loop's list, so
-- it belongs here rather than beside the Plates and Memories.
local seen = {}
for _, source in ipairs({ stoneIndices, orbIndices, keyIndices,
                          crystalIndices, applianceIndices, fuserIndices,
                          heldFormIndices, ultraCrystalIndices, driveIndices }) do
  for itemId, index in pairs(source) do
    T.check(seen[index] == nil,
      itemId .. "'s bag byte " .. tostring(index) .. " is not already "
        .. tostring(seen[index]) .. "'s")
    seen[index] = itemId
  end
end
for _, itemId in ipairs(KeyItems.ITEMS) do
  T.check(keyIndices[itemId] >= 196 and keyIndices[itemId] <= 255,
    itemId .. " continues past the orbs rather than reusing a byte")
end

-- Ultranecrozium Z continues at 233, past data/heldforms.lua's 227-232,
-- rather than reusing a byte from any of the other seven tables.
T.eq(ultraCrystalIndices.ULTRANECROZIUM_Z, 233,
  "Ultranecrozium Z continues where data/heldforms.lua stopped")

-- data/plates.lua and data/memories.lua: every one of the 34 items is
-- `false`, deliberately and exactly, never nil (an omission, still a hard
-- error at src/persistent.lua's install()) and never a real number (which
-- would either collide with a byte already handed out above, or -- worse, if
-- the number were past 255 -- silently truncate through GenSave.lua's
-- `bit.band(v, 0xFF)` into a byte that WAS already handed out, corrupting an
-- unrelated item's export rather than merely failing to add a new one).  234
-- is also asserted as the byte still available at the point the shortfall was
-- found: 22 free (234-255), 34 needed, which is the fact that sent both
-- families byteless rather than partly-byteless.
for _, pair in ipairs({ { "data/plates.lua", plateIndices },
                        { "data/memories.lua", memoryIndices } }) do
  local file, indices = pair[1], pair[2]
  local count = 0
  for itemId, index in pairs(indices) do
    T.eq(index, false, itemId .. " (" .. file .. ") is byteless, not merely absent")
    count = count + 1
  end
  T.eq(count, 17, file .. " wires exactly its seventeen items")
end
-- data/drives.lua: the family that DID fit in 234-255 with room to spare --
-- four items against the 22 free, so unlike the Plates and Memories these get
-- real bytes, continuing immediately past Ultranecrozium Z's 233 rather than
-- reusing one.
for _, itemId in ipairs({ "DOUSE_DRIVE", "SHOCK_DRIVE", "BURN_DRIVE", "CHILL_DRIVE" }) do
  T.check(driveIndices[itemId] ~= nil and driveIndices[itemId] ~= false,
    itemId .. " has a real bag byte, not the byteless sentinel")
  T.check(driveIndices[itemId] > 233,
    itemId .. " continues past Ultranecrozium Z rather than reusing a byte")
end
T.eq(seen[238], nil, "byte 238 is still free -- the Drives used exactly "
  .. "234-237 of the 22 bytes 234-255 left open, eighteen still spare")

-- ------- registration, which nothing may gate ------------------------

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

do
  local mod = fakeMod()
  KeyItems.install(mod, keyIndices)
  T.eq(#mod.errors, 0, "a complete index table installs without complaint")
  for _, itemId in ipairs(KeyItems.ITEMS) do
    local record = mod.items[itemId]
    T.check(record ~= nil, itemId .. " is registered as an item")
    T.eq(record.id, itemId, "and under its own id")
    T.eq(record.index, keyIndices[itemId], "with its permanent bag byte")
    T.eq(record.price, KeyItems.PRICE, "and its price")
    T.check(record.price > 0,
      "which is never zero -- the mart divides money by it")
    T.check(record.price < 2100,
      "and is nominal beside a stone: a key item gates a mechanic rather "
        .. "than buying a Pokemon a form")
    T.eq(record.name, itemId:gsub("_", " "), "and a readable name")
    T.eq(record.keyItem, true, "flagged as a key item, so nothing can sell it")
    T.eq(record.tossable, false, "nor toss it")
    T.eq(mod.effects[itemId], nil,
      itemId .. " registers no item effect: there is nothing to use it on")
  end
end

-- An id with no bag byte cannot exist in a Gen 1 save, so it is refused out
-- loud rather than registered into something a player could pick up and lose.
do
  local mod = fakeMod()
  KeyItems.install(mod, { [KeyItems.KEY_STONE] = 196 })
  T.eq(mod.items[KeyItems.KEY_STONE] ~= nil, true, "the indexed one registers")
  T.eq(mod.items[KeyItems.DYNAMAX_BAND], nil, "an unindexed one does not")
  T.eq(mod.items[KeyItems.TERA_ORB], nil, "nor does the other")
  T.eq(mod.items[KeyItems.Z_RING], nil, "nor the fourth")
  T.eq(#mod.errors, #KeyItems.ITEMS - 1, "and each refusal is reported")
  T.check(mod.errors[1]:find("DYNAMAX_BAND", 1, true) ~= nil,
    "naming the item it is about")
  T.check(mod.errors[2]:find("TERA_ORB", 1, true) ~= nil, "and so does the next")
  T.check(mod.errors[3]:find("Z_RING", 1, true) ~= nil, "and the one after it")
  T.check(mod.errors[1]:find("data/keyitems.lua", 1, true) ~= nil,
    "and the file to fix it in")
end

do
  local mod = fakeMod()
  KeyItems.install(mod, nil)
  T.eq(#mod.errors, #KeyItems.ITEMS,
    "no index table at all refuses every one of them, still out loud")
end

-- ------- the shelf ---------------------------------------------------

do
  local Registry = require("src.mods.Registry")
  local Schemas = require("src.mods.Schemas")
  local base = {
    CeladonMart4F = {
      TEXT_CELADONMART4F_CLERK = {
        label = "CeladonMart4FClerkText",
        mart = { "POKE_DOLL", "FIRE_STONE" },
      },
    },
  }
  local reg = Registry.new("text_pointers", Schemas.REGISTRIES.text_pointers)
  reg.base = function() return base end
  local mod = { content = { text_pointers = {
    patch = function(_, id, partial) reg:patch(id, partial, "battle_forms") end,
  } } }

  Shop.installKeyItems(mod, keyIndices)
  local mart = reg:get("CeladonMart4F").TEXT_CELADONMART4F_CLERK.mart
  local at = {}
  for i, id in ipairs(mart) do at[id] = i end
  T.check(at.POKE_DOLL and at.FIRE_STONE,
    "the floor's own stock survives the key items being patched in")
  T.eq(at[KeyItems.KEY_STONE], #base.CeladonMart4F.TEXT_CELADONMART4F_CLERK.mart + 1,
    "the Key Stone lands directly after it")
  T.check(at[KeyItems.DYNAMAX_BAND] == at[KeyItems.KEY_STONE] + 1,
    "and the Band directly after the Key Stone, in bag-byte order")
  T.check(at[KeyItems.TERA_ORB] == at[KeyItems.DYNAMAX_BAND] + 1,
    "and the Tera Orb after the Band, by the byte it was given")
end

-- ------- reading the bag ---------------------------------------------

local function battleWith(inventory)
  return { game = { save = { inventory = inventory } } }
end

T.eq(KeyItems.held(battleWith({ KEY_STONE = 1 }), "KEY_STONE"), true,
  "a bag holding one is holding one")
T.eq(KeyItems.held(battleWith({ KEY_STONE = 5 }), "KEY_STONE"), true,
  "a count above one still counts")
T.eq(KeyItems.held(battleWith({ KEY_STONE = 0 }), "KEY_STONE"), false,
  "a count of zero does not")
-- The engine's own badge fixtures store `true` rather than a count, and a
-- numeric comparison against that shape errors instead of answering.
T.eq(KeyItems.held(battleWith({ KEY_STONE = true }), "KEY_STONE"), true,
  "and neither shape a bag entry comes in throws")
T.eq(KeyItems.held(battleWith({}), "KEY_STONE"), false, "an empty bag holds nothing")
T.eq(KeyItems.held(battleWith({ DYNAMAX_BAND = 1 }), "KEY_STONE"), false,
  "and one key item is not another")

-- Every link answers false rather than throwing: this runs from the menu
-- cell's decision on every drawn frame, and a battle screen taken down by a
-- nil index is worse than a cell that is not offered.
T.eq(KeyItems.held(nil, "KEY_STONE"), false, "no battle holds nothing")
T.eq(KeyItems.held({}, "KEY_STONE"), false, "no game holds nothing")
T.eq(KeyItems.held({ game = {} }, "KEY_STONE"), false, "no save holds nothing")
T.eq(KeyItems.held({ game = { save = {} } }, "KEY_STONE"), false,
  "no inventory holds nothing")
T.eq(KeyItems.held(battleWith({ KEY_STONE = 1 }), nil), false,
  "and nothing is held when nothing was asked about")

-- ------- the gates ---------------------------------------------------

local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" } },
  CHARIZARD_MEGA_X = { baseStats = { hp = 78, attack = 130, defense = 111,
                                     speed = 100, special = 130 },
                       types = { "FIRE", "DRAGON" }, form = "MEGA_X" },
} }

local function makeInput(pressed)
  return { wasPressed = function(_, btn) return (pressed or {})[btn] == true end }
end

-- An eligible Charizard at the command menu: everything a MEGA cell needs
-- except the trainer's half, which each case below supplies or withholds.
local function makeBattle(inventory)
  local mon = { species = "CHARIZARD", level = 50, hp = 100,
                dvs = { hp = 15, attack = 15, defense = 15, speed = 15,
                        special = 15 },
                statExp = {}, [E.STAMP] = "CHARIZARDITE_X" }
  mon.stats = { hp = 78, attack = 84, defense = 78, speed = 100, special = 85 }
  return {
    phase = "menu", menuIndex = 1, queue = {}, data = DATA,
    player = { isPlayer = true, mon = mon, curStats = mon.stats,
               curTypes = DATA.pokemon.CHARIZARD.types },
    game = { save = { party = { mon }, inventory = inventory },
             input = makeInput({}) },
    enemyParty = {},
    animNext = function() end,
    animationsOn = function() return false end,
  }
end

Dynamax.bind({ forms = Forms, gigantamax = {}, keyitems = KeyItems,
               battlerof = Battlerof })

local function newCell()
  local registry = Transforms.new()
  T.eq(registry:register(Mega.entry({ forms = Forms, eligibility = E,
    megas = megas, keyitems = KeyItems, animId = "TESTANIM",
    battlerof = Battlerof })), true,
    "mega registers")
  T.eq(registry:register(Dynamax.entry(Dynamax.new())), true,
    "and Dynamax beside it")
  Overlay.bind({ registry = registry })
  Menu.bind({ overlay = Overlay })
  return registry
end

local function labels(state)
  local out = {}
  for _, entry in ipairs(Overlay.offered(state)) do out[#out + 1] = entry.label end
  return table.concat(out, ",")
end

local function cellFor(inventory)
  newCell()
  local battle = makeBattle(inventory)
  local state = Arm.new()
  state:onBattleStarted({ battle = battle })
  return battle, state
end

-- An empty bag: an eligible Charizard, a species table that has its mega, a
-- command menu with nothing queued -- and no cell at all.
do
  local battle, state = cellFor({})
  T.eq(labels(state), "", "an empty bag is offered nothing")
  T.eq(Overlay.shouldOffer(state), false, "so the cell is absent")
  T.eq(Overlay.label(state), nil, "and names nothing")
  for _, button in ipairs({ "left", "right", "up", "down", "a" }) do
    battle.game.input = makeInput({ [button] = true })
    T.eq(Menu.handleInput(battle, state), false,
      button .. " claims no frame, so the cursor never reaches the cell")
    T.eq(Menu.isOnCell(battle), false, "and never lands on it")
  end
  T.eq(state:isArmed(), false, "nothing is armed")
  T.eq(state:armed(), nil, "and nothing is waiting to resolve")
end

-- One item each, and each opens exactly its own gate.  This is the whole
-- independence claim: two items, two mechanics, no crossing over.
do
  local _, state = cellFor({ [KeyItems.KEY_STONE] = 1 })
  T.eq(labels(state), "MEGA",
    "a Key Stone alone offers the mega and not the Dynamax")
end

do
  local _, state = cellFor({ [KeyItems.DYNAMAX_BAND] = 1 })
  T.eq(labels(state), "DYNAMAX",
    "a Dynamax Band alone offers the Dynamax and not the mega, on the same "
      .. "mon carrying the same stone")
end

do
  local _, state = cellFor({ [KeyItems.KEY_STONE] = 1,
                             [KeyItems.DYNAMAX_BAND] = 1 })
  T.eq(labels(state), "MEGA,DYNAMAX",
    "both items offer both, in registration order")
end

-- With the Key Stone the mega behaves exactly as it did before there was one:
-- armed from the cell, resolved at turn start, spent once.
do
  local battle, state = cellFor({ [KeyItems.KEY_STONE] = 1 })
  T.eq(Overlay.label(state), "MEGA", "the cell reads MEGA")
  battle.game.input = makeInput({ left = true })
  T.eq(Menu.handleInput(battle, state), true, "left from FIGHT reaches the cell")
  T.eq(Menu.isOnCell(battle), true, "and the cursor is on it")
  battle.game.input = makeInput({ a = true })
  T.eq(Menu.handleInput(battle, state), true, "pressing A on the cell is claimed")
  T.eq(state:armed(), Mega.ID, "and arms the mega")
  T.eq(Overlay.label(state), "MEGA*", "which the cell marks")
end

-- Buying one mid-save: the gate reads the bag live, so the mechanic is
-- available in the next command menu with nothing reloaded and no new battle.
do
  local battle, state = cellFor({})
  T.eq(Overlay.shouldOffer(state), false, "nothing on offer before the errand")
  battle.game.save.inventory[KeyItems.KEY_STONE] = 1
  T.eq(labels(state), "MEGA", "buying a Key Stone makes the mega available")
  battle.game.save.inventory[KeyItems.DYNAMAX_BAND] = 1
  T.eq(labels(state), "MEGA,DYNAMAX", "and the Band the Dynamax, beside it")
end

T.finish("battle_forms_keyitems")
