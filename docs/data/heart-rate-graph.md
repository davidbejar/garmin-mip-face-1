# Heart-rate graph

The heart-rate box shows 24 bars covering the last 4 hours, oldest on the left. Each bar is the **highest** sample in
its 10-minute window. The tallest bars are drawn in the accent colour (≥ 100 bpm), and the lowest bar in blue.

## Bucketing

`HeartRateGraph.rebuild(now)` walks the sensor history newest first and drops each sample into a bucket:

\[
\text{bar} = 23 - \left\lfloor \frac{t_\text{now} - t_\text{sample}}{s_\text{bar}} \right\rfloor ,
\qquad s_\text{bar} = \max\!\left(60,\ \left\lfloor \frac{W}{24} \right\rfloor\right)
\]

where \(W\) is the window in seconds. A bucket keeps the maximum: `if (v > bpm[bar]) bpm[bar] = v`.

```js
var samples = SensorHistory.getHeartRateHistory({
    :period => new Time.Duration(WINDOW_SECONDS),     // 4 h
    :order => SensorHistory.ORDER_NEWEST_FIRST
});

// Shorten the window to the history that exists.
var window = WINDOW_SECONDS;
var oldest = samples.getOldestSampleTime();
if (oldest != null && nowSeconds - oldest.value() < window) {
    window = nowSeconds - oldest.value();
}
var barSeconds = window / BARS;
if (barSeconds < MIN_BAR_SECONDS) { barSeconds = MIN_BAR_SECONDS; }
```

### Adapting to the device's history

How much history a device keeps is device-dependent. If less than 4 hours exists (for example just after a reset),
the window **shrinks** to what exists and the graph **keeps 24 bars**. A partial history still fills the box instead of
leaving most of it empty. The 60-second minimum stops the bars from becoming meaningless when only a few minutes of
data exist.

### The newest sample, for free

The first valid sample seen (the iterator runs newest first) is stored as `latest` with its timestamp. It is the
fallback for the current heart rate (see [Data sources](sources.md#stale-data-is-worse-than-no-data)), so no second
history query is needed.

## Bar height

The spec defines bar height as a linear map from bpm, clamped:

\[
h = \operatorname{clamp}\!\left(3 + \frac{\text{bpm} - 50}{80} \times 25,\ 3,\ 28\right)\ \text{px}
\]

So 50 bpm or below is a 3 px stub and 130 bpm or above is a full 28 px bar. Bars are 3 px wide on a 5 px pitch
(118 px in total), right- and bottom-aligned inside the box padding. A bucket with no data (bpm 0) gets its top on
the bottom line and is skipped when drawing.

Heights are converted to device-pixel **tops** in `layoutGraph()`, once per rebuild. `drawHeartBox` only runs
`fillRectangle(x[i], top[i], w, bottom - top[i])`.

## Colouring

`ColourRules.graphBarColours` writes the colours into a caller-owned array:

```js
function graphBarColours(bpm as Array<Number>, out as Array<Number>, ink as Number, accent as Number) as Void {
    var lowest = -1;
    for (var i = 0; i < bpm.size(); i++) {
        var v = bpm[i];
        out[i] = (v >= HR_HIGH_BPM) ? accent : ink;
        if (v > 0 && (lowest < 0 || v < bpm[lowest])) {
            lowest = i;               // strict <: the first one wins a tie
        }
    }
    if (lowest >= 0 && bpm[lowest] < HR_HIGH_BPM) {
        out[lowest] = Palette.HR_LOWEST;   // 0x0055FF
    }
}
```

There are three edge cases: empty buckets are never the "lowest", ties go to the oldest bar, and if every bar is
≥ 100 none turns blue.

## The REST / MAX label

A setting chooses what the small label under the heart rate shows:

- **REST nn** (default): the 7-day average resting heart rate from `UserProfile`, falling back to the configured
  resting heart rate.
- **MAX nn**: the highest bucket in the graph, which is the tallest bar on screen. It is computed from the
  existing `bpm` array, so it needs no additional data source and always matches the graph.

## Refresh cadence

History is read when a **new 10-minute slot** starts (`minute / 10` changes), not every minute. The bar width is 10
minutes, so reading more often couldn't change what is drawn. Reading `SensorHistory` allocates an iterator and
sample objects, so this keeps all of that allocation out of 9 of every 10 minutes. The same refresh also re-reads the
resting heart rate and the Body Battery history fallback.

## Test data

The mockups' bar heights were converted back to bpm values (`Demo.GRAPH_BPM`) so the simulator can show exactly the
mockup's graph, including one blue bar and three accent bars, and the rendering can be compared pixel for pixel.
