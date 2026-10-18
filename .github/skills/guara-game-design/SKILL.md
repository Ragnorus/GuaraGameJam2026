---
name: guara-game-design
description: Game design reference for THE NIGHT UNC (GuaraGameJam2026) - premise, the Controller King's abilities, the 10-boss Guara roster with mechanics and rewards, and demo scope. Use when implementing bosses, abilities, levels, or writing boss-related dialogue/hints.
---

# THE NIGHT UNC - Game Design

Source: https://chatgpt.com/share/6ad2beec-9730-83e9-8ccb-20f188f0e182 (Godot 4 project, scripts in `scripts/`).

## Core concept
- 2D action platformer inspired by Mega Man (boss roster, boss rewards) with Solo Leveling style shadow minions.
- Premise: a nerdy gamer finds a magical controller that summons shadow minions. The Guaras (friend group) mutate into absurd bosses; he beats each one and gains a new power.
- Combat: responsive platforming, ranged attacks, dodging, boss-specific patterns.
- Signature mechanic: minions attack enemies, distract bosses and protect the player. Player controls the hero; minions are automated support.
- Art: pixel art, exaggerated anime boss animations (currently placeholder shapes). Tone: epic anime action + unhinged friend-group humor.

## Main character - The Controller King
Nerd with glasses, hoodie, magical controller. Abilities (implemented in `scripts/player.gd`):
- Controller Smash: basic ranged energy attack (J / left click; controller X or RT (R2)).
- Shadow Spawn: summon minions (K).
- Recall: reposition minions around him (L).
- Ultimate GUARA ARMY: unleash all minions temporarily (U, needs full meter).
- Mecha chest power-up: 20 seconds of supplied mecha art with a bright yellow outline, 3-damage gold rifle shots on J/click/X/RT (0.2s cooldown), and temporary rocket dash on Shift/LB even before Dash unlock. Starting/late chests in both stages; another refreshes the timer. Same health, run speed, jumps, collision size and support abilities; acid is still lethal. Protected assembly/revert preserve gravity; pause/cinematics freeze lifetime, and death/restart discard the form.

