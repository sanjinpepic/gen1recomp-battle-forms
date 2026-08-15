-- Z-Moves: the second consumer of src/substitute.lua, and the first
-- transformation here that changes neither the Pokemon nor the battler.
--
-- Section 9 of the implementation guide is unusually clear about what this is
-- NOT.  "Z-Moves are not Pokemon forms.  Do NOT do: Pokemon.form = Z.  Instead,
-- transform the selected move for that attack."  So there is no form, no stat
-- override and no type override -- the whole mechanic is that one of a
-- Pokemon's moves becomes something else for one use.  The guide's matrix says
-- the rest of it in four cells: changes form, no; persists a switch, N/A;
-- persists a faint, N/A; once per battle, yes.
--
-- What the guide does NOT say is everything a build needs.  It names no
-- crystals, no roster, no powers, no trainer item, and no answer to when the
-- substitution goes on or comes off.  Those decisions are below and each one is
-- marked.
--
-- WHY A CRYSTAL IS A TYPE AND NOT A MOVE.  The guide's one example is
-- Thunderbolt becoming Gigavolt Havoc "depending on the relevant Z-Crystal",
-- which is the real games' rule: a type crystal converts any damaging move of
-- its own type.  That is also the only rule this game can express.  A crystal
-- that named a MOVE would need a Pokemon to be told which of its four slots to
-- point at, and a Gen 1 party screen has nowhere to say so -- the same wall
-- src/tera.lua hit over the Tera type.  A crystal names a type, every damaging
-- move of that type in the moveset becomes that type's Z-Move, and the player
-- picks which one to actually use from the FIGHT menu, where they were going to
-- be picking anyway.
--
-- WHY THE STAMP IS THE ONE THERE ALREADY.  A crystal goes into
-- src/eligibility.lua's single stamp beside the mega stones and the orbs, so a
-- Pokemon holding a crystal is a Pokemon not holding a mega stone.  That is not
-- a compromise -- it is the held-item slot the real games have, and their rule
-- exactly: a Charizard wearing Firium Z cannot mega evolve, and the player
-- chooses which of the two it is going to be.  A second field would have meant
-- a second key in the save to express something the save already expresses.
--
-- WHEN IT GOES ON AND WHEN IT COMES OFF, which is the decision worth reading.
--
-- It goes on when the player ARMS the cell, not when the transformation
-- activates.  The activation lands at battle.turn_started, which the engine
-- raises AFTER both actions are chosen (BattleState.lua:2463-2469) and with the
-- move slot the FIGHT menu already handed over, so a substitution made there
-- cannot reach the choice it would have to replace -- which for one release
-- meant a Z-Move the player could not pick until the turn after they armed it,
-- and a plausible way to spend the battle's one transformation on nothing at
-- all.  Arming happens on the COMMAND menu, a step ahead of the move list being
-- drawn; src/arm.lua dispatches it and sets out the engine reads that make it
-- safe.  What still happens at turn_started is the announcement and the spending
-- of the trainer's one transformation, which is where those belong.
--
-- It comes off when it is USED and not before.  battle.move_used names the
-- move record the battler actually ran (BattleState.lua:3631, after the PP write
-- and before the effect), which is the only seam that can tell a Z-Move being
-- spent from any other move in the same list being spent; the unwind itself
-- waits for battle.turn_ended, so the substituted array is still standing for
-- everything the turn does with it.  Unused, it simply stands: there is no
-- clock to run out, and a player who armed a Z-Move and then spent four turns
-- on something else still has it.
--
-- It also unwinds on DISARMING -- a second A on the cell, or cycling away from
-- it with LEFT/RIGHT -- which is the path that only exists because arming is
-- when it goes on, and without which a player who armed a Z-Move and changed
-- their mind would take an unasked-for moveset into the turn.
--
-- And on switching out, on fainting and at both ends of the battle -- the same
-- four paths Dynamax unwinds on and for the same reason, which is that the
-- battler holding the substituted array must not outlive them.
-- Switching out ENDS it rather than following the Pokemon: the crystal belongs
-- to the mon that left, the mon arriving may be carrying a different one or
-- none, and re-deriving that on a send-out would be a second activation the
-- trainer never asked for.  The trainer's one manual transformation is spent
-- either way, which is the guide's "once per battle: yes".
local M = {}

