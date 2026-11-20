import os, json, base64, io
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
meta = json.load(open(os.path.join(OUT, "meta.json")))
ghost = json.load(open(os.path.join(OUT, "meta_ghost.json")))
KEEP = ["0", "A6", "B4", "D2"]
meta = [m for m in meta if m["id"] in KEEP] + ghost
for m in meta:
    if m["id"] in ("A6", "B4", "D2"): m["group"] = "picked"
mem = json.load(open(os.path.join(OUT, "mem.json")))

X0, X1, Y0, Y1 = 8, 176, 84, 148
TIMES = ["10:08", "23:45", "16:59", "07:28"]

NOTES = {
    "0": ("Today's font. Every option below is measured against this one.", "bitmap", "OFL"),
    "A1": ("Same family, one step heavier. It is a little wider, so it shrinks slightly to fit.", "bitmap", "OFL"),
    "A2": ("Same family, heavier again. Strong at a glance, but 6 px shorter than today.", "bitmap", "OFL"),
    "A3": ("The heaviest Barlow. Very punchy, but the width costs it 9 px of height.", "bitmap", "OFL"),
    "A4": ("Tall, narrow and sturdy. Keeps almost the full height.", "bitmap", "OFL"),
    "A5": ("Very condensed, so it keeps the full height with room to spare.", "bitmap", "OFL"),
    "A6": ("Squarer, more technical shapes. Close in spirit to a dive computer.", "bitmap", "OFL"),
    "A7": ("Tall poster numerals at full height. Narrow, with flat-sided zeros.", "bitmap", "OFL"),
    "A8": ("Garmin's own system font, already used for the date. No font file to ship.", "system", "Built into the watch"),
    "B1": ("Classic 7-segment font, upright. A 1 sits on the right of its cell, as on a real LCD.", "bitmap", "OFL"),
    "B2": ("The same font slanted, closest to a Casio F-91W.", "bitmap", "OFL"),
    "B3": ("Slanted, with the unlit segments shown in light grey behind the digits, like a real LCD.", "bitmap", "OFL"),
    "B4": ("Segments drawn as shapes in code, slanted like a Casio. Full height, no font file.", "drawn", "None needed"),
    "B5": ("Drawn in code, upright, with thick segments. Reads like a bold alarm clock.", "drawn", "None needed"),
    "B6": ("B4 plus the unlit segments in light grey.", "drawn", "None needed"),
    "C5": ("Your reference's grid and dot size: 5×7, round dots that almost touch, slashed zero, wide-footed 1. Hard edges, 35 px tall.", "drawn", "None needed"),
    "C6": ("The same grid with smooth (anti-aliased) dots, and tighter gaps between digits so the dots can be bigger. 39 px tall.", "drawn", "None needed"),
    "C7": ("C6 with the rows spread a little further apart so the digits reach 45 px. The dots stay round.", "drawn", "None needed"),
    "C1": ("Classic 5×7 dot-matrix grid. Four digits across only leave room for 34 px of height.", "drawn", "None needed"),
    "C2": ("The 5×7 grid with taller row spacing and slightly oval dots, to use the full height.", "drawn", "None needed"),
    "C3": ("A narrower 4×7 grid, so the dots can be bigger. Full height.", "drawn", "None needed"),
    "C4": ("The 4×7 grid with square dots. Looks like an LED panel.", "drawn", "None needed"),
    "D1": ("Casual marker pen, slanted.", "bitmap", "OFL"),
    "D2": ("Bold felt-tip, slanted. The most legible of the slanted ones.", "bitmap", "OFL"),
    "D3": ("Thick permanent marker. Heavy and loud.", "bitmap", "Apache 2.0"),
    "D4": ("Neat upright print, like careful handwriting. The easiest to read.", "bitmap", "OFL"),
    "D6": ("Thin ballpoint pen. The strokes are only 2 px, so it is light on this screen.", "bitmap", "OFL"),
    "D7": ("Tall, narrow pen print, a little rough.", "bitmap", "OFL"),
}
GROUPS = [
    ("current", "Today", "The current time font, for reference."),
    ("picked", "Your picks", "A6, B4 and D2, unchanged from the first round."),
    ("dots", "C · Dot matrix, take two", "Modelled on the GHOSTLINE face you linked: a 5×7 grid of big round dots, a slashed zero and a 1 with a wide foot. C6 and C7 use smooth dots, which the fēnix 8 Solar 47mm supports (Dc.setAntiAlias, API 3.2.0)."),
]


def b64(arr):
    b = io.BytesIO(); Image.fromarray(arr).save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


base = np.array(Image.open(os.path.join(OUT, "0_1008.png")))
opts = []
for m in meta:
    crops = {}
    for t in TIMES + [m["widest_time"]]:
        a = np.array(Image.open(os.path.join(OUT, f"{m['id']}_{t.replace(':', '')}.png")))
        crops[t] = b64(a[Y0:Y1, X0:X1])
    note, method, lic = NOTES[m["id"]]
    if method == "bitmap":
        memtxt = f"Bitmap font, about {mem[m['id']]} % of today's"
    elif method == "system":
        memtxt = "System font, no file"
    else:
        memtxt = "Drawn in code, no font file"
    opts.append(dict(id=m["id"], group=m["group"], name=m["name"].replace("Drawn: ", ""), h=m["digit_h"],
                     widest=m["widest"], widestTime=m["widest_time"], note=note, mem=memtxt, lic=lic, crops=crops))

data = dict(base=b64(base), band=[X0, Y0, X1 - X0, Y1 - Y0], times=TIMES, groups=GROUPS, opts=opts)
html = open(os.path.join(HERE, "template.html")).read().replace("/*DATA*/null", json.dumps(data))
open(os.path.join(OUT, "time-fonts.html"), "w").write(html)
print(len(html) // 1024, "KB")
