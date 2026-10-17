"""Rebuild the hand-packed character atlas: python assets/extract_character.py <sheet.png>."""

import argparse
from pathlib import Path

from PIL import Image


# Rectangles are exclusive-right/bottom source coordinates, not a sprite grid.
# Anchors follow the body's ground plane, never the changing cape/alpha bounds.
PLAYER = {
    "idle0": ((32, 12, 130, 171), (96, 168)),
    "idle1": ((134, 10, 228, 171), (195, 168)),
    "idle2": ((231, 10, 331, 171), (301, 168)),
    "idle3": ((338, 10, 435, 171), (406, 168)),
    "idle4": ((485, 12, 600, 171), (561, 168)),
    "run0": ((622, 13, 756, 172), (704, 168)),
    "run1": ((782, 13, 925, 172), (871, 168)),
    "run2": ((942, 13, 1081, 172), (1027, 168)),
    "run3": ((1086, 13, 1235, 172), (1171, 168)),
    "run4": ((1234, 10, 1367, 172), (1309, 168)),
    "run5": ((1376, 10, 1521, 172), (1459, 168)),
    "run6": ((14, 179, 151, 326), (93, 323)),
    "run7": ((187, 184, 332, 326), (269, 323)),
    "run8": ((358, 185, 498, 326), (433, 323)),
    "run9": ((512, 183, 673, 326), (600, 323)),
    "run10": ((699, 183, 863, 326), (795, 323)),
    "run11": ((878, 181, 1054, 326), (976, 323)),
    "run12": ((1080, 192, 1230, 326), (1173, 323)),
    "run13": ((1246, 193, 1380, 326), (1319, 323)),
    "run14": ((1384, 196, 1521, 326), (1465, 323)),
    "air0": ((18, 356, 145, 488), (94, 485)),
    "air1": ((168, 343, 298, 488), (248, 485)),
    "air2": ((326, 332, 444, 488), (398, 485)),
    "air3": ((450, 333, 561, 470), (518, 485)),
    "air4": ((563, 332, 676, 487), (630, 485)),
    "air5": ((703, 333, 807, 506), (754, 485)),
    "air6": ((832, 339, 959, 499), (904, 490)),
    "land0": ((974, 351, 1115, 482), (1057, 478)),
    "land1": ((1126, 356, 1234, 482), (1188, 478)),
    "land2": ((1235, 357, 1357, 482), (1306, 478)),
    "land3": ((1360, 381, 1505, 482), (1438, 478)),
    "shoot0": ((15, 493, 175, 622), (92, 620)),
    "shoot1": ((191, 493, 335, 623), (263, 620)),
    "shoot2": ((355, 492, 511, 623), (429, 620)),
    "shoot3": ((577, 493, 747, 623), (658, 620)),
    "shoot4": ((16, 622, 175, 743), (93, 739)),
    "shoot5": ((194, 621, 353, 743), (276, 739)),
    "shoot6": ((420, 617, 590, 743), (504, 739)),
    "gesture0": ((14, 745, 164, 872), (94, 869)),
    "gesture1": ((159, 745, 257, 872), (216, 869)),
    "gesture2": ((263, 744, 380, 872), (303, 869)),
    "dash0": ((335, 842, 510, 932), (446, 930)),
    "dash1": ((525, 841, 728, 932), (652, 930)),
    "dash2": ((741, 841, 949, 932), (867, 930)),
    "dash3": ((957, 842, 1137, 933), (1061, 930)),
    "dash4": ((1143, 841, 1317, 933), (1245, 930)),
    "dash5": ((1316, 845, 1509, 934), (1423, 930)),
    "damage0": ((14, 874, 149, 1015), (94, 1010)),
    "damage1": ((149, 909, 280, 1015), (219, 1010)),
    "damage2": ((278, 939, 400, 1015), (348, 1010)),
    "damage3": ((411, 931, 546, 1015), (452, 1010)),
    "damage4": ((555, 937, 723, 1015), (639, 1010)),
    "damage5": ((728, 931, 897, 1015), (812, 1010)),
    "damage6": ((913, 967, 1089, 1015), (1001, 1010)),
    "damage7": ((1097, 964, 1293, 1015), (1195, 1010)),
    "damage8": ((1301, 970, 1503, 1015), (1400, 1010)),
}

