package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Anim = dofile(MOD .. "/src/anim.lua")

local registered = {}
local mod = { content = { battle_anims = {
  register = function(_, id, record) registered[id] = record end,
} } }

Anim.install(mod)

local record = registered[Anim.ID]
T.check(record ~= nil, "the form-change animation is registered")
T.check(type(record.seq) == "table", "it carries a seq")
T.check(#record.seq > 0, "the seq has at least one row")

-- Effect-only rows need no tilesheet and no subanimation, which is what lets
-- this ship without art.  A row carrying a subanim would silently no-op for
-- anyone who has not also been given the art.
local allEffects = true
for _, row in ipairs(record.seq) do
  if row.effect == nil or row.subanim ~= nil or row.tileset ~= nil then
    allEffects = false
  end
end
T.check(allEffects, "every row is a screen effect needing no custom art")

T.finish("battle_forms_anim")
