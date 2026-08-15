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

T.eq(state:usedAny(), false, "and with the battle's one manual transformation intact")

state:toggle("mega")
state:consume("mega")
T.eq(state:isArmed(), false, "consuming clears the armed flag")
T.eq(state:used("mega"), true, "consuming records that this battle has had its one change")
T.eq(state:usedAny(), true, "and that the battle's one manual transformation is gone")

T.eq(state:toggle("mega"), false, "a battle that already changed form cannot arm again")
T.eq(state:isArmed(), false, "and it stays unarmed")

state:onBattleEnded({ battle = battle })
T.eq(state:current(), nil, "the reference is dropped when the battle ends")
T.eq(state:used("mega"), false, "the once-per-battle limit resets with the battle")
T.eq(state:usedAny(), false, "and so does the one the whole battle shares")

-- A second battle must start completely clean, including after one where the
-- player armed but never fired.
state:onBattleStarted({ battle = battle })
state:toggle("mega")
state:onBattleStarted({ battle = battle })
T.eq(state:isArmed(), false, "a new battle clears a leftover armed flag")

-- Each transformation still carries a limit of its own, keyed by id, and the
-- battle-wide one laid over it in 0.14.0 does not stand in for it: a spent
-- mega is spent on its own account, so a mechanic later exempted from the
-- shared rule is still refused a second go.  What the shared rule does is stop
-- the cell OFFERING the others, which is src/overlay.lua's and is pinned in
-- the overlay, transforms and dynamax suites -- this file is the record
-- underneath it, and the two are checked apart on purpose.
local multi = Arm.new()
multi:onBattleStarted({ battle = battle })
multi:toggle("mega")
multi:consume("mega")
T.eq(multi:used("mega"), true, "the transformation that fired is spent")
T.eq(multi:used("dynamax"), false, "and no other transformation was spent with it")
T.eq(multi:usedAny(), true, "though the battle's shared limit went with it")
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

-- ---------------------------------------------------------------------
-- The arm/disarm dispatch, which is how a move substitution reaches the FIGHT
-- menu on the turn it was armed instead of the turn after.  Driven here with a
-- fake registry rather than with the real Dynamax and Z-Move, because what is
-- being pinned is the ORDER of the two calls and which writes make them: the
-- mechanics' own suites pin what they do when called.
-- ---------------------------------------------------------------------
do
  local log = {}
  local function entry(id)
    return { id = id,
             arm = function(battle) log[#log + 1] = id .. ":arm:" ..
                                                    tostring(battle and battle.tag) end,
             disarm = function() log[#log + 1] = id .. ":disarm" end }
  end
  local entries = { alpha = entry("alpha"), beta = entry("beta"),
                    -- A mechanic with nothing to put on early -- mega evolution
                    -- and Terastallization are both this -- must be armable
                    -- without either hook being invented for it.
                    plain = { id = "plain" } }
  Arm.bind({ registry = { get = function(_, id) return entries[id] end } })

  local live = { tag = "live", player = { mon = { species = "PIKACHU" } } }
  local hooked = Arm.new()
  hooked:onBattleStarted({ battle = live })

  hooked:toggle("alpha")
  T.eq(table.concat(log, " "), "alpha:arm:live",
    "arming calls the entry's arm with the live battle")

  log = {}
  hooked:toggle("alpha")
  T.eq(table.concat(log, " "), "alpha:disarm",
    "and a second press takes it back off")

  -- Cycling while armed is the sharp case: LEFT/RIGHT move the selection, the
  -- selection is always what is armed, so what was armed must come off.
  log = {}
  hooked:toggle("alpha")
  hooked:select("beta")
  T.eq(table.concat(log, " "), "alpha:arm:live alpha:disarm",
    "cycling away from an armed transformation disarms it")
  T.eq(hooked:isArmed(), false, "leaving nothing armed to put anything on")

  -- Arming the other one directly is the same crossing in one press, and the
  -- old one has to come off BEFORE the new one goes on: both substitute the
  -- same array, and the wrong order would restore over the new one.
  log = {}
  hooked:toggle("alpha")
  hooked:toggle("beta")
  T.eq(table.concat(log, " "), "alpha:arm:live alpha:disarm beta:arm:live",
    "arming a second one takes the first off before putting the second on")

  -- Spending is the one write that does NOT disarm: the transformation
  -- activated, and what it put on is now its own to unwind on its own clock.
  log = {}
  hooked:consume("beta")
  T.eq(#log, 0, "spending a transformation disarms nothing")
  T.eq(hooked:isArmed(), false, "though the flag is cleared all the same")

  -- A battle ending unwinds an armed-but-never-fired substitution: the battler
  -- holding it belongs to a battle that is over.
  log = {}
  hooked:toggle("alpha")
  hooked:onBattleEnded({ battle = live })
  T.eq(table.concat(log, " "), "alpha:arm:live alpha:disarm",
    "and a battle ending takes off whatever was still armed")

  log = {}
  hooked:onBattleStarted({ battle = live })
  hooked:toggle("plain")
  hooked:toggle("plain")
  hooked:select("alpha")
  T.eq(#log, 0, "an entry with no hooks arms and disarms without them")

  -- An id the registry has never heard of is a stale flag, not a crash.
  log = {}
  hooked:toggle("nosuchthing")
  T.eq(hooked:armed(), "nosuchthing", "an unknown id still arms the flag")
  T.eq(#log, 0, "and reaches no hook")
end

-- Unbound, this file is what it was before any of that: the dispatch is the
-- only thing that wants a registry, and the mod's own suites run without one.
do
  local Bare = dofile(MOD .. "/src/arm.lua")
  local loose = Bare.new()
  loose:onBattleStarted({ battle = battle })
  T.eq(loose:toggle("mega"), true, "arming works with no registry bound")
  loose:select("dynamax")
  T.eq(loose:isArmed(), false, "and so does selecting away from it")
end

T.finish("battle_forms_arm")