M.ID = "zmove"

-- Every id this file registers wears the mod's name, for the reason
-- src/maxmoves.lua's does: "GIGAVOLTHAVOC" is precisely the id a future move
-- pack would reach for, and a collision is a load failure for whichever of the
-- two registers second.  The stems differ from the Max Moves' by construction --
-- theirs all begin MAX -- so the two rosters cannot collide with each other.
M.PREFIX = "BATTLE_FORMS_"

-- The PP every Z-Move record carries.  Five for the reason src/maxmoves.lua's
-- is five: the FIGHT menu draws its maximum off the record, and at 5 the
-- correction a substitute carries to make that maximum read the base move's is
-- a whole number.  The Z-Move itself has no PP of its own -- it spends the
-- slot's, which is what src/substitute.lua's alias arranges, and which is also
-- the honest answer, since the player used a turn of that move.
M.RECORD_PP = 5

local deps = nil

function M.bind(modules) deps = modules end

-- The registered id for a rung.  The power is in the id because the power is
-- what distinguishes one record of a type from another.
function M.idFor(stem, power)
  return M.PREFIX .. stem .. "_" .. tostring(power)
end

-- The Z-Move power a base power of `basePower` earns.  One ladder for every
-- type, unlike the Max Moves', which drops Fighting and Poison a rung.
function M.powerFor(rows, basePower)
  for _, rung in ipairs(rows.ladder) do
    if rung.upTo == nil or basePower <= rung.upTo then return rung.power end
  end
  return nil
end

-- id -> the FIGHT menu's own short name for it, one entry per rung of every
-- type the data carries a `menu` field for.  Every rung of a type shares that
-- type's one display name -- the rung changes power, not what the move is
-- called -- so this walks the same (type x rung) product M.install does
-- rather than reading anything install() built, and answers the same way
-- whether or not the running game's chart ever resolved the type: an id this
-- game never registered simply never appears in a curMoves array for the
-- lookup to find.
--
-- Never mixed into the registered record.  src/zmovemenu.lua is the only
-- reader, and only at the two places the FIGHT menu draws a move's name --
-- see data/zmoves.lua's own header for why `name` is not touched here.
function M.menuNames(rows)
  local out = {}
  for _, row in ipairs(rows.types) do
    if type(row.menu) == "string" and row.menu ~= "" then
      for _, rung in ipairs(rows.ladder) do
        out[M.idFor(row.stem, rung.power)] = row.menu
      end
    end
  end
  return out
end

