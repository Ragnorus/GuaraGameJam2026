"""Validate and copy complete stage paintings: python tools/slice_bichema.py."""
from pathlib import Path
from shutil import copyfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PAINTINGS = {
    "plaza": (2172, 724),
    "pub": (1983, 793),
    "factory": (2172, 724),
}


def generate() -> None:
    destination = ROOT / "assets/backgrounds/bichema"
    destination.mkdir(parents=True, exist_ok=True)
    for name, size in PAINTINGS.items():
        source = ROOT / "art/sheets" / f"{name}_stage.png"
        with Image.open(source) as painting:
            assert painting.format == "PNG" and painting.size == size, f"Unexpected painting: {source}"
            painting.verify()
        copyfile(source, destination / f"{name}.png")
    print(f"Copied {len(PAINTINGS)} complete stage paintings without altering source bytes")


if __name__ == "__main__":
    generate()
