import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
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
    // Week number in the hard-edged label font (7 px capitals, owner's choice):
    // the mockup's 11 px text is 30-31 px wide, which runs into the side panel
    // at wide times such as 04:44; this is 27-28 px and always clears it.
    private const WEEK_BASELINE = 103.0;   // cap tops at y 96, level with the time digits
    private const SECONDS_BASELINE = 141.0;
    private const SECONDS_DIGIT_H = 12.0;   // num12 font

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

    // ---- Heart-rate box (§2 row 9), measured from the mockup ----

    // Left column at fixed positions (heart and label at the mockup's x 39,
    // number at x 53) so nothing moves when the rate goes from 2 to 3 digits.
    private const HEART_X = 39.0;
    private const HEART_TOP = 166.0;
    private const HR_VALUE_X = 53.0;
    private const HR_LABEL_X = 39.0;
    private const HR_VALUE_BASELINE = 179.0;
    private const HR_LABEL_BASELINE = 191.0;
    // Bar graph, right- and bottom-aligned inside the padding:
    // right 232 - 2 px outline - 8 px padding = 222; bottom 198 - 2 - 6 = 190.
    private const GRAPH_RIGHT = 222.0;
    private const GRAPH_BOTTOM = 190.0;
    private const GRAPH_BAR_W = 3.0;
    private const GRAPH_BAR_PITCH = 5.0;   // 3 px bar + 2 px gap
    // Bar height = 3 + (bpm - 50) / 80 * 25, clamped to 3..28 (§7).
    private const BAR_MIN_H = 3.0;
    private const BAR_MAX_H = 28.0;
    private const BAR_BPM_FLOOR = 50.0;
    private const BAR_BPM_SPAN = 80.0;
    // History is re-read when a new 10-minute bar starts (allocates; see HeartRateGraph).
    private const GRAPH_REFRESH_MINUTES = 10;
    // The newest history sample stands in for the current heart rate only while
    // it is at most this old (owner's decision); otherwise "--".
    private const HR_FALLBACK_MAX_AGE = 600;

    // ---- Tile row (§2 row 10), measured from the mockup ----

    // Three columns of 52 px from x 52: calories, steps, distance. Icon on top,
    // value below, all centred on the column. Steps keeps the middle column so
    // its bar is not cut by the round edge.
    private const TILE_X = 52.0;
    private const TILE_W = 52.0;
    private const TILE_ICON_TOP = 203.0;
    private const TILE_VALUE_BASELINE = 231.0;
    private const DISTANCE_UNIT_GAP = 2.0;
    private const STEPS_BAR_W = 40.0;
    private const STEPS_BAR_H = 4.0;
    private const STEPS_BAR_Y = 236.0;
    private const CM_PER_KM = 100000.0;
    private const CM_PER_MILE = 160934.4;

    // Capital height of date line 1 ("MON 16"), a system vector font.
    private const CAP_13 = 13.0;

    // Cap height as a fraction of getVectorFont's :size. The size is the font's
    // full line height (hhea ascent + descent), not the em: confirmed in the
    // simulator. From the TTF metrics, Roboto Condensed Bold: cap 1456 / (1900 + 500).
    private const ROBOTO_CONDENSED_CAP_RATIO = 0.607;

    // ---- Fonts, loaded once in onLayout() ----

    private var _timeFont as FontType = Graphics.FONT_NUMBER_HOT;
    // Hard-edged Barlow Condensed numbers (tools/make_fonts.py): digit heights 12, 13, 11.
    private var _num12Font as FontType = Graphics.FONT_TINY;   // seconds, moon percent
    private var _num13Font as FontType = Graphics.FONT_SMALL;  // Body Battery, battery days
    private var _num11Font as FontType = Graphics.FONT_TINY;   // solar percent
    private var _num15Font as FontType = Graphics.FONT_MEDIUM; // current heart rate
    private var _sunTimeFont as FontType = Graphics.FONT_TINY; // sunrise and sunset (SemiBold)
    private var _weekFont as FontType = Graphics.FONT_XTINY;
    private var _monthFont as FontType = Graphics.FONT_XTINY;
    private var _labelFont as FontType = Graphics.FONT_XTINY;
    private var _cap13Font as FontType = Graphics.FONT_SMALL;  // date line 1

    // ---- Layout in device pixels, computed in onLayout() ----

    private var _sx as Float = 1.0;
    private var _sy as Float = 1.0;

    // Always-on seconds (user's request; replaces spec §8 v1, which hid them):
    // onPartialUpdate() redraws only this clip each second in low power. If the
    // power budget is exceeded the system stops partial updates and the seconds
    // are hidden while asleep, as in v1.
    private var _partialUpdates as Boolean = true;
    private var _sleeping as Boolean = false;
    private var _secondsClipY as Number = 0;
    private var _secondsClipW as Number = 0;
    private var _secondsClipH as Number = 0;

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

    // Heart rate: current from the HEART_RATE complication (fallback: newest
    // history sample), resting from the user profile, graph from SensorHistory.
    private var _heartRateId as Complications.Id? = null;
    private var _heartRate as Number? = null;
    private var _restingHeartRate as Number? = null;
    private var _graph as HeartRateGraph = new HeartRateGraph();
    private var _graphSlot as Number = -1;
    private var _graphBarX as Array<Number> = new Array<Number>[HeartRateGraph.BARS];
    private var _graphBarTop as Array<Number> = new Array<Number>[HeartRateGraph.BARS];
    private var _graphBottom as Number = 0;
    private var _graphBarW as Number = 3;
    private var _heartDirty as Boolean = true;
    private var _heartText as String = "--";
    private var _hrLabelText as String = "REST --";
    private var _heartX as Float = 0.0;
    private var _heartTextX as Number = 0;
    private var _hrLabelX as Number = 0;
    private var _heartTop as Float = 0.0;
    private var _hrValueTop as Number = 0;
    private var _hrLabelTop as Number = 0;

    // Tile row: calories, steps (with goal bar), distance in the device's unit.
    private var _tileCentreX as Array<Float> = [0.0, 0.0, 0.0] as Array<Float>;
    private var _tileIconTop as Float = 0.0;
    private var _tileValueTop as Number = 0;
    private var _tileUnitTop as Number = 0;
    private var _stepsBarX as Number = 0;
    private var _stepsBarY as Number = 0;
    private var _stepsBarW as Number = 0;
    private var _stepsBarH as Number = 0;
    private var _caloriesKey as Number = -2;
    private var _caloriesText as String = "--";
    private var _stepsKey as Number = -2;
    private var _stepsText as String = "--";
    private var _stepsFill as Float = 0.0;
    private var _distanceKey as Number = -2;
    private var _distanceText as String = "--";
    private var _distanceUnit as String = "";
    private var _distanceTextX as Number = 0;
    private var _distanceUnitX as Number = 0;

    // Text and accent colours and the heart-rate label, from the settings (§9).
    // Read in initialize() and again whenever a setting changes.
    private var _ink as Number = 0x000000;
    private var _accent as Number = 0xFF5500;
    private var _heartRateLabel as Number = Settings.LABEL_REST;

    // Colours resolved by the colour rules (§6) whenever a value changes.
    private var _batteryIconColour as Number = 0;   // icon and charge bar
    private var _batteryTextColour as Number = 0;
    private var _solarIconColour as Number = 0;
    private var _solarTextColour as Number = 0;
    private var _bodyBatteryIconColour as Number = 0;
    private var _bodyBatteryTextColour as Number = 0;
    private var _stepsBarColour as Number = 0;
    private var _graphBarColour as Array<Number> = new Array<Number>[HeartRateGraph.BARS];

    // Body Battery from SensorHistory, used when the complication has no value.
    private var _bodyBatteryHistory as Number? = null;

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
        loadSettings();
        subscribeComplications();
    }

    //! Called by the app when a setting changes (Garmin Connect, simulator
    //! editor or the on-watch menu): re-read it and rebuild every cached colour.
    function reloadSettings() as Void {
        loadSettings();
        invalidateCaches();
    }

    private function loadSettings() as Void {
        _ink = Settings.textColour();
        _accent = Settings.accentColour();
        _heartRateLabel = Settings.heartRateLabel();
    }

    function onLayout(dc as Dc) as Void {
        _sx = dc.getWidth() / SPEC_SIZE;
        _sy = dc.getHeight() / SPEC_SIZE;

        // Bitmap fonts are rasterised at the 260 px size (tools/make_fonts.py).
        _timeFont = WatchUi.loadResource(Rez.Fonts.TimeFont) as FontResource;
        _num12Font = WatchUi.loadResource(Rez.Fonts.Num12Font) as FontResource;
        _num13Font = WatchUi.loadResource(Rez.Fonts.Num13Font) as FontResource;
        _num11Font = WatchUi.loadResource(Rez.Fonts.Num11Font) as FontResource;
        _num15Font = WatchUi.loadResource(Rez.Fonts.Num15Font) as FontResource;
        _sunTimeFont = WatchUi.loadResource(Rez.Fonts.SunTimeFont) as FontResource;
        _monthFont = WatchUi.loadResource(Rez.Fonts.MonthFont) as FontResource;
        _labelFont = WatchUi.loadResource(Rez.Fonts.LabelFont) as FontResource;
        _weekFont = _labelFont;
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
        var widest = 0;
        for (var i = 0; i < 10; i++) {
            if (_secondsAdvance[i] > widest) {
                widest = _secondsAdvance[i];
            }
        }
        _secondsClipY = scaleY(SECONDS_BASELINE - SECONDS_DIGIT_H) - 1;
        _secondsClipH = scaleY(SECONDS_BASELINE) + 1 - _secondsClipY;
        _secondsClipW = 2 * widest + 1;

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

        // Tile row
        for (var i = 0; i < 3; i++) {
            _tileCentreX[i] = (TILE_X + TILE_W * i + TILE_W / 2) * _sx;
        }
        _tileIconTop = TILE_ICON_TOP * _sy;
        _tileValueTop = topForBaseline(TILE_VALUE_BASELINE, _num12Font);
        _tileUnitTop = topForBaseline(TILE_VALUE_BASELINE, _labelFont);
        _stepsBarX = round(_tileCentreX[1] - STEPS_BAR_W * _sx / 2);
        _stepsBarY = scaleY(STEPS_BAR_Y);
        _stepsBarW = scaleX(STEPS_BAR_W);
        _stepsBarH = scaleY(STEPS_BAR_Y + STEPS_BAR_H) - _stepsBarY;

        // Heart-rate box
        _heartX = HEART_X * _sx;
        _heartTextX = scaleX(HR_VALUE_X);
        _hrLabelX = scaleX(HR_LABEL_X);
        _heartTop = HEART_TOP * _sy;
        _hrValueTop = topForBaseline(HR_VALUE_BASELINE, _num15Font);
        _hrLabelTop = topForBaseline(HR_LABEL_BASELINE, _labelFont);
        _graphBottom = scaleY(GRAPH_BOTTOM);
        _graphBarW = scaleX(GRAPH_BAR_W);
        if (_graphBarW < 1) {
            _graphBarW = 1;
        }
        var bars = HeartRateGraph.BARS;
        for (var i = 0; i < bars; i++) {
            _graphBarX[i] = scaleX(GRAPH_RIGHT - GRAPH_BAR_W - (bars - 1 - i) * GRAPH_BAR_PITCH);
            _graphBarTop[i] = _graphBottom;
            _graphBarColour[i] = _ink;
        }

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

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    //! Low power: redraw only the seconds, once a second.
    function onPartialUpdate(dc as Dc) as Void {
        if (!_partialUpdates) {
            return;
        }
        var sec = System.getClockTime().sec;
        // Clip covers every value 00-59 at any time width (checked against the
        // font metrics); paint only that rectangle, then the new digits.
        dc.setClip(_sideX, _secondsClipY, _secondsClipW, _secondsClipH);
        dc.setColor(Palette.BACKGROUND, Palette.BACKGROUND);
        dc.fillRectangle(_sideX, _secondsClipY, _secondsClipW, _secondsClipH);
        drawSeconds(dc, sec);
        dc.clearClip();
    }

    //! Called by the delegate when partial updates exceed the power budget.
    function disablePartialUpdates() as Void {
        _partialUpdates = false;
        WatchUi.requestUpdate();
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
            refreshActivity(dc);
            var slot = minute / GRAPH_REFRESH_MINUTES;
            if (slot != _graphSlot) {
                _graphSlot = slot;
                refreshHeartHistory(now);
            }
            if (_heartRate == null) {
                _heartDirty = true;   // re-check the fallback's age every minute
            }
            applyDemo(dc);
            logMemory("minute");
        }
        if (_bodyBatteryDirty) {
            refreshBodyBattery(dc);
        }
        if (_sunTimesDirty) {
            refreshSunTimes(dc);
        }
        if (_heartDirty) {
            refreshHeart();
        }

        dc.setColor(Palette.BACKGROUND, Palette.BACKGROUND);
        dc.clear();
        drawSunTimes(dc);
        drawDateBlock(dc);
        drawBoxOutlines(dc);
        drawMoonBox(dc);
        drawBodyBatteryBox(dc);
        drawSidePanel(dc);
        drawHeartBox(dc);
        drawTiles(dc);
        drawTime(dc, clock.sec);
    }

    //! Complication callback: store the new value; its text is rebuilt on the next update.
    function onComplicationChanged(id as Complications.Id) as Void {
        if (demoActive()) {
            return;   // debug demo: keep the mockup values on screen
        }
        if (id.equals(_bodyBatteryId)) {
            _bodyBattery = readComplication(_bodyBatteryId);
            _bodyBatteryDirty = true;
        } else if (id.equals(_sunriseId)) {
            _sunrise = readComplication(_sunriseId);
            _sunTimesDirty = true;
        } else if (id.equals(_sunsetId)) {
            _sunset = readComplication(_sunsetId);
            _sunTimesDirty = true;
        } else if (id.equals(_heartRateId)) {
            _heartRate = readComplication(_heartRateId);
            _heartDirty = true;
        }
    }

    // ---- Drawing (no allocation) ----

    private function drawTiles(dc as Dc) as Void {
        var s = _sx;

        // Calories
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        Icons.drawFlame(dc, _tileCentreX[0] - Icons.FLAME_W * s / 2, _tileIconTop, s);
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_tileCentreX[0], _tileValueTop, _num12Font, _caloriesText, Graphics.TEXT_JUSTIFY_CENTER);

        // Steps, with progress toward the goal
        Icons.drawSteps(dc, _tileCentreX[1] - Icons.STEPS_W * s / 2, _tileIconTop, s);
        dc.drawText(_tileCentreX[1], _tileValueTop, _num12Font, _stepsText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_stepsBarX, _stepsBarY, _stepsBarW, _stepsBarH);
        var fill = (_stepsBarW * _stepsFill + 0.5).toNumber();
        if (fill > 0) {
            dc.setColor(_stepsBarColour, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_stepsBarX, _stepsBarY, fill, _stepsBarH);
        }

        // Distance, with a small grey unit
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        Icons.drawPin(dc, _tileCentreX[2] - Icons.PIN_W * s / 2, _tileIconTop, s);
        dc.drawText(_distanceTextX, _tileValueTop, _num12Font, _distanceText, Graphics.TEXT_JUSTIFY_LEFT);
        if (_distanceUnit.length() > 0) {
            dc.setColor(Palette.LABEL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_distanceUnitX, _tileUnitTop, _labelFont, _distanceUnit, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    private function drawHeartBox(dc as Dc) as Void {
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        Icons.drawHeart(dc, _heartX, _heartTop, _sx);
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_heartTextX, _hrValueTop, _num15Font, _heartText, Graphics.TEXT_JUSTIFY_LEFT);

        // Bars: bottom-aligned; a bar with no data has its top on the bottom line.
        for (var i = 0; i < HeartRateGraph.BARS; i++) {
            var top = _graphBarTop[i];
            if (top < _graphBottom) {
                dc.setColor(_graphBarColour[i], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_graphBarX[i], top, _graphBarW, _graphBottom - top);
            }
        }

        dc.setColor(Palette.LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_hrLabelX, _hrLabelTop, _labelFont, _hrLabelText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawSunTimes(dc as Dc) as Void {
        Icons.drawSunEvent(dc, _sunriseIconX, _sunIconTop, _sx, true, _ink, _accent);
        Icons.drawSunEvent(dc, _sunsetIconX, _sunIconTop, _sx, false, _ink, _accent);
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sunriseTextX, _sunTimeTop, _sunTimeFont, _sunriseText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_sunsetTextX, _sunTimeTop, _sunTimeFont, _sunsetText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawTime(dc as Dc, sec as Number) as Void {
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            dc.drawText(_timeDigitX[i], _timeTop, _timeFont, _timeDigits[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.drawText(_colonX, _timeTop, _timeFont, ":", Graphics.TEXT_JUSTIFY_LEFT);

        dc.drawText(_sideX, _weekTop, _weekFont, _weekText, Graphics.TEXT_JUSTIFY_LEFT);

        // Without partial updates, seconds would freeze while asleep: hide them.
        if (_partialUpdates || !_sleeping) {
            drawSeconds(dc, sec);
        }
    }

    private function drawSeconds(dc as Dc, sec as Number) as Void {
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        var tens = sec / 10;
        dc.drawText(_sideX, _secondsTop, _num12Font, tens, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_sideX + _secondsAdvance[tens], _secondsTop, _num12Font, sec % 10, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawDateBlock(dc as Dc) as Void {
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_dateX, _dateY, _dateW, _dateH, _dateRadius);

        dc.setColor(Palette.DATE_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_dateCentreX, _dateLine1Top, _cap13Font, _dateLine1Text, Graphics.TEXT_JUSTIFY_CENTER);
        for (var i = 0; i < _monthChars.size(); i++) {
            dc.drawText(_monthCharX[i], _dateLine2Top, _monthFont, _monthChars[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    //! 2 px outlines, drawn as nested 1 px rounded rectangles inside the spec box.
    private function drawBoxOutlines(dc as Dc) as Void {
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _boxes.size(); i++) {
            var b = _boxes[i];
            for (var k = 0; k < _outlineWidth; k++) {
                dc.drawRoundedRectangle(b[0] + k, b[1] + k, b[2] - 2 * k, b[3] - 2 * k, b[4] - k);
            }
        }
    }

    private function drawMoonBox(dc as Dc) as Void {
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        Icons.drawMoon(dc, _moonIconX, _moonIconTop, _sx, _moonPhase);
        dc.drawText(_moonTextX, _boxValueTop, _num12Font, _moonText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Palette.LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(boxCentreX(BOX_MOON), _labelTop, _labelFont, _moonLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawBodyBatteryBox(dc as Dc) as Void {
        dc.setColor(_bodyBatteryIconColour, Graphics.COLOR_TRANSPARENT);
        Icons.drawBolt(dc, _boltX, _boltTop, _sx, _boltPoints);
        dc.setColor(_bodyBatteryTextColour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_bodyBatteryTextX, _bodyBatteryValueTop, _num13Font, _bodyBatteryText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Palette.LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(boxCentreX(BOX_BODY_BATTERY), _labelTop, _labelFont, "BODY BAT", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSidePanel(dc as Dc) as Void {
        // Battery: icon and days
        dc.setColor(_batteryIconColour, Graphics.COLOR_TRANSPARENT);
        Icons.drawBattery(dc, _batteryIconX, _batteryIconTop, _sx, _batteryCharge);
        dc.setColor(_batteryTextColour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_batteryTextX, _daysTop, _num13Font, _batteryText, Graphics.TEXT_JUSTIFY_LEFT);

        // Charge bar: grey track, fill clipped from the left so its right end is square.
        var radius = _barH / 2;
        dc.setColor(Palette.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_barX, _barY, _barW, _barH, radius);
        var fill = (_barW * _batteryCharge + 0.5).toNumber();
        if (fill > 0) {
            dc.setColor(_batteryIconColour, Graphics.COLOR_TRANSPARENT);
            dc.setClip(_barX, _barY, fill, _barH);
            dc.fillRoundedRectangle(_barX, _barY, _barW, _barH, radius);
            dc.clearClip();
        }

        // Solar
        dc.setColor(_solarIconColour, Graphics.COLOR_TRANSPARENT);
        Icons.drawSun(dc, _sunX, _sunTop, _sx);
        dc.setColor(_solarTextColour, Graphics.COLOR_TRANSPARENT);
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
        _heartDirty = true;
        _graphSlot = -1;
        _caloriesKey = -2;
        _stepsKey = -2;
        _distanceKey = -2;
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
        var days = null;
        if (stats has :batteryInDays) {
            days = stats.batteryInDays.toNumber();
        }
        applyBattery(dc, stats.battery, days, stats.solarIntensity);
    }

    private function applyBattery(dc as Dc, percent as Float, days as Number?, solar as Number?) as Void {
        _batteryCharge = Icons.clamp01(percent / 100.0);

        // Key: days, or 1000 + percent when the device has no days estimate.
        var key = (days != null) ? days : 1000 + percent.toNumber();
        if (key != _batteryKey) {
            _batteryKey = key;
            _batteryText = (key < 1000) ? key.toString() + "d" : (key - 1000).toString() + "%";
            _batteryIconX = rowLeft(dc, BOX_SIDE, Icons.BATTERY_W, ICON_GAP, _batteryText, _num13Font);
            _batteryTextX = round(_batteryIconX + (Icons.BATTERY_W + ICON_GAP) * _sx);
        }
        // Rule: fewer than 4 days left (only when the device gives days).
        var low = key < ColourRules.BATTERY_LOW_DAYS;
        _batteryIconColour = low ? Palette.RED : _ink;
        _batteryTextColour = low ? Palette.RED_TEXT : _ink;

        // Key: -1 when there is no solar sensor; negative intensity (not charging) shows 0%.
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
        // Rule: intensity above 75.
        var strong = solarKey > ColourRules.SOLAR_HIGH;
        _solarIconColour = strong ? Palette.GREEN : _accent;
        _solarTextColour = strong ? Palette.GREEN_TEXT : _ink;
    }

    private function refreshBodyBattery(dc as Dc) as Void {
        _bodyBatteryDirty = false;
        var value = (_bodyBattery != null) ? _bodyBattery : _bodyBatteryHistory;
        _bodyBatteryText = (value == null) ? "--" : value.toString();
        // Rules: above 70 green, below 15 red.
        _bodyBatteryIconColour = _ink;
        _bodyBatteryTextColour = _ink;
        if (value != null && value > ColourRules.BODY_BATTERY_HIGH) {
            _bodyBatteryIconColour = Palette.GREEN;
            _bodyBatteryTextColour = Palette.GREEN_TEXT;
        } else if (value != null && value < ColourRules.BODY_BATTERY_LOW) {
            _bodyBatteryIconColour = Palette.RED;
            _bodyBatteryTextColour = Palette.RED_TEXT;
        }
        _boltX = rowLeft(dc, BOX_BODY_BATTERY, Icons.BOLT_W, BOLT_GAP, _bodyBatteryText, _num13Font);
        _bodyBatteryTextX = round(_boltX + (Icons.BOLT_W + BOLT_GAP) * _sx);
    }

    //! Calories, steps and distance for today (§7). Text is rebuilt only when a value changes.
    private function refreshActivity(dc as Dc) as Void {
        var info = ActivityMonitor.getInfo();
        applyActivity(dc, info.calories, info.steps, info.stepGoal, info.distance);
    }

    private function applyActivity(dc as Dc, calories as Number?, steps as Number?, goal as Number?, cm as Number?) as Void {
        var key = (calories == null) ? -1 : calories;
        if (key != _caloriesKey) {
            _caloriesKey = key;
            _caloriesText = (calories == null) ? "--" : formatThousands(calories);
        }

        _stepsFill = 0.0;
        _stepsBarColour = _accent;
        if (steps != null && goal != null && goal > 0) {
            _stepsFill = Icons.clamp01(steps.toFloat() / goal);
            if (steps >= goal) {
                _stepsBarColour = Palette.GREEN;   // rule: goal reached
            }
        }
        key = (steps == null) ? -1 : steps;
        if (key != _stepsKey) {
            _stepsKey = key;
            _stepsText = (steps == null) ? "--" : formatThousands(steps);
        }

        // Distance in tenths of the device's unit; the key also records the unit.
        var statute = System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
        var tenths = -1;
        if (cm != null) {
            tenths = (cm / (statute ? CM_PER_MILE : CM_PER_KM) * 10 + 0.5).toNumber();
        }
        key = (tenths < 0) ? -1 : tenths * 2 + (statute ? 1 : 0);
        if (key != _distanceKey) {
            _distanceKey = key;
            if (tenths < 0) {
                _distanceText = "--";
                _distanceUnit = "";
            } else {
                _distanceText = (tenths / 10).toString() + "." + (tenths % 10).toString();
                _distanceUnit = statute ? "MI" : "KM";
            }
            // Value and unit centred together on the column.
            var valueW = dc.getTextWidthInPixels(_distanceText, _num12Font);
            var unitW = 0.0;
            if (_distanceUnit.length() > 0) {
                unitW = DISTANCE_UNIT_GAP * _sx + dc.getTextWidthInPixels(_distanceUnit, _labelFont);
            }
            var left = _tileCentreX[2] - (valueW + unitW) / 2;
            _distanceTextX = round(left);
            _distanceUnitX = round(left + valueW + DISTANCE_UNIT_GAP * _sx);
        }
    }

    //! 1847 -> "1,847"; 12345 -> "12,345".
    private function formatThousands(n as Number) as String {
        if (n < 1000) {
            return n.toString();
        }
        return formatThousands(n / 1000) + "," + (n % 1000).format("%03d");
    }

    //! Re-reads heart-rate history, resting heart rate and the Body Battery
    //! fallback. Allocates (SensorHistory, UserProfile), so it runs only when a
    //! new 10-minute bar starts.
    private function refreshHeartHistory(now as Time.Moment) as Void {
        _graph.rebuild(now.value());
        layoutGraph();
        _restingHeartRate = readRestingHeartRate();
        logGraph();
        var history = readBodyBatteryHistory();
        if (history != _bodyBatteryHistory) {
            _bodyBatteryHistory = history;
            _bodyBatteryDirty = true;
        }
        _heartDirty = true;
    }

    //! Bar heights (§7 formula) and colours (§6) from the graph's bpm values.
    private function layoutGraph() as Void {
        var bottom = GRAPH_BOTTOM;
        for (var i = 0; i < HeartRateGraph.BARS; i++) {
            var bpm = _graph.bpm[i];
            if (bpm <= 0) {
                _graphBarTop[i] = _graphBottom;
                continue;
            }
            var h = BAR_MIN_H + (bpm - BAR_BPM_FLOOR) / BAR_BPM_SPAN * (BAR_MAX_H - BAR_MIN_H);
            if (h < BAR_MIN_H) {
                h = BAR_MIN_H;
            } else if (h > BAR_MAX_H) {
                h = BAR_MAX_H;
            }
            _graphBarTop[i] = scaleY(bottom - h);
        }
        ColourRules.graphBarColours(_graph.bpm, _graphBarColour, _ink, _accent);
    }

    //! Current bpm (complication, else a history sample under 10 minutes old) and the REST/MAX label.
    private function refreshHeart() as Void {
        _heartDirty = false;
        var hr = _heartRate;
        if (hr == null && _graph.latest != null
                && Time.now().value() - _graph.latestTime <= HR_FALLBACK_MAX_AGE) {
            hr = _graph.latest;
        }
        _heartText = (hr == null) ? "--" : hr.toString();
        // Label: resting heart rate, or the 4-hour max (tallest bar) per the setting.
        if (_heartRateLabel == Settings.LABEL_MAX) {
            var max = 0;
            for (var i = 0; i < HeartRateGraph.BARS; i++) {
                if (_graph.bpm[i] > max) {
                    max = _graph.bpm[i];
                }
            }
            _hrLabelText = (max > 0) ? "MAX " + max.toString() : "MAX --";
        } else {
            var rest = _restingHeartRate;
            _hrLabelText = (rest == null) ? "REST --" : "REST " + rest.toString();
        }
    }

    //! 7-day average resting heart rate, else the configured one (§7).
    private function readRestingHeartRate() as Number? {
        if (!(Toybox has :UserProfile)) {
            return null;
        }
        var profile = UserProfile.getProfile();
        var rest = null;
        if (profile has :averageRestingHeartRate) {
            rest = profile.averageRestingHeartRate;
        }
        if (rest == null || rest <= 0) {
            rest = profile.restingHeartRate;
        }
        return (rest != null && rest > 0) ? rest : null;
    }

    //! Newest Body Battery sample, or null.
    private function readBodyBatteryHistory() as Number? {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }
        var sample = SensorHistory.getBodyBatteryHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        }).next();
        if (sample == null || sample.data == null) {
            return null;
        }
        return sample.data.toNumber();
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

    // ---- Complications: Body Battery, sunrise, sunset, heart rate ----

    private function subscribeComplications() as Void {
        try {
            Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
        } catch (e) {
            return;
        }
        _bodyBatteryId = subscribe(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        _sunriseId = subscribe(Complications.COMPLICATION_TYPE_SUNRISE);
        _sunsetId = subscribe(Complications.COMPLICATION_TYPE_SUNSET);
        _heartRateId = subscribe(Complications.COMPLICATION_TYPE_HEART_RATE);
        _bodyBattery = readComplication(_bodyBatteryId);
        _sunrise = readComplication(_sunriseId);
        _sunset = readComplication(_sunsetId);
        _heartRate = readComplication(_heartRateId);
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
    }

    //! Debug builds: overrides live data with a mockup state (see Demo.mc).
    (:debug)
    private function applyDemo(dc as Dc) as Void {
        var i = Demo.STATE - 1;
        if (i < 0) {
            return;
        }
        applyBattery(dc, Demo.BATTERY_PERCENT[i], Demo.BATTERY_DAYS[i], Demo.SOLAR[i]);
        applyActivity(dc, Demo.CALORIES[i], Demo.STEPS[i], Demo.STEP_GOAL, Demo.DISTANCE_CM[i]);
        _bodyBattery = Demo.BODY_BATTERY[i];
        _bodyBatteryDirty = true;
        _heartRate = Demo.HEART_RATE;
        _restingHeartRate = Demo.RESTING_HEART_RATE;
        _heartDirty = true;
        for (var b = 0; b < HeartRateGraph.BARS; b++) {
            _graph.bpm[b] = Demo.GRAPH_BPM[b];
        }
        layoutGraph();
    }

    (:release)
    private function applyDemo(dc as Dc) as Void {
    }

    (:debug)
    private function demoActive() as Boolean {
        return Demo.STATE != 0;
    }

    (:release)
    private function demoActive() as Boolean {
        return false;
    }

    (:debug)
    private function logGraph() as Void {
        var bars = 0;
        for (var i = 0; i < HeartRateGraph.BARS; i++) {
            if (_graph.bpm[i] > 0) {
                bars++;
            }
        }
        System.println("hr graph: " + bars + "/" + HeartRateGraph.BARS + " bars, latest=" + _graph.latest
            + " rest=" + _restingHeartRate + " bpm=" + _graph.bpm);
    }

    (:release)
    private function logGraph() as Void {
    }}
