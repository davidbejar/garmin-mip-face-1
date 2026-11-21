# Decision log

Every place where the shipped face differs from the original spec or mockup was decided explicitly, recorded in the
spec or a commit message, and has a reason. This page collects them.

## Product decisions

| Decision | Instead of | Reason |
|----------|-----------|--------|
| Seconds always on in low power, through partial updates | Hiding the seconds in low power (spec v1) | Owner's request. Kept within the power budget by a clip-only repaint, with a defined fallback. |
| Always 24-hour time | Following the device's 12/24 h setting | Owner's decision, recorded in the spec (§7). The time box and its widest-time budget assume `HH:MM`. |
| Text and accent options exclude red, green and blue | A broader list including dark green, dark red, blue, red, green | Those colours would make some colour-rule warnings invisible. |
| `REST` / `MAX` heart-rate label setting | Resting heart rate only | Added as an option. `MAX` reuses the graph's data (the tallest bar). |
| Five time styles and rubber duck mode | One time font | Picked from rendered previews. All five fit the original time box exactly. |
| `REST` / `MAX` label in the text colour (2026-11-21) | Grey like the other small labels | It was too light to read on the watch. It now matches the week number, which uses the same font. |
| Handwritten at 44 px, glyphs narrowed to 84 % (2026-11-21) | 35 px at full width | It looked short next to the other styles. Chosen from rendered options at 41, 44 and 47 px. |
| Duck colours fixed (yellow, orange beak) | Beak in the accent colour | A magenta or amber beak no longer reads as a duck. |

## Engineering decisions

| Decision | Alternatives considered | Reason |
|----------|-------------------------|--------|
| Bitmap fonts generated from the mockup's TTFs | System fonts | System fonts were too wide at 64 px and too soft at 7 px on MIP. |
| Hand-drawn 5×7 digits in the label font | The hinted renderer's output | Hinting produced a 5 that read as 6, a split 4, and stray pixels. |
| Week number in the 7 px label font | The mockup's 11 px font | At `04:44` the 11 px text (30–31 px) overlapped the side panel. The label font (27–28 px) clears it at every minute. |
| Heart-rate digits SemiBold, fixed width, 2 px gaps | Bold, proportional | Bold closed the counters of 0, 6 and 9 and ran "77" together. Fixed width stops the number shifting. |
| Sun times in SemiBold, lighter than the box numbers | Same weight as the box numbers | Owner's choice after comparing weights in the simulator. |
| Sunrise and sunset from complications | `Weather` with a stored position | Avoids the `Positioning` permission. |
| Heart-rate history re-read every 10 minutes | Every minute | Bars are 10 minutes wide. Reading `SensorHistory` allocates. |
| Heart-rate fallback only while ≤ 10 minutes old | Always show the newest sample | A stale number is misleading. `--` is honest. |
| Graph window shrinks to available history, always 24 bars | Fixed 4 h window | Partial history fills the box instead of leaving it mostly empty. |
| Partial update fills exactly the clip | `dc.clear()` | Touches only the pixels that can change. |
| Battery red only when the device reports days | Also on a low percent | The rule is defined in days. A percent isn't comparable. |
| Steps bar under the middle tile | Under the steps value in any column | The circle narrows at the bottom, so side columns would clip the bar. |
| Settings stored as indexes | Stored colour values | Only valid MIP colours can ever be drawn. Lists can grow. |
| Only the selected time font loaded | All three bitmap time fonts | Only one time-font atlas is resident at a time. |
| LCD and dot matrix drawn in code | Bitmap fonts (for example DSEG, a 7-segment TTF) | No font resource to load, and exact control of slant, segment gaps and dot size. |
| Steps icon redrawn as shoe prints | The mockup's 8 px prints | At real size the mockup's prints read as two dots. |
| Sunrise and sunset icons redesigned | The mockup's icons | Chosen for legibility on the MIP screen: a solid half-sun, a horizon and a direction triangle. |

## Decisions that went through previews

The time styles and the duck shape went through rounds of rendered options with IDs (fonts `A6`, `B4`, `C7`, `D2`;
duck "option B"). The chosen parameters are recorded precisely: for example, for the 7-segment style, width 23,
stroke 5, slant 0.10, pitch 28, colon 12, hard edges, and for the dot matrix, 5.5 × 6.6 px pitch and 5.8 px dots.
The code reproduces them exactly. See [Design preview renderer](../tooling/preview.md).
