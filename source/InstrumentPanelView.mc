import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Instrument panel V4a watch face (design/spec.md).
//!
//! Every layout constant below is in pixels on the 260 x 260 spec canvas.
//! onLayout() scales them by dc.getWidth() / 260 (x) and dc.getHeight() / 260 (y).
//! Text is positioned by its baseline, measured from the mockups.
class InstrumentPanelView extends WatchUi.WatchFace {

    private const SPEC_SIZE = 260.0;

    // Time (§2 row 5). Ink starts at x 16, baseline y 141.
    // The mockup sets the time with -0.02 em letter-spacing (-1.25 px at 64 px).
    private const TIME_X = 16.0;
    private const TIME_BASELINE = 141.0;
    private const TIME_TRACKING = -1.25;

    // Week number and seconds, 3 px right of the time (§2 rows 6-7).
    private const SIDE_GAP = 3.0;
    private const WEEK_BASELINE = 104.0;   // cap tops at y 96, level with the time digits
    private const WEEK_CAP_HEIGHT = 8.0;
    private const SECONDS_BASELINE = 141.0;

    // Date block (§2 row 3): filled box, two centred lines.
    private const DATE_X = 98.0;
    private const DATE_Y = 37.0;
    private const DATE_W = 64.0;
    private const DATE_H = 40.0;
    private const DATE_RADIUS = 7.0;
    private const DATE_LINE1_BASELINE = 59.0;
    private const DATE_LINE1_CAP_HEIGHT = 13.0;
    // Month: Barlow Bold bitmap font, 7 px capitals with hard edges, rows y 64-70
    // (5 px clear above and below). Gaps are whole pixels so they stay even:
    // 2 px, or 1 px when the name would be wider than MAX_WIDTH (SEPTEMBER).
    private const DATE_LINE2_BASELINE = 71.0;
    private const DATE_LINE2_TRACKING = 2.0;
    private const DATE_LINE2_MIN_TRACKING = 1.0;
    private const DATE_LINE2_MAX_WIDTH = 52.0;

    // Cap height as a fraction of getVectorFont's :size. The size is the font's
    // full line height (hhea ascent + descent), not the em: confirmed in the
    // simulator. Values from the TTF metrics:
    //   Bionic SemiBold: cap 643 / (930 + 346) = 0.504
    //   Roboto Condensed Bold: cap 1456 / (1900 + 500) = 0.607
    private const BIONIC_CAP_RATIO = 0.504;
    private const ROBOTO_CONDENSED_CAP_RATIO = 0.607;

    private const MAX_MONTH_LENGTH = 9; // SEPTEMBER

    // Fonts, loaded once in onLayout().
    private var _timeFont as FontType = Graphics.FONT_NUMBER_HOT;
    private var _secondsFont as FontType = Graphics.FONT_TINY;
    private var _weekFont as FontType = Graphics.FONT_XTINY;
    private var _dateLine1Font as FontType = Graphics.FONT_SMALL;
    private var _dateLine2Font as FontType = Graphics.FONT_XTINY;

    // Scale from the spec canvas to the device.
    private var _sx as Float = 1.0;
    private var _sy as Float = 1.0;

    // Layout in device pixels, computed in onLayout().
    private var _timeTop as Number = 0;
    private var _weekTop as Number = 0;
    private var _secondsTop as Number = 0;
    private var _timeTracking as Float = 0.0;
    private var _sideGap as Float = 0.0;
    private var _dateX as Number = 0;
    private var _dateY as Number = 0;
    private var _dateW as Number = 0;
    private var _dateH as Number = 0;
    private var _dateRadius as Number = 0;
    private var _dateCentreX as Float = 0.0;
    private var _dateLine1Top as Number = 0;
    private var _dateLine2Top as Number = 0;
    private var _dateLine2Tracking as Number = 0;
    private var _dateLine2MinTracking as Number = 0;
    private var _dateLine2MaxWidth as Number = 0;

    // Glyph advances of the bitmap fonts, measured once in onLayout().
    private var _timeAdvance as Array<Number> = new Array<Number>[10];
    private var _colonAdvance as Number = 0;
    private var _secondsAdvance as Array<Number> = new Array<Number>[10];

