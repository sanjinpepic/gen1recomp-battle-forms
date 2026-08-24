-- The gimmick half of the outward-facing API: what a peer drawing its own
-- battle scene gets instead of this mod's own menu cell.
--
-- That cell is bolted to the native screen's layout, so a peer cannot reuse
-- it -- but it needs the same three facts the cell reads. The obvious move is
-- to publish the registry and the arm state and let the peer help itself.
-- That is what this suite exists to prevent, and it pins the two reasons:
--
--   1. THE REGISTRY IS NOT A READ SURFACE. Registry:register would let a peer
--      add a transformation to the player's menu, and Registry:all() hands
--      back the live list, whose ORDER is the order the cell cycles in
--      (src/transforms.lua's own header). A peer that sorted the rows it was
--      given would reorder the player's own menu.
--
--   2. ACTIVATE IS NOT THE EXTERNAL VERB. src/resolve.lua's M.onTurnStarted
--      is the only caller of activate anywhere in this mod, and it pairs it
--      unconditionally with state:consume(id) -- the one place the
--      once-per-battle limit is recorded. An external activate() therefore
--      transforms without spending the flag, and the same trainer arms a
--      second one, which is the single rule the registry exists to enforce.
--      The external verb is arm(), and the activation stays where it is.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local Api = dofile(MOD .. "/src/formapi.lua")
local Transforms = dofile(MOD .. "/src/transforms.lua")

-- A registry with the two shapes that matter: one on offer and one not.
local BATTLE = { id = "the battle" }
local seenBattle
local function registryWith()
  local registry = Transforms.new()
  registry:register({
    id = "mega", label = "MEGA",
    available = function(battle) seenBattle = battle; return true end,
    activate = function() error("activate must never be reached from here") end,
  })
  registry:register({
    id = "dynamax", label = "DYNAMAX",
    available = function() return false end,
    activate = function() error("activate must never be reached from here") end,
  })
  return registry
end

-- An arm state stub shaped like src/arm.lua's: toggle answers whether the id
-- is now armed, and records that it -- and not activate -- was the call made.
local function armStateStub()
  local self = { armedId = nil, calls = {} }
  function self:toggle(id)
    self.calls[#self.calls + 1] = id
    self.armedId = (self.armedId ~= id) and id or nil
    return self.armedId == id
  end
  function self:armed() return self.armedId end
  return self
end

local function install(registry, state)
  local exports = {}
  Api.bind({ transforms = registry, armState = state })
  Api.install({ exports = exports })
  return exports
end

-- --- the rows -------------------------------------------------------------
local registry, state = registryWith(), armStateStub()
local exports = install(registry, state)

local rows = exports.gimmicks(BATTLE)
T.eq(#rows, 2, "every registered transformation is offered")
T.eq(rows[1].id, "mega", "in registration order, which is the cell's order")
T.eq(rows[1].label, "MEGA", "carrying the label the cell would draw")
T.eq(rows[1].available, true, "and whether it can be armed right now")
T.eq(rows[2].id, "dynamax", "the second one too")
T.eq(rows[2].available, false, "with its own answer, not the first one's")
T.eq(seenBattle, BATTLE, "the predicate is asked about the battle handed in")

-- `available` is a BOOLEAN, not the predicate. Handing the function out would
-- hand a peer something callable against anything, closing over this mod's
-- own internals.
T.eq(type(rows[1].available), "boolean", "available is resolved, not a function")

-- --- the rows are COPIES --------------------------------------------------
-- A peer that sorts or edits what it was given must not touch the menu.
rows[1].label = "VANDALISED"
rows[2] = nil
local again = exports.gimmicks(BATTLE)
T.eq(#again, 2, "editing the returned rows does not shorten the registry")
T.eq(again[1].label, "MEGA", "nor rename an entry")
T.eq(registry:all()[1].label, "MEGA", "the registry's own entry is untouched")

-- --- a predicate that raises does not take the scene down ----------------
local angry = Transforms.new()
angry:register({ id = "boom", label = "BOOM",
                 available = function() error("predicate exploded") end,
                 activate = function() end })
local angryExports = install(angry, armStateStub())
local angryRows = angryExports.gimmicks(BATTLE)
T.eq(#angryRows, 1, "a raising predicate still yields its row")
T.eq(angryRows[1].available, false, "reported as unavailable rather than raising")

-- --- arming goes through toggle, never activate ---------------------------
registry, state = registryWith(), armStateStub()
exports = install(registry, state)

T.eq(exports.armed(), nil, "nothing is armed to begin with")
T.eq(exports.arm("mega"), true, "arming answers that it is now armed")
T.eq(state.calls[1], "mega", "and did it by toggling the arm state")
T.eq(exports.armed(), "mega", "which is then the armed id")
T.eq(exports.arm("mega"), false, "arming the same one again disarms it")
T.eq(exports.armed(), nil, "leaving nothing armed")

-- Both entries' activate() raise, so the assertions above passing at all is
-- the proof that no path here reached one.

-- --- refusals answer, they do not raise ----------------------------------
T.eq(exports.arm("nosuchthing"), false, "an id nothing registered is refused")
T.eq(exports.arm(nil), false, "and no id at all")
T.eq(exports.arm(42), false, "and an id that is not a string")

-- --- unbound is a no-op, not an error ------------------------------------
-- Every other entry point in this file tolerates being called before bind;
-- this module is dofile()d bare by half a dozen suites.
Api.bind({})
local bare = {}
Api.install({ exports = bare })
T.same(bare.gimmicks(BATTLE), {}, "no registry bound means no rows")
T.eq(bare.arm("mega"), false, "and nothing can be armed")
T.eq(bare.armed(), nil, "and nothing is")

-- --- colon calls are tolerated, as everywhere else on this table ---------
-- exports:gimmicks(battle) passes the exports table as the first argument,
-- which is an ordinary Lua mistake rather than a request for a nil error.
Api.bind({ transforms = registryWith(), armState = armStateStub() })
local colon = {}
Api.install({ exports = colon })
T.eq(#colon:gimmicks(BATTLE), 2, "gimmicks survives a colon call")
T.eq(colon:arm("mega"), true, "and so does arm")

T.finish("battle_forms_formapi_scene")
