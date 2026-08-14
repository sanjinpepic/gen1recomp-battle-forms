# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

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
