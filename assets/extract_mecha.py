"""Extract unchanged mecha pixels: python assets/extract_mecha.py [--contact OUTSIDE_REPO.png]."""

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/sheets/mecha_sheet.png"
CELL = (256, 256)
ANCHOR = (128, 232)
# Explicit source boxes and ground anchors; the supplied artwork is not a grid.
POSES = {
    "approach": ((7, 78, 100, 183), (70, 178)),
    "idle_0": ((9, 236, 113, 357), (65, 352)),
    "idle_1": ((134, 236, 241, 357), (191, 352)),
    "idle_2": ((257, 236, 368, 357), (318, 352)),
    "idle_3": ((391, 236, 497, 357), (446, 352)),
    "walk": ((105, 421, 207, 520), (164, 514)),
    "run_0": ((209, 421, 314, 520), (272, 514)),
    "run_1": ((308, 421, 434, 520), (382, 514)),
    "jump": ((443, 418, 555, 510), (507, 514)),
    "land": ((551, 423, 670, 520), (615, 514)),
    "dash_0": ((668, 435, 810, 520), (764, 514)),
    "dash_1": ((806, 435, 957, 520), (903, 514)),
    "rocket_0": ((815, 571, 977, 662), (921, 655)),
    "rocket_1": ((956, 571, 1111, 662), (1058, 655)),
    "rocket_2": ((1094, 571, 1248, 662), (1193, 655)),
    "rocket_3": ((1231, 571, 1384, 662), (1331, 655)),
    "rocket_4": ((1370, 571, 1527, 662), (1474, 655)),
    "rifle_ready": ((974, 423, 1064, 520), (1020, 514)),
    "rifle_0": ((1061, 423, 1177, 520), (1103, 514)),
    "rifle_1": ((1161, 423, 1264, 520), (1204, 514)),
    "missile": ((351, 753, 457, 843), (411, 833)),
    "prime_0": ((785, 719, 901, 843), (842, 833)),
    "prime_1": ((911, 712, 1068, 843), (999, 833)),
    "prime_2": ((1073, 688, 1301, 843), (1197, 833)),
    "prime_3": ((1304, 706, 1497, 843), (1420, 833)),
    "hurt_0": ((218, 898, 320, 998), (270, 991)),
    "hurt_1": ((324, 898, 435, 998), (377, 991)),
    "collapse_0": ((444, 912, 550, 998), (502, 991)),
    "assemble_0": ((742, 48, 807, 179), (774, 174)),
    "assemble_1": ((823, 7, 976, 181), (902, 174)),
    "assemble_2": ((986, 7, 1148, 181), (1069, 174)),
    "assemble_3": ((1150, 10, 1317, 181), (1243, 174)),
    "assemble_4": ((1319, 61, 1426, 182), (1380, 174)),
    "revert_0": ((817, 239, 916, 362), (868, 353)),
    "revert_1": ((931, 232, 1049, 362), (993, 353)),
    "revert_2": ((1061, 232, 1176, 362), (1120, 353)),
}
# Exclude labels, neighboring limbs, and painted background patches explicitly.
# Coordinates are source-space contours, with room around exhaust and glow.
KEEP = {
    "run_1": [(308, 478), (330, 466), (347, 442), (366, 439), (380, 424), (400, 429), (410, 451), (431, 470), (425, 493), (432, 519), (308, 519)],
    "dash_0": [(668, 455), (709, 453), (735, 441), (768, 435), (789, 449), (808, 470), (808, 520), (668, 520)],
    "dash_1": [(806, 458), (846, 453), (880, 439), (915, 435), (938, 454), (956, 476), (956, 520), (806, 520)],
    "rocket_0": [(815, 611), (867, 593), (897, 574), (936, 571), (962, 598), (976, 618), (976, 662), (815, 662)],
    "rocket_1": [(956, 613), (1004, 594), (1038, 572), (1073, 571), (1097, 594), (1110, 615), (1110, 662), (956, 662)],
    "rocket_2": [(1094, 613), (1144, 592), (1176, 571), (1211, 571), (1235, 594), (1247, 615), (1247, 662), (1094, 662)],
    "rocket_3": [(1231, 607), (1284, 592), (1317, 571), (1354, 571), (1375, 594), (1383, 615), (1383, 662), (1231, 662)],
    "rocket_4": [(1370, 606), (1423, 591), (1456, 571), (1495, 571), (1518, 596), (1526, 616), (1526, 662), (1370, 662)],
    "rifle_0": [(1061, 488), (1073, 457), (1091, 442), (1097, 423), (1126, 430), (1138, 461), (1177, 462), (1177, 483), (1138, 490), (1141, 520), (1061, 520)],
    "rifle_1": [(1161, 492), (1174, 480), (1182, 467), (1178, 460), (1192, 441), (1198, 423), (1226, 430), (1237, 459), (1264, 461), (1264, 483), (1235, 492), (1245, 520), (1161, 520)],
    "missile": [(351, 809), (367, 786), (391, 771), (400, 753), (422, 758), (437, 779), (456, 796), (456, 843), (351, 843)],
    "prime_0": [(785, 820), (807, 809), (813, 761), (823, 728), (843, 719), (863, 727), (875, 770), (879, 810), (900, 820), (900, 843), (785, 843)],
    "prime_1": [(911, 814), (928, 790), (949, 775), (961, 734), (980, 713), (1009, 712), (1035, 740), (1040, 784), (1067, 811), (1067, 843), (911, 843)],
    "prime_2": [(1073, 744), (1094, 727), (1105, 752), (1135, 768), (1148, 718), (1180, 688), (1211, 688), (1247, 737), (1253, 767), (1285, 741), (1300, 754), (1300, 843), (1073, 843)],
    "prime_3": [(1304, 813), (1330, 781), (1347, 759), (1370, 732), (1407, 706), (1438, 706), (1471, 749), (1481, 788), (1496, 814), (1496, 843), (1304, 843)],
    "assemble_0": [(742, 63), (751, 49), (790, 48), (807, 69), (807, 113), (791, 132), (793, 155), (807, 164), (807, 179), (742, 179), (742, 162), (755, 153), (756, 131), (742, 112)],
    "assemble_1": [(823, 95), (845, 79), (861, 78), (867, 43), (882, 23), (892, 7), (920, 7), (939, 34), (947, 74), (974, 90), (976, 181), (823, 181)],
    "assemble_2": [(986, 97), (1007, 80), (1023, 76), (1031, 34), (1053, 7), (1086, 7), (1106, 30), (1114, 78), (1146, 92), (1148, 181), (986, 181)],
    "assemble_3": [(1150, 97), (1173, 74), (1195, 63), (1207, 30), (1235, 10), (1267, 21), (1288, 62), (1317, 94), (1317, 181), (1150, 181)],
    "assemble_4": [(1319, 101), (1340, 88), (1348, 61), (1384, 61), (1404, 82), (1426, 101), (1426, 182), (1319, 182)],
    "revert_0": [(817, 297), (835, 279), (845, 250), (859, 239), (885, 244), (900, 272), (916, 290), (916, 362), (817, 362)],
    "revert_1": [(931, 294), (953, 278), (962, 245), (980, 232), (1010, 238), (1029, 270), (1049, 290), (1049, 362), (931, 362)],
    "revert_2": [(1061, 293), (1080, 273), (1090, 241), (1107, 232), (1138, 238), (1157, 273), (1176, 296), (1176, 362), (1061, 362)],
}
EXCLUDE = {
    "rocket_1": [(956, 607, 975, 634), (1107, 607, 1111, 634), (1104, 634, 1111, 662)],
    "rocket_2": [(1094, 607, 1113, 635), (1241, 607, 1248, 634), (1239, 634, 1248, 662)],
    "rocket_3": [(1231, 607, 1250, 635), (1377, 607, 1384, 634), (1374, 634, 1384, 662)],
    "rocket_4": [(1370, 607, 1391, 635)],
}
# shortcut: missing standalone actions reuse supplied matching poses; replace only with new source art.
ANIMATIONS = {
    "idle": (4, True, ["idle_0", "idle_1", "idle_2", "idle_1"]),
    "run": (10, True, ["walk", "run_0", "run_1", "run_0"]),
    "jump": (7, False, ["jump"]),
    "double_jump": (10, False, ["jump", "dash_0", "dash_1", "jump"]),
    "fall": (7, True, ["jump"]),
    "land": (10, False, ["land", "idle_0"]),
    "dash": (40, True, ["rocket_0", "rocket_1", "rocket_2", "rocket_3", "rocket_4"]),
    "shoot": (20, False, ["rifle_ready", "rifle_0", "rifle_1"]),
    "summon": (8, False, ["idle_3", "missile", "prime_3"]),
    "recall": (8, False, ["prime_3", "missile", "idle_3"]),
    "ultimate": (6, False, ["prime_0", "prime_1", "prime_2", "prime_3"]),
    "hurt": (10, False, ["hurt_0", "hurt_1"]),
    "death": (6, False, ["hurt_0", "hurt_1", "collapse_0"]),
    "transform": (8, False, ["approach", "assemble_0", "assemble_1", "assemble_2", "assemble_3", "assemble_4", "idle_0"]),
    # Stop while still mecha; gameplay restores its original, consistently sized normal player.
    "revert": (6, False, ["revert_0", "revert_1", "revert_2"]),
}
CHEST_BOX = (185, 129, 248, 183)
CHEST_KEEP = [(188, 140), (195, 134), (237, 134), (243, 140), (243, 174), (237, 179), (194, 179), (188, 174)]
BOLT_BOX = (1270, 456, 1310, 488)


