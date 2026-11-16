import Toybox.Lang;

//! Colour rules (design/spec.md §6). Each field uses its default colouring
//! (§5) unless a rule below applies.
module ColourRules {

    const HR_HIGH_BPM = 100;          // bar in accent at or above this
    const BATTERY_LOW_DAYS = 4;       // battery red below this many days
    const SOLAR_HIGH = 75;            // solar green above this intensity
    const BODY_BATTERY_HIGH = 70;     // Body Battery green above this
    const BODY_BATTERY_LOW = 15;      // Body Battery red below this

    //! Heart-rate bar colours: >= 100 bpm in the accent; the lowest bar (the
    //! first one if tied) in blue if it is below 100; the rest in the ink colour.
    //! bpm 0 means no data (no bar); `out` is caller-owned so this never allocates.
    function graphBarColours(bpm as Array<Number>, out as Array<Number>, ink as Number, accent as Number) as Void {
        var lowest = -1;
        for (var i = 0; i < bpm.size(); i++) {
            var v = bpm[i];
            out[i] = (v >= HR_HIGH_BPM) ? accent : ink;
            if (v > 0 && (lowest < 0 || v < bpm[lowest])) {
                lowest = i;
            }
        }
        if (lowest >= 0 && bpm[lowest] < HR_HIGH_BPM) {
            out[lowest] = Palette.HR_LOWEST;
        }
    }
}
