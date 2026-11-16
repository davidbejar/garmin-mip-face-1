# Watch face design spec: Instrument panel V4a

Target: Garmin fēnix 8 Solar 47mm. Round 260 × 260 px memory-in-pixel (MIP) screen, 64 colours, always on.

Design source: Claude Design canvas, page "Instrument panel v4", frame "V4a · Three tiles"
https://claude.ai/artifact/568ZMQVgjau2dtufr7cgr7

Mockups in this folder (export them from the canvas as PNG):
- `v4a-normal.png`: frame "V4a · Three tiles"
- `v4a-targets-met.png`: frame "State · Targets met"
- `v4a-running-low.png`: frame "State · Running low"

## 1. Coordinates

All numbers below are pixels on a 260 × 260 canvas, origin top-left. In code, multiply by
`dc.getWidth() / 260.0` so the layout scales to other screen sizes. Never hard-code pixels.

The visible area is a circle of radius 130 centred at (130, 130). Nothing may be drawn outside it.

## 2. Layout

| # | Element | x | y | w | h | Content |
|---|---------|---|---|---|---|---------|
| 1 | Sun times row | centred | 15 | auto | 15 | Sunrise icon + time, 10 px gap, sunset icon + time |
| 2 | Moon box | 40 | 39 | 54 | 36 | Outlined box. Moon-phase icon + percent lit; phase label below |
| 3 | Date block | 98 | 37 | 64 | 40 | Filled box. Line 1 weekday + day ("MON 16"); line 2 month ("NOVEMBER") |
| 4 | Body Battery box | 166 | 39 | 54 | 36 | Outlined box. Bolt icon + value; label "BODY BAT" below |
| 5 | Time | 16 | 84 | auto | 62 | HH:MM. Digit tops at y ≈ 96, baseline at y ≈ 141 |
| 6 | Week number | 3 px right of time | 94 | auto | 11 | "WK 47". Its top lines up with the tops of the time digits |
| 7 | Seconds | 3 px right of time | 126 | auto | 16 | Two digits. Shares the time's baseline (y ≈ 141) |
| 8 | Side panel | 176 | 84 | 68 | 62 | Outlined box. Battery icon + days ("11d"); bar 48 × 4 below; sun icon + solar percent below that |
| 9 | Heart-rate box | 28 | 154 | 204 | 44 | Outlined box, padding 6 top/bottom and 8 left/right. Left: heart icon + current heart rate, label "REST 52" below. Right: bar graph |
| 10 | Tile row | 52 | 202 | 156 | ~40 | Three equal columns of 52. Each: icon on top, value below |

Tile row columns, left to right:
1. Calories: flame icon, value (for example "1,847").
2. Steps: steps icon, value (for example "8,412"), then a 40 × 4 progress bar under the value.
3. Distance: pin icon, value with one decimal (for example "6.1") followed by a small "KM".

Steps must stay in the middle column. The screen narrows at the bottom, and a bar under a side column would be cut off by the round edge.

Boxes: outline 2 px on the device (1.5 px in the mockup), corner radius 7 (boxes 2 and 4) or 8 (boxes 8 and 9). The date block is filled, radius 7.

## 3. Type

The mockup uses stand-in fonts: Barlow Condensed for numbers and Barlow for small labels (both SIL Open Font License).
On the watch, start with Garmin system fonts and compare against the mockups. If the match is poor, convert the stand-ins to
bitmap fonts (digits and the few letters needed only, to save memory).

| Use | Mockup size (px) | Weight |
|-----|------------------|--------|
| Time | 64 | Semi-bold, condensed |
| Current heart rate | 20 | Bold, condensed |
| Battery days | 19 | Bold, condensed |
| Date line 1, Body Battery value | 18 | Bold, condensed |
| Seconds, moon percent, tile values | 16 | Bold, condensed |
| Sun times, solar percent | 14 | Bold, condensed |
| Week number | 11 | Semi-bold, normal width |
| Date line 2 (month) | 9 | Bold, letter-spaced |
| Box labels, "REST 52", "KM" | 8.5 | Bold |

The 8.5 px labels are at the limit of legibility on this screen. Check them in the simulator and on the watch.
If they are hard to read, use the smallest system font, or drop the labels and rely on the icons.

## 4. Icons

Ten icons, 12–14 px: sunrise, sunset, moon phase, bolt (Body Battery), battery, sun (solar), heart, flame (calories),
steps, pin (distance). Several change colour (section 6), so build them as an icon font or draw them in code, so the
colour can be set at draw time. Do not use pre-coloured bitmaps.

The moon icon shows the current phase: a circle outline in the text colour, with the unlit part filled.

## 5. Colours

Use only the 64 MIP colours: each of red, green and blue is 00, 55, AA or FF.

| Role | Value |
|------|-------|
| Background | #FFFFFF |
| Text colour (setting) | default #000000; options #000000, #000055, #005500, #550000, #0055AA |
| Accent (setting) | default #FF5500; options #FF5500, #AA0000, #0055AA, #00AA55 |
| Small labels | #555555 |
| Bar track (unfilled part) | #AAAAAA |
| Date block text | #FFFFFF |
| Red: icons and bars | #FF0000 |
| Red: numbers | #AA0000 |
| Green: icons and bars | #00AA00 |
| Green: numbers | #005500 |
| Lowest heart-rate bar | #0055FF |