-- The crystals, in the data's own order, for the two callers that register
-- items and stock a shelf.  Both need an array: pairs() over the index table
-- would reorder the shop between runs.
function M.crystalIds(rows)
  local out = {}
  for _, row in ipairs(rows.types) do out[#out + 1] = row.crystal end
  return out
end

-- Whether the merged type chart carries this type.  Guarded rather than
-- trusted, exactly as src/maxmoves.lua guards it: `get` is a registry courtesy
-- and a build that does not offer it must leave the Z-Moves out rather than
-- take the mod down with a nil call.
local function typeExists(mod, typeId)
  local registry = mod.content and mod.content.type_chart
  if not registry or type(registry.get) ~= "function" then return false end
  local ok, record = pcall(registry.get, registry, typeId)
  return ok and record ~= nil
end

-- Registers the roster and answers with the catalog the substitution reads:
-- which crystal turns on which type, and how to reach the right rung.
--
-- A type the running game's chart has no record for is skipped and SAID, the
-- way a missing Max Move is: `type` is a checked reference the merge resolves,
-- so registering BLACK HOLE ECLIPSE in a game whose chart stops at Red's
-- fifteen types would not cost one Z-Move, it would cost the whole mod.  The
-- crystal is still registered by the caller either way -- an item a save
-- carries has to stay nameable -- so what a player gets is a crystal that
-- refuses rather than a bag byte nothing can name.
function M.install(mod, rows)
  local catalog = { byCrystal = {}, rows = rows }

  for _, row in ipairs(rows.types) do
    if typeExists(mod, row.type) then
      local rungs = {}
      for _, rung in ipairs(rows.ladder) do
        if not rungs[rung.power] then
          local id = M.idFor(row.stem, rung.power)
          rungs[rung.power] = id
          mod.content.moves:register(id, {
            id = id,
            name = row.name,
            type = row.type,
            power = rung.power,
            -- A Z-Move never misses in the real games and there is no
            -- never-miss field on a move record to say so -- that lives on the
            -- effect, and borrowing one would take its effect with it.  100 is
            -- as close as a record gets, which under the faithful ruleset still
            -- leaves the cart's 1-in-256 miss.
            accuracy = 100,
            pp = M.RECORD_PP,
            effect = "NO_ADDITIONAL_EFFECT",
            -- `category` is deliberately absent, as it is on every Max Move:
            -- Gen 1 splits physical from special by TYPE and Damage.categoryOf
            -- falls through to the type record when a move does not say
            -- (Damage.lua:113-124).  It is also why the move data's split of
            -- each Z-Move into a physical and a special record collapses to one
            -- here -- this game has no way to tell them apart.
          })
          -- One animation per move id, because the id IS the animation key
          -- (BattleState.lua:3627).  A move with no sequence is not only
          -- silent to look at but silent to listen to: the rows carry the
          -- sound, and the engine skips its single-sound fallback once an
          -- animation has started.
          if deps and deps.anim then
            mod.content.battle_anims:register(id, { seq = deps.anim.zMoveSeq() })
          end
        end
      end
      catalog.byCrystal[row.crystal] = { type = row.type, rungs = rungs }
    elseif deps and deps.log then
      deps.log:warn(
        "battle_forms: no Z-Move for %s -- this game's merged type chart has "
          .. "no record for that type, which is what a Red-era chart looks "
          .. "like; %s is still sold and still stamps a Pokemon, but nothing "
          .. "it holds will convert",
        tostring(row.type), tostring(row.crystal))
    end
  end

  return catalog
end

-- The fields a substitute for `slot` should carry under `crystal`, or nil to
-- leave the slot alone.  nil covers four cases and all four are the same
-- answer: a move the registry cannot resolve, a move of another type, a status
-- move, and a crystal whose type this game never registered.
--
-- The status case is a deliberate omission rather than a gap.  A status move
-- under a crystal does not become a Z-Move in the real games -- it keeps itself
-- and gains an extra effect -- and there is no field on a move record here that
-- could say which effect, so the slot keeps itself and nothing is invented.
function M.fieldsFor(catalog, data, slot, crystal)
  local entry = catalog.byCrystal[crystal]
  if not entry then return nil end
  local def = data and data.moves and data.moves[slot and slot.id]
  if type(def) ~= "table" or def.type ~= entry.type then return nil end

  local power = tonumber(def.power) or 0
  if power <= 0 then return nil end
  local id = entry.rungs[M.powerFor(catalog.rows, power)]
  if not id then return nil end

  local ppUps = deps and deps.substitute
    and deps.substitute.menuPPUps(M.RECORD_PP, def.pp, slot.ppUps) or nil
  return { id = id, ppUps = ppUps }
end

-- The per-slot function src/substitute.lua takes.  Built per battle because it
-- closes over that battle's merged data, and per activation because it closes
-- over the crystal the Pokemon in front is carrying.
function M.picker(catalog, data, crystal)
  return function(slot)
    return M.fieldsFor(catalog, data, slot, crystal)
  end
end

-- Whether this battler has anything for that crystal to convert.  Asked by
-- `available` for the reason mega evolution asks whether its form record
-- exists: the menu must not promise a change the activation can only refuse.
function M.wouldConvert(catalog, data, battler, crystal)
  for _, slot in ipairs(battler and battler.curMoves or {}) do
    if type(slot) == "table" and M.fieldsFor(catalog, data, slot, crystal) then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------------
-- Z-STATUS: the bonus a status move keeps ON TOP OF its own effect when it
-- is the crystal's own type, rather than becoming a Z-Move.
--
-- M.fieldsFor already refuses to substitute a status move -- "the slot keeps
-- itself and nothing is invented" -- and that stands: nothing below changes
-- what a status move's own effect does or ever touches curMoves for one.
-- What follows is additive, layered on afterwards, and only for the one
-- shape of the real games' own bonus table this engine can build without
-- guessing: a status move that already raises one of the user's own stats.
--
-- WHY ONLY THAT SHAPE.  The real games hand every OTHER status move a bonus
-- picked off a fixed category table -- sleep-inducing moves get +1 Sp. Atk,
-- paralysis-inducing moves get +1 Speed, and so on through several more
-- categories with their own exceptions.  Reproducing that table case by case
-- would be this file inventing rulings for moves Gen 1 already has full
-- mechanical control over, with no source in this codebase to check any one
-- of them against.  A move that already raises the user's own stat needs no
-- such table: the real rule is simply "raise everything else too", which is
-- one rule, not a lookup, and it is what SELF_RAISE_STAT below encodes.
-- Every other status move keeps exactly what M.fieldsFor already gives it --
-- itself, unmodified -- which is honest rather than a guess dressed as one.
local SELF_RAISE_STAT = {
  ATTACK_UP1_EFFECT = "attack", ATTACK_UP2_EFFECT = "attack",
  DEFENSE_UP1_EFFECT = "defense", DEFENSE_UP2_EFFECT = "defense",
  SPEED_UP2_EFFECT = "speed",
  SPECIAL_UP1_EFFECT = "special", SPECIAL_UP2_EFFECT = "special",
  EVASION_UP1_EFFECT = "evasion",
}

-- Gen 1's six stat stages (src/battle/MoveEffects.lua's own STAT_LABEL keys).
-- HP has no stage and is never in this list.
local ALL_STATS = { "attack", "defense", "speed", "special", "accuracy", "evasion" }

