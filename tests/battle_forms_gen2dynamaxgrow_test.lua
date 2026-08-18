-- Gold's "grow instead": a Dynamaxed Pokemon with no Gigantamax picture
-- gets a bigger one instead of standing there unchanged.
--
-- WHERE THE GROWTH ACTUALLY LIVES, and why not `BgEffects.picSize`.  That
-- field is the real engine's own grow/shrink facility (BATTLE_BG_EFFECT_
-- SHOW_MON/ENTER_MON/RETURN_MON in game/src/battle/gen2/BgEffects.lua), and
-- it answers BOX-SIZE INDICES, not a magnification: 0/1/2 are the player's
-- own 6x6/4x4/2x2 BG squares and 3/4/5 the enemy's 7x7/5x5/3x3, so PIC_
-- RESIZE_TILES (game/src/ui/gen2/BattleState.lua:580) never carries an
-- index bigger than "the mon's own box, at 1x" -- there is no size in that
-- table larger than normal, because every script that writes it is a
-- SHRINK (returning to the ball) or its reverse (entering the field), never
-- a grow past normal. It is also only ever read while `self.anim` is a
-- live AnimRunner (`BattleState:animPicState` returns nil otherwise,
-- BattleState.lua:1181-1192) -- true for the few frames a send-out or
-- return script plays, false for the rest of a battle a Dynamax has to
-- stay big through. Holding a battler enlarged for three whole turns
-- therefore cannot live in `picSize` at all: it would need an index that
-- table does not have, and would vanish the instant `self.anim` went nil,
-- i.e. within a few frames of the resize script that set it finishing.
--
-- `BattleState:picScale` (BattleState.lua:551-557) is the seam that IS read
-- on every draw, animation or not, and IS meant to compose with a resize
-- script already: "the pic's own scale ... composed with whatever square
-- BattleBGEffect_RunPicResizeScript has the mon drawn at this frame"
-- (BattleState.lua:659-661) is the class's own comment on exactly this
-- multiplication (BattleState.lua:665-666, `scale * (resized / boxTiles)`).
-- src/gen2dynamaxgrow.lua wraps that method the way src/gen2menu.lua wraps
-- `update`/`drawPanel` and src/gen2movemenu.lua wraps `drawPanel` a second
-- time: multiply the vanilla answer by M.SCALE when the mon being drawn is
-- the one Dynamaxed and showing no distinct form art, leave it alone
-- otherwise. Because the real resize script still runs on TOP of whatever
-- this returns (the multiplication above is unconditional), a Dynamaxed
-- mon returning to its ball still shrinks through the identical 6x6/4x4/2x2
-- steps -- just shrinking away from a bigger starting size -- and the two
-- mechanisms never write the same field, so there is nothing for them to
-- corrupt in each other.
--
-- WHY mon.form, NOT state.form, IS THE GATE.  src/dynamax.lua's own
-- `activate` only ever sets state.form when it successfully wins the
-- Gigantamax slot (`ok` true from `becomeForm`) -- a species with no
-- Gigantamax record, a refused one (data/gigantamax.lua names a form
-- national_dex has no record for), or a mon that Dynamaxed while ALREADY
-- wearing another mechanic's form (that block is skipped outright when
-- `mon.form` is already set -- src/dynamax.lua's own comment on the
-- "refusal that is not logged") all leave state.form nil. The first two are
-- exactly "nothing better to show" and should grow; the third is a mon
-- standing there in its MEGA picture, which is very much something better
-- to show, and must not also grow. `mon.form` tells the three apart where
-- `state.form` cannot: it is nil only in the first two cases, so checking
-- it directly is both simpler than re-deriving Gigantamax-specific state
-- here and correct for a case the brief never had to spell out.
--
-- WHY TEARDOWN NEEDS NOTHING OF ITS OWN.  M.scaleFor reads `state.mon` live,
-- the identical read-only relationship src/hpscale.lua already has with
-- this same record -- so the four paths that already clear it
-- (onTurnEnded, onBattlerSwitched, onFainted, and forget() at battle
-- start/end) end the growth in the exact same instant they end everything
-- else, with no fifth teardown to add or forget. Proven below by driving
-- the real src/dynamax.lua through all four rather than trusting the
-- argument.
--
-- WHY `states` IS A LIST, NOT A SINGLE RECORD.  Only the player's own side
-- can reach the DYNAMAX cell today (src/dynamax.lua's own header), so there
-- is exactly one state in main.lua's own array -- but M.scaleFor never
-- reads `battle.player` or asks which side `mon` is drawn on, only whether
-- it equals SOME tracked state's own `.mon`. An enemy Dynamax, whenever one
-- exists, is a second state table added to that same array and nothing
-- here would need to change; the block below proves that directly by
-- handing scaleFor a state whose `.mon` is an enemy-shaped mon and getting
-- the same answer a player-shaped one would.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Grow = dofile(MOD .. "/src/gen2dynamaxgrow.lua")
local Dynamax = dofile(MOD .. "/src/dynamax.lua")
local Gen2Forms = dofile(MOD .. "/src/gen2forms.lua")
local Gen2Substitute = dofile(MOD .. "/src/gen2substitute.lua")
local KeyItems = dofile(MOD .. "/src/keyitems.lua")
local Announce = dofile(MOD .. "/src/announce.lua")
local Battlerof = dofile(MOD .. "/src/battlerof.lua")

local Gen2Mon = require("src.battle.gen2.Mon")

-- ---------------------------------------------------------------------
-- M.scaleFor: the pure decision, no love2d and no engine class involved.
-- ---------------------------------------------------------------------
do
  local mon = { species = "PIDGEY" }
  local state = { mon = mon, form = nil }

  T.eq(Grow.scaleFor({ state }, mon), Grow.SCALE,
    "a Dynamaxed mon with no form at all grows")
  T.eq(Grow.scaleFor({ state }, { species = "PIDGEY" }), nil,
    "a different mon, even an identical-looking one, does not grow")
  T.eq(Grow.scaleFor({ state }, nil), nil, "no mon at all does not grow")
  T.eq(Grow.scaleFor(nil, mon), nil, "no states list at all does not grow")
  T.eq(Grow.scaleFor({}, mon), nil, "an empty states list does not grow")

  -- A real Gigantamax form landed on the mon: state.form and mon.form both
  -- carry it, and the growth defers to that picture.
  mon.form = "PIDGEY_GMAX"
  state.form = "PIDGEY_GMAX"
  T.eq(Grow.scaleFor({ state }, mon), nil,
    "a mon actually wearing its Gigantamax picture does not also grow")

  -- The refused case: data/gigantamax.lua named a form, becomeForm could
  -- not apply it (missing/misnamed national_dex record), so state.form
  -- stayed nil and so did mon.form -- the player is looking at the base
  -- picture and this is the case the brief calls "the interesting one".
  mon.form = nil
  state.form = nil
  T.eq(Grow.scaleFor({ state }, mon), Grow.SCALE,
    "a refused Gigantamax still grows -- the base picture is on screen")

  -- The mega-before-Dynamax case: mon.form is set to something that is not
  -- this Dynamax's own Gigantamax id at all (src/dynamax.lua's own
  -- activate() never touches the Gigantamax block once mon.form is already
  -- non-nil), so state.form never gets a value -- but the mon is standing
  -- there in ITS mega picture and must not grow on top of it.
  mon.form = "PIDGEY_MEGA"
  state.form = nil
  T.eq(Grow.scaleFor({ state }, mon), nil,
    "a mon Dynamaxed while already wearing another form's picture does not "
      .. "grow on top of it, even though this Dynamax's own state.form was "
      .. "never set")
