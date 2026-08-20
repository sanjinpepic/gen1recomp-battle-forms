-- Two Pokemon go in and one comes out of the party.  The only thing in this
-- mod that takes a Pokemon off a player, and therefore the only thing here
-- where a bug costs something that cannot be earned back.
--
-- WHERE THE PARTNER GOES, which is the decision the rest of this file follows
-- from.  Into the PC, through the engine's own src/pokemon/Boxes.lua, as an
-- ordinary boxed Pokemon.  It is NOT carried inside the surviving Pokemon,
-- although it could be: src/core/SaveSerializer.lua re-emits whatever keys it
-- finds to any depth and SaveData.validate never walks a mon's unknown fields,
-- so a whole nested mon table round-trips through a save for free.
--
-- It is not carried there because of the Game Boy .sav export.  GenSave.lua
-- rebuilds a mon from fixed offsets with every byte spoken for and there is no
-- hook, event or seam anywhere near it -- so a partner nested inside a mon
-- would be DELETED by an export, and no guard this mod could write would be
-- able to say so.  Where a guard cannot be reached the damage has to be made
-- structurally impossible instead, and boxes are how: GenSave encodes all
-- twelve of them through the same encodeMon the party goes through, so a boxed
-- Reshiram survives a cartridge round trip AS a Reshiram.  What does not
-- survive is the pair of strings below, which is the recoverable half -- an
-- exported fused pair comes back as two plain Pokemon in the places they were,
-- and the ceiling on the damage is "fuse them again".
--
-- WHAT IS WRITTEN.  One string on each of the two Pokemon and nothing else.
-- M.STAMP on the survivor names the PARTNER'S SPECIES; M.HELD on the boxed
-- partner names the base's.  mon.form is derived from the first of those the
-- way src/persistent.lua derives it from a held item, so the derived-not-
-- remembered discipline holds here with no exception to argue for: the truth is
-- which partner went in, and everything else -- the form, the item that undoes
-- it, the message -- is computed from that.  Neither Pokemon's species, stats,
-- hp or moves are touched, for the four reasons src/persistent.lua sets out.
--
-- M.HELD exists only so that splitting returns THAT partner and not another of
-- the same species.  Nothing derives from it and the fusion stands without it,
-- which is deliberate: a player who releases the boxed partner still has a
-- working White Kyurem and can still separate it.
--
-- WHY THE ITEM IS NOT STAMPED.  Every other family here goes through
-- src/eligibility.lua's one held-item field, and this one must not: a fused
-- Kyurem given a Z-Crystal would have its stamp overwritten, and if the fusion
-- hung off that stamp the Reshiram in the PC would be orphaned with nothing
-- left able to name it.  A fusion is what the Pokemon IS, not what it carries.
local Boxes = require("src.pokemon.Boxes")
local Party = require("src.pokemon.Party")

local M = {}

local deps = nil

function M.bind(modules) deps = modules end

