-- G-Max Moves: names, types and powers only, layered onto the same
-- move-substitution mechanism src/maxmoves.lua's eighteen type rows already
-- own -- checked FIRST, on every slot independently, and falling back to the
-- ordinary Max Move wherever it has nothing to say.
--
-- Three things this suite exists to prove. First, that the roster matches
-- data/gigantamax.lua's own wired species exactly -- neither more (a G-Max
-- Move for a form nothing can show) nor fewer (a Gigantamax species left
-- with only an ordinary Max Move by omission rather than by the art gap
-- data/gigantamax.lua's own header names). Second, that the seven-rung power
-- ladder is READ off src/maxmoves.lua rather than duplicated, so Machamp's
-- and Garbodor's lowered rungs can never drift out of step with MAX
-- KNUCKLE's and MAX OOZE's own. Third, and most load-bearing, that
-- src/dynamax.lua's arm step tries this catalog before the ordinary one on
-- EVERY slot, not merely on the Pokemon as a whole -- a Gigantamax
-- Charizard's Body Slam must still become MAX STRIKE while its Ember becomes
-- G-MAX WILDFIRE, in the same moveset, on the same turn.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local GMax = dofile(MOD .. "/src/gmaxmoves.lua")
local MaxMoves = dofile(MOD .. "/src/maxmoves.lua")
local Substitute = dofile(MOD .. "/src/substitute.lua")
local Anim = dofile(MOD .. "/src/anim.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local Forms = dofile(MOD .. "/src/forms.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")
local ROWS = dofile(MOD .. "/data/gmaxmoves.lua")
local MAXROWS = dofile(MOD .. "/data/maxmoves.lua")
local SPECIESZ_ROWS = dofile(MOD .. "/data/speciesz.lua")
local GIGANTAMAX = dofile(MOD .. "/data/gigantamax.lua")

local RED_TYPES = { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK",
                    "BUG", "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC",
                    "PSYCHIC_TYPE", "ICE", "DRAGON" }
local ALL_TYPES = { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK",
                    "BUG", "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC",
                    "PSYCHIC_TYPE", "ICE", "DRAGON", "DARK", "STEEL", "FAIRY" }

local function chartOf(list)
  local chart = {}
  for _, id in ipairs(list) do chart[id] = { name = id, category = "physical" } end
  return chart
end

local function stubMod(chart)
  local warned = {}
  -- move_effects is unused by this file's own M.install (G-Max Moves carry
  -- no effect record of their own) but is registered anyway, so the same
  -- stub can host src/maxmoves.lua's own install too when a test composes
  -- both catalogs the way src/dynamax.lua's arm step actually does.
  local buckets = { moves = {}, battle_anims = {}, move_effects = {} }
  local content = {}
  for name, bucket in pairs(buckets) do
    content[name] = {
      register = function(_, id, record)
        T.check(bucket[id] == nil, name .. " id registered once: " .. tostring(id))
        bucket[id] = record
      end,
    }
  end
  content.type_chart = { get = function(_, id) return chart[id] end }
  return {
    content = content,
    log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt:format(...) end },
    registered = buckets,
    warned = warned,
  }
end

local function bindGmax(mod)
  GMax.bind({ anim = Anim, log = mod and mod.log, substitute = Substitute,
              maxmoves = MaxMoves })
end

