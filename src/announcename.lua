-- The name a Max / G-Max Move announces itself under.
--
-- WHAT THE ROW CAN HOLD.  The engine announces a move as the user's name, a
-- line break, then `used <move>!` (src/battle/gen2/Battle.lua). That second
-- line is NOT wrapped -- the engine's own comment beside it says so outright,
-- "It is not a wrap, and the panel must not be left to invent one" -- so
-- anything past the row's width is simply cut off. The row is eighteen
-- characters (src/announce.lua's own header: "no eighteen-character row holds
-- both halves"), `used ` costs five and the `!` one, which leaves exactly
-- TWELVE for the name. That is the same twelve-column budget data/
-- gmaxmoves.lua's own header already keeps the FIGHT menu inside, arrived at
-- from the other end.
--
-- WHAT WAS WRONG.  All twenty-six G-Max names are over it, and so are seven
-- of the eighteen ordinary Max Moves. "G-MAX WILDFIRE" is fourteen, so the row
-- printed `used G-MAX WILDFIR` -- and the half that says WHICH move it was is
-- the half that fell off the end. Every G-Max Move announced itself as the
-- same generic "G-MAX ...", which is exactly how it was reported: "dynamax
-- moves only show first part of the name when used".
--
-- WHICH HALF TO KEEP.  The tail. "G-MAX" and "MAX" are the parts every one of
-- these shares; the tail is the part that identifies one. So an over-budget
-- name announces as its short form -- `WILDFIRE`, not a clipped
-- `G-MAX WILDFIR` -- and that short form is the same `menu` string both
-- catalogs already trust for the FIGHT menu, so no second spelling is invented
-- anywhere.
--
-- WHAT IS LEFT ALONE.  A name that already fits is untouched: "G-MAX FINALE"
-- is twelve exactly and still announces in full. And a row whose `menu` is
-- missing, empty, or itself over budget keeps its full name and the clipping
-- it always had -- a wrong name is worse than a cut one, and this must never
-- be able to invent one.
local M = {}

-- Eighteen-character row, less `used ` and `!`.
M.BUDGET = 12

function M.fits(name)
  return type(name) == "string" and #name <= M.BUDGET
end

-- `row` is a catalog row carrying `name` and (usually) `menu`.
function M.of(row)
  if type(row) ~= "table" then return nil end
  local full = row.name
  if type(full) ~= "string" then return full end
  if #full <= M.BUDGET then return full end
  local short = row.menu
  if type(short) == "string" and short ~= "" and #short <= M.BUDGET then
    return short
  end
  return full
end

return M
