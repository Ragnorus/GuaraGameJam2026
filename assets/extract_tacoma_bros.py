"""Rebuild Tacoma Bros' combat/vehicle frames and Toyota projectile from supplied sheets."""

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
CANVAS = (256, 256)
FEET_Y = 240
TRUCK_CANVAS = (640, 320)
# Wheel anchors share y=240; the extra lower canvas preserves the complete donut ring.
TRUCK_POSES = {
    "idle": (491, 537, 790, 665, 642, 658),
    "drive_0": (0, 357, 393, 493, 220, 488),
    "drive_1": (393, 350, 765, 493, 596, 488),
    "drive_2": (765, 350, 1084, 493, 924, 488),
    "drive_3": (1084, 350, 1400, 493, 1239, 488),
    "drive_4": (1400, 350, 1774, 493, 1598, 488),
    "charge": (0, 712, 478, 879, 319, 862),
    "drift_0": (1321, 537, 1594, 666, 1480, 657),
    "drift_1": (1594, 532, 1774, 666, 1692, 655),
    "donut": (470, 714, 904, 887, 710, 834),
}
# Explicit overlap exclusions retain supplied pixels without neighboring vehicle parts.
TRUCK_KEEP = {
    "donut": [(492, 714), (904, 714), (904, 887), (470, 887), (470, 821), (483, 807), (483, 775), (474, 758)],
}
TRUCK_ANIMATIONS = {
    "idle": (["idle"], 5.0, True),
    "drive": (["drive_0", "drive_1", "drive_2", "drive_3", "drive_4"], 12.0, True),
    "charge": (["charge"], 8.0, True),
    "drift": (["drift_0", "drift_1"], 8.0, True),
    # shortcut: supplied views lack a full rotation; add views only when more source art exists.
    "spin": (["donut", "drift_0", "drift_1", "drift_0", "drive_2", "donut"], 9.0, True),
}
TOYOTA_PROJECTILE_SOURCE = ROOT / "art/sheets/tacoma_projectile_sheet.png"
TOYOTA_PROJECTILE_CROP = (46, 754, 344, 875)
ANIMATIONS = {
    "ludo": {
        "idle": (["idle_0", "idle_1"], 7.0, True),
        "run": (["run_0", "run_1", "run_2"], 12.0, True),
        "attack": (["attack_0", "attack_1"], 10.0, False),
    },
    "capi": {
        "idle": (["idle_0"], 7.0, True),
        "run": (["run_0", "run_1"], 10.0, True),
        "attack": (["attack_0", "attack_1"], 10.0, False),
    },
}

# Crops are (left, top, right, bottom, foot_x, foot_y) in the supplied 1774x887 sheet.
POSES = {
    "ludo": {
        "idle_0": (652, 48, 715, 166, 683, 164),
        "idle_1": (719, 48, 789, 166, 755, 165),
        "run_0": (793, 48, 894, 166, 844, 164),
        "run_1": (892, 50, 994, 166, 943, 164),
        "run_2": (1001, 44, 1090, 166, 1046, 164),
        "attack_0": (1478, 53, 1568, 169, 1524, 168),
        "attack_1": (1581, 52, 1745, 169, 1624, 168),
    },
    "capi": {
        "idle_0": (653, 213, 755, 338, 704, 337),
        "run_0": (830, 220, 939, 338, 884, 337),
        "run_1": (937, 219, 1047, 338, 990, 337),
        "attack_0": (1494, 223, 1602, 338, 1548, 337),
        "attack_1": (1582, 223, 1744, 339, 1628, 338),
    },
}


def _isolate_pose(crop: Image.Image, seed: tuple[int, int]) -> None:
    alpha = crop.getchannel("A")
    pixels = alpha.tobytes()
    width, height = crop.size
    seed_x, seed_y = seed
    candidates = [
        y * width + x
        for y in range(max(0, seed_y - 4), min(height, seed_y + 5))
        for x in range(max(0, seed_x - 4), min(width, seed_x + 5))
    ]
    start = max(candidates, key=pixels.__getitem__)
    assert pixels[start] >= 128, "Pose seed must overlap the character"
    connected = bytearray(width * height)
    connected[start] = 255
    pending = [start]
    while pending:
        index = pending.pop()
        y, x = divmod(index, width)
        for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
            row = neighbor_y * width
            for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                neighbor = row + neighbor_x
                if pixels[neighbor] >= 128 and not connected[neighbor]:
                    connected[neighbor] = 255
                    pending.append(neighbor)

    # Keep the two-pixel antialias fringe without carrying neighboring poses.
    fringe = Image.frombytes("L", crop.size, bytes(connected)).filter(ImageFilter.MaxFilter(5))
    crop.putalpha(ImageChops.multiply(alpha, fringe))


def _write_resource(output: Path, actor: str, atlas_name: str, animations: dict, placements: dict) -> None:
    suffixes = list(dict.fromkeys(f"{actor}_{name}" for names, _, _ in animations.values() for name in names))
    assert all(suffix in placements for suffix in suffixes), "Animation references a missing frame"
    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(suffixes) + 2} format=3]', "",
                f'[ext_resource type="Texture2D" path="res://assets/{atlas_name}.png" id="1"]', ""]
    for suffix in suffixes:
        resource += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{suffix}"]', 'atlas = ExtResource("1")',
                     f'region = Rect2({", ".join(map(str, placements[suffix]))})', ""]
    resource += ["[resource]", "animations = [{"]
    for index, (name, (names, fps, loop)) in enumerate(animations.items()):
        resource += ['"frames": [']
        resource += [f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{actor}_{suffix}")}}{"," if i < len(names) - 1 else ""}'
                     for i, suffix in enumerate(names)]
        resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {fps}',
                     "}, {" if index < len(animations) - 1 else "}]"]
    (output / f"tacoma_{actor}_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")


