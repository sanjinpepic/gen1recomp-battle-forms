# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

## 0.75.2

### Fixed

- **The transformation cell never appeared on Gold or Crystal.** `src/gen2menu.lua` never adopted the battle it was drawing over, so the arm state answered about whichever battle it had cached instead. `src/overlay.lua`'s `offered` asks `entry.available(battle)` about `state:current()`, so mega read a different fight's `battle.player` and a different `battle.save` for the Key Stone -- and reported nothing available for a Charizard holding the stone in the fight on screen. The diagnostic had been saying so all along (`armState=another battle ... offered=0`). The Gen 2 menu now adopts the live battle the way Gen 1's has since adoption existed.

## 0.75.1

### Fixed

- **Gold's Max Move menu drew two names to a row and hid the cursor.** The redraw wiped at tile 2 -- the forget-move screen's column, not the FIGHT menu's tile 6 -- so the real name stayed put, the short name landed beside it, and the rectangle's left edge covered the cursor gutter at tile 5.
- **Long names left a tail the wipe could not reach**: `RE` from G-MAX WILDFIRE, `M` from MAX AIRSTREAM. No width fixes that -- the name field ends at tile 18 and the box border is tile 19, which a fourteen-character name overruns. The short name is now swapped in before the vanilla draw and restored after, so the engine prints it itself and the module hard-codes no geometry.

## 0.75.0

### Changed

- **Items are called what they are called.** Every item this mod registers was named by machine -- `NORMALIUM_Z` rendered as "NORMALIUM Z", `TERA_SHARD_FIRE` as "TERA SHARD FIRE" -- across five registration sites and roughly two hundred items. The National Dex's item catalogue (0.31.0) now supplies the real ones: "Normalium Z", "Fire Tera Shard", "Charizardite X", "DNA Splicers".
- **Twenty-nine mega stones deliberately keep the old name**, and that is the point of the exercise rather than a gap in it. Baxcaliburite, Glimmoraite, Barbaraclite and the rest are for megas that do not exist in the real games, so no catalogue has them and none ever will. A resolver that answered something anyway would be worse than the name it replaced: a wrong name that looks official is harder to spot than a shouty one. The same holds for the byteless TMs and the Stellar Tera Shard.
- **Nothing is required.** No National Dex, a dex older than the catalogue, or an item it has never heard of, and the machine-derived name stands exactly as it always did.

### Notes

- **Translated on the way out, never renamed.** An item id here is not a label: `mon[eligibility.STAMP] = itemId` writes that exact string onto a Pokemon and persists it, so renaming `NORMALIUM_Z` to match PokeAPI would leave every stamped Pokemon in every existing save holding an item that no longer exists. `data/crystals.lua` already said this about the bag BYTES; the id string has the same property and had no comment saying so. It does now.
- **Three rules rather than a table of two hundred rows.** PokeAPI splits one physical item into several records by function -- `electrium-z--held` and `--bag`, `n-solarizer--merge` and `--split` -- and puts a Tera Shard's words in the other order. Exact match is always tried first, because a suffix rule that fired ahead of it could answer with the bag form of an item whose held form is the real one, and both exist.
- The dex handle is resolved once at load rather than per item: two hundred registrations happen in a row, and a lookup on each is two hundred lookups for one answer that cannot change in between.

## 0.74.0

### Added

- **Eternatus can never use a transformation, and neither can its Eternamax shape.** That shape exists for one scripted fight -- wild_forms' own two-phase encounter -- and is not a Dynamax anybody performs. A caught Eternatus that could then Dynamax, Terastallize or hold a Z-Crystal would hand the player an ordinary route to a Pokemon whose whole characterisation is that the transformation is not theirs. `src/eligibility.lua` names the bar, keyed by species AND by form id because both get asked: the caught Pokemon is `ETERNATUS`, the battle-only shape is `ETERNATUS_ETERNAMAX`.
- **The bar is asked in all three places that decide whether a gimmick is on offer** -- the player's own menu cell, the outward-facing API, and the enemy trainer's choice -- rather than inside the five mechanics. A rule enforced in one of those and not the others is a rule that holds until somebody uses the other door: the menu would refuse while a peer mod's Gimmicks button still offered it, or an enemy trainer used one on a Pokemon the player never could.

## 0.73.1

### Fixed

- **The read API could not see an enemy's Terastallization or Dynamax.** `describe(mon)` takes a Pokemon rather than a side, precisely so a peer can ask about anything on the field -- but it was bound with the player's single state, under a comment explaining why that was safe: "only the player's own side can transform here, so there is never a second Terastallization or Dynamax to tell this one apart from". Enemy trainers transform now, so there is, and a consumer asking about an opposing Pokemon mid-Terastallization was told it had none. Both sides' states are passed now and the lookup resolves whichever claims the Pokemon asked about, so an enemy's type, its turns left and its Gigantamax form all come back the same way the player's do. A single state is still accepted, since the module is handed one by its own suite.

## 0.73.0

### Added

- **Every transformation now shows a tag for as long as it stands, not just Terastallization.** `MEG`, `DYN`, `GMX`, `ZMV`, and the Tera type's own three letters, in the level slot the type tag has used since 0.65.0 -- on the player's side and the enemy's. The gap this closes is Dynamax on Red: Gold's grows the picture visibly (`src/gen2dynamaxgrow.lua`), but Red has no draw-time scaling seam at all -- `frontSize` is read once at ROM-import time and `battle.overlay` fires after the battler is already drawn -- so a Dynamaxed Pokemon there stood in its own unchanged shape, and once the message scrolled away nothing said it still was one. The five can never contend for the space: the trainer's shared once-per-battle rule means a Pokemon wears one of them.
- **A Gigantamax says `GMX` where a plain Dynamax says `DYN`.** It genuinely is a different shape and the picture already shows that much; a player looking at an unfamiliar silhouette is exactly who wants to know which of the two they are facing.
- **A mega evolution is told apart from every other form by the pairing table that defines them.** A Gigantamax, a persistent held-item form and a condition-driven form all set the same `form` field, so "is this a mega" is asked of `data/megas.lua` rather than guessed from the field being set -- a Giratina in its Origin form wears no tag, which is correct: nothing the trainer did put it there.

## 0.72.0

### Added

- **An enemy Terastallization now shows itself for as long as it stands.** It was the only one of the four transformations with no visible trace: a mega changes the sprite, a Dynamax grows it, a Z-Move names itself as it fires, and a Terastallization did nothing at all once its message had scrolled away -- which is the same reason the player's own three-letter type tag exists. The tag is drawn in the enemy's own level slot, which is not the same tile on the two games and was read off each engine rather than assumed from the player's: Red puts `<LV>` at tile (4,1) and left-aligns the digits after it, Gold pins the glyph to column 6 whatever the level is. A status tag still wins that space on both, the same way it wins the player's.
- **Big fights take the strongest gimmick on offer rather than rolling for one.** A gym leader, an Elite Four member or a rival is the wall a player prepares for, and dice in that fight make preparation pointless. Ordinary trainers keep the weighted pick, so a route stays varied and a bug catcher does not pull the single best transformation every time. Which one counts as strongest is a ranking in the data block and is meant to be edited: a Dynamax doubles HP as well as boosting moves, a mega evolution is a stat and typing change for the whole battle, a Z-Move is one enormous hit and then nothing, a Terastallization moves typing around without adding a stat point.

### Fixed

- **A rematch used to re-roll the leader's gimmick.** Gold numbers its repeat encounters -- `CLAIR1`, `CLAIR2` -- and the seed was taken from the raw id, so meeting a trainer a second time could produce a different transformation. That is precisely the re-rolling the seed exists to prevent: a fight that changes every attempt cannot be learned. The trailing number is dropped, so a rematch is the same trainer.

## 0.71.0

### Fixed

- **An enemy Z-Move was offered and could never happen.** A Z-Move needs a crystal ON the Pokemon -- `mon.item` on Gold, this mod's own stamped field on Red -- and engine trainer parties are the ROM's own data and hold no mod items. The Z-Move was nonetheless offered whenever the mechanic was wired at all, so the weighted roll could pick it, the activation would refuse, and the trainer lost its transformation for that turn with nothing said. A crystal is now resolved from the ace's own strongest damaging move and stamped before the mechanic is asked -- the same reading the Key Stone gets, that a trainer who owns the ring equipped their Pokemon before the battle -- and the Z-Move is offered only where such a crystal exists.

### Added

- **A README, with a short section on how the enemy's transformations work** -- when they unlock, which trainers get one, which Pokemon, how the gimmick and the Tera type are chosen, and which items are resolved rather than required.

## 0.70.0

### Added

- **Holding any one of the four key items now opens all four to the enemy, rather than only its own.** Gating each gimmick on its own item was perfectly symmetric and played badly: the Key Stone is almost always the first of the four a player gets, so the entire early game would have been mega evolutions and nothing else -- and mega evolution reaches 86 species, which on Gold leaves ten of the fourteen gym leaders and Elite Four unable to do anything at all. The reading now is that the player has entered the era where trainers do this sort of thing, rather than that they licensed one specific mechanic. A gimmick is still only ever offered where the ace can actually use it, so this can never announce a transformation that does not happen, and the strict behaviour remains available as `GATE_MODE = "per_gimmick"`.

### Fixed

- **A mega evolution on Gold changed the sprite and printed nothing.** The two games announce through channels that are not interchangeable: Red's `announce.mega` takes a BATTLER and queues through `push`, while Gold's `announce.gen2Mega` takes a MON and goes through `Battle:emit` -- `src/mega.lua`'s own header records why they differ. The enemy path called only Red's, so on Gold the opposing Pokemon transformed, the sprite changed, and it simply attacked with no line explaining what had happened. Each game's own channel is used now, and each names its own side: Red's `displayName` puts "Enemy " in front of a battler whose `isPlayer` is false, Gold's `gen2Name` asks the engine's own `monName`. The other three gimmicks were never affected -- they announce from inside their own `activate`, which already branched per generation.

## 0.69.0

### Added

- **Enemy trainers now reach for all four gimmicks, not just mega evolution.** Terastallization, Dynamax and Z-Moves join it, each gated on the player holding its own key item exactly as mega evolution is gated on the Key Stone. This is what the state widening in 0.68.0 was for, and it matters most on Gold: mega evolution applies to 86 species and the Johto aces mostly are not among them, so only four of the fourteen gym leaders and Elite Four could ever have used one -- Morty, Jasmine, Karen and Lance. Terastallization and Dynamax apply to every species, so every one of them can now do something.
- **Each of the three runs the mechanic's OWN code rather than a copy of it.** A second entry is built per mechanic against the enemy's own state and handed a view of the battle whose player slot holds the enemy's battler; reads fall through to the real battle and writes land on it, so a message queued during the activation is queued where the player will see it. Reimplementing the activations here would have been a fork that silently diverged the first time one of them was fixed -- and each does real work, announcing, substituting the move array, seeding its state and branching per generation.
- **The enemy's Tera type is chosen, never derived.** The player's comes from their Pokemon's own DVs, which is right for a Pokemon they raised and wrong for an opponent: a random type is frequently WORSE than the typing the Pokemon already has, and a Terastallization that downgrades its user is a threat on paper and a gift in practice. The enemy's takes the trainer's brand where the ace can use it -- and the brand is derived from the trainer's own party rather than a table of gym types, so Clair's three Dragonair and a Kingdra make Dragon and Morty's Gastly line makes Ghost -- then the type of the ace's strongest damaging move, then its own typing. No step can pick a type the Pokemon has no use for. The choice reaches the unchanged mechanic as a stamp on the Pokemon, which `src/teratype.lua` already prefers over its DV derivation; an enemy party is rebuilt from trainer data every battle, so the stamp is never saved.

### Notes

- An enemy Terastallization announces itself but has no persistent on-screen tag yet. `src/teraview.lua` paints its three-letter type marker at one slot -- the player's level position -- and the enemy's HUD has its own coordinates on both games. The announcement scrolls away, which is the exact reason that tag exists for the player, so this is worth closing.

## 0.68.2

### Fixed

- **Every Gold gym leader read as an ordinary trainer and rolled its one-in-four.** Gold hands a battle the INNER trainer record -- the one keyed `KAREN1` beneath the `KAREN` class, as `class.trainers[1]` -- so the `class` field the gym-leader test needs is frequently absent and the id carries a trailing member number instead. `Battle.isGymLeader(nil)` is false, so Karen, Morty, Jasmine and the rest were treated as bug catchers: eligible, but only a quarter of the time. Class, classId, the raw id and the id with its trailing number stripped are all tried now.

### Added

- **The mod now says why an enemy did nothing, once per battle.** "The enemy declined" and "the enemy was never asked" look identical on screen, and telling them apart by playing has cost two rounds of blind fixes. A single line per battle records the trainer, the gate that stopped it, the ace's species, whether the trainer counted as a big fight and whether anything was unlocked -- enough to name the cause without another playtest.

## 0.68.1

### Fixed

- **Nothing fired on Gold or Silver, again, and for a second reason.** 0.67.1 fixed the trainer id, which Gold spells `class`/`classId` where Red spells `id`. The gate behind it was still Red's: Red's `BattleState` sets `self.kind` to "trainer" or "wild", and **Gold's `Battle` sets no such field at all** -- every `kind` in that class is a damage kind or an action kind and has nothing to do with what sort of battle this is. So `battle.kind ~= "trainer"` was false for every Gold battle ever fought, and the first guard rejected all of them before anything else ran. On screen that is indistinguishable from a trainer simply not qualifying, which is how it survived a playtest. The trainer RECORD is what both games agree on -- a wild battle has none -- so that is what is tested now, with Red's explicit `kind` still honoured where it exists.

## 0.68.0

### Added

- **An enemy mega evolution now says so.** 0.67.0 changed the form and printed nothing, so an opposing Pokemon silently became a different one mid-battle with no line explaining it -- the player could see a new sprite and had no way to know what they were now facing. It announces through the mod's own `announce.mega`, which names whoever it is handed: `displayName` puts "Enemy " in front of a battler whose `isPlayer` is false, and the text box was sized for exactly that case ("Enemy " plus a ten-character nickname plus "'s" is eighteen characters, the width of a Gen 1 row). The line is printed only after the form actually changed, never before, so a refused transformation cannot announce one that did not happen.

### Fixed

- **Stellar was a single slot, and enemy Terastallization would have made two Pokemon fight over it.** `src/stellar.lua` kept one `{ mon, spent }` for the whole battle, under a comment explaining why it never needed keying: "only the player's side reaches the menu and there is one Terastallization a battle, so there is never a second to track." That stopped being true. It is now keyed by Pokemon, with weak keys so a mon nobody explicitly cleared cannot be held alive by the table, and `clear()` takes an argument: one Pokemon on teardown, or every one when called bare, which is what battle start wants. `src/tera.lua` captures the mon before emptying its slot, because clearing blind would have taken the other side's boosts.
- **The same single-side assumption ran through the display path.** `src/hpscale.lua` scaled the Dynamax HP bar from one state "because only the player's own side can Dynamax here", and `src/teraview.lua` read one state for its type tag. Both now accept either one state or a list and resolve whichever claims the Pokemon being drawn, so neither side's transformation can be painted from the other's record.
- **Every per-battle gimmick state is now two.** Terastallization, Dynamax and Z-Moves each keep one record per side rather than one per battle, and all fifteen lifecycle handlers -- battle started, battler switched, move used, turn ended, fainted, battle ended -- run for both. No mechanic needed changing to allow it: every one of those states was already passed to its handlers as a parameter and captured nowhere.

### Notes

- The enemy still only reaches for mega evolution. The state work above is what unblocks the other three, but their activation paths and the enemy's Tera type selection are not wired yet. `src/trainerai.lua` carries the type chooser -- the trainer's brand derived from their own party, then the type of the ace's strongest damaging move, then its own typing, so the choice can never be a downgrade -- and it is tested, but nothing calls it yet.

## 0.67.1

### Fixed

- **The feature did nothing whatsoever on Gold and Silver, and said nothing about it.** Red's `BattleState` stores the trainer record under `id` (`OPP_BROCK`); Gold's `gen2/Battle` stores the class under `classId`/`class`. 0.67.0 read only `id`, so every Gold trainer battle exited at the first gate as "no trainer id" -- no enemy ever reached for anything, on either of that game's two versions, with nothing logged and nothing on screen to distinguish it from a trainer simply not qualifying. All four spellings are read now.
- **The two games answer "is this a big fight" in completely different places.** Red keeps an `ai_classes` registry of eighteen `OPP_*` records and hands it to `TrainerAI.classFor`. Gold has no such registry for its own roster: it carries `Battle.GYM_LEADER_CLASSES` and tests it with `Battle.isGymLeader`. A mod's `require` is not redirected on a Gold boot, so asking for the Gen 1 module there loads real code that reads a table Gold never fills -- every Johto gym leader would have come back ordinary and rolled its one-in-four like a bug catcher. Each game is now asked its own question.

## 0.67.0

### Added

- **Enemy trainers now reach for a gimmick of their own, once you can too.** Every transformation this mod adds was the player's alone: a trainer with a Key Stone could mega evolve their ace and the gym leader across from them never did, which made the whole mod a difficulty reduction and left the big fights playing exactly as they had before it was installed. The new TRAINER GIMMICKS option -- on by default -- gives the enemy's strongest Pokemon one, and the gate is the item already in your own bag. `src/keyitems.lua` models the outer tier the real games use, so holding the Key Stone is what unlocks your access; it now unlocks theirs at the same moment. Nothing new is tracked, the gate is per gimmick rather than global, and it moves on its own if those items are ever sold somewhere else.
- **Which trainers is the engine's own opinion rather than a list kept here.** `data/scripts/ai_classes.lua` holds eighteen records -- seven Kanto gym leaders and Giovanni, the Elite Four, Rivals 2 and 3, and four tough ordinary classes -- and exists because those trainers get smarter move choice and item use. A trainer with one always qualifies; everybody else rolls one in four. Reusing that registry means the tier tracks whatever the engine adds and costs nothing to maintain.
- **The pick is seeded from the trainer, not rolled, and that is deliberate.** Availability is very uneven -- Tera and Dynamax apply to every species, mega evolution to 86 -- and the Kanto gym aces are precisely the species with famous megas, so a straight "best fit" would have turned every important fight into a mega evolution. Instead the choice is a weighted roll over what that Pokemon can actually do, seeded from the trainer's own id: Brock always megas, Blaine always reaches for the same thing. A hard fight that does something different on every attempt is arbitrary; one that always does the same thing can be learned. The variation lands across the roster rather than within a single trainer. The same seed picks between a species' two megas, so a given trainer's Charizard is always the same one.
- **The enemy's ace is not required to hold a stone.** Engine trainer parties are the ROM's own data and carry no mod items, so requiring a real Mega Stone would have meant the feature never firing. The trainer-side item is the whole requirement, and the reading is that a trainer who owns a Key Stone equipped their ace before the battle.

