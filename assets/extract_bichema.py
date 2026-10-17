"""Rebuild supplied Bichema character atlases: python assets/extract_bichema.py [--preview-dir DIR].

Requires Pillow. Source pixels are copied without resampling or recolouring.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


# Explicit source rectangles and measured foot anchors; these sheets are not grids.
BOSS_POSES = {
    "idle_a": ((5, 0, 131, 157), (74, 152)),
    "idle_b": ((132, 0, 242, 156), (199, 152)),
    "run_a": ((374, 0, 526, 158), (447, 152)),
    "run_b": ((671, 0, 790, 156), (741, 152)),
    "jump": ((1005, 185, 1182, 301), (1110, 300)),
    "point": ((333, 164, 537, 303), (411, 302)),
    "blast": ((531, 164, 798, 303), (625, 302)),
    "shield": ((0, 157, 222, 308), (85, 302)),
    "hurt": ((1225, 190, 1365, 305), (1295, 301)),
    "crawl": ((1353, 219, 1507, 308), (1425, 302)),
    "collapse": ((1140, 752, 1327, 820), (1234, 815)),
}
BOSS_KEEP = {
    "idle_a": [(9, 0), (120, 0), (120, 157), (9, 157)],
    "idle_b": [(132, 0), (242, 0), (242, 156), (132, 156)],
    "run_a": [(374, 0), (526, 0), (526, 100), (510, 114), (510, 158), (374, 158)],
    "run_b": [(671, 0), (787, 0), (787, 84), (780, 100), (787, 126), (787, 156), (671, 156)],
    "jump": [(1017, 185), (1182, 185), (1182, 220), (1173, 233), (1173, 275), (1182, 287), (1182, 301), (1060, 301), (1060, 292), (1028, 292), (1028, 279), (1005, 267), (1005, 234), (1024, 219)],
    "point": [(360, 164), (537, 164), (537, 280), (465, 280), (465, 303), (341, 303), (341, 275), (357, 259), (351, 245), (360, 223)],
    "blast": [(548, 164), (798, 164), (798, 280), (751, 288), (676, 288), (665, 303), (531, 303), (531, 217), (548, 212)],
    "shield": [(0, 157), (222, 157), (222, 244), (190, 259), (171, 256), (165, 302), (0, 302)],
    "hurt": [(1240, 190), (1335, 190), (1335, 245), (1357, 252), (1361, 277), (1344, 301), (1252, 301), (1238, 283), (1237, 248), (1240, 227)],
    "crawl": [(1353, 282), (1360, 256), (1375, 235), (1400, 226), (1420, 232), (1456, 227), (1472, 235), (1475, 259), (1469, 275), (1478, 286), (1483, 303), (1353, 303)],
    "collapse": [(1140, 799), (1172, 787), (1182, 770), (1208, 757), (1233, 752), (1258, 762), (1288, 774), (1301, 795), (1327, 799), (1327, 820), (1140, 820)],
}
BOSS_ANIMATIONS = {
    "idle": (3, True, ["idle_a", "idle_b"]),
    "run": (7, True, ["run_a", "run_b"]),
    "jump": (5, True, ["jump"]),
    "point": (5, False, ["point"]),
    "blast": (5, False, ["blast"]),
    "shield": (5, False, ["shield"]),
    "hurt": (5, False, ["hurt"]),
    "dead": (3, False, ["hurt", "crawl", "collapse", "collapse", "collapse"]),
}
# Costume rows share the normal-form canvas/feet; polygons exclude adjacent poses and FX.
COSTUME_POSES = {
    "transform_a": ((246, 303, 438, 453), (332, 450)),
    "transform_b": ((438, 303, 635, 453), (520, 450)),
    "transform_c": ((635, 288, 820, 457), (727, 450)),
    "transform_d": ((820, 299, 969, 457), (899, 450)),
    "transform_e": ((969, 300, 1140, 457), (1057, 450)),
    "idle_a": ((7, 456, 133, 594), (74, 589)),
    "idle_b": ((493, 450, 609, 599), (548, 592)),
    "run_a": ((140, 459, 254, 595), (197, 589)),
    "run_b": ((263, 456, 376, 599), (316, 591)),
    "jump": ((612, 459, 729, 586), (670, 578)),
    "point": ((740, 450, 852, 583), (797, 576)),
    "blast": ((1200, 452, 1350, 599), (1277, 592)),
    "shield": ((374, 441, 490, 601), (427, 591)),
    "hurt": ((1345, 563, 1483, 694), (1411, 685)),
    "fall": ((1145, 573, 1295, 694), (1224, 685)),
    "collapse": ((1480, 588, 1774, 694), (1625, 685)),
    "pink_bolt": ((1090, 827, 1278, 877), (1184, 852)),
}
COSTUME_KEEP = {
    "transform_a": [(267, 303), (410, 303), (419, 350), (419, 420), (409, 453), (270, 453), (267, 425)],
    "transform_b": [(442, 305), (615, 305), (615, 453), (442, 453)],
    "transform_c": [(635, 310), (684, 310), (684, 288), (744, 288), (744, 310), (796, 310), (805, 335), (805, 450), (635, 450)],
    "transform_d": [(820, 305), (858, 305), (858, 303), (900, 303), (900, 305), (969, 305), (969, 450), (820, 450)],
    "transform_e": [(969, 300), (1140, 300), (1140, 457), (969, 457)],
    "idle_a": [(7, 456), (133, 456), (133, 594), (7, 594)],
    "idle_b": [(558, 451), (586, 451), (599, 458), (609, 470), (609, 550), (593, 560), (572, 579), (572, 599), (493, 599), (493, 485), (532, 470), (543, 458)],
    "run_a": [(140, 459), (254, 459), (254, 595), (140, 595)],
    "run_b": [(263, 456), (365, 456), (365, 550), (376, 563), (376, 599), (263, 599)],
    "jump": [(612, 459), (729, 459), (729, 546), (710, 553), (688, 562), (680, 579), (650, 582), (632, 570), (612, 556)],
    "point": [(798, 450), (831, 450), (845, 461), (852, 474), (852, 546), (823, 552), (812, 576), (760, 583), (740, 551), (740, 495), (770, 478), (781, 460)],
    "blast": [(1254, 452), (1327, 452), (1327, 495), (1350, 495), (1350, 558), (1343, 564), (1343, 599), (1225, 599), (1225, 564), (1240, 544), (1230, 515), (1240, 498)],
    "shield": [(396, 448), (419, 448), (439, 452), (453, 465), (463, 486), (490, 504), (490, 584), (458, 584), (458, 595), (374, 595), (374, 472), (383, 457)],
    "hurt": [(1384, 563), (1453, 563), (1483, 589), (1483, 632), (1463, 647), (1463, 694), (1345, 694), (1345, 648), (1365, 610)],
    "fall": [(1145, 573), (1224, 573), (1224, 617), (1260, 636), (1295, 668), (1295, 694), (1166, 694), (1145, 657)],
    "collapse": [(1480, 588), (1774, 588), (1774, 694), (1480, 694)],
    "pink_bolt": [(1090, 827), (1278, 827), (1278, 877), (1090, 877)],
}
COSTUME_ANIMATIONS = {
    "transform": (4, False, ["transform_a", "transform_b", "transform_c", "transform_d", "transform_e"]),
    "idle": (3, True, ["idle_a", "idle_b"]),
    "run": (7, True, ["run_a", "run_b"]),
    "jump": (5, True, ["jump"]),
    "point": (5, False, ["point"]),
    "blast": (5, False, ["blast"]),
    "shield": (5, False, ["shield"]),
    "hurt": (5, False, ["hurt"]),
    "dead": (3, False, ["hurt", "fall", "collapse", "collapse", "collapse"]),
    "pink_bolt": (6, True, ["pink_bolt"]),
}

MINION_POSES = {
    "idle_a": ((15, 4, 170, 215), (96, 207)),
    "idle_b": ((170, 4, 302, 215), (237, 207)),
    "run_a": ((461, 5, 615, 215), (548, 207)),
    "run_b": ((631, 5, 790, 216), (709, 207)),
    "warn": ((304, 5, 447, 215), (379, 207)),
    "shoot": ((161, 230, 388, 436), (239, 426)),
    "hurt": ((774, 677, 933, 865), (849, 854)),
    "fall": ((927, 677, 1068, 865), (997, 854)),
    "dead_a": ((1050, 737, 1280, 860), (1163, 852)),
    "dead_b": ((1270, 685, 1528, 865), (1397, 852)),
    "fly_a": ((1100, 437, 1279, 639), (1191, 631)),
    "fly_b": ((1277, 438, 1462, 630), (1369, 622)),
    "fly_warn": ((1420, 493, 1534, 645), (1484, 637)),
}
MINION_KEEP = {
    "idle_a": [(15, 4), (170, 4), (170, 215), (15, 215)],
    "run_a": [(480, 5), (615, 5), (615, 215), (461, 215), (461, 162), (480, 133)],
    "warn": [(304, 5), (447, 5), (447, 215), (304, 215)],
    "shoot": [(171, 230), (310, 230), (310, 289), (388, 289), (388, 372), (307, 372), (307, 436), (161, 436), (161, 352), (177, 341), (177, 306), (161, 302), (161, 272)],
    "hurt": [(790, 677), (933, 677), (933, 735), (920, 741), (920, 749), (910, 760), (925, 779), (925, 865), (774, 865), (774, 754), (790, 738)],
    "fall": [(943, 677), (1068, 677), (1068, 766), (1048, 778), (1048, 795), (1037, 815), (1037, 865), (927, 865), (927, 791), (944, 767)],
    "dead_a": [(1050, 737), (1270, 737), (1270, 860), (1050, 860)],
    "dead_b": [(1293, 685), (1528, 685), (1528, 865), (1286, 865), (1286, 820), (1293, 796)],
    "fly_a": [(1100, 437), (1279, 437), (1279, 483), (1230, 485), (1220, 514), (1247, 535), (1251, 564), (1221, 594), (1204, 606), (1197, 630), (1168, 630), (1160, 603), (1134, 592), (1117, 566), (1129, 526), (1143, 484), (1100, 483)],
    "fly_b": [(1277, 438), (1462, 438), (1462, 500), (1421, 501), (1421, 630), (1277, 630)],
    "fly_warn": [(1440, 493), (1534, 493), (1534, 645), (1420, 645), (1420, 557), (1440, 541)],
    "money_bolt": [(13, 879), (86, 879), (86, 925), (62, 925), (62, 947), (13, 947)],
}
MINION_ANIMATIONS = {
    "idle": (3, True, ["idle_a", "idle_b"]),
    "run": (8, True, ["run_a", "run_b"]),
    "warn": (5, False, ["warn"]),
    "shoot": (7, False, ["shoot"]),
    "hurt": (6, False, ["hurt"]),
    "dead": (6, False, ["fall", "dead_a", "dead_b", "dead_b"]),
    "fly": (6, True, ["fly_a", "fly_b"]),
    "fly_warn": (5, True, ["fly_warn"]),
    "money_bolt": (6, True, ["money_bolt"]),
}


def generate(source_path, expected_size, stem, poses, keep, animations, size, target, preview_dir):
    with Image.open(source_path) as source:
        assert source.mode == "RGBA" and source.size == expected_size, (source_path, "Expected original RGBA sheet dimensions")
        assert source.getchannel("A").getextrema()[0] == 0, "Sheet must have transparent background"
        frames = {}
        definitions = {name: (rect, anchor, size, target) for name, (rect, anchor) in poses.items()}
        if stem == "money_minion":
            definitions["money_bolt"] = ((13, 879, 86, 947), (49, 913), (128, 96), (64, 48))
        elif stem == "ema_costume":
            rect, anchor = poses["pink_bolt"]
            definitions["pink_bolt"] = (rect, anchor, (192, 64), (96, 32))
            assert set(BOSS_ANIMATIONS) <= set(animations), "Both forms must expose the same combat animations"
            assert not animations["transform"][1] and not animations["dead"][1], "Transition and final collapse must finish"
            assert len(set(animations["transform"][2])) == 5, "Use all five supplied transformation poses"
        for name, (rect, anchor, canvas_size, foot) in definitions.items():
            left, top, right, bottom = rect
            assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height, name
            crop = source.crop(rect)
            if name in keep:
                mask = Image.new("L", crop.size)
                ImageDraw.Draw(mask).polygon([(x - left, y - top) for x, y in keep[name]], fill=255)
                crop.putalpha(Image.composite(crop.getchannel("A"), Image.new("L", crop.size), mask))
            bounds = crop.getchannel("A").getbbox()
            assert bounds is not None, (name, "empty crop")
            position = (foot[0] + left - anchor[0], foot[1] + top - anchor[1])
            assert position[0] >= 0 and position[1] >= 0, (name, "anchor clips crop")
            assert position[0] + crop.width <= canvas_size[0] and position[1] + crop.height <= canvas_size[1], (name, "frame clips crop")
            canvas = Image.new("RGBA", canvas_size)
            canvas.alpha_composite(crop, position)
            assert canvas.getchannel("A").getbbox() == tuple(v + position[i % 2] for i, v in enumerate(bounds)), (name, "clipped alpha")
            assert crop.convert("RGB").tobytes() == source.crop(rect).convert("RGB").tobytes(), (name, "source colours changed")
            frames[name] = canvas

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
    atlas.save(output / f"{stem}_atlas.png", optimize=True)
    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "",
                f'[ext_resource type="Texture2D" path="res://assets/{stem}_atlas.png" id="1"]', ""]
    for name, rect in placements.items():
        resource += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{name}"]', 'atlas = ExtResource("1")',
                     f'region = Rect2({", ".join(map(str, rect))})', ""]
    resource += ["[resource]", "animations = [{"]
    for index, (name, (fps, loop, keys)) in enumerate(animations.items()):
        assert keys and all(key in frames for key in keys), name
        resource += ['"frames": [']
        resource += [f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{key}")}}{"," if i < len(keys) - 1 else ""}' for i, key in enumerate(keys)]
        resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(fps)}',
                     "}, {" if index < len(animations) - 1 else "}]"]
    (output / f"{stem}_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
    if preview_dir:
        preview_dir.mkdir(parents=True, exist_ok=True)
        contact = Image.new("RGBA", (4 * size[0], ((len(frames) + 3) // 4) * (size[1] + 24)), "#26313c")
        draw = ImageDraw.Draw(contact)
        for index, (name, image) in enumerate(frames.items()):
            px, py = index % 4 * size[0], index // 4 * (size[1] + 24)
            contact.alpha_composite(image, (px, py + 24))
            draw.text((px + 8, py + 5), name, fill="white")
            draw.line((px, py + 24 + target[1], px + size[0], py + 24 + target[1]), fill="#69737d")
        contact.save(preview_dir / f"{stem}_contact.png")
    print(f"{stem}: {len(frames)} frames, {len(animations)} animations; {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-dir", type=Path)
    args = parser.parse_args()
    sheets = Path(__file__).resolve().parents[1] / "art/sheets"
    generate(sheets / "neon_lawyer_sheet.png", (1774, 887), "neon_lawyer", BOSS_POSES, BOSS_KEEP, BOSS_ANIMATIONS, (512, 256), (256, 240), args.preview_dir)
    generate(sheets / "neon_lawyer_sheet.png", (1774, 887), "ema_costume", COSTUME_POSES, COSTUME_KEEP, COSTUME_ANIMATIONS, (512, 256), (256, 240), args.preview_dir)
    generate(sheets / "money_minion_sheet.png", (1536, 1024), "money_minion", MINION_POSES, MINION_KEEP, MINION_ANIMATIONS, (384, 256), (192, 240), args.preview_dir)