end

-- ---------------------------------------------------------------------
-- Side-agnostic by construction: identical answer for an enemy-shaped mon,
-- proving nothing here reads battle.player.
-- ---------------------------------------------------------------------
do
  local enemyMon = { species = "GEODUDE" }
  -- Standing in for a state a hypothetical enemy Dynamax cell would hold --
  -- shaped exactly like src/dynamax.lua's own `state`, just never reachable
  -- from the menu today.
  local enemyState = { mon = enemyMon, form = nil }
  T.eq(Grow.scaleFor({ enemyState }, enemyMon), Grow.SCALE,
    "an enemy-side mon grows through the identical identity check a "
      .. "player-side one does -- nothing here special-cases battle.player")

  -- Two states at once (the shape a future roster of one-per-side states
  -- would actually take): each mon is checked against its own record and
  -- never the other's.
  local playerMon = { species = "RATTATA" }
  local playerState = { mon = playerMon, form = nil }
  local both = { playerState, enemyState }
  T.eq(Grow.scaleFor(both, playerMon), Grow.SCALE, "the player's own state matches")
  T.eq(Grow.scaleFor(both, enemyMon), Grow.SCALE, "and the enemy's own state matches")
  T.eq(Grow.scaleFor(both, { species = "RATTATA" }), nil,
    "a mon in neither state, even a same-species stand-in, does not grow")
end