### Fixed

- **The enemy's gimmick can never spend the player's.** `src/arm.lua` holds ONE once-per-battle flag for the battle rather than one per side, so routing an enemy activation through it would have taken the player's allowance with it -- they arm their mega, the gym leader moves first, and their own cell is dead for the rest of the fight with nothing said. The new module keeps its own flag and never calls an entry's `activate()`, which is meant to run at `battle.turn_started` where `src/resolve.lua` pairs it with `consume`. A refused form change does not spend either flag, the same rule the player's path already keeps.

### Notes

- This first slice is **mega evolution only**, and the reason is not obvious from the outside: of the four gimmicks, three keep single-slot per-battle state. `zmoves.new()`, `tera.new()` and `dynamax.new()` each return one record for the whole battle plus one shared move-substitution object, so an enemy activation landing after the player's would overwrite that slot and silently unwind theirs -- and tera's teardown additionally reaches a global Stellar table that a second instance would not dodge. Mega evolution keeps nothing: it writes a form onto the Pokemon and its internals already take a battler. Widening that state from one side to two is a real refactor across three files and is worth doing on its own rather than underneath a new feature. The data block carries the other three rows, commented with their reason, and a test pins their absence so re-enabling one is a deliberate act.

## 0.66.0

### Added

- **A mod drawing its own battle scene can now offer the gimmick menu, which until now only this mod's own cell could.** That cell is bolted to the native screen's layout, so a peer replacing the screen had no way to reach it and no way to ask what was on offer. `mod.exports.gimmicks(battle)` answers the same three facts the cell reads -- id, label, and whether each is armable right now -- and `mod.exports.arm(id)` / `mod.exports.armed()` arm and report, the same way the player's own cell does. `api` stays 1: these are added fields, and a reader that ignores them cannot be broken by them.
- **They hand out copies and a toggle, not the registry and the arm state.** Publishing those two objects was the obvious shape and is the wrong one. `Registry:register` would let a peer add a transformation to the player's menu, and `Registry:all()` returns the live list whose ORDER is the order the cell cycles in -- so a peer that sorted the rows it was handed would reorder somebody's menu. `available` is resolved to a boolean here for the same reason: the entry's predicate closes over this mod's internals, and a peer holding the function could call it against anything. A predicate that raises reports the entry unavailable rather than taking the peer's scene down.
- **Arming is the external verb, and activation deliberately is not.** `src/resolve.lua`'s `onTurnStarted` is the only caller of an entry's `activate` anywhere in this mod, and it pairs it unconditionally with `state:consume(id)` -- the one place the once-per-battle limit is recorded. An external `activate()` would therefore transform a Pokemon without spending the flag, and the same trainer could arm a second one, which is the single rule this registry exists to enforce. `arm()` toggles and leaves the activation to the listener every native battle already goes through.
- **`arm()` refuses an id nothing registered, which the internal path never had to.** `State:toggle` checks the id's type and its spent flag but never asks whether anything registered it, because every internal caller took the id off the cell it was already drawing. `arm()` is the one door an id can arrive through from outside, so it is the one place that has to ask -- without it a peer's typo sticks in `armedId`, and `onTurnStarted` resolves it to nil and quietly does nothing for the rest of the battle.

### Fixed

- **`.modkit/pack.json` is now ignored, because a copy in the source tree is always a lie.** `tools/modpack.py` writes that file into the archive at package time, computed from the files actually going in. A copy in the working tree arrives by unpacking a release zip and using it as a checkout, and it describes that zip's files rather than these -- so it is stale from the moment anything is edited, and the packager overwrites it regardless.

## 0.65.0

### Added

- **A Terastallized Pokemon now says so for as long as it lasts, where before the activation message was the only thing that ever marked it.** No form, no picture, no name change and no animation was a defensible answer while the Tera type was a mod option the player had set themselves -- they knew what they picked. It stopped being one in 0.60.0, when the type became a property of the Pokemon derived from its own DVs: a player can now genuinely not know what their Charizard turned into, and once the text scrolled away nothing on screen would tell them. A three-letter tag -- `WTR`, `DRG`, `STR` for Stellar -- now sits where the level does for as long as the Terastallization stands, on Red and on Gold. Built through `battle.overlay`, the same draw-only seam the scaled Dynamax HP numbers are painted through: it repaints over an already-composited HUD, holds no state the draw path could disagree with, and calls the rest of the overlay chain first and unconditionally, so another mod's overlay still runs whether or not a Terastallization is live.
- **The slot is the level's, which is not an invention.** Both games print the level at the same tile and both already hand that exact slot to a three-character status tag when a Pokemon is poisoned or burned -- so this shows something other than its default in a place the engines themselves treat as swappable, at a width they chose. The name row was the other candidate and was rejected: the nickname is right-aligned into its tiles, so the gap in front of it exists only for short names and closes the moment somebody names their Charizard CHARIZARD. An indicator that collides with the name it prefixes, depending on how long that name is, is worse than no indicator.
- **A status tag wins the slot, and the Tera tag stands down.** The engines have already decided that space belongs to the status, and being told a Pokemon is paralysed matters more in the moment than being reminded what it terastallized into. The cost is that the tag is invisible on a statused Pokemon, which is written down here rather than left to be discovered. One other collision is worth knowing: `PSN` is the tag for a Poison Tera type and is also the poison status tag. The two can never be on screen at once, since a status suppresses this entirely, but a player who sees `PSN` where the level was is looking at a Poison-Tera Pokemon rather than a poisoned one.

## 0.64.0

### Added

- **Terastallization and Dynamax are on the outward-facing API now, and the Tera type a Pokemon carries can be asked for without a battle.** 0.63.0 said outright that neither fired: a Terastallization applies no form and no stat block -- it overrides typing alone -- and a plain Dynamax scales the HP bar and nothing else, so neither ever reached the two form primitives that fire `form_applied`. They still do not. They have their own names instead: `mod.battle_forms.tera_applied` and `tera_reverted`, `dynamax_applied` and `dynamax_reverted`, all handed out through the exports beside the two form names so a consumer subscribes to a value rather than a string it retyped. Folding them into the form events was the other option and was rejected: it would have handed a consumer a payload with a nil `form`, a nil `formId` and stats the Pokemon already had, which is shaped exactly like a bug in this mod rather than like a Terastallization. A Gigantamax now fires on both channels, which is correct -- it really is a Dynamax and a form record, and two things happened.
- **Four fields, and the split between them is the point.** `teraType` and `dynamaxLevel` are properties of the Pokemon, so they answer from a party screen, a PC box or a summary page with no fight anywhere -- which is what a consumer drawing a stats row actually needs, and what the live records can never give it. `tera` and `dynamax` are the live per-battle records and are nil unless something is standing right now: `tera` names the type it is terastallized into and breaks out `stellar` separately, because Stellar is the one Tera type that changes no typing at all and a reader deciding whether to redraw a type badge should not have to know why; `dynamax` carries the turns left on the clock and the Gigantamax form, where a nil form is what makes it a plain Dynamax. All four are additive, so the payload version stays at 1 -- a reader that ignores a new field cannot be broken by one, which is the rule this API set for itself.
- **The dataset is remembered rather than demanded.** Answering `teraType` means resolving a species' own types against the running chart, and the mod api hands a mod no handle to the merged data -- it arrives as an argument to the two form primitives and on a battle. So the last one seen is kept and every reader falls back to it. A consumer that asks before this mod has been handed one gets nil rather than a wrong answer, which is the honest failure: until something supplies the dataset, this mod genuinely does not know what types a species has.

## 0.63.0

### Added

- **Another mod can now be told what form a Pokemon is wearing and what stats came with it, rather than watching `mon.form` every frame and guessing.** Everything this mod said until now it said inwards -- a line for the player, a line for whoever was chasing a bug, and `bind()` between its own files -- so a peer that wanted to react to a mega evolution had two bad options: poll a field documented here as internal and diff it, or reimplement this mod's own pairing tables to work out what a form change was about to do. The second is how two mods drift into disagreeing about one Pokemon. There are now two channels, and they are the two the engine already sanctions. `mod.events` carries `mod.battle_forms.form_applied` and `mod.battle_forms.form_reverted` the instant a form takes effect or comes off, and `mod.find("battle_forms").exports` carries `describe(mon)`, which answers the same question for a Pokemon that changed before the asking mod ever loaded -- a screen drawn long after the event fired has no event to have heard. Both answer in one payload shape, so a consumer writes one reader and points it at either: the live Pokemon, its base species (which never moves for a form change), the form marker a sprite mod resolves art from, the National Dex record the numbers came from, the stats and types it is fighting with, and which generation's stat keys those are -- Red collapses the two special stats into one where Gold splits them, so the key set is the running game's own rather than a fixed list this mod would be wrong about on one of them. The payload carries its own version, because a shape other people's code reads is a contract and the honest way to widen one later is to say which shape this is. Stats and types are handed over as copies: they are the tables battle math reads every turn, and a peer normalising a payload for its own use must not be able to rewrite the Pokemon standing on the field.
- **The announcement is fired from the two form primitives rather than from the mechanics, so a form nobody outside hears about is not something a later mechanic can add.** Mega evolution, primal reversion, the persistent held-item forms, the fusions, Ultra Burst, Gigantamax and the eight condition-driven forms are eight modules with a dozen call sites between them, and every one of them ends in `src/forms.lua`'s `becomeForm` on Red or `src/gen2forms.lua`'s on Gold -- those two functions *are* the form change, and a ninth mechanic added later is announced by the same primitive it has to call anyway to work at all. The cost, stated rather than papered over, is that a primitive cannot name which mechanic asked, so the payload does not pretend to; it names the form, which is what a consumer wanted. Both announcements are fired after the stats and types are written, never before, so a listener reading straight off `payload.mon` sees the same world the payload describes -- which is also why the revert path had to be split: reverting through the battler used to clear the marker by calling the party sweep's own function, and announcing from in there would have described the Pokemon's out-of-battle stat block while the battler was still holding the form's. Nothing about a form change depends on any of this working: an unbound primitive applies a form exactly as it always did, and an emit the loader refuses answers false and is complained about once rather than once per form change.
- **A Terastallization and a plain Dynamax deliberately fire nothing, and that is worth knowing before building on this.** Terastallization applies no form and no stats -- it overrides typing alone -- and a plain Dynamax applies neither; it scales the HP bar. Neither goes through the two primitives, so neither is announced. A Gigantamax is announced, because it really is a form record with real stats behind it.

## 0.62.1

### Fixed

- **Alongside a peer battle-engine mod that now ships its own Tera damage layer, one Pokemon showed two different Tera types.** That peer stores its Tera type in a field of its own and draws it on its stats screen, filling it with an independently rolled default on first read; this mod derives a Pokemon's Tera type from its DVs and stored it somewhere else entirely. Damage was never wrong -- the peer reads the type it multiplies out of `curTypes`, which is this mod's own override -- but the number on its screen had nothing to do with the type the Pokemon actually terastallized into, and a shard spend never reached it. Both fields are now written together at the two moments a Tera type becomes a fact about a Pokemon: when shards buy one, and when a Terastallization resolves a derived one. The mirror is deliberately one-directional. A value already sitting in the peer's field does not override this mod's own derivation, because behaviour must not change depending on what else happens to be installed.
- **With that peer installed, a wild Pokemon could be born with the one Tera type that is supposed to cost fifty shards.** Stellar has no type-chart record here on purpose, and the rare off-type roll was built to read whatever the chart held -- so its absence was the only thing keeping Stellar out of it. The peer registers a Stellar identity record of its own, and the moment it loads, Stellar joined the roll. The roll now excludes Stellar by name rather than by trusting it to be missing, which is the difference between a guarantee and an assumption another mod can invalidate. A Pokemon that paid for Stellar still has it.
- **The peer's manifest id had moved, so the load-order edge that keeps this mod's own patches outermost was not forming at all.** `optional_dependencies` named the superseded id; it now names the current one, and only that one. Two ids for one peer would be a list that goes stale silently while reading as though both had been checked.

## 0.62.0

### Added

- **Dynamax Level: a Pokemon now brings its own HP multiplier, from x1.5 to x2, and Max Candy is how it climbs.** Every Dynamax before this was a flat x2 for everything, which is exactly Level 10 -- `1.5 + 0.05 * level` is `(30 + level) / 20` as an exact rational, and level 10 is `40/20`, so levels generalise the existing HP machinery rather than replacing it. The multiplier stays two integers rather than one float on purpose: `src/hpscale.lua` never writes HP at all, it scales incoming damage and paints a scaled readout over the real bar, and that only stays honest because the fraction of a hit point each scaled hit leaves behind is carried forward exactly. A float would let the bar drift a point over a long battle in a way nobody could reproduce. The level is written to the Pokemon rather than derived the way a Tera type is, and it had to be: a Tera type is an identity and can come from DVs that never change, where this is progress a player spends items on. That has one real cost, stated rather than buried -- a Game Boy `.sav` export drops it, and unlike a Tera type there is nothing to re-derive it from, so a Pokemon back from a cartridge needs its Candy again.
- **Existing Pokemon start at Level 0, and Max Candy is on the Celadon shelf.** This is a genuine balance change to saves that already exist: a Pokemon that Dynamaxed at x2 yesterday now does so at x1.5. It is deliberate, because a level every Pokemon already holds at maximum is a mechanic with nothing to do. Max Candy sells beside the Tera Shards at ¥400, ten of them take one Pokemon from x1.5 to x2, and feeding a Pokemon already at ten is refused rather than charged -- so the Candy stays in the bag and a misclick costs nothing.
- **The Dynamax Band reads a Pokemon's Dynamax Level back.** The same necessity that gave the Tera Orb its own USE verb in 0.60.0: the level is written data that appears on no screen anywhere, so without something to read it with a player cannot tell a Pokemon they have fed ten Candies from one they have fed none, and has no way to know when to stop buying. Using the Band on a Pokemon names its level out of ten and costs nothing. The Key Stone and the Z-Ring still gate a mechanic, are used on nothing, and carry no effect at all.

## 0.61.1

### Fixed

- **Four comments claimed an engine limitation that no longer exists, which would have talked the next reader out of something that now works.** `src/persistent.lua`, `src/stone.lua` and one of the persistent-form tests each stated that Gold's `Game2:usePartyItem` calls `ItemEffects.partyAction(itemId)` with no dataset argument, and concluded from it that every mod's Gen 2 field item was unreachable, on any item, regardless of what it registered. That was accurate when it was written and is not now: the engine passes its dataset through both dispatch calls, and `ItemEffects.recordFor` consults `data.gen2ItemEffects` ahead of its own built-in records -- which is precisely the path this mod's own Tera Orb has been running on since 0.60.0, so the files contradicted working code sitting beside them. Each note now describes the gap in the past tense and says plainly that it closed. No behaviour changed, deliberately: the persistent-form items and the mega stones keep `ITEMMENU_NOUSE` on Gold, because a held item has no USE verb in the real games either, and every one of those comments already carried that as an independent reason -- it was the "and it could never have worked anyway" half that had gone stale, and it was the half a future reader would have stopped at.

## 0.61.0

### Added

- **Stellar, the Tera type that changes no typing at all.** Every other Tera type here works by replacing what the Pokemon is -- a one-element `curTypes` on Gen 1, `mon.formTypes` on Gold -- and lets the type chart do the rest. Stellar cannot: it has no chart record, nothing is weak to it and it resists nothing, and inventing a STELLAR type row to make it fit would mean writing eighteen matchups nobody asked for and dragging National Dex into a change that belongs entirely to this mod. So a Stellar-terastallized Charizard is still Fire/Flying -- still quadruple weak to Rock, still resisting Grass, still getting its ordinary STAB -- and what changes is damage, through the `battle.damage` hook chain both engines already expose. Once per move TYPE per Terastallization, a move the Pokemon has STAB on lands at x2 instead of x1.5, and a move it does not lands at x1.2 instead of x1; every later move of that same type is ordinary again. The boost is per type rather than per move, so it rewards a varied moveset once rather than one move repeatedly, and a status move never spends a type's boost on its way past. The multiplier applied is 2/1.5 rather than 2, because the engines have already applied their own STAB inside the calculation this wraps -- scaling by 2 there would land at x3 and read as a Pokemon hitting three times too hard for no findable reason. No Pokemon is ever born Stellar: it is not in any species' own types and not in the chart, so the only way to hold it is a Stellar Shard, which sells beside the other eighteen at five times their price and is spent fifty at a time like all of them. Tera Blast stays Normal for a Stellar Pokemon and takes the same boost as any other move, rather than becoming a Stellar-typed variant whose type the chart could not resolve -- the refusal this mod already makes out loud for DARK on a Red-era chart.

## 0.60.0

### Added

- **A Tera type is now a property of the Pokemon rather than a setting, and two Charizard can differ.** TERA TYPE used to be one option applied to whatever terastallized, because a Gen 1 party screen has nowhere to pick a type and there is no field on a Pokemon a player could set -- both still true. What changed is that a Pokemon already carries sixteen bits nothing here read: its four DVs, rolled at generation and never touched again. `src/teratype.lua` derives the Tera type from those, so it is per-Pokemon, stable for that Pokemon's whole life, and -- the part a written marker could never manage -- survives a Game Boy `.sav` export, since DVs are real cartridge fields where a stamp of our own is deleted by the 44-byte struct that has no hook in it. The derived type is one of the Pokemon's OWN types, evenly split for a dual-type: a Charizard is stably Fire or Flying, and becoming purely one of them is not the no-op the old NORMAL default was written to avoid, because it drops every weakness the other type brought. Roughly one Pokemon in sixteen carries a type off its own list entirely, which is what makes a wild catch worth checking. The TERA TYPE option is still there and now defaults to AUTO, meaning "ask the Pokemon"; the eighteen explicit rows behind it override every Pokemon with one type, kept because pinning a matchup deliberately is worth being able to do.
- **Tera Shards are sold on the Celadon department store floor, and fifty of one type change a Pokemon's Tera type for good.** One shard item per type the running chart resolves -- eighteen with National Dex, fifteen on a Red-era chart, off the same list the Tera Blast variants are built from, so the two can never disagree about which types this game has. There is no shard counter anywhere in the mod and deliberately none: `save.inventory` is already a per-item ledger, keyed by id, capped at 99 a stack and scrubbed against the registry on load, so the bag IS the eighteen-slot count and buying, selling and tossing work because nothing reimplemented them. Using fifty shards of a type on a Pokemon writes that type over its derived one; the Pokemon is written first and the shards taken second, so the unrecoverable failure -- paying and receiving nothing -- is the one that cannot happen. Spending on a type a Pokemon already has is refused rather than charged, including when that type is the derived one it was born with. Shards carry no bag byte on either game: seventeen were free on Gen 1 against eighteen needed, and there is no principled way to choose which type exports and which does not, so none do -- the conclusion `data/plates.lua` reached for the Plates and Memories, for the same reason.
- **The Tera Orb reads a Pokemon's Tera type back, and now has to.** A derived Tera type is real, per-Pokemon and shown on no screen anywhere, so without something to read it with, a player would be spending fifty shards to change a value they could not see. Using the Orb on a Pokemon names its Tera type and costs nothing. That is also why the type is chosen by which shard you use rather than by a picker on the Orb: choosing a Pokemon is free on both engines, but choosing a TYPE has no primitive on either -- a field item is handed a mon and answers with text, with no second prompt in the contract on Gen 1 at all -- and an Orb that spent without one would have to guess which of eighteen piles was meant, at fifty shards a guess. The Orb is the only one of the four trainer key items with a USE verb; the other three still gate a mechanic and are used on nothing.

