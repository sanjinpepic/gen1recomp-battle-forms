-- Puts the stones up for sale.
--
-- The Celadon department store's 4F clerk already sells the four vanilla
-- evolution stones (data/generated/text_pointers.lua's CeladonMart4F ->
-- TEXT_CELADONMART4F_CLERK.mart).  text_pointers is a "deep" registry
-- (Schemas.lua's R.text_pointers): under deep semantics a list value inside
-- a patch concatenates onto the base list instead of replacing it, so
-- patching in the mega stones here extends that shelf rather than
-- overwriting it -- the evolution stones stay buyable.
--
-- map_scripts, the other registry that touches a map, cannot do this: its
-- "compose" semantics chains whole registrations one after another for
-- dispatch (talk handlers, onEnter, ...) and its schema carries no `mart`
-- field at all, because a mart's stock was never one of the things a
-- map_scripts entry describes in the first place.
local M = {}

function M.install(mod, indices)
  local stones = {}
  for stoneId in pairs(indices) do
    stones[#stones + 1] = stoneId
  end
  -- Stable shelf order (by assigned bag index) rather than whatever pairs()
  -- happens to yield, so the mart menu does not reshuffle between runs.
  table.sort(stones, function(a, b) return indices[a] < indices[b] end)

  mod.content.text_pointers:patch("CeladonMart4F", {
    TEXT_CELADONMART4F_CLERK = { mart = stones },
  })
end

return M
