-- The spec's parity items that no other suite covers.  Turn order is the one
-- that matters most: a mega that does not change who moves first has not
-- really happened, and nothing else here would notice.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Forms = dofile(MOD .. "/src/forms.lua")
local Resolve = dofile(MOD .. "/src/resolve.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local megas = dofile(MOD .. "/data/megas.lua")

local DATA = { pokemon = {
  ALAKAZAM = { baseStats = { hp = 55, attack = 50, defense = 45,
                             speed = 120, special = 135 } },
  ["alakazam-mega"] = { baseStats = { hp = 55, attack = 50, defense = 65,
                                      speed = 150, special = 175 } },
} }

Resolve.bind({ forms = Forms, eligibility = E, megas = megas, animId = "TESTANIM" })

local function mon(stamped)
  return { species = "ALAKAZAM", level = 50,
           dvs = { hp = 15, attack = 15, defense = 15,
                   speed = 15, special = 15 }, statExp = {},
           [E.STAMP] = stamped and "ALAKAZITE" or nil }
end

-- Turn order must read the form's stats, not the base form's.  Compared
-- against each other rather than a magic number, because the real formula
-- puts both well above any threshold worth hardcoding.
local b = { mon = mon(true) }
Forms.becomeForm(DATA, b, "alakazam-mega")
local megaSpeed = b.mon.stats.speed
Forms.revertForm(b, DATA)
T.check(megaSpeed > b.mon.stats.speed,
  "the form's speed is higher, so turn order computed after the change differs")

-- Running from a battle still unwinds: RUN ends the battle, so it reaches the
-- same event.  This pins that it is not treated as a special case.
local runner = mon(true)
Forms.becomeForm(DATA, { mon = runner }, "alakazam-mega")
Resolve.onBattleEnded({
  battle = { data = DATA, game = { save = { party = { runner } } }, enemyParty = {} },
  result = "run",
})
T.eq(runner.species, "ALAKAZAM", "running from a battle reverts the form")

-- The stamp is a plain field on the mon, so it survives anything that moves
-- the mon by reference.  Boxing is a reference move in this engine.
local stamped = mon(true)
local party, box = { stamped }, {}
table.insert(box, table.remove(party, 1))
table.insert(party, table.remove(box, 1))
T.eq(party[1][E.STAMP], "ALAKAZITE", "the stamp survives a box deposit and withdraw")

-- And by value, which is what the save format does: a schema-less Lua-literal
-- writer that re-emits whatever keys it finds.
local copy = {}
for k, v in pairs(stamped) do copy[k] = v end
T.eq(E.formForMon(megas, copy), "alakazam-mega",
  "the stamp survives a by-value save round trip and stays eligible")

-- A mon that came back from a Game Boy .sav has no stamp, because a cart save
-- has nowhere to record one.  It must simply be ineligible, not error.
T.eq(E.formForMon(megas, mon(false)), nil,
  "a mon reimported without its stamp is ineligible, not broken")

-- The base-species marker must never outlive the battle: a mon left carrying
-- it would look transformed to a later battle's unwind.
local cleaned = mon(true)
Forms.becomeForm(DATA, { mon = cleaned }, "alakazam-mega")
Forms.revertMon(DATA, cleaned)
T.eq(cleaned[Forms.BASE], nil, "the base marker is cleared when the form unwinds")

T.finish("battle_forms_parity")