## 0.59.1

### Fixed

- **On Gold, winning a gym battle or picking a tree handed out this mod's own key items and mega stones instead of the TM, apricorn or berry that was actually awarded.** Every bag byte in `data/` was numbered against Gen 1, where vanilla ends at 97 and 98 upward is genuinely free; Gold ships 250 items filling 1-250, and this mod fills 98-233, so 140 of its 141 declared bytes put a second record on a number Gold had already spoken for. Gold resolves an awarded byte by scanning every registered item for a matching `index` -- `itemByIndex` in `game/src/world/gen2/World.lua`, which sits behind gym prizes, item balls, NPC gifts and tree pickups alike -- and `pairs` has no defined iteration order, so which of the two records won was decided afresh on every lookup, which is why the substitution was intermittent rather than constant. 196-199 are `TM_ROAR`, `TM_TOXIC`, `TM_ZAP_CANNON` and `TM_ROCK_SMASH`, the range gym leaders award from, and they were this mod's four trainer key items; 101 and 102 are `PNK_APRICORN` and `BLACKGLASSES`, and they were the Blastoisinite and the Alakazite. On Gen 2 these items now register with no `index` at all rather than with a different one -- Gold leaves five bytes free and this mod needs 136, so relocating them was never available -- and a record carrying no byte matches nothing that scan can ask for, which makes the substitution impossible rather than unlikely. That is the same treatment the Plates and the Memories have had on both games since `data/plates.lua` first argued for it. Nothing moves in a save that already exists: the bag, the mart shelves and `SaveData`'s own scrub are all keyed by item id rather than by byte, so an item already carried stays exactly what it was, and the single cost is that these items cannot survive a Game Boy `.sav` export on Gold. Gen 1 is untouched and keeps every byte permanently, as the `data/` tables have always required; TM171 keeps its own byte on both games, since 252 sits in the small range Gold itself leaves open.

## 0.59.0

### Fixed

- **Against another installed mod that also patches Gold's battle-scale seam, this mod now wins the growth it draws instead of losing it silently.** A peer GAMEPLAY mod on this engine (manifest id `g9-battle-engine`) ships its own Dynamax/Gigantamax implementation and, like `src/gen2dynamaxgrow.lua`, wraps `src.ui.gen2.BattleState:picScale` directly rather than through a priority-ordered hook chain -- so whichever mod's own `main.lua` ran last ended up wrapping the other's, and got first refusal on every draw call. Nothing in this mod's own manifest ordered it relative to that id, so `Loader:_order`'s tie-break (lower `priority` number goes first among otherwise-equal mods) put this mod's own patch first, meaning the peer's patch wrapped it rather than the other way round -- and since that peer's own species table already covers essentially the whole roster (1,227 ids, national_dex-species mostly included), its own resting-scale answer for almost any species intercepted the call before this mod's own Dynamax growth check ever ran, so a Dynamaxed Pokemon on Gold with that mod also installed silently stopped growing for nearly every species in the game, with no error and no log line. `manifest.json` now lists that id under `optional_dependencies`, which orders this mod after it when it is present and changes nothing at all when it is not (confirmed against the real loader both ways) -- so this mod's own patch sits outermost, decides first whether a Dynamax is active, and only then falls through to the peer's own answer for species it doesn't otherwise touch, composing the two instead of either silently discarding the other. The same reordering also fixes a second, lower-stakes case: that peer's own move registration unconditionally overwrites Play Rough's entire move record on Gold, discarding this mod's own `effectModeled` marker in the process (its real stat-drop still lands either way, since that runs off the move id directly rather than off the registry) -- after the fix this mod's own patch runs last and the marker survives.

## 0.58.0

### Added

- **On Gold, a Dynamaxed Pokemon with no Gigantamax picture now visibly grows instead of standing there unchanged.** The real games' own Dynamax makes every Pokemon bigger; this mod had only ever drawn the 31 species `data/gigantamax.lua` gives a distinct picture, leaving the other several hundred looking exactly like they do outside a Dynamax. `game/src/battle/gen2/BgEffects.lua`'s own `runPicResize` -- the engine's real grow/shrink facility, used for a mon entering or returning to its ball -- turned out to be the wrong seam: it only ever writes a box-size index smaller than or equal to normal, and it is only read while a battle animation is actually running, so it goes stale the instant that animation clears, which is most of a battle. `src/gen2dynamaxgrow.lua` instead wraps `BattleState:picScale`, the multiplier the engine already reads on every draw and already composes with a live resize script (`battle_sprite_scales`, then a species' own `battleScaleFront`/`battleScaleBack`, now this) -- so a Dynamaxed mon returning to its ball still shrinks through the real animation's own steps, just shrinking away from a bigger starting size, with nothing here fighting that mechanism because nothing here writes the field it owns. The growth scale (1.15x) comes from the pic box and HUD geometry directly: a typical pic grows with no overlap into the neighbouring HUD text or off the top of the screen, and only the single largest vanilla front pic gives up a few pixels to either. A species with a real Gigantamax picture applied keeps it and does not also grow; a Gigantamax refused at runtime (the record named in `data/gigantamax.lua` is missing or misnamed) grows instead, since the player is looking at the base picture either way; a mon already wearing a mega or other form's picture when it Dynamaxes does not grow on top of that either. The growth reads `src/dynamax.lua`'s own per-battle state live, so the same four paths that already end a Dynamax -- the three-turn clock, a switch, a faint, and the battle ending -- end the growth in the same instant with nothing new to unwind. Gen 1 is unaffected: Red has no draw-time scaling seam at all, so this is Gold only.

## 0.57.0

### Fixed

- **Four more species Z-Crystal base moves shared Dragon Ascent's own crash risk on Gold, and two more silently did nothing there.** Volt Tackle, Sparkling Aria, Play Rough and Clanging Scales each register a `run` handler the same shape Dragon Ascent's own used to, and Gold's move-effect dispatch fires any registered `run` unconditionally and before the accuracy roll, then returns -- an empty table was never the risk here, a real handler reading Gen 1's `ctx` shape off Gold's own positional arguments was, the identical hazard 0.55.0 already fixed for Dragon Ascent. `src/speciesbasemoves.lua` now attaches no `effect` at all to these four on Gen 2, so Gold's dispatch finds nothing registered and the move resolves the ordinary way; each move's real effect -- Volt Tackle's recoil and paralysis chance, Sparkling Aria's burn cure, Play Rough's Attack drop, Clanging Scales' self Defense drop -- now applies from `battle.damage_dealt` instead, gated on the target surviving and on damage actually dealt. Giga Impact's own recharge and Stone Edge's own high critical-hit ratio were reported as a wrong effect-id string and a wrong field read respectively, and both checked out true: Gold's engine reads neither `HYPER_BEAM_EFFECT` (Gen 1's own id) nor a move record's `highCrit` field at all -- it checks `def.effect == "EFFECT_HYPER_BEAM"` directly after damage resolves for the recharge, and `def.effect == "EFFECT_ALWAYS_CRIT"` for the raised crit ladder, both plain string comparisons with no move_effects record behind either one. Both moves are patched onto Gold's own literals now and both work there for real, driven through the real `Battle:hitOnce`/`Battle:useMove` dispatch rather than assumed from the two strings alone.
- **Darkest Lariat and Spectral Thief are refused on Gold rather than shipped with a drawback that silently never applies.** Darkest Lariat's real effect lives in `chooseDamage`, ignoring the target's stat changes for one damage calculation; Spectral Thief's lives in `beforeAccuracy`, stealing the target's boosted stats ahead of the roll. Neither callback name appears anywhere in Gold's own move-effect dispatch, which only ever calls a registered record's `run`, so there is no seam either effect can reach without an engine change. Incineroar and Marshadow are taught neither move on a Gold boot -- Incinium Z and Marshadium Z stay exactly as unreachable there as Decidium Z already is on both games -- while both moves keep working in full on Red. Sunsteel Strike and Moongeist Beam were confirmed unaffected: neither carries an effect id on either game, so plain damage was already the complete model and nothing needed to change.
- **Gold's own FORM cell diagnostic could flood its own buffer with hundreds of identical lines before a battle ever reached the menu phase.** `src/menu.lua`'s Gen 1 wrapper installed unconditionally in `main.lua`, so a Gold boot patched `src.battle.BattleState` -- a class nothing on Gold ever draws through, but still resolvable, since a mod's `require` is not redirected there -- right alongside `src/gen2menu.lua`'s own wrap of the real class. A real trace showed both wrappers' own lines interleaved at identical timestamps, and the actual mechanism was `src/diag.lua`'s `M.menu` and `M.menuGen2` sharing one module-level per-battle scope: with two wrappers alternating every frame between two different battle identities, each arrival reset the shared dedup bookkeeping before it ever got to compare an answer against itself, defeating "one line per state" for both emitters at once. `main.lua` now installs `src/menu.lua` on Gen 1 only, matching the discipline every other Gen-specific wrap in that file already holds; `src/diag.lua`'s `M.menu` and `M.menuGen2` also now keep their own separate scopes, so neither can invalidate the other's dedup regardless of what else ever calls into the shared one `M.note`/`M.primal`/`M.conditional` still use.

## 0.56.0

### Fixed

- **On Gold, taking a persistent held item back off a Pokemon left it fighting a whole extra battle still dressed as the form that item earned.** GIVE and TAKE write `mon.item` directly and fire no event this mod can hook, and `src/persistent.lua`'s own send-out handler (`M.apply`) only ever applied a form the held item still named; when the item was gone it did nothing at all, leaving `mon.form` and the mutated `mon.stats` standing exactly as an earlier `becomeForm` call had left them. A Palkia stripped of the Lustrous Globe therefore still showed Origin Forme's stats and typing on the party summary and through its whole next battle, correcting itself only at that battle's own end once the party sweep re-derived it -- one full battle late, matching a real report. `M.apply` now reverts a form its own pairing table produced the moment the item that earned it is gone, through the same `ownsSuffix` check the function already used to leave a foreign mechanic's marker untouched; Gen 1 is unaffected, since its bag-stamp mutation is already synchronous with `mon.form` and never had this gap.

## 0.55.0

### Fixed

- **Dragon Ascent used PP and did nothing else on Gold, even after 0.54.0's own attempt to fix it.** That fix made the registered move effect's `run` return an empty table on Gen 2, on the reasoning that an empty effect is a harmless one -- but Gold's own dispatch (`game/src/battle/gen2/Battle.lua:1561-1566`) fires any registered handler unconditionally and before the accuracy roll, then returns: `local handler = effectRecord and effectRecord.run; if handler then handler(...); return end`. An empty table from a registered handler is still a handler, so the move never reached accuracy or damage, only PP. `src/dragonascent.lua`'s `M.install` no longer patches DRAGONASCENT's `effect` field at all on Gen 2, leaving it at whatever national_dex's own Gold registry set (`EFFECT_NORMAL_HIT`, not `NO_ADDITIONAL_EFFECT`, but equally nothing any move effect is registered under), so Gold's dispatch finds no handler and the move resolves normally. The self-lowering stat drop is unchanged, still applying through `battle.damage_dealt` once a hit has actually landed. The level-75 learnset patch that teaches Rayquaza the move was already correct as of 0.54.0 and needed no change.
- **Persistent held-item forms other than the fusions showed their base sprite in the party and on the STATS screen until the Pokemon had been thrown into one battle.** GIVE and TAKE on Gen 2 write `mon.item` directly and fire no event this mod can hook, so `mon.form` -- applied at send-in and re-derived by the battle-end sweep -- was never written for a Pokemon that had simply been handed an item and never fought with it. `src/gen2formview.lua` and `src/formicons.lua` had each independently reasoned their way to deriving the form fresh from the held item rather than trusting `mon.form`; `src/formview.lua`'s older Gen 1 copy of the same chain still gated on `mon.form`, safely there only because Gen 1 writes it synchronously. The three near-identical copies are now one shared `src/formresolve.lua`, which never gates on `mon.form` on either game, so a future reader cannot reintroduce the Gen-1-only shortcut onto a Gen 2 screen.

### Added

- **Gold's FORM cell gained the diagnostic Red/Blue/Yellow's has always had.** A report that Dynamax and Z-Moves never appeared on the cell, only Mega, pointed first at `src/keyitems.lua`'s own `battle.save` fallback -- but driving the real registry, the real wrapped `BattleState.update` and the real `keyitems.lua` through the actual loader showed each mechanic offered correctly when its own key item was the only one in the bag, and multiple key items held together offering multiple entries correctly as well. The mechanism checks out; what was missing is what would have named the real cause on sight. `src/diag.lua` gained `menuGen2`, the same armState/phase/keys/offered report `M.menu` has always given Gen 1, shaped for Gold's own split between the UI `BattleState` (phase, queue) and the engine `Battle` (the mon, its held item) -- wired into `src/gen2menu.lua`'s wrapped `update`. The next report of this shape will have a `keys[DYNAMAX_BAND=... Z_RING=...]` line to check against the player's own save.

## 0.54.0

### Fixed

- **A mega evolution on Gold changed the stats, the type and the picture but never said a word about it.** `src/announce.lua` gained `gen2Mega`, going through `Battle:emit` the way `gen2Tera`/`gen2Primal`/`gen2UltraBurst` already do, since Gold's engine object has neither `say` nor `sayNext`. There is still no transformation flash: grepping both `game/src/battle/gen2/Battle.lua` and `game/src/ui/gen2/BattleState.lua` for `animNext`/`animationsOn`/`transformAnim`/`flash` turns up nothing but the unrelated shiny-flash kind on a shiny send-out, confirming Gold has no transformation-flash concept a mod could reach at all -- the same finding already recorded for Terastallization.
- **Mega Rayquaza's own no-stone trigger was never asked on Gold's mega path, and even asking it would have found nothing to trigger on.** `src/mega.lua`'s Gen 2 branch checked only the ordinary Key-Stone-plus-item gate; it now asks `src/dragonascent.lua`'s own trigger first, the identical order Gen 1 has always used. That trigger's own learnset patch was also landing on a dead field: national_dex's own `src/gen2shape.lua` strips `learnset` from every species it reshapes for a Gold boot and folds it into `levelMoves` instead, and Gold's `Mon.movesAtLevel` reads only `levelMoves`, so a Gold Rayquaza could not learn Dragon Ascent at all, whatever level it reached. `src/mega.lua` and `src/speciesbasemoves.lua` (whose own ten species-crystal base moves patch `learnset` the identical way) both pick the field `deps.gen2` says to now; `src/terablasttm.lua`'s own `tmhm` patch does not share the bug, since `tmhm` is not in `GEN1_ONLY` and both schemas use the same field name.
- **Dragon Ascent's own post-hit stat drop could not fire on Gold, and once Mega Rayquaza's trigger became reachable there it would have crashed the game the first time the move connected.** Gold dispatches a registered move-effect's `run` unconditionally and before the accuracy roll, handing it positional battle-engine arguments rather than the Gen 1 ctx table the effect record is built for -- reading `ctx.user`/`ctx.changeStage` off that shape answers `nil` and the resulting call errors outright, confirmed by deliberately removing the new guard. The Gen 1 record now refuses itself on Gen 2, and the real drop applies from `battle.damage_dealt` instead, the identical seam `src/zmoves.lua`'s own Z-status bonus already uses, gated on the target surviving and on real damage dealt -- the same two-part gate Gen 1's own `EffectRegistry.lua` already applies to every `"secondary"` effect. Checked but not fixed here: four of the other nine modelled species Z-Crystal base moves (Volt Tackle, Sparkling Aria, Play Rough, Clanging Scales) share the identical early-dispatch crash risk on Gold; Giga Impact's recharge, Darkest Lariat's stat-change immunity, Spectral Thief's steal and Stone Edge's high-crit rate each silently do not apply there for reasons of their own, none of them a crash.

### Changed

- **Rayquaza now learns Dragon Ascent at level 75, the main series' own level, on both games -- not level 1.** 0.30.0 through 0.53.0 taught it at level 1 so the move (and the mega) existed from the moment a Rayquaza did; that convenience is gone, and a Rayquaza below level 75 needs to reach it, or otherwise learn the move, before Mega Rayquaza's own trigger has anything to ask about. `Mon.movesAtLevel`/`Pokemon.movesAtLevel`'s shared last-four-in-append-order rule guarantees a freshly caught level-75 Rayquaza always knows the move regardless of how many earlier-level moves compete for the same four slots, on either game -- wild_forms' own Indigo Plateau Rayquaza is placed at exactly that level for this reason, and both engine functions were driven directly to confirm it rather than assumed from the arithmetic.

### Added

- **The boxed fusion partner's marker now reaches Gold's own PC too.** `game/src/ui/gen2/BoxMenu.lua` was recorded as a self-drawn icon grid with no text slot; reading the class found otherwise on both counts, and also found that its box list genuinely has no column safe for every possible nickname. The marker instead lives in Bill's own info panel -- a real two-tile gap beside the level and gender line that no mon's data can fill -- redrawn continuously for whichever Pokemon the cursor sits on, and on the STATS screen reached from it, through the same free column on its dex-number row Gen 1's own marker already uses the pixel equivalent of.

## 0.53.0

### Added

- **The eighteen type Z-Moves, the fourteen species Z-Moves, Z-status effects and Tera Blast all work on Gold now, which closes the mechanical half of the Gold parity gap.** `src/zmoves.lua` and `src/speciesz.lua` read `mon.item` for a crystal's own held-item check rather than the Gen 1 bag stamp -- the identical gap `src/mega.lua`'s and `src/primal.lua`'s own Gen 2 branches already fixed for stones and orbs, since GIVE only ever writes `mon.item` and `eligibility.STAMP` is a field Gold's own party menu never touches -- and both catalogs' `fieldsFor` gained the `maxPp`-not-`ppUps` branch every other `src/gen2substitute.lua` consumer already carries. Z-status's self-raise classification now reads live off `src.battle.gen2.Effects.STAT_CHANGES` rather than a hand-duplicated table, and applies through the engine's own `battle:changeStage` instance method, since Gold has no free function shaped like Gen 1's `MoveEffects.changeStage` to call instead. Tera Blast's own substitution was refused outright on Gen 2 in 0.43.0, written when Gold had no proven move-substitution primitive to reach for; the refusal is closed now that `src/gen2substitute.lua` has been proven under three real consumers (Max Moves, then both Z-Move catalogs), so a Pokemon that already knows TERA BLAST gets the real substituted move alongside the type override that already worked. The type Z-Moves are that primitive's second real consumer alongside Dynamax's Max Moves, and the two are proven not to collide -- `src/arm.lua`'s own one-transformation-per-battle lock always tears one substitution down before the other arms, checked directly rather than assumed.

## 0.52.0

### Added

- **Dynamax, Gigantamax and Max Moves work on Gold.** 0.49.0 built and proved `src/gen2substitute.lua`, the mutate-and-restore primitive Gold needs in place of Gen 1's whole-array swap, and deliberately wired it to nothing; `src/dynamax.lua`, `src/maxmoves.lua` and `src/gmaxmoves.lua` now carry a `deps.gen2` branch, the same shape `src/mega.lua`'s own already does, so the identical three-turn clock, once-per-battle limit and four teardown paths run through the real primitive instead of Gen 1's `src/substitute.lua`. The HP multiplier ports the same way it already worked on Red -- halving incoming damage through `battle.damage` and repainting the readout through `battle.overlay` rather than writing HP -- read off the mon directly through `src/battlerof.lua` so the one hook now covers both games' payload shapes with no branch of its own; an OHKO move fails outright against a Dynamaxed target on Gold too, wrapping `Battle.MOVE_EFFECTS.EFFECT_OHKO` the way Gen 1's own `OHKO_EFFECT` gate is wrapped, since Gold's own version has no separate gate field to compose ahead of. A new `src/gen2movemenu.lua` gives the substituted Max Move and G-Max Move names their own FIGHT-menu redraw, the equivalent of `src/zmovemenu.lua` for a class that module never touches, established against Gold's own 96-pixel/twelve-column budget rather than assumed from Gen 1's. The Dynamax Band now sells at the Indigo Plateau counter alongside the Key Stone and the Tera Orb, without which none of this was reachable regardless of how correct the mechanism is. Proven under a mid-battle level-up (a forgotten move's slot and an appended new one both survive a live substitution's unwind untouched) and by deliberately breaking six guards in turn -- the real-loader wiring, the primitive's identity-based restore, its save-write veto and the Gen 2 OHKO gate -- to confirm the suite actually catches their absence.

## 0.51.0

### Fixed

- **A formed Pokemon's party list icon is drawn by vanilla again, not reimplemented by this mod.** 0.45.0 through 0.50.0 wrapped Gold's own icon draw directly -- fetching a form's battle art, fitting it into the icon slot, looking up the party list's shared palette by hand, and suppressing the backing fill drawn everywhere else -- and each of those four steps produced its own bug in turn: the wrong sprite, the wrong colour, then a stray background block. Every one of those steps was already vanilla's own job the moment something upstream answers with the right file, so the fix is a single hook subscription on the seam both games already resolve a party icon's file through, answering with a form's own real icon file when one exists and a verified check against the real filesystem confirms it, and leaving every other case -- including a form with no icon of its own, which now shows its base species' icon, drawn by vanilla, never a downscaled copy of its battle art -- to vanilla exactly as before. Red's own party list had the identical gap and no fix at all until now; the same subscription closes it there too.

## 0.50.0

### Fixed

- **A form-altered Pokemon's party list icon on Gold drew with a pale block behind it that no unaltered icon has.** `src/gen2formview.lua`'s shared `drawFormArt` helper paints a solid backing rectangle before drawing the art, which is correct for `SummaryMenu`'s own 7x7 STATS picture -- vanilla's own `drawPicBlock` does the identical fill there -- but 0.45.0 routed the party list's 16x16 row icon through the same helper to get the sprite right, and the fill came along for the ride unnoticed: vanilla `PartyMenu:drawIcon` never paints one at all. `drawFormArt` now takes the fill as a per-caller flag, defaulting to on for the SUMMARY picture's two existing call sites and passed off explicitly from the party list icon.
- **The fusion animation showed the fused Pokemon merging with its partner, instead of the original, unfused Pokemon merging into it.** `src/fusion.lua`'s own `fuse()` sets `mon.form` to the fused suffix before its item effect even returns, so by the time `src/fusionanim.lua`'s `tryAnimate` ever saw the survivor, the mon was already post-fusion -- and it handed that same live, already-mutated mon straight to the LEFT picture's own art lookup, so any sprite hook that keys its answer on `ctx.mon.form` (the same seam every other form in this mod draws through) drew the fused form on both sides of the merge. The partner and the fused result were each already resolved correctly and at the right moment -- the partner never carries a form context at all, and the result is built from a synthetic `{form = suffix}` record rather than the live mon -- so only the left participant needed a fix: `installGen1` and `installGen2` now snapshot the survivor before running the real effect, and `M.resolveArt` draws the LEFT picture from that pre-fusion snapshot rather than from the live mon. Gen 1 shared the identical bug, since both games run through this same module, and both are fixed by the same change.
- **The eighteen ordinary type Z-Crystals were never sold on Gold, and a Z-Crystal that somehow reached a Gold save showed a USE option that silently did nothing.** `src/stone.lua`'s `installUnpaired` never received the Gen 2 treatment its sibling `M.items` already has: the item record carried no `fieldMenu`/`battleMenu` suppression, and its registered effect only ever read `ctx.target`, Gen 1's own shape. That used to be harmless because Gold's `Game2:usePartyItem` could not reach a mod's own item effect at all -- but 0.47.0's own engine fix (PR #1434) closed that gap, so USE now genuinely reaches this closure on a live Gold boot, reads `ctx.mon` as `nil`, and answers "no effect" every time with nothing on screen to explain why. A Z-Crystal is a held item, stamped onto a Pokemon and nothing more, so it gets the same GIVE-only treatment every other held item here already has (0.47.0's own precedent for telling that apart from fusion's items, which keep USE because USE is fusion's own trigger): `installUnpaired` now sets `fieldMenu`/`battleMenu = "ITEMMENU_NOUSE"` on Gen 2 and registers a correctly Gen-2-shaped effect (`ctx.mon`/`ctx.data`) alongside Gen 1's, and all eighteen now sell at the Indigo Plateau counter beside Ultranecrozium Z. This makes the crystals buyable and honest, not functional: Z-Moves themselves still do not work on Gold, since they need move substitution, and the primitive 0.49.0 built for that is not wired to any feature yet.

