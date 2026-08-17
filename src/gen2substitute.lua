-- Gen 2's equivalent of src/substitute.lua: give a mon's move list a
-- different appearance for as long as something else says so, and take it
-- back off again exactly.  Max Moves, G-Max Moves, Tera Blast and both
-- Z-Move families are all blocked on this file existing -- see this mod's
-- own HANDOFF for the full list -- but nothing here knows what any of them
-- are, on purpose: this is the mechanism, not a mechanic, the same split
-- src/substitute.lua's own header draws.
--
-- WHY src/substitute.lua'S OWN SHAPE DOES NOT PORT.
--
-- Gen 1 replaces a battler's whole `curMoves` array, a field that lives only
-- on the battler WRAPPER -- `curMoves = mon.moves` is an alias BattleState
-- installs at makeBattler, not the party record's own field, so overwriting
-- it never touches what the save writes (src/substitute.lua's header has the
-- full argument, with its own file:line evidence). Gen 2 builds no such
-- wrapper: `self.player = self.party[self.playerIndex]`
-- (game/src/battle/gen2/Battle.lua:255) -- the battler IS the exact party
-- record, and `mon.moves` (Mon.lua:358, Battle.lua:2162-2166) is that
-- record's own field, the one game/src/save_convert/GenSave.lua walks at
-- export. There is no second array to swap in front of it; there is only
-- the one the save writes, so a Gen 1-shaped swap would hand the save
-- writer the substitute the instant anything asked to write it.
--
-- WHETHER A MOVE LIST IS RECOMPUTABLE, WHICH DECIDED THE WHOLE DESIGN.
--
-- src/gen2forms.lua's stats trick works because mon.stats is fully
-- reconstructible from data.pokemon[mon.species].baseStats plus the mon's
-- own untouched dvs/level/statExp -- nothing is ever cached, so there is
-- nothing that can drift out of sync. A move list has no equivalent source.
-- TMs taught, a move the Move Deleter removed, an order a Day Care egg or a
-- forget-menu choice rearranged: none of that is derivable from species and
-- level, and Mon.movesAtLevel (Mon.lua:302) only ever answers what a FRESH
-- mon knows, never what THIS one, carrying its own history, currently has.
-- So a copy is unavoidable, taken at M.apply and thrown away at M.restore --
-- which is why this module snapshots rather than recomputes.
--
-- WHAT IS SNAPSHOTTED, AND WHY THE ARRAY ITSELF IS NEVER REPLACED.
--
-- The snapshot is per SLOT TABLE, not per array: `id` and `maxPp` are read
-- off each table `mon.moves[index]` already IS, and that exact table is
-- mutated in place -- `mon.moves` the array is never reassigned, and no
-- slot's table is ever replaced by a new one. A whole-array swap (tried
-- first, on paper) fails against two things that independently write into
-- this very array while a substitution could be live:
-- `Battle:resolveForget` (Battle.lua:3391-3397) drops a brand NEW table into
-- `mon.moves[slot]` the moment a mid-battle level-up's extra move is
-- accepted over a full moveset, and `Mon.learnMove` (Mon.lua:537-549)
-- appends a fresh slot at the end when there is room. Under a swapped
-- array, an appended move would land on whichever array `mon.moves`
-- currently was -- this module's fake one, discarded at restore -- rather
-- than the array that outlives the battle, silently losing a move the
-- player just learned. Mutating the SAME slot tables in place removes that
-- failure mode entirely: appending never touches a slot this module holds a
-- reference to, because it writes past the end of the array.
--
-- What resolveForget's overwrite still does is invalidate ONE slot's
-- snapshot, and M.restore is written to notice: it never restores by index
-- alone, only by asking each remembered table "are you still the exact
-- object sitting at your old index" (mon.moves[index] == entry.object).
-- resolveForget's fresh table fails that check, so the newly learned move is
-- left exactly where the player put it instead of being silently overwritten
-- by the move that used to occupy that slot -- and the stale snapshot for
-- that one slot is simply dropped, because there is nothing left to restore
-- it into.
--
-- PP NEEDS NO ROUTING HERE, UNLIKE GEN 1.
--
-- src/substitute.lua gives its substitute no `pp` key of its own so every
-- read and write falls through a metatable to the real slot beneath it,
-- because a Gen 1 substitute is a SEPARATE table from the slot it stands in
-- for. This module never creates a separate table at all: the slot being
-- displayed differently and the slot PP is spent from are, throughout, the
-- identical table object. `pp` is therefore simply never one of the fields
-- this module writes. Battle.lua:1391 (`move.pp = (move.pp or 1) - 1`) keeps
-- landing on the real counter with no help needed, an Ether used
-- mid-substitution refills the same field a substituted read shows, and
-- restoring `id`/`maxPp` on the way out cannot disturb `pp` because it was
-- never touched in the first place -- which is also how a substitute ends up
-- spending the PP of the move it stands in for, matching Gen 1's own rule,
-- with no metatable needed to make it true.
--
-- WHY A DISK WRITE CAN NEVER OBSERVE A SUBSTITUTED ID.
--
-- Gen 2 battles cannot be checkpointed at all: src/core/Checkpoint.lua:60
-- gates checkpoint capture on `getmetatable(top) == BattleState`, the GEN 1
-- class -- a Gold battle screen carries a different metatable entirely, so
-- it falls straight through to the "screen_busy" refusal a few lines later.
-- There is no autosave-during-battle mechanism on this game to defend
-- against in the first place. The one real bypass is Game2:hotkey's F1
-- (src/core/Game2.lua:1684-1686), which calls self:writeSave() from ANY
-- screen, battle included, with no checkpoint gate at all -- and
-- Game2:writeSave (Game2.lua:858) is, by its own comment, the one place
-- every write the player can ask for goes through, the SAVE-menu row and F1
-- alike. M.install subscribes exactly the "save.write" veto that comment
-- exists for: while this module's own registry holds any active
-- substitution, a save attempt is refused outright rather than allowed to
-- serialize a slot mid-substitution, so there is no frame in which a
-- completed write can observe an id this module put there. Restoration on
-- every normal teardown path is still the primary defence; the veto is what
-- makes an abnormal one -- the dev hotkey, or a future seam shaped like it --
-- survivable too, rather than merely unlikely.
local M = {}

