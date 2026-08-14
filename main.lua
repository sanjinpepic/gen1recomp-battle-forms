-- Mid-battle form changes.  A form change marks the mon (mon.form) and
-- overrides the active battler's curStats/curTypes, the same shape the
-- engine's own Transform uses -- mon.species is never touched.  Mega
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
  -- OFFICIAL is the 48 mega evolutions the mainline games shipped; ALL adds
  -- the 48 more the National Dex data carries that never did.  It gates what
  -- the shelf sells and what a stone is allowed to do -- never which stones
  -- exist, see src/megaset.lua.
  mod.options:define({
    { key = "megas", label = "MEGA EVOLUTIONS", type = "choice",
      default = "official", choices = { { "OFFICIAL", "official" },
                                        { "ALL", "all" } } },
  })

  local names = { "src/eligibility.lua", "src/forms.lua", "src/megaset.lua",
                  "src/stone.lua", "src/shop.lua", "src/arm.lua",
                  "src/resolve.lua", "src/primal.lua", "src/anim.lua",
                  "src/overlay.lua", "src/menu.lua", "data/megas.lua",
                  "data/stones.lua", "data/primals.lua", "data/orbs.lua" }
  local m = {}
  for _, name in ipairs(names) do
    m[name] = loadSibling(mod, name)
    if not m[name] then return end
  end

  local megaset = m["src/megaset.lua"]
  local rawMegas = m["data/megas.lua"]
  local indices = m["data/stones.lua"]
  local eligibility = m["src/eligibility.lua"]
  local anim = m["src/anim.lua"]
  local state = m["src/arm.lua"].new()

  for _, pair in ipairs(megaset.problems(rawMegas)) do
    mod.log:error("data/megas.lua: %s carries no officialness marker -- wrap "
      .. "its form id in official() or extended(); until then it is in "
      .. "neither set and its stone does nothing", pair)
  end

  -- Two tables from one source: every pair for registration, the chosen set
  -- for everything that decides whether a mega may happen.
  local allMegas = megaset.select(rawMegas, megaset.ALL)
  local megas = megaset.select(rawMegas, mod.options:get("megas"))

  -- Primal reversion's pairings are never selected between, so the table the
  -- orbs are registered from and the table their effects read are the same
  -- one -- where the mega stones need the full set for the first and the
  -- chosen set for the second.
  local primals = m["data/primals.lua"]
  local orbIndices = m["data/orbs.lua"]

  m["src/stone.lua"].bind(eligibility)
  m["src/stone.lua"].install(mod, allMegas, megas, indices)
  m["src/stone.lua"].install(mod, primals, primals, orbIndices)
  m["src/shop.lua"].install(mod, indices, megaset.stoneIds(megas))
  m["src/shop.lua"].installOrbs(mod, orbIndices)
  anim.install(mod)

  local resolve = m["src/resolve.lua"]
  resolve.bind({ forms = m["src/forms.lua"], eligibility = eligibility,
                 megas = megas, animId = anim.ID, log = mod.log })

  -- Primal reversion is wired beside the mega path, never into it: it is
  -- handed the forms primitive and its own pairing table and nothing else,
  -- so it has no way to reach the armed flag or the once-per-battle limit.
  local primal = m["src/primal.lua"]
  primal.bind({ forms = m["src/forms.lua"], eligibility = eligibility,
                primals = primals, log = mod.log })

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

  mod.events:on("battle.started", function(ev)
    state:onBattleStarted(ev)
    primal.onBattleStarted(ev)
  end)
  mod.events:on("battle.turn_started", function(ev) resolve.onTurnStarted(state, ev) end)
  mod.events:on("battle.battler_switched", function(ev)
    resolve.onBattlerSwitched(ev)
    primal.onBattlerSwitched(ev)
  end)
  mod.events:on("battle.fainted", function(ev) resolve.onFainted(ev) end)
  mod.events:on("battle.ended", function(ev)
    resolve.onBattleEnded(ev)
    state:onBattleEnded(ev)
  end)
end
