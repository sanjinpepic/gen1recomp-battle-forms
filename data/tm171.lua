-- TM171's bag byte.
--
-- The same rule every other item table in this mod runs on: Gen 1 stores an
-- item as one byte, so an id with no index cannot exist in a save at all.
-- 98-233 are packed solid and data/drives.lua's own header already worked
-- out what is left of 234-255: the Drives took 234-237 and
-- data/speciescrystals.lua's fourteen crystals took 238-251, so this
-- continues at 252 rather than reusing a byte -- three still free behind it
-- (253-255) for whatever needs one next.
--
-- tests/battle_forms_keyitems_test.lua's uniqueness sweep folds this table
-- in with every other real-byte table in the game, so a collision here is
-- caught the same way one between any other two families would be.
return {
  TM171 = 252,
}