## 0.49.0

### Added

- **A proven, standalone move-substitution primitive for Gold -- groundwork only, wired to no feature yet.** Gen 2 has no `curMoves` layer the way Red/Blue/Yellow's own `src/substitute.lua` does: `Battle.lua:255` sets `self.player` to the exact party record, so `mon.moves` is the same table the save writer walks, and the whole-array swap that mechanism relies on would hand a completed save file whatever a substitution currently showed. A move list also turned out not to be recomputable from species and level the way `src/gen2forms.lua`'s stats trick is -- TMs taught, the Move Deleter and Day Care all make it genuinely player-owned history -- so the new `src/gen2substitute.lua` snapshots each slot's `id`/`maxPp` before mutating that exact table in place, and restores by checking each slot's table identity rather than its index, which is what keeps a mid-battle level-up-and-forget's freshly learned move from being silently overwritten by a stale snapshot. PP is spent from the real slot throughout, needing no metatable the way the Gen 1 substitute does, because there is only ever the one table underneath. Gen 2 battles cannot be checkpointed at all, and the one other route to disk (the F1 dev hotkey, which calls `Game2:writeSave` from any screen with no checkpoint gate) funnels through one veto seam, so the primitive also subscribes a `save.write` refusal for as long as any substitution is live -- a save genuinely cannot observe a substituted id, even through that bypass. Proven by 121 checks driving the real `src.battle.gen2.Mon`/`Battle` modules and by deliberately breaking each of six guards in turn to confirm the suite actually catches their absence; nothing in this mod calls the new module's `M.apply` yet, so Dynamax, Gigantamax, Tera Blast and both Z-Move families remain exactly as unreachable on Gold as they were before this release.

## 0.48.0

### Added

- **Fusing now shows both Pokemon side by side merging into one, on both games, before the ordinary message -- the owner's original ask for the feature, unreachable until now for two independent reasons that are both gone.** `EvolutionState:update` still unconditionally re-keys `mon.species`, so the engine's own evolution screen stays refused exactly as HANDOFF.md records; the real blocker was that `src/ui/BagMenu.lua`'s item dispatch used to be a Lua `local` no mod could see, so nothing pushed from inside an item's own effect callback ever drew a frame. The engine's own `item.use` hook (a `Runtime.call` seam around that whole dispatch) closed that gap, and `src/fusionanim.lua` composes with it rather than replacing it -- `mod.hooks:wrap` chains behind whatever else is listening, the same discipline `src/hpscale.lua`'s own `battle.damage` wrap already keeps. That hook turns out to be Red/Blue/Yellow only: it only ever fires from `src/ui/BagMenu.lua`, and Gold's own field PACK is a different class (`src/ui/gen2/PackMenu.lua`) calling straight into `Game2:usePartyItem`, which dispatches through `src/core/gen2/ItemEffects.lua` with no `Runtime.call` anywhere near it. So Gold gets an idempotent wrap of `Game2:usePartyItem` instead, the identical monkeypatch-with-a-guard-flag technique `src/gen2forms.lua`, `src/gen2menu.lua` and `src/gen2formview.lua` already use for every Gen 2 class this mod touches that the engine gives no hook for at all. Both halves read `fusion.partnerOf` before and after the real effect runs to know a fuse happened -- nothing here re-derives what `src/fusion.lua` already decided -- and resolve all three pictures (the survivor as it stood, the partner's own species, the fused form) through the identical `pokemon.sprite` hook and record-picture fallback `src/gen2formview.lua` already draws forms with, refusing the whole animation rather than drawing a blank if any one is missing. `src/fusion.lua` itself is unchanged -- this module only interposes a screen before the two-page message it always wrote, never replaces or suppresses it. Splitting stays a plain message on purpose: nothing new appears on screen to animate, and `src/boxmark.lua`'s own F marker disappearing from the PC lists already answers "where did it go" durably, on screen, rather than in a line printed once. Confirmed by driving the real `src.mods.Hooks` chain through a real `src.ui.BagMenu` USE on Red/Blue/Yellow and the real, wrapped `Game2:usePartyItem` through a real `Gen2PartyMenu` pick on Gold, both proving the animation screen -- not the plain message -- lands on top of the stack first and that finishing it hands off to the exact message `src/fusion.lua` wrote underneath.

## 0.47.0

### Added

- **Fusion and Ultra Burst are reachable on Gold for the first time.** The engine's own PR #1434 (finding #8, merged into the player's 0.1.99) fixed `Game2:usePartyItem` to call `ItemEffects.partyAction` with the `data` argument it had always been missing, closing the dispatch gap that kept every mod's Gen 2 item effect unreachable through USE. That alone was not enough: `src/fusion.lua`'s own item registration now carries the Gen 2 shape `src/persistent.lua`'s held-item forms already use (`action`, `use(ctx)` reading `ctx.mon`/`ctx.data` rather than Gen 1's `ctx.target`/`ctx.save`), plus something no persistent form ever needed -- the live save itself, captured off `save.created`/`save.loaded` by a new `M.onSaveReady`, since fusing has to find a partner in the party array and deposit one to the PC rather than mutate only the one mon ctx hands it. The four fusion items also gained `battleMenu = "ITEMMENU_NOUSE"` on their item record, the field Gold's mid-battle PACK dispatch checks directly (the item_effects `battle = false` refusal Gen 1 relies on is never reached there), so a live fight still cannot be asked to remove a Pokemon out from under it -- persistent held-item forms are untouched and stay GIVE-only, correct and faithful to the real games, since USE is fusion's own trigger and was always meant to work. The four fusion items, Ultranecrozium Z and the Z-Ring now sell at the Indigo Plateau counter too, without which none of this was reachable regardless of how correct the dispatch is. Confirmed end to end by a headless suite that drives the real `Game2:usePartyItem` against the real `Gen2PartyMenu` screen and reads a fusion back off the real save, plus the four refusal guards (no partner, a blackout, a full PC, a full party on splitting) proven again through that same Gen 2 dispatch.

## 0.46.0

### Fixed

- **A held item with no pairing for the Pokemon carrying it could leave a stray form marker standing that a real mechanic then refused ever to clear.** An Aegislash stamped with a Draco Plate -- an Arceus item this species has no pairing for at all, most plausibly set through a save editor rather than the shop, since `src/stone.lua`'s own `effectFor` already refuses to stamp one there -- carried `mon.form` set to `ARCEUS_DRAGON`'s own suffix, and `src/conditional.lua`'s `enter()` correctly refused to overwrite what looked like an in-progress mega, permanently blocking its stance change. The actual cause was `src/resolve.lua`'s `ownsForm`, which only ever asked whether the mon's OWN species could have produced the suffix sitting on `mon.form`; a suffix that genuinely belongs to a DIFFERENT species in this mod's own tables reads identically to a genuinely foreign mod's marker, so it was left standing forever instead of cleared. `src/resolve.lua` now sweeps both send-out seams first (a new `M.onBattleStarted`, and the existing `M.onBattlerSwitched`), asking the wider question -- is this suffix ANY of this mod's own tables' at all, for ANY species -- and clears exactly the markers that are ours but belong to someone else, leaving a mon's own legitimate claim and a genuinely foreign mod's marker precisely as untouched as before.
- **A conditional form's refusal to overwrite an existing one now says so out loud, not only when DEBUG TRACE happens to be switched on.** `src/conditional.lua`'s `enter()` already refuses a mon that appears to be wearing a different form -- the guard that protects a mega from being silently replaced by a knockout-driven Battle Bond -- but the refusal only ever reached the trace log, and there is no player action behind an automatic form change for a trace to surface without tracing already on, which is exactly what turned the Draco Plate report above into a day of guessing. It now also writes through `mod.log`, which the engine keeps in a bounded history a debug overlay can read regardless of the DEBUG TRACE option, naming the species and what it is already wearing.
- **A Gold Pokemon's party list icon showed its form correctly as of 0.45.0, but shaded in the wrong colour -- the same seam 0.44.0 found on the party STATS screen, one step further down.** Vanilla `PartyMenu:drawIcon` shades every row icon through one shared palette regardless of species (`self.palettes.partyMenu[1]`, the same `PAL_OW_RED` table the game loads for the whole list), but `src/gen2formview.lua`'s shared `drawFormArt` helper always looked up the SUMMARY picture's own per-mon palette instead -- the correct source for that screen and the wrong one for this one. `M.drawIcon` now threads `self.palettes.partyMenu[1]` through explicitly, the exact field the held-item marker drawn beside it already read correctly, while the SUMMARY picture keeps its own per-mon lookup unchanged.

## 0.45.0

### Fixed

- **On Gold, a form-owning Pokemon that landed the killing blow reverted to its base picture and stats before the hit that killed the target had finished animating -- the fight told the player its own outcome ahead of the swing that decided it.** `Battle:resolveFaints` decides a knockout and, when it ends the battle, calls `Battle:endBattle` synchronously inside that same call -- before the caller has even taken the turn's queued display events off the battle, let alone before the screen has paced through them. `src/resolve.lua`'s battle-end sweep used to revert every form-owning Pokemon in both parties the instant `battle.ended` reached it, which on Gold meant well before the presentation caught up. A new `src/deferred.lua` holds the sweep instead of running it immediately, ticked from the engine's own `core.update` hook (the only per-frame seam a mod has, composed the same way `src/hpscale.lua` already wraps `battle.overlay`) for 1.5 real seconds -- long enough to clear a knockout's hit flash, HP-bar drain and faint slide on a native boot, short enough that nobody watching the victory fanfare notices the party settling a beat late. Gen 1 needed no change: `BattleState:finish` only raises `battle.ended` once its own animation queue has already drained, so an immediate sweep there was already in sync with what the player was watching.
- **A Gold Pokemon's row icon in the party list never reflected a persistent, fusion or condition-driven form either -- the identical species-keyed gap 0.44.0 fixed on the party STATS screen, one screen over.** `PartyMenu:iconIdFor` maps a species straight to an `ICON_` sheet name with no notion of `mon.form` at all, and the `pokemon.icon` hook it does call exists for a mod supplying a whole replacement two-frame icon sheet per icon id -- something no sprite mod ships per form (universal_sprites refuses Gen 2 icons outright). `src/gen2formview.lua` now wraps `PartyMenu.drawIcon` the same way it already wraps `SummaryMenu.drawPic`: it asks the real `pokemon.sprite` hook first and falls back to the form record's own `spriteFront`, the identical art the STATS and battle screens already draw, fitted down into the icon's 16x16 slot instead of up into the STATS picture's 56x56 one. The held-item marker still draws on top of it, since a Pokemon wearing a persistent form is, by construction, holding the item that grants it. `game/src/ui/gen2/BoxMenu.lua`'s identical gap did not fall out of this pass -- it is a separate class with its own `picFor`, tracked separately, and stays unbuilt here.

### Known

- **A player reported Aegislash's stance change no longer working on Red at all -- a regression, since an earlier session confirmed it working in a real game.** Driving the real `src/conditional.lua`, `src/forms.lua` and `src/resolve.lua` against the actual National Dex `AEGISLASH`/`AEGISLASH_BLADE` records -- entering Blade Forme on an attacking move, no-oping on a repeat, reverting on a status move, re-entering, and the battle-end sweep clearing the marker afterward -- every step worked exactly as designed, with the identical code that shipped in 0.43.0 and 0.44.0's own tracing pass; nothing in the diff between those releases and the version this was last confirmed working in changes the `move_kind` trigger's behaviour. This could not be reproduced this pass, the same outcome an earlier session already recorded for the same report on Gold. If it recurs, DEBUG TRACE (off by default) should name the cause outright -- that is exactly what 0.44.0 built it for.

## 0.44.0

### Fixed