## Boss roster (name - theme; mechanics; reward)
Each boss needs a distinct look, gimmick and unlockable reward.
0. **YERAL - The Spoilerman / Glizzy Gobler** (demo boss, `scripts/boss_yeral.gd`) - Riddler. Announces attacks before doing them, plants fake telegraphs, puzzle-platforming traps; player can't tell if a warning is true. Depleting his first health pool triggers a protected green transformation into Glizzy Gobler with a fresh health pool, ketchup/mustard spreads, faster bun charges, and warned, jumpable floor sauce. Only the transformed form's final collapse clears the stage. Reward: Future Spoiler - briefly reveals enemy attack patterns. Says truthful hints when hit.
1. **THE EVIL GENIUS / EMA - The Alpha and the Omega** (final boss, `scripts/boss_evil_genius.gd`, Bichema's World) - huge ego, researches any argument in politics, sports and tech. Starts in the black suit; depleting that pool triggers a protected transformation into the supplied pink costume with a fresh 72-base-HP pool. Both forms have three health-based phases, fan shots, charges and pink money-minion summons; the costume uses pink-green bolts and a modest speed/rate increase. Only its final collapse clears the stage. Weakness: girl boss lawyers, retained as the final-defeat cameo. City, pub and factory/arena art appears one environment at a time, with supplied capital platforms/details and comic presentation.
2. **PONCE - The Guara Hulk** - Marvel Rivals-style brawler. Ground slams, shockwaves, charges, destructible platforms. Reward: Rage Breaker - ground-pound.
3. **ZINNA - The Octane Menace** - rocket-powered battle car, Rocket League arena. Boost charges, aerial dives, bouncing projectiles, ricochets. Reward: Rocket Boost - dash through hazards/enemies.
4. **JAVI - The Ascetic** - Path of Exile monk. Rapid strikes, teleporting attacks, elemental waves, combo chains. Reward: Spirit Dash - short-range teleport.
5. **OMI - The Queen of Distraction** - theatrical glamorous original comedic villain. Stage lights, decoys, charm distractions, arena hazards. Reward: Hypno Clone - decoy that distracts enemies. (Keep tone non-explicit.)
6. **RODOLFO - The Charro Shogun** - samurai who fires terrible jokes (charro humor). Katana combos, joke projectiles, feints, attacks that interrupt rhythm. Reward: Punchline Parry - reflect certain projectiles.
7. **RAGN0RUS - The Hot Dog Herald** - cosmic hot dog warlock; bun armor, mustard cape, ketchup sigils. Mustard lasers, ketchup explosions, sausage minions, giant hot dog meteor. Reward: Relic of the Bun - hot dog minion that charges enemies. Joke: the hot dog is the real mastermind.
8. **VAKKA - The Hadouken Prodigy** - Ezreal-style adventurer with exactly one move: Hadouken. Teleports and spams fireballs that get faster and larger per phase. Reward: Mega Hadouken - charged massive projectile.
9. **LUDO - The Black Desert Legend** - absurdly stylish MMORPG warrior. Weapon combos, evasive rolls, chained abilities, screen-filling attacks. Reward: Awakening Weapon - temporarily upgrades Controller King attacks.

Full-game idea: every boss drops a collectible Guara Relic that changes minion behavior. Endgame reveal: Ragn0rus controls the Guaras with the forbidden hot dog.

## Demo scope
Current Yeral route follows the user's five-area sketch: Area 1 city -> Area 2 sewer descent -> Area 3 sergeant room (fixed blocks over lethal acid) -> Area 4 moving-block sewer ascent -> Area 5 city -> animated warehouse entrance and locked Yeral voice/comic introduction -> original two-form boss battle. City scenery appears only in Areas 1 and 5. See `scripts/yeral_route.gd`; do not restore random platforms in the sergeant room.

**Football Sergeant** (Area 3 mini-boss, `scripts/sergeant.gd`, user-supplied sheet): leaps between the three fixed blocks and lands on the far side of the player. He is always moving: he stalks the player on the same block (or paces between edges) and cools down faster at close range. A missed charge can carry him off a block. He falls with gravity onto a lower block or a bank, or into the acid. **The acid never hurts him**: he splashes and jumps back (jump/rage_jump pose) to the nearest block, then resumes attacking. Crossing 50% mid-air defers roid rage until he lands. Attacks: **football charge** (shoves the player off the block toward the acid), **punch** (bounces the player up and away), **scream** (a sound wave that only damages and stuns - no shove; stars circle the stunned player's head, with a short stun-guard so it can't chain). At 50% health he triggers a protected **roid rage** transformation (he shouts "ROID RAGE!!! NO PAIN, NO GAIN!" in the same comic speech bubble as Yeral's intro, tail over his head), then uses red rage art with ~25% faster attacks and +1 damage. Room exit waits for his defeat.
Focus on one polished level and one boss fight. (Implementation currently uses Yeral as the demo boss; the Evil Genius's script is the second level's boss.)

Level 1 improvements: per-area session checkpoints, held/tapped jump height and a 0.12s landing buffer (existing double jump retains generous off-ledge jumps), optional telegraphed turrets, a crouch-and-hop robot, an ascent flyer, recovery Medallas, two secret city coin ledges, and hit recoil/flash. Maximum player HP stays 10. Football Sergeant defeat unlocks **Shield Burst** permanently: Q / LT, 190px radius, 3 damage, clears nearby bolts/scream waves, 0.6s damage protection, 6s cooldown; lethal acid remains lethal. This is the implemented mini-boss reward, not a replacement for Yeral's existing dash unlock or the full-game planned Future Spoiler reward. `tests/level1_upgrades.gd` covers the additions.
The stage-two pub encounter keeps Capi and Ludo inside the Tacoma. Its harmless right-side entrance stops clear of the player, followed by a 1.2-second warning after controls return. Combat uses supplied driving/charge/drift/donut art: telegraph, jumping charge, then a harmless spinning recovery that leaves it open to attacks. It has one shared health bar and is the room's single enemy; defeating it opens the route. See `scripts/bichema_route.gd`; the full factory painting remains repeated as East Wing without stretching or cropping supplied art.
1. Tutorial - The Gamer's Awakening: move, jump, attack, first minion.
2. Level 1 - Bichema's World: money-minion mobs, platforms, hidden upgrades, minion targeting.
3. Mini-boss - The Brood Guardian: small insect introducing the final boss's patterns.
4. Boss arena: three-phase fight with distinct patterns and a dramatic finish.
5. Ending - The Controller Awakens: signal reveals other Guaras, cut to black, "The Guara War Has Just Begun".

Scope table: player movement (run/jump/attack/damage), minion system (1-2 summon types), one stage, 2-3 enemy types, boss with 3 phases, one boss reward, intro/victory/demo ending.

## Related skill
`yeral-hints` - Yeral's on-hit hint dialogue; derive hints from the boss entries above.
