# Guara Slayer

2D action platformer (Godot 4, Windows-first) for GuaraGameJam2026. Demo scope: tutorial/level + Boss #1, EMA the Bug Queen.

## Run and debug on Windows

1. Install Godot 4.x (standard build, not .NET) from https://godotengine.org/download/windows/ or `winget install GodotEngine.GodotEngine`. Unzip it anywhere; no installer is needed.
2. Clone the repo: `git clone https://github.com/Ragnorus/GuaraGameJam2026.git`.
3. Start Godot, click **Import**, select `project.godot` in the repo folder, then **Import & Edit**.
4. Press **F5** (Play) to open the level picker; choose either level with the mouse or keyboard. Press **F6** to run the currently open scene.
5. **Yeral — The Spoilerman** opens the existing stage. **The Infested Zone — Ema, the Bug Queen** opens the new bug-filled stage; reach its far end to trigger Ema's three-phase fight. Press **R** to restart the current level.

Debugging:
- Errors, warnings and `print()` output show in the **Output** and **Debugger** panels at the bottom of the editor. Script errors pause the game and open the failing line.
- Click the gutter left of a line number in the Script editor to set a breakpoint (red dot). When it hits, use the Debugger controls (**F10** step over, **F11** step into, **F12** continue) and inspect variables in the Stack Variables panel.
- While the game runs, the **Remote** tab in the Scene dock shows the live node tree. Select a node (for example the boss) to read or edit its properties in the Inspector.
- Use the **Debug** menu for **Visible Collision Shapes** to see hitboxes, and **Visible Navigation** if you add pathfinding.
- If scripts fail to parse, check that class names (`Player`, `BossYeral`, `BossEma`, `YeralHints`, ...) are unique. Use **Project > Reload Current Project** after adding `class_name` scripts.

## Test and preview locally

Replace `godot` below with the path to your Godot 4.5 executable if it is not on your `PATH` (for example `& "C:\Tools\Godot\Godot_v4.5.1-stable_win64.exe"`).

**Preview a level in the editor**
1. Open the project (`godot --editor --path .`) and let it finish importing. After changing anything in `assets/`, focus the editor window so it reimports.
2. Press **F5** to play from the level picker, or open `scenes/main.tscn` (Yeral) or `scenes/ema_level.tscn` (Ema) and press **F6** to run just that scene.
3. Reach the far end of the level (x ≈ 2100+) to trigger the boss. Enable **Debug > Visible Collision Shapes** to check hitboxes.

**Preview without the editor**
- Yeral level: `godot --path . res://scenes/main.tscn`
- Ema level: `godot --path . res://scenes/ema_level.tscn`

**Regenerate level art** (after editing `tools/gen_assets.js`)
1. Run `node tools/gen_assets.js` (no dependencies).
2. Refocus the Godot editor so it reimports the PNGs, then press **F6** to preview.

**Re-slice character and prop sprites** (Yeral, robot minions, lair props; sources in `art/sheets/`, ignored by Godot via `art/.gdignore`)
1. `node tools/slice_sheets.js` writes `assets/sprites/yeral*`, `robot*`; `node tools/slice_lair.js` writes `assets/sprites/lair`.
2. `node tools/contact_sheet.js <group> out.png` lays a group's frames out for a quick visual check.
3. Open the project once in Godot so it creates the `.import` files for the new PNGs, and commit them.

**Headless smoke test** (loads a scene, teleports the player to the boss, hits it until defeated, and fails on script errors)
- Yeral: `godot --headless --path . -s tools/smoke_test.gd -- res://scenes/main.tscn`
- Ema: `godot --headless --path . -s tools/smoke_test.gd -- res://scenes/ema_level.tscn`

Look for `SMOKE boss:` and `SMOKE done` in the output; any `SCRIPT ERROR` line or a non-zero exit code means something broke. If it fails with missing class names on a fresh clone, run `godot --headless --path . --import` once first.

**Preview the Web build** (what Railway serves)
1. Export: `godot --headless --export-release "Web" build/web/index.html` (needs the Web export templates).
2. Serve it: `python -m http.server 8080 --directory build/web`, then open http://localhost:8080 (browsers won't run it from `file://`).

**Controls**

| Action | Keys |
|---|---|
| Move | A/D or arrows |
| Jump | Space / W / Up |
| Dash | Shift |
| Controller Smash (shoot) | J / Left click |
| Shadow Spawn (summon minion) | K |
| Recall minions | L |
| GUARA ARMY (ultimate, needs full meter) | U |
| Restart | R |

## Deploy to Railway

Railway's default builder (Railpack) can't build Godot projects, so the repo ships a `Dockerfile` and `railway.json` that Railway uses instead:

1. The Dockerfile downloads headless Godot 4.5.1 plus its export templates and exports the **Web** preset from `export_presets.cfg` (single-threaded, Compatibility renderer, so no special headers are needed).
2. The static export is served by nginx on Railway's `$PORT` (`nginx.conf.template`).

To deploy: create a Railway project from this GitHub repo and deploy; it picks up `railway.json` automatically. Generate a public domain under Settings > Networking.

To export locally, use a standard (non-.NET) Godot 4.5 editor with the web export templates installed: `godot --headless --export-release "Web" build/web/index.html`, then serve `build/web` over HTTP (browsers won't run it from `file://`). The .NET editor build cannot export to Web.

The generated forest-green, toxic-lime, and gold pixel-art level assets in `assets/` are produced by `node tools/gen_assets.js` (no dependencies); edit that script and rerun it to tweak the art, then let Godot reimport. Yeral, the robot minions and the Yeral lair props use sprites sliced from the sheets in `art/sheets/`; Ema's level and other characters still use placeholder shapes.
