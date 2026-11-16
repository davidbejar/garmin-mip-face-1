#!/usr/bin/env python3
"""Generate BMFont (.fnt text + .png) bitmap fonts for the watch face.

The fēnix 8 system fonts are too wide for the time at the mockup's size, and
too soft at the smallest label sizes (design/spec.md §3). These fonts use
Barlow / Barlow Condensed (SIL OFL), rasterised with only the glyphs needed.

Usage (needs Pillow):  python3 tools/make_fonts.py
Output:                resources/fonts/<name>.fnt and <name>.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "fonts")
OUT = os.path.join(ROOT, "resources", "fonts")

MONTHS = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
          "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

# Edge modes:
#   "aa"        anti-aliased (smooth); fine for the large time digits.
#   "threshold" pixels at least half covered are inked; crisp small digits.
#   "mono"      FreeType's hinted 1-bit render; cleanest stems at tiny sizes.
#
# name, source TTF, pixel size, glyphs, edge mode, gap[, space]
#   gap None: the font's own spacing (side bearings kept).
#   gap n:    drop side bearings and space every glyph exactly n px from the
#             next (xadvance = ink width + n); `space` is the word gap in px.
#   fixed:    with a gap, every glyph gets the width of the widest one (glyph
#             centred in its cell), so numbers do not shift as digits change.
FONTS = [
    # 64 px as in the spec.
    ("time", "BarlowCondensed-SemiBold.ttf", 64, "0123456789:", "aa", None),
    # Small numbers with hard edges (system fonts were too light on the MIP
    # screen). Hinting only lands on some digit heights, so the sizes are the
    # nearest to the mockup:
    #   num12: 17 px -> 12 px digits. Seconds (spec 16 px) and moon percent.
    #   num13: 18 px -> 13 px digits. Body Battery and battery days.
    #   num11: 14 px -> 11 px digits. Solar percent (mockup 10 px; 10 is not reachable).
    ("num12", "BarlowCondensed-Bold.ttf", 17, "0123456789%d-", "threshold", None),
    ("num13", "BarlowCondensed-Bold.ttf", 18, "0123456789%d-", "threshold", None),
    ("num11", "BarlowCondensed-Bold.ttf", 14, "0123456789%d-", "threshold", None),
    # Current heart rate: spec 20 px bold. 14 px digits are not reachable with
    # hard edges (13 or 15), so 15 keeps it the largest number in the boxes.
    # SemiBold, fixed width, 2 px gaps: Bold closed the counters of 0, 6 and 9
    # and ran "77" together (user's choice after comparing options).
    ("num15", "BarlowCondensed-SemiBold.ttf", 20, "0123456789-", "threshold", 2, None, True),
    # Sunrise and sunset times: same 11 px digits in SemiBold, lighter than the
    # Bold box numbers (user's choice after comparing weights in the simulator).
    ("sun11", "BarlowCondensed-SemiBold.ttf", 14, "0123456789-:", "threshold", None),
    # Month line in the date block. 9 px -> 7 px capitals after hinting; the
    # system font's anti-aliased 6 px capitals were too soft on the MIP screen.
    # Gap 0: the code adds the month's letter-spacing.
    ("month", "Barlow-Bold.ttf", 9, "".join(sorted(set("".join(MONTHS)))), "mono", 0),
    # Small grey box labels ("WAX CRES", "BODY BAT", later "REST 52"). The spec
    # says 8.5 px (6 px capitals), but hinting only lands on 5 or 7 px capitals
    # and unhinted 6 px renders were uneven, so this uses the month's 7 px
    # capitals. The font's own spacing crowded "1ST QTR", so every letter is
    # 1 px apart with 2 px between words (widest label, WAX CRES: 46 px).
    ("label", "Barlow-Bold.ttf", 9, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -", "mono", 1, 2),
]

PAD = 1  # transparent gap between glyphs in the atlas


def build(name, ttf, size, glyphs, mode, gap, space=None, fixed=False):
    font = ImageFont.truetype(os.path.join(SRC, ttf), size)
    ascent, descent = font.getmetrics()

    # Rasterise each glyph on a generous canvas with its baseline origin at
    # (m, m + ascent), then crop to the inked pixels so the side bearings
    # cost no atlas memory (they live in xoffset / xadvance instead).
    m = int(size) + 1  # margin
    cells = []
    for ch in glyphs:
        canvas = Image.new("L", (3 * m, ascent + descent + 2 * m), 0)
        draw = ImageDraw.Draw(canvas)
        if mode == "mono":
            draw.fontmode = "1"
        draw.text((m, m + ascent), ch, font=font, fill=255, anchor="ls")
        if mode == "threshold":
            canvas = canvas.point(lambda v: 255 if v >= 128 else 0)
        if canvas.getbbox() is None:  # blank glyph (space): advance only
            adv = round(font.getlength(ch)) if gap is None or space is None else space + gap
            cells.append((ch, Image.new("L", (1, 1), 0), 0, 0, adv))
            continue
        ix0, iy0, ix1, iy1 = canvas.getbbox()
        mask = canvas.crop((ix0, iy0, ix1, iy1))
        if gap is not None:
            cells.append((ch, mask, 0, iy0 - m, mask.width + gap))
        else:
            cells.append((ch, mask, ix0 - m, iy0 - m, round(font.getlength(ch))))

    if fixed and gap is not None:
        cell = max(mask.width for _, mask, *_ in cells)
        cells = [(ch, mask, (cell - mask.width) // 2, yoff, cell + gap)
                 for ch, mask, _, yoff, _ in cells]

    # Pack into one row-based atlas.
    atlas_w = 256
    x = y = row_h = 0
    placed = []
    for ch, mask, xoff, yoff, adv in cells:
        if x + mask.width > atlas_w:
            x, y, row_h = 0, y + row_h + PAD, 0
        placed.append((ch, x, y, mask, xoff, yoff, adv))
        x += mask.width + PAD
        row_h = max(row_h, mask.height)
    atlas_h = y + row_h

    # White glyphs, coverage in alpha: colour is set at draw time.
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (255, 255, 255, 0))
    for ch, px, py, mask, *_ in placed:
        glyph = Image.new("RGBA", mask.size, (255, 255, 255, 255))
        glyph.putalpha(mask)
        atlas.paste(glyph, (px, py))
    atlas.save(os.path.join(OUT, name + ".png"))

    smooth = 1 if mode == "aa" else 0
    lines = [
        f'info face="{font.getname()[0]} {font.getname()[1]}" size={size} bold=0 italic=0 '
        f'charset="" unicode=1 stretchH=100 smooth={smooth} aa={smooth} '
        f"padding=0,0,0,0 spacing={PAD},{PAD}",
        f"common lineHeight={ascent + descent} base={ascent} scaleW={atlas_w} "
        f"scaleH={atlas_h} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(placed)}",
    ]
    for ch, px, py, mask, xoff, yoff, adv in placed:
        lines.append(
            f"char id={ord(ch)} x={px} y={py} width={mask.width} height={mask.height} "
            f"xoffset={xoff} yoffset={yoff} xadvance={adv} page=0 chnl=15"
        )
    with open(os.path.join(OUT, name + ".fnt"), "w") as f:
        f.write("\n".join(lines) + "\n")

    heights = sorted({mask.height for _, mask, *_ in cells})
    print(f"{name}: {ttf} {size}px {mode}  ascent={ascent} descent={descent} "
          f"glyph heights={heights}  glyphs={len(cells)}  atlas={atlas_w}x{atlas_h}")
    return {ch: adv for ch, _, _, _, adv in cells}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for spec in FONTS:
        advances = build(*spec)
        if spec[0] == "label":
            font = ImageFont.truetype(os.path.join(SRC, spec[1]), spec[2])
            for text in ("WAX CRES", "WAN CRES", "BODY BAT", "LAST QTR", "1ST QTR"):
                print(f"   {text:9s} {sum(advances[c] for c in text) - spec[5]}px")
        if spec[0] == "month":
            for month in MONTHS:
                ink = sum(advances[c] for c in month)
                print(f"   {month:9s} letters {ink}px, +2px gaps {ink + 2 * (len(month) - 1)}px")
