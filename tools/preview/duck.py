"""Rubber-duck proposals: every '2' in the time is replaced by a duck drawn in the 2's own box."""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import *
from PIL import ImageDraw, ImageFilter

K = 8                         # supersampling for smooth (anti-aliased) shapes
BAND_X0, BAND_Y0, BAND_W, BAND_H = 10, 84, 166, 64   # face coords of the time band
BASE_ROW = BASELINE - BAND_Y0                         # baseline inside the band
YELLOW = np.array([0xFF, 0xFF, 0x00])
ORANGE = np.array([0xFF, 0x55, 0x00])
WHITE = BG.astype(float)
R = os.path.join(REPO, "tools/fonts")

# ---------------------------------------------------------------- the fonts
G57 = {
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
}


def ttf_layout(path, size, track_em, text, axes=None):
    """Per-character (char, x, ink box) for a TTF at `size`, ink starting at x 0."""
    sp = TTF(path, axes=axes, track_em=track_em)
    f, m = sp.metrics(size)
    tr = track_em * size
    x, pos = 0.0, []
    for ch in text:
        pos.append((ch, round(x)))
        x += m[ch][0] + tr
    left = min(p + m[c][1][0] for c, p in pos)
    out = []
    for ch, p in pos:
        bb = m[ch][1]
        out.append((ch, p - left, bb))
    return f, out, left


class Font:
    """Draws the time into a band, leaving each '2' cell empty, and returns the cells."""
    def __init__(self, id, name):
        self.id, self.name = id, name


class TTFFont(Font):
    def __init__(self, id, name, path, size, track_em, digit_h, axes=None):
        super().__init__(id, name)
        self.path, self.size, self.track_em, self.H, self.axes = path, size, track_em, digit_h, axes
        self.smooth = True
        self.slant = 0.0

    def draw(self, text):
        f, items, left = ttf_layout(self.path, self.size, self.track_em, text, self.axes)
        a = Image.new("L", (BAND_W, BAND_H), 0); d = ImageDraw.Draw(a)
        cells = []
        for ch, x, bb in items:
            if ch == "2":
                cells.append((x + bb[0], bb[2] - bb[0]))
            else:
                d.text((x, BASE_ROW), ch, font=f, fill=255, anchor="ls")
        return np.array(a) / 255.0, cells


class SegFont(Font):
    def __init__(self, id, name, seg, H):
        super().__init__(id, name)
        self.seg, self.H, self.smooth, self.slant = seg, H, False, seg.slant

    def draw(self, text):
        s = self.seg
        a = Image.new("L", (BAND_W, BAND_H), 0); d = ImageDraw.Draw(a)
        polys = s.seg_polys(self.H)
        x, cells = 0.0, []
        for ch in text:
            if ch == ":":
                cs = s.t + 1
                cx = x + (s.colon_w - cs) / 2
                for cy in (self.H * 0.30, self.H * 0.70):
                    pts = [(cx, cy - cs / 2), (cx + cs, cy - cs / 2), (cx + cs, cy + cs / 2), (cx, cy + cs / 2)]
                    d.polygon(s._sk(pts, 0, self.H, BASE_ROW), fill=255)
                x += s.colon_w
                continue
            if ch == "2":
                cells.append((x, s.w))
            else:
                for sg, pts in polys.items():
                    if sg in SEG[ch]:
                        d.polygon(s._sk(pts, x, self.H, BASE_ROW), fill=255)
            x += s.pitch
        return (np.array(a) >= 128).astype(float), cells