def generate(source_path: Path) -> None:
    frames = {}
    truck_frames = {}
    with Image.open(source_path) as source:
        assert source.mode == "RGBA" and source.size == (1774, 887), "Expected the original RGBA 1774x887 sheet"
        assert source.getchannel("A").getextrema()[0] == 0, "Sheet must preserve transparent background"
        for bro, poses in POSES.items():
            for suffix, (left, top, right, bottom, foot_x, foot_y) in poses.items():
                assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height
                crop = source.crop((left, top, right, bottom))
                _isolate_pose(crop, (foot_x - left, foot_y - top - 36))
                position = (CANVAS[0] // 2 + left - foot_x, FEET_Y + top - foot_y)
                assert position[0] >= 0 and position[1] >= 0, (bro, suffix, "anchor clips crop")
                assert position[0] + crop.width <= CANVAS[0] and position[1] + crop.height <= CANVAS[1], (bro, suffix, "frame clips crop")
                frame = Image.new("RGBA", CANVAS)
                frame.alpha_composite(crop, position)
                frames[f"{bro}_{suffix}"] = frame
        for suffix, (left, top, right, bottom, wheel_x, wheel_y) in TRUCK_POSES.items():
            assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height
            assert left <= wheel_x < right and top <= wheel_y < bottom, (suffix, "wheel anchor outside crop")
            crop = source.crop((left, top, right, bottom))
            if suffix in TRUCK_KEEP:
                mask = Image.new("L", crop.size)
                ImageDraw.Draw(mask).polygon([(x - left, y - top) for x, y in TRUCK_KEEP[suffix]], fill=255)
                crop.putalpha(ImageChops.multiply(crop.getchannel("A"), mask))
            _isolate_pose(crop, (wheel_x - left, wheel_y - top - 40))
            assert crop.getchannel("A").getbbox() is not None, (suffix, "empty vehicle crop")
            position = (TRUCK_CANVAS[0] // 2 + left - wheel_x, FEET_Y + top - wheel_y)
            assert position[0] >= 0 and position[1] >= 0, (suffix, "anchor clips vehicle crop")
            assert position[0] + crop.width <= TRUCK_CANVAS[0] and position[1] + crop.height <= TRUCK_CANVAS[1], (suffix, "frame clips vehicle crop")
            frame = Image.new("RGBA", TRUCK_CANVAS)
            frame.paste(crop, position)
            assert frame.crop((*position, position[0] + crop.width, position[1] + crop.height)).tobytes() == crop.tobytes(), (suffix, "source pixels changed")
            truck_frames[f"truck_{suffix}"] = frame

    with Image.open(TOYOTA_PROJECTILE_SOURCE) as sheet:
        assert sheet.mode == "RGB" and sheet.size == (1820, 968), "Expected the supplied RGB Toyota projectile sheet"
        projectile = sheet.crop(TOYOTA_PROJECTILE_CROP).convert("RGBA")
    visible = ImageChops.lighter(ImageChops.lighter(projectile.getchannel("R"), projectile.getchannel("G")),
                                 projectile.getchannel("B"))
    projectile.putalpha(visible.point(lambda value: min(255, max(0, (value - 2) * 2))))
    assert projectile.getchannel("A").getbbox() is not None, "Toyota projectile crop must contain the logo effect"

    atlas = Image.new("RGBA", (2048, ((len(frames) + 7) // 8) * CANVAS[1]))
    placements = {}
    for index, (key, frame) in enumerate(frames.items()):
        x, y = index % 8 * CANVAS[0], index // 8 * CANVAS[1]
        atlas.alpha_composite(frame, (x, y))
        placements[key] = (x, y, *CANVAS)
    truck_atlas = Image.new("RGBA", (TRUCK_CANVAS[0] * 4, ((len(truck_frames) + 3) // 4) * TRUCK_CANVAS[1]))
    truck_placements = {}
    for index, (key, frame) in enumerate(truck_frames.items()):
        x, y = index % 4 * TRUCK_CANVAS[0], index // 4 * TRUCK_CANVAS[1]
        truck_atlas.paste(frame, (x, y))
        truck_placements[key] = (x, y, *TRUCK_CANVAS)

    output = Path(__file__).resolve().parent
    projectile.save(output / "tacoma_toyota_projectile.png", optimize=True)
    atlas.save(output / "tacoma_bros_atlas.png", optimize=True)
    truck_atlas.save(output / "tacoma_truck_atlas.png", optimize=True)
    for bro, animations in ANIMATIONS.items():
        _write_resource(output, bro, "tacoma_bros_atlas", animations, placements)
    _write_resource(output, "truck", "tacoma_truck_atlas", TRUCK_ANIMATIONS, truck_placements)

    print(f"Wrote {len(frames)} anchored combat frames, {len(truck_frames)} vehicle frames with idle/drive/charge/drift/spin, and the Toyota projectile; atlases {atlas.width}x{atlas.height} and {truck_atlas.width}x{truck_atlas.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=Path(__file__).resolve().parent.parent / "art/sheets/tacoma_bros_sheet.png")
    generate(parser.parse_args().source)
