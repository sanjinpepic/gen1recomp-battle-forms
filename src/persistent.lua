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
local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The National Dex record key this mon's stamp entitles it to, or nil.  One
-- lookup, in one place, so the item effect, the send-out handler and the party
-- sweep can never disagree about what a mon is.
function M.formIdFor(mon)
  if not deps or not deps.rows then return nil end
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
-- only gets once.
function M.apply(battle, battler)
  local mon = deps.battlerof.mon(battler)
  if not mon or not battle then return end
  local formId = M.formIdFor(mon)
  if not formId then return end

  local suffix = suffixOf(battle.data, formId)
  if mon.form and suffix and mon.form ~= suffix then return end

  local ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
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
      })
      mod.content.item_effects:register(itemId, {
        needsTarget = true,
        -- A field decision, and here that is load-bearing rather than tidy:
        -- this is the one item effect in the mod that writes a form into the
        -- save, and the engine refuses a `battle = false` effect mid-fight
        -- before it reaches this function at all.
        battle = false,
        use = function(ctx)
          local mon = ctx and ctx.target
          if not mon then return "failed", { "It won't have\nany effect." } end
          if not deps.eligibility.formFor(rows, mon.species, itemId) then
            return "failed", { "It won't have\nany effect." }
          end
          -- Generic on purpose: this one closure now serves both Rotom's
          -- appliances and every held-item form beside them, and the item's
          -- own name is already what the player just picked from the bag menu
          -- to use it, so it does not need repeating here.
          if deps.eligibility.stoneOf(mon) == itemId then
            mon[deps.eligibility.STAMP] = nil
            M.mark(ctx.data, mon)
            return "kept", { "It let go of\nthe item." }
          end
          mon[deps.eligibility.STAMP] = itemId
          M.mark(ctx.data, mon)
          return "kept", { "It's now holding\nthe item!" }
        end,
      })
    end
  end
end

return M
