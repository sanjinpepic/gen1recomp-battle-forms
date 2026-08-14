# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

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