-- ---------------------------------------------------------------------
-- The scale itself: derived from the box/HUD geometry in
-- game/src/ui/gen2/BattleState.lua, not guessed. A typical (~48px) pic on
-- either side stays clear of the box's own neighbouring HUD text and the
-- top of the screen at this scale; only the single largest vanilla front
-- pic (Onix, 56x56, filling its 7x7 box exactly) gives up a few pixels to
-- either -- see this file's own header and src/gen2dynamaxgrow.lua's for
-- the full pixel accounting.
-- ---------------------------------------------------------------------
do
  T.check(Grow.SCALE > 1, "the scale actually grows the pic")
  T.check(Grow.SCALE <= 1.2, "and stays within what the box geometry allows "
    .. "without swallowing the neighbouring HUD text for an ordinary pic")
end

-- ---------------------------------------------------------------------
-- Through the real engine class: M.install wraps the genuine
-- src.ui.gen2.BattleState.picScale, composes with battle_sprite_scales
-- and battleScaleFront/Back exactly like every other caller of that
-- method, and leaves an unrelated mon's scale untouched.
-- ---------------------------------------------------------------------
do
  local BattleState = require("src.ui.gen2.BattleState")
  local vanilla = BattleState.picScale
  T.check(type(vanilla) == "function", "precondition: the real method exists")

  local mon = { species = "SNORLAX" }
  local state = { mon = mon, form = nil }
  local mod = { log = { error = function() end } }

  T.eq(Grow.install(mod, { state }), true, "install succeeds against the real class")
  T.check(BattleState.picScale ~= vanilla, "picScale was actually wrapped")

  local fakeSelf = setmetatable({ pokemon = {}, game = { data = {} } },
    { __index = BattleState })
  T.eq(BattleState.picScale(fakeSelf, "assets/snorlax.png", mon, false),
    1 * Grow.SCALE, "the Dynamaxed mon's own draw is grown from the real "
      .. "vanilla base of 1")

  local other = { species = "PIDGEY" }
  T.eq(BattleState.picScale(fakeSelf, "assets/pidgey.png", other, false), 1,
    "a mon not held by any tracked state draws at the real vanilla scale")

  -- Composes with a species-level battleScaleFront/Back override, exactly
  -- the way the real box-resize multiplication already does -- proving
  -- this is one more source into the SAME multiplier, not a competing one.
  fakeSelf.pokemon.SNORLAX = { battleScaleFront = 2 }
  T.eq(BattleState.picScale(fakeSelf, "assets/snorlax.png", mon, false),
    2 * Grow.SCALE, "the species override and the growth multiply together")

  -- Composes with an image-level battle_sprite_scales record too -- the
  -- OTHER branch of the real vanilla picScale (BattleState.lua:538-549).
  fakeSelf.game.data.battle_sprite_scales = {
    entry = { path = "assets/snorlax.png", scale = 3 },
  }
  T.eq(BattleState.picScale(fakeSelf, "assets/snorlax.png", mon, false),
    3 * Grow.SCALE, "an image-level scale record wins the base the same way "
      .. "it always has, and growth still multiplies on top of it")

  -- Idempotency, matching every other engine_internals patch in this mod.
  local wrapped = BattleState.picScale
  T.eq(Grow.install(mod, { state }), true, "a second install still reports success")
  T.eq(BattleState.picScale, wrapped, "and wraps no further")
end

