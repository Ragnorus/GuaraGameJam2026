---
name: yeral-hints
description: Write or update the hint dialogue Yeral (the Spoilerman, demo boss) says when hit, based on the Guara game design and boss list. Use when adding bosses, editing hints, or tuning Yeral's dialogue.
---

# Yeral hint dialogue

Yeral is the Riddler-style demo boss (`scripts/boss_yeral.gd`). Each time he is hit he says a line from
`scripts/yeral_hints.gd` (`YeralHints.HINTS`), shown in the dialogue box at the bottom of the screen.

Source of truth: the game design shared at
https://chatgpt.com/share/6ad2beec-9730-83e9-8ccb-20f188f0e182
(the page is JS-rendered and could not be fetched automatically; paste its boss list here or open it manually).

## Rules
1. One dictionary key per boss (`"ema"`, ...), plus `"general"` for player-kit tips.
2. Each hint is one short sentence (< 100 chars), in Yeral's smug, spoiler-loving voice.
3. Hints must be true and actionable: reference an attack tell, a weakness, a phase change, or the right
   tool (Controller Smash, Shadow Spawn minions, Recall, GUARA ARMY).
4. Never reveal more than one mechanic per line.
5. Yeral also lies in combat; hints on hit are always truthful (that is the reward for hitting him).
6. For a new boss: read its design entry (attacks, phases, weakness, reward), write 4-5 hints, add the key.

## Current coverage
- Ema, the Bug Queen: derived from `scripts/boss_ema.gd` (acid fan, charge, bug swarm, 3 phases).
- Other bosses: add once their design entries are available.
