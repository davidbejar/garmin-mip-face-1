import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! Hours and minutes (design/spec.md §2 row 5) in the time font chosen in the
//! settings, with rubber duck mode. Owner's choices of 2026-11-20; the previews
//! they were picked from are rendered by tools/preview.
//!
//! - Classic, Bold, Handwritten: bitmap fonts (tools/make_fonts.py). Only the
//!   chosen one is loaded.
//! - LCD: Casio-style 7-segment digits, slanted, drawn with fillPolygon.
//! - Dot matrix: 5x7 grid of round anti-aliased dots, drawn with fillCircle.
//! - Rubber duck mode: every 2 becomes a yellow rubber duck with an orange beak,
//!   outlined in the text colour, as tall as the digits and no wider than the 2.
//!
//! Every style fits the box the classic time uses: digits at most 47 px tall
//! and the widest time at most 127 px wide, so the week number and seconds to
//! its right always clear the side panel.
//!
//! All shapes are built in configure() (layout or settings change). draw()
//! only shifts precomputed points into reused scratch arrays: no allocation.
class TimeDisplay {

    // ---- Spec canvas (260 px) ----

    private const TIME_X = 16.0;        // left edge of the time
    private const BASELINE = 141.0;

    // Bitmap styles, from the generated .fnt files: tracking, and the 2's ink
    // box (xoffset, width) for the duck. Indexed by Settings.TIME_*; unused
    // entries (LCD, dots) are 0.
    private const TRACKING = [-1.25, -1.2, 0.0, 0.0, 0.0] as Array<Float>;
    private const TWO_XOFF = [1.0, 1.0, 0.0, 0.0, 0.0] as Array<Float>;
    private const TWO_W = [25.0, 25.0, 0.0, 0.0, 27.0] as Array<Float>;
    // Digit height per style: the duck's height and the week number's top.
    // Kalam: 44 px, its glyphs narrowed to fit the width (owner's choice H2, 2026-11-21).
    private const DIGIT_H = [47.0, 41.0, 47.0, 45.4, 44.0] as Array<Float>;
    // The duck sits 1 px inside the 2's box on the left (2 px for Kalam, whose
    // 1 leans into the next glyph), so it never touches its neighbour.
    private const DUCK_INSET = [1.0, 1.0, 1.0, 1.0, 2.0] as Array<Float>;

    // LCD: digit cell width, stroke, gap between segments, slant, cell pitch, colon cell.
    private const SEG_W = 23.0;
    private const SEG_T = 5.0;
    private const SEG_GAP = 1.0;
    private const SEG_SLANT = 0.10;
    private const SEG_PITCH = 28.0;
    private const SEG_COLON_W = 12.0;
    //! Segments a-g as bits 0-6, per digit.
    private const SEG_MASK = [63, 6, 91, 79, 102, 109, 125, 7, 127, 111] as Array<Number>;

    // Dot matrix: pitch across and down, dot diameter, gap between digits (in
    // columns), colon spacing (in columns) and colon dot diameter.
    private const DOT_PX = 5.5;
    private const DOT_PY = 6.6;
    private const DOT_D = 5.8;
    private const DOT_GAP_COLS = 0.5;
    private const DOT_COLON_GAP = 0.6;
    private const DOT_COLON_D = 3.6;
    //! 5x7 glyphs, 7 rows per digit (flat, to save objects): one 5-bit row per
    //! entry, top row first, bit 4 = left column. Slashed zero and a
    //! wide-footed 1, after the BRAZEN "GHOSTLINE" face.
    private const DOT_GLYPHS = [
        14, 17, 19, 21, 25, 17, 14,   // 0
        4, 12, 4, 4, 4, 4, 31,        // 1
        14, 17, 1, 2, 4, 8, 31,       // 2
        31, 2, 4, 2, 1, 17, 14,       // 3
        2, 6, 10, 18, 31, 2, 2,       // 4
        31, 16, 30, 1, 1, 17, 14,     // 5
        6, 8, 16, 30, 17, 17, 14,     // 6
        31, 1, 2, 4, 8, 8, 8,         // 7
        14, 17, 17, 14, 17, 17, 14,   // 8
        14, 17, 17, 15, 1, 2, 12      // 9
    ] as Array<Number>;

