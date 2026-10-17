"""Rebuild robot art: python assets/extract_robot.py <sheet.png> (requires Pillow)."""

import argparse
from pathlib import Path

from PIL import Image


# Irregular source spacing: each pose has its own crop and hip/ground anchor.
POSES = {
    "idle": (0, 216, [(16, 158, 96, 206), (160, 300, 236, 206),
                      (302, 435, 370, 207), (438, 565, 497, 207),
                      (566, 700, 635, 208), (700, 836, 773, 209),
                      (836, 973, 914, 209)]),
    "walk": (216, 420, [(20, 202, 120, 410), (203, 368, 286, 412),
                        (370, 549, 454, 412), (551, 704, 615, 415),
                        (705, 870, 778, 415), (872, 1030, 946, 412),
                        (1032, 1202, 1112, 410), (1204, 1365, 1292, 405),
                        (1367, 1510, 1434, 408)]),
    "hurt": (432, 638, [(1180, 1340, 1256, 633), (1342, 1484, 1407, 632),
                        (1486, 1620, 1549, 630)]),
    "death": (640, 802, [(62, 220, 140, 790), (230, 406, 326, 790),
                         (415, 597, 500, 790), (604, 792, 690, 790),
                         (794, 965, 867, 790), (966, 1152, 1061, 790),
                         (1153, 1304, 1225, 790), (1305, 1480, 1390, 790)]),
}
ANIMATIONS = {"idle": (6, True), "walk": (12, True),
              "hurt": (15, False), "death": (12, False)}


def generate(source_path: Path) -> None:
    frames = {}
    with Image.open(source_path) as source:
        assert source.mode == "RGBA" and source.size == (1774, 887), "Expected the original RGBA 1774x887 sheet"
        assert source.getchannel("A").getextrema()[0] == 0, "Sheet must have transparent background"
        for name, (top, bottom, poses) in POSES.items():
            for index, (left, right, hip, ground) in enumerate(poses):
                assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height
                crop = source.crop((left, top, right, bottom))
                assert crop.getchannel("A").getbbox() is not None, (name, index, "empty crop")
                position = (128 + left - hip, 240 + top - ground)
                assert position[0] >= 0 and position[1] >= 0, (name, index, "anchor clips crop")
                assert position[0] + crop.width <= 256 and position[1] + crop.height <= 256, (name, index, "frame clips crop")
                frame = Image.new("RGBA", (256, 256))
                frame.alpha_composite(crop, position)
                frames[f"{name}_{index}"] = frame

    atlas = Image.new("RGBA", (2048, ((len(frames) + 7) // 8) * 256))
    placements = {}
    for index, (key, frame) in enumerate(frames.items()):
        x, y = index % 8 * 256, index // 8 * 256
        atlas.alpha_composite(frame, (x, y))
        placements[key] = (x, y, 256, 256)
    output = Path(__file__).resolve().parent
    atlas.save(output / "robot_atlas.png", optimize=True)

    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "",
                '[ext_resource type="Texture2D" path="res://assets/robot_atlas.png" id="1"]', ""]
    for key, rect in placements.items():
        resource += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{key}"]', 'atlas = ExtResource("1")',
                     f'region = Rect2({", ".join(map(str, rect))})', ""]
    resource += ["[resource]", "animations = [{"]
    for index, (name, (fps, loop)) in enumerate(ANIMATIONS.items()):
        keys = [key for key in frames if key.startswith(name + "_")]
        resource += ['"frames": [']
        resource += [f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{key}")}}{"," if i < len(keys) - 1 else ""}' for i, key in enumerate(keys)]
        resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(fps)}',
                     "}, {" if index < len(ANIMATIONS) - 1 else "}]"]
    (output / "robot_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
    print(f"Wrote {len(frames)} anchored frames; {len(ANIMATIONS)} animations; atlas {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    generate(parser.parse_args().source)
