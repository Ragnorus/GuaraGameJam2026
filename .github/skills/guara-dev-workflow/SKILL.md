---
name: guara-dev-workflow
description: Development workflow and accumulated session knowledge for Guara Slayer - deploy pipeline, git practices, menus/difficulty/score systems, procedural audio and web-audio gotchas, levels/bosses, tooling, and open issues. Use when continuing development on a new machine or touching menus, audio, settings, deployment or levels.
---

# Guara Slayer – dev workflow & session knowledge

## Project & deploy
- Repo: Ragnorus/GuaraGameJam2026, branch `main`. Godot 4.5.
- Live: https://guaragamejam2026-production.up.railway.app/ . Railway builds the `Dockerfile` (Godot 4.5.1 headless web export, served by nginx via `nginx.conf.template`) on every push to `main`; takes a few minutes. Hard-reload (Ctrl+F5) to bypass cache.
- `export_presets.cfg`: web export is **single-threaded** (`variant/thread_support=false`) so it works without COOP/COEP headers.
- Godot/Python may not be installed locally; validate with Node tools (`tools/`), previews and the browser. If Godot is available: open the project, F5 (main scene is `scenes/main_menu.tscn`); `tools/smoke_test.gd` and `tests/difficulty_score.gd` are headless checks.
- Git: keep `*.import` and `*.uid` tracked (Godot generates them; needed for export). LF/CRLF warnings are harmless. Resolve merge conflicts directly when asked.

## Levels & bosses
- **Yeral level** (Gotham-style city, "Spoiler Man" sheet): background built in `main.gd::_build_city_background` (panorama scale `PX=1.25`, linear filter, bottom-aligned, sky-colored gradient fade over the skyline top). `tools/preview_bg.js` mirrors this layout for Node previews. Boss `boss_yeral.gd`, mobs `robot.gd`/`bug.gd`.
- **Bichema's World** (red tones, formerly Ema's green infected level): boss `boss_evil_genius.gd` (sprites named by Evil Genius convention), mobs `truffle_android.gd` (truffle/mushroom androids). Evil Genius = last boss, "alpha and omega".
- Player, mobs enlarged; bosses much larger for visibility. See `guara-art` for sprite pipeline.
- Gates between zones are invisible (group `gates`); floating platforms are one-way, on `PLATFORM_LAYER` (4), with extra random ones each run. `WingedMob` is the flying mob (both levels). Yeral's arena extends to `arena_right` = LEVEL_END + 1000. Mob contact damage is `Bug._touch_damage` (box overlap + margin).
- Tests: `tests/*.gd` (run with `--fixed-fps 60 --script`) and `tools/smoke_test.gd`. A failing `assert` makes Godot wait in the debugger, so wrap runs in a timeout. A portable Godot can be downloaded to a scratch folder for validation.

## Menus, difficulty, score
- Scripts: `game_settings.gd` (static settings, save/load to `user://settings.cfg`), `menu_kit.gd` (UI helpers), `main_menu.gd`, `level_select.gd`, `settings_menu.gd` (resolution, music/SFX on+volume, difficulty), `game_info.gd` (judge-facing explanation), `pause_menu.gd`.
- Difficulties (`GameSettings.DIFFICULTIES`, hp/damage/aggro multipliers): Baby Guara 0.6/0.5/0.8, Young Guara 1/1/1, Guara 1.5/1.5/1.2, OG Guara 2.5/2/1.5. Applied in `bug/robot/truffle_android/boss_*` and `player.gd`.
- Score: mobs 1–5 points (`clampi(1 + int(5*x/LEVEL_END), 1, 5)`), bosses 10. High score stored per difficulty. HUD + handling in `main.gd`.

## Audio (procedural, no asset files)
- `game_audio.gd`: generates 16-bit mono `AudioStreamWAV` at 22050 Hz in code (arpeggio over Am F C G, looped; square-wave SFX `click/kill/hurt/boss`). Buses "Music"/"SFX" created at runtime. Music started in `main_menu._ready` and by the level.
- **Web history/gotchas:** user reported no sound on the deployed build while local worked. Attempts: forcing `playback_type = STREAM` on players and `project.godot` `[audio] general/default_playback_type.web` (STREAM=0, SAMPLE=1; web default is SAMPLE), then rebuilt audio as 16-bit with continuous oscillator phase + attack envelope (old 8-bit/11 kHz version clicked at every note) and `driver/output_latency.web=100`. **Status: last fix (commit 8ccdb6e) unverified by ear.** If still broken, ask which symptom (silent / crackly / stuttering) and try: reverting to SAMPLE playback, starting audio on the first user gesture (browsers block autoplay), checking the browser console.
- Local runs fine; the web is single-threaded so stream mixing happens on the main thread.

## Browser verification
Deployed page is a canvas: use screenshots and console logs, not DOM reading. Console on load should show only engine/WebGL/"single-threaded" lines.

## Working practices that worked
- Edit with proper file edits; write previews to a scratch folder, not into the repo.
- Slice/preview art with the Node tools before wiring into Godot; never alter originals.
- Document behavior changes in `README.md` ("Menus, difficulty and score" section) and in skills.
