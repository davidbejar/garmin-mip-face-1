#!/usr/bin/env python3
"""Generate the figures used by the documentation site (docs/assets/generated).

Every figure is derived from the code itself, so the docs cannot drift from it:
- icons:   the run-length arrays in source/Icons.mc
- glyphs:  DOT_GLYPHS and SEG_MASK in source/TimeDisplay.mc
- layout:  the spec-canvas constants in source/InstrumentPanelView.mc
- fonts:   the bitmap font atlases in resources/fonts/*.png

Usage (needs Pillow):  python3 tools/docs/make_assets.py
"""
import os
import re
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "assets", "generated")
ICONS_MC = os.path.join(ROOT, "source", "Icons.mc")
TIME_MC = os.path.join(ROOT, "source", "TimeDisplay.mc")

INK = "#000000"
ACCENT = "#FF5500"
GRID = "#AAAAAA"


def const_array(src, name):
    """Numbers of `const NAME = [ ... ]` in a Monkey C source file."""
    m = re.search(r"const\s+" + name + r"\s*=\s*\[(.*?)\]\s*as", src, re.S)
    if not m:
        raise SystemExit(f"{name} not found")
    body = re.sub(r"//[^\n]*", "", m.group(1))
    return [float(v) if "." in v else int(v) for v in re.findall(r"-?\d+(?:\.\d+)?", body)]


def svg(w, h, body, scale):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w * scale}" height="{h * scale}" shape-rendering="crispEdges">\n{body}</svg>\n')


def grid(w, h):
    lines = [f'<rect width="{w}" height="{h}" fill="#FFFFFF"/>']
    for x in range(w + 1):
        lines.append(f'<line x1="{x}" y1="0" x2="{x}" y2="{h}" stroke="{GRID}" stroke-width="0.04"/>')
    for y in range(h + 1):
        lines.append(f'<line x1="0" y1="{y}" x2="{w}" y2="{y}" stroke="{GRID}" stroke-width="0.04"/>')
    return lines


def runs_rects(runs, colour):
    out = []
    for i in range(0, len(runs), 3):
        row, x, w = runs[i:i + 3]
        out.append(f'<rect x="{x}" y="{row}" width="{w}" height="1" fill="{colour}"/>')
    return out


def write(name, text):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(text)
    print("wrote", name)


def icons():
    src = open(ICONS_MC).read()
    simple = {
        "sun": (12, 13, ["SUN_RUNS"], [ACCENT]),
        "heart": (9, 9, ["HEART_RUNS"], [ACCENT]),
        "flame": (6, 10, ["FLAME_RUNS"], [ACCENT]),
        "steps": (9, 11, ["STEPS_RUNS"], [INK]),
        "pin": (8, 10, ["PIN_RUNS"], [INK]),
        "sunrise": (12, 11, ["HALF_SUN_RUNS", "SUNRISE_ARROW_RUNS", "HORIZON_RUNS"], [ACCENT, INK, INK]),
        "sunset": (12, 11, ["HALF_SUN_RUNS", "SUNSET_ARROW_RUNS", "HORIZON_RUNS"], [ACCENT, INK, INK]),
    }
    for name, (w, h, arrays, colours) in simple.items():
        body = grid(w, h)
        for arr, col in zip(arrays, colours):
            body += runs_rects(const_array(src, arr), col)
        write(f"icon-{name}.svg", svg(w, h, "\n".join(body) + "\n", 14))

    # Bolt: a polygon, not runs.
    pts = const_array(src, "BOLT_POINTS")
    poly = " ".join(f"{pts[i]},{pts[i + 1]}" for i in range(0, len(pts), 2))
    body = grid(7, 10) + [f'<polygon points="{poly}" fill="{INK}" fill-opacity="0.85"/>']
    body += [f'<circle cx="{pts[i]}" cy="{pts[i + 1]}" r="0.18" fill="{ACCENT}"/>' for i in range(0, len(pts), 2)]
    write("icon-bolt.svg", svg(7, 10, "\n".join(body) + "\n", 14).replace('shape-rendering="crispEdges"', ""))


def dot_glyphs():
    g = const_array(open(TIME_MC).read(), "DOT_GLYPHS")
    cell_w, gap = 5, 1
    w = 10 * (cell_w + gap) - gap
    body = [f'<rect width="{w}" height="7" fill="#FFFFFF"/>']
    for d in range(10):
        for row in range(7):
            bits = g[7 * d + row]
            for col in range(5):
                cx = d * (cell_w + gap) + col + 0.5
                on = bits & (16 >> col)
                body.append(f'<circle cx="{cx}" cy="{row + 0.5}" r="0.42" '
                            f'fill="{INK if on else "#E6E6E6"}"/>')
    write("dot-glyphs.svg", svg(w, 7, "\n".join(body) + "\n", 12).replace('shape-rendering="crispEdges"', ""))


