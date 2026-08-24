-- What this mod tells anything OUTSIDE it when a Pokemon stops being what
-- its species record says it is.
--
-- Every other file here is inward-facing: src/announce.lua writes a line for
-- the player, src/diag.lua writes one for whoever is chasing a bug, and the
-- rest talk to each other through bind().  Nothing until now said anything
-- to another MOD, which left a peer with two bad options -- poll `mon.form`
-- every frame and diff it, or reimplement this mod's own pairing tables to
-- guess what a form change was about to do.  Both were being reasoned about
-- from the outside against fields that are documented here as internal, and
-- the second is how two mods drift into disagreeing about one Pokemon.
--
-- TWO CHANNELS, because the two questions a peer actually asks are different
-- ones, and the loader already sanctions exactly one answer for each
-- (src/mods/Loader.lua's own `_api`, and CONTRIBUTING-mods.md's "publish
-- something to another mod" note):
--
--   * WHEN did it change -- `mod.events`, under the two names below.  A mod
--     may only emit under its own `mod.<id>.` prefix, and the loader raises
--     rather than dropping an emit that is not: the prefix is load-bearing,
--     not decoration, which is why the two names are constants here and are
--     handed out through the exports rather than left for a consumer to
--     retype.
--
--   * WHAT is it right now -- `mod.exports.describe(mon)`, the call-style
--     channel.  A mod that loads after a form was applied, or that draws a
--     screen long after the event fired, has no event to have heard; asking
--     costs it one call and needs no bookkeeping of its own.
--
-- Both answer with the SAME payload shape, so a consumer writes one reader
-- and points it at either.  `api` carries the shape's own version -- 1
-- today -- because a payload is a contract with code this repo cannot see,
-- and the honest way to widen one later is to say which shape this is.
--
-- WHERE IT IS FIRED FROM, and why not from the mechanics.  Mega evolution,
-- primal reversion, the persistent held-item forms, the fusions, Ultra
-- Burst, Gigantamax and the eight condition-driven forms are eight
-- different modules with a dozen call sites between them, and every single
-- one of them ends up in src/forms.lua's becomeForm (Gen 1) or
-- src/gen2forms.lua's (Gen 2) -- those two functions ARE the form change.
-- Announcing from the two primitives rather than from the eight callers is
-- what makes it impossible for a mechanic to apply a form this API does not
-- report: a ninth mechanic added later is announced by the same primitive it
-- has to call anyway to work at all.  The cost is that the primitive cannot
-- name WHICH mechanic asked, so the payload does not pretend to -- it names
-- the form, which is the thing a consumer wanted anyway.
--
-- WHAT IS NOT ANNOUNCED, stated rather than left to be discovered.  A
-- Terastallization applies no form and no stats -- it overrides typing alone
-- (src/tera.lua's own header) -- and a plain Dynamax applies neither either;
-- it scales the HP bar and nothing else (src/hpscale.lua).  Neither goes
-- through the two primitives, so neither fires here.  A GIGANTAMAX does,
-- because it really is a form record with real stats behind it.
local M = {}

-- The payload shape's own version, carried in every payload as `api`.  A
-- consumer is expected to check it: a field added later leaves this at 1
-- (adding one cannot break a reader that ignores it), and anything that
-- changes or removes a field below moves it to 2.
M.API = 1

-- The two names, and the only two strings this mod is allowed to broadcast
-- under: `Loader:_api`'s own emit closure refuses -- with an error, not a
-- dropped call -- any name that does not begin "mod.battle_forms.".
M.APPLIED = "mod.battle_forms.form_applied"
M.REVERTED = "mod.battle_forms.form_reverted"

-- Terastallization and Dynamax get their OWN names rather than being folded
-- into the two above, and the reason is that they are not form changes.
-- Neither applies a form record and neither writes a stat block: a Tera
-- overrides typing alone and a plain Dynamax scales the HP bar, which is
-- exactly why neither ever reached the two primitives that fire form_applied.
-- Announcing them as forms would hand a consumer a payload whose `form` and
-- `formId` are nil and whose `stats` are the ones the Pokemon already had --
-- indistinguishable from a bug in this mod.
--
-- A Gigantamax still fires form_applied as well, because it genuinely IS a
-- form record with real stats behind it.  A consumer watching both channels
-- sees two events for one Gigantamax, which is correct: two things happened.
M.TERA_APPLIED = "mod.battle_forms.tera_applied"
M.TERA_REVERTED = "mod.battle_forms.tera_reverted"
M.DYNAMAX_APPLIED = "mod.battle_forms.dynamax_applied"
M.DYNAMAX_REVERTED = "mod.battle_forms.dynamax_reverted"

local deps = nil

-- `events` (mod.events), `log` (mod.log), `gen2` (the boot's own flag, so a
-- payload can say which generation's stat keys it is carrying) and
-- `formresolve` (src/formresolve.lua, for the out-of-battle half of
-- describe()).  `transforms` (src/transforms.lua's registry) and `armState`
-- (src/arm.lua's state) back the gimmick half of the exports below, and are
-- read through here rather than published themselves -- see gimmicks().  Every one of them is optional at the point of use: this
-- module is dofile()d bare by its own suite, and src/forms.lua is dofile()d
-- bare by half a dozen others, so an unbound announcement has to be a
-- silent no-op rather than an error inside a form change.
function M.bind(modules) deps = modules end

-- A COPY, never the live table.  battler.curStats and mon.stats are the
-- fields battle math reads every turn (src/forms.lua's own header on why
-- those and not the mon's own), and handing a listener the real one would
-- let a peer that meant to normalise a payload for its own use silently
-- rewrite the Pokemon that is standing on the field.  Shallow is enough:
-- both tables are flat number maps, and `types` is a flat array of strings.
--
-- Copied with pairs rather than against a key list on purpose -- Gen 1's
-- stat block carries `special` where Gen 2's carries specialAttack/
-- specialDefense (src/pokemon/Stats.lua's ORDER against
-- src/battle/gen2/Mon.stats), and a payload that named either set would be
-- wrong on the other game.  The key set a consumer receives is whatever the
-- running generation actually uses, and `generation` in the payload says
-- which that is.
local function copy(source)
  if type(source) ~= "table" then return nil end
  local out = {}
  for key, value in pairs(source) do out[key] = value end
  return out
end

local function generation()
  return (deps and deps.gen2) and 2 or 1
end

-- The four readers behind the Tera and Dynamax fields.
--
-- Every one of them tolerates its dependency being absent and answers nil
-- rather than throwing, for the reason M.bind's own header gives: this module
-- is dofile()d bare by its own suite and by half a dozen others, and a payload
-- that raised an error inside a form change would take the form change with
-- it.  A missing field is a consumer reading nil; a raised error is a Pokemon
-- stuck mid-transformation.
--
-- THE DATASET IS REMEMBERED, not asked for.  teratype.of needs the merged
-- data (a species' own types, and the chart it filters them against) and the
-- mod api hands a mod no handle to it -- it arrives as an argument to the two
-- form primitives and on a battle.  So the last one seen is kept, and every
-- reader here falls back to it.  A consumer calling describe() from a party
-- screen before any battle has ever started gets nil for `teraType` rather
-- than a wrong answer, which is the honest failure: this mod genuinely does
-- not know a species' types until something has handed it the dataset.
local lastData = nil

local function teraTypeOf(mon, data)
  local teratype = deps and deps.teratype
  if not (teratype and mon and data) then return nil end
  local ok, id = pcall(teratype.of, data, mon)
  return ok and id or nil
end

local function dynamaxLevelOf(mon)
  local level = deps and deps.dynamaxlevel
  if not (level and mon) then return nil end
  local ok, value = pcall(level.of, mon)
  return ok and value or nil
end

-- `state.mon` is the identity check every mechanic in this mod already uses:
-- only the player's own side can transform here, so there is never a second
-- Terastallization or Dynamax to tell this one apart from.
local function teraStateOf(mon)
  local state = deps and deps.teraState
  if not (state and mon) or state.mon ~= mon then return nil end
  local stellar = deps.stellar
  return {
    -- The type it is terastallized INTO right now, which is not always the
    -- persistent one above: the TERA TYPE option can override every Pokemon
    -- with a single type for a battle (src/tera.lua's own chosenType).
    type = state.type,
    -- Broken out rather than left for a consumer to compare against a string:
    -- Stellar is the one Tera type that changes no typing at all, so a reader
    -- deciding whether to redraw a type badge needs to know without having to
    -- know why.
    stellar = stellar ~= nil and state.type == stellar.TYPE or false,
  }
end

local function dynamaxStateOf(mon)
  local state = deps and deps.dynamaxState
  if not (state and mon) or state.mon ~= mon then return nil end
  return {
    -- Turns left on the three-turn clock, counting the one it was armed on.
    turns = state.turns,
    -- The Gigantamax form record's own suffix, or nil for a plain Dynamax.
    -- A Gigantamax also fires form_applied; a plain one has no form at all,
    -- which is the whole distinction this field exists to carry.
    form = state.form,
  }
end

-- The one shape, built in one place, so the event payloads and describe()'s
-- own answer cannot drift into being two different things a consumer has to
-- tell apart.
--
-- `stats` is the block the Pokemon is FIGHTING with, which is not always the
-- block its HP bar is drawn from: neither primitive touches the bar's
-- denominator (a mega keeps the base form's HP in the real games), so on Gen
-- 1 the `hp` key here is the form record's own computed maximum and on Gen 2
-- there is no `hp` key written at all.  Documented rather than smoothed
-- over -- a consumer drawing a bar wants mon.stats.hp, and a consumer doing
-- damage math wants exactly what is here.
local function payload(event, fields)
  local mon = fields.mon
  -- Remembered here rather than at each call site, so every path that has a
  -- dataset feeds the ones that do not.
  if fields.data then lastData = fields.data end
  local data = fields.data or lastData
  return {
    api = M.API,
    event = event,
    generation = generation(),
    -- The live Pokemon, deliberately not a copy: it is the identity a
    -- consumer matches its own bookkeeping against, and there is no second
    -- table that would compare equal to the one the battle holds.
    mon = mon,
    -- Never moves for a form change -- the base species is what the sprite
    -- registry keys art under and what the engine draws the name from
    -- (src/forms.lua's own header).
    species = mon and mon.species or nil,
    -- What `mon.form` now is: the record's own suffix ("MEGA_X"), which is
    -- what a sprite mod resolves art from.  Present on a revert too, naming
    -- the form that was just taken OFF.
    form = fields.form,
    -- The National Dex record key the stats and types came from
    -- ("CHARIZARD_MEGA_X").  nil on a revert, where there is no record to
    -- name -- the Pokemon went back to its own species.
    formId = fields.formId,
    stats = copy(fields.stats),
    types = copy(fields.types),
    -- Gen 1 alone, and only because Gen 1 is the game that HAS a battler to
    -- read it off (src/battlerof.lua's own header: on Gen 2 the mon IS the
    -- battler and carries no side marker).  nil is "not known here", never
    -- "the enemy" -- a Gen 2 consumer holding the live battle can compare
    -- `battle.player == payload.mon` itself.
    isPlayer = fields.isPlayer,

    -- PERSISTENT, and the half worth having.  Both of these are properties of
    -- the Pokemon rather than of a battle, so they are answerable from a party
    -- screen, a PC box or a summary page with no fight in sight -- which is
    -- what a consumer drawing a stats row actually needs.  The live state
    -- below can only ever say something mid-battle.
    --
    -- `teraType` is the type this Pokemon WOULD terastallize into, whether or
    -- not it ever has: src/teratype.lua derives it from the Pokemon's own DVs
    -- unless shards have bought it something else.  Never nil for a Pokemon
    -- with a species record, which is why it is worth asking for.
    teraType = teraTypeOf(mon, data),
    -- 0-10 (src/dynamaxlevel.lua).  0 is a real answer -- an unfed Pokemon --
    -- and never "unknown".
    dynamaxLevel = dynamaxLevelOf(mon),

    -- LIVE, and nil when nothing is standing.  Present on every payload
    -- shape, including describe()'s, so one reader answers "is this Pokemon
    -- terastallized right now" without needing to have heard the event.
    tera = teraStateOf(mon),
    dynamax = dynamaxStateOf(mon),
  }
end

-- Logged once and then never again.  The only way an emit below can fail is
-- a name that does not carry the loader's required prefix, which is a
-- constant in this file -- so it either fails every single time or not at
-- all, and a per-form-change error line would bury the log of anyone with a
-- form-heavy party.
local complained = false

local function emit(name, body)
  local events = deps and deps.events
  if not events then return false end
  local ok, err = pcall(events.emit, events, name, body)
  if not ok then
    if not complained and deps.log then
      complained = true
      deps.log:error("battle_forms: %s could not be emitted (%s) -- nothing "
        .. "outside this mod will hear about form changes for the rest of "
        .. "this session", name, tostring(err))
    end
    return false
  end
  return true
end

-- Called by src/forms.lua and src/gen2forms.lua the instant a form is
-- actually standing -- after the stats and types are written, never before,
-- so a listener that reads straight off `payload.mon` sees the same world
-- the payload describes.
function M.applied(fields)
  if not (fields and fields.mon) then return false end
  return emit(M.APPLIED, payload("applied", fields))
end

-- The other half, from the same two files.  Fired once per Pokemon that
-- actually carried a form: both primitives refuse early on an unmarked mon,
-- which is what keeps the blunt battle-end party sweep (src/resolve.lua's
-- own settle) from announcing five Pokemon that never transformed.
function M.reverted(fields)
  if not (fields and fields.mon) then return false end
  return emit(M.REVERTED, payload("reverted", fields))
end

-- Terastallization and Dynamax, announced from their own mechanics rather
-- than from the form primitives -- they never reach those, which is the whole
-- reason these two pairs exist.
--
-- `fields.mon` alone is required.  Everything a consumer wants about the
-- transformation is read live off the state tables by the payload builder, so
-- a caller cannot announce something the state does not agree with: these are
-- called AFTER the state is set on the way in and BEFORE it is cleared on the
-- way out, and both `tera` and `dynamax` in the payload will be populated or
-- nil accordingly with no second copy of the truth to drift.
function M.tera(applied, fields)
  if not (fields and fields.mon) then return false end
  return emit(applied and M.TERA_APPLIED or M.TERA_REVERTED,
    payload(applied and "tera_applied" or "tera_reverted", fields))
end

function M.dynamax(applied, fields)
  if not (fields and fields.mon) then return false end
  return emit(applied and M.DYNAMAX_APPLIED or M.DYNAMAX_REVERTED,
    payload(applied and "dynamax_applied" or "dynamax_reverted", fields))
end

-- The call-style answer, and the export a peer actually holds.
--
-- `battler` is Gen 1's own wrapper and is optional there: with one, the
-- answer is what that battler is fighting with this instant (curStats/
-- curTypes, the fields a form change overrides); without one -- a party
-- screen, a PC box, anything outside a battle -- it falls back to the mon's
-- own block, which is what a Pokemon out of battle actually has.  Gen 2 has
-- no wrapper at all and ignores the argument: mon.stats and mon.formTypes
-- ARE the fields src/gen2forms.lua writes.
--
-- `formId` is asked of src/formresolve.lua rather than derived from
-- mon.form, which is the whole reason that file exists: a Pokemon freshly
-- handed a Rotom appliance on Gold is entitled to a form and still carries
-- mon.form == nil until its next battle applies it, and a reader that
-- gated on the marker would answer "no form" for a Pokemon whose party icon
-- is already drawing one.
function M.describe(mon, battler)
  if not mon then return nil end
  local stats, types, isPlayer
  if generation() == 2 then
    stats, types = mon.stats, mon.formTypes
  elseif battler and battler.mon == mon then
    stats, types, isPlayer = battler.curStats, battler.curTypes, battler.isPlayer
  else
    stats = mon.stats
  end
  return payload("state", {
    mon = mon,
    form = mon.form,
    formId = deps and deps.formresolve and deps.formresolve.formIdFor(mon) or nil,
    stats = stats,
    types = types,
    isPlayer = isPlayer,
  })
end

-- Publishes the exports table another mod reads through
-- `mod.find("battle_forms").exports`.
--
-- Every entry is a closure rather than the module function itself, and each
-- one tolerates being called with a colon: `exports:describe(mon)` hands the
-- exports table in as the first argument, and a peer author who writes it
-- that way is making an ordinary Lua mistake, not asking for a nil error
-- three frames deep inside this mod.  The loader's own `api.find` extends
-- exactly the same courtesy for the same reason.
function M.install(mod)
  local exports = mod and mod.exports
  if type(exports) ~= "table" then return false end

  local function shift(first, second)
    if first == exports then return second end
    return first
  end

  exports.api = M.API
  -- The event names, so a consumer subscribes to a value it was given
  -- rather than to a string it retyped.
  exports.events = {
    applied = M.APPLIED, reverted = M.REVERTED,
    teraApplied = M.TERA_APPLIED, teraReverted = M.TERA_REVERTED,
    dynamaxApplied = M.DYNAMAX_APPLIED, dynamaxReverted = M.DYNAMAX_REVERTED,
  }
  exports.describe = function(first, second, third)
    if first == exports then return M.describe(second, third) end
    return M.describe(first, second)
  end
  exports.formIdFor = function(first, second)
    local mon = shift(first, second)
    if not (mon and deps and deps.formresolve) then return nil end
    return deps.formresolve.formIdFor(mon)
  end

  -- Every manually activated transformation there is, as COPIED rows of
  -- { id, label, available }.
  --
  -- A peer drawing its own battle scene cannot use the cell this mod draws --
  -- that one is bolted to the native screen's own layout -- but it needs the
  -- same three facts that cell reads.  So it gets those three and not the
  -- registry, because the registry is not a read surface: Registry:register
  -- would let a peer add a transformation, and Registry:all() hands back the
  -- live list itself, whose ORDER is the order the player's menu cycles in
  -- (src/transforms.lua's own header).  Neither is a thing to hand out by
  -- accident.
  --
  -- `available` is RESOLVED here rather than passed out as the entry's own
  -- predicate.  That predicate closes over this mod's internals and expects
  -- the battle it is being asked about; handing the function to a peer means
  -- handing over something callable against anything.  Pass the battle, get
  -- booleans.  A predicate that raises answers false rather than taking the
  -- caller's scene down with it.
  exports.gimmicks = function(first, second)
    local battle = shift(first, second)
    local out = {}
    local registry = deps and deps.transforms
    if not registry then return out end
    for _, entry in ipairs(registry:all()) do
      local ok, available = pcall(entry.available, battle)
      out[#out + 1] = { id = entry.id, label = entry.label,
                        available = (ok and available) and true or false }
    end
    return out
  end

  -- Arms one of them, or disarms it again, exactly as the player's own cell
  -- does -- and deliberately NOT the entry's own activate().
  --
  -- activate is meant to run at battle.turn_started, where src/resolve.lua's
  -- M.onTurnStarted pairs it with state:consume(id).  That pairing is the ONE
  -- place the once-per-battle limit is recorded, so an external activate()
  -- performs the transformation and never spends the flag -- and the same
  -- trainer arms a second one, which is the single rule this registry exists
  -- to enforce.  Arming here leaves the activation to this mod's own
  -- turn_started listener, the same one every native battle already goes
  -- through.  toggle() also refuses an id already spent, so the limit holds
  -- on this path without a second copy of it living here.
  --
  -- Answers true when the id is now armed, false when it was disarmed, was
  -- refused, or names nothing.
  exports.arm = function(first, second)
    local id = shift(first, second)
    local state = deps and deps.armState
    local registry = deps and deps.transforms
    if not (state and type(id) == "string") then return false end
    -- Refused HERE, and the registry check is not redundant: State:toggle
    -- validates the id's type and its spent flag but never asks whether
    -- anything registered it, because every internal caller took the id off
    -- the cell it was already drawing.  arm() is the one door an id can
    -- arrive through from outside, so it is the one place that has to ask.
    -- Without it a peer's typo arms a cell that can never fire: the id sticks
    -- in armedId, and src/resolve.lua's onTurnStarted resolves it to nil and
    -- quietly does nothing, every turn, for the rest of the battle.
    if not (registry and registry:get(id)) then return false end
    return state:toggle(id) == true
  end

  -- The id currently armed, or nil.  For a scene redrawing its own button.
  exports.armed = function()
    local state = deps and deps.armState
    if not state then return nil end
    return state:armed()
  end
  return true
end

return M
