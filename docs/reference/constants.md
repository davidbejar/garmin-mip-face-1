# Constants

All geometry is in pixels on the 260 × 260 spec canvas and is scaled by `dc.getWidth() / 260` (x) and
`dc.getHeight() / 260` (y) in `onLayout`.

## Layout (`InstrumentPanelView.mc`)

| Region | x | y | w | h | Radius / notes |
|--------|--:|--:|--:|--:|----------------|
| Moon box | 40 | 39 | 54 | 36 | r 7, outline 2 |
| Date block (filled) | 98 | 37 | 64 | 40 | r 7. Line 1 baseline 59, line 2 baseline 71 |
| Body Battery box | 166 | 39 | 54 | 36 | r 7 |
| Side panel | 176 | 84 | 68 | 62 | r 8. Charge bar at (186, 114), 48 × 4 |
| Heart-rate box | 28 | 154 | 204 | 44 | r 8. Graph right edge 222, bottom 190 |
| Tile row | 52 | 202 | 3 × 52 | ~40 | Icon top 203, value baseline 231. Steps bar 40 × 4 at y 236 |
| Time | 16 | — | ≤ 127 | ≤ 47 | Baseline 141 |
| Week number | time end + 3 | — | ~28 | 7 | Baseline 103 for 47 px digits |
| Seconds | time end + 3 | — | — | 12 | Baseline 141 |
| Sun times row | centred on 130 | 16 | — | 11 | Time baseline 28, icon gap 3, pair gap 10 |

## Heart-rate graph

| Constant | Value |
|----------|-------|
| Bars | 24 |
| Window | 4 h (14,400 s), shrinks to the available history |
| Minimum bar span | 60 s |
| Bar width / pitch | 3 / 5 px |
| Height | \(3 + (\text{bpm} - 50) / 80 \times 25\), clamped to 3–28 px |
| Refresh | when `minute / 10` changes |
| Current-HR fallback max age | 600 s |

## Colour rule thresholds (`ColourRules.mc`)

| Constant | Value | Effect |
|----------|------:|--------|
| `HR_HIGH_BPM` | 100 | bar in the accent at or above |
| `BATTERY_LOW_DAYS` | 4 | battery red below |
| `SOLAR_HIGH` | 75 | solar green above |
| `BODY_BATTERY_HIGH` | 70 | green above |
| `BODY_BATTERY_LOW` | 15 | red below |

## Time styles (`TimeDisplay.mc`)

| Style | Digit height | Tracking | Other |
|-------|-------------:|---------:|-------|
| Classic | 47 | −1.25 | 2's ink box: x offset 1, width 25 |
| Bold | 41 | −1.2 | 2's ink box: x offset 1, width 25 |
| LCD | 47 | — | cell 23, stroke 5, gap 1, slant 0.10, pitch 28, colon 12 |
| Dot matrix | 45.4 | — | pitch 5.5 × 6.6, dot 5.8, digit gap 0.5 columns, colon dot 3.6 |
| Handwritten | 44 | 0 | glyphs narrowed to 83.8 %, 2's ink box width 27, duck inset 2 |

## Duck (unit coordinates)

| Constant | Value |
|----------|-------|
| Outline | 1.3 px |
| Head radius | 0.38 |
| Maximum body height | 1.35 |
| Body polygon | (0.24,1) (0.07,0.80) (0.03,0.52) (0.10,0.20) (0.30,0) (0.68,0) (0.88,0.09) (0.97,0.34) (1,0.96) (0.88,0.80) (0.74,0.84) (0.64,1) |
| Mitre limit | \(\cos\theta \ge 0.5\) (at most 2 × the offset) |
| Beak outline | the beak scaled ×1.12 about its centroid |
| Colours | body `#FFFF00`, beak `#FF5500` |

## Moon

| Constant | Value |
|----------|-------|
| Synodic month | 29.530588 days |
| Reference new moon | 947182440 (2000-01-06 18:14 UTC) |
| Labels | `round(8φ) mod 8` |

## Units

| Constant | Value |
|----------|-------|
| `CM_PER_KM` | 100,000 |
| `CM_PER_MILE` | 160,934.4 |
| `ROBOTO_CONDENSED_CAP_RATIO` | 0.607 (cap 1456 / (ascent 1900 + descent 500)) |