-- state -> true while that state's substitution is live, so more than one
-- consumer (a Dynamax picker and a Z-Move picker, say) can each own an
-- independent state while the veto below still answers for the union of all
-- of them. Deliberately NOT weak-keyed: a state a caller drops without
-- calling M.restore is a bug in that caller, and the failure mode has to be
-- "this table stays pinned in memory" rather than "the veto silently stops
-- protecting a mon that is still sitting mid-substitution" -- a leaked
-- handful of fields is a cost worth paying to keep the save-write refusal
-- honest even when something upstream of this module misbehaves.
local active = {}

function M.new()
  return { mon = nil, slots = nil }
end

function M.active(state)
  return state ~= nil and state.slots ~= nil
end

-- One slot's snapshot: the exact table object about to be mutated, its own
-- original index (restore re-checks the index rather than trusting order),
-- and the two fields this module ever writes.
local function snapshot(slot, index)
  return { object = slot, index = index, id = slot.id, maxPp = slot.maxPp }
end

-- `pick(slot, index)` answers with the fields to write onto that slot --
-- `id` at minimum, `maxPp` optionally for a substitute whose own PP maximum
-- differs from the move it is spending -- or nil/false to leave the slot
-- exactly as it is. Mirrors src/substitute.lua's own M.apply contract on
-- purpose, so a future picker (a Max Move catalog, a Z-Move catalog) can
-- hand either module the identical function without caring which game it
-- is running on.
--
-- Answers false when nothing was substituted, so a caller cannot end up
-- holding a state that M.active reports live but M.restore has nothing to
-- undo -- the same refusal src/substitute.lua's own M.apply makes.
function M.apply(state, mon, pick)
  if not state or state.slots then return false end
  local moves = mon and mon.moves
  if type(moves) ~= "table" or type(pick) ~= "function" then return false end

  local slots, any = {}, false
  for index, slot in ipairs(moves) do
    local fields = type(slot) == "table" and pick(slot, index) or nil
    if type(fields) == "table" and fields.id then
      slots[#slots + 1] = snapshot(slot, index)
      slot.id = fields.id
      if fields.maxPp ~= nil then slot.maxPp = fields.maxPp end
      any = true
    end
  end
  if not any then return false end

  state.mon, state.slots = mon, slots
  active[state] = true
  return true
end

-- Puts every slot this module actually altered back to what it was, but
-- only where that slot's table is still the one it altered -- see the
-- header on why a slot whose identity changed underneath this (a mid-battle
-- forget-and-learn) is left alone rather than clobbered.
--
-- Safe to call blind, the same contract src/substitute.lua's own M.restore
-- promises: an inactive state, or one that was never applied, is a no-op
-- rather than an error, since a disarm now runs down the same paths a
-- teardown does and every one of them has to be able to call this without
-- first asking whether there is anything to undo.
function M.restore(state)
  if not state or not state.slots then return false end
  local mon, slots = state.mon, state.slots
  state.mon, state.slots = nil, nil
  active[state] = nil
  if not (mon and type(mon.moves) == "table") then return true end

  for _, entry in ipairs(slots) do
    if mon.moves[entry.index] == entry.object then
      entry.object.id = entry.id
      entry.object.maxPp = entry.maxPp
    end
  end
  return true
end

-- Subscribes the "save.write" veto the header above argues for. Idempotent
-- like every other engine_internals patch in this codebase
-- (src/gen2forms.lua, src/menu.lua, src/boxmark.lua, src/formview.lua): a
-- second call finds the guard already set and subscribes nothing, so
-- repeated mod loads in one process cannot stack a chain of listeners
-- around themselves. Wrap-and-delegate, never capture: the vanilla writer
-- (or the next mod's own "save.write" link) still runs on every call this
-- module has no reason to refuse.
function M.install(mod)
  if M._installed then return true end
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    if mod and mod.log then
      mod.log:error("battle_forms: mod.hooks:wrap is unavailable -- a Gen 2 "
        .. "move substitution cannot veto a save attempt while it is live")
    end
    return false
  end
  M._installed = true
  mod.hooks:wrap("save.write", function(nextFn, ...)
    if next(active) ~= nil then return false end
    return nextFn(...)
  end)
  return true
end

return M