class DotFont(Font):
    def __init__(self, id, name, px, py, dd, gap_cols, colon_gap, colon_d):
        super().__init__(id, name)
        self.px, self.py, self.dd, self.gc, self.cg, self.cd = px, py, dd, gap_cols, colon_gap, colon_d
        self.H = round(6 * py + dd)
        self.smooth, self.slant = True, 0.0

    def grid_cells(self, text):
        x, out = self.dd / 2, []
        for ch in text:
            if ch == ":":
                x += (self.cg - 1) * self.px
                out.append((ch, x))
                x += (self.cg + 1) * self.px
            else:
                out.append((ch, x))
                x += (5 + self.gc) * self.px
        return out

    def dot_centre(self, x, c, r):
        top = BASE_ROW - self.H
        return x + c * self.px, top + self.dd / 2 + r * self.py

    def draw(self, text, pattern=None):
        im = Image.new("L", (BAND_W * K, BAND_H * K), 0); d = ImageDraw.Draw(im)
        def dot(cx, cy, dd):
            r = dd / 2 * K
            d.ellipse([cx * K - r, cy * K - r, cx * K + r - 1, cy * K + r - 1], fill=255)
        cells = []
        for ch, x in self.grid_cells(text):
            if ch == ":":
                for r in (2.2, 4.8):
                    dot(*self.dot_centre(x, 0, r), self.cd)
                continue
            rows = G57[ch]
            if ch == "2":
                cells.append((x - self.dd / 2, 4 * self.px + self.dd))
                if pattern is None:
                    continue
                rows = pattern
            for r, line in enumerate(rows):
                for c, v in enumerate(line):
                    if v == "#":
                        dot(*self.dot_centre(x, c, r), self.dd)
        a = np.array(im.resize((BAND_W, BAND_H), Image.BOX)) / 255.0
        return a, cells


FONTS = [
    TTFFont("0", "Barlow Condensed SemiBold (today)", os.path.join(R, "BarlowCondensed-SemiBold.ttf"), 64, -1.25 / 64, 47),
    TTFFont("A6", "Saira Condensed ExtraBold", os.path.join(R, "SairaCondensed-ExtraBold.ttf"), 60, -0.02, 41),
    SegFont("B4", "Casio-style LCD", SevenSeg(w=23, t=5, gap=1, slant=0.10, pitch=28, colon_w=12), 47),
    DotFont("C7", "Dot matrix", 5.5, 6.6, 5.8, 0.5, 0.6, 3.6),
    TTFFont("D2", "Kalam Bold", os.path.join(R, "Kalam-Bold.ttf"), 48, 0.0, 35),
]

# ------------------------------------------------------------------ ducks
# Unit coordinates: x from 0 (beak tip, left) to 1 (tail, right) across the 2's width;
# y measured up from the baseline in the same unit. Every part is a circle or polygon,
# so on the watch each is one fillCircle / fillPolygon call.
def classic():
    return dict(
        head=(0.42, 0.70, 0.22),
        beak=[(0.24, 0.73), (0.02, 0.69), (0.0, 0.63), (0.10, 0.60), (0.26, 0.62)],
        body=[(0.24, 0.50), (0.08, 0.38), (0.06, 0.22), (0.16, 0.08), (0.34, 0.0), (0.66, 0.0),
              (0.86, 0.06), (0.97, 0.22), (1.0, 0.56), (0.88, 0.47), (0.72, 0.47), (0.60, 0.52)],
        eye=(0.37, 0.75, 0.055),
        wing=[(0.40, 0.30), (0.56, 0.20), (0.78, 0.26)],
    )


def bighead():
    return dict(
        head=(0.46, 1.02, 0.33),
        beak=[(0.22, 1.02), (0.02, 0.96), (0.0, 0.88), (0.10, 0.84), (0.26, 0.86)],
        body=[(0.24, 0.70), (0.06, 0.52), (0.04, 0.30), (0.14, 0.10), (0.32, 0.0), (0.66, 0.0),
              (0.86, 0.06), (0.97, 0.24), (1.0, 0.66), (0.88, 0.57), (0.74, 0.58), (0.64, 0.70)],
        eye=(0.38, 1.10, 0.07),
        wing=[(0.36, 0.40), (0.56, 0.24), (0.82, 0.32)],
    )


OUTLINE_PX = 1.3


def _body(hb, y0):
    """Rubber-duck body: chest bulge at the front (left), tail rising at the back."""
    f = [(0.24, 1.0), (0.07, 0.80), (0.03, 0.52), (0.10, 0.20), (0.30, 0.0), (0.68, 0.0),
         (0.88, 0.09), (0.97, 0.34), (1.0, 0.96), (0.88, 0.80), (0.74, 0.84), (0.64, 1.0)]
    return [(x, y0 + y * hb) for x, y in f]


