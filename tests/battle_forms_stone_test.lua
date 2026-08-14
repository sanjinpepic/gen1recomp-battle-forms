package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Stone = dofile(MOD .. "/src/stone.lua")
local E = dofile(MOD .. "/src/eligibility.lua")
local megas = dofile(MOD .. "/data/megas.lua")

Stone.bind(E)

local DATA = { pokemon = { CHARIZARD = { name = "CHARIZARD" },
                           PIDGEY = { name = "PIDGEY" } } }

local use = Stone.effectFor(megas, "CHARIZARDITE_X")

local mon = { species = "CHARIZARD" }
local outcome = use({ data = DATA, target = mon })
T.eq(outcome, "kept", "the stone is not consumed -- it stays with the mon")
T.eq(E.stoneOf(mon), "CHARIZARDITE_X", "using the stone stamps the mon")

local wrong = { species = "PIDGEY" }
T.eq(use({ data = DATA, target = wrong }), "failed",
  "a stone refuses a species it has no form for")
T.eq(E.stoneOf(wrong), nil, "a refused use stamps nothing")

T.eq(use({ data = DATA, target = nil }), "failed", "no target fails cleanly")

T.check(Stone.items(megas)["CHARIZARDITE_X"] ~= nil,
  "every stone in the table becomes an item")

-- Charizard has two stones and they must not collapse into one item.
local items = Stone.items(megas)
T.check(items["CHARIZARDITE_Y"] ~= nil, "the second Charizard stone is its own item")

-- Re-stamping with a different stone replaces rather than accumulates.
local swap = { species = "CHARIZARD" }
use({ data = DATA, target = swap })
Stone.effectFor(megas, "CHARIZARDITE_Y")({ data = DATA, target = swap })
T.eq(E.stoneOf(swap), "CHARIZARDITE_Y", "a second stone replaces the first")

T.finish("battle_forms_stone")
