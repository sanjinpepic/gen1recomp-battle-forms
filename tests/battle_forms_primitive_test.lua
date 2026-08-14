package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Forms = dofile(MOD .. "/src/forms.lua")

-- Two species records differing only in base stats, so a stat change proves
-- the recompute ran rather than the re-key alone.
-- charizard-mega-x's name is deliberately NOT its base species' name here --
-- forms.lua only has to follow whatever the record says, the same as any
-- other field recompute reads; src/naming.lua (and its own suite) is what
-- makes the two agree in a real load.
local DATA = { pokemon = {
  CHARIZARD = { baseStats = { hp = 78, attack = 84, defense = 78,
                              speed = 100, special = 85 },
                types = { "FIRE", "FLYING" }, name = "CHARIZARD" },
  ["charizard-mega-x"] = { baseStats = { hp = 78, attack = 130, defense = 111,
                                         speed = 100, special = 130 },
                           types = { "FIRE", "DRAGON" }, name = "MEGA-X-RAW" },
} }

local function battler()
  return { mon = { species = "CHARIZARD", level = 50,
                   dvs = { hp = 15, attack = 15, defense = 15,
                           speed = 15, special = 15 },
                   statExp = {} },
           sprite = "stale", isPlayer = false }
end

local b = battler()

T.eq(Forms.becomeForm(DATA, b, "charizard-mega-x"), true, "form change succeeds")
T.eq(b.mon.species, "charizard-mega-x", "species is re-keyed to the form")
T.check(b.mon.stats.attack > 100, "stats are recomputed from the form record")
T.eq(b.sprite, "stale", "no battle was given, so the cached picture is left alone")

local megaAttack = b.mon.stats.attack

T.eq(Forms.revertForm(b, DATA), true, "revert succeeds")
T.eq(b.mon.species, "CHARIZARD", "species is restored")
T.check(b.mon.stats.attack < megaAttack, "stats are recomputed back")

T.eq(Forms.revertForm(b, DATA), nil, "reverting an unchanged battler is a no-op")

local missing = battler()
T.eq(Forms.becomeForm(DATA, missing, "nosuchform"), nil,
  "an unknown form id refuses rather than half-applying")
T.eq(missing.mon.species, "CHARIZARD", "a refused change leaves the mon alone")

-- The bug this file exists to pin: a mega survives switching out, and the
-- engine builds a fresh battler on the way back in.  A marker held on the
-- battler would be lost there, and the mon would never revert.
local switched = battler()
Forms.becomeForm(DATA, switched, "charizard-mega-x")
local returned = { mon = switched.mon, sprite = "fresh" }
T.eq(returned.mon.species, "charizard-mega-x",
  "the form survives being wrapped in a new battler")
T.eq(Forms.revertForm(returned, DATA), true,
  "a battler rebuilt on send-out can still revert its mon")
T.eq(returned.mon.species, "CHARIZARD", "and the base species comes back")

-- The battle-end sweep walks the party, where there is no battler at all.
local benched = battler()
Forms.becomeForm(DATA, benched, "charizard-mega-x")
T.eq(Forms.revertMon(DATA, benched.mon), true, "a mon reverts without a battler")
T.eq(benched.mon.species, "CHARIZARD", "a benched mon is restored too")
T.eq(Forms.revertMon(DATA, benched.mon), nil, "sweeping an untransformed mon is a no-op")

-- A fake battle exposing speciesSprite, recording every call and answering
-- from a species -> picture table (nil for anything not listed, standing in
-- for a lookup that misses).
local function fakeBattle(pics)
  local calls = {}
  return {
    speciesSprite = function(_, species, isPlayerSide, transformed)
      calls[#calls + 1] = { species = species, isPlayerSide = isPlayerSide,
                             transformed = transformed }
      return pics[species]
    end,
  }, calls
end

-- becomeForm reloads the picture, asking for the FORM's own color rather
-- than Transform's forced gray.
local withBattle = battler()
local battle1, calls1 = fakeBattle({ ["charizard-mega-x"] = "mega-pic",
                                     CHARIZARD = "base-pic" })
T.eq(Forms.becomeForm(DATA, withBattle, "charizard-mega-x", battle1), true,
  "form change succeeds with a battle in hand")
T.eq(withBattle.sprite, "mega-pic", "the picture is reloaded through the battle")
T.eq(#calls1, 1, "speciesSprite is asked once")
T.eq(calls1[1].species, "charizard-mega-x", "for the new form id")
T.eq(calls1[1].isPlayerSide, false, "on the battler's own side")
T.eq(calls1[1].transformed, false,
  "and asks for the form's real color, not Transform's forced gray")

-- revertForm reloads too, and gets back the BASE species' picture.
T.eq(Forms.revertForm(withBattle, DATA, battle1), true, "revert succeeds")
T.eq(withBattle.sprite, "base-pic", "revert reloads the base species' picture")
T.eq(#calls1, 2, "speciesSprite is asked again on revert")
T.eq(calls1[2].species, "CHARIZARD", "for the base species this time")

-- A battle with no speciesSprite method at all (not every fake in this
-- codebase bothers to stub it) is treated the same as no battle: succeed,
-- leave the picture alone.
local noMethod = battler()
T.eq(Forms.becomeForm(DATA, noMethod, "charizard-mega-x", {}), true,
  "a battle-shaped table with no speciesSprite still succeeds")
T.eq(noMethod.sprite, "stale", "and leaves the picture alone")

-- A speciesSprite that resolves but comes back nil (a missing sprite path,
-- say) must not blank the picture the way the old unconditional nil did.
local missingPic = battler()
local battle2 = fakeBattle({})
T.eq(Forms.becomeForm(DATA, missingPic, "charizard-mega-x", battle2), true,
  "form change succeeds even when the sprite lookup misses")
T.eq(missingPic.sprite, "stale",
  "a nil lookup leaves the previous picture intact rather than blanking it")

-- battler.name follows the form record and is restored on revert, so the
-- HUD does not wait for the next send-out to catch up.
local named = battler()
named.name = "CHARIZARD"
T.eq(Forms.becomeForm(DATA, named, "charizard-mega-x"), true, "form change succeeds")
T.eq(named.name, "MEGA-X-RAW", "the HUD name follows the form record")
T.eq(Forms.revertForm(named, DATA), true, "revert succeeds")
T.eq(named.name, "CHARIZARD", "and is restored to the base species' name")

-- A nickname outranks both the base and the form's own name throughout.
local nicknamed = battler()
nicknamed.mon.nickname = "SPARKY"
nicknamed.name = "SPARKY"
T.eq(Forms.becomeForm(DATA, nicknamed, "charizard-mega-x"), true,
  "form change succeeds for a nicknamed mon")
T.eq(nicknamed.name, "SPARKY", "the nickname survives the form change")
T.eq(Forms.revertForm(nicknamed, DATA), true, "revert succeeds")
T.eq(nicknamed.name, "SPARKY", "and survives the revert too")

T.finish("battle_forms_primitive")
