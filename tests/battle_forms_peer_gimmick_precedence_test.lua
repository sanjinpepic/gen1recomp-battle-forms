-- Load-order precedence against another mod that patches the same shared
-- engine classes battle_forms's own Dynamax/Gigantamax/Mega/Z-Move/Tera code
-- does. Not this project's own mod: any third-party GAMEPLAY mod on this
-- engine that declares the manifest id below, ships its own version of one
-- of those five gimmicks, and monkeypatches the same class methods rather
-- than composing through a Hooks chain -- direct class patches are last-
-- writer-wins-outermost, so whichever mod's entry chunk runs LAST ends up
-- wrapping the OTHER mod's own wrap, and gets first refusal on every call.
--
-- battle_forms wants to be that outermost wrap when this specific peer is
-- present, so its own state-gated checks (is THIS mon under battle_forms's
-- own Dynamax, Mega, ...?) run before the peer's, and correctly fall through
-- to the peer's own answer only when battle_forms has nothing to say. The
-- manifest's own `optional_dependencies` entry for this id is the whole
-- fix: an optional dependency orders a mod after the id it names WHEN THAT
-- ID IS PRESENT, and does nothing at all otherwise (Loader.lua's own
-- Kahn-order edge() plus Manifest.lua's optionalSpecs parse, both read
-- directly against this checkout's source before writing this suite).
--
-- The peer here is entirely synthesized (memfs, no real third-party source
-- anywhere in this file or this repo) -- this suite proves the ENGINE
-- MECHANISM and battle_forms's own manifest entry, not any specific other
-- mod's behavior, and needs nothing installed on this machine to run.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local function readFile(path)
  local handle = assert(io.open(path, "rb"), "cannot open " .. path)
  local body = handle:read("*a")
  handle:close()
  return body
end

-- A bare functional string -- the manifest id battle_forms's own
-- optional_dependencies entry matches on -- not a reference to any mod's
-- source or a hint at where to find one (CLAUDE.md's own carve-out for a
-- "mod id the code matches on").
local PEER_ID = "g9-battle-engine"

local function baseFiles()
  return {
    ["mods/battle_forms_mod/manifest.json"] = readFile(MOD .. "/manifest.json"),
    ["mods/battle_forms_mod/main.lua"] = readFile(MOD .. "/main.lua"),
    ["mods/national_dex/manifest.json"] =
      '{"id":"national_dex","name":"National Dex","version":"0.0.0",'
        .. '"entry":"main.lua","games":["gen1","gen2"]}',
    ["mods/national_dex/main.lua"] = "return function() end",
  }
end

-- priority 100: higher than battle_forms's own 80, matching the real peer
-- manifest this id belongs to -- without the optional_dependencies edge,
-- Loader:_order's own tie-break (lower priority number goes first among
-- ready nodes) would place battle_forms BEFORE this id, which is exactly
-- the bug: battle_forms's own direct class patches would end up wrapped
-- INSIDE this mod's, not outside it.
local PEER_MANIFEST = ([[{
  "id": "%s", "name": "Peer Gimmick Mod", "version": "1.0.0",
  "entry": "main.lua", "api": 2, "priority": 100,
  "games": ["gen2"], "dependencies": ["national_dex"]
}]]):format(PEER_ID)

local function orderIndex(order, id)
  for i, v in ipairs(order or {}) do
    if v == id then return i end
  end
  return nil
end

-- ---------------------------------------------------------------------
-- Case 1: the peer is present, on the generation it (and Gold) share.
-- ---------------------------------------------------------------------
local files1 = baseFiles()
files1["mods/peer/manifest.json"] = PEER_MANIFEST
files1["mods/peer/main.lua"] = "return function() end"

local run1 = T.sdk.loadMods({ "battle_forms_mod", "national_dex", "peer" }, {
  fs = T.sdk.memfs(files1), data = T.fixtures.fresh(), generation = 2,
})
local bfIndex1 = orderIndex(run1.loader.order, "battle_forms")
local peerIndex1 = orderIndex(run1.loader.order, PEER_ID)
T.check(bfIndex1 ~= nil, "battle_forms is in the load order at all")
T.check(peerIndex1 ~= nil, "the peer mod is in the load order at all")
T.check(bfIndex1 ~= nil and peerIndex1 ~= nil and bfIndex1 > peerIndex1,
  "battle_forms loads AFTER the peer mod when it is present, so battle_forms's "
    .. "own direct class patches sit outermost and decide whether to call "
    .. "inward -- got battle_forms at position "
    .. tostring(bfIndex1) .. ", peer at " .. tostring(peerIndex1))

-- ---------------------------------------------------------------------
-- Case 2: the peer is entirely absent -- the whole point of an optional
-- dependency, and the load this checkout's players overwhelmingly run.
-- battle_forms's own position relative to national_dex must be byte-
-- identical to a world where this manifest entry never existed.
-- ---------------------------------------------------------------------
local files2 = baseFiles()
local run2 = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
  fs = T.sdk.memfs(files2), data = T.fixtures.fresh(), generation = 2,
})
T.eq(#(run2.loader.order or {}), 2,
  "only the two real mods load when no peer mod is present")
T.eq(run2.loader.order[1], "national_dex",
  "national_dex still loads first -- it is battle_forms's own hard "
    .. "dependency, unrelated to the optional entry")
T.eq(run2.loader.order[2], "battle_forms",
  "battle_forms follows exactly as it would if the optional_dependencies "
    .. "entry for an absent peer had never been added")

-- ---------------------------------------------------------------------
-- Case 3: the peer is present but targets a generation this boot is not
-- running -- Loader:_gateGeneration skips it before _order ever runs, so
-- the optional_dependencies edge has nothing to attach to and the graph is
-- exactly Case 2's, not a broken or a silently-reordered one.
-- ---------------------------------------------------------------------
local files3 = baseFiles()
files3["mods/peer/manifest.json"] = PEER_MANIFEST
files3["mods/peer/main.lua"] = "return function() end"
local run3 = T.sdk.loadMods({ "battle_forms_mod", "national_dex", "peer" }, {
  fs = T.sdk.memfs(files3), data = T.fixtures.fresh(), generation = 1,
})
T.check(orderIndex(run3.loader.order, PEER_ID) == nil,
  "the peer mod itself never activates on a generation its own manifest "
    .. "does not claim, regardless of who names it optionally")
T.eq(#(run3.loader.order or {}), 2,
  "battle_forms and national_dex load exactly as if the peer mod's files "
    .. "were never on disk at all")

T.finish("battle_forms_peer_gimmick_precedence")
