# Data sources and fallbacks

The face shows 14 live values. Each one comes from a specific Connect IQ API, is guarded against that API being
missing, and has a defined fallback when the value is `null`. Missing data is treated as a normal input, not an
error.

## Source map

| Field | Primary source | Fallback chain | Shown when missing |
|-------|----------------|----------------|--------------------|
| Time | `System.getClockTime()` | — | — (always available) |
| Seconds | `System.getClockTime().sec` | — | hidden only if the power budget is exceeded while asleep |
| Date, weekday | `Time.Gregorian.info(now, FORMAT_SHORT)` | — | — |
| ISO week | computed in `DateUtil` | — | — |
| Sunrise, sunset | Complications `SUNRISE`, `SUNSET` (seconds after local midnight) | — | `--:--` |
| Moon phase | computed in `MoonPhase` from `Time.now()` | — | — |
| Body Battery | Complication `BODY_BATTERY` | newest `SensorHistory.getBodyBatteryHistory` sample | `--` |
| Battery | `getSystemStats().batteryInDays` | `getSystemStats().battery` as a percent | — |
| Battery bar | `getSystemStats().battery` | — | empty bar |
| Solar | `getSystemStats().solarIntensity` | negative (not charging) → `0%` | `--` (no solar sensor) |
| Heart rate | Complication `HEART_RATE` | newest `SensorHistory` heart-rate sample, **only if ≤ 10 min old** | `--` |
| Resting HR | `UserProfile.getProfile().averageRestingHeartRate` (7-day) | `restingHeartRate` (configured) | `REST --` |
| 4-hour max | tallest bar of the graph | — | `MAX --` |
| HR graph | `SensorHistory.getHeartRateHistory` (4 h) | shorter window if less history exists | bar omitted |
| Calories | `ActivityMonitor.getInfo().calories` | — | `--` |
| Steps, goal | `ActivityMonitor.getInfo().steps`, `.stepGoal` | — | `--`, empty bar |
| Distance | `ActivityMonitor.getInfo().distance` (cm) | unit from `getDeviceSettings().distanceUnits` | `--` |

## Complications: push, not poll

Body Battery, sunrise, sunset and heart rate come from the **Complications** API (Connect IQ 4.2+). The face
subscribes once in `initialize()` and receives changes through a callback:

```js
private function subscribeComplications() as Void {
    try {
        Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
    } catch (e) {
        return;   // no complications on this device: every field keeps its fallback
    }
    _bodyBatteryId = subscribe(Complications.COMPLICATION_TYPE_BODY_BATTERY);
    _sunriseId = subscribe(Complications.COMPLICATION_TYPE_SUNRISE);
    _sunsetId = subscribe(Complications.COMPLICATION_TYPE_SUNSET);
    _heartRateId = subscribe(Complications.COMPLICATION_TYPE_HEART_RATE);
    _bodyBattery = readComplication(_bodyBatteryId);   // initial values
    ...
}
```

Reading is defensive about types. Complication values may arrive as `Number` or `Float`, or be absent:

```js
private function readComplication(id as Complications.Id?) as Number? {
    if (id == null) { return null; }
    try {
        var v = Complications.getComplication(id).value;
        if (v instanceof Number) { return v; }
        if (v instanceof Float) { return v.toNumber(); }
    } catch (e) {
    }
    return null;
}
```

Using complications for sunrise and sunset meant the face needs **no `Positioning` permission**. The alternative,
`Weather.getSunrise` with the last known location, would have needed it. Only three permissions are requested:
`ComplicationSubscriber`, `SensorHistory` and `UserProfile`.

## Stale data is worse than no data

The current heart rate falls back to the newest sensor-history sample, but only while that sample is at most
**10 minutes** old:

```js
var hr = _heartRate;
if (hr == null && _graph.latest != null
        && Time.now().value() - _graph.latestTime <= HR_FALLBACK_MAX_AGE) {   // 600 s
    hr = _graph.latest;
}
_heartText = (hr == null) ? "--" : hr.toString();
```

While the fallback is in use, the view sets `_heartDirty` every minute, so the age is re-checked and the number turns
into `--` once it expires instead of staying on screen indefinitely.

## Capability checks

Every API that might be missing on some firmware or device is guarded with Monkey C's `has` operator, which is
resolved at runtime:

```js
if (stats has :batteryInDays) { days = stats.batteryInDays.toNumber(); }
if (!(Toybox has :UserProfile)) { return null; }
if (profile has :averageRestingHeartRate) { rest = profile.averageRestingHeartRate; }
if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) { return null; }
_antiAlias = dc has :setAntiAlias;
```

Combined with the fallbacks, the face degrades field by field instead of failing as a whole.

## Units and formatting

- **Distance.** `ActivityMonitor` reports centimetres. The face converts to tenths of the device's unit with
  rounding (`cm / 100000 * 10 + 0.5` for km, `160934.4` cm per mile) and formats it as `"6.1"` without floating-point
  formatting, followed by a small grey `KM` or `MI`.
- **Thousands separators.** A short recursive formatter: `1847 → "1,847"`, `12345 → "12,345"`, using `"%03d"` for
  inner groups so `1005` becomes `"1,005"`.
- **Time of day.** Complication sunrise and sunset values are seconds after local midnight, formatted as `HH:MM` with
  `% 24` to be safe for values past midnight.
- **24-hour time** always, whatever the device's 12/24 h setting. This was a design decision recorded in the spec.
- **Battery** shows whole days with `d`, or falls back to a percent with `%`. One change key covers both
  ([Rendering](../architecture/rendering.md#change-keys)).

## Debug demo data

Debug builds can replace all of the above with the values read off the three design mockups (`Demo.STATE = 1, 2, 3`).
The demo goes through the **same** `applyBattery` / `applyActivity` / `layoutGraph` functions as live data, so it
exercises the real formatting and colour rules rather than a separate drawing path. While the demo is active,
`onComplicationChanged` ignores live pushes so the screenshot stays stable.
