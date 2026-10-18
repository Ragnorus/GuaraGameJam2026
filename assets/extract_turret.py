"""Extract the turret idle sprite and small bolt from the supplied sheet (requires Pillow)."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art/sheets/neon_sewer_turret_sheet.png"
CROPS = {
	"turret": (0, 44, 160, 220),
	"turret_bolt": (43, 500, 143, 546),
}

with Image.open(SOURCE) as sheet:
	assert sheet.mode == "RGBA" and sheet.size == (1774, 887), "Expected supplied transparent 1774x887 sheet"
	for name, rect in CROPS.items():
		sprite = sheet.crop(rect)
		assert sprite.getchannel("A").getbbox() is not None, f"Empty crop: {name}"
		sprite.save(ROOT / "assets" / f"{name}.png")