def tall_upright(R, w):
    """Head on top, body stretched to fill the rest of the digit height."""
    m = OUTLINE_PX / w
    r = 0.40
    hx, hy = 0.52, R - m - r
    hb = hy - 0.12 - m              # body overlaps the lower part of the head
    return dict(
        head=(hx, hy, r),
        beak=[(hx - r + 0.06, hy + 0.02), (0.02, hy - 0.04), (0.0, hy - 0.13), (0.10, hy - 0.17), (hx - r + 0.10, hy - 0.15)],
        body=_body(hb, m),
        eye=(hx - 0.10, hy + 0.08, 0.075),
        wing=[(0.36, m + hb * 0.50), (0.56, m + hb * 0.32), (0.84, m + hb * 0.42)],
    )


def tall_neck(R, w, body_max=1.15, r=0.38, neck_half=0.16):
    """Round head on a taller body; a thin neck only when the cell is taller than head + body.
    R is digit height / duck width. The duck with its outline is exactly the digit height."""
    m = OUTLINE_PX / w
    hx, hy = 0.50, R - m - r
    head_bottom = hy - r
    hb = min(body_max, head_bottom - m + 0.08)      # body top tucks slightly under the head
    body = _body(hb, m)
    d = dict(head=(hx, hy, r),
        beak=[(hx - r + 0.06, hy + 0.02), (0.02, hy - 0.03), (0.0, hy - 0.12), (0.10, hy - 0.16), (hx - r + 0.10, hy - 0.14)],
        body=body, eye=(hx - 0.11, hy + 0.08, 0.08),
        wing=[(0.36, m + hb * 0.50), (0.56, m + hb * 0.30), (0.84, m + hb * 0.42)])
    if m + hb < head_bottom + 0.04:
        top = m + hb - 0.06
        d["neck"] = [(hx - neck_half - 0.02, top), (hx - neck_half, hy - r * 0.6), (hx + neck_half, hy - r * 0.6), (hx + neck_half + 0.02, top)]
    return d


def tall_body(R, w):
    return tall_neck(R, w, body_max=1.35)


tall_neck.tall = tall_body.tall = tall_upright.tall = True


class Painter:
    """Paints shapes into the band at K x supersampling, then blends by coverage."""
    def __init__(self, band, smooth):
        self.band, self.smooth = band, smooth

    def blank(self):
        return Image.new("L", (BAND_W * K, BAND_H * K), 0)

    def blend(self, mask_img, colour):
        a = np.array(mask_img.resize((BAND_W, BAND_H), Image.BOX)) / 255.0
        if not self.smooth:
            a = (a >= 0.5).astype(float)
        self.band[:] = self.band * (1 - a[..., None]) + colour * a[..., None]
        return a


def to_px(cell, slant, pts):
    x0, w = cell
    return [((x0 + x * w + slant * y * w) * K, (BASE_ROW - y * w) * K) for x, y in pts]


def circle_pts(cx, cy, r, n=24):
    return [(cx + r * np.cos(t), cy + r * np.sin(t)) for t in np.linspace(0, 2 * np.pi, n, endpoint=False)]