-- ---------------------------------------------------------------------
-- The roster: matches data/gigantamax.lua's own wired species exactly, and
-- every row is well-formed.
-- ---------------------------------------------------------------------
do
  local gigantamaxSpecies, rowSpecies = {}, {}
  for species in pairs(GIGANTAMAX) do gigantamaxSpecies[#gigantamaxSpecies + 1] = species end
  table.sort(gigantamaxSpecies)

  local seenSpecies, seenStem = {}, {}
  for _, row in ipairs(ROWS) do
    T.check(type(row.species) == "string" and row.species ~= "",
      "every row carries a species")
    T.check(not seenSpecies[row.species], row.species .. " appears once")
    seenSpecies[row.species] = true
    rowSpecies[#rowSpecies + 1] = row.species

    T.check(type(row.stem) == "string" and row.stem ~= "",
      row.species .. " carries a stem")
    T.check(not seenStem[row.stem], row.stem .. " is not reused by another row")
    seenStem[row.stem] = true

    T.check(type(row.type) == "string" and row.type ~= "",
      row.species .. " carries a type")
    T.check(type(row.name) == "string" and row.name:sub(1, 6) == "G-MAX ",
      row.species .. "'s real name reads G-MAX ...: " .. tostring(row.name))
    T.check(type(row.menu) == "string" and row.menu ~= "",
      row.species .. " carries a FIGHT-menu display name")
    if row.power then
      T.eq(row.power, 160, row.species .. "'s fixed power is the real games' 160")
    end
  end
  table.sort(rowSpecies)

  T.eq(#ROWS, 31, "data/gmaxmoves.lua wires exactly the 31 species it says it does")
  T.eq(table.concat(rowSpecies, ","), table.concat(gigantamaxSpecies, ","),
    "and its species set is EXACTLY data/gigantamax.lua's own -- no more, no "
      .. "fewer, so a G-Max Move can never be wired for a form nothing can "
      .. "show or omitted for a species that is otherwise fully wired")

  -- The three fixed-power rows named in data/gmaxmoves.lua's own header.
  local fixed = {}
  for _, row in ipairs(ROWS) do
    if row.power then fixed[#fixed + 1] = row.species end
  end
  table.sort(fixed)
  T.eq(table.concat(fixed, ","), "CINDERACE,INTELEON,RILLABOOM",
    "exactly the three G-Max Moves whose real effect is fully expressible "
      .. "here -- fixed 160 power, ignoring an ability this engine does not "
      .. "have -- carry a fixed power; every other row rides the ladder")

  -- No id this file can produce may collide with the ordinary Max Move
  -- roster's or the species Z-Move roster's own stems -- all three share the
  -- one BATTLE_FORMS_ prefix.
  local maxmoveStems = {}
  for _, row in ipairs(MAXROWS.types) do maxmoveStems[row.stem] = true end
  maxmoveStems[MAXROWS.guard.stem] = true
  local speciesZStems = {}
  for _, row in ipairs(SPECIESZ_ROWS) do speciesZStems[row.stem] = true end
  for stem in pairs(seenStem) do
    T.check(not maxmoveStems[stem], stem .. " does not collide with an "
      .. "ordinary Max Move's stem")
    T.check(not speciesZStems[stem], stem .. " does not collide with a "
      .. "species Z-Move's stem")
  end
end

-- ---------------------------------------------------------------------
-- The FIGHT menu's own names (`menu`): every row fits both layout budgets,
-- and the longest shipped one is pinned at the tighter of the two -- the
-- same measured budget data/zmoves.lua's own header cites (BattleState.lua's
-- moveSelect draws a name at x=48 with the move box's border at x=152, and
-- WideBattle.lua's fitName gets a 96px = 12-column budget).
-- ---------------------------------------------------------------------
do
  local CLASSIC_BUDGET = 13
  local WIDE_BUDGET = 12

  local longestMenu, longestLen = nil, 0
  for _, row in ipairs(ROWS) do
    T.check(#row.menu <= WIDE_BUDGET,
      ("%s (%d chars) fits the widescreen grid's %d-column budget"):format(
        row.menu, #row.menu, WIDE_BUDGET))
    T.check(#row.menu <= CLASSIC_BUDGET,
      ("%s (%d chars) fits the classic FIGHT menu's %d-column budget"):format(
        row.menu, #row.menu, CLASSIC_BUDGET))
    if #row.menu > longestLen then longestMenu, longestLen = row.menu, #row.menu end
  end
  -- Pinned at the boundary itself: the longest name shipped sits exactly on
  -- the tighter budget, so a future rename that adds even one more
  -- character overflows widescreen and this assertion catches it rather
  -- than the player.
  T.eq(longestLen, WIDE_BUDGET,
    "the longest shipped name (" .. tostring(longestMenu) .. ") sits "
      .. "exactly on the tighter of the two budgets")

  local names = GMax.menuNames(ROWS, MAXROWS)
  local mapped = 0
  for _, row in ipairs(ROWS) do
    if row.power then
      mapped = mapped + 1
      T.eq(names[GMax.idFor(row.stem, row.power)], row.menu,
        row.stem .. "'s one fixed-power record shares the row's display name")
    else
      for _, rung in ipairs(MAXROWS.ladder) do
        local power = (MAXROWS.lowered and MAXROWS.lowered[row.type])
          and rung.loweredPower or rung.power
        mapped = mapped + 1
        T.eq(names[GMax.idFor(row.stem, power)], row.menu,
          row.stem .. "'s every rung shares the row's one display name")
      end
    end
  end
  T.check(mapped > 0, "the mapping loop actually walked some rows")

  T.eq(next(GMax.menuNames({}, MAXROWS)), nil,
    "no rows, no names -- the function reads the roster, not the ladder alone")
end

-- ---------------------------------------------------------------------
-- Registration: gated on the merged type chart, exactly like the ordinary
-- Max Moves -- a row whose type this game's chart cannot resolve is skipped
-- and logged rather than registered half-working.
-- ---------------------------------------------------------------------

-- Computed from the roster itself rather than hand-counted, so a future row
-- added to data/gmaxmoves.lua is covered by this guard the moment it exists.
local function expectedFor(availableTypes)
  local avail = {}
  for _, t in ipairs(availableTypes) do avail[t] = true end
  local records, warnings = 0, 0
  for _, row in ipairs(ROWS) do
    if avail[row.type] then
      records = records + (row.power and 1 or #MAXROWS.ladder)
    else
      warnings = warnings + 1
    end
  end
  return records, warnings
end

do
  local mod = stubMod(chartOf(RED_TYPES))
  bindGmax(mod)
  local catalog = GMax.install(mod, ROWS, MAXROWS)

  local expectRecords, expectWarnings = expectedFor(RED_TYPES)
  local count = 0
  for _ in pairs(mod.registered.moves) do count = count + 1 end
  T.eq(count, expectRecords,
    "under Red's fifteen types, every row whose type is among them registers "
      .. "its full rung count")
  T.eq(#mod.warned, expectWarnings,
    "and the rows whose type is Fairy, Dark or Steel are logged, not "
      .. "swallowed")
  T.check(mod.warned[1] ~= nil and mod.warned[1]:find("no G-Max Move for", 1, true) ~= nil,
    "the warning names what it refused")

  -- One laddered row, checked at its bottom and top rungs.
  local wildfire90 = mod.registered.moves[GMax.idFor("GMAXWILDFIRE", 90)]
  T.check(wildfire90 ~= nil, "G-MAX WILDFIRE registered at the bottom rung")
  T.eq(wildfire90.id, GMax.idFor("GMAXWILDFIRE", 90),
    "the record's id equals the key it was registered under")
  T.eq(wildfire90.name, "G-MAX WILDFIRE", "with the real, unshortened name")
  T.eq(wildfire90.type, "FIRE", "the row's own type")
  T.eq(wildfire90.power, 90, "the rung's power")
  T.eq(wildfire90.accuracy, 100, "an accuracy a move record can express")
  T.eq(wildfire90.pp, GMax.RECORD_PP, "the PP the menu's maximum is built from")
  T.eq(wildfire90.effect, "NO_ADDITIONAL_EFFECT", "and a vanilla effect id")
  T.eq(wildfire90.category, nil,
    "with no category, so Gen 1's own type split decides it")
  T.check(mod.registered.moves[GMax.idFor("GMAXWILDFIRE", 150)] ~= nil,
    "and at the top rung too")

  -- The lowered ladder: Machamp's Fighting row lands on MAX KNUCKLE's own
  -- lowered numbers, never on the standard ones.
  T.check(mod.registered.moves[GMax.idFor("GMAXCHISTRIKE", 70)] ~= nil,
    "G-MAX CHI STRIKE registers on the lowered ladder's bottom rung")
  T.eq(mod.registered.moves[GMax.idFor("GMAXCHISTRIKE", 130)], nil,
    "and never on a standard rung the lower ladder does not reach")

  -- The three fixed-power rows: exactly one record, at 160, whatever base
  -- power a move it replaces would have carried.
  local fireball = mod.registered.moves[GMax.idFor("GMAXFIREBALL", 160)]
  T.check(fireball ~= nil, "G-MAX FIREBALL registers at its fixed power")
  T.eq(fireball.power, 160, "160, the real games' own fixed number")
  local fireballRungs = 0
  for id in pairs(mod.registered.moves) do
    if id:match("^" .. GMax.PREFIX .. "GMAXFIREBALL_") then fireballRungs = fireballRungs + 1 end
  end
  T.eq(fireballRungs, 1, "and only ONE record -- a fixed-power row rides no ladder")

  -- Every id is also an animation id.
  for id in pairs(mod.registered.moves) do
    T.check(mod.registered.battle_anims[id] ~= nil,
      "an animation is registered for " .. id)
    T.check(#mod.registered.battle_anims[id].seq > 0, "with rows in it for " .. id)
  end

  -- Every id wears the mod's name.
  for id in pairs(mod.registered.moves) do
    T.eq(id:sub(1, #GMax.PREFIX), GMax.PREFIX, id .. " is namespaced to this mod")
  end

  -- The catalog answers for the species this chart could resolve and stays
  -- silent about the ones it could not.
  T.check(catalog.bySpecies.CHARIZARD ~= nil, "CHARIZARD resolved (Fire)")
  T.eq(catalog.bySpecies.ALCREMIE, nil,
    "ALCREMIE did not -- Fairy is not among Red's fifteen types")
end

-- With the modern chart, nothing is refused.
do
  local mod = stubMod(chartOf(ALL_TYPES))
  bindGmax(mod)
  local catalog = GMax.install(mod, ROWS, MAXROWS)
  local expectRecords, expectWarnings = expectedFor(ALL_TYPES)

  local count = 0
  for _ in pairs(mod.registered.moves) do count = count + 1 end
  T.eq(count, expectRecords, "every row registers its full rung count")
  T.eq(#mod.warned, expectWarnings, "and nothing is refused")
  T.eq(expectWarnings, 0, "precondition: the full chart leaves nothing out")
  T.check(catalog.bySpecies.ALCREMIE ~= nil, "and ALCREMIE resolves now")
end

-- A build whose registry offers no `get` leaves every row out rather than
-- taking the mod down with a nil call -- the same resilience
-- src/maxmoves.lua's own equivalent test pins.
do
  local mod = stubMod({})
  mod.content.type_chart = {}
  bindGmax(mod)
  local catalog = GMax.install(mod, ROWS, MAXROWS)
  local count = 0
  for _ in pairs(mod.registered.moves) do count = count + 1 end
  T.eq(count, 0, "nothing registers -- there is no type this chart resolves")
  T.eq(#mod.warned, #ROWS, "and every row was refused and said so")
  T.eq(next(catalog.bySpecies), nil, "the catalog answers for no species at all")
end

-- ---------------------------------------------------------------------
-- Which record a move slot becomes -- and, just as importantly, which slots
-- this catalog leaves alone for the ordinary Max Move picker to decide.
-- ---------------------------------------------------------------------
local MOVES = {
  EMBER =     { id = "EMBER", name = "EMBER", type = "FIRE", power = 40,
                accuracy = 100, pp = 25, effect = "NO_ADDITIONAL_EFFECT" },
  FLAMETHROWER = { id = "FLAMETHROWER", name = "FLAMETHROWER", type = "FIRE",
                power = 95, accuracy = 100, pp = 15, effect = "NO_ADDITIONAL_EFFECT" },
  SMOKESCREEN = { id = "SMOKESCREEN", name = "SMOKESCREEN", type = "FIRE",
                power = 0, accuracy = 100, pp = 20, effect = "ACCURACY_DOWN1_EFFECT" },
  BODYSLAM =  { id = "BODYSLAM", name = "BODY SLAM", type = "NORMAL", power = 85,
                accuracy = 100, pp = 15, effect = "NO_ADDITIONAL_EFFECT" },
  LOWKICK =   { id = "LOWKICK", name = "LOW KICK", type = "FIGHTING", power = 50,
                accuracy = 90, pp = 20, effect = "NO_ADDITIONAL_EFFECT" },
  GROWL =     { id = "GROWL", name = "GROWL", type = "NORMAL", power = 0,
                accuracy = 100, pp = 40, effect = "ATTACK_DOWN1_EFFECT" },
}

do
  local mod = stubMod(chartOf(ALL_TYPES))
  bindGmax(mod)
  local catalog = GMax.install(mod, ROWS, MAXROWS)
  local data = { moves = MOVES }

  local ember = GMax.fieldsFor(catalog, data, { species = "CHARIZARD" },
    { id = "EMBER", pp = 25 })
  T.eq(ember.id, GMax.idFor("GMAXWILDFIRE", 90),
    "a Gigantamax Charizard's 40-power Fire move becomes G-MAX WILDFIRE at 90, "
      .. "the same rung MAX FLARE would land on")
  local flamethrower = GMax.fieldsFor(catalog, data, { species = "CHARIZARD" },
    { id = "FLAMETHROWER", pp = 15 })
  T.eq(flamethrower.id, GMax.idFor("GMAXWILDFIRE", 140),
    "and a 95-power one climbs the same ladder to 140")

  T.eq(GMax.fieldsFor(catalog, data, { species = "CHARIZARD" },
    { id = "BODYSLAM", pp = 15 }), nil,
    "a Normal move stays nil here -- Charizard's G-Max Move is Fire-only, so "
      .. "this slot is left for the ordinary Max Move picker to claim")
  T.eq(GMax.fieldsFor(catalog, data, { species = "CHARIZARD" },
    { id = "SMOKESCREEN", pp = 20 }), nil,
    "a Fire STATUS move also stays nil -- G-Max Moves never replace a status "
      .. "move, MAX GUARD does, universally, through the ordinary picker")

  -- The fixed-power row: 160 whatever the base move's own power is.
  local cinderEmber = GMax.fieldsFor(catalog, data, { species = "CINDERACE" },
    { id = "EMBER", pp = 25 })
  T.eq(cinderEmber.id, GMax.idFor("GMAXFIREBALL", 160),
    "a Gigantamax Cinderace's 40-power Fire move becomes G-MAX FIREBALL at "
      .. "its fixed 160")
  local cinderFlame = GMax.fieldsFor(catalog, data, { species = "CINDERACE" },
    { id = "FLAMETHROWER", pp = 15 })
  T.eq(cinderFlame.id, GMax.idFor("GMAXFIREBALL", 160),
    "and so does a 95-power one -- the fixed row does not ladder")

  -- The lowered ladder, on a live pick rather than only on the registered
  -- shelf.
  local chistrike = GMax.fieldsFor(catalog, data, { species = "MACHAMP" },
    { id = "LOWKICK", pp = 20 })
  T.eq(chistrike.id, GMax.idFor("GMAXCHISTRIKE", 75),
    "a Gigantamax Machamp's 50-power Fighting move takes the lower ladder, "
      .. "landing where MAX KNUCKLE would")

  -- No entry for the species at all.
  T.eq(GMax.fieldsFor(catalog, data, { species = "PIDGEY" },
    { id = "EMBER", pp = 25 }), nil,
    "a species with no G-Max Move leaves every slot alone")
  T.eq(GMax.fieldsFor(catalog, data, nil, { id = "EMBER", pp = 25 }), nil,
    "and so does no mon at all")
  T.eq(GMax.fieldsFor(catalog, data, { species = "CHARIZARD" }, nil), nil,
    "and no slot at all")
  T.eq(GMax.fieldsFor(catalog, data, { species = "CHARIZARD" },
    { id = "NOSUCHMOVE", pp = 5 }), nil,
    "an unknown move id has no type or power to read")

  -- The synthesised ppUps, the same menu-maximum correction
  -- src/maxmoves.lua's own picker carries.
  local function menuMax(fields)
    local def = mod.registered.moves[fields.id]
    return def.pp + (fields.ppUps or 0) * math.floor(def.pp / 5)
  end
  T.eq(menuMax(ember), 25, "the menu draws EMBER's own maximum of 25")
  T.eq(menuMax(cinderEmber), 25, "the same holds for the fixed-power row")
  local upped = GMax.fieldsFor(catalog, data, { species = "CHARIZARD" },
    { id = "EMBER", pp = 30, ppUps = 1 })
  T.eq(menuMax(upped), 30, "and a PP Up on the slot still shows through")
end

-- ---------------------------------------------------------------------
-- src/dynamax.lua's arm step: this catalog checked BEFORE the ordinary Max
-- Move picker, on every slot independently -- the composition
-- src/dynamax.lua's own header promises and main.lua actually wires,
-- reproduced here with the two real pickers rather than a stand-in.
-- ---------------------------------------------------------------------
do
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

  local maxMod = stubMod(chartOf(ALL_TYPES))
  MaxMoves.bind({ anim = Anim, announce = Announce, log = maxMod.log,
                  guard = MaxMoves.newGuard(), substitute = Substitute })
  local MAX_CATALOG = MaxMoves.install(maxMod, MAXROWS)
  for id, record in pairs(maxMod.registered.moves) do MOVES[id] = record end

  local gmaxMod = stubMod(chartOf(ALL_TYPES))
  bindGmax(gmaxMod)
  local GMAX_CATALOG = GMax.install(gmaxMod, ROWS, MAXROWS)
  for id, record in pairs(gmaxMod.registered.moves) do MOVES[id] = record end

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
    local mon = newMon(species)
    local said = {}
    return {
      data = DATA, said = said,
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

  -- The two picker-factories exactly as main.lua binds them -- the
  -- composition itself lives in src/dynamax.lua's own `arm`, not here, so
  -- this drives the REAL fallback order rather than a copy of it.
  Dynamax.bind({ forms = Forms, gigantamax = { CHARIZARD = "CHARIZARD_GMAX" },
                 keyitems = KeyItems, announce = Announce,
                 substitute = Substitute, battlerof = Battlerof,
                 maxMoves = function(data)
                   return MaxMoves.picker(MAX_CATALOG, data)
                 end,
                 gmaxMoves = function(data, mon)
                   return GMax.picker(GMAX_CATALOG, data, mon)
                 end })

  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle("CHARIZARD")
  local battler = battle.player

  T.eq(entry.arm(battle), true,
    "arming a Gigantamax-eligible Charizard substitutes")
  T.eq(battler.curMoves[1].id, GMax.idFor("GMAXWILDFIRE", 90),
    "EMBER, a Fire move, becomes G-MAX WILDFIRE -- the species-aware picker "
      .. "wins on the matching type")
  T.eq(battler.curMoves[2].id, MaxMoves.idFor("MAXSTRIKE", 130),
    "BODY SLAM, a Normal move, falls through to the ordinary MAX STRIKE -- "
      .. "Charizard's G-Max Move is Fire-only")
  T.eq(battler.curMoves[3].id, MaxMoves.idFor("MAXKNUCKLE", 75),
    "LOW KICK falls through the same way, to MAX KNUCKLE")
  T.eq(battler.curMoves[4].id, MAX_CATALOG.guard,
    "and GROWL still becomes MAX GUARD -- a G-Max Move never covers a "
      .. "status move")

  entry.disarm()
  T.eq(battler.curMoves, battler.mon.moves, "disarming restores the array")

  -- A species with no Gigantamax form gets ordinary Max Moves throughout,
  -- exactly as it did before this catalog existed -- the fallback is not
  -- merely per-slot, it is also silent when the whole species has nothing.
  local pidgeyBattle = makeBattle("PIDGEY")
  local pidgeyBattler = pidgeyBattle.player
  T.eq(entry.arm(pidgeyBattle), true, "arming a plain Dynamax still substitutes")
  T.eq(pidgeyBattler.curMoves[1].id, MaxMoves.idFor("MAXFLARE", 90),
    "EMBER becomes the ordinary MAX FLARE -- Pidgey carries no G-Max Move at all")
  entry.disarm()
end

-- ---------------------------------------------------------------------
-- Through the real loader: main.lua's own wiring, not a hand mirror of it.
-- ---------------------------------------------------------------------
do
  local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local body = handle:read("*a")
    handle:close()
    return body
  end

  -- Read out of main.lua's own source rather than mirrored by hand, the
  -- same reason tests/battle_forms_maxmoves_test.lua's own final block does.
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
  T.eq(#run.errors, 0, "the mod loads clean with the G-Max roster registered too")

  local wildfire = run.data.moves[GMax.idFor("GMAXWILDFIRE", 90)]
  T.check(wildfire ~= nil,
    "G-MAX WILDFIRE survived the merge -- Fire is one of Red's fifteen types")
  T.eq(wildfire.type, "FIRE", "with its type resolved against the chart")
  T.eq(wildfire.name, "G-MAX WILDFIRE", "and its real, unshortened name")

  T.eq(run.data.moves[GMax.idFor("GMAXFINALE", 90)], nil,
    "and no G-MAX FINALE -- this fixture chart is Red's fifteen types and "
      .. "Fairy is not among them")

  local fireball = run.data.moves[GMax.idFor("GMAXFIREBALL", 160)]
  T.check(fireball ~= nil, "the fixed-power G-MAX FIREBALL survived the merge too")
  T.eq(fireball.power, 160, "at its fixed power")

  local anims = (run.data.battle_anims or {}).moveAnims or {}
  T.check(anims[GMax.idFor("GMAXWILDFIRE", 90)] ~= nil,
    "an animation is merged in for the G-Max roster too")

  -- ---------------------------------------------------------------------
  -- The trap named in src/gmaxmoves.lua's own header: zmovemenu.install may
  -- only ever be called once, so a G-Max name that main.lua forgot to fold
  -- into the SAME map handed to that one call would silently never draw --
  -- "G-MAX WILDFIRE" would run straight into the move box border rather
  -- than showing "WILDFIRE". Proven through the REAL classic FIGHT-menu
  -- redraw src/zmovemenu.lua patched during the load above (Lua modules are
  -- singletons through package.loaded, the same fact
  -- tests/battle_forms_diag_test.lua's own real-loader block relies on) --
  -- not a hand-built name map fed to src/zmovemenu.lua directly, which
  -- would still pass even if main.lua itself never performed the merge.
  -- ---------------------------------------------------------------------
  local BattleState = require("src.battle.BattleState")
  T.check(BattleState._battleFormsZMoveMenuPatched == true,
    "the real classic FIGHT menu draw was actually wrapped by this load")

  local Font = require("src.render.Font")
  local drawn = {}
  local originalDraw = Font.draw
  Font.draw = function(text, x, y) drawn[#drawn + 1] = { text = text, x = x, y = y } end

  local ok = pcall(BattleState.drawTextArea, { phase = "moveSelect",
    player = { curMoves = { { id = GMax.idFor("GMAXWILDFIRE", 90) } } } })
  Font.draw = originalDraw
  T.check(ok, "the wrapped draw does not throw against a real G-Max move id")
  T.eq(#drawn, 1, "the FIGHT menu redrew the one G-Max slot")
  T.eq(drawn[1] and drawn[1].text, "WILDFIRE",
    "with data/gmaxmoves.lua's own short menu name -- not the real, "
      .. "fourteen-column \"G-MAX WILDFIRE\" the vanilla draw would have left")
end

T.finish("battle_forms_gmaxmoves")
