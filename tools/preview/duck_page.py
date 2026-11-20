import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from duck import *
import base64, io


def b64(arr):
    b = io.BytesIO(); Image.fromarray(arr).save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()

X0, X1, Y0, Y1 = 8, 176, 84, 148
TIMES = ["12:25", "22:22", "20:42", "10:08"]
FONT_NAME = {"0": "Today's font", "A6": "A6 · Saira Condensed", "B4": "B4 · Casio LCD", "C7": "C7 · Dot matrix", "D2": "D2 · Kalam"}
SHAPE_H = {"classic": 0.92, "bighead": 1.35}

DESIGNS_PAGE = [
    ("tallneck", "A", "Option A: round head, taller body, thin neck where needed", "The head is a full circle again. The body grows up to 1.15 times the duck's width; where the digits are taller than head plus body (only the LCD font), a thin neck about a third of the duck's width fills the gap.", "colour", "tall"),
    ("tallbody", "B", "Option B: round head, tallest body, no neck", "The body grows up to 1.35 times the duck's width, so the head always sits straight on the body.", "colour", "tall"),
    ("yellow", "3", "Before: design 3", "The original, shorter version, for comparison.", "colour", "bighead"),
]
ONLY = {"angular": "B4", "dots": "C7", "finedots": "C7", "doodle": "D2"}


def two_width(f):
    return f.draw("2")[1][0][1] - (2.0 if f.id == "D2" else 1.0)


base = np.array(Image.open(os.path.join(OUT, "0_1008.png")))
groups, opts = [], []
for key, num, title, blurb, kind, shape in DESIGNS_PAGE:
    groups.append((key, title, blurb))
    fn, st = DESIGNS[key]
    for f in FONTS:
        if key in ONLY and ONLY[key] != f.id:
            continue
        crops = {}
        for t in TIMES:
            out = render(f, t, (fn, st))
            crops[t] = b64(out[Y0:Y1, X0:X1])
        if shape == "tall":
            h = f.H
        elif key == "dots":
            h = f.H
        else:
            h = round(SHAPE_H[shape] * two_width(f))
        colours = "Yellow, orange beak, text-colour outline" if kind == "colour" else "Text colour"
        parts = "Dots on the digit grid" if kind == "dots" else ("Circle, 2 polygons, eye, wing" if kind != "outline" else "Outlined circle and body, beak, eye, wing")
        opts.append(dict(id=f"{num} · {f.id if f.id != '0' else 'Now'}", group=key, name=FONT_NAME[f.id],
                         facts=[["Duck height", f"{h} px (digits {f.H} px)"], ["Colours", colours], ["Drawn with", parts]],
                         note="", crops=crops))
        print(key, f.id, h, flush=True)

data = dict(base=b64(base), band=[X0, Y0, X1 - X0, Y1 - Y0], times=TIMES, groups=groups, opts=opts)
html = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "duck_template.html")).read().replace("/*DATA*/null", json.dumps(data))
open(os.path.join(OUT, "rubber-duck.html"), "w").write(html)
print(len(html) // 1024, "KB")
