---
name: guara-art
description: Art direction and sprite pipeline for Guara Slayer - palette, Yeral the Spoilerman / robot minion / lair sprite sheets, slicing tools, naming and scale rules, and how sprites are wired into Godot. Use when adding or changing art, slicing new sheets, or integrating sprites into scripts.
---

# Guara Slayer art

Related: `guara-game-design` (roster, mechanics), `yeral-hints` (Yeral dialogue).

## Style
Painted pixel art with dark outlines, glowing accents, slightly gritty. Do not use coarse blocky placeholders.

Yeral the Spoilerman palette (level, UI, projectiles, traps):
- Forest green `#17251a` to `#29442a` (coat, walls, banners); near-black `#080d0a`
- Toxic lime `#70ed18` / `#9cff22` / `#68f51c` (glow, orbs, live traps, screens)
- Gold `#d99a28` (trim, warning telegraphs); brown `#513321` (boots, wood)

## Source sheets (`art/sheets/`, ignored by Godot via `art/.gdignore`)
- `yeral_sheet.png` - Yeral poses: idle_0/1, run, announce, point, swing, cast, taunt, summon, dash, plus the orb.
- `robot_sheet.png` - robot minion: idle, run, warn, shoot, hurt, dead frames, plus bolt and boom FX.
- `level_sheet.png` - lair props: banners, lamps, desk/crown screen/hologram, crates, platforms, spikes, terminal, vat, etc.
- `city_sheet.png` - Gotham-style night city: skyline panorama, clouds/moon, modular towers, bridges, rooftop platforms, street props, windows, ground strips, atmosphere/fog.

## Pipeline
1. `node tools/slice_sheets.js` - explicit frame boxes (`GROUPS`), keeps the main blob, trims, downscales, and puts every frame of a group on one uniform canvas aligned to the feet. Output `assets/sprites/<group>/<group>_<frame>.png` (`yeral`, `yeral_fx`, `robot`, `robot_fx`).
2. `node tools/slice_lair.js` - labels blobs and assigns them to named `REGIONS`; output `assets/sprites/lair/lair_<name>.png`, trimmed, scaled 0.6.
3. `node tools/slice_city.js` - `city_sheet.png` is opaque, so it builds parallax layers `assets/sprites/city_bg/city_bg_{far,mid,near}.png` (far: sky + clouds, 1280x720; mid: mirrored skyline, fades in at top; near: fog/silhouettes with brightness alpha) and flood-fills the dark backdrop to cut `assets/sprites/city/city_<tower|bridge|platform|prop|window|ground>_<n>.png` (numbered row-major).
4. `node tools/contact_sheet.js <group> out.png` - visual check. Write to a new filename each time (image viewers cache).
5. `node tools/gen_assets.js` - floor/wall tiles, backgrounds and legacy props in `assets/` (still used by Ema's level).
6. Open Godot once so it generates `.import` files; commit them.

When a sheet changes, adjust the boxes/regions in the slicer rather than editing PNGs by hand.

## Godot integration
- `scripts/sprite_lib.gd` (`SpriteLib`): `build(group, anims)` makes `SpriteFrames` from frame suffixes; `make_sprite(frames, feet_y)` places the sprite so the canvas bottom sits at the feet; `texture(group, suffix)`.
- Yeral (`boss_yeral.gd`): body 56x100, sprite feet at y=+50, spawn y `FLOOR_Y - 52`. Idle/run/announce/dash by state; `cast` on volley, `summon` on trap, `taunt` on a fake "nothing" attack; flips toward the player.
- Robot minions (`bug.gd`, `robot = true`, Yeral level only): body 44x72, `warn` then `shoot` fires the bolt, `dead` then `boom`, then freed. Dead robots count as cleared for gates.
- Background: `_build_city_background` in `main.gd` stacks the three `city_bg` layers in a `ParallaxBackground` (Yeral level only; Ema keeps `bg_*.png`).
- Lair props and platforms: `_build_yeral_props` and `_add_platform_sprite` in `main.gd`. Ema's level keeps the older generated art.
- Pixel art uses `TEXTURE_FILTER_NEAREST` for tiles/props.
