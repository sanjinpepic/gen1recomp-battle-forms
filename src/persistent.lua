-- The first form change here that outlives the battle it happened in, and the
-- first thing this mod deliberately writes into a player's save.
--
-- WHAT IS WRITTEN, which is the decision worth reading.
--
-- Two string fields on the party mon's own table and nothing else.  The item is
-- stamped through src/eligibility.lua's existing STAMP -- the field the mega
-- stones, the orbs and the Z-Crystals have always used -- and `mon.form` is set
-- beside it so the marker is right while the mon is standing in the party menu
-- rather than only while it is standing on a battlefield.  mon.species is not
-- touched, mon.stats is not touched, mon.moves is not touched, mon.hp is not
-- touched.
--
-- Each of those four is a refusal with a reason.  Re-keying the species would
-- put a form id in a field src/core/SaveData.lua's validate() checks against
-- data.pokemon and quarantines the whole mon for missing -- so a save opened
-- once without this mod would move the Pokemon to the LOST box.  Writing
-- mon.stats is the hazard src/dynamax.lua declines at length: the party menu
-- and the summary screen read that block directly, nothing recomputes it on
-- load, and Experience.lua replaces it wholesale from the BASE species record
-- on any level-up -- so a form's stats written there would be silently undone
-- by the next level and could not be told from honest growth in the meantime.
--
-- WHICH FIELD IS THE TRUTH.  The stamp is; `mon.form` is derived from it.  That
-- is not a detail, it is the whole safety argument: the marker is the field
-- every battle mechanic in this mod writes to, so a marker that could not be
-- re-derived would be a marker a bug could quietly turn into something else and
-- then save.  Because it can be re-derived, the battle-end sweep does not have
-- to tell a persistent form from a battle one at all -- it asks this table what
-- the mon is entitled to and writes that, and anything a battle put there is
-- gone by construction.  See M.settle below and src/resolve.lua.
--
-- WHAT A GAME BOY .sav EXPORT DOES TO THIS.  Loses it, both halves, and that is
-- the best outcome available rather than a gap.  GenSave.lua decodes and
-- re-encodes a byte-exact 44-byte party struct with every offset spoken for and
-- no hook of any kind, so neither field can survive a round trip -- but neither
-- can be half-lost either, because the marker is worthless without the stamp
-- and this module refuses to honour one without the other.  A Rotom-Wash
-- exported to a cartridge save comes back a plain Rotom that has forgotten
-- which appliance it was in.  It cannot come back as a different species,
-- because the species was never written; it cannot come back holding a form's
-- stats, because the stats were never written.  The ceiling on the damage is
-- "use the appliance again", and that is a property of what is written rather
-- than of a check that could be forgotten.
--
-- GEN 2 HAS A REAL HELD-ITEM SLOT, AND ON THAT GAME IT IS THE ONLY TRIGGER.
-- Everything above is Gen 1's story: that game has no held-item slot, so the
-- bag-use stamp was the only field available and remains it there, unchanged
-- by anything below. Gold's own mon.item is the field GIVE
-- (src/ui/gen2/HeldItemMenu.lua) writes and TAKE clears, the same one
-- src/battle/gen2/Battle.lua already reads for LUCKY_EGG, EXP_SHARE and
-- EVERSTONE -- so M.formIdFor reads it too, and on Gen 2 it is asked FIRST
-- (see that function's own header for the precedence and why). The bag "use"
-- path this file still builds for Gen 1 is deliberately NOT offered on Gen 2
-- at all -- M.install's item record carries fieldMenu/battleMenu =
-- "ITEMMENU_NOUSE", so Gold's own PACK never shows a USE verb for one of
-- these items, GIVE and TOSS only, matching every held item the real games
-- already ship (Leftovers, the Exp. Share, ...). That is also the faithful
-- answer independent of the bug that made it necessary: confirmed against a
-- real Gold boot, pressing USE on one of these items reached
-- Game2:usePartyItem, whose own call to ItemEffects.partyAction(itemId)
-- passes no `data` argument, so it can only ever consult the engine's
-- built-in item_effects table and never a mod's merged one -- every mod's
-- Gen 2 field item is unreachable through that path today, not just this
-- one, and fixing it would mean patching engine dispatch logic this mod
-- has no seam for. Taking the verb off the screen is the fix this mod can
-- make; M.install's own item_effects registration still builds a
-- correctly-shaped Gen 2 record regardless (see M.install's own header),
-- so nothing here needs a second change if either gap ever closes upstream.
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The National Dex record key this mon is entitled to, or nil.  One lookup,
-- in one place, so the item effect, the send-out handler and the party sweep
-- can never disagree about what a mon is.
--
-- On Gen 2 this asks TWO fields rather than one, in a fixed order.  mon.item
-- is the engine's own held-item slot -- populated by
-- src/ui/gen2/HeldItemMenu.lua's real GIVE, the same field
-- src/battle/gen2/Battle.lua already reads for LUCKY_EGG, EXP_SHARE and
-- EVERSTONE -- and it is asked FIRST, ahead of eligibility.STAMP: it is what
-- the SUMMARY screen's own ITEM row names, a real inventory transaction the
-- bag count reflects, where the stamp below is this mod's own bolt-on for a
-- game (Gen 1) that has no held-item slot to read at all.  Of the two, mon.
-- item is the stronger, more current claim, so a mon actually HOLDING a
-- different one of this table's items than it is stamped with (Rotom's five
-- appliances are the one family that can genuinely disagree with itself)
-- wears the form the real item names.  The stamp is asked only as a
-- fallback -- when mon.item is empty, or holds something this table
-- recognises nothing for the species -- so giving a Rotom a Leftovers does
-- not cancel an appliance form a bag "use" already stamped it with (that
-- item never left the bag in the first place; see M.install below).
--
-- Gen 1 never reaches the mon.item branch at all: that game has no
-- held-item slot, so `deps.gen2` gates it the way it gates every other
-- Gen-2-only read in this file (src/persistent.lua's own M.apply, HANDOFF's
-- Gen 2 trap #1) -- never inferred from whether the field happens to be
-- present on the table.
function M.formIdFor(mon)
  if not deps or not deps.rows then return nil end
  if deps.gen2 and mon then
    local held = deps.eligibility.formFor(deps.rows, mon.species, mon.item)
    if held then return held end
  end
  return deps.eligibility.formForMon(deps.rows, mon)
end

-- mon.form carries the record's `form` SUFFIX, not the record id, so every
-- question about what the marker should read has to go through the record.
local function suffixOf(data, formId)
  local record = data and data.pokemon and data.pokemon[formId]
  local suffix = record and record.form
  if type(suffix) ~= "string" or suffix == "" then return nil end
  return suffix
end

-- Makes the marker agree with the stamp, and answers whether this module
-- claimed the mon at all.
--
-- This is what the battle-end party sweep calls, and why that sweep needs no
-- way of telling a persistent form from a battle one.  A mon with no pairing
-- here is answered `false` and left entirely to src/forms.lua's blunt clear; a
-- mon with one has its marker OVERWRITTEN with what the pairing says, so a
-- battle form standing on a persistent Pokemon is replaced rather than
-- preserved.  Neither path can leak a battle form into the save.
--
-- The unresolvable case clears rather than keeps, which looks like the harsher
-- choice and is the recoverable one: the stamp still names the appliance, so
-- the next send-out derives the form again, where a marker left standing for a
-- record nobody can resolve is art with no stats behind it -- exactly the
-- silent mismatch this mod exists not to have.  It says so out loud because
-- there is no player action behind a sweep to notice it failing.
function M.settle(data, mon)
  if not mon then return false end
  local formId = M.formIdFor(mon)
  if not formId then return false end

  local suffix = suffixOf(data, formId)
  if not suffix then
    mon.form = nil
    if deps.log then
      deps.log:warn(
        "battle_forms: %s carries the stamp for %s but that form could not be "
          .. "resolved (missing national_dex record, or no `form` field) -- the "
          .. "marker was cleared; the item is still on the Pokemon and the form "
          .. "returns as soon as the record does",
        tostring(mon.species), tostring(formId))
    end
    return true
  end

  mon.form = suffix
  return true
end

-- The out-of-battle write, and the only one.  Unconditional where M.settle is
-- careful, because every caller of this is a bag action: nothing but a
-- persistent form can be on `mon.form` outside a battle -- OR a fusion, which
-- is the exception this function asks about before it acts like there is
-- nothing here to be careful of.  Handing an appliance to a Rotom sets the
-- marker; handing that Rotom a Z-Crystal instead moves the stamp and this
-- takes the marker back off, which is what stops a Pokemon wearing a form the
-- item it holds no longer entitles it to.
--
-- deps.fusion is asked FIRST in the fallback, matching src/resolve.lua's own
-- party sweep and for the same reason it gives: no species was ever supposed
-- to be both a fusion base and an appliance user, so asking fusion here cost
-- nothing for 0.22.0 versions of this file. Ultra Burst broke that -- Necrozma
-- is a fusion base (data/fusion.lua) AND an eligibility.STAMP user
-- (data/ultraburst.lua, through src/stone.lua's PAIRED install, the same path
-- every mega stone takes) -- so giving a fused Necrozma the crystal reached
-- this function, M.settle found no data/persistent.lua row for Necrozma, and
-- the unconditional `mon.form = nil` below wiped the Dusk Mane or Dawn Wings
-- suffix src/fusion.lua had just set, with nothing about the fusion stamp or
-- the crystal touched -- only the marker the party sprite actually reads.
-- deps.fusion.settle is a pure re-derivation from that stamp, so asking it
-- here remembers nothing new; it consults a stronger, pre-existing claim
-- before assuming there is none.
function M.mark(data, mon)
  if not mon then return false end
  if not M.settle(data, mon) then
    if deps.fusion and deps.fusion.settle(data, mon) then
      return false
    end
    mon.form = nil
    return false
  end
  return true
end

-- Whether mon.form already holds a suffix THIS module's own pairing table
-- could produce for this species -- any one of its rows, not necessarily the
-- one M.formIdFor names right now.  Asked only by M.apply's own guard below:
-- on Gen 2, mon.item can change with no hook this mod sees at all
-- (src/ui/gen2/HeldItemMenu.lua's GIVE/TAKE is pure engine code), so a mon
-- can arrive at a send-out wearing the suffix of an appliance/Plate/Memory/
-- Drive it is no longer holding -- this module's OWN marker, one held-item
-- swap stale, and not a foreign mechanic's claim on the mon.
local function ownsSuffix(data, mon)
  local byItem = mon and mon.species and deps.rows[mon.species]
  if not byItem then return false end
  for _, formId in pairs(byItem) do
    if suffixOf(data, formId) == mon.form then return true end
  end
  return false
end

-- Puts the form's stats and types on the battler, through the same primitive
-- every other transformation type here uses.  becomeForm is idempotent, which
-- is what makes this safe to run on every send-out without asking first: a
-- persistent mon coming back from the bench arrives on the fresh, form-blind
-- battler makeBattler hands over and needs exactly the same override applied
-- exactly the same way as one entering for the first time.
--
-- Refuses to dress a mon already wearing SOME OTHER mechanic's form, which is
-- the guard src/conditional.lua and src/dynamax.lua both keep: a persistent
-- form is the baseline a battle form is laid over, not something that outranks
-- one, and overwriting a mega here would undo mid-battle something the player
-- only gets once.  On Gen 2 that refusal is narrowed by ownsSuffix above: a
-- mismatch explained by this module's OWN table (Rotom marked "WASH" while
-- mon.item now names the Microwave Oven) is this module's own marker gone
-- stale, not a foreign mechanic's claim, and correcting it is the whole point
-- of wiring mon.item into M.formIdFor in the first place.  ownsSuffix is
-- never asked on Gen 1: every stamp mutation there re-derives synchronously
-- through M.mark, so nothing can make this module's own marker stale out from
-- under it, and a mismatch can only ever mean a foreign mechanic -- exactly
-- what the refusal was always written to assume.
--
-- deps.gen2 picks which primitive actually does the work, and it is a flag
-- this module is bound with rather than anything read off `battler` -- Gen 2
-- hands battle.player/battle.enemy in as the bare mon with no wrapper at all
-- (src/battlerof.lua's own header), so `battler` having no `.mon` field is
-- indistinguishable from a malformed Gen 1 payload and cannot be trusted to
-- mean "this is Gen 2" (HANDOFF's own trap: gate on the generation, never on
-- which shape a table happens to have).  deps.battlerof.mon still does the
-- right thing on either shape -- it is what `mon` below already is -- so only
-- the primitive itself needs to branch.
function M.apply(battle, battler)
  local mon = deps.battlerof.mon(battler)
  if not mon or not battle then return end
  local formId = M.formIdFor(mon)
  if not formId then return end

  local suffix = suffixOf(battle.data, formId)
  -- See this function's own header above for what ownsSuffix narrows here
  -- and why only Gen 2 asks it.
  if mon.form and suffix and mon.form ~= suffix
      and not (deps.gen2 and ownsSuffix(battle.data, mon)) then
    return
  end

  local ok, reason
  if deps.gen2 then
    ok, reason = deps.gen2forms.becomeForm(battle.data, mon, formId)
  else
    ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
  end
  if not ok and deps.log then
    -- A guard that refuses must say so out loud.  There is no player action
    -- behind a send-out, so a silent refusal would show as a Rotom that is
    -- somehow its appliance form in the party menu and its base form in
    -- battle, with nothing anywhere to say why.
    deps.log:warn(
      "battle_forms: refused persistent form for %s -> %s (%s) -- the "
        .. "national_dex record is missing, has no `form` field, or "
        .. "data/persistent.lua names the wrong id",
      tostring(mon.species), tostring(formId), tostring(reason))
  end
end

-- Both battlers, not just the player's.  The appliance is the mon's own, the
-- way a held item is, so a trainer's Rotom wears its form on the same terms the
-- player's does.
--
-- Applies and NOTHING else, which is a decision rather than an omission.  An
-- early draft reconciled here as well -- taking off any marker this table could
-- not vouch for, on the reasoning that at battle start a marker can only be a
-- claim the save made.  That reasoning is sound and the code was still wrong:
-- it made the handler's correctness depend on running before every other
-- send-out handler in the mod, and primal reversion had already applied its own
-- form by then, so a Groudon holding the Red Orb was stripped of a reversion it
-- had just been given.  A pass that has to be first is a pass that breaks the
-- day something else is put in front of it.
--
-- Nothing is lost by leaving it out.  A marker with no item behind it is
-- cleared by the battle-END sweep, where the same question is asked of the
-- whole party rather than of the two mons on the field -- so an orphan survives
-- at most one battle, and it survives it as a wrong picture rather than as
-- wrong stats, because becomeForm below never ran for it.
function M.onBattleStarted(ev)
  local battle = ev and ev.battle
  if not battle then return end
  M.apply(battle, battle.player)
  M.apply(battle, battle.enemy)
end

-- The same call for the same reason, and the reason it is a separate handler at
-- all is makeBattler: a mon coming back from the bench keeps its marker but
-- arrives on a fresh, form-blind battler whose curStats and curTypes were
-- seeded from the base species.
function M.onBattlerSwitched(ev)
  local battle = ev and ev.battle
  if not battle then return end
  M.apply(battle, ev.battler)
end

-- The bag "use" toggle every one of these items shares: stamp on if the mon
-- is not already carrying one of this mod's items, swap the stamp for a
-- different item of the SAME row (Rotom's five appliances, Arceus' Plates),
-- or take it back off if the same item is used again.  Factored out once so
-- Gen 1's item_effects shape below and Gen 2's cannot drift from each
-- other's rule about which species may hold which item -- only the ctx shape
-- and the return convention differ between the two generations' own
-- dispatchers, never the eligibility check or the mutation.  Returns the
-- Gen 1 three-value shape ("kept"/"failed", a single message STRING) because
-- that is what the Gen 1 closure below hands back unmodified; the Gen 2
-- closure re-shapes it into {used, text} itself.
local function toggle(rows, itemId, mon, data)
  if not mon then return "failed", "It won't have\nany effect." end
  if not deps.eligibility.formFor(rows, mon.species, itemId) then
    return "failed", "It won't have\nany effect."
  end
  -- Generic on purpose: this one closure now serves both Rotom's appliances
  -- and every held-item form beside them, and the item's own name is already
  -- what the player just picked to use it, so it does not need repeating.
  if deps.eligibility.stoneOf(mon) == itemId then
    mon[deps.eligibility.STAMP] = nil
    M.mark(data, mon)
    return "kept", "It let go of\nthe item."
  end
  mon[deps.eligibility.STAMP] = itemId
  M.mark(data, mon)
  return "kept", "It's now holding\nthe item!"
end

-- Every row of `rows` -- appliances and held-item forms alike -- as bag items
-- used on a Pokemon.
--
-- Registered through an install of this module's own rather than src/stone.lua's
-- because of the second branch below and nothing else: a persistent form is the
-- only one of these items a player needs a way to UNDO.  A stone, an orb and a
-- crystal are all pure additions -- the Pokemon can do something it could not do
-- before and loses nothing -- so overwriting one with another is the whole of
-- the choice.  This one changes what the Pokemon IS, in the save, until
-- something changes it back, and shipping a write with no way back would leave a
-- player who tried one once holding a Pokemon they could not restore.
--
-- Using the item a Pokemon is already carrying takes it back off, which is the
-- closest honest reading of the real games' own arrangement: a Rotom's room
-- offers its base form in the same list it offers the five, and one item slot
-- is the only thing this game has to say that with.
--
-- Callers hand this the WHOLE pairing table -- main.lua passes the entire
-- data/persistent.lua, not a slice for one family -- so `indices` has to
-- resolve every item any row names, whichever of the caller's several bag-byte
-- tables it was merged from; this function does not know or need to know which
-- shelf an item ends up on.
--
-- An id with NO ENTRY AT ALL in `indices` is refused out loud for the reason
-- every other family here refuses one: a Gen 1 save cannot hold an item with
-- no byte, so registering it would ship something a player could pick up and
-- then silently lose.  That is `index == nil`, checked explicitly rather than
-- with a truthiness test, because `false` is a real, different answer here --
-- see data/plates.lua and data/memories.lua -- and `not false` is `true` in
-- Lua, which would have refused all 34 of those on this exact line.  `false`
-- means the table was consulted and answered "no byte, on purpose": the item
-- still registers, still buys, still stamps, and simply carries no `index`
-- field for src/save_convert/GenSave.lua's cartridge crosswalk to find, the
-- same shape a TM or an HM already registers with there.  Only a genuinely
-- ABSENT key -- a row in `rows` naming an item no indices table mentions at
-- all -- is the mistake this refusal exists to catch.
function M.install(mod, rows, indices)
  local items = {}
  for _, byItem in pairs(rows) do
    for itemId in pairs(byItem) do items[itemId] = true end
  end

  for itemId in pairs(items) do
    local index = indices and indices[itemId]
    if index == nil then
      mod.log:error("%s has no bag index -- add it to its indices table "
        .. "(data/appliances.lua, data/heldforms.lua, data/plates.lua, "
        .. "data/memories.lua or data/drives.lua); until then the item "
        .. "cannot exist in a save and no Pokemon can be given one", itemId)
    else
      mod.content.items:register(itemId, {
        id = itemId,
        name = itemId:gsub("_", " "),
        price = deps.price,
        index = index ~= false and index or nil,
        effect = itemId,
        needsTarget = true,
        -- Gen 2's own PACK submenu (src/ui/gen2/PackMenu.lua's submenuRows)
        -- reads these two fields straight off the item record.  Both say the
        -- same thing GIVE-only already means: a held item is not something
        -- the real games ever let a player USE out of the bag, in the field
        -- or mid-battle -- Leftovers, the Exp. Share, every held item Gold
        -- already ships shows no USE verb in either pocket menu, GIVE and
        -- TOSS only, and this mod's own held-item forms belong on that same
        -- shelf now that Gen 2 has a real slot for them (see M.formIdFor's
        -- own header).  Confirmed against a real Gold boot: without these two
        -- fields, choosing USE on a Griseous Orb reached
        -- Game2:usePartyItem, which calls
        -- `ItemEffects.partyAction(itemId)` with NO data argument -- so
        -- `ItemEffects.recordFor` can only ever check the engine's own
        -- built-in ItemEffects.RECORDS table, never a mod's
        -- data.gen2ItemEffects merge, and `action` comes back nil for every
        -- mod-registered item without exception. `usePartyItem`'s `if not
        -- action then return end` then does precisely nothing: no party
        -- picker, no message, no error -- unlike a Berry, which is exactly
        -- the discrepancy the player noticed. That is an engine-side gap this
        -- mod cannot close from here (HANDOFF's own standing rule: nothing
        -- may require an engine change), so rather than leave a USE verb on
        -- screen that silently does nothing, these two fields take the verb
        -- off the screen entirely -- which is also the more faithful choice
        -- on its own terms, independent of the bug.  Gen 1 has neither field
        -- name and ignores both; USE remains its only mechanism there.
        fieldMenu = "ITEMMENU_NOUSE",
        battleMenu = "ITEMMENU_NOUSE",
      })
      -- Two shapes, chosen once at registration time and never both: the
      -- registry name `item_effects` is itself rerouted to a DIFFERENT table
      -- depending on the running boot's generation (Schemas.GEN2 maps it to
      -- data.gen2ItemEffects), so a single boot only ever calls the branch
      -- below that matches it, and only one record is ever registered under
      -- this id.
      --
      -- The Gen 2 branch is unreachable through Gold's own PACK today --
      -- fieldMenu/battleMenu above already take the USE verb off both menus,
      -- and Game2:usePartyItem's own `data`-less call to
      -- ItemEffects.partyAction (this file's header on the item record
      -- above) would refuse it even if a verb reached this dispatcher. It is
      -- registered anyway, correctly shaped for the one caller Gen 2 gives an
      -- item_effects record (src/core/gen2/ItemEffects.lua's `use(ctx) ->
      -- {used, text}`, ctx = {item, mon, data, slot}), so this needs no
      -- second change the day either of those two engine-side gaps closes --
      -- and so a mod that reaches ItemEffects.useOnMon some other way still
      -- gets the right answer.
      mod.content.item_effects:register(itemId, deps.gen2 and {
        needsTarget = true,
        action = "form",
        use = function(ctx)
          local _, text = toggle(rows, itemId, ctx and ctx.mon, ctx and ctx.data)
          -- The generic branch of Game2:usePartyItem's dispatch spends the
          -- item itself whenever `used` comes back true -- there is no
          -- "kept" outcome in its vocabulary the way Gen 1's three-way
          -- ("consumed"/"kept"/"failed") has one.  `used` stays false on
          -- every branch here on purpose: this item is KEPT, not consumed,
          -- on both generations (see this function's own header above), and
          -- Gen 2's `used` flag is the one lever this closure has to say so.
          return { used = false, text = text }
        end,
      } or {
        needsTarget = true,
        -- A field decision, and here that is load-bearing rather than tidy:
        -- this is the one item effect in the mod that writes a form into the
        -- save, and the engine refuses a `battle = false` effect mid-fight
        -- before it reaches this function at all.
        battle = false,
        use = function(ctx)
          local status, text = toggle(rows, itemId, ctx and ctx.target, ctx and ctx.data)
          return status, { text }
        end,
      })
    end
  end
end

return M