Default colouring: all text, outlines, the date block fill, and the battery, bolt, steps, pin, moon and sun-time icons use the
text colour. The heart, flame and sun icons use the accent. The steps bar fill uses the accent. The battery bar fill uses the text colour.

## 6. Colour rules

| Field | Condition | Effect |
|-------|-----------|--------|
| Heart-rate bars | value ≥ 100 bpm | Bar in accent |
| Heart-rate bars | the lowest bar in the graph (first one if tied), if below 100 | Bar in #0055FF |
| Watch battery | days remaining < 4 | Icon and bar #FF0000, number #AA0000 |
| Solar | intensity > 75 | Icon #00AA00, number #005500 |
| Body Battery | value > 70 | Icon #00AA00, number #005500 |
| Body Battery | value < 15 | Icon #FF0000, number #AA0000 |
| Steps bar | steps ≥ step goal | Bar fill #00AA00 |

Otherwise each field uses its default colouring from section 5.

## 7. Data

API names marked (check) are from memory. Confirm each against the Connect IQ API docs before using it.

| Field | Source | Format | When there is no data |
|-------|--------|--------|------------------------|
| Time | `System.getClockTime()`; always 24-hour, whatever the device setting (decided 2026-11-16) | HH:MM | n/a |
| Seconds | `System.getClockTime().sec` | two digits | hidden in low power |
| Date | `Time.Gregorian.info()` (check) | "MON 16" / "NOVEMBER" | n/a |
| Week number | computed: ISO 8601 week | "WK 47" | n/a |
| Sunrise, sunset | Complications `SUNRISE` and `SUNSET`, or `Weather.getSunrise` / `getSunset` with last known position (check) | HH:MM | "--:--" |
| Moon phase | computed from the date (synodic month 29.53 days) | percent lit + label | n/a |
| Body Battery | Complication `BODY_BATTERY`, or latest sample from `SensorHistory.getBodyBatteryHistory` | 0–100 | "--" |
| Battery days | `System.getSystemStats().batteryInDays` | whole days + "d" | fall back to `battery` percent + "%" |
| Battery bar | `System.getSystemStats().battery` | fill = percent / 100 | empty bar |
| Solar intensity | `System.getSystemStats().solarIntensity` (0–100; null without solar; negative when not charging) | percent; show 0% when negative | "--" |
| Current heart rate | `Activity.getActivityInfo().currentHeartRate` (check), else latest `SensorHistory` sample | bpm | "--" |
| Resting heart rate | `UserProfile.getProfile().averageRestingHeartRate` (7-day average); fall back to `restingHeartRate` | "REST 52" | "REST --" |
| Heart-rate graph | `SensorHistory.getHeartRateHistory`, last 4 hours | 24 bars, see below | bar omitted |
| Calories | `ActivityMonitor.getInfo().calories` | thousands separator | "--" |
| Steps | `ActivityMonitor.getInfo().steps` and `.stepGoal` | thousands separator; bar = steps / goal, capped at 1 | "--", empty bar |
| Distance | `ActivityMonitor.getInfo().distance` (check the unit) | km with one decimal; follow the device distance-unit setting (KM or MI) | "--" |

Moon labels: NEW, WAX CRES, 1ST QTR, WAX GIB, FULL, WAN GIB, LAST QTR, WAN CRES.

### Heart-rate graph

- 24 bars, oldest on the left. Each bar covers 10 minutes; use the highest sample in that window.
- On the device: bar 3 px wide, 2 px gap (118 px total), bottom-aligned, right-aligned inside the box.
- Height = 3 + (bpm − 50) / 80 × 25, clamped to 3–28 px.
- The amount of history is device dependent. Check in the simulator how far back the data goes. If it is less than 4 hours,
  shorten the window and keep 24 bars.
- Rebuild the bar data at most once a minute, and not inside `onUpdate()` if it allocates.

## 8. Low power

- The screen stays on. Redraw the full face once a minute.
- Version 1: hide the seconds in low power. Everything else stays the same.
- Later option: draw seconds with `onPartialUpdate`, clipped to the seconds area only, and handle `onPowerBudgetExceeded`.

## 9. Settings

- Text colour and accent colour (options in section 5).
- Prefer on-device settings so they can be tested by sideloading. Supporting the fēnix 8 native watch face editor is a later step.

## 10. Permissions (check each)

Sensor history, user profile, and complications (subscriber) are likely needed. Positioning is needed only if sunrise and
sunset are computed from location instead of read from complications.

## 11. Done when

- [ ] Simulator screenshot matches `v4a-normal.png` in layout and proportions.
- [ ] All colour rules in section 6 work (test with simulated data).
- [ ] Every field shows its fallback when its data is null.
- [ ] Nothing is clipped by the round edge.
- [ ] Low power hides the seconds and redraws once a minute.
- [ ] Builds for `fenix8solar47mm` with no warnings. (Confirm the exact device ID in `manifest.xml`.)
