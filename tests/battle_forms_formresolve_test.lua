-- The shared fusion-then-persistent resolver src/formicons.lua,
-- src/formview.lua and src/gen2formview.lua all call now, rather than each
-- keeping its own copy of the chain. Three things this suite has to prove:
-- fusion is asked before persistent, NEITHER is ever gated on mon.form (the
-- whole reason this file exists -- see its own header), and a mon claimed
-- by neither answers nil rather than throwing.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD = arg[0]:gsub("[/\\]tests[/\\][^/\\]+$", "")
local Resolve = dofile(MOD .. "/src/formresolve.lua")
local Persistent = dofile(MOD .. "/src/persistent.lua")
local Fusion = dofile(MOD .. "/src/fusion.lua")
local Eligibility = dofile(MOD .. "/src/eligibility.lua")

local persistentRows = dofile(MOD .. "/data/persistent.lua")
local fusionRows = dofile(MOD .. "/data/fusion.lua")

-- ---------------------------------------------------------------------
-- No mon, or no resolvers bound at all: nil, not a throw.
-- ---------------------------------------------------------------------
T.eq(Resolve.formIdFor(nil), nil, "no mon at all resolves nothing")

do
  Resolve.bind({})
  T.eq(Resolve.formIdFor({ species = "ROTOM" }), nil,
    "neither fusion nor persistent bound answers nil rather than throwing")
end

-- ---------------------------------------------------------------------
-- Persistent alone: derives from the held item / stamp, never from
-- mon.form -- the exact property src/formview.lua's own gated copy did NOT
-- have, and the property this file exists to guarantee on every reader.
-- ---------------------------------------------------------------------
do
  Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
  Resolve.bind({ persistent = Persistent })

  local mon = { species = "ROTOM", [Eligibility.STAMP] = "WASHING_MACHINE" }
  T.eq(Resolve.formIdFor(mon), persistentRows.ROTOM.WASHING_MACHINE,
    "a stamped mon resolves through persistent with mon.form entirely absent")

  mon.form = nil
  T.eq(Resolve.formIdFor(mon), persistentRows.ROTOM.WASHING_MACHINE,
    "explicitly nil mon.form changes nothing -- there is no gate to trip")

  local unstamped = { species = "ROTOM" }
  T.eq(Resolve.formIdFor(unstamped), nil,
    "a mon holding nothing this table pairs resolves to nothing")
end

-- ---------------------------------------------------------------------
-- Gen 2: persistent's own mon.item read, asked through the identical
-- shared path -- the case the player's own report was about, and the one
-- src/persistent.lua's header says GIVE writes with no event this mod can
-- hook, so mon.form can lag it by a whole battle.
-- ---------------------------------------------------------------------
do
  Persistent.bind({ eligibility = Eligibility, rows = persistentRows, gen2 = true })
  Resolve.bind({ persistent = Persistent })

  -- Freshly GIVEn: mon.item names the appliance, mon.form is nil because no
  -- battle has applied it yet. This is the exact gap the bug report
  -- described, and the exact case a gate on mon.form would still fail.
  local freshlyGiven = { species = "ROTOM", item = "WASHING_MACHINE" }
  T.eq(Resolve.formIdFor(freshlyGiven), persistentRows.ROTOM.WASHING_MACHINE,
    "a freshly-GIVEn Gen 2 item resolves immediately, with mon.form still nil")

  Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
end

-- ---------------------------------------------------------------------
-- Fusion alone.
-- ---------------------------------------------------------------------
do
  Fusion.bind({ rows = fusionRows })
  Resolve.bind({ fusion = Fusion })

  local kyurem = { species = "KYUREM", [Fusion.STAMP] = "RESHIRAM" }
  local expected = fusionRows.KYUREM.DNA_SPLICERS.RESHIRAM
  T.check(expected ~= nil, "precondition: the real fusion table pairs this")
  T.eq(Resolve.formIdFor(kyurem), expected,
    "a fused mon resolves through fusion, mon.form untouched")

  local unfused = { species = "KYUREM" }
  T.eq(Resolve.formIdFor(unfused), nil, "an unfused Kyurem resolves to nothing")
end

-- ---------------------------------------------------------------------
-- Both bound: fusion wins, matching src/resolve.lua's own settle() order --
-- proven with a species stamped for BOTH, which cannot happen in the real
-- data (no species is both a fusion base and a persistent-form holder) but
-- pins the ORDER itself rather than trusting that the data never collides.
-- ---------------------------------------------------------------------
do
  Persistent.bind({ eligibility = Eligibility, rows = persistentRows })
  Fusion.bind({ rows = fusionRows })
  Resolve.bind({ fusion = Fusion, persistent = Persistent })

  local both = { species = "KYUREM", [Fusion.STAMP] = "RESHIRAM",
                 [Eligibility.STAMP] = "WASHING_MACHINE" }
  T.eq(Resolve.formIdFor(both), fusionRows.KYUREM.DNA_SPLICERS.RESHIRAM,
    "fusion is asked first and wins when (artificially) both could answer")

  -- A mon neither claims falls through both cleanly.
  T.eq(Resolve.formIdFor({ species = "PIDGEY" }), nil,
    "a mon neither mechanic has anything to say about resolves to nothing")
end

T.finish("battle_forms_formresolve")