-- The live save, on Gen 2 only.  Gold's own item_effects ctx is {item, mon,
-- data} -- no `save` -- because every OTHER family here only ever needs the
-- one mon it is handed (src/persistent.lua's own Gen 2 branch reads exactly
-- that ctx and nothing more).  Fusion is the one family that needs the ARRAY
-- around the mon too: `fuse` finds a partner by walking the party, `split`
-- puts one back into it, and both need the save itself for Boxes.deposit.
-- Bound to save.created/save.loaded in main.lua -- the sanctioned way a mod
-- holds the live save past the moment it is handed one
-- (docs/preparing-your-mod-for-gen2.md's own "Capturing state" section) --
-- rather than required at file scope, which would capture the load-time nil
-- every mod's entry chunk runs before a save exists.  Both events, not just
-- one, because self.save is reassigned wholesale on NEW GAME and on
-- CONTINUE, and the stale table a listener bound only to the first would
-- otherwise still hold is not the one Game2:usePartyItem goes on to mutate.
local liveSave = nil

function M.onSaveReady(ev)
  liveSave = ev and ev.save
end

-- On the survivor: the species of the Pokemon it was fused with.
M.STAMP = "battleFormsFusedWith"
-- On the boxed partner: the species it is inside.  A tag, not a link -- there
-- is nothing unique on a Gen 1 Pokemon to link TO (no personality value, no
-- uuid; otId is the trainer's and DVs are four 4-bit rolls), so two Kyurem each
-- fused with a Reshiram can only be told apart by which box slot comes first.
-- Both went in, so neither is lost by that; at worst the two swap owners.
M.HELD = "battleFormsFusedInto"

function M.partnerOf(mon)
  local species = mon and mon[M.STAMP]
  if type(species) ~= "string" or species == "" then return nil end
  return species
end

-- The National Dex record key this pair makes, or nil.  Derived from the two
-- species and nothing else, which is why the item that made the fusion never
-- has to be remembered: a partner species appears under exactly one item.
function M.formIdFor(mon)
  local partner = M.partnerOf(mon)
  if not partner or not deps or not deps.rows or not mon.species then return nil end
  local byItem = deps.rows[mon.species]
  if not byItem then return nil end
  for _, byPartner in pairs(byItem) do
    local formId = byPartner[partner]
    if formId then return formId end
  end
  return nil
end

-- mon.form carries the record's `form` SUFFIX, not the record id, so every
-- question about what the marker should read goes through the record.
local function suffixOf(data, formId)
  local record = data and data.pokemon and data.pokemon[formId]
  local suffix = record and record.form
  if type(suffix) ~= "string" or suffix == "" then return nil end
  return suffix
end

-- Makes the marker agree with the pair, and answers whether this module
-- claimed the mon at all -- the same contract src/persistent.lua's settle keeps
-- and the same one src/resolve.lua's party sweep branches on.  A fused mon is
-- answered true and has its marker OVERWRITTEN, so a battle form standing on
-- one is replaced rather than carried into the save; every other mon is
-- answered false and left to the blunt clear.
--
-- The unresolvable case clears the marker and keeps the fusion, for the reason
-- the appliances do: the pair still names the form, so it returns the moment
-- the record does, where a marker left standing is art with no stats behind it.
-- It says so out loud because there is no player action behind a sweep.
function M.settle(data, mon)
  if not mon then return false end
  local formId = M.formIdFor(mon)
  if not formId then return false end

  local suffix = suffixOf(data, formId)
  if not suffix then
    mon.form = nil
    if deps.log then
      deps.log:warn(
        "battle_forms: %s is fused with %s but %s could not be resolved "
          .. "(missing national_dex record, or no `form` field) -- the marker "
          .. "was cleared; the pair is intact and the form returns as soon as "
          .. "the record does",
        tostring(mon.species), tostring(M.partnerOf(mon)), tostring(formId))
    end
    return true
  end

  mon.form = suffix
  return true
end

-- The out-of-battle write, and the only one.  Unconditional where M.settle is
-- careful, for src/persistent.lua's reason: every caller of THIS function is
-- one of the two fusion items, and neither stamps eligibility.STAMP -- see
-- the header above on why the item is not stamped -- so nothing this
-- function's fallback could wipe was ever put there by data/persistent.lua's
-- family.  That is a narrower claim than "no species is both a fusion base
-- and an appliance user" -- Ultra Burst made that one false the day
-- data/ultraburst.lua paired Necrozma through src/stone.lua's PAIRED install
-- -- but the narrower one still holds: this function is never reached by
-- giving an appliance, a mega stone, an orb or a crystal, only by using
-- DNA_SPLICERS, N_SOLARIZER, N_LUNARIZER or REINS_OF_UNITY, so a persistent
-- form has no route onto mon.form for this fallback to be careless about. The
-- reverse direction -- an appliance or a crystal wiping a FUSION marker -- is
-- src/persistent.lua's own M.mark, and that is the one Ultra Burst broke.
function M.mark(data, mon)
  if not mon then return false end
  if not M.settle(data, mon) then
    mon.form = nil
    return false
  end
  return true
end

-- Puts the form's stats and types on the battler, through the same primitive
-- every other transformation type here uses.  becomeForm is idempotent, so this
-- is safe on every send-out: makeBattler is form-blind and seeds curStats and
-- curTypes from the base species whether the mon is arriving for the first time
-- or coming back from the bench.
--
-- Refuses to dress a mon already wearing SOME OTHER mechanic's form, the guard
-- src/persistent.lua, src/conditional.lua and src/dynamax.lua all keep: a
-- fusion is the baseline a battle form is laid over, not something that
-- outranks one.
-- deps.gen2/deps.gen2forms pick the primitive, the exact pair
-- src/persistent.lua's own M.apply branches on and for the identical
-- reason: Gen 2 has no battler wrapper at all (src/battlerof.lua's own
-- header), so deps.forms.becomeForm -- built on battler.mon -- would find
-- no target and silently apply nothing, leaving a genuinely fused Necrozma
-- looking and fighting as plain Necrozma for the length of every battle.
function M.apply(battle, battler)
  local mon = deps.battlerof.mon(battler)
  if not mon or not battle then return end
  local formId = M.formIdFor(mon)
  if not formId then return end

  local suffix = suffixOf(battle.data, formId)
  if mon.form and suffix and mon.form ~= suffix then return end

  local ok, reason
  if deps.gen2 then
    ok, reason = deps.gen2forms.becomeForm(battle.data, mon, formId)
  else
    ok, reason = deps.forms.becomeForm(battle.data, battler, formId, battle)
  end
  if not ok and deps.log then
    -- A guard that refuses must say so out loud.  There is no player action
    -- behind a send-out, so a silent refusal would show as a Pokemon that is
    -- fused in the party menu and not in battle, with nothing to say why.
    deps.log:warn(
      "battle_forms: refused fusion form for %s -> %s (%s) -- the national_dex "
        .. "record is missing, has no `form` field, or data/fusion.lua names "
        .. "the wrong id",
      tostring(mon.species), tostring(formId), tostring(reason))
  end
end

-- Both battlers, because a fusion is the Pokemon's own the way an appliance is.
-- Applies and reconciles NOTHING, for the reason src/persistent.lua gives at
-- length: a pass that has to run before every other send-out handler is a pass
-- that breaks the day something is put in front of it.  A marker with no pair
-- behind it is taken off by the battle-END sweep instead, where the whole party
-- is walked -- so an orphan survives at most one battle, and survives it as a
-- wrong picture rather than as wrong stats.
function M.onBattleStarted(ev)
  local battle = ev and ev.battle
  if not battle then return end
  M.apply(battle, battle.player)
  M.apply(battle, battle.enemy)
end

function M.onBattlerSwitched(ev)
  local battle = ev and ev.battle
  if not battle then return end
  M.apply(battle, ev.battler)
end

-- ---- the item ---------------------------------------------------------

local NO_EFFECT = { "It won't have\nany effect." }

local function nameOf(data, mon)
  local nickname = mon and mon.nickname
  if type(nickname) == "string" and nickname ~= "" then return nickname end
  local record = data and data.pokemon and data.pokemon[mon and mon.species]
  local name = record and record.name
  if type(name) == "string" and name ~= "" then return name end
  return tostring(mon and mon.species)
end

-- The first eligible partner in PARTY ORDER.  Kyurem and Calyrex each have one
-- item and two possible partners, so a party holding both needs something to
-- choose between them, and party order is the only ordering a player can see
-- and rearrange without a screen this mod would have to invent.
--
-- A candidate already inside a fusion is skipped rather than taken.  That can
-- only happen when a player withdraws a boxed partner, and consuming it a
-- second time would leave two survivors pointing at one Pokemon -- the shape
-- from which something eventually goes missing.
local function findPartner(party, mon, byPartner)
  for i, other in ipairs(party) do
    if other ~= mon and byPartner[other.species]
       and not M.partnerOf(other) and other[M.HELD] == nil then
      return i, other
    end
  end
  return nil
end

-- Would the party still be able to fight without this one?  Blackout is keyed
-- on Party.firstHealthy rather than on party size (src/battle/BattleState.lua),
-- so fusing a healthy partner into a fainted base can leave a party that is not
-- empty and still cannot battle -- a soft-lock reached outside battle, where
-- nothing exists to recover from it.  A refusal is always better than that.
local function keepsAFighter(party, skipIndex)
  for i, other in ipairs(party) do
    if i ~= skipIndex and (other.hp or 0) > 0 then return true end
  end
  return false
end

local function fuse(ctx, mon, byPartner)
  local save, data = ctx.save, ctx.data
  local party = save.party

  local index, partner = findPartner(party, mon, byPartner)
  if not partner then
    return "failed", { "There's no PKMN\nto join with!" }
  end

  -- Resolved before anything moves.  A fusion that boxed a Pokemon and then
  -- could not name a form would leave the player a Kyurem that looks entirely
  -- unchanged and a Reshiram in the PC to explain it.
  local formId = byPartner[partner.species]
  local suffix = suffixOf(data, formId)
  if not suffix then
    if deps.log then
      deps.log:error(
        "battle_forms: refused to fuse %s with %s -- %s has no national_dex "
          .. "record or no `form` field, and nothing is moved until it does; "
          .. "check data/fusion.lua names the record's KEY",
        tostring(mon.species), tostring(partner.species), tostring(formId))
    end
    return "failed", NO_EFFECT
  end

  if not keepsAFighter(party, index) then
    return "failed", { "The party needs\na healthy PKMN!" }
  end

  local removed = table.remove(party, index)
  -- Identity rather than the index that found it.  Nothing between the scan
  -- and here can reorder a party, so this cannot fire -- and it is checked
  -- anyway because this is the one place in the mod where being wrong loses a
  -- Pokemon instead of drawing a wrong picture.
  if removed ~= partner then
    table.insert(party, index, removed)
    if deps.log then
      deps.log:error(
        "battle_forms: refused to fuse %s -- the party moved between choosing "
          .. "the partner and removing it, so nothing was changed",
        tostring(mon.species))
    end
    return "failed", NO_EFFECT
  end

  local box = Boxes.deposit(save, partner)
  if not box then
    -- Put back exactly where it stood.  The party is the only place this
    -- Pokemon has ever been and it is going straight back into it, so there is
    -- one statement between the two lists and none where it is in both.
    table.insert(party, index, partner)
    return "failed", { "There's no room\nin the PC!" }
  end

  partner[M.HELD] = mon.species
  mon[M.STAMP] = partner.species
  M.mark(data, mon)
  -- One page, not two.  The partner still goes to the PC -- that has not
  -- changed and is not going to -- but the player no longer has to read a
  -- textbox to learn it: src/boxmark.lua marks the boxed partner with an F
  -- in the WITHDRAW and RELEASE lists and on its own STATS screen, which is
  -- durable and on screen every time the PC is opened, where a message
  -- printed once here is gone the moment the player presses past it.
  return "kept", { nameOf(data, mon) .. "\nwas fused!" }
end

local function findHeld(save, species, baseSpecies)
  for b, box in ipairs(Boxes.ensure(save)) do
    for i, other in ipairs(box) do
      if other.species == species and other[M.HELD] == baseSpecies then
        return b, i, other
      end
    end
  end
  return nil
end

local function split(ctx, mon)
  local save, data = ctx.save, ctx.data
  local partnerSpecies = M.partnerOf(mon)
  local box, slot, partner = findHeld(save, partnerSpecies, mon.species)

  -- Asked before anything is taken out of a box, so a full party is a refusal
  -- with the pair exactly as it was rather than a Pokemon in neither place.
  if partner and #save.party >= Party.MAX then
    return "failed", { "The party is\nfull!" }
  end

  -- One page, not two, on the ordinary path: the "came back from the PC!"
  -- line is cut for the same reason 0.28.0 cut fusing's "went into the PC!"
  -- one -- src/boxmark.lua's F marker is gone from the WITHDRAW and RELEASE
  -- lists the instant the withdraw happens, which already answers "where is
  -- it now" on screen rather than in a line printed once and gone. The
  -- anomaly branch below still gets its own page: there is no marker for a
  -- Pokemon that never came back, so the player has nowhere else to learn it.
  local extra
  if partner then
    table.remove(Boxes.ensure(save)[box], slot)
    partner[M.HELD] = nil
    table.insert(save.party, partner)
  else
    -- The partner was released, traded or lost to a cartridge round trip.  The
    -- fusion is undone anyway: refusing here would leave the player holding a
    -- Pokemon they could never separate, and the missing one is not made any
    -- less missing by keeping the marker that names it.
    if deps.log then
      deps.log:warn(
        "battle_forms: %s was separated but the %s it was fused with is no "
          .. "longer in the PC -- it was released, traded or lost to a Game "
          .. "Boy .sav export; the fusion was undone with nothing to return",
        tostring(mon.species), tostring(partnerSpecies))
    end
    extra = "The other PKMN\nwasn't in the PC!"
  end

  mon[M.STAMP] = nil
  M.mark(data, mon)
  local pages = { nameOf(data, mon) .. "\nwas separated!" }
  if extra then pages[2] = extra end
  return "kept", pages
end

-- The fusion items, as bag items used on a Pokemon.
--
-- Its own install rather than src/stone.lua's for a stronger version of the
-- reason the appliances have one: this item does not stamp the mon at all, it
-- rearranges the party and the PC.  The undo is the same item used again, which
-- is how the real games do it and the only way back there can be.
--
-- An id with no bag index is refused out loud for the reason every other family
-- here refuses one: a Gen 1 save cannot hold an item with no byte, so
-- registering it would ship something a player could pick up and then silently
-- lose.
function M.install(mod, rows, indices)
  local items = {}
  for _, byItem in pairs(rows) do
    for itemId in pairs(byItem) do items[itemId] = true end
  end

  for itemId in pairs(items) do
    local index = indices and indices[itemId]
    if not index then
      mod.log:error("%s has no bag index -- add it to data/fusers.lua; until "
        .. "then the item cannot exist in a save and no Pokemon can be given "
        .. "one", itemId)
    else
      mod.content.items:register(itemId, {
        id = itemId,
        name = itemId:gsub("_", " "),
        price = deps.price,
        -- No bag byte on Gold -- data/stones.lua holds the argument.
        index = (not deps.gen2) and index or nil,
        effect = itemId,
        needsTarget = true,
        -- Gold's mid-battle PACK dispatch (game/src/ui/gen2/BattleState.lua's
        -- own useItem, the first thing it checks) gates purely on THIS field,
        -- not on item_effects' own `battle = false` below -- that guard is
        -- never even reached from a Gen 2 battle, since the mid-fight caller
        -- runs ItemEffects.useOnMon directly rather than through anything
        -- that reads `battle`.  Without this a fusion USE would reach the
        -- real party list mid-battle and remove a Pokemon a live fight holds
        -- a direct reference to.  fieldMenu is left unset on purpose: unlike
        -- a persistent form (src/persistent.lua's own registration, both
        -- fields NOUSE), USE from the field PACK is fusion's own trigger and
        -- has to stay on -- GIVE cannot stand in for an action that moves a
        -- second Pokemon into the PC.
        battleMenu = deps.gen2 and "ITEMMENU_NOUSE" or nil,
      })
      mod.content.item_effects:register(itemId, deps.gen2 and {
        needsTarget = true,
        -- Any value Game2:usePartyItem's own "stone"/"candy"/"pp" special
        -- cases do not name -- none of the three describe moving a second
        -- Pokemon into the PC, and this closure's `used` is always false
        -- (see below), so the branch that actually reads `action` past this
        -- point is never taken anyway.
        action = "fusion",
        use = function(ctx)
          local mon = ctx and ctx.mon
          if not mon then return { used = false, text = NO_EFFECT[1] } end
          local byItem = rows[mon.species]
          local byPartner = byItem and byItem[itemId]
          if not byPartner then return { used = false, text = NO_EFFECT[1] } end

          if not liveSave or type(liveSave.party) ~= "table" then
            if deps.log then
              deps.log:error(
                "battle_forms: %s was used with no party to read -- nothing "
                  .. "was changed", itemId)
            end
            return { used = false, text = NO_EFFECT[1] }
          end

          -- fuse/split read ctx.save and ctx.data; Gold's own ctx carries
          -- neither the save (see M.onSaveReady's own header) nor `data`
          -- under that name (it is `ctx.data` already, matching Gen 1's), so
          -- this is the save substituted in and nothing else changed.
          local innerCtx = { save = liveSave, data = ctx and ctx.data }
          local partner = M.partnerOf(mon)
          local status, pages
          if partner then
            if not byPartner[partner] then
              return { used = false, text = NO_EFFECT[1] }
            end
            status, pages = split(innerCtx, mon)
          else
            status, pages = fuse(innerCtx, mon, byPartner)
          end
          -- `used` stays false on every branch, success and refusal alike:
          -- this item is KEPT, not consumed, on both generations (this
          -- file's own header on the item, and src/persistent.lua's
          -- identical choice for the appliances) -- the undo is the same
          -- item used again, and Gen 2's dispatcher spends the item whenever
          -- `used` comes back true, the one lever this closure has to say
          -- otherwise.
          return { used = false, text = table.concat(pages, "\f") }
        end,
      } or {
        needsTarget = true,
        -- The most load-bearing field in this file.  A battle holds direct
        -- references to party mons (battle.player.mon, the enemy party, the
        -- participant set), so removing one mid-fight would leave the battle
        -- pointing at a Pokemon the party no longer has.  The engine refuses a
        -- `battle = false` effect before it reaches this function at all.
        battle = false,
        use = function(ctx)
          local mon = ctx and ctx.target
          if not mon then return "failed", NO_EFFECT end
          local byItem = rows[mon.species]
          local byPartner = byItem and byItem[itemId]
          if not byPartner then return "failed", NO_EFFECT end

          local save = ctx.save
          if not save or type(save.party) ~= "table" then
            if deps.log then
              deps.log:error(
                "battle_forms: %s was used with no party to read -- nothing "
                  .. "was changed", itemId)
            end
            return "failed", NO_EFFECT
          end

          local partner = M.partnerOf(mon)
          if partner then
            -- Only the item that made this pair may undo it: an N-Lunarizer
            -- does nothing to a Dusk Mane Necrozma, which the real games rule
            -- the same way.
            if not byPartner[partner] then return "failed", NO_EFFECT end
            return split(ctx, mon)
          end
          return fuse(ctx, mon, byPartner)
        end,
      })
    end
  end
end

return M
