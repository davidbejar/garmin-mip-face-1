import Toybox.Complications;
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

    // ---- Time (§2 rows 5-7) ----

    // Ink starts at x 16, baseline y 141.
    // The mockup sets the time with -0.02 em letter-spacing (-1.25 px at 64 px).
    private const TIME_X = 16.0;
    private const TIME_BASELINE = 141.0;
    private const TIME_TRACKING = -1.25;

    // Week number and seconds, 3 px right of the time.
    private const SIDE_GAP = 3.0;
    private const WEEK_BASELINE = 104.0;   // cap tops at y 96, level with the time digits
    private const WEEK_CAP_HEIGHT = 8.0;
    private const SECONDS_BASELINE = 141.0;

    // ---- Date block (§2 row 3): filled box, two centred lines ----

    private const DATE_X = 98.0;
    private const DATE_Y = 37.0;
    private const DATE_W = 64.0;
    private const DATE_H = 40.0;
    private const DATE_RADIUS = 7.0;
    private const DATE_LINE1_BASELINE = 59.0;
    // Month: Barlow Bold bitmap font, 7 px capitals with hard edges, rows y 64-70
    // (5 px clear above and below). Gaps are whole pixels so they stay even:
    // 2 px, or 1 px when the name would be wider than MAX_WIDTH (SEPTEMBER).
    private const DATE_LINE2_BASELINE = 71.0;
    private const DATE_LINE2_TRACKING = 2.0;
    private const DATE_LINE2_MIN_TRACKING = 1.0;
    private const DATE_LINE2_MAX_WIDTH = 52.0;
    private const MAX_MONTH_LENGTH = 9; // SEPTEMBER

    // ---- Outlined boxes (§2 rows 2, 4, 8, 9): x, y, w, h, corner radius ----

    private const BOXES = [
        [40.0, 39.0, 54.0, 36.0, 7.0],    // moon
        [166.0, 39.0, 54.0, 36.0, 7.0],   // Body Battery
        [176.0, 84.0, 68.0, 62.0, 8.0],   // side panel
        [28.0, 154.0, 204.0, 44.0, 8.0]   // heart rate (content in milestone 4)
    ] as Array<Array<Float>>;
    private const BOX_MOON = 0;
    private const BOX_BODY_BATTERY = 1;
    private const BOX_SIDE = 2;
    private const OUTLINE_WIDTH = 2.0;

    // Box contents, measured from the mockup. Each icon + value row is centred
    // on its box; labels are centred below.
    private const ICON_GAP = 4.0;
    private const BOLT_GAP = 5.0;
    private const BOX_VALUE_BASELINE = 59.0;   // moon percent and Body Battery value
    private const BOX_LABEL_BASELINE = 70.0;
    private const MOON_ICON_TOP = 46.0;
    private const BOLT_TOP = 47.0;
    private const BATTERY_ICON_TOP = 97.0;
    private const BATTERY_DAYS_BASELINE = 108.0;
    private const BAR_X = 186.0;
    private const BAR_Y = 114.0;
    private const BAR_W = 48.0;
    private const BAR_H = 4.0;
    private const SUN_TOP = 126.0;             // 12 x 13 px icon centred on y 132
    private const SOLAR_BASELINE = 138.0;

    // ---- Sun times row (§2 row 1), measured from the mockup ----

    // Sunrise icon + time, 10 px gap, sunset icon + time; centred on the face.
    private const SUN_ROW_CENTRE_X = 130.0;
    private const SUN_ICON_TOP = 16.0;    // 11 px tall icon, horizon on y 26
    private const SUN_TIME_BASELINE = 28.0;
    private const SUN_ICON_GAP = 3.0;    // icon to its time
    private const SUN_PAIR_GAP = 10.0;   // sunrise time to sunset icon

    // Capital height of date line 1 ("MON 16"), a system vector font.
    private const CAP_13 = 13.0;

    // Cap height as a fraction of getVectorFont's :size. The size is the font's
    // full line height (hhea ascent + descent), not the em: confirmed in the
    // simulator. Values from the TTF metrics:
    //   Bionic SemiBold: cap 643 / (930 + 346) = 0.504
    //   Roboto Condensed Bold: cap 1456 / (1900 + 500) = 0.607
    private const BIONIC_CAP_RATIO = 0.504;
    private const ROBOTO_CONDENSED_CAP_RATIO = 0.607;

    // ---- Fonts, loaded once in onLayout() ----

    private var _timeFont as FontType = Graphics.FONT_NUMBER_HOT;
    // Hard-edged Barlow Condensed numbers (tools/make_fonts.py): digit heights 12, 13, 11.
    private var _num12Font as FontType = Graphics.FONT_TINY;   // seconds, moon percent
    private var _num13Font as FontType = Graphics.FONT_SMALL;  // Body Battery, battery days
    private var _num11Font as FontType = Graphics.FONT_TINY;   // solar percent
    private var _sunTimeFont as FontType = Graphics.FONT_TINY; // sunrise and sunset (SemiBold)
    private var _weekFont as FontType = Graphics.FONT_XTINY;
    private var _monthFont as FontType = Graphics.FONT_XTINY;
    private var _labelFont as FontType = Graphics.FONT_XTINY;
    private var _cap13Font as FontType = Graphics.FONT_SMALL;  // date line 1

    // ---- Layout in device pixels, computed in onLayout() ----

    private var _sx as Float = 1.0;
    private var _sy as Float = 1.0;

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

    private var _boxes as Array<Array<Number>> = [] as Array<Array<Number>>;
    private var _outlineWidth as Number = 2;
    private var _boxValueTop as Number = 0;          // moon percent
    private var _bodyBatteryValueTop as Number = 0;  // Body Battery value
    private var _labelTop as Number = 0;
    private var _moonIconTop as Float = 0.0;
    private var _boltTop as Float = 0.0;
    private var _batteryIconTop as Float = 0.0;
    private var _daysTop as Number = 0;
    private var _barX as Number = 0;
    private var _barY as Number = 0;
    private var _barW as Number = 0;
    private var _barH as Number = 0;
    private var _sunTop as Float = 0.0;
    private var _solarTop as Number = 0;

    // Glyph advances of the bitmap fonts, measured once in onLayout().
    private var _timeAdvance as Array<Number> = new Array<Number>[10];
    private var _colonAdvance as Number = 0;
    private var _secondsAdvance as Array<Number> = new Array<Number>[10];

    // Reused by Icons.drawBolt so drawing never allocates.
    private var _boltPoints as Array<Array<Float>> = [] as Array<Array<Float>>;

    // ---- Time layout, rebuilt when the minute changes ----

    private var _lastMinute as Number = -1;
    private var _timeDigits as Array<Number> = [0, 0, 0, 0];
    private var _timeDigitX as Array<Number> = [0, 0, 0, 0];
    private var _colonX as Number = 0;
    private var _sideX as Number = 0;

    // ---- Date text, rebuilt when the day changes ----

    private var _dayKey as Number = -1;
    private var _weekText as String = "";
    private var _dateLine1Text as String = "";
    private var _monthChars as Array<Char> = [] as Array<Char>;
    private var _monthCharX as Array<Number> = new Array<Number>[MAX_MONTH_LENGTH];

    // ---- Box data. Text and row positions are rebuilt only when a value changes ----

    // Moon
    private var _moonPhase as Float = 0.0;
    private var _moonPercent as Number = -1;
    private var _moonText as String = "";
    private var _moonLabel as String = "";
    private var _moonIconX as Float = 0.0;
    private var _moonTextX as Number = 0;

    // Body Battery: complication value, null when unavailable.
    private var _bodyBatteryId as Complications.Id? = null;
    private var _bodyBattery as Number? = null;
    private var _bodyBatteryDirty as Boolean = true;
    private var _bodyBatteryText as String = "--";
    private var _boltX as Float = 0.0;
    private var _bodyBatteryTextX as Number = 0;

    // Sunrise and sunset: complication values in seconds after local midnight.
    private var _sunriseId as Complications.Id? = null;
    private var _sunsetId as Complications.Id? = null;
    private var _sunrise as Number? = null;
    private var _sunset as Number? = null;
    private var _sunTimesDirty as Boolean = true;
    private var _sunriseText as String = "--:--";
    private var _sunsetText as String = "--:--";
    private var _sunriseIconX as Float = 0.0;
    private var _sunriseTextX as Number = 0;
    private var _sunsetIconX as Float = 0.0;
    private var _sunsetTextX as Number = 0;
    private var _sunIconTop as Float = 0.0;
    private var _sunTimeTop as Number = 0;

    // Watch battery and solar
    private var _batteryCharge as Float = 0.0;
    private var _batteryKey as Number = -1;
    private var _batteryText as String = "";
    private var _batteryIconX as Float = 0.0;
    private var _batteryTextX as Number = 0;
    private var _solarKey as Number = -2;
    private var _solarText as String = "--";
    private var _sunX as Float = 0.0;
    private var _solarTextX as Number = 0;

    function initialize() {
        WatchFace.initialize();
        subscribeComplications();
    }

    function onLayout(dc as Dc) as Void {
        _sx = dc.getWidth() / SPEC_SIZE;
        _sy = dc.getHeight() / SPEC_SIZE;

        // Bitmap fonts are rasterised at the 260 px size (tools/make_fonts.py).
        _timeFont = WatchUi.loadResource(Rez.Fonts.TimeFont) as FontResource;
        _num12Font = WatchUi.loadResource(Rez.Fonts.Num12Font) as FontResource;
        _num13Font = WatchUi.loadResource(Rez.Fonts.Num13Font) as FontResource;
        _num11Font = WatchUi.loadResource(Rez.Fonts.Num11Font) as FontResource;
        _sunTimeFont = WatchUi.loadResource(Rez.Fonts.SunTimeFont) as FontResource;
        _monthFont = WatchUi.loadResource(Rez.Fonts.MonthFont) as FontResource;
        _labelFont = WatchUi.loadResource(Rez.Fonts.LabelFont) as FontResource;
        _weekFont = vectorFont("BionicSemiBold", WEEK_CAP_HEIGHT / BIONIC_CAP_RATIO, Graphics.FONT_XTINY);
        _cap13Font = vectorFont("RobotoCondensedBold", CAP_13 / ROBOTO_CONDENSED_CAP_RATIO, Graphics.FONT_SMALL);

        // Time
        _timeTop = topForBaseline(TIME_BASELINE, _timeFont);
        _weekTop = topForBaseline(WEEK_BASELINE, _weekFont);
        _secondsTop = topForBaseline(SECONDS_BASELINE, _num12Font);
        _timeTracking = TIME_TRACKING * _sx;
        _sideGap = SIDE_GAP * _sx;
        for (var i = 0; i < 10; i++) {
            var digit = i.toString();
            _timeAdvance[i] = dc.getTextWidthInPixels(digit, _timeFont);
            _secondsAdvance[i] = dc.getTextWidthInPixels(digit, _num12Font);
        }
        _colonAdvance = dc.getTextWidthInPixels(":", _timeFont);

        // Date block
        _dateX = scaleX(DATE_X);
        _dateY = scaleY(DATE_Y);
        _dateW = scaleX(DATE_X + DATE_W) - _dateX;
        _dateH = scaleY(DATE_Y + DATE_H) - _dateY;
        _dateRadius = scaleX(DATE_RADIUS);
        _dateCentreX = (DATE_X + DATE_W / 2) * _sx;
        _dateLine1Top = topForBaseline(DATE_LINE1_BASELINE, _cap13Font);
        _dateLine2Top = topForBaseline(DATE_LINE2_BASELINE, _monthFont);
        _dateLine2Tracking = scaleX(DATE_LINE2_TRACKING);
        _dateLine2MinTracking = scaleX(DATE_LINE2_MIN_TRACKING);
        _dateLine2MaxWidth = scaleX(DATE_LINE2_MAX_WIDTH);

        // Outlined boxes
        _boxes = new Array<Array<Number>>[BOXES.size()];
        for (var i = 0; i < BOXES.size(); i++) {
            var b = BOXES[i];
            var x = scaleX(b[0]);
            var y = scaleY(b[1]);
            _boxes[i] = [x, y, scaleX(b[0] + b[2]) - x, scaleY(b[1] + b[3]) - y, scaleX(b[4])];
        }
        _outlineWidth = scaleX(OUTLINE_WIDTH);
        if (_outlineWidth < 1) {
            _outlineWidth = 1;
        }

        // Box contents
        _boxValueTop = topForBaseline(BOX_VALUE_BASELINE, _num12Font);
        _bodyBatteryValueTop = topForBaseline(BOX_VALUE_BASELINE, _num13Font);
        _labelTop = topForBaseline(BOX_LABEL_BASELINE, _labelFont);
        _moonIconTop = MOON_ICON_TOP * _sy;
        _boltTop = BOLT_TOP * _sy;
        _batteryIconTop = BATTERY_ICON_TOP * _sy;
        _daysTop = topForBaseline(BATTERY_DAYS_BASELINE, _num13Font);
        _barX = scaleX(BAR_X);
        _barY = scaleY(BAR_Y);
        _barW = scaleX(BAR_X + BAR_W) - _barX;
        _barH = scaleY(BAR_Y + BAR_H) - _barY;
        _sunTop = SUN_TOP * _sy;
        _solarTop = topForBaseline(SOLAR_BASELINE, _num11Font);
        _sunIconTop = SUN_ICON_TOP * _sy;
        _sunTimeTop = topForBaseline(SUN_TIME_BASELINE, _sunTimeFont);

        _boltPoints = new Array<Array<Float>>[Icons.BOLT_POINTS.size()];
        for (var i = 0; i < _boltPoints.size(); i++) {
            _boltPoints[i] = [0.0, 0.0];
        }

        invalidateCaches();
        logMemory("onLayout");
    }

    function onShow() as Void {
        // The time zone may have changed while the face was hidden.
        invalidateCaches();
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var minute = clock.hour * 60 + clock.min;
        if (minute != _lastMinute) {
            _lastMinute = minute;
            var now = Time.now();
            layoutTime(clock.hour, clock.min);
            refreshDate(dc, now);
            refreshMoon(dc, now);
            refreshBattery(dc);
            logMemory("minute");
        }
        if (_bodyBatteryDirty) {
            refreshBodyBattery(dc);
        }
        if (_sunTimesDirty) {
            refreshSunTimes(dc);
        }

        dc.setColor(Palette.BACKGROUND, Palette.BACKGROUND);
        dc.clear();
        drawSunTimes(dc);
        drawDateBlock(dc);
        drawBoxOutlines(dc);
        drawMoonBox(dc);
        drawBodyBatteryBox(dc);
        drawSidePanel(dc);
        drawTime(dc, clock.sec);
    }

    //! Complication callback: store the new value; its text is rebuilt on the next update.
    function onComplicationChanged(id as Complications.Id) as Void {
        if (id.equals(_bodyBatteryId)) {
            _bodyBattery = readComplication(_bodyBatteryId);
            _bodyBatteryDirty = true;
        } else if (id.equals(_sunriseId)) {
            _sunrise = readComplication(_sunriseId);
            _sunTimesDirty = true;
        } else if (id.equals(_sunsetId)) {
            _sunset = readComplication(_sunsetId);
            _sunTimesDirty = true;
        }
    }

    // ---- Drawing (no allocation) ----

    private function drawSunTimes(dc as Dc) as Void {
        Icons.drawSunEvent(dc, _sunriseIconX, _sunIconTop, _sx, true, Palette.TEXT, Palette.ACCENT);
        Icons.drawSunEvent(dc, _sunsetIconX, _sunIconTop, _sx, false, Palette.TEXT, Palette.ACCENT);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sunriseTextX, _sunTimeTop, _sunTimeFont, _sunriseText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_sunsetTextX, _sunTimeTop, _sunTimeFont, _sunsetText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawTime(dc as Dc, sec as Number) as Void {
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            dc.drawText(_timeDigitX[i], _timeTop, _timeFont, _timeDigits[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.drawText(_colonX, _timeTop, _timeFont, ":", Graphics.TEXT_JUSTIFY_LEFT);

        dc.drawText(_sideX, _weekTop, _weekFont, _weekText, Graphics.TEXT_JUSTIFY_LEFT);

        var tens = sec / 10;
        dc.drawText(_sideX, _secondsTop, _num12Font, tens, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_sideX + _secondsAdvance[tens], _secondsTop, _num12Font, sec % 10, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawDateBlock(dc as Dc) as Void {
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_dateX, _dateY, _dateW, _dateH, _dateRadius);

        dc.setColor(Palette.DATE_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_dateCentreX, _dateLine1Top, _cap13Font, _dateLine1Text, Graphics.TEXT_JUSTIFY_CENTER);
        for (var i = 0; i < _monthChars.size(); i++) {
            dc.drawText(_monthCharX[i], _dateLine2Top, _monthFont, _monthChars[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    //! 2 px outlines, drawn as nested 1 px rounded rectangles inside the spec box.
    private function drawBoxOutlines(dc as Dc) as Void {
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _boxes.size(); i++) {
            var b = _boxes[i];
            for (var k = 0; k < _outlineWidth; k++) {
                dc.drawRoundedRectangle(b[0] + k, b[1] + k, b[2] - 2 * k, b[3] - 2 * k, b[4] - k);
            }
        }
    }

    private function drawMoonBox(dc as Dc) as Void {
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        Icons.drawMoon(dc, _moonIconX, _moonIconTop, _sx, _moonPhase);
        dc.drawText(_moonTextX, _boxValueTop, _num12Font, _moonText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Palette.LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(boxCentreX(BOX_MOON), _labelTop, _labelFont, _moonLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawBodyBatteryBox(dc as Dc) as Void {
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        Icons.drawBolt(dc, _boltX, _boltTop, _sx, _boltPoints);
        dc.drawText(_bodyBatteryTextX, _bodyBatteryValueTop, _num13Font, _bodyBatteryText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Palette.LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(boxCentreX(BOX_BODY_BATTERY), _labelTop, _labelFont, "BODY BAT", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSidePanel(dc as Dc) as Void {
        // Battery: icon and days
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        Icons.drawBattery(dc, _batteryIconX, _batteryIconTop, _sx, _batteryCharge);
        dc.drawText(_batteryTextX, _daysTop, _num13Font, _batteryText, Graphics.TEXT_JUSTIFY_LEFT);

        // Charge bar: grey track, fill clipped from the left so its right end is square.
        var radius = _barH / 2;
        dc.setColor(Palette.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_barX, _barY, _barW, _barH, radius);
        var fill = (_barW * _batteryCharge + 0.5).toNumber();
        if (fill > 0) {
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.setClip(_barX, _barY, fill, _barH);
            dc.fillRoundedRectangle(_barX, _barY, _barW, _barH, radius);
            dc.clearClip();
        }

        // Solar
        dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
        Icons.drawSun(dc, _sunX, _sunTop, _sx);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_solarTextX, _solarTop, _num11Font, _solarText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ---- Cached layout and data (runs once a minute / when a value changes) ----

    private function invalidateCaches() as Void {
        _lastMinute = -1;
        _dayKey = -1;
        _moonPercent = -1;
        _batteryKey = -1;
        _solarKey = -2;
        _bodyBatteryDirty = true;
        _sunTimesDirty = true;
    }

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
    private function refreshDate(dc as Dc, now as Time.Moment) as Void {
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
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
            _monthCharX[i] = dc.getTextWidthInPixels(_monthChars[i].toString(), _monthFont);
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

    private function refreshMoon(dc as Dc, now as Time.Moment) as Void {
        _moonPhase = MoonPhase.phase(now.value());
        _moonLabel = MoonPhase.LABELS[MoonPhase.label(_moonPhase)];
        var percent = MoonPhase.percentLit(_moonPhase);
        if (percent != _moonPercent) {
            _moonPercent = percent;
            _moonText = percent.toString() + "%";
            _moonIconX = rowLeft(dc, BOX_MOON, Icons.MOON_SIZE, ICON_GAP, _moonText, _num12Font);
            _moonTextX = round(_moonIconX + (Icons.MOON_SIZE + ICON_GAP) * _sx);
        }
    }

    //! Battery days (fallback: percent) and solar intensity (§7).
    private function refreshBattery(dc as Dc) as Void {
        var stats = System.getSystemStats();
        _batteryCharge = Icons.clamp01(stats.battery / 100.0);

        // Key: days, or 1000 + percent when the device has no days estimate.
        var key = 1000 + stats.battery.toNumber();
        if (stats has :batteryInDays) {
            key = stats.batteryInDays.toNumber();
        }
        if (key != _batteryKey) {
            _batteryKey = key;
            _batteryText = (key < 1000) ? key.toString() + "d" : (key - 1000).toString() + "%";
            _batteryIconX = rowLeft(dc, BOX_SIDE, Icons.BATTERY_W, ICON_GAP, _batteryText, _num13Font);
            _batteryTextX = round(_batteryIconX + (Icons.BATTERY_W + ICON_GAP) * _sx);
        }

        // Key: -1 when there is no solar sensor; negative intensity (not charging) shows 0%.
        var solar = stats.solarIntensity;
        var solarKey = -1;
        if (solar != null) {
            solarKey = (solar < 0) ? 0 : solar;
        }
        if (solarKey != _solarKey) {
            _solarKey = solarKey;
            _solarText = (solarKey < 0) ? "--" : solarKey.toString() + "%";
            _sunX = rowLeft(dc, BOX_SIDE, Icons.SUN_W, ICON_GAP, _solarText, _num11Font);
            _solarTextX = round(_sunX + (Icons.SUN_W + ICON_GAP) * _sx);
        }
    }

    private function refreshBodyBattery(dc as Dc) as Void {
        _bodyBatteryDirty = false;
        var value = _bodyBattery;
        _bodyBatteryText = (value == null) ? "--" : value.toString();
        _boltX = rowLeft(dc, BOX_BODY_BATTERY, Icons.BOLT_W, BOLT_GAP, _bodyBatteryText, _num13Font);
        _bodyBatteryTextX = round(_boltX + (Icons.BOLT_W + BOLT_GAP) * _sx);
    }

    //! Places "icon time  icon time" centred on the face (§2 row 1).
    private function refreshSunTimes(dc as Dc) as Void {
        _sunTimesDirty = false;
        _sunriseText = formatTimeOfDay(_sunrise);
        _sunsetText = formatTimeOfDay(_sunset);

        var icon = Icons.SUN_EVENT_W * _sx;
        var gap = SUN_ICON_GAP * _sx;
        var riseW = dc.getTextWidthInPixels(_sunriseText, _sunTimeFont);
        var setW = dc.getTextWidthInPixels(_sunsetText, _sunTimeFont);
        var total = 2 * (icon + gap) + riseW + SUN_PAIR_GAP * _sx + setW;

        var x = SUN_ROW_CENTRE_X * _sx - total / 2;
        _sunriseIconX = x;
        x += icon + gap;
        _sunriseTextX = round(x);
        x += riseW + SUN_PAIR_GAP * _sx;
        _sunsetIconX = x;
        x += icon + gap;
        _sunsetTextX = round(x);
    }

    //! Seconds after local midnight as 24-hour HH:MM, or "--:--".
    private function formatTimeOfDay(seconds as Number?) as String {
        if (seconds == null) {
            return "--:--";
        }
        var hour = (seconds / 3600) % 24;
        var min = (seconds % 3600) / 60;
        return hour.format("%02d") + ":" + min.format("%02d");
    }

    // ---- Complications: Body Battery, sunrise, sunset ----

    private function subscribeComplications() as Void {
        try {
            Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
        } catch (e) {
            return;
        }
        _bodyBatteryId = subscribe(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        _sunriseId = subscribe(Complications.COMPLICATION_TYPE_SUNRISE);
        _sunsetId = subscribe(Complications.COMPLICATION_TYPE_SUNSET);
        _bodyBattery = readComplication(_bodyBatteryId);
        _sunrise = readComplication(_sunriseId);
        _sunset = readComplication(_sunsetId);
    }

    private function subscribe(type as Complications.Type) as Complications.Id? {
        try {
            var id = new Complications.Id(type);
            Complications.subscribeToUpdates(id);
            return id;
        } catch (e) {
            return null;
        }
    }

    //! Current value as a whole number, or null when unavailable.
    private function readComplication(id as Complications.Id?) as Number? {
        if (id == null) {
            return null;
        }
        try {
            var v = Complications.getComplication(id).value;
            if (v instanceof Number) {
                return v;
            }
            if (v instanceof Float) {
                return v.toNumber();
            }
        } catch (e) {
        }
        return null;
    }

    // ---- Helpers ----

    //! Left x of an icon + gap + text row centred on a box. Sizes on the spec canvas.
    private function rowLeft(dc as Dc, box as Number, iconW as Float, gap as Float, text as String, font as FontType) as Float {
        var width = (iconW + gap) * _sx + dc.getTextWidthInPixels(text, font);
        return boxCentreX(box) - width / 2;
    }

    private function boxCentreX(box as Number) as Float {
        var b = BOXES[box];
        return (b[0] + b[2] / 2) * _sx;
    }

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
    }}