    // Duck (option B): unit x runs 0-1 across the duck's width, facing left;
    // unit y runs up from the baseline in the same unit.
    private const DUCK_OUTLINE = 1.3;   // px, in the text colour
    private const DUCK_HEAD_R = 0.38;
    private const DUCK_BODY_MAX = 1.35;
    //! Body outline as x, y pairs; y is a fraction of the body height.
    private const DUCK_BODY = [
        0.24, 1.0, 0.07, 0.80, 0.03, 0.52, 0.10, 0.20, 0.30, 0.0, 0.68, 0.0,
        0.88, 0.09, 0.97, 0.34, 1.0, 0.96, 0.88, 0.80, 0.74, 0.84, 0.64, 1.0
    ] as Array<Float>;
    private const DUCK_YELLOW = 0xFFFF00;
    private const DUCK_ORANGE = 0xFF5500;

    // ---- State ----

    private var _style as Number = Settings.TIME_CLASSIC;
    private var _duck as Boolean = false;
    private var _sx as Float = 1.0;
    private var _sy as Float = 1.0;
    private var _aa as Boolean = false;      // dc.setAntiAlias available

    private var _font as FontResource? = null;
    private var _fontTop as Number = 0;
    private var _measured as Boolean = false;
    private var _advance as Array<Float> = new Array<Float>[10];
    private var _colonAdvance as Float = 0.0;

    // Layout of the current minute.
    private var _digits as Array<Number> = [0, 0, 0, 0];
    private var _x as Array<Float> = [0.0, 0.0, 0.0, 0.0];   // glyph origin or cell left
    private var _colonX as Float = 0.0;
    private var _endX as Float = 0.0;
    private var _baseY as Float = 0.0;

    // LCD templates, relative to the cell's bottom-left: 7 segments + 2 colon squares.
    private var _segs as Array<Array<Array<Float>>> = [] as Array<Array<Array<Float>>>;
    private var _colonSquares as Array<Array<Array<Float>>> = [] as Array<Array<Array<Float>>>;

    // Duck templates, in px relative to the duck's left edge on the baseline.
    private var _duckDx as Float = 0.0;        // glyph origin (or cell left) to duck left
    private var _duckBody as Array<Array<Float>> = [] as Array<Array<Float>>;
    private var _duckBodyOut as Array<Array<Float>> = [] as Array<Array<Float>>;
    private var _duckNeck as Array<Array<Float>>? = null;
    private var _duckNeckOut as Array<Array<Float>>? = null;
    private var _duckBeak as Array<Array<Float>> = [] as Array<Array<Float>>;
    private var _duckBeakOut as Array<Array<Float>> = [] as Array<Array<Float>>;
    private var _duckWing as Array<Array<Float>> = [] as Array<Array<Float>>;
    private var _duckHead as Array<Float> = [0.0, 0.0, 0.0, 0.0];   // x, y, r, outlined r
    private var _duckEye as Array<Float> = [0.0, 0.0, 0.0];

    // Scratch point arrays, refilled before each fillPolygon.
    private var _p4 as Array<Array<Float>>;
    private var _p5 as Array<Array<Float>>;
    private var _p6 as Array<Array<Float>>;
    private var _p12 as Array<Array<Float>>;

    function initialize() {
        _p4 = points(4);
        _p5 = points(5);
        _p6 = points(6);
        _p12 = points(12);
    }

    //! Applies the time-font and rubber-duck settings at the given scale.
    //! Called from onLayout() (with its dc, to measure the font) and when a
    //! setting changes (dc null: measured on the next layout), never from onUpdate().
    function configure(dc as Dc?, style as Number, duck as Boolean, sx as Float, sy as Float, aa as Boolean) as Void {
        _style = style;
        _duck = duck;
        _sx = sx;
        _sy = sy;
        _aa = aa;
        _baseY = BASELINE * sy;

        // Only the chosen bitmap font stays in memory.
        _font = null;
        var font = null;
        if (style == Settings.TIME_CLASSIC) {
            font = WatchUi.loadResource(Rez.Fonts.TimeFont) as FontResource;
        } else if (style == Settings.TIME_BOLD) {
            font = WatchUi.loadResource(Rez.Fonts.TimeSairaFont) as FontResource;
        } else if (style == Settings.TIME_HAND) {
            font = WatchUi.loadResource(Rez.Fonts.TimeKalamFont) as FontResource;
        }
        _font = font;
        _measured = false;
        if (font != null) {
            _fontTop = (_baseY + 0.5).toNumber() - Graphics.getFontAscent(font);
            if (dc != null) {
                measure(dc);
            }
        }

        _segs = [] as Array<Array<Array<Float>>>;
        _colonSquares = [] as Array<Array<Array<Float>>>;
        if (style == Settings.TIME_LCD) {
            buildSegments();
        }
        if (duck) {
            buildDuck();
        }
    }

