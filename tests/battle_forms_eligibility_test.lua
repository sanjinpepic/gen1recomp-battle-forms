package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local megas = dofile(MOD .. "/data/megas.lua")
local E = dofile(MOD .. "/src/eligibility.lua")

T.eq(E.formFor(megas, "CHARIZARD", "CHARIZARDITE_X"), "charizard-mega-x",
  "species plus stone resolves to the matching form")
T.eq(E.formFor(megas, "CHARIZARD", "CHARIZARDITE_Y"), "charizard-mega-y",
  "the same species with a different stone resolves elsewhere")
T.eq(E.formFor(megas, "CHARIZARD", nil), nil,
  "no stone is not eligible")
T.eq(E.formFor(megas, "PIDGEY", "CHARIZARDITE_X"), nil,
  "a stone on the wrong species is not eligible")

T.eq(E.stoneOf({ species = "CHARIZARD" }), nil,
  "an unstamped mon carries no stone")
T.eq(E.stoneOf({ species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_X" }),
  "CHARIZARDITE_X", "a stamped mon reports its stone")

T.eq(E.formForMon(megas, { species = "CHARIZARD", [E.STAMP] = "CHARIZARDITE_Y" }),
  "charizard-mega-y", "mon eligibility combines both halves")
T.eq(E.formForMon(megas, nil), nil, "a nil mon is not eligible")

T.finish("battle_forms_eligibility")
