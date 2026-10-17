---
name: guara-game-design
description: Game design reference for Guara Slayer (GuaraGameJam2026) - premise, the Controller King's abilities, the 10-boss Guara roster with mechanics and rewards, and demo scope. Use when implementing bosses, abilities, levels, or writing boss-related dialogue/hints.
---

# GUARA SLAYER - Game Design

Source: https://chatgpt.com/share/6ad2beec-9730-83e9-8ccb-20f188f0e182 (Godot 4 project, scripts in `scripts/`).

## Core concept
- 2D action platformer inspired by Mega Man (boss roster, boss rewards) with Solo Leveling style shadow minions.
- Premise: a nerdy gamer finds a magical controller that summons shadow minions. The Guaras (friend group) mutate into absurd bosses; he beats each one and gains a new power.
- Combat: responsive platforming, ranged attacks, dodging, boss-specific patterns.
- Signature mechanic: minions attack enemies, distract bosses and protect the player. Player controls the hero; minions are automated support.
- Art: pixel art, exaggerated anime boss animations (currently placeholder shapes). Tone: epic anime action + unhinged friend-group humor.

## Main character - The Controller King
Nerd with glasses, hoodie, magical controller. Abilities (implemented in `scripts/player.gd`):
- Controller Smash: basic ranged energy attack (J / left click).
- Shadow Spawn: summon minions (K).
- Recall: reposition minions around him (L).
- Ultimate GUARA ARMY: unleash all minions temporarily (U, needs full meter).

## Boss roster (name - theme; mechanics; reward)
Each boss needs a distinct look, gimmick and unlockable reward.
0. **YERAL - The Spoilerman** (demo boss, `scripts/boss_yeral.gd`) - Riddler. Announces attacks before doing them, plants fake telegraphs, puzzle-platforming traps; player can't tell if a warning is true. Reward: Future Spoiler - briefly reveals enemy attack patterns. Says hints about other bosses when hit.
1. **EMA - The Bug Queen** (`scripts/boss_ema.gd`) - giant insect with armor, razor legs, bug swarm. Wall crawling, acid projectiles, bug swarms, faster/aggressive final phase (3 phases). Reward: Swarm Command - summon extra minions briefly.
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
Focus on one polished level and one boss fight. (Implementation currently uses Yeral as the demo boss; Ema's script remains.)
1. Tutorial - The Gamer's Awakening: move, jump, attack, first minion.
2. Level 1 - The Infested Zone: bug mobs, platforms, hidden upgrades, minion targeting.
3. Mini-boss - The Brood Guardian: small insect introducing Ema's patterns.
4. Boss arena: three-phase fight with distinct patterns and a dramatic finish.
5. Ending - The Controller Awakens: signal reveals other Guaras, cut to black, "The Guara War Has Just Begun".

Scope table: player movement (run/jump/attack/damage), minion system (1-2 summon types), one stage, 2-3 enemy types, boss with 3 phases, one boss reward, intro/victory/demo ending.

## Related skill
`yeral-hints` - Yeral's on-hit hint dialogue; derive hints from the boss entries above.
