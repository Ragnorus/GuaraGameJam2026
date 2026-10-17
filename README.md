# THE NIGHT UNC

2D action platformer (Godot 4, Windows-first) for GuaraGameJam2026. Two playable stages: Yeral — The Spoilerman and his true second form, Glizzy Gobler, followed by Bichema's World — the Evil Genius, the alpha and the omega.

## Run and debug on Windows

1. Install Godot 4.x (standard build, not .NET) from https://godotengine.org/download/windows/ or `winget install GodotEngine.GodotEngine`. Unzip it anywhere; no installer is needed.
2. Clone the repo: `git clone https://github.com/Ragnorus/GuaraGameJam2026.git`.
3. Start Godot, click **Import**, select `project.godot` in the repo folder, then **Import & Edit**.
4. Press **F5** (Play) to open the main menu (Start Game, Level Select, Settings, Game Info). Press **F6** to run the currently open scene.
5. Reach the far end of a stage and defeat its boss. Depleting Yeral's first health bar transforms him into Glizzy Gobler with a fresh health pool; he cannot take damage during the transformation. Defeat the second form and wait for his collapse, then the three-second clear banner opens Ema's stage. Completing Ema returns to level selection because it is the last available stage. Each stage starts with a fresh player. Press **R** while playing or after death to restart the current level; restarting either Yeral form restores the first encounter.

Debugging:
- Errors, warnings and `print()` output show in the **Output** and **Debugger** panels at the bottom of the editor. Script errors pause the game and open the failing line.
- Click the gutter left of a line number in the Script editor to set a breakpoint (red dot). When it hits, use the Debugger controls (**F10** step over, **F11** step into, **F12** continue) and inspect variables in the Stack Variables panel.
- While the game runs, the **Remote** tab in the Scene dock shows the live node tree. Select a node (for example the boss) to read or edit its properties in the Inspector.
- Use the **Debug** menu for **Visible Collision Shapes** to see hitboxes, and **Visible Navigation** if you add pathfinding.
- If scripts fail to parse, check that class names (`Player`, `BossYeral`, `BossEvilGenius`, `YeralHints`, ...) are unique. Use **Project > Reload Current Project** after adding `class_name` scripts.
- If Godot reports that a member already exists in a parent class, remove the duplicate declaration from the subclass. `Robot` uses the `sprite` member inherited from `Bug`.

## Test and preview locally

Replace `godot` below with the path to your Godot 4.5 executable if it is not on your `PATH` (for example `& "C:\Tools\Godot\Godot_v4.5.1-stable_win64.exe"`).

