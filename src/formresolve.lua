-- The one place "what form should this mon actually be wearing, right now"
-- is decided from something other than mon.form itself.
--
-- Fusion asked first, persistent second -- the identical order
-- src/resolve.lua's own settle() asks them in, for the identical reason:
-- no species is both a fusion base and a persistent-form holder, so the
-- order can never actually decide an outcome by itself.  Asking the
-- stronger claim (a fusion, which stands a second Pokemon in the PC) first
-- is the order to be wrong in if that assumption ever stops holding.
--
-- WHY THIS FILE EXISTS, AND WHY EVERY OUT-OF-BATTLE READER SHOULD CALL IT
-- RATHER THAN KEEP ITS OWN COPY.  src/formicons.lua, src/formview.lua and
-- src/gen2formview.lua each built the identical two-line fusion-then-
-- persistent chain independently before this file existed, and one of the
-- three (src/formview.lua) built it WITH a `not mon.form` early exit that
-- is only safe on the game it was written for: Gen 1 writes mon.form
-- synchronously with the bag-use stamp (src/persistent.lua's own M.mark
-- runs inside that same closure), so a nil mon.form really does mean
-- neither mechanic has anything to say there.  Gen 2 has no such
-- guarantee -- src/persistent.lua's own M.formIdFor reads mon.item, the
-- real held-item slot src/ui/gen2/HeldItemMenu.lua's GIVE writes directly,
-- with NO event this mod can hook (src/persistent.lua's own header) -- so a
-- mon can be freshly GIVEn an appliance, genuinely entitled to a form, and
-- still show mon.form == nil until its next battle applies it.  A reader
-- that gates on mon.form the way Gen 1's safely could is exactly the bug
-- this file exists to stop from being reintroduced: the party screen (or
-- the PC, or any future reader) showing a persistent-form Pokemon's BASE
-- picture until it has been thrown into one battle, then correct forever
-- after -- correct in battle, correct after the battle-end sweep re-derives
-- it, wrong only in the gap before the very first fight since the item was
-- handed over.  Kyurem (a fusion, whose marker src/fusion.lua writes
-- DURABLY at fuse time -- a real save write, not a derived-per-draw
-- answer) never shows this gap, which is why a report of this shape can
-- name one species working and another not without either mechanic's own
-- code actually differing in the way that matters.
--
-- So this module NEVER gates on mon.form, on either game: fusion and
-- persistent are each asked fresh, every time, the way src/gen2formview.lua
-- and src/formicons.lua already reasoned their own copies had to.  On Gen 1
-- that costs two cheap table lookups instead of one nil check for a mon
-- that carries no form at all -- src/persistent.lua's own Gen 1 branch of
-- M.formIdFor reads the bag stamp directly, always in lockstep with
-- mon.form there, so the answer can never differ from what the old gated
-- version returned -- and buys the one thing that matters: no reader can
-- ever again copy Gen 1's short-circuit onto a Gen 2 screen by accident.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The National Dex record key `mon` is entitled to wear right now, asked
-- fresh from the mon's own held item or stamp rather than trusted off
-- mon.form -- see this file's own header for why that distinction is the
-- whole point.  Answers nil for a mon carrying neither claim, a nil mon,
-- or a build with neither src/fusion.lua nor src/persistent.lua bound
-- (the unit suites for callers that only exercise one of the two).
function M.formIdFor(mon)
  if not mon then return nil end
  local id = deps and deps.fusion and deps.fusion.formIdFor(mon)
  if id then return id end
  return deps and deps.persistent and deps.persistent.formIdFor(mon)
end

return M
