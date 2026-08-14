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
  local names = { "src/eligibility.lua", "src/forms.lua", "src/stone.lua",
                  "src/shop.lua", "src/arm.lua", "src/resolve.lua", "src/anim.lua",
                  "src/overlay.lua", "src/menu.lua", "data/megas.lua", "data/stones.lua" }
  local m = {}
  for _, name in ipairs(names) do
    m[name] = loadSibling(mod, name)
    if not m[name] then return end
  end

  local megas = m["data/megas.lua"]
  local indices = m["data/stones.lua"]
  local eligibility = m["src/eligibility.lua"]
  local anim = m["src/anim.lua"]
  local state = m["src/arm.lua"].new()

  m["src/stone.lua"].bind(eligibility)
  m["src/stone.lua"].install(mod, megas, indices)
  m["src/shop.lua"].install(mod, indices)
  anim.install(mod)

  local resolve = m["src/resolve.lua"]
  resolve.bind({ forms = m["src/forms.lua"], eligibility = eligibility,
                 megas = megas, animId = anim.ID })

  -- Decision only: overlay says whether a mega is on offer and what to call
  -- it, and the menu cell is the one thing that draws it.  It owned a START
  -- handler and a corner indicator until 0.2.1; both are gone because the
  -- menu cell says the same thing in the place the player is already looking.
  local overlay = m["src/overlay.lua"]
  overlay.bind({ eligibility = eligibility, megas = megas })

  -- The menu cell owns input/draw seams overlay.lua has no hook for
  -- (BattleState.update, BattleState.drawTextArea, WideBattle.draw), which
  -- is why it is a separate module even though it reads the same shouldOffer
  -- decision.
  local menu = m["src/menu.lua"]
  menu.bind({ overlay = overlay })
  menu.install(mod, state)

  mod.events:on("battle.started", function(ev) state:onBattleStarted(ev) end)
  mod.events:on("battle.turn_started", function(ev) resolve.onTurnStarted(state, ev) end)
  mod.events:on("battle.fainted", function(ev) resolve.onFainted(ev) end)
  mod.events:on("battle.ended", function(ev)
    resolve.onBattleEnded(ev)
    state:onBattleEnded(ev)
  end)
end
