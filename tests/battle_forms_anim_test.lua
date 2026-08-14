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

-- The Max Move sequences hold to the same rule, and one more of their own: a
-- registry keeps what it is handed, and these are handed out over a hundred
-- times, so each call has to return a table of its own rather than one shared
-- sequence every Max Move record could be mutated through.
for label, build in pairs({ ["Max Move"] = Anim.maxMoveSeq,
                            ["Max Guard"] = Anim.maxGuardSeq }) do
  local first, second = build(), build()
  T.check(#first > 0, label .. "'s sequence has rows")
  T.check(first ~= second, label .. "'s sequence is a fresh table per call")
  local clean = true
  for _, row in ipairs(first) do
    if row.effect == nil or row.subanim ~= nil or row.tileset ~= nil then
      clean = false
    end
  end
  T.check(clean, "every " .. label .. " row is a screen effect needing no art")
end

-- The sound rows name MOVES whose sound to borrow, which is how the engine's
-- own animations carry sound; a row inventing one would mean shipping audio.
local sounds = 0
for _, row in ipairs(Anim.maxMoveSeq()) do
  if row.sound then
    sounds = sounds + 1
    T.eq(type(row.sound), "string", "a sound row names a move id")
  end
end
T.check(sounds > 0,
  "a Max Move makes a noise -- the row sounds are the only ones it gets, "
    .. "because the engine skips its single-sound fallback once an animation "
    .. "has started")

T.finish("battle_forms_anim")