def draw_duck(painter, cell, slant, shape, style, fg):
    S = shape
    def poly(img, pts, grow=0.0):
        d = ImageDraw.Draw(img)
        if grow:
            # crude outward offset: scale the polygon around its centroid
            c = np.mean(pts, axis=0)
            pts = [tuple(c + (np.array(p) - c) * (1 + grow)) for p in pts]
        d.polygon(to_px(cell, slant, pts), fill=255)
    def circ(img, cx, cy, r):
        d = ImageDraw.Draw(img)
        d.polygon(to_px(cell, slant, circle_pts(cx, cy, r, 48)), fill=255)
    def line(img, pts, width_px):
        d = ImageDraw.Draw(img)
        d.line(to_px(cell, slant, pts), fill=255, width=max(1, round(width_px * K)), joint="curve")

    w = cell[1]
    hx, hy, hr = S["head"]
    if style in ("silhouette", "angular"):
        m = painter.blank()
        if style == "angular":   # LCD look: octagonal head, straight facets, 1 px gaps between parts
            poly(m, circle_pts(hx, hy, hr, 8))
            poly(m, S["body"][::2] + [S["body"][-1]])
            poly(m, S["beak"])
            g = None
        else:
            circ(m, hx, hy, hr); poly(m, S["body"]); poly(m, S["beak"])
            g = None
        painter.blend(m, fg)
        k = painter.blank()
        ex, ey, er = S["eye"]
        er = max(er, 1.1 / w)
        if style == "angular":
            s = er * 1.2
            poly(k, [(ex - s, ey - s), (ex + s, ey - s), (ex + s, ey + s), (ex - s, ey + s)])
        else:
            circ(k, ex, ey, er)
        line(k, S["wing"], 1.0)
        if g is not None:
            painter.blend(g, WHITE)
        painter.blend(k, WHITE)
    elif style == "yellow":
        o = painter.blank()            # text-colour outline: the shape grown by ~1.3 px
        grow_px = 1.3
        circ(o, hx, hy, hr + grow_px / w)
        line(o, S["body"] + [S["body"][0]], 2 * grow_px)
        if "neck" in S:
            line(o, S["neck"] + [S["neck"][0]], 2 * grow_px); poly(o, S["neck"])
        poly(o, S["body"]); poly(o, S["beak"], 0.12)
        painter.blend(o, fg)
        y = painter.blank(); circ(y, hx, hy, hr); poly(y, S["body"])
        if "neck" in S:
            poly(y, S["neck"])
        painter.blend(y, YELLOW)
        b = painter.blank(); poly(b, S["beak"])
        painter.blend(b, ORANGE)
        e = painter.blank(); ex, ey, er = S["eye"]; circ(e, ex, ey, max(er, 1.1 / w))
        painter.blend(e, fg)
        wg = painter.blank(); line(wg, S["wing"], 1.0)
        painter.blend(wg, fg)
    elif style == "doodle":           # pen outline, as if drawn with the Kalam pen
        pen = 3.2
        o = painter.blank()
        circ(o, hx, hy, hr); poly(o, S["body"])
        inner = painter.blank()
        circ(inner, hx, hy, hr - pen / w);
        c = np.mean(S["body"], axis=0)
        # body interior: shrink toward centroid by the pen width
        sx = 1 - pen / (w * 0.9); sy = 1 - pen / (w * 0.6)
        poly(inner, [(c[0] + (x - c[0]) * sx, c[1] + (y - c[1]) * sy) for x, y in S["body"]])
        oa = np.array(o).astype(int) - np.array(inner).astype(int)
        painter.blend(Image.fromarray(np.clip(oa, 0, 255).astype(np.uint8)), fg)
        b = painter.blank(); poly(b, S["beak"]); painter.blend(b, fg)
        e = painter.blank(); ex, ey, er = S["eye"]; circ(e, ex, ey, max(er * 1.2, 1.4 / w)); painter.blend(e, fg)
        wg = painter.blank(); line(wg, S["wing"], 2.2); painter.blend(wg, fg)


DUCK_DOTS = {   # 5 x 7, facing left: head with an eye gap, beak, body, raised tail
    "dots": [".##..", "#.#..", "###..", ".#..#", ".####", "#####", ".###."],
}


def fine_dot_duck(font, painter, cell, fg):
    x0, w = cell
    S = bighead()
    m = painter.blank(); d = ImageDraw.Draw(m)
    # silhouette mask at K x (no slant)
    hx, hy, hr = S["head"]
    d.polygon(to_px(cell, 0, circle_pts(hx, hy, hr, 48)), fill=255)
    d.polygon(to_px(cell, 0, S["body"]), fill=255)
    d.polygon(to_px(cell, 0, S["beak"]), fill=255)
    ex, ey, er = S["eye"]
    d.polygon(to_px(cell, 0, circle_pts(ex, ey, er * 1.6, 24)), fill=0)
    mask = np.array(m)
    px, py, dd = font.px / 2, font.py / 2, font.px / 2 * 1.08
    dots = painter.blank(); dr = ImageDraw.Draw(dots)
    ncols = int(round((w - dd) / px)) + 1
    top = BASE_ROW - font.H
    for r in range(13):
        for c in range(ncols):
            cx, cy = x0 + dd / 2 + c * px, top + dd / 2 + r * py
            if 0 <= int(cy * K) < mask.shape[0] and mask[int(cy * K), int(cx * K)]:
                rr = dd / 2 * K
                dr.ellipse([cx * K - rr, cy * K - rr, cx * K + rr - 1, cy * K + rr - 1], fill=255)
    painter.blend(dots, fg)


