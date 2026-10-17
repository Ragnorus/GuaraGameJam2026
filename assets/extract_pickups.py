"""Extract the medalla-can and coin pickups from the supplied sheet (requires Pillow)."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art/sheets/medalla_powerups_sheet.png"
CROPS = {
    "medalla_can": (8, 350, 81, 434),
    "coin": (901, 752, 962, 826),
}

with Image.open(SOURCE) as sheet:
    assert sheet.mode == "RGBA" and sheet.size == (1774, 887), "Expected supplied transparent 1774x887 sheet"
    for name, rect in CROPS.items():
        sprite = sheet.crop(rect)
        assert sprite.getchannel("A").getbbox() is not None, f"Empty crop: {name}"
        sprite.save(ROOT / "assets" / f"{name}.png")
