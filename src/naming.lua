-- A mega form's National Dex record carries the source data's slug as its
-- `name` (e.g. "charizard-mega-x"), because that field was never meant to
-- reach a player -- it is what build_national_dex.py's PokeAPI import calls
-- the species, not a display string.  In the real games a mega form keeps
-- the base species' own name in battle (Mega Charizard X is still
-- "CHARIZARD"), which is also the only name that fits: this engine's name
-- field is the Gen 1 HUD field, about ten characters wide, and "MEGA
-- CHARIZARD X" does not fit where "CHARIZARD" does.
--
-- Patched into the shared record at load rather than worked around per
-- reader, so every consumer of data.pokemon[formId].name -- the HUD cache in
-- BattleState.makeBattler and the post-battle experience/level-up text alike
-- -- sees the right string with no special-casing.  National Dex's own UI
-- was checked before this landed: its form browser distinguishes forms by
-- the record's `form`/`baseSpecies` fields and by record id, never by
-- `name`, so collapsing every mega's name onto its base species does not
-- make forms indistinguishable there.
local M = {}

function M.install(mod, megas)
  for baseId, byStone in pairs(megas) do
    local base = mod.content.pokemon:get(baseId)
    local baseName = base and base.name
    if not baseName then
      mod.log:error(
        "battle_forms: %s has no species record to name its mega forms after",
        tostring(baseId))
    else
      for _, formId in pairs(byStone) do
        mod.content.pokemon:patch(formId, { name = baseName })
      end
    end
  end
end

return M
