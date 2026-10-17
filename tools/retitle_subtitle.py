"""Rebuild the title screen subtitle "A GOTHAM ADVENTURE" as "A GUARA ADVENTURE".

Reuses the art's own pixel letters (G, U, A, R are all on that line), so the font, fill and outline match.
Source:  art/sheets/title_screen_original.png (unaltered, as supplied)
Output:  assets/ui/title_screen.png
Run:     python tools/retitle_subtitle.py   (requires Pillow)
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "sheets" / "title_screen_original.png"
OUT = ROOT / "assets" / "ui" / "title_screen.png"

TOP, BOTTOM = 136, 154          # letter rows (fill)
CLEAN_TOP, CLEAN_BOTTOM = 132, 158  # rows just outside the outline, used to repaint the background
X0, X1 = 345, 680               # horizontal span of the subtitle line
OUTLINE = 2
LETTER_GAP = 3                  # empty columns between letters
WORD_GAP = 19                   # empty columns between words
TEXT = "A GUARA ADVENTURE"
SOURCE_TEXT = "AGOTHAMADVENTURE"


def lum(p):
    return sum(p[:3]) / 3.0


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    sp = src.load()
    # Letter columns: runs of bright fill along the line.
    runs, start = [], None
    for x in range(X0, X1):
        on = any(min(sp[x, y]) > 170 for y in range(TOP, BOTTOM + 1))
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append((start, x - 1))
            start = None
    assert len(runs) == len(SOURCE_TEXT), runs
    centre = (runs[0][0] + runs[-1][1]) / 2.0

    def glyph_mask(x0: int, x1: int, pad: int = OUTLINE) -> set:
        core = {(x, y) for x in range(x0 - 1, x1 + 2) for y in range(TOP, BOTTOM + 1) if lum(sp[x, y]) > 60}
        return {(x + dx, y + dy) for (x, y) in core
                for dx in range(-pad, pad + 1) for dy in range(-pad, pad + 1)}

    glyphs = {}
    for ch, (x0, x1) in zip(SOURCE_TEXT, runs):
        glyphs.setdefault(ch, (x0, x1, glyph_mask(x0, x1)))

    out = src.copy()
    op = out.load()
    # Erase the old line: repaint every text pixel by blending the clean rows above and below it.
    erase = set()
    for x0, x1 in runs:
        erase |= glyph_mask(x0, x1, OUTLINE + 1)
    span = CLEAN_BOTTOM - CLEAN_TOP
    for (x, y) in erase:
        t = (y - CLEAN_TOP) / span
        a, b = sp[x, CLEAN_TOP], sp[x, CLEAN_BOTTOM]
        op[x, y] = tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))

    # Lay out the new line with the original spacing, centred where the old one was.
    layout, x = [], 0
    for ch in TEXT:
        if ch == " ":
            x += WORD_GAP - LETTER_GAP
            continue
        g0, g1, _ = glyphs[ch]
        layout.append((ch, x))
        x += (g1 - g0 + 1) + LETTER_GAP
    width = x - LETTER_GAP
    left = round(centre - width / 2.0)
    for ch, offset in layout:
        g0, _, mask = glyphs[ch]
        shift = left + offset - g0
        for (gx, gy) in mask:
            op[gx + shift, gy] = sp[gx, gy]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print("wrote", OUT, "subtitle", TEXT, "x", left, "..", left + width)


if __name__ == "__main__":
    main()
