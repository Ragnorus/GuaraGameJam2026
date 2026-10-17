# Guara Slayer

2D action platformer (Godot 4, Windows-first) for GuaraGameJam2026. Two playable stages: Yeral — The Spoilerman, followed by The Infested Zone — Ema, the Bug Queen.

## Run and debug on Windows

1. Install Godot 4.x (standard build, not .NET) from https://godotengine.org/download/windows/ or `winget install GodotEngine.GodotEngine`. Unzip it anywhere; no installer is needed.
2. Clone the repo: `git clone https://github.com/Ragnorus/GuaraGameJam2026.git`.
3. Start Godot, click **Import**, select `project.godot` in the repo folder, then **Import & Edit**.
4. Press **F5** (Play) to open the level picker; choose either level with the mouse or keyboard. Press **F6** to run the currently open scene.
5. Reach the far end of a stage and defeat its boss. After a three-second clear banner, Yeral's stage automatically opens Ema's stage; completing Ema returns to level selection because it is the last available stage. Each stage starts with a fresh player. Press **R** while playing or after death to restart the current level.

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
1. `node tools/slice_lair.js` writes `assets/sprites/lair`; `node tools/slice_city.js` builds the city background layers (`assets/sprites/city_bg`) and cut-out towers/bridges/platforms/props/windows/ground (`assets/sprites/city`) from `art/sheets/city_sheet.png`. `node tools/slice_sheets.js` writes `yeral*` and `robot*`.
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

The main character uses the full supplied sprite sheet: animated idle/run, jump/double-jump, fall/landing, firing, dash, summon/recall, ultimate, hurt, and death. Energy shots and shadow minions use the sheet's effect frames. The ultimate's beam/flock are visual effects; its damage still comes from the temporary minions. Yeral uses the supplied neon-green rogue art for idle, announcements, charge/run-up, firing, trap casting, fake-out taunts, and energy orbs. His poses share a ground anchor, face the player (or the committed charge direction), and brighten on damage. Honest and fake announcements share the same pose. Yeral's hostile mobs use the supplied neon CRT robot art; Ema and her bugs retain placeholder shapes. Controls, hitboxes, damage, and cooldowns are unchanged.

Animation data lives in `assets/character_frames.tres`, backed by `assets/character_atlas.png`. To rebuild from the original 1536×1024 RGBA sheet, run `python assets/extract_character.py "path/to/Nerdy Bat Vigilante Sprite Sheet.png"` (requires Pillow for asset rebuilding only, not for the game).

Yeral's resources are `assets/yeral_frames.tres` and `assets/yeral_atlas.png`. Rebuild with `python assets/extract_yeral.py "path/to/Neon Green Rogue Sprite Sheet.png"` (Pillow required). The original PNG is 1774×887 with transparency, not a regular grid; the builder uses explicit crops, removes neighboring-pose intrusions, and aligns feet without rescaling the source pixels. The airborne and melee-sweep illustrations are unused because Yeral has no jump or melee-sweep attack.

Robot resources are `assets/robot_frames.tres` and `assets/robot_atlas.png`. Rebuild with `python assets/extract_robot.py "path/to/Neon CRT Robot Sprite Sheet.png"` (Pillow required). The original transparent PNG is 1774×887, not a regular grid. Its 27 idle/walk/hurt/death poses are cropped individually and aligned by hips and feet into shared atlas cells, preserving source pixels and transparency. In-game scaling uses nearest-neighbor filtering. `Robot` reuses `Bug` patrol/chase/contact combat only in Yeral's stage; firing poses/projectile effects are deliberately unused because these mobs do not shoot. Defeated robots immediately lose targeting, collision, and contact damage, then finish their collapse animation before despawning. Friendly summoned shadows and Ema's mobs/swarm are unchanged.

Run the action regression self-check with `Godot --headless --path . --fixed-fps 60 --script res://tests/player_actions.gd`. It exercises movement, facing, airborne shooting, complete firing/dash sequences, shadow attacks/recall, ultimate effects, invulnerability, and the final death pose.

Run the progression regression with `Godot --headless --path . --fixed-fps 60 --script res://tests/level_progression.gd`. It covers restarting at the boss entrance, both bosses' phase boundaries, Yeral → Ema → level selection, death before victory, and restarting the current stage.

Run Yeral's art/combat regression with `Godot --headless --path . --fixed-fps 60 --script res://tests/yeral_actions.gd`. It covers facing, identical honest/fake warning poses, committed charge direction and sustained dash pose, recovery to idle, orb collision/damage, and damage-highlight expiry.

Run the robot regression with `Godot --headless --path . --fixed-fps 60 --script res://tests/robot_actions.gd`. It covers movement-facing, blocked idle, contact/projectile/shadow damage, hurt recovery, immediate corpse safety, death-animation completion, and Ema's unchanged mobs.

## Deploy to Railway

Railway's default builder (Railpack) can't build Godot projects, so the repo ships a `Dockerfile` and `railway.json` that Railway uses instead:

1. The Dockerfile downloads headless Godot 4.5.1 plus its export templates and exports the **Web** preset from `export_presets.cfg` (single-threaded, Compatibility renderer, so no special headers are needed).
2. The static export is served by nginx on Railway's `$PORT` (`nginx.conf.template`).

To deploy: create a Railway project from this GitHub repo and deploy; it picks up `railway.json` automatically. Generate a public domain under Settings > Networking.

To export locally, use a standard (non-.NET) Godot 4.5 editor with the web export templates installed: `godot --headless --export-release "Web" build/web/index.html`, then serve `build/web` over HTTP (browsers won't run it from `file://`). The .NET editor build cannot export to Web.

The generated forest-green, toxic-lime, and gold pixel-art level assets in `assets/` are produced by `node tools/gen_assets.js` (no dependencies); edit that script and rerun it to tweak the art, then let Godot reimport. Yeral, the robot minions and the Yeral lair props use sprites sliced from the sheets in `art/sheets/`; Ema's level and other characters still use placeholder shapes.