- **A Gold Pokemon's PICTURE on the party STATS screen never reflected a persistent, fusion or condition-driven form -- a Giratina holding the Griseous Orb kept showing base Giratina there even after 0.43.0 fixed the same screen's stats and types.** `SummaryMenu:picFor` reads `data.pokemon[mon.species].spriteFront` straight off the BASE species and raises no hook, so neither this mod nor a sprite mod could ever reach it -- the identical seam National Dex's own `src/gen2dexlist.lua` and `src/gen2summary.lua` had already found and worked around for their own art on Gold's dex and this exact screen. `src/gen2formview.lua` now wraps `SummaryMenu.drawPic`, not `picFor`: confirmed against the real class that the shading decision a picture needs (skip the Game Boy palette for full-colour art, or the crush National Dex's own HANDOFF.md documents for this screen recurs) lives one level up, in `drawPic`'s own call to `drawPicBlock`, so `picFor`'s plain Image return could never have carried it. The fix asks the sprite mod through the real `pokemon.sprite` hook the battle screen already fires -- the same seam the bug report named outright as the one thing this screen never raised -- and falls back to the form's own record picture, drawn through the exact treatment every other mon's picture already gets here, when there is no hook answer. Composes with National Dex's own species-level art on the same method: this module's wrap always ends up outermost, since battle_forms declares national_dex a hard dependency, and it decides only for a mon actually wearing a battle_forms form, leaving everything else to whatever drew before it.
- **`src/conditional.lua` had no diagnostic at all, unlike `src/primal.lua` beside it, which is exactly what left a report that Aegislash never changes stance in battle with nothing to go on beyond "the event reached."** Every enter/leave attempt now traces through a new `src/diag.lua` `M.conditional` -- the species, the row matched (or the mismatched trigger it matched instead), the move's own power for a stance check, and `becomeForm`'s or `revertMon`'s own reason. Driving the real mechanism end to end -- the real National Dex data through its real Gen 2 registration reshape, the real Runtime event bus, NATIONAL DEX forced on -- found no defect: `AEGISLASH_BLADE` registers with the correct split stats and Aegislash's Blade Forme applies exactly as it should. The cause of the specific report stays open; this trace is what would name it outright if it recurs.

## 0.43.0

### Added

- **Terastallization works on Gold -- type change only, no Tera Blast.** `src/tera.lua` branches on Gen 2 the way `src/mega.lua` and `src/persistent.lua` already do: there is no battler on Gold to hold a `curTypes` copy, so the override writes `mon.formTypes` directly, the field `src/gen2forms.lua`'s `Battle.speciesDef` wrap already reads for a persistent or fused form and installs unconditionally on a Gen 2 boot, so no new engine patch was needed. It reapplies on every switch-in ahead of persistent's and fusion's own reapply (main.lua's own event order), because either would otherwise overwrite `mon.formTypes` with its own form's types on a mon carrying both -- Tera stays the outermost layer on Gold exactly as it is on Red/Blue/Yellow. TERA BLAST's own substitution is left out on purpose: Gold has no `curMoves` array to swap the way `src/substitute.lua` does (0.42.0's own finding on Dynamax and Z-Moves, extended here rather than reopened), so a Gold Pokemon that already knows TERA BLAST keeps it as a plain Normal-type attack even after terastallizing. The battle message goes through a Gen 2 channel of its own -- `Battle:emit`, drained the same way `game/src/ui/gen2/BattleState.lua` shows any engine message -- because Gold's engine object has neither `say` nor `sayNext`; there is nothing else to notice a Terastallization by on that game, so this pass built the channel (`announce.lua`'s new `gen2Tera`) rather than shipping it silent the way mega evolution's own message still is. There is no animation either, and none was built: Gold has no `animNext`/`animationsOn` to call, and none is needed -- the picture (where one exists) updates on its own because Gold's sprite draw reads `mon.form` fresh every frame rather than through a cached `battler.sprite`. The Tera Orb now sells at the Indigo Plateau counter alongside the Key Stone and the active mega stones. Confirmed by a headless suite that drives the real, load-patched `BattleState.update` through the same FIGHT-column-to-`battle.turn_started` sequence 0.42.0 held mega evolution to, and reads the type and the message back off the real engine objects.
- **Fusion and Ultra Burst gained a real Gen 2 primitive, using the identical `gen2forms.becomeForm`/`mon.item` substitutions `src/persistent.lua` and `src/mega.lua` already made -- but neither is reachable in a real Gold game.** Fusion's own trigger item (the DNA Splicers, the N-Solarizer, the N-Lunarizer, the Reins of Unity) cannot be used on Gold at all: `Game2:usePartyItem` calls `ItemEffects.partyAction(itemId)` with no `data` argument, so it can only ever resolve the engine's own built-in item_effects table -- confirmed in 0.39.0 for every mod's Gen 2 field item, regardless of what it registers, and the party picker never even opens. Unlike a persistent form, GIVE cannot stand in for USE here: holding the item does nothing on its own, and fusion needs an ACTION -- moving a second Pokemon to the PC, writing two markers -- that only a working item effect can perform. Ultra Burst sits on top of fusion, so its own cell can never appear on Gold either until that gap closes. What ships here is the mechanism, proven against the real primitives and the real event chain and ready the day either gap does.

### Fixed

- **`src/resolve.lua`'s battle-end sweep and faint handler were deleting any party mon's form marker they did not personally recognise, which included every OTHER mod's.** The sweep asked `src/fusion.lua` and `src/persistent.lua` whether a mon's form was theirs and, failing both, cleared `mon.form` unconditionally -- sound while this mod was the only thing that ever wrote that field, and wrong the moment a sibling mod (`wild_forms`, catchable regional and Minior forms) started marking Pokemon through the identical field for a form meant to outlive the battle the same way a persistent held-item form does here. A new `ownsForm` check now asks first whether the mon's current `mon.form` is a suffix ANY pairing table this mod actually owns (megas, primal reversion, the persistent held-item families, Ultra Burst, fusion, the condition-driven forms, Gigantamax) could have produced for that species; a marker matching none of them is left completely untouched, and on Gold that means the real `mon.stats` field is left alone too, not just the marker. A leftover form this mod DID set still reverts exactly as before -- the fix is precedence, not exemption, the same principle 0.35.0 established for the fusion/Ultra Burst collision.
- **Primal reversion did not work on Gold at all -- confirmed by a player, and the report named the cause outright: the Red and Blue Orbs offer USE and GIVE, USE does nothing, and only GIVE works for a mega stone.** `src/primal.lua` read `eligibility.STAMP`, the Gen 1 bag stamp, on both generations -- a field GIVE (the party ITEM row's real held-item write, and the ONLY working trigger for one of these items on Gold, since `Game2:usePartyItem` cannot reach this mod's own item_effects at all) never touches. A Groudon genuinely holding the Red Orb was therefore never primal on Gold, however it got the orb. `src/primal.lua` now reads `mon.item` on Gen 2, the identical substitution `src/mega.lua`'s own Gen 2 branch already makes, and dispatches to `src/gen2forms.lua`'s `becomeForm`. `src/stone.lua`'s own registration (mega stones, the orbs, Ultranecrozium Z) and `src/keyitems.lua`'s trainer items now also carry `fieldMenu`/`battleMenu = "ITEMMENU_NOUSE"` on Gen 2, the same treatment held-item forms got in 0.39.0, so the dead USE verb that misled this exact report is gone from the PACK on every item this mod sells there.
- **Aegislash's stance change (and the other seven condition-driven forms: Darmanitan, Minior, Wishiwashi, Morpeko, Mimikyu, Eiscue, Greninja) did not work on Gold either, for an unrelated reason -- these carry no item and no gate at all, so there was no eligibility read to have gotten wrong.** `src/conditional.lua`'s `enter`/`leave` called `src/forms.lua`'s `becomeForm`/`revertForm`, built on the Gen 1 battler wrapper (`battler.mon`) Gold's raw mon never has -- every trigger fired correctly (the right event, the right row) and the primitive itself silently found no target. Both now dispatch to `src/gen2forms.lua` on Gen 2, the same substitution every other form-changing module in this mod already makes.

### Known

- **Extensive investigation, driving the real, wrapped `game/src/ui/gen2/SummaryMenu.lua` class exactly the way `game/src/ui/gen2/PartyMenu.lua`'s own `openStats()` constructs it (party + index, `mon.form` left deliberately unset to match a freshly-given item), found no defect in `src/gen2formview.lua`: the overlay resolves through `mon.item` and draws the form's own types and stats correctly in every scenario this session could construct, including the exact one reported (a Pokemon given a held-item form and never yet battled with).** A player reported a held-item form's stats and types showing correctly in battle but not on the party STATS screen. `gen2formview.install` is confirmed reached on a Gen 2 boot with `deps.fusion`/`deps.persistent` both bound, `Gen2SummaryMenu` is confirmed to resolve to the same class this module wraps, and `src/persistent.lua`'s `formIdFor` is the identical call both the in-battle and the party-screen paths make, so a working in-battle report and a broken party-screen one cannot be explained by anything this module reads or does differently between the two. `tests/battle_forms_gen2formview_test.lua` gained a section driving the real class end to end (the earlier suite here stubbed the whole engine class, the identical trap that cost this repo the Gen 2 menu cell once already) so a future regression would be caught here rather than reported by a player again -- but this pass could not reproduce the bug and did not change `src/gen2formview.lua` itself. Needs either a live-boot confirmation this environment cannot perform, or more specific repro detail (which other mods are enabled, whether the STATS screen was already open before the item was given) to take further.

## 0.42.0

### Added

- **Gold gets the battle menu cell, and mega evolution is confirmed working through it.** Every other manual transformation here has been gated behind a fifth command-menu entry since 0.12.0, and that entry only ever existed on Red/Blue/Yellow -- Gold's battle screen is a different class (`src/ui/gen2/BattleState.lua`) with its own geometry and its own hard-coded 2x2 input grid, not a loop over the label list the draw side reads, so it needed a wrapper of its own (`src/gen2menu.lua`) rather than a branch inside the existing one. It lives in the same blank spacer row Gen 1's cell does -- Gold's own command box turns out to sit at the identical screen position, tile for tile -- and opens the same `src/formmenu.lua` list unchanged, since that module already reads whichever battle object it is handed. `src/mega.lua` now branches on Gold: the real held-item slot (`mon.item`) decides which stone a Pokemon is carrying rather than the bag-use stamp Gen 1 invented for a game with no such slot, and `src/gen2forms.lua` is the primitive that actually rewrites `mon.stats` and the Pokemon's types, since Gen 1's primitive is built on a battler wrapper Gold's engine never hands out. The Key Stone and this boot's own active mega stones now sell at the Indigo Plateau counter alongside the persistent held-item forms, because a cell with correct code behind it is not a reachable feature if nothing sells what it needs -- mega evolution needed both a trainer item and a Pokemon item and neither had a route onto Gold before this. Confirmed by a headless suite that drives the real, load-patched `BattleState.update` through a full FIGHT-column press, list-open, confirm and `battle.turn_started` sequence and checks the mon's own `form`/`stats` fields, the same discipline `battle_forms_formmenu_test.lua` already holds Gen 1 to.

### Known

- **Mega Rayquaza's own trigger, the battle message and the transformation flash are not extended to Gold in this pass.** Only the two-tier Key Stone plus Mega Stone gate applies there; Dragon Ascent's exemption stays Red/Blue/Yellow only. `src/announce.lua` assumes Gen 1's battler shape and the flash is played through methods (`animNext`/`animationsOn`) that exist on Gen 1's `BattleState` and nowhere on Gold's engine object, so a Gold mega evolution is silent and unanimated -- mechanically correct, cosmetically bare.
- **Dynamax, Terastallization, Z-Moves, fusion and Ultra Burst still have no menu cell entry on Gold.** All five are registered in the same shared registry and would need a Gen 2-aware `available`/`activate` of their own the way mega evolution just got, and two of them -- Dynamax's Max Moves and Z-Moves themselves -- need something mega evolution does not: substituting a Pokemon's moveset. Gen 2 has no `curMoves` array to swap the way `src/substitute.lua` does on Gen 1 (moves live on the mon directly, the same object the save writes), so that mechanism needs a mutate-and-restore primitive of its own, on the model `src/gen2forms.lua` already set for stats -- and until one is built and proven, arming either on Gold would be either inert or would risk writing a move list wrong, which is a save-corruption class of mistake this mod has avoided since 0.2.1. Left unbuilt rather than shipped half-working.
- **Contest battles (`BATTLETYPE_CONTEST`, the Bug-Catching Contest) and the DUDE's tutorial battle (`BATTLETYPE_TUTORIAL`) never show the cell on Gold.** Neither battle type has any use for a transformation -- a contest is decided by catching one Pokemon and holding it, not by winning a fight, and the tutorial sends the player no Pokemon of their own to transform.

## 0.41.0

### Changed

- **The gimmick cell now opens a submenu instead of cycling with LEFT/RIGHT, and shows what is armed instead of a generic label.** LEFT/RIGHT used to do two jobs on the cell -- move between commands everywhere else, cycle between transformations here -- because the cell had only one spare row to show them in and cycling was the only way to fit more than one. Pressing A now opens `src/formmenu.lua`'s own list, shaped like the FIGHT menu's move list, with one row per transformation currently on offer; UP/DOWN move a cursor with no side effect, A confirms the highlighted row (arming or disarming exactly as the old toggle did, substitution and all), and B backs out leaving whatever was armed before untouched. Re-opening the list while something is armed starts the cursor on it, so switching to a different transformation or disarming outright are both one press away. The cell itself reads FORM until something is armed and then switches to that transformation's own name (MEGA*, DYNAMAX*, and so on) rather than a trailing asterisk on whatever the cursor last happened to rest on, which is a far more visible change on arming and was the whole point of the second half of this ask -- a player could arm a transformation before and have almost nothing on screen say so.

## 0.40.0

### Added

- **G-Max Moves ship for the 31 wired Gigantamax forms -- names, types and base powers only, with no effect of any kind, stated here and in `mod.card` rather than left for a player to discover mid-battle.** A second, species-aware picker (`src/gmaxmoves.lua`) now runs inside `src/dynamax.lua`'s own `arm` step, checked before the ordinary type-based Max Move picker on every slot: a Gigantamax Pokemon's damaging move of its G-Max Move's own type becomes that move instead -- G-MAX WILDFIRE in place of MAX FLARE for a Gigantamax Charizard's Fire moves -- riding the identical seven-rung power ladder `src/maxmoves.lua` already owns, read live rather than copied a second time, while every other type in the same moveset still becomes an ordinary Max Move. No additional effect is modelled, because Gen 1 predates weather outright and has no residual-damage, field-effect, PP-draining or multi-turn-effect primitive in `MoveEffects` for Wildfire's four-turn burn, Cannonade's or Vine Lash's own field damage, Volcalith's rockfall, Depletion's PP drain, or any of the rest of what these moves actually do in the real games -- the concept exists and this engine has nothing to build it from, so a G-Max Move here hits as a plain damaging move of its real type and power and says nothing more. G-Max Drum Solo, G-Max Fireball and G-Max Hydrosnipe are the one exception and are modelled in full, at their real fixed 160 power regardless of the move they replace: their whole effect past damage in the real games is ignoring an ability, the identical shape Sunsteel Strike and Moongeist Beam were given in 0.36.0, and with no abilities in this engine at all there is nothing left for that clause to still be doing. Every display name is shortened to fit the FIGHT menu's 13-column classic / 12-column widescreen budget -- "G-MAX WILDFIRE" alone is fourteen -- merged into the single name map `zmovemenu.install` takes, since that call accepts only one wrap per boot. The roster matches `data/gigantamax.lua` exactly: Corviknight and the Low Key and Rapid Strike variants of Toxtricity and Urshifu carry no row either, for the identical reason they carry no Gigantamax form at all.

## 0.39.0

### Added

- **Holding the Griseous Orb now turns a Giratina into Origin Forme on Gold, the way the real games have always worked -- previously nothing on that game ever read Gold's own held-item slot.** Every persistent form here derived from `battleFormsStone`, a field this mod invented because Gen 1 has no held-item slot at all to read; Gold has one (`mon.item`, the same field `src/battle/gen2/Battle.lua` already reads for LUCKY_EGG, EXP_SHARE and EVERSTONE), and nothing here ever asked it. `src/persistent.lua`'s `M.formIdFor` now reads `mon.item` on Gen 2, ahead of the bag-use stamp, so a Pokemon that is actually HOLDING one of the nine held-item families' items wears its form -- confirmed on a real Gold boot in battle, on the SUMMARY screen, across a real switch and after a real battle end, with no bag use involved anywhere in that chain. Where the real held item and the bag-use stamp disagree (Rotom's five appliances are the one family that can), the real held item wins: it is Gold's own field, the one the SUMMARY screen's ITEM row already names.

### Fixed

- **Pressing USE on one of these items did nothing at all on Gold -- no message, no party picker, unlike a Berry.** `Game2:usePartyItem` calls `ItemEffects.partyAction(itemId)` with no `data` argument, so it can only ever consult the engine's own built-in item_effects table and never a mod's merged one -- no mod's Gen 2 field item is reachable through that dispatcher on any item, regardless of what shape it registers, and there is no seam here to patch that engine-side gap without touching engine dispatch logic. Rather than leave a USE verb on screen that silently does nothing, these items now carry `fieldMenu`/`battleMenu = "ITEMMENU_NOUSE"`, which takes the verb off Gold's PACK entirely in both pockets -- the more faithful answer on its own terms too, since the real games never offer a USE verb for a held item either (Leftovers and the Exp. Share show none). GIVE is the sole, working trigger for these items on Gold now; Gen 1 is unaffected and keeps bag USE as its only mechanism, since that game has no held-item slot to read at all.

## 0.38.0

### Added

- **Persistent held-item forms are buyable, usable and confirmed working on a real Gold boot -- the manifest now declares `gen2`.** Neither of Gold's mart registries (`text_pointers`, `map_scripts`) has a Gen 2 home, and `data/generated/marts.lua` is a bare, unnamed 1-based array in ROM order, so nothing in this source checkout said which numeric id was which real shop. The two ids came from a live ROM import instead: `data/generated/maps.lua`'s `CELADON_DEPT_STORE_4F` and `INDIGO_PLATEAU_POKECENTER_1F` each name a `SPRITE_CLERK` object with a `scriptKey`, and that key's row in `data/generated/scripts.lua` decodes to `pokemart 0, 26` and `pokemart 0, 32` -- cross-checked against that same cache's own `marts.lua`, whose list 27 sells POKé DOLL / LOVELY MAIL / SURF MAIL and list 33 sells ULTRA BALL / MAX REPEL / HYPER POTION / MAX POTION / FULL RESTORE / REVIVE / FULL HEAL, both exactly the real games' own shelves. A new `src/gen2shop.lua` wraps `MartMenu.inventory` -- the one function every dialog kind's buy list already calls through -- and appends the appliances at id 26 and the other six held-item forms, the Plates, the Memories and the Drives at id 32, wrap-and-delegate and idempotent like every other engine patch here. Confirmed end to end against a real Gold boot: bought a Griseous Orb at the Indigo Plateau counter, used it on a Giratina, watched Origin Forme apply on send-in, survive a real switch out and back, survive a real faint and a real battle end, and show its own types and stats on the SUMMARY screen.
- **Fixed the SUMMARY screen overlay never drawing on Gold, which the 0.37.0 headless suite could not have caught.** `src/gen2formview.lua` wrapped `SummaryMenu.draw`, and `SummaryMenu:draw()` is defined as nothing but `self:drawPanel()` -- but the real render pipeline never calls `:draw()` at all; every Gen 2 screen in this engine, this class included, is driven by whatever owns the frame calling `:drawPanel()` directly, with `:draw()` left an unused alias. A fixture harness that calls `SummaryMenu.draw(fakeSelf)` by hand cannot tell the two apart, so the previous suite installed cleanly, passed every check, and never painted a single pixel in a real game -- caught only by counting live calls through a real START -> POKeMON -> STATS navigation on an actual Gold boot, which saw `drawPanel` invoked every frame and `draw` not once. The wrap now targets `drawPanel`; the suite now proves the same class does, and a live screenshot of Giratina's SUMMARY page after the fix shows ORIGIN's own ATTACK/DEFENSE/etc. and GHOST/DRAGON typing rather than the base species'.

### Known

- **Every other mechanic here -- mega evolution, primal reversion, Dynamax, Terastallization, Z-Moves, fusion, Ultra Burst, the condition-driven forms -- still has no menu cell and no shop stock on Gold.** The persistent held-item forms needed no menu cell, which is what made them buildable first; the battle menu's fifth entry and the rest of `src/shop.lua`'s eleven other shelves are unbuilt for Gold and stay Red/Blue/Yellow only.

## 0.37.0

### Added

- **Persistent held-item forms now apply correctly in a Gold battle, and their real types and stats now show on Gold's own SUMMARY screen -- both still unreachable in a real game, because the items are not yet sold there.** `src/persistent.lua`'s send-out handler called `src/forms.lua`'s `becomeForm`, which assumes Gen 1's battler wrapper (`battler.mon`) -- on Gold, `battle.player`/`battle.enemy` already ARE the mon, so that call always found no target and applied nothing. `M.apply` now dispatches to `src/gen2forms.lua` instead when this boot is Gen 2, a flag read once at load the same way `national_dex`'s own `src/gen2shape.lua` reads the generation, rather than inferred from which fields a payload happens to carry. A new `src/gen2formview.lua`, modelled on `src/formview.lua`, draws the active form's types and stats over Gold's SUMMARY screen -- its own class, with its own page layout and `specialAttack`/`specialDefense` as two rows where Gen 1 shows one `special` -- recomputed fresh from the form's own record on every draw rather than trusted from `mon.stats`, because Gold's own level-up recomputes that field from the BASE species alone and would otherwise show stale numbers for a form the Pokemon is still genuinely wearing until its next battle corrects it again.
- **Confirmed, empirically, that Gold's form data is already correctly shaped: no `gen2shape.lua`-style splitting is needed for alternate-form records.** This mod's own `data/*.lua` files are pairing tables (species -> item -> form id) carrying no stat blocks of any kind -- the concern flagged in 0.32.0 as unverified. The stats come from National Dex, whose `nationaldex.lua` runs every record in its `register` block, base species and the 326 alternate forms alike, through the same `gen2 and gen2shape.record(record) or record` line -- a form record is never `romOwned` (that check requires `record.form == nil`), so it always takes the reshaping branch on a Gold boot. Nothing needed building here.

### Known

- **The persistent forms are still unreachable in a real Gold game: the items are not sold anywhere on that game, and `manifest.json` still declares `gen1` alone.** Gold's shop stock has no registry route at all -- `text_pointers`, the registry `src/shop.lua` patches on Red/Blue/Yellow, is one of the six registries `Schemas.GEN2` marks as having no Gen 2 home outright, not merely a differently-shaped one, so a patch through it is silently dropped and reported. The raw table Gold's own mart screen reads (`game.data.gen2Marts`) has no registry pointing at it either, and which numeric mart id corresponds to which real shop is ROM-extracted at import time -- nothing in this source checkout names it, and guessing one risked shipping stock in the wrong shop, or none, with no way to verify it against a real cartridge. It stays unbuilt rather than shipped unverified. `manifest.json`'s `games` stays `["gen1"]` because of it: a mod that loads on Gold and half-works is worse than one that honestly does not load, and nothing here is buyable, so nothing here is a coherent feature yet.

## 0.36.0

### Fixed

- **Ten of the fourteen species Z-Crystals shipped in 0.27.0 permanently
  unreachable.** Pikashunium Z, Snorlium Z, Incinium Z, Primarium Z,
  Lycanium Z, Mimikium Z, Kommonium Z, Solganium Z, Lunalium Z and
  Marshadium Z each key off a base move (Volt Tackle, Giga Impact, Darkest
  Lariat, Sparkling Aria, Stone Edge, Play Rough, Clanging Scales, Sunsteel
  Strike, Moongeist Beam) National Dex registers with `effectModeled =
  false`, and that flag permanently bars a move from any learnset National
  Dex builds, MOVES=ALL included -- so nothing could ever be taught them.
  `src/speciesbasemoves.lua` now models each move's real effect -- Volt
  Tackle's one-third recoil and 10% paralysis chance, Giga Impact's forced
  recharge (repointed at the engine's own native `HYPER_BEAM_EFFECT` rather
  than a copy of it, since that already is Giga Impact's real effect),
  Darkest Lariat's damage ignoring the target's Defense stage, Sparkling
  Aria curing the target's burn, Stone Edge's high critical-hit ratio
  (the move record's own `highCrit` field, needing no handler at all),
  Play Rough's 10% Attack-lowering chance, and Clanging Scales' own
  Defense drop -- flags each honestly modelled, and teaches it to its
  species directly, the same reachability fix 0.29.0 gave Dragon Ascent
  and 0.34.0 gave Tera Blast. Sunsteel Strike and Moongeist Beam are
  taught as plain damage: their whole real effect beyond that is ignoring
  the target's ability, and this engine has none at all, so there is
  nothing left over for a handler to add.
- **Marshadium Z (Spectral Thief) is fixed the same way**, stealing every
  positive stat stage the target is carrying onto the user before the hit,
  across every stage this engine tracks, capped at +6 -- and happening
  whether or not the hit goes on to land, matching the real move.
- **Mewnium Z never registered its Z-Move and logged a warning on every
  boot.** `data/speciesz.lua` named the base move `PSYCHIC`, but National
  Dex registers Psychic under `PSYCHIC_M` -- pokered's own constant name
  for the move, kept because the plain `PSYCHIC` id already belongs to
  something else in this engine -- so the lookup found nothing and Genesis
  Supernova never built. Fixed to name the real id. No teaching patch was
  needed alongside it: TM29 is Psychic in Gen 1, Mew can learn every TM in
  the real games, and National Dex leaves an id the cart already owns
  alone rather than overriding it, so an ordinary save already has Mew
  knowing Psychic under this same id with NATIONAL DEX off and no help
  from this mod at all.

### Known

- **Decidium Z (Spirit Shackle) is refused, not merely unfinished.** Spirit
  Shackle's real effect beyond damage prevents the target switching out,
  and this Gen 1 engine has no seam a mod can reach to block a switch
  decision -- no event fires before one, and nothing on a battler tracks
  it, unlike Gen 2's own trapping moves. Building one would mean changing
  engine code, which is out of reach here, and shipping it as plain damage
  with an honest-modelled flag would be exactly the stub this reachability
  fix exists to refuse elsewhere. Decidueye's crystal stays exactly as
  unreachable as it has been since 0.27.0.
- **Almost everything on this mod's list needs National Dex's own NATIONAL
  DEX option turned on, not merely National Dex installed.** Every species
  and form pseudo-record beyond Kanto's own 151 -- every mega, every
  primal, every persistent held-item form, both fusions, Ultra Burst and
  eleven of these fourteen species Z-Crystals' own species -- lives in
  National Dex's `national.lua`, which its `main.lua` only loads when that
  option reads `on`, and it defaults to `off`. `mod.card` advertised the
  whole feature list with no mention of this; it now says so plainly.

## 0.35.0

### Fixed

- **Giving a fused Necrozma Ultranecrozium Z reverted it to plain Necrozma in
  the party menu.** Ultra Burst (0.22.0) made Necrozma both a fusion base
  (`data/fusion.lua`) and an eligibility-stamp item user (`data/ultraburst.lua`,
  through `src/stone.lua`'s paired install), which is exactly the case
  `src/persistent.lua` assumed could never happen. Handing over the crystal
  called `persistent.mark`, which could not find Necrozma in its own
  `data/persistent.lua` table and unconditionally cleared `mon.form` --
  wiping the Dusk Mane or Dawn Wings suffix `src/fusion.lua` had just set,
  while leaving the fusion stamp and the crystal itself untouched. A second
  report that pressing BURST left the Pokemon as Dusk Mane could not be
  reproduced separately -- `activate()` always either fully transforms or
  refuses loudly -- and reads as the same defect seen at a different moment,
  since the marker was already gone by the time BURST was pressed.
  `persistent.mark` now asks `src/fusion.lua` before it falls back to
  clearing the marker, the same order `src/resolve.lua`'s own party sweep
  already used for the identical reason.

## 0.34.0

### Fixed

- **TERA BLAST, added in 0.27.0, could not actually be learned by any
  Pokemon.** National Dex registers the move, and Terastallizing already
  substituted it into the chosen type correctly whenever a Pokemon happened
  to know it -- but nothing taught it to anything: it sat in no species'
  learnset and no shard National Dex's own MOVES=ALL widening reads either,
  so the whole eighteen-type substitution was built on a move a player could
  never actually have. A new item, TM171, fixes it the way the real games
  do: buyable on the Celadon department store's stone floor right behind
  the Tera Orb, it teaches TERA BLAST to any Pokemon that is not a mega,
  Gigantamax or other alternate-form entry -- those never appear as a
  battler's own species in this mod, so a Pokemon that can be caught,
  hatched or traded can learn it. Tera Blast's own real effect, becoming
  the Tera type, is what the substitution already does, so it is now
  honestly flagged as a modelled move rather than the placeholder National
  Dex had no choice but to register it as before this mod existed to make
  the claim true.

## 0.33.0

### Changed

- **Splitting a fused Pokemon no longer prints a "came back from the PC!"
  textbox.** The partner still comes out of the PC exactly as it did before
  -- that has not changed -- but the player no longer has to read a message
  to know it, for the same reason 0.28.0 dropped the matching line on the
  way in: 0.24.0's `src/boxmark.lua` already marks a boxed fusion partner
  with an F in the WITHDRAW and RELEASE lists and on its own STATS screen,
  and that marker is simply gone the instant the withdraw happens, which
  answers "where did it go" on screen rather than in a line printed once
  and then gone. The one exception is the anomaly branch, where the partner
  was released, traded or lost to a Game Boy `.sav` export: that page still
  prints, because there is no marker for a Pokemon that never came back and
  nowhere else for the player to learn it.

## 0.32.0

### Added

- **`src/gen2forms.lua`, the Gen 2 form primitive -- groundwork only, still
  unreachable from any battle.** Gen 2 has no battler wrapper for
  `curStats`/`curTypes` to override, so stats follow the one precedent the
  engine already has: `Battle:transform` mutates `mon.stats` in place and
  restores it on the way out, and this module does the same, except nothing
  needs caching for the restore -- `mon.species` never moves, so
  `data.pokemon[mon.species].baseStats` plus the mon's own untouched
  dvs/level/statExp recompute the exact pre-form numbers on demand, the way
  `src/forms.lua`'s own revert already does for Gen 1. Types had no such
  seam: `Battle:speciesDef(mon)` is read first at roughly ten damage, AI and
  immunity call sites and never consults `mon.form`, and no Runtime hook
  covers all ten -- `battle.damage` wraps only the two full damage
  calculations, where Curse's Ghost check, Leech Seed's Grass check and the
  rest read `speciesDef` directly. `M.install` wraps `Battle.speciesDef`
  itself instead, the one thing every one of those sites already funnels
  through, guarded and delegating the way every other engine patch in this
  codebase is, so a third-party mod's own wrap over the same method keeps
  running whichever order the two install in. `manifest.json` still declares
  `gen1` alone and nothing calls this module yet: there is still no Gen 2
  menu cell to trigger a form change from, so this step only proves the
  primitive itself -- apply, revert, and revert exactly through fainting,
  switching, a battle-end sweep and a mod disabled mid-battle -- against the
  real engine's own stat formula and its own `Battle.speciesDef`.

## 0.31.0

### Changed

- **Event handling is now generation-agnostic under the hood; nothing a
  player sees has changed.** Gen 1 and Gen 2 fire the same Runtime event
  names -- `battle.started`, `battle.battler_switched`, `battle.fainted`,
  `battle.turn_ended`, `battle.move_used`, `battle.damage_dealt` and the rest
  -- but with different payloads. Gen 1 hands every handler a battler
  wrapper (`{ mon = ..., isPlayer = ..., curStats = ... }`); Gen 2's own
  engine builds no such wrapper at all, so `battler`, `user`, `target` and
  `previous` on its events, and the live `battle.player`/`battle.enemy`
  fields, already ARE the mon. Every `battler.mon`-style read in the mod
  used to assume Gen 1's shape and would have silently returned nil on Gold.
  A new adapter, `src/battlerof.lua`, tells the two shapes apart from the
  wrapper's own `mon` field -- a raw Pokemon record never carries one -- and
  every event handler and switch-in check now reads through it instead.
  `manifest.json` still declares `gen1` alone: the mechanics that still need
  a real Gen 2 counterpart, chiefly the form primitive's
  `curStats`/`curTypes` override, are unbuilt, and this step only stops the
  next one from having to re-audit every event read by hand.

## 0.30.0

### Removed

- **RAYQUAZITE is withdrawn; Dragon Ascent is Mega Rayquaza's only trigger
  now.** The stone was always a stand-in for the real trigger, kept alive
  only because Rayquaza had no way into any save; wild_forms 0.2.0 placed one
  at Indigo Plateau, so that blocking condition is gone and 0.29.0's own
  promise to withdraw the stone once it was is kept. `data/megas.lua` carries
  no row for Rayquaza any longer, so `src/dragonascent.lua` can no longer
  read `RAYQUAZA_MEGA` off that table the way it did through 0.29.0 -- it now
  names the record's own key as its own literal, checked against National
  Dex directly by `tests/battle_forms_formids_test.lua` the same way every
  other form id here is. A Rayquaza already holding a Rayquazite from an
  earlier version keeps it: the item is simply no longer registered, so it
  neither triggers anything nor vanishes from the bag. Byte 172 stays
  permanently reserved in `data/stones.lua`, as this file's own rule requires
  of every stone byte once assigned.

### Fixed

- **DEBUG TRACE now reports Mega Rayquaza's real reason.** The trace's menu
  line answered mega eligibility purely through the held-stone path, so a
  Dragon-Ascent-triggered Mega Rayquaza -- which stamps no item at all --
  always read `stone=nil form=nil`, indistinguishable from a mega that had
  simply failed. Now that RAYQUAZITE is gone, Dragon Ascent is the only path
  Rayquaza has, so that misreading would have become the sole answer this
  tool ever gave for it. The line now also names `trigger=`, `dragonascent`
  or `stone`, and reports whichever form actually resolved rather than only
  the stone-based half.

## 0.29.0

### Added

- **Mega Rayquaza now has its real trigger.** Dragon Ascent is a modelled
  move now -- 120-power Flying, physical, and it lowers the user's own
  Defense and Special Defense one stage after it lands -- registered through
  the same move-effect seam Max Guard already uses. A Rayquaza that knows it
  reaches the MEGA cell with no Key Stone and no mega stone at all, refused
  only by a held Z-Crystal, exactly as the real games rule it; every other
  mega still needs both items. National Dex's own DRAGONASCENT record and
  Rayquaza's learnset are patched from here rather than registered fresh,
  since both already exist -- the move's power, accuracy, type and PP are
  untouched, and the level-1 learnset row is appended alongside REST, FLY and
  HYPER BEAM rather than replacing them. Teaching the move lives here instead
  of behind National Dex's own MOVES=ALL option, because that option is off
  by default and would have left the mega unreachable out of the box, and
  because National Dex cannot honestly call the move modelled on the
  strength of an effect that lives in a mod it does not depend on.
  RAYQUAZITE still works, since Rayquaza is not yet placed in any encounter,
  gift or trade anywhere in the game -- it stays as a transitional trigger
  and will be withdrawn once one exists; its bag byte (172) is never reused
  regardless, matching the rule every stone in this mod follows.

## 0.28.0

### Fixed

- **The party menu and the STATS screen now show a formed Pokemon's real
  types and stats.** An Arceus holding a Flame Plate was genuinely Fire-type
  in battle -- `src/forms.lua`'s `becomeForm` already overrides the
  battler's `curTypes` and `curStats` from the form record -- but the STATS
  screen reads `data.pokemon[mon.species]` directly, and `mon.species` is
  deliberately never re-keyed by a form change, so it kept showing NORMAL
  and the base stat block regardless. `src/formview.lua`, a new draw-time
  wrap on `src/ui/SummaryMenu.lua`'s `draw` built the same way
  `src/boxmark.lua` and `src/hpscale.lua` already reach past the engine's
  own draw calls, now recomputes the form's types and stats from the same
  National Dex record `becomeForm` itself reads and paints them over the
  vanilla ones after the real draw has already run. Nothing is cached onto
  the Pokemon and nothing is written to it at all -- every value is
  recomputed on every draw, so a level-up between visits to the screen can
  never leave a stale number behind. HP and the name stay untouched on
  purpose: a form keeps the base form's HP in the real games, and the name
  is read off the unchanged species record, which was already correct. The
  party list itself draws no types or stats to begin with (only a nickname,
  a level and an HP bar), so the one wrap on the STATS screen is everywhere
  this needed fixing.

### Changed

- **Fusing two Pokemon no longer prints a "went into the PC!" textbox.** The
  partner still goes to the PC -- that has not changed and is not going to
  -- but the player no longer has to read a message to know it: 0.24.0
  already marks the boxed partner with an F in the WITHDRAW and RELEASE
  lists and on its own STATS screen (`src/boxmark.lua`), which stays on
  screen every time the PC is opened rather than only in a line printed
  once and then gone.

## 0.27.0

### Added

- **Tera Blast.** A Pokemon that knows it (National Dex already registers
  the move -- Normal, 80 power, special, 100 accuracy) plays it as an
  ordinary Normal-type attack until it terastallizes; while terastallized,
  arming the TERA cell substitutes that one slot for a variant carrying the
  chosen Tera type, the same move-substitution mechanism Max Moves and
  Z-Moves already use, and not a form or a second type-override system. The
  substitution goes on at arm time, before the FIGHT menu is drawn, and --
  unlike a Z-Move -- follows the Pokemon back in on every switch, because
  Terastallization itself does. Category stays Special explicitly on every
  variant, matching the real games and National Dex's own record, rather
  than falling through to Gen 1's type-based split the way the Max Moves and
  the type Z-Moves do.
- **Fourteen species-specific Z-Moves**, each behind its own crystal
  restricted to one species (or a small family of forms of it) and one named
  base move: Catastropika, Stoked Sparksurfer, Pulverizing Pancake, Genesis
  Supernova, Sinister Arrow Raid, Malicious Moonsault, Oceanic Operetta,
  Splintered Stormshards, Let's Snuggle Forever, Clangorous Soulblaze,
  Searing Sunraze Smash, Menacing Moonraze Maelstrom, Soul-Stealing 7-Star
  Strike and 10,000,000 Volt Thunderbolt (gated on Pikachu's eight cosmetic
  cap forms, matching the real games, rather than loosened to cover an
  ordinary Pikachu). These were refused outright in 0.17-ish on the grounds
  that every one of them keyed off a base move Gen 1 did not have; that
  stopped being true once National Dex 0.15.0 registered all 833 modern
  moves, and checking the data again rather than trusting the old refusal is
  what found this. Two of the real games' roster are still left out on
  purpose and for a different reason than the byte ceiling: Guardian of
  Alola computes its damage from the target's current HP rather than a fixed
  power, and Extreme Evoboost replaces its base move with a pure stat boost
  and deals no damage at all -- both a different shape from the fourteen
  this build covers, not a smaller version of it. All fourteen crystals sell
  on the Celadon shelf behind Ultranecrozium Z and share the Z-MOVE cell and
  the trainer's once-per-battle lock with the eighteen type Z-Moves.
- **Z-status effects.** A status move that already raises the user's own
  stat, used under a Z-Crystal of its own type, keeps its own effect exactly
  and additionally raises every other stat by one stage -- the one shape of
  the real games' Z-status bonus table this engine can build without
  inventing a ruling for the rest of it (sleep-inducing, paralysis-inducing
  and the other category-based bonuses are not modelled, and a status move
  outside this one shape still keeps only itself, as it always has). The
  bonus prints after the rest of the turn's own text rather than immediately
  behind the move's own "X's STAT rose!" line, because Gen 1's status-move
  pipeline has no hook between an effect resolving and the next one running,
  and it is applied at the same battle.turn_ended seam the substitution
  mechanism already unwinds through.

## 0.26.0

### Changed

- **Dynamax finally multiplies effective HP.** It shipped without this since
  0.11-ish because there is nowhere safe to write a doubled HP: max and
  current HP are both save data with no battle-only copy to move instead, and
  a single missed unwind on either field would be a permanent, undetectable
  change to a Pokemon's stats. HP itself is still never touched -- instead,
  incoming damage against the Dynamaxed Pokemon is halved before it lands,
  which is mathematically the same thing: doubling max and current HP and
  taking a hit of D leaves the same fraction of the bar as halving D against
  the untouched HP does. The halving carries a remainder across hits rather
  than flooring each one independently, which is what makes the survival
  count exactly match what doubled HP would have produced rather than merely
  approximating it. OHKO moves now fail outright against a Dynamaxed target,
  matching the real games, since they set their fixed 65535 damage directly
  and never go through the seam the halving hooks; Super Fang needed no
  change, because it already halves the target's current HP directly rather
  than dealing a fixed amount.

## 0.25.0

### Added

- **Genesect's four Drives -- Douse, Shock, Burn and Chill -- as held items
  that change its appearance and nothing else.** National Dex 0.26.0 added
  the four records this needed, and the sprite mod's form-art index picked up
  full front-and-back art for all four the moment it was rebuilt against
  them, so the same held-item mechanism every other persistent form here uses
  -- an item stamped on the Pokemon, a marker derived from it, undone by using
  the same item again -- covers them with no new code, only a new row in
  `data/persistent.lua`. They are the first purely cosmetic family this
  mechanism has carried: a Drive changes nothing else about Genesect, because
  the real games only ever change the type of Techno Blast, a per-move
  property no form record here can hold, and `mod.card` and this entry both
  say so plainly rather than leaving a stat or type effect implied. Sold at
  the Indigo Plateau lobby counter behind the Memories.
- **Real bag bytes, where the 34 Plates and Memories had to go without.**
  98-233 was full with no gap before this addition and 234-255 sat entirely
  unused -- `tests/battle_forms_keyitems_test.lua` now pins both facts
  directly -- so the four Drives fit comfortably at 234-237 with eighteen
  bytes still spare, and `data/drives.lua` gives each a real byte rather than
  the `false` sentinel the Plates and Memories needed when the same 22 bytes
  had 34 items competing for them. `src/persistent.lua`'s install() now names
  `data/drives.lua` alongside the other four indices tables in its "no bag
  index" refusal.

## 0.24.0

### Added

- **The fusion partner boxed in the PC now carries a marker, in the WITHDRAW
  and RELEASE lists and on the STATS screen reached from either.** Fusion
  (0.20.0) puts the partner Pokemon into an ordinary PC box rather than
  nesting it inside the survivor -- GenSave.lua's Game Boy `.sav` export
  rebuilds a mon from fixed offsets with no hook for a nested one -- which
  left the boxed partner looking like any other Pokemon a player could
  release by accident, with no way back for the fusion it silently ended. An
  `F` now prints beside its name wherever the engine draws it: right-aligned
  in the box list, through the same `item.right` field the Pokedex ball
  marker and the shop's price already use, and in a free two-tile gap on the
  STATS screen's dex-number row. Both are engine draw-seam wraps, not save
  writes -- a nickname was considered and rejected for writing to the save at
  all -- and the two are installed as one unit: if either seam has changed
  shape, neither is built, rather than a marker that appears in the list and
  not the screen it opens into.

### Fixed

- **Thirteen of the eighteen Z-Move names overflowed the FIGHT menu.** The
  classic layout draws a move's name with no truncation of its own, so a name
  longer than thirteen characters ran into the move box's border; the
  widescreen grid truncates with an ellipsis at twelve, which fit but made
  half the roster unrecognisable. `data/zmoves.lua` now carries a `menu`
  field beside each row's real `name` -- a short form of the same move,
  measured against both budgets and pinned at the tighter one in
  `tests/battle_forms_zmoves_test.lua` so a future rename cannot quietly
  overflow again -- and a new `src/zmovemenu.lua` redraws the FIGHT menu's
  name cell over top of whatever the engine just printed there, on both
  layouts. The registered move record is untouched: `name` is still what a
  save, the battle text row and Mimic see, and only the redraw ever reads
  `menu`.

## 0.23.0

### Added

- **Arceus's seventeen Plates and Silvally's seventeen Memories, the two
  families 0.21.0 investigated and left unwired for want of art.** The sprite
  mod's form-art index was rebuilt against the two type-named animated dumps
  it already had on disk and now carries a full front-and-back entry for
  every one of the 34 forms, so this mod's own gate on that -- "wire it if it
  has art" -- opens for both at once. Every Plate and every Memory pairs with
  its type the exact way Rotom's appliances pair with an appliance: one item,
  stamped on the Pokemon, one form derived from the stamp, and using the same
  item again takes it back off. Both are sold at the Indigo Plateau lobby
  counter, behind the six other held-item forms.
- **Neither family carries a bag byte, which is new.** Gen 1 stores an item
  as a single byte, 0-255; every earlier table in this mod packs 98-233 with
  no gap at all, which leaves 22 bytes free and the two new families need 34
  between them. Splitting the shortfall -- some Plates and Memories with a
  real byte, the rest without -- had no principled line to draw it on, so all
  34 are registered with none: they buy, stamp and hold their form on every
  save this mod supports exactly like any other held item, but none of them
  survives an export to a Game Boy `.sav` cartridge, where each is silently
  dropped from the bag the way an unrecognised item already is.
  `src/persistent.lua`'s install() now tells that difference apart
  explicitly -- an item's indices-table entry answering `false` registers it
  byteless and on purpose; an entry that is simply absent is still the same
  hard refusal it always was -- and `src/shop.lua`'s shelf sort, which used
  to assume every entry was a number, now sorts a byteless item after every
  real byte and alphabetically among its own kind.

## 0.22.0

### Added

- **Ultra Burst, the last unimplemented in-battle gimmick.** A Necrozma
  already fused into Dusk Mane or Dawn Wings -- through the N-Solarizer or the
  N-Lunarizer, shipped in 0.20.0 -- can now hold Ultranecrozium Z, a new
  nineteenth Z-Crystal sold alongside the other eighteen on the Celadon stone
  floor, and become Ultra Necrozma for the rest of the battle once the
  trainer's Z-Ring is on. It costs no turn, no move and no PP, joins the one
  manual transformation a trainer gets per battle alongside mega evolution,
  Dynamax, Terastallization and Z-Moves, and survives switching out the way a
  mega does, reverting only on fainting or when the battle ends. The item
  occupies the same held-item slot a mega stone or a type Z-Crystal does, so a
  Necrozma carrying Ultranecrozium Z cannot also be offered a Z-Move -- the
  crystal converts nothing on its own -- and the third gate, "already fused,"
  is answered by asking src/fusion.lua's own stamp rather than by teaching
  Ultra Burst anything about fusion itself. Reverting lands back on whichever
  fused form the mon burst from, not on a plain Necrozma, because the fusion
  never stopped being true underneath it.

## 0.21.0

### Added

- **Six more persistent held-item forms, on the exact mechanism Rotom's
  appliances proved.** The Griseous Orb, the Lustrous Globe, the Adamant
  Crystal, the Rusted Sword, the Rusted Shield and the Gracidea are now bag
  items sold at the Indigo Plateau lobby counter; using one on Giratina,
  Palkia, Dialga, Zacian, Zamazenta or Shaymin stamps the item and derives the
  matching form -- Origin Forme, Crowned Forme or Sky Forme -- the same way an
  appliance derives Rotom's, and using the same item again takes it back off.
  Nothing new was built to do this: src/persistent.lua's `rows` argument was
  already the whole pairing table rather than Rotom's alone, so the six new
  rows in data/persistent.lua and a second bag-byte table
  (data/heldforms.lua, 227-232) were the entire change, merged into one
  `M.install` call in main.lua the same way the appliances' bytes always were.
  Arceus's 17 Plates and Silvally's 17 Memories were investigated and left
  unwired: both have real held-item mechanics and a National Dex record for
  every type, but neither species has a single entry in the built form-art
  set, not even a base one, so every form between them would show as the
  plain species with nothing to tell it apart. Genesect's four Drives have no
  species record to name at all -- GENESECT_DOUSE/SHOCK/BURN/CHILL do not
  exist in the National Dex data -- so there was no id a pairing could point
  at.

## 0.20.0

### Added

- **Fusion for Kyurem, Necrozma and Calyrex, which takes a Pokemon out of the
  party and keeps it in the PC.** The DNA Splicers, the N-Solarizer, the
  N-Lunarizer and the Reins of Unity are bag items sold at the Indigo Plateau
  counter beside the orbs; using one on the base Pokemon while its partner is in
  the party joins the two, and using it again separates them and hands the
  partner back exactly as it went in -- same level, moves, PP, stats and DVs.
  The partner is deposited into the PC rather than carried inside the Pokemon it
  was fused with, which was the other option and the worse one: a Game Boy `.sav`
  export rebuilds every mon from fixed offsets and drops fields it does not know,
  and there is no hook anywhere near it, so a partner stored inside another
  Pokemon would have been deleted by an export with nothing able to say so.
  Boxes go through that same export intact, so a fused pair exported to a
  cartridge comes back as two plain Pokemon -- one in the party, one in the box
  it was put in -- and the way back is to fuse them again. Only two strings are
  written: which partner went in, and which Pokemon it is inside; the form is
  derived from the first of those, and no species, stat block, HP or move list
  is touched on either half. Fusing refuses without moving anything when there
  is no partner in the party, when it would leave the party with nothing able to
  battle, and when all 240 PC slots are full; separating refuses when the party
  is full. Where one item has two possible partners -- Kyurem with both Reshiram
  and Zekrom, Calyrex with both steeds -- the first in party order is taken, so
  reordering the party is how the other is chosen.

## 0.19.0

### Added

- **A form that outlives the battle, and the first thing this mod writes into a
  save.** Rotom's five appliances are now bag items sold on the Celadon stone
  floor; using one on a Rotom puts it in that appliance's form and leaves it
  there through the battle, the party sweep, saving and reloading, and using the
  same appliance again takes it back off. Every form before this was cleared by
  the battle-end sweep, which is what kept them safe, so the persistent one is
  derived rather than remembered: the item stamped on the Pokemon is the truth
  and the form marker is computed from it, which is why the sweep needs no way
  of telling the two kinds apart -- it writes whatever the pairing table
  vouches for and deletes everything else, so a mega still cannot reach the save
  and an appliance form still cannot be swept out of one. The species, the stat
  block, current HP and the move list are never written, so the form changes the
  Pokemon's picture and its types in battle and nothing that a level-up or a
  save validation would disagree with. Exporting to a Game Boy `.sav` loses both
  fields, because the cartridge party struct is 44 bytes with every one of them
  spoken for: a Rotom comes back plain, having forgotten which appliance it was
  in, and never as a different Pokemon or as a base form carrying a form's
  stats. Fusion, regional forms, cosmetic forms and Ultra Burst are deliberately
  not part of this.

## 0.18.0

### Changed

- **Max Moves and Z-Moves are selectable on the turn they are armed.** Both
  mechanics swapped the battler's move list at the start of the turn, which the
  engine raises only after both actions are already chosen and holds a direct
  reference to the move slot the FIGHT menu handed over -- so the new moves
  arrived a turn late, costing a Dynamax one of its three turns and giving a
  player every chance to spend the battle's one transformation on a Z-Move that
  was never selectable. The swap now happens when the cell is armed instead,
  which is a step ahead of the FIGHT menu on the command menu, and every reader
  of the move list takes it fresh as it runs. Disarming puts the moveset back:
  pressing A a second time, or cycling to another transformation with LEFT and
  RIGHT, leaves the Pokemon holding exactly the moves it started with. The
  forms, the stats and the three-turn clock still land where they always did.

## 0.17.0

### Added

- **Z-Moves, on the move-substitution mechanism Max Moves were built on.** A
  trainer carrying a Z-Ring and a Pokemon carrying a Z-Crystal now turn every
  damaging move of that crystal's type into its Z-Move for a single use, at a
  power taken from the move being replaced and spending that move's PP. There
  are eighteen crystals, one per type, sold beside the key items at the head of
  the Celadon stone floor and stamped onto a Pokemon the way a mega stone is --
  which is the real games' held-item rule and means a Pokemon carrying a crystal
  is a Pokemon not carrying a stone. The substitution goes on after both actions
  are chosen, so the Z-Move is there to pick from the turn after arming, and it
  comes off at the end of the turn one of its moves is used rather than on a
  clock; switching out, fainting and the battle ending end it as well, and it
  counts as the trainer's one transformation for the fight. The
  species-specific Z-Moves are not included and neither are the Z-status
  effects: every one of the former keys off a base move Gen 1 does not have, and
  a status move under a crystal gains an effect rather than becoming a move,
  which no field on a move record here can say -- so a status move keeps itself.
  The eighteen names are the ones the move data carries and thirteen of them are
  longer than a Gen 1 move name, so the widescreen layout truncates them and the
  classic FIGHT menu draws them into its box border.

## 0.16.0

### Added

- **Max Moves, on a move-substitution mechanism built to be shared.** A
  Dynamaxed Pokemon's damaging moves now become the Max Move for their own type
  -- MAX FLARE for a Fire move, MAX GEYSER for a Water one -- with a power taken
  from the move being replaced, and its status moves become MAX GUARD, which
  shields it for the turn and goes first so that it can. Each Max Move spends
  the PP of the slot it stands in for and writes nothing else to the Pokemon at
  all: the battler's whole move list is swapped for one the battle owns and the
  original list is put back on the same four paths the Dynamax already ended on,
  because those move slots are the party Pokemon's own records and a single flag
  written into one would land in the save. The move a player picked on the turn
  they Dynamaxed still runs as itself -- the transformation resolves after both
  actions are chosen, which is what keeps it from costing a turn -- so the Max
  Moves are there from the second turn. G-Max moves are not included: nothing in
  the species data, the move data or the engine describes one, and a table of
  invented powers behind real names would be content this mod made up. Z-Moves
  are not part of this release either; they are the substitution mechanism's
  intended second consumer and will arrive through it rather than beside it.

## 0.15.0

### Added

- **Terastallization, which changes a Pokemon's type and nothing else.** TERA
  joins the battle menu cell once the trainer buys a Tera Orb, and the Pokemon
  that uses it becomes a single type for the rest of the fight: it takes damage
  as that type, gets the same-type bonus on it, keeps it across switching out
  and loses it only on fainting or when the battle ends. Which type is a mod
  option, TERA TYPE, read at the moment it is used rather than carried on the
  Pokemon -- a Gen 1 Pokemon has nowhere a player could set one, and defaulting
  to the type it already is would make the whole mechanic do nothing to a
  single-typed species. The three modern types are offered but resolve only in
  a game where National Dex has registered a chart carrying them; picking one
  the running game has no record for leaves the cell away and says why in the
  log. It counts as the trainer's one transformation for the battle, so it and
  a mega cannot both happen, and it writes nothing to the Pokemon at all -- the
  override lives on the battler, which the battle takes with it. Two departures
  are deliberate: the type is announced in two message pages because no
  eighteen-character row holds both halves of the sentence, and the Tera Orb is
  never used up, where the real games exhaust it until the next Pokemon Center.

## 0.14.0

### Changed

- **Using one of the transformations the player asks for now costs them the
  others for the rest of the battle.** Mega evolution and Dynamax each carried a
  once-per-battle limit of its own, so a trainer could mega on one turn and
  Dynamax on another in the same fight, which no mainline game allows -- Sun and
  Moon ruled Z-Moves against Mega Evolution exactly this way. Spending either
  one now takes the whole battle menu cell away for the remainder of that
  battle rather than leaving the other on it, and it goes the same silent way it
  already goes when a key item is missing: the cell is simply absent, and the
  cursor steps back to the command it came from if it was standing there. Each
  mechanic still keeps its own limit underneath, so a spent mega is spent on its
  own account whatever else happens. Primal reversion and the eight
  condition-driven forms are untouched, because neither is something the player
  asks for: both stay unlimited, both still flip as often as the battle calls
  for, and neither spends the trainer's one transformation nor is spent by it.

## 0.13.0

### Changed

- **The battle menu cell now says when it is holding more than one
  transformation, instead of leaving the second one to be found by accident.**
  With a mega and a Dynamax both on offer the cell read MEGA and nothing else,
  and the only way to learn that LEFT and RIGHT reached DYNAMAX was to press a
  direction there was no reason to press. A small hollow arrow now sits at the
  right-hand edge of the cell's row whenever more than one transformation is
  available, in the last column inside the command box -- the same one both
  battle layouts already use for their own "there is more" arrow, and the
  hollow shape rather than the solid one because the solid arrow is the cursor
  everywhere else in this engine. It is read off the offer every frame, so it
  goes again the moment the offer drops back to one, which happens mid-battle
  when a key item leaves the bag or a transformation is spent. A cell holding a
  single transformation is unchanged in every respect: the same label in the
  same column, the same cursor, and LEFT and RIGHT still step off the cell
  rather than cycling. One glyph is all the affordance there was room for --
  DYNAMAX with its armed mark already fills the classic layout's row to the
  pixel.

## 0.12.0

### Changed

- **The trainer now needs an item of their own, so an existing save loses mega
  evolution until a Key Stone is bought.** This mod only ever modelled the item
  a Pokemon carries; the real games gate both mechanics a second time on
  something the trainer wears, and without that tier a stone was the whole
  requirement and Dynamax had no requirement at all -- which is why it was
  offered for every species from the first route. The Key Stone and the Dynamax
  Band are sold at the Celadon department store's stone counter for ¥200 each,
  ahead of the mega stones on the same shelf, and each opens only its own gate:
  a Key Stone does nothing for a Dynamax and the Band does nothing for a mega.
  A missing key item is silent in battle, the way an ineligible species already
  was -- the menu cell is simply not there rather than there and refusing.
  Primal reversion is untouched and takes no trainer item, because the orbs are
  the whole of its requirement in the real games too, and neither are the eight
  condition-driven forms.

## 0.11.0

### Added

- **Dynamax and Gigantamax, the first transformation here that runs on a clock
  instead of lasting the battle.** DYNAMAX joins mega evolution on the battle
  menu cell, which now cycles between the two on LEFT and RIGHT, and lasts three
  turns unless the Pokemon switches out or faints first; each trainer gets one a
  battle, and the limit is its own, so arming a Dynamax never spends the mega nor
  the mega it. Thirty-one species have a Gigantamax shape to wear while it lasts
  and every other species Dynamaxes in its own, which is deliberate rather than
  partial -- Corviknight and the Low Key and Rapid Strike variants of Toxtricity
  and Urshifu are left plain for want of usable art, because a form wired without
  it falls back to the base species' picture and does so quietly. It does not
  multiply HP, and that was the hard call: maximum and current HP both live on
  the Pokemon itself, which is save data, and the engine keeps no battle-only
  copy to move instead, so a three-turn HP boost would be a timed write into the
  save whose one missed unwind could never be told apart from honest growth.
  Max Moves and G-Max Moves are deliberately not here -- they replace the
  Pokemon's moveset for the duration, which is a move-substitution system rather
  than a form change, and it shares its shape with Z-Moves.

## 0.10.0

### Added

- **A form change now prints a line, so it can never again be one missing file
  away from invisible.** Primal reversion has no animation by design and keeps
  its species name the way a mega does, so its only signal was the back sprite
  -- and while one art file was missing, a mechanic that was working looked
  exactly like one that was not. Groudon and Kyogre now announce with the real
  games' own line, and mega evolution announces with its own for the same
  reason from the other direction: the armed marker leaves the cell the instant
  the change lands, and a player with battle animations off was getting a mega
  that said nothing at all. The eight condition-driven forms stay silent
  deliberately -- Aegislash flips on every move it picks and Morpeko at the
  close of every round, and a line apiece would bury the messages a player is
  actually reading.

### Fixed

- **Enabling the mod during a battle left it inert for the rest of that
  fight.** The live battle was only ever cached from `battle.started`, an event
  that has already been and gone by the time a player turns the mod on from the
  manager mid-fight, so the arm state never learned which battle it was in: no
  MEGA cell, and no primal reversion for a mon already on the field. It now
  adopts a battle already under way from the frame it arrives, through the
  battle-update seam the menu cell was already patched into rather than any new
  hook. Adoption re-derives what a send-out would have applied -- primal
  reversion, and the HP-driven conditional forms -- and leaves the rest alone:
  it never spends the trainer's one mega, never re-transforms a mon already
  transformed, and does not invent triggers it was not there to see, so an
  Aegislash that attacked before the mod loaded arrives shielded.

## 0.9.0

### Added

- **A DEBUG TRACE option that records why the battle menu cell and primal
  reversion did or did not happen.** Both had been failing on a real install
  with nothing anywhere to say why, and the reason nothing said anything is
  that `mod.log` reaches a `print()` the packaged launcher discards -- so this
  writes to mod storage instead, at
  `mod_storage/<game>/<playthrough>/battle_forms/trace/`, where a player can
  open it. With the option on it records what the menu patch actually wrapped
  and whether it found itself already installed, what the transformation
  registry holds, the first time each wrapped draw and update function is
  called, the full decision behind the cell whenever that decision changes,
  which battle events are delivered at all, and every primal reversion attempt
  down to becomeForm's own refusal reason. It is off by default and does
  nothing at all while it is: no writes, no log lines, no work beyond one
  option read.

### Fixed

- **A handler that threw took every handler behind it down with it, silently.**
  The engine catches a throwing event listener and carries on, but it catches
  the whole listener -- and three handlers shared one `battle.started`
  subscription, so the first to fail cancelled the two after it and the
  engine's report went to the same discarded `print()`. Every call is guarded
  on its own now and says which one threw and with what error, through the log
  and the trace both. They were left sharing one listener rather than split
  into one each because `Events:on` re-sorts by priority on every subscribe and
  Lua's sort is not stable, so separate listeners would have traded a silent
  failure for an undefined order.

## 0.8.0

### Changed

- **The battle menu's fifth cell became a registry, with mega evolution as its
  first entry rather than its only one.** Nothing a player does changes: with
  one transformation registered the cell reads MEGA, arms the same way, spends
  the same one change per battle and moves the cursor exactly as it did in
  0.7.0. What changed is underneath. A manually activated transformation now
  supplies an id, a label, an availability predicate and an activation, and
  the once-per-battle flag is keyed by that id instead of being a single
  boolean, so arming one can never spend another's. Neither battle layout has
  a spare row -- the cell already lives in the blank spacer row vanilla never
  draws in -- so when more than one is on offer the cell cycles through them
  on LEFT and RIGHT, and UP or DOWN returns the cursor to the four real cells.
  This is groundwork for the mechanics that come next and there is nothing new
  to press today.

## 0.7.0

### Added

- **Forms that change themselves, driven by what happens in the battle rather
  than by an item or a menu.** Darmanitan and Minior flip when their HP
  crosses half and flip back when it crosses again, Wishiwashi schools while
  it is above a quarter and is level 20 or better, Aegislash draws its blade
  on an attacking move and shields again on a status one, Morpeko alternates
  at the end of every round, Mimikyu's disguise and Eiscue's face break on a
  damaging hit, and Greninja bonds when a hit it dealt knocks something out.
  Each is one row in a new `data/conditional.lua` naming a species, a form and
  the trigger it answers to, and the answer is re-derived from the mon every
  time rather than remembered, which is what lets the reversible ones flip
  back and forth for as long as the fight lasts. None of them touches mega
  evolution: no MEGA cell appears for these species, the trainer's one change
  per battle is not spent, and a Greninja that already megaed keeps its mega
  when its knockout trigger fires, because a conditional form refuses to dress
  a mon that is wearing another form. Castform and Cherrim were left out
  because both are weather-driven and Gen 1 has no weather at all -- the
  battle seeds a weather field and nothing ever assigns it -- and Cramorant
  because Gulp Missile is a payload fired back at an attacker, which is
  ability behaviour this mod does not implement. As with every other form
  here, these are the stats, the types and the picture and never the ability:
  the species alone is the trigger, since a Gen 1 Pokemon carries no ability
  field to gate on, so every Darmanitan and every Greninja qualifies rather
  than the rare ones that would in the real games.

## 0.6.0

### Added

- **Primal Reversion, as its own transformation and not a second kind of
  mega.** A Groudon carrying the Red Orb or a Kyogre carrying the Blue Orb
  reverts the moment it is on the field -- on the first send-out and on every
  switch-in after it -- with no menu entry, nothing to arm and nothing to
  press, because there is no decision for the player to make. It has no
  once-per-battle limit either: Groudon and Kyogre both revert in the same
  fight, and neither spends the one mega evolution the trainer gets, which is
  still theirs afterwards for whatever they bring in next. The two orbs are
  bag items assigned the way a mega stone is -- used on the Pokemon they fit,
  kept rather than consumed -- and are sold at the Indigo Plateau lobby
  counter rather than on the mega stones' Celadon shelf. The form unwinds on
  faint and at the end of the battle exactly as a mega's does, through the
  same party sweep, so nothing is ever written into a save.

## 0.5.0

### Added

- **A MEGA EVOLUTIONS option, defaulting to the 48 mega evolutions the real
  games have.** The other 48 the species data carries -- second megas for
  Absol, Garchomp and Lucario, two for Raichu, three for Tatsugiri, and megas
  for species that never had one -- are no longer on by default; switching
  the option to ALL brings them back exactly as they were in 0.4.0. Under
  OFFICIAL the Celadon shelf sells only the 48 official stones and a
  switched-off pairing is not eligible, so no MEGA cell appears and nothing
  can be armed. Every stone stays a registered item under both settings,
  including the ones the option turns off: a stone already in a bag when the
  setting changes must still be an item the save can name, so what the option
  gates is what a stone does, never whether it exists. One official entry
  deviates: Mega Rayquaza has no stone in the real games -- it megas by
  knowing Dragon Ascent -- so the Rayquazite sold here is this mod's
  invention, because a stone is the only trigger implemented.

## 0.4.0

### Added

- **The mega roster grew from five species to every mega National Dex has
  art for: 96 forms across 87 species.** `data/megas.lua` and
  `data/stones.lua` were extended rather than redesigned -- the pair-keyed
  table, the permanent bag indices and the stone-based trigger all work
  exactly as they did for the original five, just for more of them. 48 are
  the mega evolutions from the mainline games, sold under their real item
  names (Absolite, Garchompite, Mewtwonite X and Y, and so on); the other 48
  are megas National Dex carries that never shipped in an official game,
  sold under a mechanical BASE+ITE name instead, with an X/Y/Z or similar
  suffix where a species carries more than one. One mega National Dex
  defines, Mega Meowstic (female), has no art in the installed sprite sets
  and was left out on purpose -- wiring it would have shown the ordinary
  Meowstic sprite with a mega's stats and called that correct. New bag
  indices run 104-193, leaving headroom to 255 for future additions; the
  original six stones keep 98-103 unchanged, as they must. All 96 stones are
  sold on the same Celadon department store stone shelf the original five
  were, at the same price.

## 0.3.0

### Fixed

- **A mega Charizard rendered with no picture at all, and every fix since
  0.2.2 was patching around the real cause instead of it.** `becomeForm`
  re-keyed `mon.species` to the alternate-form id (`CHARIZARD_MEGA_X`), but
  the sprite registry resolves form art from a `form` field on the Pokemon
  and indexes it under the BASE species (`CHARIZARD.forms.MEGA_X`), never
  under a re-keyed id -- there is no `CHARIZARD_MEGA_X` entry anywhere in
  the art index, so a re-keyed species could never match any art, mega or
  not. A form change now marks the Pokemon (`mon.form = "MEGA_X"`) and
  leaves `mon.species` alone, the way the engine's own Transform already
  overrides a battler's `curStats`/`curTypes` rather than rewriting the
  Pokemon underneath it. Leaving the species untouched also means the name
  the real games show ("CHARIZARD", not the National Dex source data's raw
  slug) was never wrong in the first place, so `src/naming.lua` -- the
  patch 0.2.3 added to paper over the re-key exposing that slug in battle
  text -- is gone along with the record it no longer needs to touch. And
  because there is no species to leave re-keyed, a Pokemon can no longer be
  left permanently transformed in the save if a battle is abandoned
  mid-fight. Switching a mega to the bench and back in now also reapplies
  its stat and type override explicitly (`battle.battler_switched`), since
  a freshly built battler knows nothing about a mon's `form` on its own --
  under the old model this fell out for free because the re-keyed species
  carried the mega's stats with it everywhere.

## 0.2.4

### Fixed

- **0.2.3's fix for the vanishing mega only worked in this development
  checkout.** It got the picture back by calling `BattleState:speciesSprite`
  with a third `transformed` argument that does not exist in the released
  engine -- it was added by editing `BattleState.lua` locally, and the
  player runs the engine the launcher ships, not this checkout. Against the
  real engine the extra argument is silently ignored, `speciesSprite` always
  forces the Transformed mon's gray palette, and a mega would have rendered
  gray, if it rendered at all, for every player who reported the original
  bug. The picture is now rebuilt through `BattleState.makeBattler`, the
  same constructor every ordinary send-out already uses -- it builds a
  battler's sprite through the species' own palette, not Transform's forced
  gray -- so a throwaway battler built for the mega form, keeping only its
  `sprite` field, is the real send-out picture. Nothing here needs anything
  from the engine beyond what `engine_internals` already exposes.

## 0.2.3

### Fixed

- **A Pokemon vanished from the battle screen the instant it mega evolved.**
  `becomeForm` set `battler.sprite = nil` to invalidate the cached picture,
  meaning "reload this next draw" -- but nothing ever reloaded it, and the
  draw path just skips a nil sprite outright, so the mon stayed invisible for
  the rest of the fight. It now rebuilds the picture from the new species the
  same way Transform already does, and reverting rebuilds it back. Reusing
  Transform's own reload forces the copied species' gray palette, which is
  correct for a Transformed mon but wrong for a mega -- a mega form keeps its
  own colors -- so that reload now takes an explicit switch and mega evolution
  asks for the form's real color.
- **The post-battle EXP text and the HUD name read the raw National Dex slug
  instead of a real name**, e.g. "charizard-mega-x gained 260 EXP. Points!"
  and CHARIZARD staying on the HUD after transforming (the opposite problem:
  the HUD field was never updated at all). The mega form records carry
  `name = "charizard-mega-x"`, the source data's own field, not a display
  string -- the post-battle text reads that field live off the species table,
  and the HUD name is cached at send-out and was never touched by a form
  change either way. Mega form records now get their base species' own name
  patched in at load, matching the real games (Mega Charizard X is still
  "CHARIZARD" in battle), and the battler's cached name is re-keyed alongside
  the species so the HUD updates immediately rather than waiting for the next
  send-out.

## 0.2.2

### Fixed

- **Arming a mega did nothing, ever, for any of the five Pokemon.** `data/megas.lua`
  held each form under its National Dex record's `name` field (`"charizard-mega-x"`)
  instead of the record's KEY (`CHARIZARD_MEGA_X`), which is what `data.pokemon` is
  actually indexed by. The menu cell still appeared, the toggle still armed, and the
  confirm sound still played, because none of that touches the species table -- only
  the turn-start form change did, and it looked up a key that was never there, found
  nil, and refused without a word. The mega table now names the six real record keys,
  the MEGA cell no longer offers a form the species table has no record for, and a
  refusal now logs the species and the form id it could not find, so this exact
  failure cannot ship silently again.

## 0.2.1

### Fixed

- **There is one way to arm a mega now, not one and a half.** START still
  toggled it as well as the menu cell, and START worked only on the first
  command menu of a battle -- from the second turn onward it did nothing at
  all, which reads as a broken key rather than as a hint to use the menu. The
  cause is the engine bug 0.2.0 already worked around: `drainHold` is never
  returned to nil once an HP bar finishes draining, so the safety gate that
  guards the START hook refuses for the rest of the battle. Both the START
  handler and the corner MEGA indicator are gone; the menu cell says the same
  thing where the player is already looking.

## 0.2.0

### Changed

- **MEGA moved off START and onto the battle menu itself, as a fifth entry
  beside FIGHT / PKMN / ITEM / RUN.** START looked like it worked in a fresh
  battle and then silently stopped after the first turn that drained any HP,
  because the engine's `stepHPDrain` sets a battler's `drainHold` while
  pacing the HP bar and counts it down to zero but never back to `nil`, and
  the safety check the engine runs before letting a mod claim START treats
  `drainHold ~= nil` as "battle busy" -- zero still counts. Since that check
  runs before every START press once a battle is past its first turn, no fix
  from inside this mod could reach it. The new entry sits in the command
  menu's own input path instead, past that gate entirely, and only appears
  when a mega is actually available, so a player with no stone sees the same
  four-item menu as always. This is also why the mod now declares the
  `engine_internals` permission: the menu's cursor movement and dispatch have
  no hook of their own, so reaching them means patching the battle screen
  directly.

## 0.1.1

### Fixed

- **The MEGA indicator no longer appears when START would do nothing.** It
  could be on screen mid-message -- for example while "Wild MANKEY appeared!"
  was still printing -- where pressing START had no effect, advertising a key
  that was not live. The cause was that the indicator's visibility check
  never looked at the battle's phase, only at eligibility and the once-per-
  battle limit, while the engine only wires START to the toggle when the
  battle is at the command menu with nothing queued. The indicator now
  requires that same condition, so it is on screen exactly when the key does
  something.

## 0.1.0

### Added

- **Mega evolution, built so that it is not a move.** A Pokemon carrying a
  stone that fits it can mega evolve once per battle: press START at the
  battle menu to arm it, pick a move as normal, and the change lands before
  turn order is decided, with the move following on the same turn. Nothing
  about it runs inside the engine's move path, so it cannot spend PP, cannot
  be Disabled, and cannot be copied by Metronome or Mirror Move -- not because
  each of those is checked for, but because the mechanic was never in that
  code path to begin with. Five forms are covered: Venusaur, Charizard X and
  Y, Blastoise, Alakazam and Gengar.
- A form change underneath it that is not specific to megas. Changing form is
  a species re-key: the battler's species id becomes the alternate form's, its
  stats are recomputed from that form's own record, and the base is remembered
  for the unwind. Primal Reversion, stance changes and Zen Mode are the same
  transaction with a different trigger, which is why the mod is not named
  after mega evolution.
- Mega stones as bag items, **sold on the Celadon department store's stone
  floor** alongside the evolution stones it already stocks, at 4000 each. The
  shelf is extended rather than replaced, so nothing that was on sale there
  before has gone.
- Using a stone on a Pokemon it fits assigns it to that Pokemon and is **not**
  used up, so the assignment can be moved or repeated. Gen 1 has no held-item
  slot at all, so the stone is recorded on the Pokemon itself; the save format
  stores whatever fields it finds, so this needed no change to how saves are
  written and no engine patch.
- The form behaves the way the real games' does at the edges. It survives
  switching out, so a mega that goes to the bench comes back still mega. It
  unwinds when the Pokemon faints, so a revived one is back to normal. It
  unwinds for the whole party when the battle ends, including for a mon that
  transformed and then sat out the rest of the fight -- reverting only what
  was on the field would have left it transformed permanently in the save.
  The once-per-battle limit belongs to the trainer rather than to a Pokemon,
  so using it on one team member spends it for the team.

### Known limits

- Abilities are untouched. Nothing here makes an ability do anything, and no
  ability animations ship yet; both wait on a battle mechanics layer.
- Red, Blue and Yellow only. Gold has a real held-item slot and will get the
  stone as an actual held item, which is a different trigger over the same
  form change.
- There is no Key Stone. Carrying the matching stone is the whole requirement,
  where the real games also gate on the trainer.
- A Pokemon exported to a Game Boy save and brought back loses its stone,
  because a cartridge save has nowhere to record one. It returns ineligible
  rather than broken.
