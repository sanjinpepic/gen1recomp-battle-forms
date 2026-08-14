package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Arm = dofile(MOD .. "/src/arm.lua")

local state = Arm.new()
local battle = { player = { mon = { species = "CHARIZARD" } } }

T.eq(state:current(), nil, "no battle is cached before one starts")

state:onBattleStarted({ battle = battle })
T.eq(state:current(), battle, "the live battle is cached from battle.started")
T.eq(state:isArmed(), false, "a fresh battle starts unarmed")

T.eq(state:toggle("mega"), true, "toggling arms")
T.eq(state:isArmed(), true, "armed state sticks")
T.eq(state:toggle("mega"), false, "toggling again disarms")

state:toggle("mega")
state:consume("mega")
T.eq(state:isArmed(), false, "consuming clears the armed flag")
T.eq(state:used("mega"), true, "consuming records that this battle has had its one change")

T.eq(state:toggle("mega"), false, "a battle that already changed form cannot arm again")
T.eq(state:isArmed(), false, "and it stays unarmed")

state:onBattleEnded({ battle = battle })
T.eq(state:current(), nil, "the reference is dropped when the battle ends")
T.eq(state:used("mega"), false, "the once-per-battle limit resets with the battle")

-- A second battle must start completely clean, including after one where the
-- player armed but never fired.
state:onBattleStarted({ battle = battle })
state:toggle("mega")
state:onBattleStarted({ battle = battle })
T.eq(state:isArmed(), false, "a new battle clears a leftover armed flag")

-- Each transformation carries its own limit, which is the whole reason the
-- flag is keyed rather than counted: mega evolution, Dynamax and the rest each
-- get one per battle in the real games, so spending one must leave the others
-- exactly where they were.
local multi = Arm.new()
multi:onBattleStarted({ battle = battle })
multi:toggle("mega")
multi:consume("mega")
T.eq(multi:used("mega"), true, "the transformation that fired is spent")
T.eq(multi:used("dynamax"), false, "and no other transformation was spent with it")
T.eq(multi:toggle("dynamax"), true, "another transformation can still be armed")
T.eq(multi:armed(), "dynamax", "the armed flag names which one it is")
multi:consume("dynamax")
T.eq(multi:used("mega") and multi:used("dynamax"), true, "now both are spent")
T.eq(multi:toggle("mega"), false, "and neither can be armed again")

-- Only one may be armed at a time, and it is always the selected one: the cell
-- shows one label, so an armed flag behind a label the player cannot see is a
-- change that fires by surprise.
local one = Arm.new()
one:onBattleStarted({ battle = battle })
one:toggle("mega")
T.eq(one:selected(), "mega", "arming selects what it armed")
one:toggle("dynamax")
T.eq(one:armed(), "dynamax", "arming a second one replaces the first")
one:select("mega")
T.eq(one:armed(), nil, "selecting away from the armed one disarms it")
T.eq(one:selected(), "mega", "and leaves the selection where it was moved to")
one:toggle("mega")
one:select("mega")
T.eq(one:armed(), "mega", "reselecting what is already selected changes nothing")

-- Selection resets with the battle the same as everything else here.
one:onBattleEnded({ battle = battle })
T.eq(one:selected(), nil, "the selection is dropped when the battle ends")

T.eq(state:toggle(nil), false, "arming nothing is refused rather than crashed on")

T.finish("battle_forms_arm")