**Preview a level in the editor**
1. Open the project (`godot --editor --path .`) and let it finish importing. After changing anything in `assets/`, focus the editor window so it reimports.
2. Press **F5** to play from the main menu, or open `scenes/main.tscn` (Yeral) or `scenes/bichema_level.tscn` (Bichema's World) and press **F6** to run just that scene (menu settings are only loaded when you start from the main menu).
3. Reach the far end of the level (x ≈ 2100+) to trigger the boss. Enable **Debug > Visible Collision Shapes** to check hitboxes.

**Preview without the editor**
- Yeral level: `godot --path . res://scenes/main.tscn`
- Bichema's World: `godot --path . res://scenes/bichema_level.tscn`

**Regenerate level art** (after editing `tools/gen_assets.js`)
1. Run `node tools/gen_assets.js` (no dependencies).
2. Refocus the Godot editor so it reimports the PNGs, then press **F6** to preview.

**Re-slice character and prop sprites** (Yeral, robot minions, lair props; sources in `art/sheets/`, ignored by Godot via `art/.gdignore`)
1. `node tools/slice_lair.js` writes `assets/sprites/lair`; `node tools/slice_gotham.js` cuts `art/sheets/spoiler_gotham_sheet.png` into `assets/sprites/gotham` and crops the sheet's painted skyline, unaltered, into `assets/sprites/city_bg` (preview with `node tools/preview_bg.js out.png [scrollX]`). `node tools/slice_sheets.js` writes `yeral*` and `robot*`.
2. `node tools/contact_sheet.js <group> out.png` lays a group's frames out for a quick visual check.
3. Open the project once in Godot so it creates the `.import` files for the new PNGs, and commit them.

**Headless scene smoke test** (loads the actual scene, keeps the player survivable, and damages the boss through both Yeral forms until the final animated defeat; missing bosses or a missing defeat fail within a bounded run)
- Yeral: `godot --headless --path . -s tools/smoke_test.gd -- res://scenes/main.tscn`
- Bichema's World: `godot --headless --path . -s tools/smoke_test.gd -- res://scenes/bichema_level.tscn`

Look for `SMOKE boss:` followed by `SMOKE PASS:`; success requires exactly one defeat signal and a live-player stage clear, plus Yeral's transformation when applicable. A non-zero exit code or any `SCRIPT ERROR` means something broke; `SMOKE FAILED:` explains explicit smoke failures. If it fails with missing class names on a fresh clone, run `godot --headless --path . --import` once first.

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

The main character uses the full supplied sprite sheet: animated idle/run, jump/double-jump, fall/landing, firing, dash, summon/recall, ultimate, hurt, and death. Energy shots and flying friendly shadow minions use the sheet's effect frames. The ultimate's beam/flock are visual effects; its damage still comes from the temporary minions. Yeral's first form uses the supplied neon-green rogue art for idle, announcements, charge/run-up, firing, trap casting, fake-out taunts, and energy orbs. Glizzy Gobler uses the supplied transparent hot-dog warlock sheet for transformation, movement, casts, condiment shots, floor sauce, hurt, and final collapse. Both forms retain identical honest/fake warning poses and health-based combat phases; the second form adds alternating ketchup/mustard volleys and jumpable sauce puddles (0.85-second safe warning, then 1.8 seconds active). Damage hints are truthful even when attack announcements lie. Yeral's hostile mobs use the supplied neon CRT robot art; Bichema's World uses the red Evil Genius art: the boss from `art/sheets/evil_genius_sheet.png` (unaltered, background-keyed) and truffle-android mobs derived from it.

Animation data lives in `assets/character_frames.tres`, backed by `assets/character_atlas.png`. To rebuild from the original 1536×1024 RGBA sheet, run `python assets/extract_character.py "path/to/Nerdy Bat Vigilante Sprite Sheet.png"` (requires Pillow for asset rebuilding only, not for the game).

Yeral's resources are `assets/yeral_frames.tres` and `assets/yeral_atlas.png`. Rebuild with `python assets/extract_yeral.py "path/to/Neon Green Rogue Sprite Sheet.png"` (Pillow required). The original PNG is 1774×887 with transparency, not a regular grid; the builder uses explicit crops, removes neighboring-pose intrusions, and aligns feet without rescaling the source pixels. The airborne and melee-sweep illustrations are unused because Yeral has no jump or melee-sweep attack.

Glizzy's resources are `assets/glizzy_frames.tres` and `assets/glizzy_atlas.png`. Rebuild with `python assets/extract_glizzy.py art/sheets/glizzy_sheet.png` (Pillow required; the source path is optional and defaults to that supplied sheet). The builder crops the irregular transparent source without rescaling its pixels, aligning character poses on 512×384 canvases with foot anchor (256, 352); projectiles use 128×96 canvases, and puddles use 320×128. Refocus the Godot editor or run `godot --headless --path . --import` after rebuilding.

Robot resources are `assets/robot_frames.tres` and `assets/robot_atlas.png`. Rebuild with `python assets/extract_robot.py "path/to/Neon CRT Robot Sprite Sheet.png"` (Pillow required). The original transparent PNG is 1774×887, not a regular grid. Its 27 idle/walk/hurt/death poses are cropped individually and aligned by hips and feet into shared atlas cells, preserving source pixels and transparency. In-game scaling uses nearest-neighbor filtering. `Robot` reuses `Bug` patrol/chase/contact combat only in Yeral's stage; firing poses/projectile effects are deliberately unused because these mobs do not shoot. Defeated robots immediately lose targeting, collision, and contact damage, then finish their collapse animation before despawning. Friendly summoned shadows are unchanged; Bichema's World uses `TruffleAndroid` (which shoots red bolts) instead.

Robot sprites place their shared foot anchor at the collision shape's bottom, keeping their feet on floors and platforms without changing hitboxes.

Run the action regression self-check with `Godot --headless --path . --fixed-fps 60 --script res://tests/player_actions.gd`. It exercises movement, facing, airborne shooting, complete firing/dash sequences, shadow attacks/recall, ultimate effects, invulnerability, and the final death pose.

Run the progression regression with `Godot --headless --path . --fixed-fps 60 --script res://tests/level_progression.gd`. It covers boss-entrance restart, both forms' phase boundaries, refill/transformation immunity without a stage clear, restarting during transformation and second-form combat, final animated collapse → Ema → level selection, and player death blocking victory (including during the collapse).

Run Yeral's art/combat regression with `Godot --headless --path . --fixed-fps 60 --script res://tests/yeral_actions.gd`. It retains first-form facing, honest/fake tells, committed charge and sustained dash pose, idle recovery, real orb damage, and damage-highlight checks. Second-form checks cover phase boundaries, indistinguishable fake warnings, charge contact damage, real ketchup/mustard collisions, safe sauce warnings, jumping clear of active floor damage, transformation immunity/attack cleanup, and exactly one defeat only after the final collapse.

Run the robot regression with `Godot --headless --path . --fixed-fps 60 --script res://tests/robot_actions.gd`. It covers movement-facing, visible foot contact while walking and idle, blocked idle, contact/projectile/shadow damage, hurt recovery, immediate corpse safety, death-animation completion, and Bichema's World mobs being truffle androids.

## Menus, difficulty and score

- Main menu (`scenes/main_menu.tscn`, the project's main scene) opens on the "The Night Unc" title art (`assets/ui/title_screen.png`, unaltered, scaled to cover the window); any key, button or click at **PRESS START** reveals a button strip along the bottom (returning from a sub-menu skips the title). Buttons: **Start Game** (first level, fresh score), **Level Select** (replay one level), **Settings**, **Game Info** (the rules screen for reviewers, generated from the live difficulty values), and Quit (hidden on web). **Esc** pauses a level (Resume / Restart Level / Main Menu).
- In-level announcements (stage title, boss intro, transformation, victory, death) pop up in a yellow comic-style caption box at the top right (`scripts/comic_box.gd`, `ComicBox`), under the score; boss dialogue and hints stay at the bottom.
- Settings (`scripts/settings_menu.gd`): difficulty, resolution (desktop only), fullscreen, music on/off + volume, sound on/off + volume. Saved to `user://settings.cfg` (browser storage on web) by `GameSettings`. Music and sound effects are generated in code by `GameAudio` (no audio files) and routed through `Music`/`SFX` buses.
- Difficulties (`GameSettings.DIFFICULTIES`): Baby Guara (health x0.6, damage x0.5, aggression x0.8), Young Guara (x1/x1/x1, the original balance), Guara (x1.5/x1.5/x1.2), OG Guara (x2.5/x2/x1.5). Health scales mobs and bosses (and Yeral's second form); damage scales everything that hurts the player (min 1); aggression scales mob speed/shot rate and boss attack rate/charge speed. Mobs/bosses read it when they spawn, so a change applies from the next level load.
- Score: a mob gives 1-5 points (more the deeper it is in the level; boss-summoned minions give 1), a boss gives 10. Score carries Yeral -> Bichema's World in one run; dying or restarting reverts to the score the level began with. The high score is kept per difficulty and recorded on death or boss defeat. The HUD shows score, high score and difficulty.
- Regression: `Godot --headless --path . --fixed-fps 60 --script res://tests/difficulty_score.gd`.

## Level layout and mobs

- Zones are separated by **invisible** barriers; walking into one before its mobs are dead shows "Defeat the mobs nearby to keep moving!". They block only the player (shots pass through).
- Floating platforms: a fixed set plus extra platforms placed at random each run (`_random_platforms` in `main.gd`), kept clear of barriers and within double-jump reach. Platforms are one-way (jump up through them) on their own physics layer (`PLATFORM_LAYER`), so only the player stands on them and projectiles pass through.
- Yeral's lair (boss arena) is 500 px wider than before (`arena_right`), and Yeral spawns further in.
- Mobs deal contact damage whenever their body touches the player (`Bug._touch_damage`).
- `WingedMob` (`scripts/winged_mob.gd`): flying mob with code-drawn bat-like wings in the level palette (green/lime/gold with a mini robot for Yeral, crimson with a truffle android for Bichema's World). Hovers, flashes a warning, swoops at the player, then returns. Ignores walls/barriers and never body-blocks.
- Jump height raised (`Player.JUMP_VELOCITY` -590).
- Yeral's vertical floor attack ("Spoiler Pillar", `TrapZone` in `boss_yeral.gd`) is drawn in his palette: a pulsing gold "?" rune telegraph, then a lime energy column with crackling arcs and rising question marks.

## Deploy to Railway

Railway's default builder (Railpack) can't build Godot projects, so the repo ships a `Dockerfile` and `railway.json` that Railway uses instead:

1. The Dockerfile downloads headless Godot 4.5.1 plus its export templates and exports the **Web** preset from `export_presets.cfg` (single-threaded, Compatibility renderer, so no special headers are needed).
2. The static export is served by nginx on Railway's `$PORT` (`nginx.conf.template`).

To deploy: create a Railway project from this GitHub repo and deploy; it picks up `railway.json` automatically. Generate a public domain under Settings > Networking.

To export locally, use a standard (non-.NET) Godot 4.5 editor with the web export templates installed: `godot --headless --export-release "Web" build/web/index.html`, then serve `build/web` over HTTP (browsers won't run it from `file://`). The .NET editor build cannot export to Web.

The generated forest-green, toxic-lime, and gold pixel-art level assets in `assets/` are produced by `node tools/gen_assets.js` (no dependencies); edit that script and rerun it to tweak the art, then let Godot reimport. Yeral, the robot minions and the Yeral lair props use sprites sliced from the sheets in `art/sheets/`; Bichema's World uses the red set from `node tools/gen_assets.js bichema` (`assets/bichema/`) plus sprites from `node tools/slice_evil_genius.js`; other characters still use placeholder shapes.
