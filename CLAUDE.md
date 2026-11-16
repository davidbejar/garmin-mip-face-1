# fēnix 8 Solar watch face

A Connect IQ watch face written in Monkey C.

## Target
- Device: Garmin fēnix 8 Solar 47mm. Round 260 × 260 px MIP screen, 64 colours, always on. API level 6.0.
- The device ID is in `manifest.xml` (expected `fenix8solar47mm`; confirm it there).
- SDK: Connect IQ 9.3.0 or newer.

## Design
- The design is final. Build exactly what `design/spec.md` describes. Do not redesign.
- Mockups: `design/v4a-normal.png`, `design/v4a-targets-met.png`, `design/v4a-running-low.png`.
- If the spec and a mockup disagree, ask before choosing.

## Build and run
- Build: `monkeyc -f monkey.jungle -d <device-id> -o bin/WatchFace.prg -y <path-to-developer-key>`
- Run: start the simulator with `connectiq`, then `monkeydo bin/WatchFace.prg <device-id>`
- The developer key lives outside this repository. Ask me for its path. Never read, copy or commit it.
- Build after every change and fix all warnings before moving on.

## Rules
- Position everything from `dc.getWidth()` and `dc.getHeight()`, scaled from the 260 px spec. No hard-coded pixels.
- Use only the 64 MIP colours (each channel 0x00, 0x55, 0xAA or 0xFF).
- No object allocation inside `onUpdate()`. Load fonts and bitmaps once, in `onLayout()` or `initialize()`.
- Every data field handles null and shows the fallback from the spec.
- Low power: full redraw once a minute, and the seconds are always on: `onPartialUpdate` redraws only the
  seconds area (clipped) every second. This is a deliberate decision by the owner. Never remove `onPartialUpdate`,
  never hide or freeze the seconds in low power, and never "simplify" this back to once-a-minute updates.
  The only exception: if `onPowerBudgetExceeded` is called, stop partial updates and hide the seconds while asleep.
  If a change risks the power budget, ask first; do not drop the seconds to fix it.
- Some API names in the spec are marked "(check)". Confirm them in the Connect IQ API docs
  (https://developer.garmin.com/connect-iq/api-docs/) before using them. Do not guess an API.
- Request only the permissions the code uses.
- Watch faces have a tight memory limit. Prefer drawing shapes in code to loading images. Report memory use after each milestone.

## How to work
- Work in small milestones, in this order, and stop after each so I can check the simulator:
  1. Time, seconds, week number, date block.
  2. The three outlined boxes and the side panel, with battery, solar, Body Battery and moon.
  3. Sunrise and sunset row.
  4. Heart-rate box with the bar graph.
  5. Tile row: calories, steps with bar, distance.
  6. Colour rules.
  7. Low-power behaviour.
  8. Settings for text colour and accent.
- Commit after each milestone that builds and looks right.
- When I send a simulator screenshot, compare it to the mockup and list the differences before changing code.