# Small bats are individual minion frames; their surrounding flocks remain in army.
BATS = {
    "bat0": (391, 749, 431, 782),
    "bat1": (438, 772, 490, 802),
    "bat2": (478, 746, 527, 777),
    "bat3": (510, 767, 557, 803),
    "bat4": (384, 795, 441, 832),
    "bat5": (486, 799, 536, 833),
    "bat6": (633, 715, 691, 760),
    "bat7": (699, 714, 751, 752),
}

# Neighboring poses/effects intrude into these otherwise useful source rectangles.
# These explicit source-space exclusions preserve the character, not a bbox recenter.
EXCLUDE = {
    "shoot1": [(191, 493, 198, 558)],
    "shoot2": [(355, 492, 375, 560), (500, 618, 511, 623)],
    "shoot3": [(703, 493, 747, 512)],
    "shoot6": [(420, 617, 483, 625)],
    "gesture0": [(158, 800, 164, 872)],
    "gesture1": [(159, 745, 169, 800)],
    "dash0": [(335, 842, 359, 871)],
    "bat2": [(516, 773, 527, 777)],
    "bat3": [(510, 767, 516, 774), (547, 796, 557, 803)],
    "bat6": [(633, 754, 641, 760), (687, 741, 691, 760)],
    "bat7": [(699, 743, 713, 752), (740, 745, 751, 752)],
    "army0": [(515, 767, 553, 797), (539, 798, 553, 836)],
    "army1": [(553, 767, 561, 798), (553, 799, 582, 831),
              (738, 739, 781, 777), (771, 781, 781, 810)],
    "army2": [(781, 739, 804, 777), (781, 781, 822, 810), (1028, 760, 1035, 789)],
    "army3": [(1035, 760, 1071, 789), (1283, 768, 1289, 789)],
    "army4": [(1289, 768, 1304, 789)],
}

# name: (FPS, loop, frame keys). Reusing real poses across related actions is intentional.
ANIMATIONS = {
    "idle": (6, True, [f"idle{i}" for i in range(5)]),
    "run": (14, True, [f"run{i}" for i in range(15)]),
    "jump": (14, False, ["air0", "air1", "air2", "air3", "air4"]),
    "double_jump": (10, False, ["air3", "air4", "air5", "air6"]),
    "fall": (8, False, ["air5", "air6"]),
    "land": (18, False, [f"land{i}" for i in range(4)]),
    "shoot": (28, False, [f"shoot{i}" for i in range(6)]),
    "summon": (10, False, [f"gesture{i}" for i in range(3)]),
    "recall": (10, False, ["gesture2", "gesture1", "gesture0"]),
    "ultimate": (6, False, ["shoot4", "shoot5", "shoot6"]),
    "dash": (40, False, [f"dash{i}" for i in range(6)]),
    "hurt": (18, False, ["damage0", "damage1", "damage2"]),
    "death": (10, False, [f"damage{i}" for i in range(2, 9)]),
    "projectile": (18, True, [f"projectile{i}" for i in range(7)]),
    "shadow_spawn": (12, False, ["bat0", "bat1", "bat6"]),
    "shadow_fly": (12, True, ["bat0", "bat1", "bat2", "bat3", "bat4", "bat5"]),
    "shadow_attack": (16, False, ["bat7", "bat6", "bat4"]),
    "shadow_recall": (16, True, ["bat5", "bat3", "bat2", "bat0"]),
    "army": (8, False, [f"army{i}" for i in range(5)]),
    "beam": (7, False, [f"beam{i}" for i in range(4)]),
}


