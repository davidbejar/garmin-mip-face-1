import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.Time;

//! Heart-rate history for the bar graph (design/spec.md §7): 24 bars over the
//! last 4 hours, oldest on the left, each bar the highest sample in its window.
//! If the device keeps less than 4 hours, the window shrinks and stays 24 bars.
//!
//! rebuild() reads SensorHistory, which allocates an iterator and samples, so
//! the view calls it only when a new 10-minute bar starts (user's decision).
//! Results go into arrays allocated once.
class HeartRateGraph {

    static const BARS = 24;
    static const WINDOW_SECONDS = 4 * 3600;
    static const MIN_BAR_SECONDS = 60;

    //! Highest bpm per bar, oldest first; 0 = no data (bar omitted).
    var bpm as Array<Number>;

    //! Newest valid sample and its time (Unix seconds), or null / 0.
    //! Fallback for the current heart rate while it is recent.
    var latest as Number? = null;
    var latestTime as Number = 0;

    function initialize() {
        bpm = new Array<Number>[BARS];
        clear();
    }

    function rebuild(nowSeconds as Number) as Void {
        clear();
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getHeartRateHistory)) {
            return;
        }
        var samples = SensorHistory.getHeartRateHistory({
            :period => new Time.Duration(WINDOW_SECONDS),
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });

        // Shorten the window to the history that exists.
        var window = WINDOW_SECONDS;
        var oldest = samples.getOldestSampleTime();
        if (oldest != null && nowSeconds - oldest.value() < window) {
            window = nowSeconds - oldest.value();
        }
        var barSeconds = window / BARS;
        if (barSeconds < MIN_BAR_SECONDS) {
            barSeconds = MIN_BAR_SECONDS;
        }

        var sample = samples.next();
        while (sample != null) {
            var value = sample.data;
            if (value != null && value > 0) {
                var v = value.toNumber();
                if (latest == null) {
                    latest = v;
                    latestTime = sample.when.value();
                }
                var bar = BARS - 1 - (nowSeconds - sample.when.value()) / barSeconds;
                if (bar >= 0 && bar < BARS && v > bpm[bar]) {
                    bpm[bar] = v;
                }
            }
            sample = samples.next();
        }
    }

    private function clear() as Void {
        for (var i = 0; i < BARS; i++) {
            bpm[i] = 0;
        }
        latest = null;
        latestTime = 0;
    }
}
