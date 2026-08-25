# Battle Forms

Mid-battle form changes for the gen1recomp engine: mega evolution, Dynamax and
Gigantamax, Terastallization, Z-Moves, primal reversion, condition-driven and
held-item forms, fusion, and Ultra Burst. Runs on Red/Blue/Yellow and on
Gold/Silver.

See `CHANGELOG.md` for the full history and `mod.card` for what changes against
a vanilla game.

## Enemy trainers use them too

Off the `TRAINER GIMMICKS` option, which is **on** by default.

**When.** The moment the player is carrying any one of the four key items --
Key Stone, Tera Orb, Dynamax Band, Z-Ring -- enemy trainers may use any of the
four. Holding one is read as having entered the era where trainers do this,
not as licensing one specific mechanic: the Key Stone is almost always the
first one found, and gating each gimmick on its own item would make the whole
early game mega evolutions and nothing else.

**Who.** Trainers the engine itself marks as a hard fight always qualify --
gym leaders, the Elite Four, the rivals, and a few tough ordinary classes.
Everyone else rolls one in four. The list is the engine's own, so it tracks
whatever it adds.

**Which Pokemon.** The strongest in the party, by level, and only once it is
actually on the field. One gimmick per trainer per battle.

**Which gimmick.** Whatever that Pokemon can genuinely do, picked by a weight
that leans away from mega evolution so the famous megas do not monopolise
every important fight. The choice is seeded from the trainer rather than
rolled, so Brock always reaches for the same thing and Blaine for his own: the
fight can be learned instead of re-rolled, and the variety lands across the
roster rather than inside one battle.

**Terastallization picks a type, it does not roll one.** The trainer's brand
first -- derived from their own party, so a Dragon gym reads as Dragon --
where the Pokemon knows a move of that type; otherwise the type of its
strongest attack; otherwise its own typing. No step can pick a type the
Pokemon has no use for, so an enemy Terastallization is never a downgrade.

**Items the enemy does not carry** are resolved rather than required. Engine
trainer parties hold no mod items, so a mega form and a Z-Crystal are chosen
for the ace on the same reading the Key Stone gets: a trainer who owns the
band equipped their Pokemon before the battle.

Every transformation announces itself. The player's own once-per-battle
allowance is kept separately and can never be spent by an opponent.
