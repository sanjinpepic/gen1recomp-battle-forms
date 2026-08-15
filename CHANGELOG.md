# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

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
