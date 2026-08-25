-- The Terastallization readout, and the three ways it must refuse to draw.
--
-- Built the way src/hpscale.lua's own Dynamax readout is -- battle.overlay,
-- draw-only, after the engine has composited the real HUD -- so this suite is
-- shaped like that one's: the DECISION (what tag, and may it be drawn at all)
-- is tested without a graphics context, because a decision made inside a draw
-- function is one that cannot be tested at all.
--
-- The refusals matter more than the drawing.  This paints over the slot the
-- engines print the LEVEL in, and both of them already hand that slot to a
-- status tag when a Pokemon is poisoned or burned.  Painting a Tera tag over a
-- status the engine just decided to show would trade a piece of information a
-- player needs THIS turn for one they can look up.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")

local View = dofile(MOD .. "/src/teraview.lua")
local Tera = dofile(MOD .. "/src/tera.lua")
local Stellar = dofile(MOD .. "/src/stellar.lua")
local TeraBlast = dofile(MOD .. "/data/terablast.lua")

-- --- every type this mod can terastallize into has a code ----------------
-- data/terablast.lua is the list src/tera.lua and src/terashards.lua both
-- drive off, so a type that can be reached but has no code here would be a
-- Terastallization that draws nothing with no way to tell it apart from one
-- that was refused.
for _, typeId in ipairs(TeraBlast) do
  local code = View.codeFor(typeId)
  T.check(code ~= nil, typeId .. " has a tag")
  T.eq(#code, 3, typeId .. "'s tag is three characters, the slot's own width")
end
T.check(View.codeFor(Stellar.TYPE) ~= nil,
  "and so does Stellar, which is not in that list")

-- Distinct, because two types sharing a tag is a readout that lies.
local seen = {}
for typeId, code in pairs(View.CODES) do
  T.eq(seen[code], nil,
    code .. " is used by exactly one type (" .. typeId .. " collides)")
  seen[code] = typeId
end
-- The one pairing worth naming: Steel and Stellar both start STL-ish, and the
-- slot is the only place either is ever shown.
T.check(View.CODES.STEEL ~= View.CODES.STELLAR,
  "Steel and Stellar do not share a tag")

-- An unknown type draws nothing rather than a truncated guess -- another mod
-- may register a type this table has never heard of.
T.eq(View.codeFor("MYSTERY"), nil, "an unknown type has no tag")
T.eq(View.codeFor(nil), nil, "and neither does no type")

-- --- the tag follows the live state, not the Pokemon ---------------------
local mon, other = { species = "CHARIZARD" }, { species = "PIKACHU" }
local state = { mon = nil, type = nil }
T.eq(View.tagFor(state, mon), nil, "nothing is drawn with no Tera standing")

state.mon, state.type = mon, "WATER"
T.eq(View.tagFor(state, mon), "WTR", "the terastallized Pokemon gets its tag")
T.eq(View.tagFor(state, other), nil, "and no other Pokemon does")
T.eq(View.tagFor(state, nil), nil, "and no Pokemon at all gets nothing")

state.type = Stellar.TYPE
T.eq(View.tagFor(state, mon), "STR", "a Stellar Terastallization is shown too")

-- --- Gen 1: the three refusals -------------------------------------------
local function battle(overrides)
  local b = {
    player = { mon = mon, shownStatus = nil },
    safari = false, demo = false, showPlayerBack = false, introSlide = 0,
    statusHUDVisible = function() return true end,
    wideLayout = function() return false end,
  }
  for k, v in pairs(overrides or {}) do b[k] = v end
  return b
end

T.eq(View.visible(battle()), true, "an ordinary player HUD is drawn over")

-- STATUS WINS.  The engine has already given this slot to the status tag.
local statused = battle()
statused.player.shownStatus = "PSN"
T.eq(View.visible(statused), false,
  "a statused Pokemon keeps its status tag -- the Tera tag stands down")

for _, case in ipairs({
  { field = "safari", value = true, why = "the Safari HUD has no level slot" },
  { field = "demo", value = true, why = "the demo battle draws no player HUD" },
  { field = "showPlayerBack", value = true, why = "the back-pic view has none" },
  { field = "introSlide", value = 1, why = "the HUD is still sliding in" },
}) do
  T.eq(View.visible(battle({ [case.field] = case.value })), false, case.why)
end
T.eq(View.visible(battle({ statusHUDVisible = function() return false end })),
  false, "and a hidden status HUD is not painted over")
T.eq(View.visible(nil), false, "no battle, nothing drawn")
T.eq(View.visible({ }), false, "and no player either")

-- --- Gen 2: the same refusals, through the UI screen's own methods -------
local function uiBattle(overrides)
  local u = {
    battle = { player = mon },
    showPlayerHud = true,
    statusHUDVisible = function() return true end,
    hudCleared = function() return false end,
    statusTag = function() return nil end,
  }
  for k, v in pairs(overrides or {}) do u[k] = v end
  return u
end

T.eq(View.gen2Visible(uiBattle()), true, "Gold's ordinary player HUD qualifies")
T.eq(View.gen2Visible(uiBattle({ statusTag = function() return "PSN" end })),
  false, "Gold's status tag wins the slot the same way Gen 1's does")
T.eq(View.gen2Visible(uiBattle({ showPlayerHud = false })), false,
  "a hidden player HUD is not painted over")
T.eq(View.gen2Visible(uiBattle({ hudCleared = function() return true end })),
  false, "nor a cleared one")
T.eq(View.gen2Visible(uiBattle({ statusHUDVisible = function() return false end })),
  false, "nor an invisible status HUD")
T.eq(View.gen2Visible(nil), false, "and no screen draws nothing")

-- A reshaped screen missing one of those methods degrades to painting nothing
-- rather than taking the draw frame down.
T.eq(View.gen2Visible({ battle = { player = mon }, showPlayerHud = true }),
  false, "a screen with no statusHUDVisible is refused, not crashed on")

-- --- the draw itself is guarded before it ever reaches love.graphics -----
-- No graphics context here, so reaching a real paint would throw; these pass
-- precisely because every one of them is refused first.
state.mon, state.type = mon, "WATER"
View.draw(state, battle({ safari = true }))
View.draw(state, nil)
View.draw({ mon = nil }, battle())
View.drawGen2(state, uiBattle({ showPlayerHud = false }))
View.drawGen2(state, nil)
T.check(true, "every refused path returns before touching a draw call")

-- --- install composes rather than replaces -------------------------------
local ran, wrapped = false, nil
local fakeMod = { hooks = { wrap = function(_, name, fn)
  wrapped = name
  fn(function() ran = true end, battle({ safari = true }))
end } }
View.install(fakeMod, state, false)
T.eq(wrapped, "battle.overlay", "it wraps the draw-only overlay seam")
T.eq(ran, true,
  "and calls the rest of the chain FIRST and unconditionally, so another "
    .. "mod's overlay runs whether or not a Tera is live")

-- --- one slot, five transformations -----------------------------------------
-- A Dynamax has no picture of its own and Red has no draw-time scaling seam at
-- all, so a Dynamaxed Pokemon there stands in its unchanged shape and nothing
-- said it still was one once the message scrolled. Every transformation now
-- wears a three-letter tag in the level slot instead. They can never contend
-- for it: the trainer's once-per-battle rule means a Pokemon wears one.
local MEGAS = { CHARIZARD = { CHARIZARDITE_X = "CHARIZARD_MEGA_X" },
                GENGAR = { GENGARITE = "GENGAR_MEGA" } }
local who = { species = "GENGAR" }

T.eq(View.gimmickTagFor({ dynamax = { mon = who } }, who), "DYN",
  "a plain Dynamax says DYN")
T.eq(View.gimmickTagFor({ dynamax = { mon = who, form = "GENGAR_GMAX" } }, who),
  "GMX", "a Gigantamax says GMX -- it IS a different shape and the player can see it")
T.eq(View.gimmickTagFor({ zmove = { mon = who } }, who), "ZMV", "a Z-Move says ZMV")
T.eq(View.gimmickTagFor({ megas = MEGAS },
  { species = "GENGAR", form = "GENGAR_MEGA" }), "MEG", "a mega says MEG")

-- A mega is told from every OTHER form by the pairing table that defines them,
-- never by the form field being set: a Gigantamax, a persistent held-item form
-- and a condition-driven form all set that same field.
T.eq(View.gimmickTagFor({ megas = MEGAS },
  { species = "GIRATINA", form = "GIRATINA_ORIGIN" }), nil,
  "a persistent form is not a mega and wears no tag")
T.eq(View.gimmickTagFor({ megas = MEGAS }, { species = "GENGAR" }), nil,
  "and an untransformed Pokemon wears none either")

-- A Terastallization still wins the slot, since its tag says more than "MEG"
-- would: it names the type.
local teraState = { mon = who, type = "DRAGON" }
T.eq(View.gimmickTagFor({ tera = teraState, dynamax = { mon = who } }, who), "DRG",
  "the Tera type beats the generic tag")

-- Lists work the same as single states, both spellings being live.
T.eq(View.gimmickTagFor({ dynamax = { { mon = {} }, { mon = who } } }, who), "DYN",
  "a list of states resolves the one that claims this Pokemon")
T.eq(View.gimmickTagFor({}, who), nil, "no sources, no tag")
T.eq(View.gimmickTagFor(nil, who), nil, "and none at all")
T.eq(View.gimmickTagFor({ dynamax = { mon = who } }, nil), nil, "and no mon")

T.finish("battle_forms_teraview")
