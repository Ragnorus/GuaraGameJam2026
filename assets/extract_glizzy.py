"""Rebuild Glizzy's atlas: python assets/extract_glizzy.py [sheet.png] (requires Pillow)."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


# Source-space rectangles and feet anchors: this sheet is deliberately not a grid.
POSES = {
    "coat": ((0, 47, 171, 331), (98, 322)),
    "coat_smug": ((160, 51, 333, 332), (256, 322)),
    "swirl": ((322, 8, 536, 332), (441, 322)),
    "growing": ((512, 19, 712, 332), (607, 322)),
    "emerging": ((702, 9, 907, 332), (798, 322)),
    "settling": ((889, 34, 1088, 332), (984, 322)),
    "idle": ((1076, 64, 1235, 333), (1155, 322)),
    "idle_breathe": ((1226, 69, 1383, 333), (1306, 322)),
    "staff_idle": ((1381, 65, 1536, 334), (1458, 322)),
    "staff_ready": ((0, 348, 163, 594), (100, 584)),
    "walk_a": ((157, 357, 298, 594), (232, 584)),
    "walk_b": ((298, 355, 430, 594), (367, 584)),
    "point": ((429, 356, 612, 594), (510, 584)),
    "walk_c": ((590, 363, 757, 595), (675, 584)),
    "staff_stride": ((733, 366, 925, 595), (837, 584)),
    "staff_cast": ((884, 344, 1152, 594), (1043, 584)),
    "raised_staff": ((1316, 345, 1536, 596), (1443, 584)),
    "sauce_cast": ((0, 599, 333, 820), (102, 808)),
    "guns": ((312, 605, 543, 820), (401, 808)),
    "hands_up": ((697, 598, 909, 820), (810, 808)),
    "falling": ((910, 594, 1352, 822), (1130, 810)),
    "rear": ((1348, 605, 1536, 822), (1438, 810)),
    "collapsed_a": ((0, 811, 377, 934), (187, 925)),
    "collapsed_b": ((374, 825, 780, 935), (577, 925)),
}

# Keep the real contours/effects while separating tightly interleaved neighbors.
# Points are in source coordinates; no resampling or alpha thresholding occurs.
KEEP = {
    "coat": [(0, 47), (159, 47), (159, 155), (171, 162), (171, 199), (158, 218), (158, 331), (0, 331)],
    "coat_smug": [(160, 51), (333, 51), (333, 169), (319, 186), (319, 332), (160, 332), (160, 220), (181, 205), (181, 145), (160, 145)],
    "swirl": [(322, 8), (536, 8), (536, 113), (516, 138), (513, 227), (526, 264), (516, 332), (322, 332), (322, 214), (345, 194), (340, 153), (340, 120), (322, 100)],
    "growing": [(512, 19), (712, 19), (712, 146), (701, 163), (700, 332), (516, 332), (526, 264), (513, 227), (516, 138), (536, 113), (536, 31)],
    "emerging": [(702, 9), (907, 9), (907, 153), (894, 170), (894, 266), (903, 282), (891, 332), (702, 332), (702, 162), (712, 146), (712, 9)],
    "settling": [(889, 34), (1088, 34), (1088, 141), (1070, 159), (1070, 333), (891, 332), (903, 282), (894, 266), (894, 170), (907, 153), (907, 34)],
    "idle": [(1076, 64), (1235, 64), (1235, 188), (1227, 207), (1235, 226), (1235, 333), (1076, 333), (1076, 230), (1089, 206), (1076, 180)],
    "idle_breathe": [(1226, 69), (1383, 69), (1383, 178), (1374, 198), (1383, 218), (1383, 333), (1238, 333), (1238, 284), (1226, 260), (1226, 229), (1235, 207), (1235, 188), (1226, 178)],
    "staff_idle": [(1381, 65), (1536, 65), (1536, 334), (1381, 334), (1381, 218), (1374, 198), (1381, 178)],
    "staff_ready": [(0, 348), (163, 348), (163, 510), (157, 530), (157, 594), (0, 594)],
    "point": [(429, 356), (601, 356), (601, 433), (591, 462), (589, 594), (429, 594)],
    "walk_c": [(590, 363), (737, 363), (737, 444), (757, 457), (757, 595), (590, 595), (591, 462), (612, 433), (612, 363)],
    "staff_stride": [(733, 366), (889, 366), (889, 430), (925, 435), (925, 494), (906, 505), (900, 530), (900, 555), (925, 570), (925, 595), (780, 595), (780, 520), (759, 505), (759, 461), (733, 443)],
    "staff_cast": [(895, 344), (1143, 344), (1143, 432), (1152, 439), (1152, 449), (1145, 467), (1117, 478), (1117, 594), (954, 594), (954, 568), (926, 568), (916, 558), (923, 540), (895, 540), (895, 509), (922, 489), (922, 439), (895, 426)],
    "raised_staff": [(1316, 345), (1536, 345), (1536, 596), (1374, 596), (1374, 535), (1361, 504), (1350, 470), (1334, 462), (1330, 430), (1343, 405), (1328, 389), (1316, 376)],
    "sauce_cast": [(0, 599), (333, 599), (333, 694), (320, 735), (304, 781), (204, 794), (182, 820), (0, 820)],
    "guns": [(330, 605), (543, 605), (543, 672), (526, 682), (534, 692), (534, 738), (478, 740), (486, 820), (312, 820), (312, 774), (330, 748)],
    "hands_up": [(697, 598), (909, 598), (909, 820), (697, 820), (719, 739), (706, 709), (719, 689), (697, 647)],
    "falling": [(910, 594), (1340, 594), (1340, 780), (1352, 790), (1352, 822), (910, 822)],
    "rear": [(1348, 605), (1536, 605), (1536, 822), (1362, 822), (1362, 780), (1348, 760)],
    "collapsed_a": [(0, 811), (377, 811), (377, 934), (0, 934)],
    "collapsed_b": [(374, 825), (780, 825), (780, 935), (374, 935)],
}
FX = {
    "ketchup": ((374, 936, 449, 1012), (412, 974), (128, 96), (64, 48)),
    "mustard": ((451, 950, 502, 1009), (477, 979), (128, 96), (64, 48)),
    "puddle": ((1254, 909, 1536, 1018), (1395, 1008), (320, 128), (160, 112)),
}
KEEP["puddle"] = [(1254, 965), (1280, 951), (1306, 953), (1330, 943), (1350, 946), (1392, 914), (1440, 920), (1486, 909), (1536, 914), (1536, 1018), (1375, 1018), (1350, 990), (1300, 981), (1270, 983)]
ANIMATIONS = {
    "transform": (4, False, ["coat", "coat_smug", "swirl", "growing", "emerging", "settling", "idle", "idle_breathe"]),
    "idle": (3, True, ["idle", "idle_breathe", "staff_idle", "staff_ready"]),
    "announce": (2, False, ["staff_ready", "point"]),
    "charge": (9, True, ["walk_a", "walk_b", "point", "walk_c", "staff_stride"]),
    "volley": (5, False, ["staff_idle", "staff_cast", "sauce_cast"]),
    "spray": (5, False, ["point", "guns"]),
    "trap": (4, False, ["staff_ready", "raised_staff"]),
    "taunt": (3, False, ["hands_up", "rear", "hands_up"]),
    "hurt": (5, False, ["hands_up", "idle_breathe"]),
    "death": (2, False, ["hands_up", "falling", "collapsed_a", "collapsed_b"]),
    "ketchup": (6, True, ["ketchup"]),
    "mustard": (6, True, ["mustard"]),
    "puddle": (4, True, ["puddle"]),
}


def generate(source_path: Path) -> None:
    with Image.open(source_path) as source:
        assert source.mode == "RGBA" and source.size == (1536, 1024), "Expected original RGBA 1536x1024 sheet"
        assert source.getchannel("A").getextrema()[0] == 0, "Sheet must have transparent background"
        frames = {}

        def frame(name, rect, anchor, size, target):
            left, top, right, bottom = rect
            assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height, name
            crop = source.crop(rect)
            if name in KEEP:
                mask = Image.new("L", crop.size)
                ImageDraw.Draw(mask).polygon([(x - left, y - top) for x, y in KEEP[name]], fill=255)
                crop.putalpha(Image.composite(crop.getchannel("A"), Image.new("L", crop.size), mask))
            assert crop.getchannel("A").getbbox() is not None, (name, "empty crop")
            position = (target[0] + left - anchor[0], target[1] + top - anchor[1])
            assert position[0] >= 0 and position[1] >= 0, (name, "anchor clips crop")
            assert position[0] + crop.width <= size[0] and position[1] + crop.height <= size[1], (name, "frame clips crop")
            canvas = Image.new("RGBA", size)
            canvas.alpha_composite(crop, position)
            assert canvas.getchannel("A").getbbox() == tuple(v + position[i % 2] for i, v in enumerate(crop.getchannel("A").getbbox())), (name, "clipped alpha")
            frames[name] = canvas

        for name, (rect, anchor) in POSES.items():
            frame(name, rect, anchor, (512, 384), (256, 352))
        for name, (rect, anchor, size, target) in FX.items():
            frame(name, rect, anchor, size, target)

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
    atlas.save(output / "glizzy_atlas.png", optimize=True)
    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "",
                '[ext_resource type="Texture2D" path="res://assets/glizzy_atlas.png" id="1"]', ""]
    for name, rect in placements.items():
        resource += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{name}"]', 'atlas = ExtResource("1")',
                     f'region = Rect2({", ".join(map(str, rect))})', ""]
    resource += ["[resource]", "animations = [{"]
    for index, (name, (fps, loop, keys)) in enumerate(ANIMATIONS.items()):
        assert keys and all(key in frames for key in keys), name
        resource += ['"frames": [']
        resource += [f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{key}")}}{"," if i < len(keys) - 1 else ""}' for i, key in enumerate(keys)]
        resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(fps)}',
                     "}, {" if index < len(ANIMATIONS) - 1 else "}]"]
    (output / "glizzy_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
    print(f"Wrote {len(frames)} unique frames; {len(ANIMATIONS)} animations; atlas {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, nargs="?", default=Path(__file__).resolve().parents[1] / "art/sheets/glizzy_sheet.png")
    generate(parser.parse_args().source)
