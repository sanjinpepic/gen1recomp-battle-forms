-- species id -> item id -> National Dex form id, for the forms that OUTLIVE
-- the battle.
--
-- The same shape as data/megas.lua and data/primals.lua and read by the same
-- lookup, and a SEPARATE table for the reason theirs are separate: which table
-- a caller hands to eligibility.formForMon is what says which transformation
-- type it is asking about.  Nothing that decides whether a mega may happen ever
-- sees this table, and nothing here ever sees theirs.
--
-- What makes this one different is not its shape but what src/resolve.lua's
-- party sweep does with a mon it names.  Every other table here describes a
-- form the sweep takes off; this one describes the form the sweep puts BACK.
-- That is the whole of the difference, and src/persistent.lua is where it
-- lives.
--
-- The form id MUST be the National Dex record's KEY -- what data.pokemon[...]
-- is indexed by (e.g. ROTOM_WASH) -- and never the record's `name` field
-- (e.g. "rotom-wash").  Those look interchangeable and are not: a `name` value
-- here compiles fine and passes review, and then every lookup in
-- Forms.becomeForm misses silently.  That exact mistake shipped in 0.2.1;
-- tests/battle_forms_formids_test.lua is why it cannot ship again.
--
-- Rotom alone, and deliberately.  Three families in the National Dex data are
-- persistent forms of this kind -- Rotom's appliances, Giratina's Origin Forme
-- and Shaymin's Sky Forme -- and only the first is item-driven end to end: the
-- other two hang off a held item and a time of day that this game has no way to
-- ask about, so wiring them would mean inventing the trigger rather than
-- modelling it.  Rotom is also the one that proves the mechanism rather than a
-- special case of it, because it has five forms and a base to come back to
-- where the others have one form and a toggle.
--
-- All five have front AND back art under ROTOM.forms.[SUFFIX]; the art suite
-- fails if that ever stops being true.  A form with only a front picture is
-- invisible on the player's own side of the battle, which is worse here than
-- anywhere else in this mod -- a battle form a player cannot see lasts one
-- fight, and this one lasts until they change it back.
return {
  ROTOM = {
    MICROWAVE_OVEN  = "ROTOM_HEAT",
    WASHING_MACHINE = "ROTOM_WASH",
    REFRIGERATOR    = "ROTOM_FROST",
    ELECTRIC_FAN    = "ROTOM_FAN",
    LAWN_MOWER      = "ROTOM_MOW",
  },
}
