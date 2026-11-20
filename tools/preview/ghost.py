import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import *
from PIL import ImageDraw

G = dict(FONT5x7)
G["1"] = ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", "#####"]   # wide foot, as in the reference

class Dots:
    """5x7 grid of round dots. Fractional pitch allowed; AA draws at 8x and downsamples (fillCircle with setAntiAlias)."""
    def __init__(self, px, py, d, aa, colon_d, gap_cols=1.0, colon_gap=1.0):
        self.px, self.py, self.d, self.aa, self.cd = px, py, d, aa, colon_d
        self.gap_cols, self.colon_gap = gap_cols, colon_gap
        self.hard = not aa
    def height(self): return round(6 * self.py + self.d)
    def draw(self, text):
        k = 8 if self.aa else 1
        W, H = 200, self.height() + 4
        im = Image.new("L", (W * k, H * k), 0); dr = ImageDraw.Draw(im)
        def dot(cx, cy, dd):
            if self.aa:
                r = dd / 2 * k
                dr.ellipse([cx * k - r, cy * k - r, cx * k + r - 1, cy * k + r - 1], fill=255)
            else:
                x0 = round(cx - dd / 2); y0 = round(cy - dd / 2)
                dr.ellipse([x0, y0, x0 + dd - 1, y0 + dd - 1], fill=255)
        x = self.d / 2
        for i, ch in enumerate(text):
            if ch == ":":
                x += (self.colon_gap - 1) * self.px
                for r in (2.2, 4.8):
                    dot(x, 2 + self.d / 2 + r * self.py, self.cd)
                x += (self.colon_gap + 1) * self.px
                continue
            for r, line in enumerate(G[ch]):
                for c, v in enumerate(line):
                    if v == "#":
                        dot(x + c * self.px, 2 + self.d / 2 + r * self.py, self.d)
            x += (4 + 1 + self.gap_cols) * self.px
        if self.aa:
            im = im.resize((W, H), Image.BOX)
        a = np.array(im)
        return a, None, self.height() + 2

V = {
 "C5": ("5×7 like the reference, hard edges", Dots(5, 5, 5, False, 3)),
 "C6": ("5×7 like the reference, smooth dots", Dots(5.5, 5.5, 5.6, True, 3.6, 0.5, 0.6)),
 "C7": ("5×7, taller rows, smooth dots", Dots(5.5, 6.6, 5.8, True, 3.6, 0.5, 0.6)),
}
res = []
for id, (name, sp) in V.items():
    best = (0, None)
    for t in all_times():
        a = sp.draw(t)[0]; xs = np.where((a >= 128).any(0))[0]
        if xs.max() + 1 > best[0]: best = (xs.max() + 1, t)
    for t in ["10:08", "23:45", "16:59", "07:28", best[1]]:
        a, g, base = sp.draw(t)
        xs = np.where(a.any(0))[0]; a = a[:, xs.min():]
        out, clash, right, top = composite(a, g, base, sp.hard)
        Image.fromarray(out).save(os.path.join(OUT, f"{id}_{t.replace(':','')}.png"))
    res.append(dict(id=id, group="dots", name=name, digit_h=sp.height(), widest=int(best[0]), widest_time=best[1]))
    print(res[-1])
json.dump(res, open(os.path.join(OUT, "meta_ghost.json"), "w"), indent=1)
ims = [Image.open(os.path.join(OUT, f"{i}_1008.png")).crop((0, 80, 180, 150)) for i in V]
c = Image.new("RGB", (540, 70)); [c.paste(im, (k * 180, 0)) for k, im in enumerate(ims)]
c.resize((1620, 210), Image.NEAREST).save(os.path.join(OUT, "ghost_sheet.png"))
