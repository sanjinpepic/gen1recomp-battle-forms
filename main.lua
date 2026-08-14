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

-- The type a Terastallization turns a Pokemon into, as the rows the manager
-- draws for it.  The list lives here rather than in src/tera.lua because the
-- options are declared before any sibling is read, so that they reach the
-- settings screen even on a load where a sibling could not be: an option
-- defined out of a file that failed to load is an option a player cannot see.
--
-- Red's fifteen come first and DARK, STEEL and FAIRY last, because those three
-- exist only once National Dex has registered a chart over the top of the
-- cart's own -- and the manager's choice row steps rather than wraps, so the
-- three that may not resolve sit at the far end of it rather than in the middle
-- of it.  Only PSYCHIC differs between what is stored and what is shown: the
-- engine's id for it is PSYCHIC_TYPE.
local TERA_CHOICES = {
  { "NORMAL", "NORMAL" }, { "FIGHTING", "FIGHTING" }, { "FLYING", "FLYING" },
  { "POISON", "POISON" }, { "GROUND", "GROUND" }, { "ROCK", "ROCK" },
  { "BUG", "BUG" }, { "GHOST", "GHOST" }, { "FIRE", "FIRE" },
  { "WATER", "WATER" }, { "GRASS", "GRASS" }, { "ELECTRIC", "ELECTRIC" },
  { "PSYCHIC", "PSYCHIC_TYPE" }, { "ICE", "ICE" }, { "DRAGON", "DRAGON" },
  { "DARK", "DARK" }, { "STEEL", "STEEL" }, { "FAIRY", "FAIRY" },
}