def seven_segment():
    """Segment map (a-g) and the ten digits from SEG_MASK, unslanted."""
    masks = const_array(open(TIME_MC).read(), "SEG_MASK")
    # Simple segment boxes in a 6 x 10 cell.
    seg = {
        0: (1, 0, 4, 1), 1: (5, 1, 1, 4), 2: (5, 5, 1, 4), 3: (1, 9, 4, 1),
        4: (0, 5, 1, 4), 5: (0, 1, 1, 4), 6: (1, 4.5, 4, 1),
    }
    names = "abcdefg"
    pitch = 8
    w = 11 * pitch
    body = [f'<rect width="{w}" height="12" fill="#FFFFFF"/>']
    # Legend cell.
    for s, (x, y, sw, sh) in seg.items():
        body.append(f'<rect x="{x + 0.1}" y="{y + 0.5}" width="{sw - 0.2}" height="{sh - 0.2}" fill="{GRID}"/>')
        tx, ty = x + sw / 2, y + sh / 2 + 0.85
        body.append(f'<text x="{tx}" y="{ty}" font-size="1.3" text-anchor="middle" '
                    f'font-family="monospace" fill="{INK}">{names[s]}</text>')
    for d in range(10):
        ox = (d + 1) * pitch
        for s, (x, y, sw, sh) in seg.items():
            on = masks[d] & (1 << s)
            body.append(f'<rect x="{ox + x + 0.1}" y="{y + 0.5}" width="{sw - 0.2}" height="{sh - 0.2}" '
                        f'fill="{INK if on else "#EEEEEE"}"/>')
        body.append(f'<text x="{ox + 3}" y="11.8" font-size="1.3" text-anchor="middle" '
                    f'font-family="monospace" fill="#555555">{masks[d]}</text>')
    write("seven-segment.svg", svg(w, 12, "\n".join(body) + "\n", 9).replace('shape-rendering="crispEdges"', ""))


def layout():
    """The 260 px spec canvas with every region from the view's constants."""
    regions = [
        ("Sun times", 70, 15, 120, 15, ACCENT),
        ("Moon", 40, 39, 54, 36, INK),
        ("Date block", 98, 37, 64, 40, INK),
        ("Body Battery", 166, 39, 54, 36, INK),
        ("Time HH:MM", 16, 94, 127, 47, "#0055FF"),
        ("WK / sec", 146, 94, 28, 47, "#AA00AA"),
        ("Side panel", 176, 84, 68, 62, INK),
        ("Heart rate", 28, 154, 204, 44, INK),
        ("Calories", 52, 202, 52, 40, "#00AA00"),
        ("Steps", 104, 202, 52, 40, "#00AA00"),
        ("Distance", 156, 202, 52, 40, "#00AA00"),
    ]
    body = ['<rect width="260" height="260" fill="#FFFFFF"/>',
            '<circle cx="130" cy="130" r="130" fill="#F4F4F4" stroke="#555555" stroke-width="1"/>']
    for x in range(0, 261, 20):
        body.append(f'<line x1="{x}" y1="0" x2="{x}" y2="260" stroke="#DDDDDD" stroke-width="0.3"/>')
        body.append(f'<line x1="0" y1="{x}" x2="260" y2="{x}" stroke="#DDDDDD" stroke-width="0.3"/>')
    for name, x, y, w, h, col in regions:
        body.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{col}" fill-opacity="0.08" '
                    f'stroke="{col}" stroke-width="1"/>')
        body.append(f'<text x="{x + w / 2}" y="{y + h / 2 + 2.5}" font-size="7" text-anchor="middle" '
                    f'font-family="sans-serif" fill="{col}">{name}</text>')
    body.append('<line x1="10" y1="141" x2="176" y2="141" stroke="#FF0000" stroke-width="0.6" stroke-dasharray="2 2"/>')
    body.append('<text x="12" y="150" font-size="6" font-family="sans-serif" fill="#FF0000">baseline y 141</text>')
    write("layout.svg", svg(260, 260, "\n".join(body) + "\n", 2).replace('shape-rendering="crispEdges"', ""))


def font_atlases():
    """White-on-transparent atlases shown on a dark tile, 3x, nearest neighbour."""
    fonts = os.path.join(ROOT, "resources", "fonts")
    for name in ["time", "time_saira", "time_kalam", "num15", "num13", "num12", "num11", "sun11", "month", "label"]:
        atlas = Image.open(os.path.join(fonts, name + ".png")).convert("RGBA")
        bbox = atlas.getbbox() or (0, 0, 1, 1)
        atlas = atlas.crop((0, 0, bbox[2], bbox[3]))
        tile = Image.new("RGBA", (atlas.width + 8, atlas.height + 8), (34, 34, 34, 255))
        tile.alpha_composite(atlas, (4, 4))
        k = 2 if atlas.height > 40 else 4
        tile = tile.resize((tile.width * k, tile.height * k), Image.NEAREST)
        tile.convert("RGB").save(os.path.join(OUT, f"atlas-{name}.png"), optimize=True)
        print("wrote", f"atlas-{name}.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icons()
    dot_glyphs()
    seven_segment()
    layout()
    font_atlases()
