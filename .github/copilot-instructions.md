# Guara Slayer – Copilot instructions

Godot 4.5 2D action platformer (GDScript). Scripts in `scripts/`, scenes in `scenes/`, Node helper tools in `tools/`.

## Skills (read before working in that area)
- `guara-game-design` – premise, abilities, boss roster, demo scope.
- `guara-art` – palette, sprite sheets, slicing tools, naming/scale rules, background layout.
- `yeral-hints` – Yeral's on-hit hint dialogue (`scripts/yeral_hints.gd`).
- `guara-dev-workflow` – environment, deploy, git, audio, menus/difficulty/score, gotchas and history.

## Code style
Tabs, typed GDScript, `class_name` per script, bosses emit `defeated`/`health_changed`. Keep `*.import` and `*.uid` files tracked.

## Rules of thumb
- Never alter or wash out original user-provided art; scale/position only. Prefer smooth (linear) filtering over blocky upscales when asked for "less pixelated".
- Do not generate boss art when told another person owns it. Decline sexualized depictions of real people.
- Update README / skills when behavior changes. Commit trailer: `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Pushing to `main` redeploys the web build on Railway (a few minutes); hard-reload to test.
