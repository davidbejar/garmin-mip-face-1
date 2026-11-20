"""Shared renderer for design previews: draws candidate time styles onto a
260 px simulator screenshot, snapped to the 64 MIP colours. See README.md."""
import json, os, sys, base64, io
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DL = os.path.join(HERE, "cache")          # candidate fonts (fetch_fonts.sh), git-ignored
DSEG = os.path.join(DL, "dseg/fonts-DSEG_v046")
SYS = os.path.expanduser("~/Library/Application Support/Garmin/ConnectIQ/Fonts")
OUT = os.path.join(HERE, "out")         # renders and pages, git-ignored
os.makedirs(OUT, exist_ok=True)

# A 260 px simulator screenshot of the normal state (store/ is local only;
# override with PREVIEW_BASE=/path/to/screenshot.png).
BASE_PATH = os.environ.get("PREVIEW_BASE", os.path.join(REPO, "store/screenshots/normal.png"))
BASE = np.array(Image.open(BASE_PATH).convert("RGB"))
BG = BASE[120, 8].copy()
FG = np.array([0, 0, 0])
GHOST = np.array([0xAA, 0xAA, 0xAA])
LEVELS = np.array([0, 85, 170, 255])

TIME_X = 14          # left ink edge of today's time (screenshot)
BASELINE = 142       # bottom ink row of today's digits + 1
SIDE_GAP = 5         # last time ink column -> week/seconds column (today 128 -> 133)
WK = BASE[96:104, 133:162].copy()
SEC = BASE[129:143, 133:148].copy()
PANEL_X = 176

TIMES = {"10:08": "10:08", "23:45": "23:45", "16:59": "16:59", "07:28": "07:28"}


def snap(rgb):
    return LEVELS[np.abs(rgb[..., None] - LEVELS).argmin(-1)]


def all_times():
    return [f"{h:02d}:{m:02d}" for h in range(24) for m in range(60)]


# ---------------------------------------------------------------- TTF glyphs
class TTF:
    def __init__(self, path, axes=None, track_em=-0.02, hard=False, ghost=False, cell=False):
        self.path, self.axes, self.track_em, self.hard, self.ghost, self.cell = path, axes, track_em, hard, ghost, cell

    def font(self, size):
        f = ImageFont.truetype(self.path, size)
        if self.axes:
            names = [a["name"] for a in f.get_variation_axes()]
            vals = []
            for a in f.get_variation_axes():
                n = a["name"].decode() if isinstance(a["name"], bytes) else a["name"]
                vals.append(self.axes.get(n, a["default"]))
            f.set_variation_by_axes(vals)
        return f

    def metrics(self, size):
        f = self.font(size)
        m = {}
        for ch in "0123456789:":
            bb = f.getbbox(ch, anchor="ls")
            m[ch] = (f.getlength(ch), bb)
        return f, m

    def layout(self, size, text):
        f, m = self.metrics(size)
        tr = self.track_em * size
        x, pos = 0.0, []
        for ch in text:
            pos.append((ch, round(x)))
            x += m[ch][0] + tr
        left = min(p + m["8" if self.cell else c][1][0] for c, p in pos)
        right = max(p + m["8" if (self.cell and c != ":") else c][1][2] for c, p in pos)
        return f, pos, left, right

    def digit_h(self, size):
        f = self.font(size)
        bb = f.getbbox("8", anchor="ls")
        return bb[3] - bb[1]

    def width(self, size, text):
        _, _, l, r = self.layout(size, text)
        return r - l

    def draw(self, size, text):
        """Return (alpha array, ghost alpha or None) with ink starting at x 0, baseline at row `size*2`."""
        f, pos, left, right = self.layout(size, text)
        W, H = int(right - left) + 4, size * 3
        a = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(a)
        g = None
        if self.ghost:
            g = Image.new("L", (W, H), 0)
            dg = ImageDraw.Draw(g)
        for ch, p in pos:
            if self.ghost:
                dg.text((p - left, size * 2), "8" if ch != ":" else ":", font=f, fill=255, anchor="ls")
            d.text((p - left, size * 2), ch, font=f, fill=255, anchor="ls")
        return np.array(a), (np.array(g) if g else None), size * 2