-- ---------------------------------------------------------------------
-- A missing or reshaped engine class refuses cleanly and says so, matching
-- CLAUDE.md's own rule: a guard that refuses must say so out loud.
-- ---------------------------------------------------------------------
do
  local savedLoaded = package.loaded["src.ui.gen2.BattleState"]
  package.loaded["src.ui.gen2.BattleState"] = { picScale = "not a function" }
  local logged = {}
  local mod = { log = { error = function(_, fmt, ...) logged[#logged + 1] =
    fmt:format(...) end } }
  T.eq(Grow.install(mod, {}), false,
    "a BattleState.picScale that is not a function refuses")
  T.check(#logged > 0 and logged[1]:find("battle_forms:", 1, true) ~= nil,
    "and logs through mod.log rather than doing nothing quietly")
  package.loaded["src.ui.gen2.BattleState"] = savedLoaded
end

do
  package.loaded["src.ui.gen2.BattleState"] = nil
  package.preload["src.ui.gen2.BattleState"] = function() error("no such module") end
  local logged = {}
  local mod = { log = { error = function(_, fmt, ...) logged[#logged + 1] =
    fmt:format(...) end } }
  T.eq(Grow.install(mod, {}), false, "an unrequireable BattleState refuses cleanly")
  T.check(#logged > 0, "and says so")
  package.preload["src.ui.gen2.BattleState"] = nil
  -- The failed require above left package.loaded holding Lua's own
  -- "still loading" sentinel (that is what "loop or previous error loading
  -- module" means), so it has to be cleared before a fresh require can
  -- succeed rather than immediately re-raising the same error.
  package.loaded["src.ui.gen2.BattleState"] = nil
  package.loaded["src.ui.gen2.BattleState"] = require("src.ui.gen2.BattleState")
end

-- ---------------------------------------------------------------------
-- Teardown, through the real src/dynamax.lua state machine rather than a
-- hand-built stand-in: all four paths that end a Dynamax already clear
-- state.mon, and that alone is proven to end the growth too, with nothing
-- added here to make it happen.
-- ---------------------------------------------------------------------
local DATA = { pokemon = {
  PIDGEY = { baseStats = { hp = 40, attack = 45, defense = 40, speed = 56,
                           specialAttack = 35, specialDefense = 35 },
             types = { "NORMAL", "FLYING" } },
} }
local DVS = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 }

local function newMon(species)
  local def = DATA.pokemon[species]
  local mon = {
    species = species, level = 50, nickname = "BIRD",
    dvs = { hp = DVS.hp, attack = DVS.attack, defense = DVS.defense,
            speed = DVS.speed, special = DVS.special },
    statExp = {},
    moves = { { id = "TACKLE", pp = 35, maxPp = 35 } },
    hp = 100,
  }
  mon.stats = Gen2Mon.stats(def.baseStats, mon.dvs, mon.level, mon.statExp)
  return mon
end

local function makeBattle(mon)
  local events = {}
  return {
    data = DATA, player = mon, party = { mon }, enemyParty = {},
    events = events,
    save = { inventory = { [KeyItems.DYNAMAX_BAND] = 1 } },
    emit = function(_, ev) events[#events + 1] = ev end,
    monName = function(_, m) return m and m.nickname end,
  }
end

Dynamax.bind({ gigantamax = {}, keyitems = KeyItems, announce = Announce,
               battlerof = Battlerof, gen2 = true, gen2forms = Gen2Forms,
               gen2substitute = Gen2Substitute })

-- Three turns, then the clock itself ends the growth.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle(newMon("PIDGEY"))
  local mon = battle.player

  entry.activate(battle)
  T.eq(Grow.scaleFor({ state }, mon), Grow.SCALE, "growing while Dynamaxed")

  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(Grow.scaleFor({ state }, mon), Grow.SCALE, "still growing, one turn down")
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(Grow.scaleFor({ state }, mon), Grow.SCALE, "still growing, two turns down")
  Dynamax.onTurnEnded(state, { battle = battle })
  T.eq(Grow.scaleFor({ state }, mon), nil,
    "the clock running out ends the growth with no code of this module's "
      .. "own involved")
end

-- Switching out ends it immediately, not on the next turn tick.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle(newMon("PIDGEY"))
  local outgoing = battle.player
  entry.activate(battle)
  T.eq(Grow.scaleFor({ state }, outgoing), Grow.SCALE, "growing before the switch")

  local incoming = newMon("PIDGEY")
  battle.player = incoming
  Dynamax.onBattlerSwitched(state, { battle = battle, battler = incoming,
                                     previous = outgoing })
  T.eq(Grow.scaleFor({ state }, outgoing), nil,
    "the mon that switched out no longer grows")
  T.eq(Grow.scaleFor({ state }, incoming), nil,
    "and the mon that came in was never Dynamaxed to begin with")
end

-- Fainting ends it.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle(newMon("PIDGEY"))
  local mon = battle.player
  entry.activate(battle)
  T.eq(Grow.scaleFor({ state }, mon), Grow.SCALE, "growing before the faint")

  Dynamax.onFainted(state, { battle = battle, battler = mon })
  T.eq(Grow.scaleFor({ state }, mon), nil,
    "a fainted mon does not keep drawing enlarged")
end

-- The battle ending ends it, even though Gen 2's own party sweep for the
-- form itself is deferred (src/deferred.lua) -- src/dynamax.lua's own state
-- is dropped immediately regardless, and that is all this module reads.
do
  local state = Dynamax.new()
  local entry = Dynamax.entry(state)
  local battle = makeBattle(newMon("PIDGEY"))
  local mon = battle.player
  entry.activate(battle)
  T.eq(Grow.scaleFor({ state }, mon), Grow.SCALE, "growing before the battle ends")

  Dynamax.onBattleEnded(state)
  T.eq(Grow.scaleFor({ state }, mon), nil,
    "the battle ending ends the growth in the same instant it ends "
      .. "everything else src/dynamax.lua's own state was holding")
end

T.finish("battle_forms_gen2dynamaxgrow")
