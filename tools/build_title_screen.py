"""Build the title screen from the supplied art.

1. Subtitle "A GOTHAM ADVENTURE" -> "A GUARA ADVENTURE", reusing the art's own pixel letters
   (G, U, A, R are all on that line) so the font, fill and outline match.
2. The bat in the spotlight signal -> a black Guara red hawk head (the Guaras' symbol), traced by hand
   from art/sheets/guara_hawk.png as a polygon stencil.
3. The "(c) 1993 PIXELWORKS ... LICENSED BY DC COMICS" credit lines are removed.
Source:  art/sheets/title_screen_original.png (unaltered, as supplied)
Output:  assets/ui/title_screen.png
Run:     python tools/build_title_screen.py   (requires Pillow)
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "sheets" / "title_screen_original.png"
HAWK = ROOT / "art" / "sheets" / "guara_hawk.png"  # reference the stencil was traced from
OUT = ROOT / "assets" / "ui" / "title_screen.png"

# Spotlight disc in the title art.
DISC_CENTER = (249.5, 394.0)
DISC_RX, DISC_RY = 30.0, 27.0
DISC_COLOR = (238, 230, 166)
LOGO_SIZE = 42                  # logo height in px
LOGO_COLOR = (10, 10, 14)
SS = 8                          # supersampling for the stencil
# Hawk head facing right, in the icon's 81x84 pixel space: crest/back feathers, hooked beak, throat, neck feathers.
HAWK_OUTLINE = [
    (22, 17), (31, 20), (40, 19), (48, 21), (55, 25), (60, 31), (64, 37), (67, 43), (68, 50),
    (66, 56), (63, 60), (62, 54), (59, 49), (53, 48), (49, 51), (46, 55), (47, 62), (45, 69),
    (39, 64), (34, 70), (30, 63), (24, 67), (22, 58), (15, 62), (16, 52), (9, 54), (14, 45),
    (7, 42), (14, 37), (9, 31), (17, 29), (13, 23), (23, 23),
]
HAWK_MOUTH = [(52, 46), (60, 45), (62, 48), (58, 47)]  # notch separating beak from jaw
HAWK_EYE = (47, 34, 2.2)                                 # x, y, radius (cut out)
CREDIT_BOX = (270, 431, 758, 480)                        # "(c) 1993 PIXELWORKS..." lines, removed
CREDIT_SAMPLE_TOP = 419                                  # clean facade rows 419..430 refill the block

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


def retitle() -> Image.Image:
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

    return out


def hawk_silhouette(height: int) -> Image.Image:
    """Anti-aliased hawk mask ("L"), traced from the Guara red hawk icon and supersampled."""
    xs = [p[0] for p in HAWK_OUTLINE]
    ys = [p[1] for p in HAWK_OUTLINE]
    x0, y0 = min(xs), min(ys)
    scale = height / (max(ys) - y0)
    w = round((max(xs) - x0) * scale)
    big = Image.new("L", (w * SS, height * SS), 0)
    d = ImageDraw.Draw(big)
    tf = lambda pts: [((x - x0) * scale * SS, (y - y0) * scale * SS) for x, y in pts]
    d.polygon(tf(HAWK_OUTLINE), fill=255)
    d.polygon(tf(HAWK_MOUTH), fill=0)
    (ex, ey), er = tf([HAWK_EYE[:2]])[0], HAWK_EYE[2] * scale * SS
    d.ellipse((ex - er * 1.4, ey - er, ex + er * 1.4, ey + er), fill=0)
    return big.resize((w, height), Image.LANCZOS)


def hawk_signal(img: Image.Image) -> None:
    """Replace the bat in the spotlight disc with a black Guara hawk."""
    p = img.load()
    cx, cy = DISC_CENTER
    # Relight the inside of the disc (removes the bat), feathering into the original rim.
    for y in range(int(cy - DISC_RY - 2), int(cy + DISC_RY + 3)):
        for x in range(int(cx - DISC_RX - 2), int(cx + DISC_RX + 3)):
            r = math.hypot((x - cx) / DISC_RX, (y - cy) / DISC_RY)
            if r > 1.03:
                continue
            a = 1.0 if r < 0.97 else (1.03 - r) / 0.06
            shade = 1.0 - 0.08 * r * r
            c = tuple(min(255, round(v * shade)) for v in DISC_COLOR)
            o = p[x, y]
            p[x, y] = tuple(round(o[i] * (1 - a) + c[i] * a) for i in range(3))
    mask = hawk_silhouette(LOGO_SIZE)
    ox = round(cx - mask.width / 2)
    oy = round(cy - mask.height / 2)
    ink = Image.new("RGB", mask.size, LOGO_COLOR)
    img.paste(ink, (ox, oy), mask)


def remove_credits(img: Image.Image, src: Image.Image) -> None:
    """Erase the "(c) 1993 PIXELWORKS ... LICENSED BY DC COMICS" lines, inpainting from the surrounding art."""
    x0, y0, x1, y1 = CREDIT_BOX
    p = img.load()
    # Clear the whole block by reflecting the clean facade band just above it back and forth (between the
    # art's PRESS START and the credits; keeps the pixel texture crisp), then blend the last rows into the
    # street below so the pedestrians and police car are not stretched.
    band = y0 - CREDIT_SAMPLE_TOP
    blend = 8
    for y in range(y0, y1 + 1 - blend):
        k = (y - y0) % (2 * band)
        sy = y0 - 1 - k if k < band else CREDIT_SAMPLE_TOP + (k - band)
        for x in range(x0, x1 + 1):
            p[x, y] = src.getpixel((x, sy))
    top = y1 - blend
    for y in range(top + 1, y1 + 1):
        t = (y - top) / (blend + 1)
        for x in range(x0, x1 + 1):
            a, b = p[x, top], src.getpixel((x, y1 + 1))
            p[x, y] = tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def main() -> None:
    out = retitle()
    remove_credits(out, Image.open(SRC).convert("RGB"))
    hawk_signal(out)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
