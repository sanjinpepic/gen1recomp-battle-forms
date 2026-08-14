-- Puts the stones and the orbs up for sale.
--
-- The Celadon department store's 4F clerk already sells the four vanilla
-- evolution stones (data/generated/text_pointers.lua's CeladonMart4F ->
-- TEXT_CELADONMART4F_CLERK.mart).  text_pointers is a "deep" registry
-- (Schemas.lua's R.text_pointers): under deep semantics a list value inside
-- a patch concatenates onto the base list instead of replacing it, so
-- patching in the mega stones here extends that shelf rather than
-- overwriting it -- the evolution stones stay buyable.  The Indigo Plateau
-- lobby clerk works the same way and keeps its own stock too.
--
-- map_scripts, the other registry that touches a map, cannot do this: its
-- "compose" semantics chains whole registrations one after another for
-- dispatch (talk handlers, onEnter, ...) and its schema carries no `mart`
-- field at all, because a mart's stock was never one of the things a
-- map_scripts entry describes in the first place.
local M = {}

-- `offered` is the subset of `indices` that may actually be sold; nil sells
-- everything indexed.  Stable shelf order (by assigned bag index) rather than
-- whatever pairs() happens to yield, so the mart menu does not reshuffle
-- between runs.
local function shelf(mod, map, clerk, indices, offered)
  local ids = {}
  for itemId in pairs(indices) do
    if not offered or offered[itemId] then ids[#ids + 1] = itemId end
  end
  table.sort(ids, function(a, b) return indices[a] < indices[b] end)

  mod.content.text_pointers:patch(map, { [clerk] = { mart = ids } })
end

-- `offered` is the set of stone ids the MEGA EVOLUTIONS option turned on.
-- The shelf is the one place that option may take a stone away: a stone that
-- is never sold is one the player simply never had, where a stone that is
-- never registered is a bag entry an existing save can no longer resolve.
function M.install(mod, indices, offered)
  shelf(mod, "CeladonMart4F", "TEXT_CELADONMART4F_CLERK", indices, offered)
end

-- The trainer key items sell on the mega stones' own floor, and ahead of them.
--
-- Same shelf because it is the only counter this mod already owns and because
-- a player buying their first stone should see the thing that makes it work in
-- the same list; not the Indigo Plateau counter, because that one is the last
-- room before the Elite Four and a mechanic gated behind it is a mechanic
-- gated behind the endgame.  Ahead of the stones because the shelf carries
-- ninety-odd of them and a Key Stone at the bottom of that is a Key Stone
-- nobody finds -- main.lua calls this before M.install, and a deep registry
-- concatenates patches in the order they arrive.
--
-- Every key item registered is a key item sold: no option gates one, so there
-- is no subset to offer.
function M.installKeyItems(mod, indices)
  shelf(mod, "CeladonMart4F", "TEXT_CELADONMART4F_CLERK", indices, nil)
end

-- The Z-Crystals sell on the same floor and immediately behind the key items,
-- which main.lua arranges by calling this between the two: a deep registry
-- concatenates patches in the order they arrive, so the shelf reads key items,
-- crystals, then the ninety-odd stones.  Ahead of the stones because a crystal
-- costs the same as one and does far less on its own -- a player who cannot
-- find the crystal for the Z-Ring they just bought has a mechanic that appears
-- not to exist.  Every crystal indexed is a crystal sold: no option gates one.
function M.installCrystals(mod, indices)
  shelf(mod, "CeladonMart4F", "TEXT_CELADONMART4F_CLERK", indices, nil)
end

-- The orbs sell at the Indigo Plateau lobby, the last counter before the
-- Elite Four, rather than on the mega stones' shelf.  They are a different
-- transformation type and Groudon and Kyogre are endgame Pokemon, so the two
-- families stay apart in the shop the way they do everywhere else.  Every orb
-- registered is an orb sold: no option gates a primal pairing, so there is no
-- subset to offer.
function M.installOrbs(mod, indices)
  shelf(mod, "IndigoPlateauLobby", "TEXT_INDIGOPLATEAULOBBY_CLERK", indices, nil)
end

return M