    //! Digit height on the spec canvas: the week number's top lines up with it.
    function digitHeight() as Float {
        return DIGIT_H[_style];
    }

    //! Right end of the time (after the last glyph's advance), for the week
    //! number and seconds column.
    function endX() as Float {
        return _endX;
    }

    //! Places the digits of HH:MM. Always 24-hour. Runs once a minute.
    function layout(dc as Dc, hour as Number, min as Number) as Void {
        _digits[0] = hour / 10;
        _digits[1] = hour % 10;
        _digits[2] = min / 10;
        _digits[3] = min % 10;

        var x = TIME_X * _sx;
        if (_style == Settings.TIME_LCD) {
            var pitch = SEG_PITCH * _sx;
            for (var i = 0; i < 4; i++) {
                if (i == 2) {
                    _colonX = x;
                    x += SEG_COLON_W * _sx;
                }
                _x[i] = x;
                x += pitch;
            }
            // Ink right of the last cell (its top is shifted by the slant), plus 1 px
            // so the gap to the week number matches the bitmap fonts' side bearing.
            _endX = _x[3] + (SEG_W + DIGIT_H[_style] * SEG_SLANT + 1.0) * _sx;
        } else if (_style == Settings.TIME_DOTS) {
            // c: centre of the first dot column of the next glyph.
            var px = DOT_PX * _sx;
            var half = DOT_D / 2 * _sx;
            var c = x + half;
            for (var i = 0; i < 4; i++) {
                if (i == 2) {
                    c += (DOT_COLON_GAP - 1) * px;
                    _colonX = c;
                    c += (DOT_COLON_GAP + 1) * px;
                }
                _x[i] = c - half;   // cell left
                c += (5 + DOT_GAP_COLS) * px;
            }
            _endX = _x[3] + (4 * DOT_PX + DOT_D + 1.0) * _sx;
        } else {
            measure(dc);
            var tracking = TRACKING[_style] * _sx;
            for (var i = 0; i < 4; i++) {
                if (i == 2) {
                    _colonX = x;
                    x += _colonAdvance + tracking;
                }
                _x[i] = x;
                x += _advance[_digits[i]] + tracking;
            }
            _endX = x;
        }
    }

    function draw(dc as Dc, ink as Number) as Void {
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        if (_style == Settings.TIME_LCD) {
            drawSegments(dc);
        } else if (_style == Settings.TIME_DOTS) {
            drawDots(dc);
        } else {
            var font = _font as FontResource;
            for (var i = 0; i < 4; i++) {
                if (!(_duck && _digits[i] == 2)) {
                    dc.drawText(round(_x[i]), _fontTop, font, _digits[i], Graphics.TEXT_JUSTIFY_LEFT);
                }
            }
            dc.drawText(round(_colonX), _fontTop, font, ":", Graphics.TEXT_JUSTIFY_LEFT);
        }

        if (_duck) {
            // Smooth edges, except with the hard-edged LCD segments.
            var smooth = _aa && _style != Settings.TIME_LCD;
            if (smooth) {
                dc.setAntiAlias(true);
            }
            for (var i = 0; i < 4; i++) {
                if (_digits[i] == 2) {
                    drawDuck(dc, _x[i] + _duckDx, ink);
                }
            }
            if (smooth) {
                dc.setAntiAlias(false);
            }
        }
    }

    // ---- Drawing ----