# ---------------------------------------------------------- drawn in code
SEG = {  # a b c d e f g
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
    "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
}


class SevenSeg:
    """7-segment digits drawn with fillPolygon (no font resource)."""
    def __init__(self, w, t, gap=1, slant=0.0, ghost=False, colon_w=None, pitch=None, ends="hex"):
        self.w, self.t, self.gap, self.slant, self.ghost, self.ends = w, t, gap, slant, ghost, ends
        self.pitch = pitch or (w + max(4, t))
        self.colon_w = colon_w or (t + 2 * max(4, t))
        self.hard = True

    def seg_polys(self, H):
        w, t, g = self.w, self.t, self.gap
        h2 = t / 2
        mid = H / 2
        top, bot = h2, H - h2
        L, R = h2, w - h2
        def hseg(y):
            if self.ends == "hex":
                return [(L + g, y), (L + h2 + g, y - h2), (R - h2 - g, y - h2), (R - g, y), (R - h2 - g, y + h2), (L + h2 + g, y + h2)]
            return [(L + h2 + g, y - h2), (R - h2 - g, y - h2), (R - h2 - g, y + h2), (L + h2 + g, y + h2)]
        def vseg(x, y0, y1):
            if self.ends == "hex":
                return [(x, y0 + g), (x + h2, y0 + h2 + g), (x + h2, y1 - h2 - g), (x, y1 - g), (x - h2, y1 - h2 - g), (x - h2, y0 + h2 + g)]
            return [(x - h2, y0 + h2 + g), (x + h2, y0 + h2 + g), (x + h2, y1 - h2 - g), (x - h2, y1 - h2 - g)]
        return {
            "a": hseg(top), "g": hseg(mid), "d": hseg(bot),
            "f": vseg(L, top, mid), "b": vseg(R, top, mid),
            "e": vseg(L, mid, bot), "c": vseg(R, mid, bot),
        }

    def _sk(self, pts, x0, H, base):
        return [(x0 + x + (H - y) * self.slant, base - H + y) for x, y in pts]

    def layout_w(self, H, text):
        x = 0
        for ch in text:
            x += self.colon_w if ch == ":" else self.pitch
        return x - (self.pitch - self.w) + H * self.slant

    def draw(self, H, text):
        W = int(self.layout_w(H, text)) + 6
        base = H + 4
        a = Image.new("L", (W, H + 8), 0); d = ImageDraw.Draw(a)
        g = Image.new("L", (W, H + 8), 0) if self.ghost else None
        dg = ImageDraw.Draw(g) if g else None
        polys = self.seg_polys(H)
        x = 0.0
        for ch in text:
            if ch == ":":
                cs = self.t + 1
                cx = x + (self.colon_w - cs) / 2
                for cy in (H * 0.30, H * 0.70):
                    pts = [(cx, cy - cs / 2), (cx + cs, cy - cs / 2), (cx + cs, cy + cs / 2), (cx, cy + cs / 2)]
                    d.polygon(self._sk(pts, 0, H, base), fill=255)
                x += self.colon_w
                continue
            for s, pts in polys.items():
                poly = self._sk(pts, x, H, base)
                if s in SEG[ch]:
                    d.polygon(poly, fill=255)
                elif dg is not None:
                    dg.polygon(poly, fill=255)
            x += self.pitch
        arr = np.array(a)
        sl = slice(0, None)
        return arr[:, sl], (np.array(g)[:, sl] if g else None), base


FONT5x7 = {
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
}
FONT4x7 = {  # condensed, so bigger dots fit the width
    "0": [".##.", "#..#", "#..#", "#..#", "#..#", "#..#", ".##."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".##.", "#..#", "...#", "..#.", ".#..", "#...", "####"],
    "3": ["###.", "...#", "...#", ".##.", "...#", "...#", "###."],
    "4": ["..#.", ".##.", "#.#.", "#.#.", "####", "..#.", "..#."],
    "5": ["####", "#...", "###.", "...#", "...#", "#..#", ".##."],
    "6": [".##.", "#...", "#...", "###.", "#..#", "#..#", ".##."],
    "7": ["####", "...#", "..#.", "..#.", ".#..", ".#..", ".#.."],
    "8": [".##.", "#..#", "#..#", ".##.", "#..#", "#..#", ".##."],
    "9": [".##.", "#..#", "#..#", ".###", "...#", "...#", ".##."],
}


