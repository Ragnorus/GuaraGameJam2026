# THE NIGHT UNC – Copilot instructions

Godot 4.5 2D action platformer (GDScript). Scripts in `scripts/`, scenes in `scenes/`, Node helper tools in `tools/`.

## Skills (read before working in that area)
- `godot-development` - typed GDScript, physics, cinematics, audio/asset lifecycle and runtime regression testing.
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
- After a successful push to `main`, automatically open https://guaragamejam2026-production.up.railway.app/ in VS Code's integrated browser (Simple Browser), reusing an existing tab when possible. Also open it when asked to preview or play the deployed game. Use the browser tools when available; if unavailable, tell the user rather than claiming it opened. Opening the page does not confirm the new deployment is ready; remind the user Railway may take a few minutes and a reload may be needed.
