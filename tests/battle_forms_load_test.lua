-- Proves the mod loads clean. Deliberately thin: every later suite asserts
-- behaviour, and this one exists only so a broken manifest or a syntax error
-- in main.lua fails here rather than somewhere confusing.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local function readFile(path)
  local handle = assert(io.open(path, "rb"), "cannot open " .. path)
  local body = handle:read("*a")
  handle:close()
  return body
end

-- battle_forms declares national_dex as a hard dependency (a later task
-- reads its species records), and Loader:_enforceDependencies runs BEFORE
-- any entry file is compiled -- with no mod answering that id, main.lua
-- would never even be loaded, and a syntax error in it would sail through
-- silently.  The real national_dex mod is heavyweight and needs specific
-- options set just to load without its own unrelated warnings, so a stub
-- satisfies the dependency graph without dragging that in: this suite only
-- has to prove battle_forms's own manifest and main.lua are sound, and a
-- synthesized filesystem (Sdk.memfs) is the harness's own seam for that.
local files = {
  ["mods/battle_forms_mod/manifest.json"] = readFile(MOD .. "/manifest.json"),
  ["mods/battle_forms_mod/main.lua"] = readFile(MOD .. "/main.lua"),
  ["mods/national_dex/manifest.json"] =
    '{"id":"national_dex","name":"National Dex","version":"0.0.0","entry":"main.lua"}',
  ["mods/national_dex/main.lua"] = "return function() end",
}

local run = T.sdk.loadMods({ "battle_forms_mod", "national_dex" }, {
  fs = T.sdk.memfs(files),
  data = T.fixtures.fresh(),
})

T.eq(#run.errors, 0, "mod loads without errors")

-- #errors == 0 alone passes vacuously if discovery found nothing at all.
-- Pin down that battle_forms specifically was found, matches its own
-- manifest id, and was not marked failed by any earlier phase.
local mod = run.mods.battle_forms
T.check(mod ~= nil, "battle_forms was discovered")
T.eq(mod and mod.manifest.id, "battle_forms", "manifest id matches")
T.check(mod and not mod.failed, "battle_forms did not fail to load")

-- The MEGA EVOLUTIONS option is declared before any sibling is read, so it
-- reaches the launcher's settings screen even on the degraded load this
-- synthesized filesystem produces.  OFFICIAL is the default a fresh install
-- gets: the megas the real games have, with the rest opt-in.
local schema = run.loader.optionSchemas.battle_forms
local megasRow
for _, row in ipairs(schema or {}) do
  if row.key == "megas" then megasRow = row end
end
T.check(megasRow ~= nil, "the megas option is defined")
T.eq(megasRow and megasRow.default, "official", "it defaults to OFFICIAL")
T.eq(megasRow and megasRow.choices and #megasRow.choices, 2,
  "it offers exactly two choices")
T.eq(megasRow and megasRow.choices and megasRow.choices[1][2], "official",
  "OFFICIAL is the first choice")
T.eq(megasRow and megasRow.choices and megasRow.choices[2][2], "all",
  "ALL is the second")

-- DEBUG TRACE reaches the same screen and must default to off there, not
-- merely be documented as off: it is the switch a player is told to flip when
-- something has gone wrong, and it costs nothing only while nobody has.
local traceRow
for _, row in ipairs(schema or {}) do
  if row.key == "debug_trace" then traceRow = row end
end
T.check(traceRow ~= nil, "the debug_trace option is defined")
T.eq(traceRow and traceRow.default, "off", "it defaults to off")
T.eq(traceRow and traceRow.choices and traceRow.choices[1][2], "off",
  "OFF is the first choice")
T.eq(traceRow and traceRow.choices and traceRow.choices[2][2], "on",
  "ON is the second")

T.finish("battle_forms_load")
