import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import *

H0, W0 = 47, 127
SHOW = ["10:08", "23:45", "16:59", "07:28"]


def dl(n): return os.path.join(DL, n)


def fit_ttf(spec, maxsize=200):
    lo = None
    for s in range(30, maxsize):
        if spec.digit_h(s) <= H0:
            lo = s
        else:
            break
    s = lo
    while True:
        w, t = widest_ttf(spec, s)
        if w <= W0:
            return s, w, t
        s -= 1


def widest_ttf(spec, size):
    best = (0, None)
    f, m = spec.metrics(size)
    tr = spec.track_em * size
    for t in all_times():
        x, l, r = 0.0, 1e9, -1e9
        for ch in t:
            p = round(x)
            k = "8" if (spec.cell and ch != ":") else ch
            l = min(l, p + m[k][1][0]); r = max(r, p + m[k][1][2])
            x += m[ch][0] + tr
        if r - l > best[0]:
            best = (r - l, t)
    return best


def widest_drawn(fn):
    best = (0, None)
    for t in all_times():
        a = fn(t)[0]
        xs = np.where((a >= 128).any(0))[0]
        w = xs.max() + 1
        if w > best[0]:
            best = (w, t)
    return best


OPTIONS = []
def ttf(id, group, name, path, note, **kw):
    OPTIONS.append(dict(id=id, group=group, name=name, kind="ttf", spec=TTF(path, **kw), note=note))
def drawn(id, group, name, obj, H, note):
    OPTIONS.append(dict(id=id, group=group, name=name, kind="drawn", spec=obj, H=H, note=note))

R = os.path.join(REPO, "tools/fonts")
ttf("0", "current", "Barlow Condensed SemiBold (today)", os.path.join(R, "BarlowCondensed-SemiBold.ttf"), "", track_em=-1.25 / 64)

ttf("A1", "bold", "Barlow Condensed Bold", os.path.join(R, "BarlowCondensed-Bold.ttf"), "")
ttf("A2", "bold", "Barlow Condensed ExtraBold", dl("BarlowCondensed-ExtraBold.ttf"), "")
ttf("A3", "bold", "Barlow Condensed Black", dl("BarlowCondensed-Black.ttf"), "")
ttf("A4", "bold", "Oswald Bold", dl("Oswald.ttf"), "", axes={"Weight": 700})
ttf("A5", "bold", "Antonio Bold", dl("Antonio.ttf"), "", axes={"Weight": 700})
ttf("A6", "bold", "Saira Condensed ExtraBold", dl("SairaCondensed-ExtraBold.ttf"), "")
ttf("A7", "bold", "Bebas Neue", dl("BebasNeue-Regular.ttf"), "")
ttf("A8", "bold", "Roboto Condensed Bold (Garmin system font)", os.path.join(SYS, "RobotoCondensed-Bold.ttf"), "")

D7 = os.path.join(DSEG, "DSEG7-Classic")
ttf("B1", "lcd", "DSEG7 Classic Bold", os.path.join(D7, "DSEG7Classic-Bold.ttf"), "", track_em=-0.06, cell=True)
ttf("B2", "lcd", "DSEG7 Classic Bold Italic", os.path.join(D7, "DSEG7Classic-BoldItalic.ttf"), "", track_em=-0.06, cell=True)
ttf("B3", "lcd", "DSEG7 Classic Italic + unlit segments", os.path.join(D7, "DSEG7Classic-Italic.ttf"), "", track_em=-0.06, cell=True, ghost=True)
drawn("B4", "lcd", "Drawn: Casio slant, thin segments", SevenSeg(w=23, t=5, gap=1, slant=0.10, pitch=28, colon_w=12), 47, "")
drawn("B5", "lcd", "Drawn: upright, heavy segments", SevenSeg(w=24, t=7, gap=1, slant=0.0, pitch=29, colon_w=13), 47, "")
drawn("B6", "lcd", "Drawn: Casio slant + unlit segments", SevenSeg(w=23, t=5, gap=1, slant=0.10, pitch=28, colon_w=12, ghost=True), 47, "")