return function(mod)
  -- OFFICIAL is the 48 mega evolutions the mainline games shipped; ALL adds
  -- the 48 more the National Dex data carries that never did.  It gates what
  -- the shelf sells and what a stone is allowed to do -- never which stones
  -- exist, see src/megaset.lua.
  mod.options:define({
    { key = "megas", label = "MEGA EVOLUTIONS", type = "choice",
      default = "official", choices = { { "OFFICIAL", "official" },
                                        { "ALL", "all" } } },
    -- Which type a Terastallization changes the Pokemon into.  It is an option
    -- rather than something carried on the Pokemon because there is nowhere on
    -- a Gen 1 Pokemon a player could set one -- see src/tera.lua -- and NORMAL
    -- rather than the mon's own type because terastallizing into the type you
    -- already are is a mechanic that does nothing at all.
    { key = "tera_type", label = "TERA TYPE", type = "choice",
      default = "NORMAL", choices = TERA_CHOICES },
    -- diagnostic: records why the menu cell and primal reversion did or did
    -- not happen, into mod storage (src/diag.lua).  Off unless a bug is being
    -- chased -- it answers questions a player never has.
    { key = "debug_trace", label = "DEBUG TRACE", type = "choice",
      default = "off",
      choices = { { "OFF", "off" }, { "ON", "on" } } },
  })

  local names = { "src/eligibility.lua", "src/forms.lua", "src/megaset.lua",
                  "src/stone.lua", "src/keyitems.lua", "src/shop.lua",
                  "src/arm.lua",
                  "src/transforms.lua", "src/mega.lua", "src/dynamax.lua",
                  "src/tera.lua", "src/resolve.lua",
                  "src/primal.lua", "src/conditional.lua", "src/diag.lua",
                  "src/anim.lua", "src/announce.lua", "src/adopt.lua",
                  "src/overlay.lua", "src/menu.lua",
                  "data/megas.lua", "data/stones.lua", "data/primals.lua",
                  "data/orbs.lua", "data/keyitems.lua", "data/conditional.lua",
                  "data/gigantamax.lua" }
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
  local diag = m["src/diag.lua"]

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

  -- The other tier of item: worn by the trainer rather than stamped on a mon,
  -- and what decides whether a mechanic is on offer at all.  Registered before
  -- either shelf is stocked and unconditionally, because an item a save carries
  -- has to stay nameable no matter what any gate later says about it.
  local keyitems = m["src/keyitems.lua"]
  local keyIndices = m["data/keyitems.lua"]
  keyitems.install(mod, keyIndices)

  m["src/stone.lua"].bind(eligibility)
  m["src/stone.lua"].install(mod, allMegas, megas, indices)
  m["src/stone.lua"].install(mod, primals, primals, orbIndices)
  -- Before the stones, so the two items that make that shelf worth anything
  -- are at the top of it rather than under ninety-odd stones.
  m["src/shop.lua"].installKeyItems(mod, keyIndices)
  m["src/shop.lua"].install(mod, indices, megaset.stoneIds(megas))
  m["src/shop.lua"].installOrbs(mod, orbIndices)
  anim.install(mod)

  -- The battle message a form change prints.  Handed to the two
  -- transformations that announce and to nothing else, so the eight
  -- condition-driven forms cannot start narrating themselves by accident --
  -- see src/announce.lua for why they stay quiet.
  local announce = m["src/announce.lua"]

  -- One cell on the command menu hosts every manually activated
  -- transformation there is, because the blank spacer row it draws into is the
  -- only space either battle layout has spare.  Mega evolution is the first
  -- entry rather than a special case: what makes it the only one today is that
  -- it is the only one registered.
  local registry = m["src/transforms.lua"].new()
  local registered, why = registry:register(m["src/mega.lua"].entry({
    forms = m["src/forms.lua"], eligibility = eligibility, megas = megas,
    keyitems = keyitems, animId = anim.ID, announce = announce,
    log = mod.log }))
  if not registered then
    mod.log:error("battle_forms: mega evolution was refused a place on the "
      .. "battle menu (%s) -- no stone can be armed until that is fixed",
      tostring(why))
  end

  -- The second entry on that cell, and the one that proves it is a cell rather
  -- than a mega with decoration: registered through the same registry and
  -- cycled to with LEFT/RIGHT.  Being registered is also what puts it under the
  -- trainer's one manual transformation per battle, so a player picks this or
  -- the mega and not both.  Dynamax is still handed the forms primitive and its
  -- own pairing table and nothing else, so like primal reversion it has no way
  -- to reach the mega's eligibility.
  local dynamax = m["src/dynamax.lua"]
  dynamax.bind({ forms = m["src/forms.lua"],
                 gigantamax = m["data/gigantamax.lua"], keyitems = keyitems,
                 announce = announce, log = mod.log })
  local dynamaxState = dynamax.new()
  local dynaOk, dynaWhy = registry:register(dynamax.entry(dynamaxState))
  if not dynaOk then
    mod.log:error("battle_forms: Dynamax was refused a place on the battle "
      .. "menu (%s) -- the cell falls back to mega evolution alone",
      tostring(dynaWhy))
  end

  -- The third entry, and the first that is not a form change at all: it
  -- overrides the battler's types and marks nothing, so it is handed neither
  -- the forms primitive nor a pairing table.  The chosen type is passed as a
  -- reader rather than a value for the reason the diagnostic's switch is:
  -- changing an option in the manager does not reload the mod, so a value
  -- captured here would only take effect on the next boot.
  local tera = m["src/tera.lua"]
  tera.bind({ keyitems = keyitems, announce = announce, log = mod.log,
              chosen = function() return mod.options:get("tera_type") end })
  local teraState = tera.new()
  local teraOk, teraWhy = registry:register(tera.entry(teraState))
  if not teraOk then
    mod.log:error("battle_forms: Terastallization was refused a place on the "
      .. "battle menu (%s) -- the cell keeps the transformations that did "
      .. "register", tostring(teraWhy))
  end

  diag.registry(registry, registered, why)

  local resolve = m["src/resolve.lua"]
  resolve.bind({ registry = registry, forms = m["src/forms.lua"],
                 eligibility = eligibility, megas = megas, log = mod.log })

  -- Primal reversion is wired beside the mega path, never into it: it is
  -- handed the forms primitive and its own pairing table and nothing else,
  -- so it has no way to reach the armed flag or the once-per-battle limit.
  local primal = m["src/primal.lua"]
  primal.bind({ forms = m["src/forms.lua"], eligibility = eligibility,
                primals = primals, log = mod.log, diag = diag,
                announce = announce })

  -- Condition-driven forms are wired the same way and for the same reason:
  -- the forms primitive, their own pairing table, and nothing else.  They
  -- carry no item, so they are not handed eligibility either -- there is no
  -- stamp for them to read.
  local conditional = m["src/conditional.lua"]
  conditional.bind({ forms = m["src/forms.lua"],
                     rows = m["data/conditional.lua"], log = mod.log })

  -- Decision only: overlay says which registered transformations are on offer
  -- and what the cell should call the one it is showing, and the menu cell is
  -- the one thing that draws it.  It owned a START handler and a corner
  -- indicator until 0.2.1; both are gone because the menu cell says the same
  -- thing in the place the player is already looking.
  local overlay = m["src/overlay.lua"]
  overlay.bind({ registry = registry })

  -- Bound after everything it reads and before anything that reports through
  -- it.  The option is read live rather than captured: changing it in the
  -- manager does not reload the mod (ManagerState:setOption writes
  -- loader.modOptions in place), so a captured value would mean the switch
  -- only ever took effect on the next boot.
  diag.bind({ mod = mod, registry = registry, overlay = overlay, state = state,
              eligibility = eligibility, megas = megas, keyitems = keyitems,
              enabled = function()
                return mod.options:get("debug_trace") == "on"
              end })

  -- Enabling the mod from the manager during a battle means battle.started has
  -- already been and gone, so the arm state below would never learn which
  -- battle it is in and nothing manual would work for the rest of the fight.
  -- Adoption is handed the two send-out handlers rather than the events,
  -- because what it recovers is exactly what a send-out would have applied.
  local adopt = m["src/adopt.lua"]
  adopt.bind({ state = state, primal = primal, conditional = conditional,
               diag = diag })

  -- The menu cell owns input/draw seams overlay.lua has no hook for
  -- (BattleState.update, BattleState.drawTextArea, WideBattle.draw), which
  -- is why it is a separate module even though it reads the same shouldOffer
  -- decision.  Its update wrapper is also the only place the live battle
  -- reaches this mod without an event, which is why adoption rides it.
  local menu = m["src/menu.lua"]
  menu.bind({ overlay = overlay, diag = diag, adopt = adopt })
  menu.install(mod, state)

  -- Events:emit pcalls the LISTENER, not the calls inside it, so three
  -- handlers sharing one listener meant the first to throw silently cancelled
  -- the two behind it -- and the engine's report for that is a print() the
  -- packaged launcher discards, so the symptom was a mechanic that just
  -- stopped happening.  Each call is guarded on its own now, and says what it
  -- caught.
  --
  -- Guarded rather than split into a listener each, which would isolate them
  -- just as well: Events:on table.sorts the list by priority on every
  -- subscribe and Lua's sort is not stable, so listeners sharing a priority
  -- have no guaranteed order between them where calls in one listener do.
  local function run(what, fn)
    local ok, err = pcall(fn)
    if not ok then diag.fault(what, err) end
  end

  mod.events:on("battle.started", function(ev)
    diag.reached("battle.started", ev)
    run("arm.onBattleStarted", function() state:onBattleStarted(ev) end)
    run("primal.onBattleStarted", function() primal.onBattleStarted(ev) end)
    run("conditional.onBattleStarted", function() conditional.onBattleStarted(ev) end)
    run("dynamax.onBattleStarted", function() dynamax.onBattleStarted(dynamaxState) end)
    run("tera.onBattleStarted", function() tera.onBattleStarted(teraState) end)
  end)
  mod.events:on("battle.turn_started", function(ev)
    diag.reached("battle.turn_started", ev)
    run("resolve.onTurnStarted", function() resolve.onTurnStarted(state, ev) end)
  end)
  mod.events:on("battle.battler_switched", function(ev)
    diag.reached("battle.battler_switched", ev)
    run("resolve.onBattlerSwitched", function() resolve.onBattlerSwitched(ev) end)
    run("primal.onBattlerSwitched", function() primal.onBattlerSwitched(ev) end)
    run("conditional.onBattlerSwitched", function() conditional.onBattlerSwitched(ev) end)
    -- After resolve's switch-in reapply, and it has to stay after it: this
    -- reads ev.previous (the mon LEAVING) where resolve reads ev.battler (the
    -- one arriving), so the two never touch the same mon -- but a Dynamax
    -- ending has to clear mon.form before any later handler asks what form the
    -- mon is wearing.
    run("dynamax.onBattlerSwitched", function() dynamax.onBattlerSwitched(dynamaxState, ev) end)
    -- Last of the switch handlers, and it has to stay last: a Terastallization
    -- outlives a switch where every other manual transformation here either
    -- ends on one or is reapplied by resolve above, and it is the outermost of
    -- them -- a mon that megaed and then terastallized is the type it chose,
    -- not the type its mega form is.
    run("tera.onBattlerSwitched", function() tera.onBattlerSwitched(teraState, ev) end)
  end)
  -- Subscribing is also what makes these three fire at all: the engine builds
  -- their payloads behind a Runtime.wants check on the exact event name, so an
  -- unsubscribed battle.damage_dealt is never constructed in the first place.
  mod.events:on("battle.move_used", function(ev)
    diag.reached("battle.move_used", ev)
    run("conditional.onMoveUsed", function() conditional.onMoveUsed(ev) end)
  end)
  mod.events:on("battle.damage_dealt", function(ev)
    diag.reached("battle.damage_dealt", ev)
    run("conditional.onDamageDealt", function() conditional.onDamageDealt(ev) end)
  end)
  mod.events:on("battle.turn_ended", function(ev)
    diag.reached("battle.turn_ended", ev)
    run("conditional.onTurnEnded", function() conditional.onTurnEnded(ev) end)
    run("dynamax.onTurnEnded", function() dynamax.onTurnEnded(dynamaxState, ev) end)
  end)
  mod.events:on("battle.fainted", function(ev)
    diag.reached("battle.fainted", ev)
    run("resolve.onFainted", function() resolve.onFainted(ev) end)
    run("dynamax.onFainted", function() dynamax.onFainted(dynamaxState, ev) end)
    run("tera.onFainted", function() tera.onFainted(teraState, ev) end)
  end)
  mod.events:on("battle.ended", function(ev)
    diag.reached("battle.ended", ev)
    run("resolve.onBattleEnded", function() resolve.onBattleEnded(ev) end)
    run("arm.onBattleEnded", function() state:onBattleEnded(ev) end)
    -- Beside the arm state's own reset and after the party sweep above, for
    -- the same two reasons: the sweep has already taken every form off, and
    -- what is left to drop is the mon reference, which must not outlive the
    -- battle that owned it.
    run("dynamax.onBattleEnded", function() dynamax.onBattleEnded(dynamaxState) end)
    -- Beside it, and for one reason of its own: this one has a battler to put
    -- back rather than a mon to strip, so it is given the event and not just
    -- the state.
    run("tera.onBattleEnded", function() tera.onBattleEnded(teraState, ev) end)
    -- After the party sweep above, and it must stay after it: this marks the
    -- battle closed so no later frame can adopt it and re-apply a form to a
    -- mon resolve.onBattleEnded has just reverted.
    run("adopt.onBattleEnded", function() adopt.onBattleEnded(ev) end)
    -- Last, so the flush it performs carries everything the handlers above
    -- had to say about the battle that just ended.
    run("diag.onBattleEnded", function() diag.onBattleEnded(ev) end)
  end)
end
