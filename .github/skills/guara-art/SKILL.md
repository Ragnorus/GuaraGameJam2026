---
name: guara-art
description: Art direction and sprite pipeline for THE NIGHT UNC - palette, Yeral the Spoilerman / robot minion / lair sprite sheets, slicing tools, naming and scale rules, and how sprites are wired into Godot. Use when adding or changing art, slicing new sheets, or integrating sprites into scripts.
---

# THE NIGHT UNC art

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
- `glizzy_sheet.png` - supplied 1536x1024 Yeral-to-hotdog transformation, bun combat poses, collapse, and condiment effects.
- `spoiler_gotham_sheet.png` - Gotham City "Spoiler Man theme" background spritesheet (opaque, dark green smoke backdrop, S emblems): skyline painting, clouds/moon, modular towers, rooftop details, bridges, walkways/platforms, street props, windows, ground/base layers, beam/atmosphere effects.

## Pipeline
1. `node tools/slice_sheets.js` - explicit frame boxes (`GROUPS`), keeps the main blob, trims, downscales, and puts every frame of a group on one uniform canvas aligned to the feet. Output `assets/sprites/<group>/<group>_<frame>.png` (`yeral`, `yeral_fx`, `robot`, `robot_fx`).
2. `node tools/slice_lair.js` - labels blobs and assigns them to named `REGIONS`; output `assets/sprites/lair/lair_<name>.png`, trimmed, scaled 0.6.
3. `node tools/slice_gotham.js` - copies the sheet's painted skyline UNALTERED (crop x263,y46 1021x322, right of the title text) to `assets/sprites/city_bg/city_bg_panorama.png` plus a plain `city_bg_sky.png` backstop. Do not recolour, downsample, fade or recompose it - the user wants the original art. Also cuts sprites (colour mask: red >= 26 or bright green; backdrop is low-red smoke; closed, solid-filled for buildings/props, 3x box-downsampled + quantised) into `assets/sprites/gotham/gotham_<tower|roof|bridge|platform|prop|window|ground>_<n>.png`. `node tools/preview_bg.js out.png [scrollX]` composites the background like main.gd.
4. `node tools/contact_sheet.js <group> out.png` - visual check. Write to a new filename each time (image viewers cache).
5. `node tools/gen_assets.js` - green floor/wall tiles, backgrounds and legacy props in `assets/` (Yeral level floor/walls). `node tools/gen_assets.js bichema` writes the same set recoloured to red/crimson (green-dominant -> red, blue -> crimson, gold/neutral kept) into `assets/bichema/`.
5b. `node tools/slice_evil_genius.js` - from `art/sheets/evil_genius_sheet.png` (near-black backdrop keyed by flood fill; the boss art is never recoloured): boss poses `assets/sprites/evil_genius/evil_genius_<idle|staff|run|jump|point|blast|shield|hurt>.png` (shared 662x439 canvas, feet at (331,435)), the girl-boss lawyer `evil_genius_fx_lawyer.png` (his weakness, shown on defeat), red hologram props `bichema/bichema_holo_*.png`, and the mob `truffle_android/truffle_android_<idle_0|idle_1|run_0|run_1|warn_0|shoot_0|hurt_0|dead_0..3>.png` (half-res 228x210 canvas, feet at (114,206); truffle-textured head, steel face, red glow).
6. `python assets/extract_glizzy.py` - rebuilds `assets/glizzy_atlas.png` and `assets/glizzy_frames.tres` from the copied Glizzy source; requires Pillow. Explicit crops, polygon exclusions, and per-pose feet anchors preserve source pixels without neighboring poses.
6b. `python tools/build_title_screen.py` - title screen: from the supplied `art/sheets/title_screen_original.png` (kept unaltered) writes `assets/ui/title_screen.png` with two user-requested edits: (1) subtitle "A GOTHAM ADVENTURE" -> "A GUARA ADVENTURE", re-laid with the art's own letter pixels (G, U, A, R), centred with the original spacing, old line repainted from the rows above/below; (2) the bat in the spotlight signal -> a black **Guara red hawk** head (the Guaras' symbol; reference icon `art/sheets/guara_hawk.png`). The hawk is a hand-traced polygon stencil (`HAWK_OUTLINE`, crest/hooked beak/neck feathers, cut-out eye) because colour-keying the small icon gave a blobby mask; the disc interior is repainted cream first so no bat edges remain; (3) the "(c) 1993 PIXELWORKS ENTERTAINMENT / LICENSED BY DC COMICS" credit lines are removed (`CREDIT_BOX`), refilled by reflecting the clean facade rows between the art's PRESS START and the credits, with the last rows blended into the street. Requires Pillow.
7. Open Godot once so it generates `.import` files; commit them.

When a sheet changes, adjust the boxes/regions in the slicer rather than editing PNGs by hand.

## Godot integration
- `scripts/sprite_lib.gd` (`SpriteLib`): `build(group, anims)` makes `SpriteFrames` from frame suffixes; `make_sprite(frames, feet_y)` places the sprite so the canvas bottom sits at the feet; `texture(group, suffix)`.
- Yeral (`boss_yeral.gd`): body 126x188 (sprite scale 0.5), sprite feet at y=+94, spawn y `FLOOR_Y - 96`. The first health depletion switches to `glizzy_frames.tres`: character canvases 512x384, feet (256,352), scale 0.8, non-centered offset (-256,-352), still at y=+94. Transform and death animations finish before combat resumes or the stage clears; attacks use the sheet's condiment and sauce art.
- Robot minions (`bug.gd`, `robot = true`, Yeral level only): body 44x72, `warn` then `shoot` fires the bolt, `dead` then `boom`, then freed. Dead robots count as cleared for gates.
- Evil Genius (`boss_evil_genius.gd`, `BossEvilGenius`): body 120x220, sprite scale 0.55, feet at y=+110, spawn y `FLOOR_Y - 112`. Shield pose = charge wind-up (never invulnerable), point = summon, blast = red fan, hurt = phase change; on death the lawyer sprite appears beside him for 0.6s.
- Truffle androids (`truffle_android.gd`, extends `Bug`, Bichema's World only): scale 0.42, body 48x80, shoot a red bolt after a `warn` pose, `dead` dissolve then freed.
- Background: `_build_city_background` in `main.gd` draws `city_bg_panorama.png` zoomed out at 1.25x with smooth (linear) filtering, bottom-aligned under the floor, its top edge feathered into the sky colour (a flipped copy beside it makes the loop seamless) over the `city_bg_sky.png` backstop (Yeral level only; Bichema's World uses `assets/bichema/bg_*.png` via `_asset()`).
- Lair props and platforms: `_build_yeral_props` and `_add_platform_sprite` in `main.gd`. Bichema's World uses `assets/bichema/*` plus holo panels.
- Pixel art uses `TEXTURE_FILTER_NEAREST` for tiles/props.
- Code-drawn effects (no PNG): `WingedMob` wings (`_draw`, palette per level) and Yeral's `TrapZone` "Spoiler Pillar" (gold "?" telegraph, lime column, question marks) - keep these in the level palette.