    // Time layout, rebuilt when the minute changes.
    private var _lastMinute as Number = -1;
    private var _timeDigits as Array<Number> = [0, 0, 0, 0];
    private var _timeDigitX as Array<Number> = [0, 0, 0, 0];
    private var _colonX as Number = 0;
    private var _sideX as Number = 0;

    // Date text, rebuilt when the day changes.
    private var _dayKey as Number = -1;
    private var _weekText as String = "";
    private var _dateLine1Text as String = "";
    private var _monthChars as Array<Char> = [] as Array<Char>;
    private var _monthCharX as Array<Number> = new Array<Number>[MAX_MONTH_LENGTH];

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _sx = dc.getWidth() / SPEC_SIZE;
        _sy = dc.getHeight() / SPEC_SIZE;

        // Bitmap fonts are rasterised at the 260 px size (tools/make_fonts.py).
        _timeFont = WatchUi.loadResource(Rez.Fonts.TimeFont) as FontResource;
        _secondsFont = WatchUi.loadResource(Rez.Fonts.SecondsFont) as FontResource;
        _weekFont = vectorFont("BionicSemiBold", WEEK_CAP_HEIGHT / BIONIC_CAP_RATIO, Graphics.FONT_XTINY);
        _dateLine1Font = vectorFont("RobotoCondensedBold", DATE_LINE1_CAP_HEIGHT / ROBOTO_CONDENSED_CAP_RATIO, Graphics.FONT_SMALL);
        _dateLine2Font = WatchUi.loadResource(Rez.Fonts.MonthFont) as FontResource;

        _timeTop = topForBaseline(TIME_BASELINE, _timeFont);
        _weekTop = topForBaseline(WEEK_BASELINE, _weekFont);
        _secondsTop = topForBaseline(SECONDS_BASELINE, _secondsFont);
        _timeTracking = TIME_TRACKING * _sx;
        _sideGap = SIDE_GAP * _sx;

        _dateX = scaleX(DATE_X);
        _dateY = scaleY(DATE_Y);
        _dateW = scaleX(DATE_X + DATE_W) - _dateX;
        _dateH = scaleY(DATE_Y + DATE_H) - _dateY;
        _dateRadius = scaleX(DATE_RADIUS);
        _dateCentreX = (DATE_X + DATE_W / 2) * _sx;
        _dateLine1Top = topForBaseline(DATE_LINE1_BASELINE, _dateLine1Font);
        _dateLine2Top = topForBaseline(DATE_LINE2_BASELINE, _dateLine2Font);
        _dateLine2Tracking = scaleX(DATE_LINE2_TRACKING);
        _dateLine2MinTracking = scaleX(DATE_LINE2_MIN_TRACKING);
        _dateLine2MaxWidth = scaleX(DATE_LINE2_MAX_WIDTH);

        for (var i = 0; i < 10; i++) {
            var digit = i.toString();
            _timeAdvance[i] = dc.getTextWidthInPixels(digit, _timeFont);
            _secondsAdvance[i] = dc.getTextWidthInPixels(digit, _secondsFont);
        }
        _colonAdvance = dc.getTextWidthInPixels(":", _timeFont);

