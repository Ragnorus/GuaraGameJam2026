"""Preserve source pixels: python tools/slice_capital.py [contact-sheet-outside-repo.png]."""
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
# Platform boxes begin on a continuous stone row, not the uneven cloth above it.
BOXES = {
    "platform_long": (721, 50, 1205, 151),
    "platform_short": (757, 177, 1013, 256),
    "banner": (1210, 13, 1329, 239),
    "chandelier": (141, 367, 344, 554),
    "monitor": (749, 260, 1095, 433),
    "office": (1098, 236, 1530, 431),
    "desk": (10, 550, 287, 744),
    "statue": (620, 556, 737, 743),
    "safe": (851, 601, 1005, 727),
    "money": (1343, 661, 1534, 768),
    "pillar": (1234, 565, 1294, 690),
}
# Absolute sheet coordinates exclude neighboring props, including faint alpha debris.
POLYGONS = {
    "platform_long": [(721, 50), (1204, 50), (1204, 143),
                      (1100, 143), (1100, 151), (721, 151)],
    "banner": [(1210, 13), (1328, 13), (1328, 34), (1317, 40),
               (1317, 238), (1218, 238), (1218, 40), (1210, 40)],
    "chandelier": [(232, 367), (248, 367), (251, 405), (270, 441),
                   (298, 463), (340, 463), (340, 487), (326, 487),
                   (326, 510), (311, 510), (311, 529), (291, 529),
                   (291, 543), (270, 543), (270, 553), (244, 553),
                   (244, 543), (216, 543), (216, 530), (190, 530),
                   (190, 513), (168, 513), (168, 494), (141, 494),
                   (141, 461), (180, 461), (211, 431), (227, 404)],
    "office": [(1098, 275), (1170, 275), (1170, 258), (1253, 258),
               (1253, 236), (1530, 236), (1530, 431), (1098, 431)],
    "desk": [(120, 550), (220, 550), (220, 580), (278, 580),
             (278, 632), (290, 632), (290, 744), (10, 744),
             (10, 642), (68, 642), (68, 625), (95, 625), (95, 599),
             (120, 599)],
    "money": [(1400, 661), (1470, 661), (1470, 680), (1494, 680),
              (1494, 708), (1513, 708), (1513, 741), (1533, 741),
              (1533, 791), (1343, 791), (1343, 762), (1367, 737),
              (1367, 706), (1400, 687)],
}


def cutout(source: Image.Image, name: str, box: tuple[int, int, int, int]) -> Image.Image:
    left, top, right, bottom = box
    assert 0 <= left < right <= source.width and 0 <= top < bottom <= source.height
    crop = source.crop(box)
    mask = Image.new("L", crop.size, 255 if name not in POLYGONS else 0)
    draw = ImageDraw.Draw(mask)
    if name in POLYGONS:
        draw.polygon([(x - left, y - top) for x, y in POLYGONS[name]], fill=255)
    if name == "chandelier":
        # Gold suspension chains cross the dark lighting truss on the source sheet.
        for x0, x1 in ((144, 154), (324, 333)):
            for y in range(386, 467):
                for x in range(x0, x1):
                    red, green, blue, alpha = source.getpixel((x, y))
                    if alpha >= 16 and red > 60 and red > blue * 1.4:
                        mask.putpixel((x - left, y - top), 255)
    # The supplied alpha contains near-invisible background noise; retain original
    # RGBA verbatim inside the binary silhouette, never recolor or resample it.
    silhouette = crop.getchannel("A").point(lambda alpha: 255 if alpha >= 16 else 0)
    mask = ImageChops.multiply(mask, silhouette)
    bounds = mask.getbbox()
    assert bounds is not None, f"Empty cutout: {name}"
    result = Image.new("RGBA", crop.size)
    result.paste(crop, (0, 0), mask)
    result = result.crop(bounds)
    assert result.getchannel("A").getextrema()[0] == 0, f"Missing transparency: {name}"
    assert result.getchannel("A").getbbox() == (0, 0, *result.size), f"Untrimmed cutout: {name}"
    if name.startswith("platform_"):
        assert bounds[1] == 0, f"Walking surface moved: {name}"
        assert result.getchannel("A").crop((0, 0, result.width, 1)).getextrema()[0] >= 200
    return result


def generate() -> None:
    output = ROOT / "assets/sprites/capital"
    output.mkdir(parents=True, exist_ok=True)
    sprites = {}
    with Image.open(ROOT / "art/sheets/corrupt_capital_sheet.png") as source:
        assert source.size == (1536, 1024) and source.mode == "RGBA", "Expected the original capital sheet"
        for name, box in BOXES.items():
            sprite = cutout(source, name, box)
            sprite.save(output / f"{name}.png")
            sprites[name] = sprite
            print(f"{name}.png: {sprite.width}x{sprite.height}")
    if len(sys.argv) > 1:
        destination = Path(sys.argv[1]).resolve()
        assert not destination.is_relative_to(ROOT), "Keep contact previews outside the repository"
        sheet = Image.new("RGB", (1020, 6 * 280), (62, 65, 72))
        draw = ImageDraw.Draw(sheet)
        for index, (name, sprite) in enumerate(sprites.items()):
            x, y = (index % 2) * 510, (index // 2) * 280
            draw.text((x + 8, y + 5), f"{name}: {sprite.width}x{sprite.height}", fill="white")
            sheet.paste(sprite, (x + 8, y + 24), sprite)
        sheet.save(destination)
        print(f"Contact sheet: {destination}")


if __name__ == "__main__":
    generate()