class DotMatrix:
    """Digits as a grid of dots drawn with fillCircle / fillRectangle (no font resource)."""
    def __init__(self, glyphs, px, py, dot, shape="round", ghost=False, colon_cols=1, dot_h=None):
        self.gl, self.px, self.py, self.dot, self.shape, self.ghost = glyphs, px, py, dot, shape, ghost
        self.dot_h = dot_h or dot
        self.colon_cols = colon_cols
        self.hard = True

    def cols(self, ch):
        return self.colon_cols if ch == ":" else len(self.gl[ch][0])

    def layout_w(self, text):
        n = sum(self.cols(c) for c in text) + (len(text) - 1)  # one empty column between glyphs
        return (n - 1) * self.px + self.dot

    def height(self):
        return 6 * self.py + self.dot_h

    def draw(self, text):
        W = self.layout_w(text) + 4; H = self.height()
        base = H + 2
        a = Image.new("L", (W, H + 4), 0); d = ImageDraw.Draw(a)
        g = Image.new("L", (W, H + 4), 0) if self.ghost else None
        dg = ImageDraw.Draw(g) if g else None
        col = 0
        def dot(dr, c, r):
            x0, y0 = c * self.px, 2 + r * self.py
            box = [x0, y0, x0 + self.dot - 1, y0 + self.dot_h - 1]
            if self.shape == "round":
                dr.ellipse(box, fill=255)
            else:
                dr.rectangle(box, fill=255)
        for ch in text:
            if ch == ":":
                for r in (2, 4):
                    dot(d, col, r)
            else:
                rows = self.gl[ch]
                for r, line in enumerate(rows):
                    for c, v in enumerate(line):
                        if v == "#":
                            dot(d, col + c, r)
                        elif dg is not None:
                            dot(dg, col + c, r)
            col += self.cols(ch) + 1
        return np.array(a), (np.array(g) if g else None), base


# ------------------------------------------------------------ compositing
def composite(alpha, ghost, base_row, hard, ink_left=TIME_X, baseline=BASELINE):
    img = BASE.astype(float).copy()
    img[86:147, 10:PANEL_X] = BG            # erase old time, week, seconds
    rows, cols = alpha.shape
    y0 = baseline - base_row
    def put(a, colour):
        af = (a >= 128).astype(float) if hard else a / 255.0
        for r in range(rows):
            y = y0 + r
            if not (0 <= y < 260):
                continue
            seg = af[r]
            x1 = min(260, ink_left + cols)
            seg = seg[: x1 - ink_left]
            region = img[y, ink_left:x1]
            img[y, ink_left:x1] = region * (1 - seg[:, None]) + colour * seg[:, None]
    if ghost is not None:
        put(ghost, GHOST)
    put(alpha, FG)
    out = snap(img).astype(np.uint8)
    # restore pixels outside the face disc and the side panel from the base image
    ys, xs = np.mgrid[0:260, 0:260]
    outside = (xs - 129.5) ** 2 + (ys - 129.5) ** 2 > 129 ** 2
    out[outside] = BASE[outside]
    out[:, PANEL_X:] = BASE[:, PANEL_X:]
    # week + seconds column next to the new time
    xs_ink = np.where((alpha >= 128).any(0))[0]
    right = ink_left + xs_ink.max()
    sx = right + SIDE_GAP
    clash = sx + WK.shape[1] > PANEL_X - 2
    sx = min(sx, PANEL_X - 2 - WK.shape[1])
    top = y0 + np.where((alpha >= 128).any(1))[0].min()
    out[top:top + 8, sx:sx + WK.shape[1]] = WK
    out[129:143, sx:sx + SEC.shape[1]] = SEC
    return out, clash, int(right), int(top)


def png_b64(arr):
    b = io.BytesIO(); Image.fromarray(arr).save(b, "PNG", optimize=True)
    return base64.b64encode(b.getvalue()).decode()
