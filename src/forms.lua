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
-- to reload left the mon undrawn for the rest of the fight.  `battle` is
-- optional -- the unit suite binds fakes with no real battle in play -- and
-- when it, or its speciesSprite method, is missing the picture is simply
-- left as it was rather than blanked; "or battler.sprite" covers a lookup
-- that resolves but comes back nil the same way.
--
-- transformed=false: BattleState:speciesSprite's other caller (Transform)
-- forces PAL_GRAYMON, correct for a copied species that really is gray, but
-- a mega form is not Transform and keeps its own color -- forcing it gray
-- would trade "the sprite vanished" for "the sprite is the wrong color".
local function reloadSprite(battle, battler, speciesId)
  if not (battle and battle.speciesSprite and battler) then return end
  battler.sprite = battle:speciesSprite(speciesId, battler.isPlayer, false)
                    or battler.sprite
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
-- `battle` is optional and threaded through only to reach speciesSprite --
-- forms.lua stays unit-testable with a bare battler and no battle at all.
function M.becomeForm(data, battler, formId, battle)
  local mon = battler and battler.mon
  if not mon or not formId then return nil, "no_target" end
  if not (data and data.pokemon and data.pokemon[formId]) then return nil, "no_record" end

  mon[M.BASE] = mon[M.BASE] or mon.species
  mon.species = formId
  recompute(data, mon, formId)
  reloadSprite(battle, battler, formId)
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
    reloadSprite(battle, battler, battler.mon.species)
    reloadName(data, battler, battler.mon, battler.mon.species)
  end
  return done
end

return M
