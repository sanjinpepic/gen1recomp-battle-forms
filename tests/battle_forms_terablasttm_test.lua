-- TM171: the fix for TERA BLAST having shipped in 0.27.0 registered by
-- National Dex, substituted by src/tera.lua, and unreachable by any
-- Pokemon -- it sat in zero learnsets.  Three things this suite exists to
-- prove and none of them for free.
--
-- First, the rule: M.eligible is a species-shaped test, not a list, so it
-- is exercised directly against a handful of shapes before anything is
-- wired into the loader.
--
-- Second, that src/terablasttm.lua's three jobs -- the item, the honest
-- `effectModeled` flag, and the tmhm patches -- degrade independently and
-- correctly when a base is missing, the same discipline
-- src/dragonascent.lua's own suite holds it to.
--
-- Third, and the one that matters most: the whole reachability CHAIN,
-- driven through the real loader and the engine's own
-- src/inventory/ItemEffects.lua rather than reimplemented here -- a save,
-- an eligible Pokemon, the real machine-item path, and src/tera.lua's own
-- substitution treating the taught move exactly like one that was always
-- there.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local TM = dofile(MOD .. "/src/terablasttm.lua")
local Tera = dofile(MOD .. "/src/tera.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local tmIndices = dofile(MOD .. "/data/tm171.lua")
local TERABLAST_TYPES = dofile(MOD .. "/data/terablast.lua")

-- ---------------------------------------------------------------------
-- M.eligible: the rule, not a hand-picked list.
-- ---------------------------------------------------------------------
T.eq(TM.eligible("CHARIZARD", { id = "CHARIZARD", baseStats = {} }), true,
  "an ordinary species may learn it")
T.eq(TM.eligible("CHARIZARD_MEGA_X",
  { id = "CHARIZARD_MEGA_X", baseSpecies = "CHARIZARD", form = "MEGA_X" }),
  false, "a form pseudo-record -- both baseSpecies and form set -- may not")
T.eq(TM.eligible("ODD",
  { id = "ODD", baseSpecies = "CHARIZARD" }), true,
  "baseSpecies alone, with no form, is not the form shape and stays eligible")
T.eq(TM.eligible("ODD2", { id = "ODD2", form = "MEGA_X" }), true,
  "form alone, with no baseSpecies, is not the form shape either")
T.eq(TM.eligible("X", nil), false, "no record at all is never eligible")
T.eq(TM.eligible("X", "not a table"), false,
  "a non-table record is never eligible")

-- ---------------------------------------------------------------------
-- M.install through a stub mod: the three jobs, and how each degrades
-- without cascading into the other two.
-- ---------------------------------------------------------------------
local function stubMod(opts)
  opts = opts or {}
  local registered = { items = {} }
  local patched = { moves = {}, pokemon = {} }
  local warned, errored = {}, {}
  local pokemonRecords = opts.pokemon or {}
  local mod = {
    content = {
      items = {
        register = function(_, id, record) registered.items[id] = record end,
      },
      moves = {
        get = function(_, id)
          if opts.moveMissing then return nil end
          return { id = id, power = 80, type = "NORMAL" }
        end,
        patch = function(_, id, partial) patched.moves[id] = partial end,
      },
      pokemon = opts.noEach and {} or {
        each = function()
          local ids = {}
          for id in pairs(pokemonRecords) do ids[#ids + 1] = id end
          table.sort(ids)
          local i = 0
          return function()
            i = i + 1
            local id = ids[i]
            if id == nil then return nil end
            return id, pokemonRecords[id]
          end
        end,
        patch = function(_, id, partial) patched.pokemon[id] = partial end,
      },
    },
    log = {
      warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end,
      error = function(_, fmt, ...) errored[#errored + 1] = fmt:format(...) end,
    },
  }
  return mod, registered, patched, warned, errored
end

-- Everything present: all three jobs go through.
do
  local pokemon = {
    ORDINARY = { id = "ORDINARY" },
    FORM = { id = "FORM", baseSpecies = "ORDINARY", form = "MEGA" },
  }
  local mod, registered, patched, warned, errored = stubMod({ pokemon = pokemon })
  TM.install(mod, tmIndices)

  T.check(registered.items.TM171 ~= nil, "TM171 is registered as an item")
  T.eq(registered.items.TM171.id, "TM171", "under its own id")
  T.eq(registered.items.TM171.index, tmIndices.TM171, "with its permanent bag byte")
  T.eq(registered.items.TM171.price, TM.PRICE, "and its price")
  T.check(registered.items.TM171.price > 0, "which is never zero")
  T.eq(registered.items.TM171.machine.kind, "TM", "a TM, not an HM")
  T.eq(registered.items.TM171.machine.move, "TERABLAST", "teaching TERABLAST")
  T.eq(registered.items.TM171.machine.number, 171, "TM171's own number")
  T.eq(registered.items.TM171.needsTarget, true, "and needs a party target")
  T.eq(registered.items.TM171.tossable, true,
    "an ordinary, tossable TM -- unlike a key item")

  T.eq(patched.moves.TERABLAST.effectModeled, true,
    "TERABLAST is patched to be flagged honestly modelled")

  T.check(patched.pokemon.ORDINARY ~= nil, "the ordinary species is patched")
  T.eq(patched.pokemon.ORDINARY.tmhm.__append[1], "TERABLAST",
    "appending TERABLAST rather than replacing the list")
  T.eq(patched.pokemon.FORM, nil, "the form pseudo-record is never patched")
  T.eq(#warned, 0, "nothing to warn about when everything exists")
  T.eq(#errored, 0, "nor to error about")
end

-- No bag index: the item never registers, but nothing else is held hostage
-- to it -- the same independence src/dragonascent.lua's own suite pins.
do
  local mod, registered, patched, warned, errored =
    stubMod({ pokemon = { ORDINARY = {} } })
  TM.install(mod, {})
  T.eq(registered.items.TM171, nil, "no bag index, no item")
  T.eq(#errored, 1, "and it is reported as an error")
  T.check(errored[1]:find("TM171", 1, true) ~= nil, "naming the item")
  T.check(errored[1]:find("data/tm171.lua", 1, true) ~= nil,
    "and the file to fix it in")
  T.eq(patched.moves.TERABLAST.effectModeled, true,
    "the move flag still goes ahead independently")
  T.check(patched.pokemon.ORDINARY ~= nil,
    "and teaching still goes ahead independently")
end

-- TERABLAST is not a registered move: the item still claims its bag byte
-- (permanent, the same rule every item table in this mod runs on), but
-- carries no `machine` field, gets no effect flag, and nothing is taught --
-- every one of those three would be an `f.id("moves")` reference to a move
-- that does not exist, which fails the loader's cross-reference pass.
do
  local mod, registered, patched, warned =
    stubMod({ moveMissing = true, pokemon = { ORDINARY = {} } })
  TM.install(mod, tmIndices)
  T.check(registered.items.TM171 ~= nil,
    "the item still registers -- a bag byte is permanent")
  T.eq(registered.items.TM171.machine, nil,
    "but carries no machine field, since it would name a move that is not there")
  T.eq(patched.moves.TERABLAST, nil,
    "no effectModeled patch without a move to attach it to")
  T.eq(next(patched.pokemon), nil,
    "and nothing is taught: a tmhm entry naming a nonexistent move would "
      .. "fail the loader's own cross-reference pass")
  T.eq(#warned, 1, "the missing move is reported")
  T.check(warned[1]:find("TERABLAST", 1, true) ~= nil, "naming it")
end

-- mod.content.pokemon:each is unavailable: the item and the move flag still
-- go through, but nothing can be taught without a way to walk the roster.
do
  local mod, registered, patched, warned = stubMod({ noEach = true })
  TM.install(mod, tmIndices)
  T.check(registered.items.TM171 ~= nil, "the item still registers")
  T.eq(patched.moves.TERABLAST.effectModeled, true, "and the move is still flagged")
  T.eq(next(patched.pokemon), nil,
    "but nothing can be taught without an each() to walk")
  T.eq(#warned, 1, "reported")
end

-- Every registered species is a form pseudo-record: nothing eligible, and
-- it says so rather than staying silent.
do
  local pokemon = { FORM = { baseSpecies = "X", form = "MEGA" } }
  local mod, registered, patched, warned = stubMod({ pokemon = pokemon })
  TM.install(mod, tmIndices)
  T.eq(next(patched.pokemon), nil, "no eligible species, no patches")
  T.eq(#warned, 1, "and it says so")
  T.check(warned[1]:find("TERABLAST", 1, true) ~= nil,
    "naming the move with nothing to teach")
end

-- ---------------------------------------------------------------------
-- Through the real loader: national_dex registers TERABLAST the way it
-- really does, plus a form pseudo-record this rule must exclude, and
-- battle_forms is loaded for real behind it -- the merged registries read
-- back the way the game would see them, not asserted against a stub of
-- this mod's own patches.
-- ---------------------------------------------------------------------
do
  local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local body = handle:read("*a")
    handle:close()
    return body
  end

  -- Read out of main.lua's own source rather than mirrored by hand, the
  -- way tests/battle_forms_dragonascent_test.lua's own loader block does.
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
    if name == "src/terablasttm.lua" then ok = true end
  end
  T.check(ok, "src/terablasttm.lua is one of the files main.lua actually loads")

  local NATIONAL_DEX_STUB = [[
return function(mod)
  mod.content.moves:register("TERABLAST", {
    id = "TERABLAST", name = "Tera Blast", type = "NORMAL",
    power = 80, accuracy = 100, pp = 10, category = "special",
    effect = "NO_ADDITIONAL_EFFECT", effectModeled = false,
  })
  -- A form pseudo-record, the exact shape M.eligible must exclude: this id
  -- can never be a battler's mon.species (src/tera.lua's own header states
  -- battle_forms never re-keys a Pokemon), so a tmhm entry on it would be
  -- unreachable in this engine no matter what taught it.
  mod.content.pokemon:register("FIXMON_A_MEGA", {
    id = "FIXMON_A_MEGA", name = "FIXMON A", dex = 1, form = "MEGA",
    baseSpecies = "FIXMON_A",
    types = { "GRASS" },
    baseStats = { hp = 80, attack = 90, defense = 90, speed = 80, special = 100 },
    catchRate = 45, baseExp = 64, growthRate = "MEDIUM_SLOW",
    level1Moves = {}, learnset = {}, evolutions = {},
    spriteFront = "assets/sets/placeholder/front.png",
    spriteBack = "assets/sets/placeholder/back.png",
    frontSize = 5,
  })
end
]]

  local files = {
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
    ["mods/national_dex/main.lua"] = NATIONAL_DEX_STUB,
  }
  for _, name in ipairs(shipped) do
    files["mods/battle_forms_mod/" .. name] = readFile(MOD .. "/" .. name)
  end

  local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
    fs = T.sdk.memfs(files), data = T.fixtures.fresh(),
  })
  T.eq(#run.errors, 0, "the mod loads clean against a real TERABLAST")

  -- The item.
  local item = run.data.items.TM171
  T.check(item ~= nil, "TM171 is registered")
  T.eq(item.index, 252, "with the bag byte data/tm171.lua assigns")
  T.eq(item.price, TM.PRICE, "and the mod's own price")
  T.eq(item.machine.kind, "TM", "a TM")
  T.eq(item.machine.move, "TERABLAST", "teaching TERABLAST")
  T.eq(item.machine.number, 171, "numbered 171, matching the real games")
  T.eq(item.tossable, true, "an ordinary, tossable TM")

  -- The move flag.
  local terablast = run.data.moves.TERABLAST
  T.eq(terablast.effectModeled, true,
    "TERA BLAST is flagged honestly modelled -- the type change IS "
      .. "src/tera.lua's own substitution, loaded here")
  T.eq(terablast.power, 80, "national_dex's own power is untouched")
  T.eq(terablast.type, "NORMAL", "and type")
  T.eq(terablast.category, "special",
    "and category -- the patch touched exactly one field")

  -- Reachability: the fixture species are patched in place, not replaced.
  local fixmonA = run.data.pokemon.FIXMON_A
  T.check(fixmonA ~= nil, "the fixture species survived the merge")
  local tmhmA = {}
  for _, id in ipairs(fixmonA.tmhm) do tmhmA[id] = true end
  T.check(tmhmA.FIX_CUT, "FIXMON_A's own TM/HM list keeps what it had")
  T.check(tmhmA.TERABLAST, "and gains TERABLAST")
  T.eq(#fixmonA.tmhm, 2, "appended, not replaced -- exactly the two entries")

  local fixmonB = run.data.pokemon.FIXMON_B
  T.eq(#fixmonB.tmhm, 1,
    "a species that started with an EMPTY tmhm list still gets exactly one entry")
  T.eq(fixmonB.tmhm[1], "TERABLAST", "which is TERABLAST")

  -- The form pseudo-record: never patched.
  local mega = run.data.pokemon.FIXMON_A_MEGA
  T.check(mega ~= nil, "the form record survived the merge too")
  T.eq(mega.tmhm, nil,
    "but was never taught -- it can never be a battler's mon.species, so a "
      .. "tmhm entry on it would be unreachable no matter what put it there")

  -- Sold: the Celadon department store's stone floor, immediately behind
  -- the key items (src/shop.lua's own M.installTM).
  local mart = run.data.text_pointers.CeladonMart4F.TEXT_CELADONMART4F_CLERK.mart
  local at = {}
  for i, id in ipairs(mart) do at[id] = i end
  T.check(at.TM171 ~= nil, "TM171 is on the Celadon shelf")
  T.check(at[KeyItems.Z_RING] and at.TM171 > at[KeyItems.Z_RING],
    "behind the key items, the last of which is the Z-Ring")

  -- --------------------------------------------------------------------
  -- The teach, driven through the engine's OWN item-use code
  -- (src/inventory/ItemEffects.lua) rather than reimplemented here -- the
  -- chain the whole task turns on: a save, an eligible Pokemon, and the
  -- real machine-item path (ItemEffects.lua:508-534).
  -- --------------------------------------------------------------------
  local ItemEffects = require("src.inventory.ItemEffects")
  local save = { player = { name = "RED" } }

  local mon = { species = "FIXMON_A", moves = { { id = "FIX_TACKLE", pp = 35 } } }
  local result, payload = ItemEffects.use(run.data, save, "TM171", mon)
  T.eq(result, "learn", "using TM171 on an eligible Pokemon offers to teach")
  T.eq(payload, "TERABLAST", "the move it offers is TERABLAST")

  -- The insertion itself is BagMenu.lua's own "learn" flow -- ItemEffects
  -- .lua's module header documents the contract
  -- (table.insert(target.moves, { id = moveId, pp = mdef.pp })) --
  -- reproduced here rather than driving the UI stack, the same way none of
  -- this mod's other suites touch BagMenu.lua either.
  table.insert(mon.moves, { id = payload, pp = run.data.moves[payload].pp })
  local learnedTerablast
  for _, slot in ipairs(mon.moves) do
    if slot.id == "TERABLAST" then learnedTerablast = slot end
  end
  T.check(learnedTerablast ~= nil,
    "TERA BLAST is now in the Pokemon's own moveset")
  T.eq(learnedTerablast.pp, run.data.moves.TERABLAST.pp,
    "taught at the move's own full PP")

  -- Using it again refuses cleanly: it already knows the move.
  local again, againMsg = ItemEffects.use(run.data, save, "TM171", mon)
  T.eq(again, "failed", "a Pokemon that already knows the move refuses TM171")
  T.check(againMsg and againMsg[1] ~= nil and
    (againMsg[1]:find("already", 1, true) or againMsg[1]:find("knows", 1, true)),
    "with the real already-knows message")

  -- An ineligible species refuses cleanly too: the engine's own gate,
  -- proven directly against a tmhm list that does not carry TERABLAST --
  -- the shape a species this rule did not reach would be in, if one
  -- existed. Under this rule none does among reachable species; the only
  -- excluded ids are form pseudo-records, and this engine can never hand
  -- ItemEffects.use a form id as target.species in the first place, since
  -- no transformation here ever rewrites mon.species -- so this proves the
  -- refusal MECHANISM the teach path above relies on, the same one that
  -- protects it.
  run.data.pokemon.FIXMON_NOT_ELIGIBLE = {
    name = "FIXMON NOT ELIGIBLE", tmhm = { "FIX_CUT" },
  }
  local other = { species = "FIXMON_NOT_ELIGIBLE", moves = {} }
  local refused, refusedMsg = ItemEffects.use(run.data, save, "TM171", other)
  T.eq(refused, "failed",
    "a species whose tmhm does not carry TERABLAST refuses cleanly")
  T.check(refusedMsg and refusedMsg[1] ~= nil and
    (refusedMsg[1]:find("learn", 1, true) or refusedMsg[1]:find("can't", 1, true)),
    "with the real can't-learn-that-move message")
  T.eq(#other.moves, 0, "and teaches it nothing")

  -- --------------------------------------------------------------------
  -- The substitution: the TM-taught move is not a special case. Once it
  -- sits in the Pokemon's own moveset, src/tera.lua's substitution treats
  -- it exactly like a move that was always there.
  -- --------------------------------------------------------------------
  local CHART = { matchups = {}, types = { FIRE = { name = "FIRE", category = "special" } } }
  local teraMod = {
    content = {
      type_chart = { get = function(_, id) return CHART.types[id] end },
      moves = { register = function() end },
      battle_anims = { register = function() end },
    },
  }
  Tera.bind({ keyitems = KeyItems, announce = Announce, log = nil,
              substitute = Substitute, anim = Anim, battlerof = Battlerof,
              chosen = function() return "FIRE" end })
  local catalog = Tera.install(teraMod, TERABLAST_TYPES)
  T.check(catalog.byType.FIRE ~= nil, "precondition: a FIRE variant was catalogued")

  local teraState = Tera.new()
  local entry = Tera.entry(teraState, catalog)
  local battler = { isPlayer = true, mon = mon, curMoves = mon.moves,
                     curTypes = { "NORMAL" } }
  local battle = { player = battler,
                    data = { type_chart = CHART, moves = run.data.moves },
                    game = { save = { inventory = { [KeyItems.TERA_ORB] = 1 } } } }

  entry.arm(battle)
  local substituted
  for _, slot in ipairs(battler.curMoves) do
    if slot.id == Tera.idFor("FIRE") then substituted = true end
  end
  T.check(substituted,
    "arming substitutes the TM-taught TERA BLAST slot exactly like any other")

  entry.disarm()
  local restored
  for _, slot in ipairs(battler.curMoves) do
    if slot.id == "TERABLAST" then restored = true end
  end
  T.check(restored, "and disarming restores the move the TM actually taught")
end

T.finish("battle_forms_terablasttm")
