import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Icons drawn in code so their colour is set at draw time (design/spec.md §4).
//! Sizes are on the 260 px spec canvas, measured from the mockup; `s` scales them.
//! The caller sets the colour (two-colour icons take it as arguments). None of these allocate.
module Icons {

    const MOON_SIZE = 12.0;
    const BOLT_W = 7.0;
    const BOLT_H = 10.0;
    const BATTERY_W = 12.0;     // 10 px body + 2 px nub
    const BATTERY_H = 6.0;
    const SUN_W = 12.0;
    const SUN_H = 13.0;

    // Pixel icons traced from the mockup are stored as horizontal runs
    // (row, x, width), flattened into one array to save memory; see drawRuns().

    //! Sun on a 12 x 13 grid: a 6 px disc and eight 2 px rays, with a 1 px gap
    //! between the side rays and the disc so they stay separate on the MIP screen.
    const SUN_RUNS = [
        0, 5, 2,
        1, 5, 2,
        2, 1, 2,  2, 5, 2,  2, 9, 2,
        3, 2, 2,  3, 8, 2,
        4, 4, 4,
        5, 0, 2,  5, 3, 6,  5, 10, 2,
        6, 0, 2,  6, 3, 6,  6, 10, 2,
        7, 0, 2,  7, 3, 6,  7, 10, 2,
        8, 4, 4,
        9, 2, 2,  9, 8, 2,
        10, 1, 2,  10, 5, 2,  10, 9, 2,
        11, 5, 2,
        12, 5, 2
    ] as Array<Number>;

    //! Heart (heart-rate box), 9 x 9: two lobes and a tapered point.
    const HEART_W = 9.0;
    const HEART_RUNS = [
        0, 1, 3,  0, 5, 3,
        1, 0, 9,
        2, 0, 9,
        3, 0, 9,
        4, 0, 9,
        5, 0, 9,
        6, 1, 7,
        7, 2, 5,
        8, 3, 3
    ] as Array<Number>;

    //! Sunrise and sunset, 12 x 11 (not in the mockup; chosen for legibility on
    //! the MIP screen): a triangle (up = sunrise, down = sunset) in the text
    //! colour, a gap, then a solid half-sun in the accent colour on a horizon line.
    const SUN_EVENT_W = 12.0;
    const SUNRISE_ARROW_RUNS = [0, 5, 2,  1, 4, 4,  2, 3, 6,  3, 2, 8] as Array<Number>;
    const SUNSET_ARROW_RUNS = [0, 2, 8,  1, 3, 6,  2, 4, 4,  3, 5, 2] as Array<Number>;
    const HALF_SUN_RUNS = [5, 4, 4,  6, 2, 8,  7, 2, 8,  8, 1, 10,  9, 1, 10] as Array<Number>;
    const HORIZON_RUNS = [10, 0, 12] as Array<Number>;

    //! Bolt outline on a 7 x 10 grid (Body Battery).
    const BOLT_POINTS = [[4.5, 0.0], [4.5, 3.0], [7.0, 3.0], [3.0, 10.0], [3.5, 6.0], [0.0, 6.0]] as Array<Array<Float>>;

    //! Moon: circle outline with the unlit part filled. Lit on the right while waxing.
    //! phase: 0 new, 0.5 full (MoonPhase.phase()).
    function drawMoon(dc as Dc, left as Float, top as Float, s as Float, phase as Float) as Void {
        var r = MOON_SIZE * s / 2;
        var cx = left + r;
        var cy = top + r;
        dc.drawCircle(cx, cy, r);

        // Each pixel row of the disc: the terminator is at x = w * cos(2 pi phase).
        var k = Math.cos(phase * 2 * Math.PI);
        var waxing = phase < 0.5;
        var y0 = top.toNumber();
        var y1 = (top + 2 * r).toNumber();
        for (var y = y0; y < y1; y++) {
            var dy = y + 0.5 - cy;
            var w2 = r * r - dy * dy;
            if (w2 <= 0) {
                continue;
            }
            var w = Math.sqrt(w2);
            var x0 = waxing ? cx - w : cx - w * k;
            var x1 = waxing ? cx + w * k : cx + w;
            var ix0 = (x0 + 0.5).toNumber();
            var ix1 = (x1 + 0.5).toNumber();
            if (ix1 > ix0) {
                dc.fillRectangle(ix0, y, ix1 - ix0, 1);
            }
        }
    }

    //! Bolt (Body Battery). `points` is a caller-owned 6-point array, refilled here
    //! so drawing never allocates.
    function drawBolt(dc as Dc, left as Float, top as Float, s as Float, points as Array<Array<Float>>) as Void {
        for (var i = 0; i < BOLT_POINTS.size(); i++) {
            points[i][0] = left + BOLT_POINTS[i][0] * s;
            points[i][1] = top + BOLT_POINTS[i][1] * s;
        }
        dc.fillPolygon(points as Array<Point2D>);
    }

    //! Watch battery: outlined body, nub on the right, inner fill for the charge (0-1).
    function drawBattery(dc as Dc, left as Float, top as Float, s as Float, charge as Float) as Void {
        var x = (left + 0.5).toNumber();
        var y = (top + 0.5).toNumber();
        var bodyW = (10 * s + 0.5).toNumber();
        var h = (BATTERY_H * s + 0.5).toNumber();
        var two = (2 * s + 0.5).toNumber();

        // 1 px outline; nub and fill sit 2 px in from the edges.
        dc.drawRectangle(x, y, bodyW, h);
        dc.fillRectangle(x + bodyW, y + two, two, h - 2 * two);

        var inner = bodyW - 2 * two;
        var fill = (inner * clamp01(charge) + 0.5).toNumber();
        if (fill > 0) {
            dc.fillRectangle(x + two, y + two, fill, h - 2 * two);
        }
    }

    //! Sun (solar): filled disc and eight short rays.
    function drawSun(dc as Dc, left as Float, top as Float, s as Float) as Void {
        drawRuns(dc, SUN_RUNS, left, top, s);
    }

    function drawHeart(dc as Dc, left as Float, top as Float, s as Float) as Void {
        drawRuns(dc, HEART_RUNS, left, top, s);
    }

    //! Sunrise (rising = true) or sunset. Two colours, so the caller passes them.
    function drawSunEvent(dc as Dc, left as Float, top as Float, s as Float, rising as Boolean,
            ink as Number, accent as Number) as Void {
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        drawRuns(dc, HALF_SUN_RUNS, left, top, s);
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        drawRuns(dc, rising ? SUNRISE_ARROW_RUNS : SUNSET_ARROW_RUNS, left, top, s);
        drawRuns(dc, HORIZON_RUNS, left, top, s);
    }

    //! Draws a run-encoded pixel icon (row, x, width triples), scaled by s.
    function drawRuns(dc as Dc, runs as Array<Number>, left as Float, top as Float, s as Float) as Void {
        for (var i = 0; i < runs.size(); i += 3) {
            var row = runs[i];
            var x = runs[i + 1];
            var w = runs[i + 2];
            var x0 = (left + x * s + 0.5).toNumber();
            var x1 = (left + (x + w) * s + 0.5).toNumber();
            var y0 = (top + row * s + 0.5).toNumber();
            var y1 = (top + (row + 1) * s + 0.5).toNumber();
            dc.fillRectangle(x0, y0, x1 - x0, y1 - y0);
        }
    }

    function clamp01(v as Float) as Float {
        if (v < 0.0) {
            return 0.0;
        }
        if (v > 1.0) {
            return 1.0;
        }
        return v;
    }
}