-- The stat a status move of `moveId` already raises on its user, under a
-- crystal of `typeId` -- or nil, which covers everything that is not that
-- one shape: a move the registry cannot resolve, a move of another type, a
-- move that deals damage (power > 0, so it is M.fieldsFor's business and not
-- this one's), and a status move whose effect is not a self stat-raise.
function M.statusBonusStat(data, moveId, typeId)
  if not typeId then return nil end
  local def = data and data.moves and data.moves[moveId]
  if type(def) ~= "table" or def.type ~= typeId then return nil end
  if (tonumber(def.power) or 0) > 0 then return nil end
  return SELF_RAISE_STAT[def.effect]
end

-- Whether this battler carries a status move the crystal's type would bonus
-- -- asked by `available` alongside M.wouldConvert, for the same reason: a
-- Pokemon whose only move of the crystal's type is a self-raise status move
-- (no damaging move to substitute at all) still has something for the cell
-- to do, and the menu must not stay silent about it.
function M.wouldStatusBonus(catalog, data, battler, crystal)
  local entry = catalog.byCrystal[crystal]
  local typeId = entry and entry.type
  if not typeId then return false end
  for _, slot in ipairs(battler and battler.curMoves or {}) do
    if type(slot) == "table" and M.statusBonusStat(data, slot.id, typeId) then
      return true
    end
  end
  return false
end

-- The engine's own stat-stage math, reached the way src/zmovemenu.lua
-- reaches BattleState -- required defensively, because a mod's own file is
-- not guaranteed the shape it was built against forever.  Cached after the
-- first call; require() itself is cheap once loaded, but a build with no
-- engine underneath it (the unit suite drives this file with none) should
-- not pay for a failing require on every turn a status bonus might apply.
local moveEffectsModule, moveEffectsTried = nil, false
local function moveEffects()
  if not moveEffectsTried then
    moveEffectsTried = true
    local ok, found = pcall(require, "src.battle.MoveEffects")
    if ok and type(found) == "table" and type(found.changeStage) == "function" then
      moveEffectsModule = found
    end
  end
  return moveEffectsModule
end

-- Raises every stage but the one the move's own effect just raised, printing
-- the engine's own "X's STAT rose!" line for each -- the same text a Swords
-- Dance or an Agility already prints for its own stat, so the bonus reads as
-- more of the same rather than as this mod's own invention.  Silent and safe
-- on anything missing: no battle, no battler, or a build with no engine
-- MoveEffects to reach leaves the move's own effect as the whole of what
-- happened, which is the honest degradation and not a crash.
local function applyStatusBonus(bonus)
  if not bonus or not bonus.battle or not bonus.battler then return end
  local effects = moveEffects()
  if not effects then return end
  for _, stat in ipairs(ALL_STATS) do
    if stat ~= bonus.stat then
      for _, msg in ipairs(effects.changeStage(bonus.battle, bonus.battler, stat, 1, false) or {}) do
        bonus.battle:sayNext(msg)
      end
    end
  end
end

-- One record, like Dynamax's and Terastallization's and for the same reasons:
-- only the player's side can reach the menu cell and the trainer gets one
-- activation a battle, so there is never a second Z-Move to track, and one
-- record is one thing to drop when the battle ends.
--
-- `moves` is the substitution's own record and is created here rather than on
-- activation so that every teardown path can hand it to restore() blind,
-- including the ones that run when nothing was ever substituted.  `ids` is the
-- set of registered ids this activation put on, which is what tells a Z-Move
-- being used from any other move in the same list being used.
--
-- `statusType` is the crystal's own type, kept for the whole activation
-- rather than only while arming, because the Pokemon may use an UNCONVERTED
-- status move of that type on any later turn, not only the one it was
-- armed on -- an armed Z-Move simply stands, section 9's own rule.
-- `statusBonus` is set only once such a move is actually used, and only
-- until the turn ends, which is where it is spent.
function M.new()
  return { mon = nil, ids = nil, spent = false, statusType = nil, statusBonus = nil,
           moves = deps and deps.substitute and deps.substitute.new() or nil }
end

local function forget(state)
  state.mon, state.ids, state.spent = nil, nil, false
  state.statusType, state.statusBonus = nil, nil
  if deps.substitute then deps.substitute.restore(state.moves) end
end

M.onBattleStarted = forget
M.onBattleEnded = forget

-- `speciesCatalog` is src/speciesz.lua's own -- optional, the way
-- src/tera.lua's TERA BLAST catalog is: a build with no species rows bound
-- gets ordinary type-only Z-Moves, exactly what this cell has always been.
-- The two catalogs share this one cell rather than getting one each because
-- that is what the real games do -- a Z-Ring and any Z-Crystal, type or
-- species, work through the same interface -- and because the trainer's
-- once-per-battle lock and PP-spending discipline only need to exist once.
local function wouldConvertAny(catalog, speciesCatalog, data, mon, battler, crystal)
  if M.wouldConvert(catalog, data, battler, crystal) then return true end
  if M.wouldStatusBonus(catalog, data, battler, crystal) then return true end
  if speciesCatalog and deps.speciesz then
    return deps.speciesz.wouldConvert(speciesCatalog, data, mon, battler, crystal)
  end
  return false
end

-- The merged per-slot function: the type catalog answers first, since it is
-- the cheaper, more common case, and the species catalog is only ever asked
-- about a slot the type catalog passed over -- a slot can never match both,
-- since a species Z-Move's own type is read off the very move it replaces
-- (src/speciesz.lua's install), so if the type catalog already converted it
-- the id it produced belongs to a different crystal than the one in hand.
local function pickerAny(catalog, speciesCatalog, data, mon, crystal)
  local typePicker = M.picker(catalog, data, crystal)
  local speciesPicker = speciesCatalog and deps.speciesz
    and deps.speciesz.picker(speciesCatalog, data, mon, crystal) or nil
  return function(slot)
    return typePicker(slot) or (speciesPicker and speciesPicker(slot))
  end
end

function M.entry(state, catalog, speciesCatalog)
  return {
    id = M.ID,
    -- Seven characters is the whole budget the classic layout leaves a label
    -- once the armed '*' and the cycle marker have taken theirs
    -- (tests/battle_forms_menu_test.lua measures it).  Z-MOVE is six and is
    -- what the games call the mechanic, so there is nothing to shorten.
    label = "Z-MOVE",

    -- Two tiers, the trainer's before the Pokemon's, the way mega evolution
    -- asks them and unlike Dynamax and Tera, which rest on the trainer's item
    -- alone: no Z-Ring means no Z-Move whatever crystal the mon in front is
    -- carrying.  Failing here is how the gate stays silent -- the cell is
    -- simply absent rather than present and refusing.
    available = function(battle)
      if not deps.keyitems.held(battle, deps.keyitems.Z_RING) then
        return false
      end
      local battler = battle.player
      local mon = battler and battler.mon
      if not mon or not mon.species then return false end
      local crystal = deps.eligibility.stoneOf(mon)
      if not crystal then return false end
      return wouldConvertAny(catalog, speciesCatalog, battle.data, mon, battler, crystal)
    end,

    -- The whole of the mechanic, done at the moment the cell is armed so that
    -- the FIGHT menu the player is about to open already lists the Z-Move --
    -- the menu reads `curMoves` as it draws, so this is the last moment a swap
    -- is still ahead of the action being chosen.
    arm = function(battle)
      if not deps.substitute then return false end
      local battler = battle and battle.player
      local mon = battler and battler.mon
      local crystal = mon and deps.eligibility.stoneOf(mon)
      if not crystal then return false end

      -- The ids are collected from the picker's own answers rather than read
      -- back off the finished array, so a slot the picker passed over cannot
      -- later be mistaken for a Z-Move being spent -- which would end the
      -- substitution on a move that was never part of it.
      local picker = pickerAny(catalog, speciesCatalog, battle.data, mon, crystal)
      local ids = {}
      local applied = deps.substitute.apply(state.moves, battler, function(slot)
        local fields = picker(slot)
        if fields then ids[fields.id] = true end
        return fields
      end)

      -- A crystal whose ONLY match is a self-raise status move substitutes
      -- nothing at all -- M.fieldsFor leaves a status move exactly as it is,
      -- on purpose -- so `applied` alone would refuse arming here, and the
      -- cell would have promised something `available` already checked for.
      -- The type is kept either way applying succeeded or not, because the
      -- Pokemon may use an unconverted status move of it on a LATER turn too.
      local typeEntry = catalog.byCrystal[crystal]
      local statusType = typeEntry and typeEntry.type
      if not applied and not (statusType
          and M.wouldStatusBonus(catalog, battle.data, battler, crystal)) then
        return false
      end

      state.mon, state.spent, state.ids, state.statusType = mon, false, ids, statusType
      return true
    end,

    -- Everything arming set, in one call, because that is what forget() is.
    disarm = function() forget(state) end,

    -- By here the moves are already substituted -- or, for a crystal whose
    -- only match is a self-raise status move, deliberately left alone -- so
    -- this says the sentence and answers whether the battle's one
    -- transformation was actually spent.  `state.mon` is the signal rather
    -- than `deps.substitute.active`, because a status-only activation never
    -- makes the substitution active at all: arm() still succeeded and still
    -- set state.mon, and that is what a refusal here must not cost the
    -- player who armed in good faith.  A mon that left the field between
    -- arming and the turn resolving took its Z-Power with it either way.
    activate = function(battle)
      if not state.mon then return false end
      local battler = battle and battle.player
      if not battler or battler.mon ~= state.mon then return false end
      if deps.announce then deps.announce.zPower(battle, battler) end
      return true
    end,
  }
end

-- The Z-Move being spent.  `ev.move` is the record the engine ran, so the id
-- test is against what was actually used and not against what the menu was
-- showing; `ev.user` is the battler, compared on its MON because that is the
-- identity a switch does not replace.
--
-- Marks rather than unwinds.  The effect, the damage and everything else the
-- turn does with this move all run after this event, and pulling the array out
-- from under them would be this mod reaching into the middle of a move.
--
-- ALSO marks the Z-status bonus, the second and last thing this event can
-- spend the activation on: a move NOT among the substituted ids, used while
-- `statusType` names a type, is checked against M.statusBonusStat the same
-- way M.wouldStatusBonus already previewed it might be.  The two branches
-- are mutually exclusive by construction -- a substituted slot's id is never
-- also a status move's own id -- so at most one of them ever marks anything
-- in a turn, matching "one move, once" for either kind of bonus this cell
-- can spend on a status move.
function M.onMoveUsed(state, ev)
  if not state.mon or state.spent then return end
  local user = ev and ev.user
  if not user or user.mon ~= state.mon then return end
  local id = ev.move and ev.move.id
  if not id then return end

  if state.ids and state.ids[id] then
    state.spent = true
    return
  end

  if not state.statusType then return end
  local battle = ev.battle
  local stat = M.statusBonusStat(battle and battle.data, id, state.statusType)
  if not stat then return end
  state.statusBonus = { battler = user, battle = battle, stat = stat }
  state.spent = true
end

-- One move, once: the turn a Z-Move was used on is the last turn it exists for.
-- battle.turn_ended is the seam src/dynamax.lua counts on and for the same
-- reason -- it fires even on the turn a battle is decided.
--
-- The status bonus applies HERE rather than at M.onMoveUsed, because that
-- event fires before the move's own effect resolves (BattleState.lua:3631,
-- before the PP write's sibling call into the status pipeline) and Gen 1's
-- status-move pipeline has no hook after it -- see applyStatusBonus's own
-- header.  The bonus therefore prints after the rest of the turn's text
-- rather than immediately following the move's own "X's STAT rose!" line,
-- which is a later line, not a wrong one.
function M.onTurnEnded(state)
  if not state.spent then return end
  applyStatusBonus(state.statusBonus)
  forget(state)
end

-- Switching out ends it.  `previous` is the OUTGOING battler, captured whole
-- before makeBattler replaces it, so the mon that just left is previous.mon --
-- ev.battler is the one arriving and is the wrong end of this event to read.
--
-- Silent, like Dynamax's switch-out and for the same reason: the mon is off the
-- screen by the time this runs and the engine is part-way through its own
-- send-out text.
function M.onBattlerSwitched(state, ev)
  local mon = ev and ev.previous and ev.previous.mon
  if not mon or state.mon ~= mon then return end
  forget(state)
end

-- Fainting ends it.  Nothing here marks the mon, so there is no form for
-- src/resolve.lua's faint handler to collide with -- the array is all there is
-- to put back, and the battler it belongs to is the one in hand.
function M.onFainted(state, ev)
  local mon = ev and ev.battler and ev.battler.mon
  if not mon or state.mon ~= mon then return end
  forget(state)
end

return M
