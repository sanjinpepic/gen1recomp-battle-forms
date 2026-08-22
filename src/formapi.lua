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

local deps = nil

-- `events` (mod.events), `log` (mod.log), `gen2` (the boot's own flag, so a
-- payload can say which generation's stat keys it is carrying) and
-- `formresolve` (src/formresolve.lua, for the out-of-battle half of
-- describe()).  Every one of them is optional at the point of use: this
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
  exports.events = { applied = M.APPLIED, reverted = M.REVERTED }
  exports.describe = function(first, second, third)
    if first == exports then return M.describe(second, third) end
    return M.describe(first, second)
  end
  exports.formIdFor = function(first, second)
    local mon = shift(first, second)
    if not (mon and deps and deps.formresolve) then return nil end
    return deps.formresolve.formIdFor(mon)
  end
  return true
end

return M
