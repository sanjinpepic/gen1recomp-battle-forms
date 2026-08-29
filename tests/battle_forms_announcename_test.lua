-- A Max / G-Max Move announces under a name the battle text row can hold.
--
-- The row is eighteen characters and the engine does NOT wrap it (its own
-- comment beside the string says so), so `used ` plus `!` leaves twelve for
-- the name. Every one of the 26 G-Max names and 7 of the 18 ordinary Max Move
-- names are over that, so the row printed `used G-MAX WILDFIR` and the half
-- that identifies the move fell off the end.
--
-- Checked against the REAL catalogs, not fixtures: the point is that every
-- shipped row can announce itself, and a fixture cannot promise that.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local A = dofile(MOD .. "/src/announcename.lua")
local gmax = dofile(MOD .. "/data/gmaxmoves.lua")
local maxdata = dofile(MOD .. "/data/maxmoves.lua")

T.eq(A.BUDGET, 12, "the row leaves twelve characters for a move name")

-- The reported case.
T.eq(A.of({ name = "G-MAX WILDFIRE", menu = "WILDFIRE" }), "WILDFIRE",
  "G-MAX WILDFIRE announces as WILDFIRE rather than being cut mid-word")

-- A name that fits is untouched -- twelve exactly is still twelve.
T.eq(A.of({ name = "G-MAX FINALE", menu = "G-MAX FINALE" }), "G-MAX FINALE",
  "a name that already fits is left alone")
T.eq(A.of({ name = "MAX FLARE", menu = "FLARE" }), "MAX FLARE",
  "and a short one keeps its MAX prefix")

-- Never invent a name. A missing, empty or over-budget short form keeps the
-- full name and the clipping it always had.
T.eq(A.of({ name = "G-MAX SOMETHINGLONG" }), "G-MAX SOMETHINGLONG",
  "no menu form means the full name, cut as before")
T.eq(A.of({ name = "G-MAX SOMETHINGLONG", menu = "" }), "G-MAX SOMETHINGLONG",
  "an empty menu form is not a name")
T.eq(A.of({ name = "G-MAX SOMETHINGLONG", menu = "STILLFARTOOLONG" }),
  "G-MAX SOMETHINGLONG", "a menu form that is itself over budget is refused")

-- Shape guards.
T.check(A.of(nil) == nil, "nil row answers nil")
T.eq(A.of({ name = 5 }), 5, "a non-string name is handed back untouched")

-- EVERY SHIPPED ROW, both catalogs: whatever it announces under must fit.
local checked, rescued = 0, 0
local function sweep(rows, label)
  for _, row in ipairs(rows or {}) do
    if type(row.name) == "string" then
      checked = checked + 1
      local announced = A.of(row)
      if announced ~= row.name then rescued = rescued + 1 end
      -- The one exception this cannot fix is a row with no usable short form,
      -- and neither catalog has one -- which is what makes the flat assertion
      -- below honest rather than lucky.
      T.check(#announced <= A.BUDGET, string.format(
        "%s: %s announces as %s (%d chars), which the row can hold",
        label, row.name, announced, #announced))
    end
  end
end
sweep(gmax, "gmax")
sweep(maxdata.types, "max")

T.check(checked > 40, checked .. " shipped rows were checked")
T.check(rescued > 25, rescued .. " of them needed the short form (expected 26 G-Max + 7 Max)")

T.finish("battle_forms_announcename")
