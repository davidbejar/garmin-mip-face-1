# Memory engineering

Connect IQ watch faces run in a small, fixed heap. On this device a debug build reports **126.8 KB** in total for code,
resources and runtime objects together. Every font, icon, string and array competes for that space, and garbage
collection pauses cost battery.

Memory was treated as a requirement. It was measured at every milestone, and each design option was judged partly by
its cost.

## Measured over the project

Values are `usedMemory` from `System.getSystemStats()`, logged by the debug build after the first minute's refresh
(`mem[minute] used=…`).

| Milestone | Feature added | Used (KB) | Δ (KB) |
|-----------|---------------|----------:|-------:|
| 1 | Time, seconds, week number, date block | 13.0 | +13.0 |
| 2 | Box outlines, side panel, battery, solar, Body Battery, moon | 22.5 | +9.5 |
| 3 | Sunrise and sunset row | 25.2 | +2.7 |
| 4 | Heart-rate box, 24-bar graph, always-on seconds | 30.0 | +4.8 |
| 5 | Tiles: calories, steps with bar, distance | 33.6 | +3.6 |
| 6 | Colour rules (+ ~1.5 KB demo data, debug only) | 35.9 | +2.3 |
| 7 | Low-power hardening | 35.5 | −0.4 |
| 8 | Settings: text colour, accent, heart-rate label, on-watch menu | 38.2 | +2.7 |
| 1.0 | Five time styles + rubber duck mode (default settings) | 48.4 | +10.2 |
| 1.0 | Worst case: LCD style with ducks | 53.6 | |


The worst case uses about 42 % of the limit, which leaves room for future features.

## Techniques

### Fonts: subset, pre-rasterised, loaded once

System fonts carry every glyph. The face's bitmap fonts carry only what they display:

| Font | Glyphs | Used for |
|------|--------|----------|
| `time` | `0123456789:` (11) | Hours and minutes (Classic) |
| `num12` | `0123456789%d-,.` (15) | Seconds, moon percent, tile values |
| `num13` | `0123456789%d-` (13) | Body Battery, battery days |
| `num15` | `0123456789-` (11) | Current heart rate |
| `month` | the 21 distinct letters of the twelve month names | Month line |
| `label` | `A–Z 0–9 space -` (38) | Box labels, week number, REST/MAX, KM/MI |

Each glyph is cropped to its ink, and the side bearings move into the BMFont `xoffset`/`xadvance` fields instead of
the atlas. The small fonts' atlases are 313–474 bytes as PNG. See [Bitmap font pipeline](../graphics/fonts.md).

All fonts are loaded **once** in `onLayout`, never in `onUpdate`.

### Only the chosen time font is resident

Three of the five time styles are bitmap fonts, with atlases of 4–5 KB each as PNG. `TimeDisplay.configure` loads only the selected one
and drops the reference to the previous one, so switching style frees the old atlas:

```js
_font = null;
var font = null;
if (style == Settings.TIME_CLASSIC) {
    font = WatchUi.loadResource(Rez.Fonts.TimeFont) as FontResource;
} else if (style == Settings.TIME_BOLD) { ... }
_font = font;
```

The LCD and dot-matrix styles load **no** font at all: they are geometry drawn in code.

### Icons as run-length data, not bitmaps

The spec required icons whose colour can change at draw time (several icons turn red or green under the colour
rules). Pre-coloured bitmaps would need one resource per colour. Instead each pixel icon is stored as a flat array of
`(row, x, width)` triples and drawn with `fillRectangle`:

```js
const HEART_RUNS = [
    0, 1, 3,  0, 5, 3,
    1, 0, 9,
    ...
    8, 3, 3
] as Array<Number>;
```

A 9 × 9 heart is 30 numbers. The arrays are **flat**: an array of arrays would create one object per row, and in
Monkey C each object has a header cost. See [Icons drawn in code](../graphics/icons.md).

### Flat constant tables

The same rule applies elsewhere:

- `DOT_GLYPHS`: ten 5×7 digits as **70 numbers** (one 5-bit row each) in a single array, not 10 arrays of 7.
- `SEG_MASK`: ten 7-segment digits as **10 bit masks**.
- `DUCK_BODY`: 12 points as 24 interleaved floats.
- `BOXES`: the one nested table, read only in `onLayout`.

### Preallocated, reused working arrays

| Array | Size | Refilled by |
|-------|------|-------------|
| `HeartRateGraph.bpm` | 24 | `rebuild()` every 10 minutes |
| `_graphBarX`, `_graphBarTop`, `_graphBarColour` | 24 each | `onLayout`, `layoutGraph()` |
| `_secondsAdvance` | 10 | `onLayout` |
| `_monthCharX` | 9 (longest month) | `refreshDate()` once a day |
| `_boltPoints` | 6 points | every `drawBolt` |
| `TimeDisplay._p4/_p5/_p6/_p12` | 4–12 points | every polygon fill |
| `_tileCentreX` | 3 | `onLayout` |

### Allocation confined to rare events

| Where | Allocates | How often |
|-------|-----------|-----------|
| `onLayout`, `TimeDisplay.configure` | fonts, scaled boxes, polygon templates | once, and on a settings change |
| `refreshHeartHistory` | `SensorHistory` iterator and samples | once every 10 minutes (when a new bar starts) |
| `refreshDate` | weekday, week and month strings | once a day |
| Other refreshes | a new string when the displayed value changes | at most once a minute per field |
| `onUpdate` draw phase, `onPartialUpdate` | **nothing** | every second |

The 10-minute cadence for sensor history was a deliberate trade-off. The graph's bars are 10 minutes wide, so
reading history more often could not change what is shown.

### Debug code that doesn't ship

The `Demo` module (mockup data, about 1.5 KB) and the logging functions are annotated `(:debug)`. Each has an empty
`(:release)` twin. The release build (`monkeyc -r`) excludes them entirely. Memory figures above are from debug
builds, so the shipped face uses slightly less.

## How memory was measured

```js
(:debug)
private function logMemory(tag as String) as Void {
    var stats = System.getSystemStats();
    System.println("mem[" + tag + "] used=" + stats.usedMemory
        + " free=" + stats.freeMemory + " total=" + stats.totalMemory);
}
```

The workflow is recorded in the project's build skill:

- **After every milestone:** report `mem[minute] used` and the change from the previous commit.
- **Per setting:** temporarily force a setting (for example the LCD style with ducks) to measure the worst case,
  then restore the file.
- **Baseline from an earlier commit:** build it in a throwaway `git worktree`, read the same log line, and remove the
  worktree, so comparisons are like for like.
