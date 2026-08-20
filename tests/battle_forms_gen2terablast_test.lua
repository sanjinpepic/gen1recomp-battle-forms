-- Tera Blast on Gold: the last of the four pieces, and the reopening of a
-- refusal src/tera.lua's own `entry.arm` carried in plain text -- "TERA
-- BLAST substitution is Gen 1 only... arming still has to succeed, it just
-- substitutes nothing" -- written before src/gen2substitute.lua was proven
-- under a real consumer. It has been proven three times over since (Max
-- Moves, type Z-Moves, species Z-Moves), so this suite closes the refusal
-- rather than inheriting it.
--
-- Terastallization's own type override (mon.formTypes) already works on
-- Gold and is untouched here -- this suite is scoped to the one thing that
-- was missing, TERA BLAST's own move substitution, mirroring
-- tests/battle_forms_gen2zmoves_test.lua's shape.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Tera = dofile(MOD .. "/src/tera.lua")
local Gen2Substitute = dofile(MOD .. "/src/gen2substitute.lua")
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local TYPES = dofile(MOD .. "/data/terablast.lua")

local RED_TYPES = { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK",
                    "BUG", "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC",
                    "PSYCHIC_TYPE", "ICE", "DRAGON" }

local function chartOf(list)
  local chart = {}
  for _, id in ipairs(list) do chart[id] = { name = id, category = "physical" } end
  return chart
end

local function stubMod(chart)
  local buckets = { moves = {}, battle_anims = {} }
  local content = {}
  for name, bucket in pairs(buckets) do
    content[name] = { register = function(_, id, record) bucket[id] = record end }
  end
  content.type_chart = { get = function(_, id) return chart[id] end }
  return { content = content, log = { warn = function() end, error = function() end } }
end

local TERA_CATALOG
do
  Tera.bind({ keyitems = KeyItems, announce = Announce, anim = Anim,
              battlerof = Battlerof })
  TERA_CATALOG = Tera.install(stubMod(chartOf(RED_TYPES)), TYPES)
end

local DATA = { moves = {
  TERABLAST = { id = "TERABLAST", name = "TERA BLAST", type = "NORMAL",
                power = 80, pp = 10, accuracy = 100 },
  EMBER = { id = "EMBER", name = "EMBER", type = "FIRE", power = 40, pp = 25,
            accuracy = 100 },
}, type_chart = { types = chartOf(RED_TYPES) } }

local function bind(chosen)
  Tera.bind({ keyitems = KeyItems, announce = Announce, anim = Anim,
              battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms,
              gen2substitute = Gen2Substitute,
              chosen = chosen or function() return "ELECTRIC" end })
end

bind()

local function newMon()
  return { species = "PIKACHU", level = 50, nickname = "SPARKY", hp = 100,
           moves = { { id = "TERABLAST", pp = 10, maxPp = 10 },
                     { id = "EMBER", pp = 25, maxPp = 25 } } }
end