        // Force the cached time and date to rebuild with the new layout.
        _lastMinute = -1;
        _dayKey = -1;
        logMemory("onLayout");
    }

    function onShow() as Void {
        // The time zone may have changed while the face was hidden.
        _lastMinute = -1;
        _dayKey = -1;
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var minute = clock.hour * 60 + clock.min;
        if (minute != _lastMinute) {
            _lastMinute = minute;
            layoutTime(clock.hour, clock.min);
            refreshDate(dc);
            logMemory("minute");
        }

        dc.setColor(Palette.BACKGROUND, Palette.BACKGROUND);
        dc.clear();
        drawDateBlock(dc);
        drawTime(dc, clock.sec);
    }

    // ---- Drawing (no allocation) ----

    private function drawTime(dc as Dc, sec as Number) as Void {
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            dc.drawText(_timeDigitX[i], _timeTop, _timeFont, _timeDigits[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.drawText(_colonX, _timeTop, _timeFont, ":", Graphics.TEXT_JUSTIFY_LEFT);

        dc.drawText(_sideX, _weekTop, _weekFont, _weekText, Graphics.TEXT_JUSTIFY_LEFT);

        var tens = sec / 10;
        dc.drawText(_sideX, _secondsTop, _secondsFont, tens, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_sideX + _secondsAdvance[tens], _secondsTop, _secondsFont, sec % 10, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawDateBlock(dc as Dc) as Void {
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_dateX, _dateY, _dateW, _dateH, _dateRadius);

        dc.setColor(Palette.DATE_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_dateCentreX, _dateLine1Top, _dateLine1Font, _dateLine1Text, Graphics.TEXT_JUSTIFY_CENTER);
        for (var i = 0; i < _monthChars.size(); i++) {
            dc.drawText(_monthCharX[i], _dateLine2Top, _dateLine2Font, _monthChars[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ---- Cached layout (runs once a minute / once a day) ----

    //! Splits HH:MM into digits and places each glyph with the time's tracking.
    //! Always a 24-hour clock, whatever the device's 12/24-hour setting.
    private function layoutTime(hour as Number, min as Number) as Void {
        _timeDigits[0] = hour / 10;
        _timeDigits[1] = hour % 10;
        _timeDigits[2] = min / 10;
        _timeDigits[3] = min % 10;

        var x = TIME_X * _sx;
        for (var i = 0; i < 4; i++) {
            if (i == 2) {
                _colonX = round(x);
                x += _colonAdvance + _timeTracking;
            }
            _timeDigitX[i] = round(x);
            x += _timeAdvance[_timeDigits[i]] + _timeTracking;
        }
        _sideX = round(x + _sideGap);
    }

    //! Rebuilds the date and week text when the calendar day changes.
    private function refreshDate(dc as Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var year = info.year;
        var month = info.month as Number;
        var day = info.day;
        var dow = info.day_of_week as Number;

        var key = (year * 13 + month) * 32 + day;
        if (key == _dayKey) {
            return;
        }
        _dayKey = key;

        _dateLine1Text = DateUtil.DAY_NAMES[dow - 1] + " " + day.toString();
        _weekText = "WK " + DateUtil.isoWeek(year, month, day, DateUtil.isoDayOfWeek(dow)).toString();

        // Month name, letter-spaced and centred in the block.
        // First pass stores each glyph's width, second turns widths into x positions.
        _monthChars = DateUtil.MONTH_NAMES[month - 1].toCharArray();
        var n = _monthChars.size();
        var glyphs = 0;
        for (var i = 0; i < n; i++) {
            _monthCharX[i] = dc.getTextWidthInPixels(_monthChars[i].toString(), _dateLine2Font);
            glyphs += _monthCharX[i];
        }
        // Narrower gaps if the name would be wider than the cap.
        var tracking = _dateLine2Tracking;
        if (glyphs + tracking * (n - 1) > _dateLine2MaxWidth) {
            tracking = _dateLine2MinTracking;
        }
        var x = _dateCentreX - (glyphs + tracking * (n - 1)) / 2;
        for (var i = 0; i < n; i++) {
            var width = _monthCharX[i];
            _monthCharX[i] = round(x);
            x += width + tracking;
        }
    }

    // ---- Helpers ----

    private function vectorFont(face as String, sizeAt260 as Float, fallback as FontDefinition) as FontType {
        var font = Graphics.getVectorFont({:face => face, :size => sizeAt260 * _sy});
        if (font == null) {
            return fallback;
        }
        return font;
    }

    //! Top of the text cell that puts the font's baseline on the given spec y.
    private function topForBaseline(baseline as Float, font as FontType) as Number {
        return scaleY(baseline) - Graphics.getFontAscent(font);
    }

    private function scaleX(v as Float) as Number {
        return round(v * _sx);
    }

    private function scaleY(v as Float) as Number {
        return round(v * _sy);
    }

    private function round(v as Float) as Number {
        return (v + 0.5).toNumber();
    }

    (:debug)
    private function logMemory(tag as String) as Void {
        var stats = System.getSystemStats();
        System.println("mem[" + tag + "] used=" + stats.usedMemory + " free=" + stats.freeMemory + " total=" + stats.totalMemory);
    }

    (:release)
    private function logMemory(tag as String) as Void {
    }
}
