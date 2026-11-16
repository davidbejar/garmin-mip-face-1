import Toybox.Lang;
import Toybox.Math;

//! Moon phase computed from the date (design/spec.md §7): mean synodic month,
//! counted from a known new moon. Accurate to within about a day, which is
//! enough for a percent and an eight-step label.
module MoonPhase {

    const SYNODIC_DAYS = 29.530588;

    //! New moon of 2000-01-06 18:14 UTC, in Unix seconds.
    const REFERENCE_NEW_MOON = 947182440;

    const SECONDS_PER_DAY = 86400.0;

    //! Indexed by label(): eight phases centred on the principal phases.
    const LABELS = [
        "NEW", "WAX CRES", "1ST QTR", "WAX GIB",
        "FULL", "WAN GIB", "LAST QTR", "WAN CRES"
    ] as Array<String>;

    //! Position in the cycle: 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
    function phase(unixSeconds as Number) as Float {
        var days = (unixSeconds - REFERENCE_NEW_MOON) / SECONDS_PER_DAY;
        var cycles = days / SYNODIC_DAYS;
        var fraction = cycles - Math.floor(cycles);
        return fraction.toFloat();
    }

    //! Percent of the disc that is lit, 0-100.
    function percentLit(phase as Float) as Number {
        var lit = (1 - Math.cos(phase * 2 * Math.PI)) / 2;
        return (lit * 100 + 0.5).toNumber();
    }

    //! Index into LABELS.
    function label(phase as Float) as Number {
        return (phase * 8 + 0.5).toNumber() % 8;
    }
}
