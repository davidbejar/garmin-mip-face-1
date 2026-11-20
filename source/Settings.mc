import Toybox.Application;
import Toybox.Lang;

//! User settings (design/spec.md §9). Each is stored as an index into the
//! option lists below (resources/settings/properties.xml).
//!
//! Option lists avoid the fixed colour-rule colours (§6: red, green, blue) so
//! warnings and targets always stand out (owner's decision, 2026-11-16).
module Settings {

    const TEXT_COLOUR = "TextColour";
    const ACCENT_COLOUR = "AccentColour";
    const HEART_RATE_LABEL = "HeartRateLabel";
    const TIME_FONT = "TimeFont";
    const RUBBER_DUCK = "RubberDuck";

    //! Black (default), navy, dark purple.
    const TEXT_COLOURS = [0x000000, 0x000055, 0x550055] as Array<Number>;
    //! Orange (default), magenta, amber.
    const ACCENT_COLOURS = [0xFF5500, 0xAA00AA, 0xFFAA00] as Array<Number>;

    //! HeartRateLabel values.
    const LABEL_REST = 0;   // 7-day average resting heart rate (default)
    const LABEL_MAX = 1;    // highest reading in the graph's 4-hour window

    //! TimeFont values (owner's choice 2026-11-20; previews in tools/preview).
    const TIME_CLASSIC = 0;   // Barlow Condensed SemiBold (default)
    const TIME_BOLD = 1;      // Saira Condensed ExtraBold
    const TIME_LCD = 2;       // 7-segment, drawn in code
    const TIME_DOTS = 3;      // 5x7 dot matrix, drawn in code
    const TIME_HAND = 4;      // Kalam Bold
    const TIME_FONT_COUNT = 5;

    function textColour() as Number {
        return TEXT_COLOURS[index(TEXT_COLOUR, TEXT_COLOURS.size())];
    }

    function accentColour() as Number {
        return ACCENT_COLOURS[index(ACCENT_COLOUR, ACCENT_COLOURS.size())];
    }

    function heartRateLabel() as Number {
        return index(HEART_RATE_LABEL, 2);
    }

    function timeFont() as Number {
        return index(TIME_FONT, TIME_FONT_COUNT);
    }

    //! Rubber duck mode: every 2 in the hours and minutes becomes a duck. Off by default.
    function rubberDuck() as Boolean {
        return index(RUBBER_DUCK, 2) == 1;
    }

    //! Stored index for key, or 0 (the default) if missing or out of range.
    function index(key as String, count as Number) as Number {
        try {
            var v = Properties.getValue(key);
            if (v instanceof Number && v >= 0 && v < count) {
                return v;
            }
        } catch (e) {
        }
        return 0;
    }

    function setIndex(key as String, value as Number) as Void {
        Properties.setValue(key, value);
    }
}
