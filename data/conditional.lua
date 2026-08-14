-- species id -> the one condition-driven form that species has, and what
-- makes it happen.
--
-- The third pairing table, and the third transformation type.  A mega is a
-- player decision and a primal reversion is a held item; these are neither.
-- Nothing is armed, nothing is carried, and the mon is never asked: the form
-- is whatever the row's condition currently says it should be, which is why
-- src/conditional.lua stores nothing and re-derives the answer every time it
-- is handed a battler.
--
-- Keyed by species rather than listed as rows, so a species can carry exactly
-- one of these and the lookup is a plain index.  Two rows for one species
-- would need a priority order between them, and there is no honest one.
--
-- The form id MUST be the National Dex record's KEY -- what data.pokemon[...]
-- is indexed by (e.g. DARMANITAN_ZEN) -- and never the record's `name` field
-- (e.g. "darmanitan-zen").  A `name` value here compiles fine and then misses
-- silently in every lookup; tests/battle_forms_formids_test.lua is why that
-- cannot ship again.  Every form named here also has art under
-- [BASE].forms[FORM] in the form art index, and the art suite fails if that
-- stops being true.
--
-- `trigger` names the engine seam the condition is answered from, and the
-- set is closed because the seams are.  Each one maps to exactly one event:
--
--   hp             battle.damage_dealt, and re-derived again at
--                  battle.turn_ended and on entering the field.  `below` puts
--                  the mon in the form while its HP fraction is at or under
--                  the threshold, `above` while it is over.  Reversible in
--                  both directions and as many times as the HP crosses.
--   move_kind      battle.move_used.  An attacking move (power above zero)
--                  puts the form on, a status move takes it off.
--   hit_taken      battle.damage_dealt, read from the receiving end.  Sticks
--                  for the rest of the battle: nothing in Gen 1 restores it.
--   knockout_dealt battle.damage_dealt, read from the dealing end -- the
--                  payload fires after the HP write, so a target left at zero
--                  is a knockout this hit caused.  There is no separate
--                  "you knocked something out" event to use.  Sticks.
--   turn_end       battle.turn_ended.  Alternates every round.
--
-- These are ability-driven in the real games and this mod implements no
-- abilities, so the species is the whole trigger: a Gen 1 mon has no ability
-- field at all, and gating on one would gate on a value that is always nil.
-- The practical difference is that the forms whose ability is a hidden one --
-- Zen Mode and Battle Bond -- happen for every Darmanitan and every Greninja
-- here rather than for the rare ones.  mod.card says so.
--
-- Castform and Cherrim are the two the guide names that are not here: both
-- are weather-driven, and Gen 1 has no weather.  BattleState seeds
-- field.weather to nil and nothing ever assigns it, there is no
-- weather-changed event anywhere in the engine, and Cherrim has no form art
-- either.  Cramorant is out for a different reason -- Gulp Missile is a
-- payload that fires back at an attacker, which is ability behaviour, and the
-- guide itself says to model it as battle state rather than as a form.
return {
  -- Zen Mode: the flip that gave the whole subsystem its shape, since it is
  -- the one the guide writes out as trigger/threshold/target/reverse.
  DARMANITAN = { form = "DARMANITAN_ZEN", trigger = "hp", below = 0.5 },

  -- Shields Down.  The base MINIOR record is the meteor -- 100/100 defences
  -- and 60 speed -- and MINIOR_RED is the core it breaks into, so the pairing
  -- runs the same direction as Zen Mode even though the names read backwards.
  MINIOR = { form = "MINIOR_RED", trigger = "hp", below = 0.5 },

  -- Schooling, and the only row that runs the other way: the school holds
  -- while the HP is UP, and a Wishiwashi too small to school never forms one.
  WISHIWASHI = { form = "WISHIWASHI_SCHOOL", trigger = "hp",
                 above = 0.25, minLevel = 20 },

  -- Stance Change.  The real reverse trigger is King's Shield, which Gen 1
  -- does not have a move record for, so any status move stands in for it --
  -- the same shape of action, and the closest thing to it that a Gen 1
  -- Aegislash can actually select.
  AEGISLASH = { form = "AEGISLASH_BLADE", trigger = "move_kind" },

  -- Hunger Switch.
  MORPEKO = { form = "MORPEKO_HANGRY", trigger = "turn_end" },

  -- Disguise and Ice Face.  Neither absorbs the hit that breaks it here:
  -- absorbing is the ability, and this mod changes the form, the stats, the
  -- types and the picture but never what an ability does.
  MIMIKYU = { form = "MIMIKYU_BUSTED", trigger = "hit_taken" },
  EISCUE  = { form = "EISCUE_NOICE",   trigger = "hit_taken" },

  -- Battle Bond.  Greninja is also the one species in this table with a mega
  -- of its own (an extended one, GRENINJA_MEGA), which is exactly why
  -- src/conditional.lua refuses to dress a mon that is already wearing some
  -- other form: a knockout must not quietly undo the trainer's one mega.
  GRENINJA = { form = "GRENINJA_ASH", trigger = "knockout_dealt" },
}
