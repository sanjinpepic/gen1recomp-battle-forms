-- Terastallization and Dynamax on the outward-facing API.
--
-- These two were deliberately absent from it: neither applies a form record
-- and neither writes a stat block, so neither reaches the two primitives that
-- fire form_applied, and announcing them as forms would have handed a consumer
-- a payload with nil `form`, nil `formId` and unchanged `stats` -- shaped
-- exactly like a bug in this mod.
--
-- So they get their own event names, and the payload grows four fields that
-- are additive: `api` stays 1, because a reader that ignores a new field
-- cannot be broken by it (src/formapi.lua's own rule for its version).
--
-- The split that matters is PERSISTENT versus LIVE.  teraType and
-- dynamaxLevel are properties of the Pokemon and answerable from a party
-- screen with no battle anywhere; `tera` and `dynamax` are the live records
-- and are nil unless something is standing right now.  A consumer drawing a
-- stats row wants the first pair; one drawing a battle HUD wants the second.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Api = dofile(MOD .. "/src/formapi.lua")
local TeraType = dofile(MOD .. "/src/teratype.lua")
local Level = dofile(MOD .. "/src/dynamaxlevel.lua")
local Stellar = dofile(MOD .. "/src/stellar.lua")

local data = {
  type_chart = { types = { FIRE = { name = "FIRE" }, FLYING = { name = "FLYING" },
                           WATER = { name = "WATER" } } },
  pokemon = { CHARIZARD = { types = { "FIRE", "FLYING" } } },
}

-- A recording events table shaped like mod.events.
local heard
local events = { emit = function(_, name, body)
  heard[#heard + 1] = { name = name, body = body }
end }

local teraState = { mon = nil, type = nil }
local dynamaxState = { mon = nil, turns = 0, form = nil }

Api.bind({ events = events, gen2 = false, teratype = TeraType,
           dynamaxlevel = Level, stellar = Stellar,
           teraState = teraState, dynamaxState = dynamaxState })

local function mon()
  return { species = "CHARIZARD", nickname = "ZARD",
           dvs = { attack = 9, defense = 4, speed = 15, special = 2 },
           stats = { hp = 78, attack = 84 } }
end

-- --- the names are their own, and are handed out ------------------------
T.eq(Api.TERA_APPLIED, "mod.battle_forms.tera_applied",
  "Terastallization has its own event name")
T.eq(Api.DYNAMAX_APPLIED, "mod.battle_forms.dynamax_applied",
  "and so does Dynamax")
for _, name in ipairs({ Api.TERA_APPLIED, Api.TERA_REVERTED,
                        Api.DYNAMAX_APPLIED, Api.DYNAMAX_REVERTED }) do
  T.check(name:find("^mod%.battle_forms%.") ~= nil,
    name .. " carries the prefix the loader refuses an emit without")
end
T.eq(Api.API, 1,
  "the payload version stays 1 -- these are added fields, and a reader that "
    .. "ignores them cannot be broken by them")

-- The exports hand out every name, so a consumer subscribes to a value it was
-- given rather than a string it retyped.
local exports = {}
Api.install({ exports = exports })
T.eq(exports.events.teraApplied, Api.TERA_APPLIED, "the exports name tera")
T.eq(exports.events.dynamaxApplied, Api.DYNAMAX_APPLIED, "and dynamax")
T.eq(exports.events.applied, Api.APPLIED, "and still the form events")

-- --- the persistent half answers with no battle at all -------------------
local subject = mon()
Level.set(subject, 7)
local payload = Api.describe(subject)
T.check(payload ~= nil, "describe answers for a Pokemon out of battle")
T.eq(payload.dynamaxLevel, 7, "and reports its Dynamax Level")
T.eq(payload.tera, nil, "with no live Terastallization")
T.eq(payload.dynamax, nil, "and no live Dynamax")
-- teraType needs the dataset, which describe() has not been handed yet: the
-- honest answer is nil rather than a guess.
T.eq(payload.teraType, nil,
  "and no Tera type until this mod has been handed a dataset")

-- Once any path has supplied one, the remembered dataset answers it.
Api.tera(true, { mon = subject, data = data })
local afterData = Api.describe(subject)
T.check(afterData.teraType == "FIRE" or afterData.teraType == "FLYING",
  "once a dataset has been seen, the persistent Tera type is answerable")
T.eq(afterData.dynamaxLevel, 7, "and the level still is")

-- An unfed Pokemon is level 0, which is a real answer and not "unknown".
T.eq(Api.describe(mon()).dynamaxLevel, 0, "an unfed Pokemon reads level 0")

-- --- tera_applied carries the live record --------------------------------
heard = {}
local zard = mon()
teraState.mon, teraState.type = zard, "WATER"
Api.tera(true, { mon = zard, data = data })
T.eq(#heard, 1, "one event fired")
T.eq(heard[1].name, Api.TERA_APPLIED, "under the tera name")
local p = heard[1].body
T.eq(p.event, "tera_applied", "the payload names the event")
T.eq(p.mon, zard, "and carries the live Pokemon")
T.eq(p.form, nil, "with no form, because a Terastallization applies none")
T.eq(p.formId, nil, "and no form record")
T.check(p.tera ~= nil, "the live tera record is present")
T.eq(p.tera.type, "WATER", "naming the type it is terastallized into")
T.eq(p.tera.stellar, false, "and saying it is not Stellar")

-- Stellar is broken out rather than left as a string compare, because it is
-- the one Tera type that changes no typing at all.
teraState.type = Stellar.TYPE
local sp = Api.describe(zard)
T.eq(sp.tera.stellar, true, "a Stellar Terastallization says so")
T.eq(sp.tera.type, Stellar.TYPE, "and still names the type")

-- --- tera_reverted describes the world AFTER the revert ------------------
heard = {}
teraState.mon, teraState.type = nil, nil
Api.tera(false, { mon = zard })
T.eq(heard[1].name, Api.TERA_REVERTED, "the revert fires under its own name")
T.eq(heard[1].body.tera, nil,
  "and the live record is already gone -- a revert that still claimed a "
    .. "Terastallization would describe the instant before itself")

-- --- dynamax carries its clock, and tells a Gigantamax apart -------------
heard = {}
local dyna = mon()
dynamaxState.mon, dynamaxState.turns, dynamaxState.form = dyna, 3, nil
Api.dynamax(true, { mon = dyna, data = data })
T.eq(heard[1].name, Api.DYNAMAX_APPLIED, "dynamax fires under its own name")
T.eq(heard[1].body.dynamax.turns, 3, "carrying the turns left on the clock")
T.eq(heard[1].body.dynamax.form, nil,
  "and no form, which is what makes it a PLAIN Dynamax")

heard = {}
dynamaxState.form = "GMAX"
Api.dynamax(true, { mon = dyna, data = data })
T.eq(heard[1].body.dynamax.form, "GMAX",
  "a Gigantamax carries its form here too -- and fires form_applied "
    .. "separately, because two things really did happen")

heard = {}
dynamaxState.mon, dynamaxState.turns, dynamaxState.form = nil, 0, nil
Api.dynamax(false, { mon = dyna })
T.eq(heard[1].name, Api.DYNAMAX_REVERTED, "the revert fires under its own name")
T.eq(heard[1].body.dynamax, nil, "with the live record already gone")

-- --- one Pokemon's state is not another's --------------------------------
teraState.mon, teraState.type = zard, "WATER"
T.eq(Api.describe(mon()).tera, nil,
  "a different Pokemon reports no Terastallization of its own")
T.check(Api.describe(zard).tera ~= nil, "while the one that did still does")

-- --- unbound is silent, never fatal --------------------------------------
-- src/formapi.lua is dofile()d bare by several suites, and a payload that
-- threw inside a transformation would take the transformation with it.
local Bare = dofile(MOD .. "/src/formapi.lua")
T.eq(Bare.tera(true, { mon = mon() }), false, "an unbound tera emit answers false")
T.eq(Bare.dynamax(true, { mon = mon() }), false, "and so does dynamax")
local bareState = Bare.describe(mon())
T.check(bareState ~= nil, "and describe still answers")
T.eq(bareState.teraType, nil, "with nils rather than an error")
T.eq(bareState.dynamaxLevel, nil, "for both persistent fields")

T.eq(Api.tera(true, { mon = nil }), false, "no Pokemon, no event")
T.eq(Api.dynamax(false, {}), false, "on either channel")

-- --- the API answers for the ENEMY too --------------------------------------
-- describe() takes a Pokemon, not a side, so a peer asking about the opposing
-- Terastallization must get an answer as readily as about the player's. It did
-- not: this module was bound with the player's single state, under a comment
-- saying "only the player's own side can transform here, so there is never a
-- second Terastallization or Dynamax to tell this one apart from". Enemy
-- trainers transform now, so there is.
local mine, theirs = { species = "CHARIZARD" }, { species = "GENGAR" }
local playerTera = { mon = mine, type = "WATER" }
local enemyTera = { mon = theirs, type = "DRAGON" }
local playerDyna = { mon = nil }
local enemyDyna = { mon = theirs, turns = 3, form = "GENGAR_GMAX" }

Api.bind({ teraState = { playerTera, enemyTera },
           dynamaxState = { playerDyna, enemyDyna },
           stellar = Stellar })

T.eq(Api.describe(mine).tera.type, "WATER", "the player's Terastallization is reported")
T.eq(Api.describe(theirs).tera.type, "DRAGON",
  "and the ENEMY'S is reported too, with its own type")
T.eq(Api.describe(theirs).dynamax.form, "GENGAR_GMAX",
  "the enemy's Gigantamax form comes back as well")
T.eq(Api.describe(mine).dynamax, nil, "and a side with none reports none")
T.eq(Api.describe({ species = "PIDGEY" }).tera, nil,
  "a Pokemon in neither state reports neither")

-- A single state still works, since this module is dofile'd bare by its own
-- suite and handed one.
Api.bind({ teraState = playerTera, stellar = Stellar })
T.eq(Api.describe(mine).tera.type, "WATER", "one state, not a list, still resolves")
T.eq(Api.describe(theirs).tera, nil, "and does not answer for a mon it never claimed")

T.finish("battle_forms_formapi_gimmicks")
