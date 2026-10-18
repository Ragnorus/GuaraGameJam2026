---
name: game-testing
description: Gameplay testing for THE NIGHT UNC - headless Godot regression scripts, deterministic scenario setup, AI/physics scenario checklists, bounded test runners, log scanning, import churn and rendered previews for user review. Use when writing or running tests, verifying a gameplay change, reproducing a bug, or producing a preview before asking for approval.
---

# Game testing

Related: `godot-development` (implementation rules), `guara-dev-workflow` (deploy/approval flow).

## Harness pattern (`tests/*.gd`)
- Tests are `extends SceneTree` scripts. `_initialize()` defers `_run()`. Set `GameSettings.loaded = true` and turn music/SFX off. Then `change_scene_to_file("res://scenes/main.tscn")` and wait a few physics and process frames before reading `current_scene`.
- Step time with a `_frames(n)` helper that awaits `physics_frame`. Always run with `--fixed-fps 60` so frame counts are deterministic.
- Drive the player with real input (`Input.action_press/release`) for jumps, landings and platform riding. Teleport only to set up a scenario, never to skip the behaviour under test.
- Write small setup helpers that reset all state an actor depends on, then assert on the result. Example: `_hold()` sets `ai_enabled=false`, a large cooldown, `clear_attacks()`, and IDLE; `_stand(index, x)` puts an actor on a block. Re-enable the AI only for autonomous scenarios.
- Make the player `invuln` (or put them on a safe bank) when a scenario needs an attack to miss. Restore health and `clear_status()` between scenarios.
- Short-lived effects (splashes, popups, waves) may free themselves before the action ends. Sample them inside the stepping loop rather than after it.
- Record the sequence of states seen (`seen.append(state)`) and include it, plus positions, in assertion messages so failures are diagnosable from the log alone.
- End with one summary `print("<SUITE> OK")` / `PASS: ...` line and `quit()`.

## Scenario checklist for actors and bosses
- Every attack: windup tell, hit, miss, knockback direction, stun/guard, and damage scaled by difficulty.
- Edges and hazards: missing an attack near each block edge (left and right, every block), falling onto a lower block or a bank, touching the hazard, and recovery. Hand-calculate the expected landing spots from speed and gravity and test the tight ones.
- Phase changes (for example roid rage at 50%): triggered on the ground, deferred while airborne, protected during the transform, and with faster/stronger follow-up attacks.
- Autonomy: run the real AI for several hundred frames. Assert it keeps moving, attacks repeatedly, and never idles still for long.
- Death: during each state, including mid-air; cleanup of attacks and summons; no damage after death; room exit unlocking.
- Player death, restart, pause and difficulty.

## Running
- Import first after adding assets/scripts: `godot --headless --path . --editor --import --rendering-method gl_compatibility --quit`.
- Run each suite as `godot --headless --path . --fixed-fps 60 --script res://tests/<name>.gd` inside a bounded timeout (about 120s); a failed `assert` leaves Godot waiting in the debugger. Kill the process by PID.
- Scan stdout and stderr for `SCRIPT ERROR`, `SHADER ERROR` and `ERROR` even when the PASS line printed.
- After an actor change, run its own suite, then the regressions: `yeral_route`, `death_safety`, `level_progression`, `robot_actions`, `yeral_actions`, `platform_visibility`, `difficulty_score`, `pickups`, `story_intro`. `player_actions` has a known upstream vertical-dash failure; do not treat that one as new.
- Validation runs can rewrite `assets/*.import`. Restore only the churn that your run produced.

## Previews for approval
- Render with the real renderer (not headless): `godot --path . --rendering-method gl_compatibility --fixed-fps 60 -s <preview.gd>`. Headless runs don't render.
- Prefer stepping the live simulation and snapshotting at key moments, such as edge, falling, splash, jump apex and landing. Pause the actor's physics and sprite while grabbing `root.get_texture().get_image()` after `RenderingServer.frame_post_draw`. Use `state_time` fractions for parametric moves; velocity is not used during leaps.
- Composite the frames into one sheet and save it outside the repository (session scratch). Delete any temporary preview script copied into the project and its `.uid`.
- Show the preview and wait for the user's approval before committing or pushing.
