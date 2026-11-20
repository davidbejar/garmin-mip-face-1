import Toybox.Lang;

//! Debug builds only: replaces live data with the values in the mockups, to
//! compare simulator screenshots against design/v4a-*.png and to exercise the
//! colour rules (design/spec.md §6). Release builds leave this module out.
//!
//! Set STATE and rebuild: 0 = live data, 1 = normal, 2 = targets met,
//! 3 = running low. Commit it as 0.
(:debug)
module Demo {

    const STATE = 0;

    //! Shown time in minutes after midnight (e.g. 22 * 60 + 22), or -1 for the
    //! clock. Commit it as -1.
    const TIME = -1;

    // Indexed by STATE - 1, read off the three mockups.
    const BODY_BATTERY = [68, 74, 12] as Array<Number>;
    const BATTERY_DAYS = [11, 11, 3] as Array<Number>;
    const BATTERY_PERCENT = [52.0, 52.0, 15.0] as Array<Float>;
    const SOLAR = [62, 82, 12] as Array<Number>;
    const CALORIES = [1847, 1966, 1440] as Array<Number>;
    const STEPS = [8412, 10240, 2150] as Array<Number>;
    const DISTANCE_CM = [610000, 740000, 160000] as Array<Number>;
    const STEP_GOAL = 10000;
    const HEART_RATE = 62;
    const RESTING_HEART_RATE = 52;

    //! Heart-rate bars, oldest first, from the mockup bar heights (same in all three).
    const GRAPH_BPM = [
        60, 56, 56, 60, 72, 95, 117, 127, 111, 88, 76, 69,
        66, 63, 69, 82, 76, 69, 66, 63, 66, 72, 63, 63
    ] as Array<Number>;
}
