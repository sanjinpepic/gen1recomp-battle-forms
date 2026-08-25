-- Enemy trainers reaching for a gimmick, decided as a pure function.
--
-- The decision is party + trainer id + what the PLAYER has unlocked + what the
-- ace can do, in; a gimmick id, out. No battle, no registry, no engine -- which
-- is the point: every rule this feature has is a rule about that function, and
-- a suite that needed a live battle to check "does Brock always pick the same
-- thing" would be checking the battle instead.
--
-- Two of these tests are about something that would never be visible on
-- screen. src/arm.lua holds ONE once-per-battle flag for the whole battle
-- rather than one per side, so an enemy activation routed through it would
-- spend the PLAYER'S allowance -- they arm their mega, the gym leader moves
-- first, and their own cell is dead for the rest of the fight with nothing
-- said. The separation is pinned here because the symptom is a menu cell that
-- quietly stops working.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local AI = dofile(MOD .. "/src/trainerai.lua")

local function party(...)
  local out = {}
  for _, level in ipairs({ ... }) do
    out[#out + 1] = { species = "MON" .. level, level = level }
  end
  return out
end

local ALL = function() return true end
local NONE = function() return false end
local function only(want)
  return function(_, id) return id == want end
end
local UNLOCKED = { KEY_STONE = true, Z_RING = true }
local function scripted(v) local i = 0 return function(lo, hi)
  i = i + 1 local x = v[i] or lo
  if x < lo then return lo end if x > hi then return hi end return x end end

-- --- the ace ---------------------------------------------------------------
T.eq(AI.aceOf(party(12, 30, 18)).level, 30, "the highest level is the ace")
T.eq(AI.aceOf(party(30, 14, 30)).species, "MON30", "a tie goes to the later slot")
T.eq(AI.aceOf({}), nil, "an empty party has no ace")
T.eq(AI.aceOf(nil), nil, "and neither does no party")
-- A roster row with no level at all is skipped rather than treated as level 0:
-- the real party is engine data and a malformed row must not become the ace.
T.eq(AI.aceOf({ { species = "A" }, { species = "B", level = 5 } }).species, "B",
  "a row with no level is not eligible to be the ace")

-- --- the gate --------------------------------------------------------------
local function decide(over)
  local ctx = { party = party(10, 40), trainerId = "OPP_BROCK",
                hasAiClass = true, unlocked = UNLOCKED, canDo = ALL,
                rng = scripted({ 1 }) }
  for k, v in pairs(over or {}) do ctx[k] = v end
  return AI.decide(ctx)
end

T.check(decide() ~= nil, "with the items held, a gym leader reaches for one")
T.eq(decide({ unlocked = {} }), nil, "holding nothing, nothing happens")
-- Under "any" the item held does not decide WHICH gimmick -- what the ace can
-- do decides that, and the seed picks among them.
T.check(decide({ unlocked = { KEY_STONE = true } }) ~= nil,
  "one item held opens the roll")
-- --- GATE_MODE: what one key item buys -------------------------------------
-- "any" is the default. The Key Stone is almost always the first item a player
-- gets, so gating each gimmick on its own item would make the whole early game
-- mega evolutions and nothing else -- and mega reaches 86 species, which on
-- Gold leaves ten of the fourteen leaders unable to do anything at all.
T.eq(AI.GATE_MODE, "any", "one item opens all four by default")
local everything = function() return true end
for _, item in ipairs({ "KEY_STONE", "Z_RING", "TERA_ORB", "DYNAMAX_BAND" }) do
  T.check(decide({ unlocked = { [item] = true }, canDo = everything }) ~= nil,
    "holding " .. item .. " alone opens something")
end
-- ...but only ever something the ace can actually do, so "any" can never
-- announce a transformation that does not happen.
T.eq(decide({ unlocked = { KEY_STONE = true }, canDo = only("tera") }), "tera",
  "and it is filtered by what the Pokemon can do, not by which item was held")
T.eq(decide({ unlocked = { KEY_STONE = true }, canDo = NONE }), nil,
  "an ace that can do nothing still does nothing")

-- The strict mode is still there and still works.
AI.GATE_MODE = "per_gimmick"
T.eq(decide({ unlocked = { Z_RING = true }, canDo = everything }), "zmove",
  "under per_gimmick the Z-Ring opens the Z-Move and nothing else")
T.eq(decide({ unlocked = { TERA_ORB = true }, canDo = everything }), "tera",
  "and the Orb opens tera")
T.eq(decide({ unlocked = { KEY_STONE = true }, canDo = only("tera") }), nil,
  "and a Key Stone does not open a Terastallization")
AI.GATE_MODE = "any"

-- The gate is the PLAYER's item, so a mon that could mega is still refused
-- while the player has no Key Stone -- that is the whole clock.
T.eq(decide({ unlocked = {}, canDo = only("mega") }), nil,
  "an ace that could mega is still refused without the Key Stone")

-- --- eligibility -----------------------------------------------------------
T.eq(decide({ canDo = NONE }), nil, "an ace that can do nothing does nothing")
T.eq(decide({ canDo = only("zmove") }), "zmove", "only what it can actually do")

-- --- the tier --------------------------------------------------------------
T.check(decide({ hasAiClass = true, rng = scripted({ 4 }) }) ~= nil,
  "a trainer with an AI class never rolls")
T.eq(decide({ hasAiClass = false, rng = scripted({ 2 }) }), nil,
  "an ordinary trainer that loses its roll does nothing")
T.check(decide({ hasAiClass = false, rng = scripted({ 1 }) }) ~= nil,
  "and one that wins it does")
T.eq(AI.qualifies(false, nil), false, "no rng means an ordinary trainer is out")
T.eq(AI.qualifies(true, nil), true, "but an AI class still qualifies")

-- --- the seed: stable per trainer, varied across them ----------------------
-- The whole reason the pick is seeded rather than rolled. A hard fight that
-- does something different every attempt is arbitrary; one that always does
-- the same thing can be learned.
local first = decide({ trainerId = "OPP_BLAINE" })
for _ = 1, 20 do
  T.eq(decide({ trainerId = "OPP_BLAINE" }), first, "the same trainer, every time")
end
T.eq(AI.seedFor("OPP_BROCK"), AI.seedFor("OPP_BROCK"), "the seed is a function of the id")
T.check(AI.seedFor("OPP_BROCK") ~= AI.seedFor("OPP_BLAINE"), "and two ids differ")
T.eq(AI.seedFor(nil), 0, "no id seeds zero rather than raising")
T.eq(AI.seedFor(""), 0, "and neither does an empty one")

-- Across the real eighteen, with everything unlocked and every gimmick
-- possible, the roll must not land on one answer for everybody -- which is the
-- failure this design exists to avoid.
local ROSTER = { "OPP_BROCK", "OPP_MISTY", "OPP_LT_SURGE", "OPP_ERIKA",
                 "OPP_KOGA", "OPP_BLAINE", "OPP_SABRINA", "OPP_GIOVANNI",
                 "OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE",
                 "OPP_RIVAL2", "OPP_RIVAL3", "OPP_JUGGLER", "OPP_BLACKBELT",
                 "OPP_COOLTRAINER_M", "OPP_COOLTRAINER_F" }
local seen, distinct = {}, 0
for _, id in ipairs(ROSTER) do
  local pick = AI.choose({ "mega", "zmove", "dynamax", "tera" }, id)
  if not seen[pick] then seen[pick] = 0; distinct = distinct + 1 end
  seen[pick] = seen[pick] + 1
end
T.check(distinct >= 3, "the eighteen do not all reach for the same thing")
T.check((seen.mega or 0) < #ROSTER, "and specifically not all for mega")

-- --- the weights ----------------------------------------------------------
-- A weight of zero takes a gimmick out of the roll without removing its row.
local ZERO = { mega = 0, zmove = 1 }
for _, id in ipairs(ROSTER) do
  T.eq(AI.choose({ "mega", "zmove" }, id, ZERO), "zmove",
    "a zero weight is never chosen while something else is on offer")
end
T.eq(AI.choose({}, "OPP_BROCK"), nil, "no candidates, no choice")
T.eq(AI.choose(nil, "OPP_BROCK"), nil, "and no list at all")
-- Every weight zero must still answer something rather than nil: the ace IS
-- eligible for these, so refusing here would be a silent no-op.
T.eq(AI.choose({ "mega" }, "OPP_BROCK", { mega = 0 }), "mega",
  "an all-zero table still answers a candidate")

-- --- the override ---------------------------------------------------------
AI.OVERRIDE["OPP_LANCE"] = "mega"
T.eq(decide({ trainerId = "OPP_LANCE" }), "mega", "an override beats the roll")
-- but still has to clear the gate and the eligibility check: a forced gimmick
-- that cannot happen would mean announcing a transformation and doing nothing
T.eq(decide({ trainerId = "OPP_LANCE", unlocked = {} }), nil,
  "an override the player has not unlocked does not fire")
T.eq(decide({ trainerId = "OPP_LANCE", canDo = only("zmove") }), nil,
  "nor one the ace cannot do")
-- An override naming a gimmick with no GATE row at all is refused rather than
-- half-honoured -- the shape a typo would take.
AI.OVERRIDE["OPP_LANCE"] = "nosuchgimmick"
T.eq(decide({ trainerId = "OPP_LANCE",
              unlocked = { KEY_STONE = true, TERA_ORB = true } }), nil,
  "an override naming a gimmick with no gate does not fire")
AI.OVERRIDE["OPP_LANCE"] = nil

-- --- refusals answer a reason ---------------------------------------------
local pick, why = AI.decide({ party = {}, trainerId = "OPP_BROCK" })
T.eq(pick, nil, "an empty party decides nothing")
T.eq(type(why), "string", "and says which gate stopped it")
T.eq(AI.decide(nil), nil, "no context at all is refused rather than raising")

-- --- every gimmick is gated on its own item -------------------------------
-- Tera and Dynamax are commented out of GATE because their per-battle state is
-- single-slot: an enemy Terastallization after the player's overwrites
-- state.mon and silently unwinds theirs. Pinned so re-enabling them is a
-- deliberate act with this test to update, not an edit that slips through.
-- All four are wired now: the single-slot state that blocked three of them was
-- widened to one record per side, so an enemy activation can no longer
-- overwrite the player's.
T.eq(AI.GATE.mega, "KEY_STONE", "mega is gated on the Key Stone")
T.eq(AI.GATE.tera, "TERA_ORB", "tera on the Orb")
T.eq(AI.GATE.dynamax, "DYNAMAX_BAND", "dynamax on the Band")
T.eq(AI.GATE.zmove, "Z_RING", "and the Z-Move on the Ring")
T.check(decide({ unlocked = { TERA_ORB = true, DYNAMAX_BAND = true, Z_RING = true } })
  ~= nil, "so holding those three now offers something")
-- An item nothing is gated on still opens nothing.
T.eq(decide({ unlocked = { BICYCLE = true } }), nil,
  "an item no gimmick is gated on opens nothing")

-- --- ORDER is a field, and has to be ---------------------------------------
-- decide() reads M.ORDER above the line that defines it. A local would have
-- been an upvalue that does not exist yet; a field is resolved when it is
-- called. Same lesson wild_forms' swarmmap paid for with an invisible marker.
T.eq(type(AI.ORDER), "table", "the walk order is reachable as a field")
T.eq(#AI.ORDER, 4, "and names every gimmick, including the two not yet gated")

-- ==========================================================================
-- The application half.
-- ==========================================================================

-- species -> stone -> form, the real shape of data/megas.lua. Charizard has
-- two, which is the case that makes the stone meaningful and is exactly what
-- an enemy -- carrying no stone at all -- cannot use to choose.
local MEGAS = {
  CHARIZARD = { CHARIZARDITE_X = "CHARIZARD_MEGA_X",
                CHARIZARDITE_Y = "CHARIZARD_MEGA_Y" },
  GENGAR    = { GENGARITE = "GENGAR_MEGA" },
  ONIX      = { FAKEITE = "ONIX_MEGA_MISSING" },   -- form record absent below
}
local POKEMON = { CHARIZARD_MEGA_X = {}, CHARIZARD_MEGA_Y = {}, GENGAR_MEGA = {} }

T.eq(AI.megaFormFor(MEGAS, "GENGAR", POKEMON, "OPP_AGATHA"), "GENGAR_MEGA",
  "a species with one mega takes it")
T.eq(AI.megaFormFor(MEGAS, "MISSINGNO", POKEMON, "OPP_BROCK"), nil,
  "a species with no mega takes none")
T.eq(AI.megaFormFor(MEGAS, "ONIX", POKEMON, "OPP_BROCK"), nil,
  "a form the running game cannot resolve is skipped, not returned")
T.eq(AI.megaFormFor(nil, "GENGAR", POKEMON, "OPP_AGATHA"), nil, "no table, no form")

-- The two-mega case: stable per trainer, and not the same for everybody.
local x = AI.megaFormFor(MEGAS, "CHARIZARD", POKEMON, "OPP_BLAINE")
for _ = 1, 10 do
  T.eq(AI.megaFormFor(MEGAS, "CHARIZARD", POKEMON, "OPP_BLAINE"), x,
    "the same trainer's Charizard is always the same mega")
end
local picks = {}
for _, id in ipairs(ROSTER) do
  picks[AI.megaFormFor(MEGAS, "CHARIZARD", POKEMON, id)] = true
end
T.check(picks.CHARIZARD_MEGA_X and picks.CHARIZARD_MEGA_Y,
  "but across the roster both Charizard megas are reached")

-- --- the hook --------------------------------------------------------------
local becameForm, refuse
local forms = { becomeForm = function(_, mon, formId)
  if refuse then return false, "refused on purpose" end
  becameForm = { mon = mon, formId = formId }
  mon.species = formId
  return true
end }
local KEY = { ITEMS = { "KEY_STONE", "Z_RING" }, KEY_STONE = "KEY_STONE",
              held = function(_, item) return item == "KEY_STONE" end }

local function battleWith(over)
  local ace = { species = "GENGAR", level = 40 }
  local b = { kind = "trainer", trainer = { id = "OPP_AGATHA" },
              enemyParty = { { species = "RATTATA", level = 9 }, ace },
              enemy = { mon = ace }, data = { pokemon = POKEMON },
              rng = scripted({ 1 }) }
  for k, v in pairs(over or {}) do b[k] = v end
  return b, ace
end

AI.bind({ megas = MEGAS, battlerof = { mon = function(b) return b and b.mon end },
          keyitems = KEY, forms = forms, gen2 = false })

local state = AI.newState()
local b, ace = battleWith()
becameForm = nil
local pick = AI.onTurnStarted(state, { battle = b }, { hasAiClass = true })
T.eq(pick, "mega", "the gym leader's ace mega evolves")
T.eq(becameForm.formId, "GENGAR_MEGA", "into its own mega form")
T.eq(state.used, true, "and the trainer has now spent theirs")
T.eq(AI.onTurnStarted(state, { battle = b }, { hasAiClass = true }), nil,
  "a second turn does not do it again")

-- --- the option ------------------------------------------------------------
T.eq(AI.onTurnStarted(AI.newState(), { battle = battleWith() },
     { hasAiClass = true, enabled = false }), nil, "OFF means nothing happens")

-- --- it must be the ace on the field ---------------------------------------
local weak = { species = "GENGAR", level = 9 }
local bench = battleWith({ enemy = { mon = weak },
  enemyParty = { weak, { species = "GENGAR", level = 40 } } })
T.eq(AI.onTurnStarted(AI.newState(), { battle = bench }, { hasAiClass = true }), nil,
  "a non-ace on the field spends nothing")

-- --- a refusal does not spend the flag -------------------------------------
-- The same rule src/resolve.lua keeps for the player: nothing happened, so the
-- option survives.
refuse = true
local rstate = AI.newState()
T.eq(AI.onTurnStarted(rstate, { battle = battleWith() }, { hasAiClass = true }), nil,
  "a refused form change does nothing")
T.eq(rstate.used, false, "and specifically does not spend the once-per-battle flag")
refuse = false

-- --- the gate is the player's item -----------------------------------------
local locked = { ITEMS = { "KEY_STONE" }, KEY_STONE = "KEY_STONE",
                 held = function() return false end }
AI.bind({ megas = MEGAS, battlerof = { mon = function(b) return b and b.mon end },
          keyitems = locked, forms = forms, gen2 = false })
T.eq(AI.onTurnStarted(AI.newState(), { battle = battleWith() }, { hasAiClass = true }),
  nil, "no Key Stone in the player's bag, no enemy mega")
AI.bind({ megas = MEGAS, battlerof = { mon = function(b) return b and b.mon end },
          keyitems = KEY, forms = forms, gen2 = false })

-- --- a GOLD battle sets no `kind` at all -----------------------------------
-- Red's BattleState sets kind to "trainer"/"wild". Gold's Battle sets no such
-- field: every `kind` in that class is a damage kind or an action kind. The
-- first guard used to test `battle.kind ~= "trainer"` directly, which rejected
-- EVERY Gold battle before anything else ran -- the feature could not fire on
-- that game at all, and looked exactly like a trainer declining to.
local goldBattle = battleWith()
goldBattle.kind = nil
goldBattle.trainer = { class = "KAREN" }
T.eq(AI.onTurnStarted(AI.newState(), { battle = goldBattle }, { hasAiClass = true }),
  "mega", "a battle with no `kind` field still counts as a trainer battle")

-- --- wild battles and malformed input are refused, never raised ------------
-- A wild battle is told apart by having no trainer record, which is what both
-- games agree on -- not by `kind`, which only one of them has.
local wild = battleWith()
wild.kind, wild.trainer = nil, nil
T.eq(AI.onTurnStarted(AI.newState(), { battle = wild }, { hasAiClass = true }), nil,
  "a wild battle has no trainer record and does nothing")
T.eq(AI.onTurnStarted(AI.newState(), { battle = battleWith({ kind = "wild" }) },
     { hasAiClass = true }), nil, "and Red's explicit wild kind is refused too")
-- Built by hand rather than through battleWith: `trainer = nil` in an
-- override table is a key pairs() never visits, so the helper would have left
-- the default trainer in place and the assertion would have passed for the
-- wrong reason. It did, on the first run of this suite.
local noTrainer = battleWith()
noTrainer.trainer = nil
T.eq(AI.onTurnStarted(AI.newState(), { battle = noTrainer },
     { hasAiClass = true }), nil, "and neither does a battle with no trainer record")
T.eq(AI.onTurnStarted(AI.newState(), {}, {}), nil, "no battle, no crash")
T.eq(AI.onTurnStarted(nil, { battle = battleWith() }, {}), nil, "no state, no crash")

-- --- the announcement uses each game's OWN channel --------------------------
-- Red's announce.mega takes a BATTLER and queues through push; Gold's
-- announce.gen2Mega takes a MON and goes through Battle:emit. Calling only
-- Red's meant a Gold mega changed the sprite and printed nothing -- the
-- Pokemon transformed and simply attacked.
local said
local spy = {
  mega = function(_, battler) said = { fn = "mega", arg = battler } end,
  gen2Mega = function(_, mon) said = { fn = "gen2Mega", arg = mon } end,
}
local BASE = { megas = MEGAS, battlerof = { mon = function(b) return b and b.mon end },
               keyitems = KEY, forms = forms, announce = spy }

AI.bind(BASE)
said = nil
local g1b, g1ace = battleWith()
AI.onTurnStarted(AI.newState(), { battle = g1b }, { hasAiClass = true })
T.eq(said and said.fn, "mega", "on Red the battler-shaped announcement is used")
T.eq(said and said.arg, g1b.enemy, "and it is handed the enemy's BATTLER")

local gen2deps = {}
for k, v in pairs(BASE) do gen2deps[k] = v end
gen2deps.gen2 = true
gen2deps.gen2forms = forms
AI.bind(gen2deps)
said = nil
local g2b, g2ace = battleWith()
AI.onTurnStarted(AI.newState(), { battle = g2b }, { hasAiClass = true })
T.eq(said and said.fn, "gen2Mega", "on Gold the mon-shaped one is used instead")
T.eq(said and said.arg, g2ace, "and it is handed the MON, not the battler")

AI.bind({ megas = MEGAS, battlerof = { mon = function(b) return b and b.mon end },
          keyitems = KEY, forms = forms, gen2 = false })

-- --- BOTH games name the trainer differently -------------------------------
-- Red's BattleState stores the record under `id` (OPP_BROCK); Gold's
-- gen2/Battle stores the class under `classId`/`class`. Reading only `id` made
-- every Gold battle exit as "no trainer id" -- the feature did nothing on that
-- game at all, and said nothing about it.
local gold = battleWith()
gold.trainer = { class = "BLAINE" }
becameForm = nil
T.eq(AI.onTurnStarted(AI.newState(), { battle = gold }, { hasAiClass = true }),
  "mega", "a Gold trainer, whose id lives on `class`, still fires")
T.eq(becameForm.formId, "GENGAR_MEGA", "and applies the form")

local goldClassId = battleWith()
goldClassId.trainer = { classId = "MISTY" }
T.eq(AI.onTurnStarted(AI.newState(), { battle = goldClassId },
     { hasAiClass = true }), "mega", "and `classId` answers too")

-- The seed must key off whatever id the game gave, so a Gold trainer is as
-- stable as a Red one rather than all sharing the empty-string seed.
T.check(AI.seedFor("BLAINE") ~= AI.seedFor("MISTY"),
  "two Gold classes seed differently")

-- --- the arm state is NEVER touched ----------------------------------------
-- The failure this separates would be invisible: arm.lua holds ONE
-- once-per-battle flag for the battle rather than one per side, so an enemy
-- activation routed through it would spend the player's -- they arm their
-- mega, the gym leader moves first, and their cell is dead with nothing said.
local Arm = dofile(MOD .. "/src/arm.lua")
local armed = Arm.new()
AI.onTurnStarted(AI.newState(), { battle = battleWith() }, { hasAiClass = true })
T.eq(armed:usedAny(), false, "an enemy activation leaves the player's flag unspent")
T.eq(armed:armed(), nil, "and arms nothing on the player's side")

-- --- the Z-Crystal an enemy does not carry ---------------------------------
-- A Z-Move needs a crystal ON the Pokemon, and engine trainer parties hold no
-- mod items. Offering the Z-Move on the strength of the entry merely being
-- wired let the roll pick one that then refused -- the trainer lost its turn
-- and nothing was said. One is resolved from the ace's own best move instead.
local ZROWS = {
  { type = "NORMAL", crystal = "NORMALIUM_Z" },
  { type = "FIRE",   crystal = "FIRIUM_Z" },
  { type = "WATER",  crystal = "WATERIUM_Z" },
}
T.eq(AI.crystalFor(ZROWS, "FIRE"), "FIRIUM_Z", "a type resolves to its crystal")
T.eq(AI.crystalFor(ZROWS, "GHOST"), nil, "a type with no crystal resolves to none")
T.eq(AI.crystalFor(nil, "FIRE"), nil, "and no rows resolve to none")

local zdata = { moves = { EMBER = { power = 40, type = "FIRE" },
                          SURF = { power = 95, type = "WATER" },
                          GROWL = { power = 0, type = "NORMAL" } } }
T.eq(AI.crystalForMon(ZROWS, zdata, { moves = { "EMBER", "SURF" } }), "WATERIUM_Z",
  "the crystal follows the STRONGEST damaging move, not the first")
T.eq(AI.crystalForMon(ZROWS, zdata, { moves = { "GROWL" } }), nil,
  "a Pokemon with only status moves gets no crystal")
T.eq(AI.crystalForMon(ZROWS, zdata, { moves = {} }), nil, "and neither does one with none")

T.finish("battle_forms_trainerai")
