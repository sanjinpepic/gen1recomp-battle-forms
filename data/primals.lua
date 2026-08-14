-- species id -> orb item id -> National Dex form id.
--
-- The same shape as data/megas.lua and read by the same lookup, and a
-- SEPARATE table on purpose.  Primal reversion is its own transformation
-- type, not a mega with a different item: nothing that decides whether a mega
-- may happen -- the MEGA cell, the armed flag, the one change per battle --
-- ever sees this table, and nothing here ever sees theirs.  Which table a
-- caller passes to eligibility.formForMon is what says which transformation
-- type it is asking about, so keeping the two apart is the whole separation.
--
-- The form id MUST be the National Dex record's KEY -- what data.pokemon[...]
-- is indexed by (e.g. GROUDON_PRIMAL) -- and never the record's `name` field
-- (e.g. "groudon-primal").  Those look interchangeable and are not: a `name`
-- value here compiles fine and passes review, and then every lookup in
-- Forms.becomeForm misses silently.  That exact mistake shipped in 0.2.1;
-- tests/battle_forms_formids_test.lua is why it cannot ship again.
--
-- No official/extended marker, unlike megas.lua.  Both pairings are ones the
-- real games have and there is no larger set to choose between, so the MEGA
-- EVOLUTIONS option has nothing to say about either of them.
--
-- Both forms have art in data/sprites/generated/formart.lua under
-- [BASE].forms.PRIMAL; the art suite fails if that ever stops being true.
return {
  GROUDON = { RED_ORB  = "GROUDON_PRIMAL" },
  KYOGRE  = { BLUE_ORB = "KYOGRE_PRIMAL" },
}
