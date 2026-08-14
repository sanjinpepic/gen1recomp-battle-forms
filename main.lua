-- Mid-battle form changes.  A form change is a species re-key: the battler's
-- species id becomes an alternate-form id, its stats are recomputed from that
-- form's record, and the original is remembered for the unwind.  Mega
-- evolution is one trigger on that primitive; Primal Reversion and stance
-- changes are the same shape and are why the primitive is not called "mega".
--
-- Nothing here runs inside performMove.  That is the whole point: a mega that
-- resolves outside the move path cannot spend PP, cannot be Disabled and
-- cannot be copied by Metronome, because it was never a move.

-- A mod's own files are not on package.path, so siblings are read and
-- compiled rather than required.  A sibling that fails returns nil and the
-- load carries on -- an assert inside a mod callback takes the whole load
-- down, and a player is better served by a degraded mod than by none.
local function loadSibling(mod, name)
  local source = mod:read(name)
  if not source then
    mod.log:error("%s is missing -- reinstall the mod zip", name)
    return nil
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. name)
  if not chunk then
    mod.log:error("%s failed to compile (%s) -- reinstall the mod zip",
      name, tostring(err))
    return nil
  end
  local ok, result = pcall(chunk)
  if not ok then
    mod.log:error("%s errored while loading (%s)", name, tostring(result))
    return nil
  end
  return result
end

return function(mod)
  local eligibility = loadSibling(mod, "src/eligibility.lua")
  local stone = loadSibling(mod, "src/stone.lua")
  local megas = loadSibling(mod, "data/megas.lua")
  if not (eligibility and stone and megas) then return end

  stone.bind(eligibility)
  stone.install(mod, megas)

  mod.battleForms = { eligibility = eligibility, megas = megas }
end