    private function drawSegments(dc as Dc) as Void {
        var y = _baseY;
        for (var i = 0; i < 4; i++) {
            var d = _digits[i];
            if (_duck && d == 2) {
                continue;
            }
            var mask = SEG_MASK[d];
            for (var s = 0; s < 7; s++) {
                if ((mask & (1 << s)) != 0) {
                    fillShifted(dc, _segs[s], _p6, _x[i], y);
                }
            }
        }
        for (var k = 0; k < 2; k++) {
            fillShifted(dc, _colonSquares[k], _p4, _colonX, y);
        }
    }

    private function drawDots(dc as Dc) as Void {
        if (_aa) {
            dc.setAntiAlias(true);
        }
        var px = DOT_PX * _sx;
        var py = DOT_PY * _sy;
        var r = DOT_D / 2 * _sx;
        var top = _baseY - DIGIT_H[_style] * _sy + r;   // first row's dot centres
        for (var i = 0; i < 4; i++) {
            var d = _digits[i];
            if (_duck && d == 2) {
                continue;
            }
            var left = _x[i] + r;
            for (var row = 0; row < 7; row++) {
                var bits = DOT_GLYPHS[7 * d + row];
                for (var col = 0; col < 5; col++) {
                    if ((bits & (16 >> col)) != 0) {
                        dc.fillCircle(left + col * px, top + row * py, r);
                    }
                }
            }
        }
        var cr = DOT_COLON_D / 2 * _sx;
        dc.fillCircle(_colonX, top + 2.2 * py, cr);
        dc.fillCircle(_colonX, top + 4.8 * py, cr);
        if (_aa) {
            dc.setAntiAlias(false);
        }
    }

    //! Outline, yellow body and head, orange beak, then eye and wing in the text colour.
    private function drawDuck(dc as Dc, x as Float, ink as Number) as Void {
        var y = _baseY;
        var head = _duckHead;
        var neck = _duckNeck;
        var neckOut = _duckNeckOut;

        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + head[0], y + head[1], head[3]);
        fillShifted(dc, _duckBodyOut, _p12, x, y);
        if (neckOut != null) {
            fillShifted(dc, neckOut, _p4, x, y);
        }
        fillShifted(dc, _duckBeakOut, _p5, x, y);

        dc.setColor(DUCK_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + head[0], y + head[1], head[2]);
        fillShifted(dc, _duckBody, _p12, x, y);
        if (neck != null) {
            fillShifted(dc, neck, _p4, x, y);
        }