def isolate(source: Image.Image, name: str, box: tuple, polygon=None) -> Image.Image:
    left, top, right, bottom = box
    assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height, name
    crop = source.crop(box)
    allowed = Image.new("L", crop.size, 255 if polygon is None else 0)
    if polygon:
        ImageDraw.Draw(allowed).polygon([(x - left, y - top) for x, y in polygon], fill=255)
    for x0, y0, x1, y1 in EXCLUDE.get(name, []):
        ImageDraw.Draw(allowed).rectangle((x0 - left, y0 - top, x1 - left - 1, y1 - top - 1), fill=0)
    # The sheet has painted charcoal/brown (not transparent) behind purple armor/gold fire.
    # Key only the alpha; every retained RGB triple remains byte-for-byte original.
    pigment = bytearray()
    armor_pixels = bytearray()
    for (r, g, b, a), keep in zip(crop.getdata(), allowed.getdata()):
        armor = b >= 38 and b >= r + 8 and b >= g + 5
        gold = r >= 65 and r >= g * 1.35 and g >= b * 1.15
        pigment.append(255 if keep and a >= 40 and (armor or gold) else 0)
        armor_pixels.append(255 if armor and keep else 0)
    mask = Image.frombytes("L", crop.size, bytes(pigment))
    mask = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    # Fill enclosed dark armor lines, not the exterior painted backdrop.
    exterior = Image.new("L", (crop.width + 2, crop.height + 2))
    exterior.paste(mask, (1, 1))
    ImageDraw.floodfill(exterior, (0, 0), 128)
    filled = exterior.crop((1, 1, crop.width + 1, crop.height + 1)).point(lambda v: 0 if v == 128 else 255)
    pixels = filled.tobytes()
    connected = bytearray(len(pixels))
    visited = bytearray(len(pixels))
    for index, value in enumerate(pixels):
        if not value or visited[index]:
            continue
        pending = deque([index])
        visited[index] = 1
        component = []
        while pending:
            current = pending.popleft()
            component.append(current)
            y, x = divmod(current, crop.width)
            for ny in range(max(0, y - 1), min(crop.height, y + 2)):
                for nx in range(max(0, x - 1), min(crop.width, x + 2)):
                    neighbor = ny * crop.width + nx
                    if pixels[neighbor] and not visited[neighbor]:
                        visited[neighbor] = 1
                        pending.append(neighbor)
        if len(component) >= 12:
            for current in component:
                connected[current] = 255
    mask = Image.frombytes("L", crop.size, bytes(connected)).filter(ImageFilter.MaxFilter(3))
    mask = ImageChops.multiply(mask, allowed)
    alpha = ImageChops.multiply(crop.getchannel("A"), mask)
    if name == "chest":
        # Its explicit box silhouette includes black panels that color-keying would perforate.
        alpha = ImageChops.multiply(crop.getchannel("A"), allowed)
    if name == "bolt" or name.startswith(("assemble_", "prime_", "revert_")):
        # Fade diffuse brown flame tails at isolation boundaries, never recolor source pixels.
        alpha_values = bytearray(alpha.tobytes())
        protected_armor = Image.frombytes("L", crop.size, bytes(armor_pixels)).filter(ImageFilter.MaxFilter(5)).tobytes()
        for index, (r, g, b, _) in enumerate(crop.getdata()):
            if not protected_armor[index]:
                y, x = divmod(index, crop.width)
                edge = min(x, y, crop.width - 1 - x, crop.height - 1 - y)
                brightness = min(255, max(0, (r - 55) * 3))
                alpha_values[index] = min(alpha_values[index], brightness * min(8, edge) // 8)
        alpha = Image.frombytes("L", crop.size, bytes(alpha_values))
    crop.putalpha(alpha)
    assert crop.getchannel("A").getbbox(), (name, "empty isolated pose")
    assert crop.convert("RGB").tobytes() == source.crop(box).convert("RGB").tobytes(), (name, "RGB changed")
    # An opaque rectangular crop would retain at least one complete painted border.
    alpha = crop.getchannel("A")
    assert all(min(alpha.crop(edge).getdata()) == 0 for edge in [(0, 0, crop.width, 1), (0, crop.height - 1, crop.width, crop.height), (0, 0, 1, crop.height), (crop.width - 1, 0, crop.width, crop.height)]), (name, "painted box retained")
    return crop


def generate(contact: Path | None = None) -> None:
    source = Image.open(SOURCE)
    assert source.mode == "RGBA" and source.size == (1536, 1024), "Expected unchanged supplied RGBA 1536x1024 sheet"
    frames = {}
    for name, (box, feet) in POSES.items():
        assert box[0] <= feet[0] <= box[2] and box[1] <= feet[1] <= box[3] + 8, (name, "anchor outside pose")
        crop = isolate(source, name, box, KEEP.get(name))
        position = (ANCHOR[0] + box[0] - feet[0], ANCHOR[1] + box[1] - feet[1])
        assert position[0] >= 0 and position[1] >= 0, (name, "anchor clips top/left")
        assert position[0] + crop.width <= CELL[0] and position[1] + crop.height <= CELL[1], (name, "anchor clips bottom/right")
        frame = Image.new("RGBA", CELL)
        frame.paste(crop, position)
        assert (position[0] + feet[0] - box[0], position[1] + feet[1] - box[1]) == ANCHOR
        assert frame.crop((*position, position[0] + crop.width, position[1] + crop.height)).tobytes() == crop.tobytes(), (name, "copied pixels changed")
        assert frame.getchannel("A").getbbox() == tuple(v + position[i % 2] for i, v in enumerate(crop.getchannel("A").getbbox())), (name, "alpha overflow")
        frames[name] = frame
    assert all(keys and all(key in frames for key in keys) for _, _, keys in ANIMATIONS.values()), "Animation references absent pose"
    assert set(frames) == {key for _, _, keys in ANIMATIONS.values() for key in keys}, "Unused extracted pose"
    atlas = Image.new("RGBA", (CELL[0] * 8, CELL[1] * ((len(frames) + 7) // 8)))
    placements = {}
    for index, (name, frame) in enumerate(frames.items()):
        x, y = index % 8 * CELL[0], index // 8 * CELL[1]
        atlas.paste(frame, (x, y))
        placements[name] = (x, y, *CELL)
    output = ROOT / "assets"
    atlas.save(output / "mecha_atlas.png", optimize=True)
    chest = isolate(source, "chest", CHEST_BOX, CHEST_KEEP)
    chest = chest.crop(chest.getchannel("A").getbbox())
    chest.save(output / "mecha_chest.png", optimize=True)
    bolt = isolate(source, "bolt", BOLT_BOX)
    bolt = bolt.crop(bolt.getchannel("A").getbbox())
    assert bolt.width <= 40 and bolt.height <= 32, "Use the small gold bolt, not the full laser"
    bolt.save(output / "mecha_bolt.png", optimize=True)
    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "", '[ext_resource type="Texture2D" path="res://assets/mecha_atlas.png" id="1"]', ""]
    for name, rect in placements.items():
        resource += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{name}"]', 'atlas = ExtResource("1")', f'region = Rect2({", ".join(map(str, rect))})', ""]
    resource += ["[resource]", "animations = [{"]
    for index, (name, (fps, loop, keys)) in enumerate(ANIMATIONS.items()):
        resource += ['"frames": [']
        resource += [f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{key}")}}{"," if i < len(keys) - 1 else ""}' for i, key in enumerate(keys)]
        resource += [f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(fps)}', "}, {" if index < len(ANIMATIONS) - 1 else "}]"]
    (output / "mecha_frames.tres").write_text("\n".join(resource) + "\n", encoding="utf-8")
    if contact:
        contact = contact.resolve()
        assert not contact.is_relative_to(ROOT), "Contact previews must stay outside the repository"
        preview = Image.new("RGB", (256 * 6, 280 * ((len(frames) + 5) // 6)), (47, 75, 70))
        draw = ImageDraw.Draw(preview)
        for index, (name, frame) in enumerate(frames.items()):
            x, y = index % 6 * 256, index // 6 * 280
            draw.line((x, y + ANCHOR[1], x + 255, y + ANCHOR[1]), fill=(99, 125, 114))
            preview.paste(frame, (x, y), frame)
            draw.text((x + 8, y + 260), name, fill="white")
        preview.save(contact)
    print(f"Wrote {len(frames)} frames / {len(ANIMATIONS)} animations; atlas {atlas.size}; cells {CELL}; feet {ANCHOR}; chest {chest.size}; bolt {bolt.size}")
    if contact:
        print(f"Contact sheet: {contact}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contact", type=Path)
    generate(parser.parse_args().contact)