def generate(source_path: Path) -> None:
    with Image.open(source_path) as source:
        assert source.mode == "RGBA" and source.size == (1536, 1024), "Expected the original RGBA 1536x1024 sheet"
        assert source.getchannel("A").getextrema()[0] == 0, "Sheet must contain transparent background"
        frames = {}

        def frame(name, rect, anchor, size, target):
            left, top, right, bottom = rect
            assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height, (name, rect)
            crop = source.crop(rect)
            for x0, y0, x1, y1 in EXCLUDE.get(name, []):
                assert left <= x0 < x1 <= right and top <= y0 < y1 <= bottom, (name, "exclusion outside crop")
                crop.paste((0, 0, 0, 0), (x0 - left, y0 - top, x1 - left, y1 - top))
            assert crop.getchannel("A").getbbox() is not None, (name, "empty crop")
            position = (target[0] - anchor[0] + left, target[1] - anchor[1] + top)
            assert position[0] >= 0 and position[1] >= 0, (name, "anchor clips crop", position)
            assert position[0] + crop.width <= size[0] and position[1] + crop.height <= size[1], (name, "frame clips crop")
            canvas = Image.new("RGBA", size)
            canvas.alpha_composite(crop, position)
            frames[name] = canvas

        for name, (rect, anchor) in PLAYER.items():
            frame(name, rect, anchor, (256, 192), (128, 168))
        for name, rect in BATS.items():
            frame(name, rect, ((rect[0] + rect[2]) // 2, (rect[1] + rect[3]) // 2), (96, 80), (48, 40))

        for i, rect in enumerate([
            (796, 502, 872, 580), (914, 501, 990, 580), (1035, 502, 1118, 578),
            (1163, 506, 1239, 577), (1269, 507, 1339, 572), (1354, 510, 1427, 577),
            (1440, 508, 1515, 574),
        ]):
            frame(f"projectile{i}", rect, ((rect[0] + rect[2]) // 2, 540), (96, 96), (48, 48))
        for i, rect in enumerate([
            (383, 745, 553, 836), (553, 712, 781, 837), (781, 710, 1035, 838),
            (1035, 711, 1289, 838), (1289, 718, 1523, 840),
        ]):
            frame(f"army{i}", rect, ((rect[0] + rect[2]) // 2, 776), (256, 144), (128, 72))

        # The continuous original beam is followed by its three hand-packed spark groups.
        # No player pixels enter the beam; terminal particles keep their original spacing.
        for i, (rect, x) in enumerate([
            ((590, 624, 1305, 704), 0), ((1305, 620, 1370, 704), 400),
            ((1370, 620, 1425, 704), 465), ((1425, 618, 1518, 704), 520),
        ]):
            frame(f"beam{i}", rect, (rect[0] - x, 661), (768, 112), (0, 56))

    # Shelf packing retains every original source pixel at a common 1:1 scale.
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
    atlas.save(output / "character_atlas.png", optimize=True)

    ids = {name: f"AtlasTexture_{i}" for i, name in enumerate(frames)}
    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "",
                '[ext_resource type="Texture2D" path="res://assets/character_atlas.png" id="1"]', ""]
    for name, rect in placements.items():
        resource += [f'[sub_resource type="AtlasTexture" id="{ids[name]}"]', 'atlas = ExtResource("1")',
                     f'region = Rect2({", ".join(map(str, rect))})', ""]
    resource += ["[resource]", "animations = [{"]
    for index, (name, (fps, loop, keys)) in enumerate(ANIMATIONS.items()):
        assert all(key in frames for key in keys), name
        assert len({frames[key].tobytes() for key in keys}) == len(keys), (name, "repeated fake frames")
        resource += ['"frames": [']
        resource += [f'{{"duration": 1.0, "texture": SubResource("{ids[key]}")}}{"," if i < len(keys) - 1 else ""}' for i, key in enumerate(keys)]
        resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(fps)}',
                     "}, {" if index < len(ANIMATIONS) - 1 else "}]"]
    (output / "character_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
    print(f"Wrote {len(frames)} unique frames; {len(ANIMATIONS)} animations; atlas {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    generate(parser.parse_args().source)
