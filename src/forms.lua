-- A form change is a species re-key.  Everything downstream in battle derives
-- from mon.species -- the species def, the battle picture, the palette -- so
-- changing that one field and dropping the cached picture is the entire
-- transaction.  Transform already works this way; this is the same move made
-- deliberately and held for the rest of the battle.
--
-- The base species is remembered on the MON, not on the battler.  A mega
-- survives switching out, and the engine builds a fresh battler every
-- send-out -- a marker held on the battler would vanish on the way back in
-- while the re-keyed species stayed, leaving the mon permanently transformed
-- in the save.
local Stats = require("src.pokemon.Stats")

local M = {}

M.BASE = "battleFormsBase"

local function recompute(data, mon, speciesId)
  local def = data and data.pokemon and data.pokemon[speciesId]
  if def then
    mon.stats = Stats.calc(def, mon.level, mon.dvs, mon.statExp)
  end
end

-- The battle picture is rebuilt from the new species rather than merely
-- invalidated: BattleState builds battler.sprite once at send-out and the
-- draw path just blits whatever is cached there, so clearing it with nothing
-- to reload left the mon undrawn for the rest of the fight.
--
-- BattleState:speciesSprite looked like the obvious way to rebuild it, but
-- its only real caller is Transform, and it forces PAL_GRAYMON to match a
-- Transformed mon's copied-and-grayed sprite (transform.asm's
-- DeterminePaletteID) -- exactly wrong for a mega, which keeps its own
-- color.  BattleState.makeBattler builds the same picture through the
-- species' own palette (the monPalette path every normal send-out uses) and
-- is a pure constructor -- it reads data/mon and returns a fresh battler,
-- mutating nothing -- so a throwaway one built for this mon, discarding
-- everything but its sprite, is the real send-out picture without forcing
-- gray and without touching the engine.
--
-- `battle` is optional -- the unit suite exercises forms.lua with a bare
-- battler and no battle at all -- and requiring BattleState is wrapped in
-- pcall because engine_internals is a courtesy the host owes the mod, not a
-- guarantee: whenever the module, or the build itself, is unavailable the
-- picture is simply left as it was rather than blanked.  "or battler.sprite"
-- covers a build that resolves but comes back with no sprite the same way.
local function reloadSprite(battle, battler)
  if not (battle and battler) then return end
  local okRequire, BattleState = pcall(require, "src.battle.BattleState")
  if not okRequire or not (BattleState and BattleState.makeBattler) then return end
  local okBuild, fresh = pcall(BattleState.makeBattler, battle.data, battler.mon,
                                battler.isPlayer)
  if okBuild then
    battler.sprite = fresh and fresh.sprite or battler.sprite
  end
end

-- The HUD name is cached on the battler at send-out (mon.nickname or
-- def.name; BattleState.makeBattler) while the post-battle text re-reads
-- data.pokemon[mon.species].name live, so a re-key with nothing updating the
-- cached copy leaves the HUD showing the old name until the next switch-in
-- even after the species (and everything else) has changed.
local function reloadName(data, battler, mon, speciesId)
  if not battler then return end
  local def = data and data.pokemon and data.pokemon[speciesId]
  if not def then return end
  battler.name = mon.nickname or def.name
end

-- Refuses rather than half-applying.  A mon left holding a form id its
-- species table has no record for would draw nothing and compute nothing, and
-- the failure would surface somewhere far from here.  The refusal reason is
-- returned rather than swallowed: a caller (src/resolve.lua) logs it, because
-- a silent refusal here is exactly the failure that let a wrong form id ship
-- for a whole release without a single error anywhere.
--
-- `battle` is optional and threaded through only to reach makeBattler --
-- forms.lua stays unit-testable with a bare battler and no battle at all.
function M.becomeForm(data, battler, formId, battle)
  local mon = battler and battler.mon
  if not mon or not formId then return nil, "no_target" end
  if not (data and data.pokemon and data.pokemon[formId]) then return nil, "no_record" end

  mon[M.BASE] = mon[M.BASE] or mon.species
  mon.species = formId
  recompute(data, mon, formId)
  reloadSprite(battle, battler)
  reloadName(data, battler, mon, formId)
  return true
end

-- Takes the mon rather than the battler: the battle-end sweep walks the whole
-- party, where a mon that transformed and then switched out has no battler at
-- all.  Reverting an untransformed mon is a no-op so the sweep can be blunt.
function M.revertMon(data, mon)
  local base = mon and mon[M.BASE]
  if not base then return nil end
  mon.species = base
  mon[M.BASE] = nil
  recompute(data, mon, base)
  return true
end

function M.revertForm(battler, data, battle)
  if not battler then return nil end
  local done = M.revertMon(data, battler.mon)
  if done then
    reloadSprite(battle, battler)
    reloadName(data, battler, battler.mon, battler.mon.species)
  end
  return done
end

return M