        dc.setColor(DUCK_ORANGE, Graphics.COLOR_TRANSPARENT);
        fillShifted(dc, _duckBeak, _p5, x, y);

        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + _duckEye[0], y + _duckEye[1], _duckEye[2]);
        dc.setPenWidth(1);
        var w = _duckWing;
        dc.drawLine(x + w[0][0], y + w[0][1], x + w[1][0], y + w[1][1]);
        dc.drawLine(x + w[1][0], y + w[1][1], x + w[2][0], y + w[2][1]);
    }

    private function fillShifted(dc as Dc, template as Array<Array<Float>>, scratch as Array<Array<Float>>, x as Float, y as Float) as Void {
        for (var k = 0; k < template.size(); k++) {
            scratch[k][0] = x + template[k][0];
            scratch[k][1] = y + template[k][1];
        }
        dc.fillPolygon(scratch as Array<Point2D>);
    }

    // ---- Precomputed shapes (configure() only) ----

    //! Glyph advances of the bitmap font, measured once after configure().
    private function measure(dc as Dc) as Void {
        if (_measured) {
            return;
        }
        var font = _font as FontResource;
        for (var i = 0; i < 10; i++) {
            _advance[i] = dc.getTextWidthInPixels(i.toString(), font).toFloat();
        }
        _colonAdvance = dc.getTextWidthInPixels(":", font).toFloat();
        _measured = true;
    }

    //! Hexagonal segments for a cell of SEG_W x digit height, slanted to the right.
    private function buildSegments() as Void {
        var h = DIGIT_H[Settings.TIME_LCD];
        var t = SEG_T;
        var g = SEG_GAP;
        var h2 = t / 2;
        var mid = h / 2;
        var top = h2;
        var bot = h - h2;
        var l = h2;
        var r = SEG_W - h2;

        _segs = [
            hSeg(top, l, r, h2, g, h),        // a
            vSeg(r, top, mid, h2, g, h),      // b
            vSeg(r, mid, bot, h2, g, h),      // c
            hSeg(bot, l, r, h2, g, h),        // d
            vSeg(l, mid, bot, h2, g, h),      // e
            vSeg(l, top, mid, h2, g, h),      // f
            hSeg(mid, l, r, h2, g, h)         // g
        ] as Array<Array<Array<Float>>>;

        var cs = t + 1;
        var cx = (SEG_COLON_W - cs) / 2;
        _colonSquares = [] as Array<Array<Array<Float>>>;
        var centres = [h * 0.30, h * 0.70] as Array<Float>;
        for (var k = 0; k < 2; k++) {
            var cy = centres[k];
            _colonSquares.add(segPoints([
                cx, cy - cs / 2, cx + cs, cy - cs / 2, cx + cs, cy + cs / 2, cx, cy + cs / 2
            ] as Array<Float>, h));
        }
    }

    private function hSeg(y as Float, l as Float, r as Float, h2 as Float, g as Float, h as Float) as Array<Array<Float>> {
        return segPoints([
            l + g, y, l + h2 + g, y - h2, r - h2 - g, y - h2,
            r - g, y, r - h2 - g, y + h2, l + h2 + g, y + h2
        ] as Array<Float>, h);
    }

    private function vSeg(x as Float, y0 as Float, y1 as Float, h2 as Float, g as Float, h as Float) as Array<Array<Float>> {
        return segPoints([
            x, y0 + g, x + h2, y0 + h2 + g, x + h2, y1 - h2 - g,
            x, y1 - g, x - h2, y1 - h2 - g, x - h2, y0 + h2 + g
        ] as Array<Float>, h);
    }

    //! Cell coordinates (y down from the cell top) to px relative to the cell's
    //! bottom-left on the baseline, slanted: the top leans right.
    private function segPoints(xy as Array<Float>, h as Float) as Array<Array<Float>> {
        var n = xy.size() / 2;
        var out = new Array<Array<Float>>[n];
        for (var k = 0; k < n; k++) {
            var x = xy[2 * k];
            var y = xy[2 * k + 1];
            out[k] = [(x + (h - y) * SEG_SLANT) * _sx, (y - h) * _sy];
        }
        return out;
    }

    //! The duck for this style's 2 box (option B: round head, tallest body,
    //! a thin neck only when the digits are taller than head plus body).
    private function buildDuck() as Void {
        var style = _style;
        var inset = DUCK_INSET[style];
        var w = 0.0;   // duck width, spec px
        if (style == Settings.TIME_LCD) {
            w = SEG_W - inset;
            _duckDx = inset * _sx;
        } else if (style == Settings.TIME_DOTS) {
            w = 4 * DOT_PX + DOT_D - inset;
            _duckDx = inset * _sx;
        } else {
            w = TWO_W[style] - inset;
            _duckDx = (TWO_XOFF[style] + inset) * _sx;
        }
        var slant = style == Settings.TIME_LCD ? SEG_SLANT : 0.0;
        var rh = DIGIT_H[style] / w;
        var m = DUCK_OUTLINE / w;
        var r = DUCK_HEAD_R;
        var hx = 0.50;
        var hy = rh - m - r;
        var headBottom = hy - r;
        var hb = headBottom - m + 0.08;
        if (hb > DUCK_BODY_MAX) {
            hb = DUCK_BODY_MAX;
        }

        var n = DUCK_BODY.size();
        var body = new Array<Float>[n];
        for (var k = 0; k < n; k += 2) {
            body[k] = DUCK_BODY[k];
            body[k + 1] = m + DUCK_BODY[k + 1] * hb;
        }
        _duckBody = duckPoints(body, w, slant);
        _duckBodyOut = grow(_duckBody, DUCK_OUTLINE);

        _duckNeck = null;
        _duckNeckOut = null;
        if (m + hb < headBottom + 0.04) {
            var nt = m + hb - 0.06;
            var neck = duckPoints([
                hx - 0.18, nt, hx - 0.16, hy - r * 0.6, hx + 0.16, hy - r * 0.6, hx + 0.18, nt
            ] as Array<Float>, w, slant);
            _duckNeck = neck;
            _duckNeckOut = grow(neck, DUCK_OUTLINE);
        }

        _duckBeak = duckPoints([
            hx - r + 0.06, hy + 0.02, 0.02, hy - 0.03, 0.0, hy - 0.12,
            0.10, hy - 0.16, hx - r + 0.10, hy - 0.14
        ] as Array<Float>, w, slant);
        _duckBeakOut = scaleAboutCentre(_duckBeak, 1.12);

        _duckWing = duckPoints([
            0.36, m + hb * 0.50, 0.56, m + hb * 0.30, 0.84, m + hb * 0.42
        ] as Array<Float>, w, slant);

        var head = duckPoints([hx, hy] as Array<Float>, w, slant)[0];
        var hr = r * w * _sx;
        _duckHead = [head[0], head[1], hr, hr + DUCK_OUTLINE * _sx];

        var eye = duckPoints([hx - 0.11, hy + 0.08] as Array<Float>, w, slant)[0];
        var er = 0.08 * w;
        if (er < 1.1) {
            er = 1.1;
        }
        _duckEye = [eye[0], eye[1], er * _sx];
    }

    //! Duck units to px relative to the duck's left edge on the baseline.
    private function duckPoints(xy as Array<Float>, w as Float, slant as Float) as Array<Array<Float>> {
        var n = xy.size() / 2;
        var out = new Array<Array<Float>>[n];
        for (var k = 0; k < n; k++) {
            var x = xy[2 * k];
            var y = xy[2 * k + 1];
            out[k] = [(x + slant * y) * w * _sx, -y * w * _sy];
        }
        return out;
    }

    //! The polygon offset outward by d px (mitred, miter capped at 2 d).
    private function grow(pts as Array<Array<Float>>, d as Float) as Array<Array<Float>> {
        var n = pts.size();
        var area = 0.0;
        for (var k = 0; k < n; k++) {
            var a = pts[k];
            var b = pts[(k + 1) % n];
            area += a[0] * b[1] - b[0] * a[1];
        }
        // Outward normal of edge (dx, dy): (dy, -dx) for a positive area in
        // screen coordinates (y down), (-dy, dx) otherwise.
        var sign = area > 0 ? 1.0 : -1.0;
        var dd = d * _sx;
        var out = new Array<Array<Float>>[n];
        for (var k = 0; k < n; k++) {
            var p0 = pts[(k + n - 1) % n];
            var p1 = pts[k];
            var p2 = pts[(k + 1) % n];
            var n1 = unitNormal(p0, p1, sign);
            var n2 = unitNormal(p1, p2, sign);
            var bx = n1[0] + n2[0];
            var by = n1[1] + n2[1];
            var len = Math.sqrt(bx * bx + by * by).toFloat();
            if (len < 0.001) {
                bx = n1[0];
                by = n1[1];
                len = 1.0;
            }
            bx /= len;
            by /= len;
            var cos = bx * n1[0] + by * n1[1];
            if (cos < 0.5) {
                cos = 0.5;
            }
            out[k] = [p1[0] + bx * dd / cos, p1[1] + by * dd / cos];
        }
        return out;
    }

    private function unitNormal(a as Array<Float>, b as Array<Float>, sign as Float) as Array<Float> {
        var dx = b[0] - a[0];
        var dy = b[1] - a[1];
        var len = Math.sqrt(dx * dx + dy * dy).toFloat();
        if (len < 0.001) {
            return [0.0, 0.0];
        }
        return [sign * dy / len, -sign * dx / len];
    }

    private function scaleAboutCentre(pts as Array<Array<Float>>, f as Float) as Array<Array<Float>> {
        var cx = 0.0;
        var cy = 0.0;
        var n = pts.size();
        for (var k = 0; k < n; k++) {
            cx += pts[k][0];
            cy += pts[k][1];
        }
        cx /= n;
        cy /= n;
        var out = new Array<Array<Float>>[n];
        for (var k = 0; k < n; k++) {
            out[k] = [cx + (pts[k][0] - cx) * f, cy + (pts[k][1] - cy) * f];
        }
        return out;
    }

    private function points(n as Number) as Array<Array<Float>> {
        var out = new Array<Array<Float>>[n];
        for (var k = 0; k < n; k++) {
            out[k] = [0.0, 0.0];
        }
        return out;
    }

    private function round(v as Float) as Number {
        return (v + 0.5).toNumber();
    }
}
