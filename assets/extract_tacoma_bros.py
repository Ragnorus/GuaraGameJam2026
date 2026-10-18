"""Rebuild Tacoma Bros' combat frames and Toyota projectile from supplied sheets."""

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
CANVAS = (256, 256)
FEET_Y = 240
TRUCK_CROP = (0, 360, 400, 490)
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


def generate(source_path: Path) -> None:
    frames = {}
    with Image.open(source_path) as source:
        assert source.mode == "RGBA" and source.size == (1774, 887), "Expected the original RGBA 1774x887 sheet"
        assert source.getchannel("A").getextrema()[0] == 0, "Sheet must preserve transparent background"
        assert 0 <= TRUCK_CROP[0] < TRUCK_CROP[2] <= source.width
        assert 0 <= TRUCK_CROP[1] < TRUCK_CROP[3] <= source.height
        truck = source.crop(TRUCK_CROP)
        assert truck.getchannel("A").getbbox() is not None, "Tacoma crop must contain the truck"
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

    output = Path(__file__).resolve().parent
    truck.save(output / "tacoma_truck.png", optimize=True)
    projectile.save(output / "tacoma_toyota_projectile.png", optimize=True)
    atlas.save(output / "tacoma_bros_atlas.png", optimize=True)
    for bro, animations in ANIMATIONS.items():
        resource = [f'[gd_resource type="SpriteFrames" load_steps={1 + sum(len(value[0]) for value in animations.values()) + 1} format=3]', "",
                    '[ext_resource type="Texture2D" path="res://assets/tacoma_bros_atlas.png" id="1"]', ""]
        for suffix in (f"{bro}_{name}" for names, _, _ in animations.values() for name in names):
            resource += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{suffix}"]', 'atlas = ExtResource("1")',
                         f'region = Rect2({", ".join(map(str, placements[suffix]))})', ""]
        resource += ["[resource]", "animations = [{"]
        for index, (name, (suffixes, fps, loop)) in enumerate(animations.items()):
            resource += ['"frames": [']
            resource += [f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{bro}_{suffix}")}}{"," if i < len(suffixes) - 1 else ""}'
                         for i, suffix in enumerate(suffixes)]
            resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {fps}',
                         "}, {" if index < len(animations) - 1 else "}]"]
        (output / f"tacoma_{bro}_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")

    print(f"Wrote {len(frames)} anchored combat frames, two 3-animation resources, the Tacoma drive sprite and Toyota projectile; atlas {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=Path(__file__).resolve().parent.parent / "art/sheets/tacoma_bros_sheet.png")
    generate(parser.parse_args().source)