drawn("C1", "dots", "Drawn: 5×7 round dots (classic)", DotMatrix(FONT5x7, 5, 5, 4, "round"), None, "")
drawn("C2", "dots", "Drawn: 5×7 tall dots", DotMatrix(FONT5x7, 5, 7, 4, "round", dot_h=5), None, "")
drawn("C3", "dots", "Drawn: 4×7 round dots", DotMatrix(FONT4x7, 6, 7, 5, "round"), None, "")
drawn("C4", "dots", "Drawn: 4×7 square dots", DotMatrix(FONT4x7, 6, 7, 5, "square"), None, "")

ttf("D1", "hand", "Caveat Bold", dl("Caveat.ttf"), "", axes={"Weight": 700}, track_em=0)
ttf("D2", "hand", "Kalam Bold", dl("Kalam-Bold.ttf"), "", track_em=0)
ttf("D3", "hand", "Permanent Marker", dl("PermanentMarker-Regular.ttf"), "", track_em=-0.04)
ttf("D4", "hand", "Patrick Hand", dl("PatrickHand-Regular.ttf"), "", track_em=0)
ttf("D6", "hand", "Nanum Pen Script", dl("NanumPenScript-Regular.ttf"), "", track_em=0)
ttf("D7", "hand", "Covered By Your Grace", dl("CoveredByYourGrace.ttf"), "", track_em=0)

only = set(sys.argv[1:])
results = []
for o in OPTIONS:
    if only and o["id"] not in only:
        continue
    sp = o["spec"]
    if o["kind"] == "ttf":
        size, w, wt = fit_ttf(sp)
        render_t = lambda t, sp=sp, size=size: sp.draw(size, t)
        meta = dict(size=size, digit_h=sp.digit_h(size))
    elif isinstance(sp, SevenSeg):
        render_t = lambda t, sp=sp, H=o["H"]: sp.draw(H, t)
        w, wt = widest_drawn(render_t)
        meta = dict(digit_h=o["H"])
    else:
        render_t = lambda t, sp=sp: sp.draw(t)
        w, wt = widest_drawn(render_t)
        meta = dict(digit_h=sp.height())
    imgs = {}
    for t in SHOW + [wt]:
        a, g, base = render_t(t)
        out, clash, right, top = composite(a, g, base, sp.hard)
        imgs[t] = out
        Image.fromarray(out).save(os.path.join(OUT, f"{o['id']}_{t.replace(':', '')}.png"))
    meta.update(widest=int(w), widest_time=wt)
    print(o["id"], o["name"], meta, flush=True)
    results.append(dict(id=o["id"], group=o["group"], name=o["name"], **meta))
json.dump(results, open(os.path.join(OUT, "meta.json" if not only else "meta_partial.json"), "w"), indent=1)

# contact sheet: time area of 10:08 for every option
cells = [(r["id"], np.array(Image.open(os.path.join(OUT, f"{r['id']}_1008.png")))[82:150, 0:180]) for r in results]
cols = 3
sheet = Image.new("RGB", (cols * 190, ((len(cells) + cols - 1) // cols) * 80), "white")
d = ImageDraw.Draw(sheet)
for i, (id, c) in enumerate(cells):
    x, y = (i % cols) * 190, (i // cols) * 80
    sheet.paste(Image.fromarray(c), (x, y + 10)); d.text((x + 2, y), id, fill="red")
sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(OUT, "sheet.png"))


# Memory estimate for the page: summed ink area of the 11 glyphs, relative to
# today's font (a proxy for the bitmap font's size).
def _area(spec, size):
    f = spec.font(size)
    return sum((lambda bb: (bb[2] - bb[0]) * (bb[3] - bb[1]))(f.getbbox(c)) for c in "0123456789:")

if not only:
    sizes = {r["id"]: r.get("size") for r in results}
    base_area = _area(OPTIONS[0]["spec"], sizes["0"])
    mem = {o["id"]: round(100 * _area(o["spec"], sizes[o["id"]]) / base_area)
           for o in OPTIONS if o["kind"] == "ttf"}
    json.dump(mem, open(os.path.join(OUT, "mem.json"), "w"))