local function makeBattle(mon, orb)
  local events = {}
  local inventory = {}
  if orb ~= false then inventory[KeyItems.TERA_ORB] = 1 end
  return {
    data = DATA, player = mon, party = { mon }, enemyParty = {}, events = events,
    save = { inventory = inventory },
    emit = function(_, ev) events[#events + 1] = ev end,
    monName = function(_, m) return m and m.nickname end,
  }
end

-- ---------------------------------------------------------------------
-- fieldsFor: maxPp on Gold, ppUps on Gen 1 -- the identical branch every
-- other substitution catalog in this mod already carries.
-- ---------------------------------------------------------------------
do
  bind()
  local fields = Tera.fieldsFor(TERA_CATALOG, DATA,
    { id = "TERABLAST", pp = 10, maxPp = 10 }, "ELECTRIC")
  T.check(fields ~= nil, "a TERA BLAST slot still converts on Gold")
  T.eq(fields.maxPp, 10, "carrying TERA BLAST's own real maxPp")
  T.eq(rawget(fields, "ppUps"), nil, "never a ppUps correction on Gold")
end

-- ---------------------------------------------------------------------
-- Arming: the real primitive, substituting TERA BLAST for real -- the gap
-- this suite exists to close. Before this pass entry.arm short-circuited
-- `if deps.gen2 then return true end` before ever reaching the substitution.
-- ---------------------------------------------------------------------
do
  local state = Tera.new()
  local entry = Tera.entry(state, TERA_CATALOG)
  local mon = newMon()
  local battle = makeBattle(mon)
  local slot1 = mon.moves[1]

  T.eq(entry.available(battle), true, "the cell is offered with the Tera Orb")
  T.eq(entry.arm(battle), true, "arming answers that it happened")
  T.eq(mon.moves[1], slot1, "the slot is the SAME table, mutated in place")
  T.check(mon.moves[1].id ~= "TERABLAST",
    "and TERA BLAST really did substitute into the Electric variant")
  T.eq(mon.moves[1].id, Tera.idFor("ELECTRIC"), "into the exact registered id")
  T.eq(mon.moves[1].maxPp, 10, "carrying TERA BLAST's own real maxPp")
  T.eq(mon.moves[2].id, "EMBER", "the other slot is untouched")

  entry.disarm()
  T.eq(mon.moves[1].id, "TERABLAST", "disarming puts the real move back")
  T.eq(mon.moves[1].maxPp, 10, "and the real maxPp")
end

-- ---------------------------------------------------------------------
-- activate(): the type override lands on mon.formTypes, unchanged by this
-- pass, alongside the now-real substitution.
-- ---------------------------------------------------------------------
do
  local state = Tera.new()
  local entry = Tera.entry(state, TERA_CATALOG)
  local mon = newMon()
  local battle = makeBattle(mon)

  entry.arm(battle)
  T.eq(entry.activate(battle), true, "activating answers that it happened")
  T.same(mon.formTypes, { "ELECTRIC" }, "the type override lands on mon.formTypes")
  T.check(mon.moves[1].id ~= "TERABLAST", "and the substitution is still standing")
end

-- ---------------------------------------------------------------------
-- Switching out and back in: unlike Dynamax and the Z-Moves, Terastallization
-- does NOT end on a switch -- it is reapplied to the mon arriving, both the
-- type override AND the substitution, since makeBattler/a fresh send-out is
-- form-blind and move-blind alike on Gen 2 too.
-- ---------------------------------------------------------------------
do
  local state = Tera.new()
  local entry = Tera.entry(state, TERA_CATALOG)
  local mon = newMon()
  local battle = makeBattle(mon)

  entry.arm(battle)
  entry.activate(battle)
  local teraId = mon.moves[1].id

  -- A switch out and back in: Gen 2 rebuilds nothing about the mon itself
  -- (mon.formTypes and mon.moves both survive, being the mon's own fields),
  -- but the substitution's own snapshot is checked here anyway, matching
  -- Gen 1's own "reapplied on every switch-in" contract.
  Tera.onBattlerSwitched(state, { battle = battle, battler = mon })
  T.same(mon.formTypes, { "ELECTRIC" }, "the type override is reasserted on switch-in")
  T.eq(mon.moves[1].id, teraId, "and the substitution is still standing after it")
end

-- ---------------------------------------------------------------------
-- Every other way it ends.
-- ---------------------------------------------------------------------
for _, case in ipairs({
  { "fainting", function(state, battle, mon)
      Tera.onFainted(state, { battle = battle, battler = mon })
    end },
  { "the battle ending", function(state, battle)
      Tera.onBattleEnded(state, { battle = battle })
    end },
  { "a battle starting", function(state) Tera.onBattleStarted(state) end },
}) do
  local state = Tera.new()
  local entry = Tera.entry(state, TERA_CATALOG)
  local mon = newMon()
  local battle = makeBattle(mon)

  entry.arm(battle)
  entry.activate(battle)
  T.check(mon.moves[1].id ~= "TERABLAST", "armed before " .. case[1])

  case[2](state, battle, mon)
  T.eq(mon.moves[1].id, "TERABLAST", case[1] .. " puts the real move back")
end

-- ---------------------------------------------------------------------
-- Without the primitive bound: a degraded mod, not a broken one -- arming
-- still succeeds (Terastallizing needs no TERA BLAST in the moveset at all)
-- but nothing is substituted.
-- ---------------------------------------------------------------------
do
  Tera.bind({ keyitems = KeyItems, announce = Announce, anim = Anim,
              battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms,
              chosen = function() return "ELECTRIC" end })
  local state = Tera.new()
  local entry = Tera.entry(state, TERA_CATALOG)
  local mon = newMon()
  local battle = makeBattle(mon)
  T.eq(entry.arm(battle), true, "arming still succeeds with no primitive bound")
  T.eq(mon.moves[1].id, "TERABLAST", "but nothing is substituted")
  bind()
end

-- ---------------------------------------------------------------------
-- Through the real loader: main.lua's own wiring, not a hand mirror of it.
-- This is the assertion an unwired Gold Tera Blast (main.lua never passing
-- gen2substitute into src/tera.lua's own bind) would fail -- confirmed by
-- deliberate breakage while building this suite: commenting out
-- `gen2substitute = m["src/gen2substitute.lua"]` from tera.bind in main.lua
-- reproduces exactly the failure this block exists to catch (arm() answers
-- true but the real move slot is never substituted) -- restored immediately
-- afterward and confirmed green again.
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
  run.data.moves.TERABLAST = { id = "TERABLAST", name = "TERA BLAST",
                               type = "NORMAL", power = 80, accuracy = 100,
                               pp = 10, effect = "NO_ADDITIONAL_EFFECT" }

  -- mod.options:get("tera_type") now defaults to AUTO, which asks the Pokemon
  -- (src/teratype.lua).  This mon is stamped instead -- the field a Tera Orb
  -- writes when a player spends shards on one -- because the fixture dataset
  -- carries no PIKACHU record for the derivation to read types off, and
  -- because pinning the type is what this suite is actually about: the real
  -- cell must arm the NORMAL variant, a DIFFERENT registered id from the base
  -- TERABLAST despite sharing a type, since M.fieldsFor substitutes on the
  -- type CHOICE and never on whether it happens to already match.
  local teraId = Tera.idFor("NORMAL")
  T.check(run.data.moves[teraId] ~= nil,
    "the real NORMAL TERA BLAST variant reached the merged registry")

  local TeraType = dofile(MOD .. "/src/teratype.lua")
  local mon = { species = "PIKACHU", level = 50, nickname = "SPARKY", hp = 100,
                [TeraType.STAMP] = "NORMAL",
                moves = { { id = "TERABLAST", pp = 10, maxPp = 10 } } }
  local engineBattle = { data = run.data,
                          save = { inventory = { TERA_ORB = 1 } },
                          player = mon, party = { mon }, enemyParty = {},
                          events = {},
                          emit = function(self, ev)
                            self.events[#self.events + 1] = ev
                          end,
                          monName = function(_, m) return m and m.nickname end }

  local BattleState = require("src.ui.gen2.BattleState")
  run.loader.events:emit("battle.started", { battle = engineBattle })

  local uiBattle = { phase = "menu", menuIndex = 1, queue = {},
                     battle = engineBattle, game = { input = nil } }
  local function press(button)
    uiBattle.game.input = { wasPressed = function(_, btn) return btn == button end }
    return BattleState.update(uiBattle, 0)
  end

  -- Nothing else this save could carry is held (no Key Stone, no Dynamax
  -- Band, no Z-Ring), so Terastallization is the ONLY entry `available()`
  -- offers -- the submenu's one row is unambiguously this one.
  press("left")
  T.check(uiBattle._battleFormsMenuCell == true,
    "left from FIGHT reached the real cell through the real wrapped update")
  press("a")
  T.check(uiBattle._battleFormsListOpen == true, "A on the cell opened the real submenu")
  press("a")
  T.check(uiBattle._battleFormsListOpen == false, "confirming the one row closed it")

  -- Arming happens the moment the cell is confirmed, a step AHEAD of
  -- activation (src/arm.lua's own header) -- proof the confirm inside the
  -- real submenu dispatched a real src/gen2substitute.lua apply through the
  -- real src/tera.lua Gen 2 branch, not just a UI-only field flip.
  T.eq(mon.moves[1].id, teraId,
    "the real move slot was substituted the moment the cell was confirmed, "
      .. "into the real registered Electric TERA BLAST id")
  T.eq(mon.moves[1].maxPp, 10,
    "carrying TERA BLAST's own real maxPp, not a ppUps correction")

  run.loader.events:emit("battle.turn_started", { battle = engineBattle })
  T.same(mon.formTypes, { "NORMAL" },
    "and turn start ran the real activation, landing the type override too")

  run.release()
end

T.finish("battle_forms_gen2terablast")
