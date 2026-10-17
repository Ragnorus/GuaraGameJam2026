"""Rebuild Yeral's atlas: python assets/extract_yeral.py <sheet.png> (requires Pillow)."""

import argparse
from pathlib import Path

from PIL import Image


# Hand-packed source rectangles and body/ground anchors, not a regular sprite grid.
POSES = {
    "idle": ((48, 42, 264, 448), (174, 442)),
    "smug": ((342, 42, 548, 448), (465, 442)),
    "run": ((588, 77, 967, 451), (803, 442)),
    "announce": ((1315, 90, 1747, 445), (1505, 439)),
    "volley": ((318, 526, 670, 870), (491, 864)),
    "taunt": ((822, 495, 1050, 869), (944, 863)),
    "trap": ((1051, 427, 1362, 875), (1214, 864)),
    "dash": ((1370, 540, 1735, 881), (1600, 864)),
}
EXCLUDE = {
    "volley": [(318, 526, 390, 700)],  # Neighbor's staff sweep.
    "trap": [(1250, 427, 1362, 445)],  # Neighbor's boot.
}
ANIMATIONS = {
    "idle": (2, True, ["idle", "smug"]),
    "announce": (1, False, ["announce"]),
    "charge": (8, False, ["run", "dash"]),
    "volley": (1, False, ["volley"]),
    "trap": (1, False, ["trap"]),
    "taunt": (1, False, ["taunt"]),
    "projectile": (1, False, ["projectile"]),
}


def generate(source_path: Path) -> None:
    with Image.open(source_path) as source:
        assert source.mode == "RGBA" and source.size == (1774, 887), "Expected the original RGBA 1774x887 sheet"
        assert source.getchannel("A").getextrema()[0] == 0, "Sheet must have transparent background"
        frames = {}

        def frame(name, rect, anchor, size, target):
            left, top, right, bottom = rect
            assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height
            crop = source.crop(rect)
            for x0, y0, x1, y1 in EXCLUDE.get(name, []):
                assert left <= x0 < x1 <= right and top <= y0 < y1 <= bottom
                crop.paste((0, 0, 0, 0), (x0 - left, y0 - top, x1 - left, y1 - top))
            position = (target[0] + left - anchor[0], target[1] + top - anchor[1])
            assert position[0] >= 0 and position[1] >= 0, (name, "anchor clips crop")
            assert position[0] + crop.width <= size[0] and position[1] + crop.height <= size[1], (name, "frame clips crop")
            assert crop.getchannel("A").getbbox() is not None, (name, "empty crop")
            canvas = Image.new("RGBA", size)
            canvas.alpha_composite(crop, position)
            frames[name] = canvas

        for name, (rect, anchor) in POSES.items():
            frame(name, rect, anchor, (512, 512), (256, 480))
        frame("projectile", (666, 600, 825, 711), (746, 655), (192, 128), (96, 64))

    placements = {}
    x = y = row_height = 0
    for name, image in frames.items():
        if x + image.width > 2048:
            y += row_height
            x = row_height = 0
        placements[name] = (x, y, image.width, image.height)
        x += image.width
        row_height = max(row_height, image.height)
    atlas = Image.new("RGBA", (2048, y + row_height))
    for name, image in frames.items():
        atlas.alpha_composite(image, placements[name][:2])
    output = Path(__file__).resolve().parent
    atlas.save(output / "yeral_atlas.png", optimize=True)

    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "",
                '[ext_resource type="Texture2D" path="res://assets/yeral_atlas.png" id="1"]', ""]
    for name, rect in placements.items():
        resource += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{name}"]', 'atlas = ExtResource("1")',
                     f'region = Rect2({", ".join(map(str, rect))})', ""]
    resource += ["[resource]", "animations = [{"]
    for index, (name, (fps, loop, keys)) in enumerate(ANIMATIONS.items()):
        assert all(key in frames for key in keys), name
        resource += ['"frames": [']
        resource += [f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{key}")}}{"," if i < len(keys) - 1 else ""}' for i, key in enumerate(keys)]
        resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(fps)}',
                     "}, {" if index < len(ANIMATIONS) - 1 else "}]"]
    (output / "yeral_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
    print(f"Wrote {len(frames)} unique frames; {len(ANIMATIONS)} animations; atlas {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    generate(parser.parse_args().source)