def render(font, text, design):
    """design: (shape_fn or None, style)."""
    shape_fn, style = design
    band = np.tile(WHITE, (BAND_H, BAND_W, 1)).astype(float)
    if style == "dots":
        a, cells = font.draw(text, pattern=DUCK_DOTS["dots"])
    else:
        a, cells = font.draw(text)
    if not font.smooth:
        a = (a >= 0.5).astype(float)
    band = band * (1 - a[..., None]) + FG * a[..., None]
    inset = 2.0 if font.id == "D2" else 1.0
    cells = [(x + inset, w - inset) for x, w in cells]
    p = Painter(band, font.smooth)
    if style == "finedots":
        for cell in cells:
            fine_dot_duck(font, p, cell, FG.astype(float))
    elif style != "dots":
        for cell in cells:
            shape = shape_fn(font.H / cell[1], cell[1]) if getattr(shape_fn, "tall", False) else shape_fn()
            draw_duck(p, cell, font.slant, shape, style, FG.astype(float))
    band = p.band
    ink = (np.abs(band - WHITE).sum(-1) > 60)
    # face
    img = BASE.astype(float).copy()
    img[86:147, 10:PANEL_X] = BG
    x0 = TIME_X
    img[BAND_Y0:BAND_Y0 + BAND_H, x0:x0 + BAND_W] = band[:, : 260 - x0][:, :BAND_W]
    out = snap(img).astype(np.uint8)
    ys, xs = np.mgrid[0:260, 0:260]
    outside = (xs - 129.5) ** 2 + (ys - 129.5) ** 2 > 129 ** 2
    out[outside] = BASE[outside]
    out[:, PANEL_X:] = BASE[:, PANEL_X:]
    right = x0 + np.where(ink.any(0))[0].max()
    sx = min(right + SIDE_GAP, PANEL_X - 2 - WK.shape[1])
    top = BASELINE - font.H
    out[top:top + 8, sx:sx + WK.shape[1]] = WK
    out[129:143, sx:sx + SEC.shape[1]] = SEC
    return out


DESIGNS = {
    "classic": (classic, "silhouette"),
    "bighead": (bighead, "silhouette"),
    "yellow": (bighead, "yellow"),
    "angular": (bighead, "angular"),
    "dots": (None, "dots"),
    "finedots": (None, "finedots"),
    "tallup": (tall_upright, "yellow"),
    "tallneck": (tall_neck, "yellow"),
    "tallbody": (tall_body, "yellow"),
    "doodle": (bighead, "doodle"),
}

if __name__ == "__main__":
    texts = sys.argv[1:] or ["12:25", "22:22", "20:42", "10:08"]
    rows = []
    for dz, (fn, st) in DESIGNS.items():
        row = []
        for f in FONTS:
            if st in ("dots", "finedots") and f.id != "C7":
                continue
            if st == "angular" and f.id != "B4":
                continue
            if st == "doodle" and f.id != "D2":
                continue
            for t in texts:
                out = render(f, t, (fn, st))
                Image.fromarray(out).save(os.path.join(OUT, f"duck_{dz}_{f.id}_{t.replace(':', '')}.png"))
                row.append(out[82:150, 0:180])
        rows.append(row)
    W = max(len(r) for r in rows)
    sheet = Image.new("RGB", (W * 180, len(rows) * 68), "white")
    for i, r in enumerate(rows):
        for j, c in enumerate(r):
            sheet.paste(Image.fromarray(c), (j * 180, i * 68))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(OUT, "duck_sheet.png"))
    print("ok")
