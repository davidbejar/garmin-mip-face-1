# Testing and verification

Connect IQ has a unit-test framework, but most of what can go wrong in a watch face is visual or temporal: a label
one pixel into a border, a value that freezes in low power, a rule that never fires, a layout that breaks at one
particular minute. Verification here combines automated checks, a deterministic simulator fixture, exhaustive
offline checks, and human review against mockups.

## The layers

| Layer | What it catches | How |
|-------|-----------------|-----|
| Compiler with type checking and `-w` | Type errors, nullability mistakes, unused or unreachable code | Every change. A build with a warning doesn't count. |
| API verification | Calls that don't exist or aren't supported on the device | `tools/ciq_api.py` before any new Toybox call |
| Exhaustive layout checks | A time style that overflows at some minute | All 1,440 times rendered per style in the preview tooling |
| Deterministic fixture | Formatting, layout and colour-rule regressions | `Demo.STATE` 1–3 feeds the mockup values through the real code |
| Pinned time | Rubber ducks, wide times, rollover | `Demo.TIME` |
| Simulator review against mockups | Pixel-level layout differences | The owner compares each milestone with `design/v4a-*.png`. Differences are listed before any fix. |
| Low-power simulation | Partial-update timing, sleep and wake, budget fallback | Simulator Display Mode → Always-On |
| Memory logging | Regressions in heap use | `mem[minute]` every milestone, worst-case settings forced |
| Offline algorithm checks | Calendar maths edge cases | `DateUtil` ported to Python and compared with `isocalendar()` for 1990–2099 |
| Device | Real power budget, real sensors, Garmin's review | Installed from the store on a fēnix 8 Solar |

## The spec's "done when" list

From `design/spec.md` §11, as achieved:

- [x] The simulator screenshot matches `v4a-normal.png` in layout and proportions.
- [x] All colour rules in §6 work, tested with the three demo states.
- [x] Every field shows its fallback when its data is `null`.
- [x] Nothing is clipped by the round edge (steps bar in the middle column, panel clearance at every minute).
- [x] Low power redraws once a minute. The seconds stay on through partial updates and are hidden only after a
      power-budget fallback (the requirement was changed deliberately, see [decisions](decisions.md)).
- [x] Builds for `fenix8solar47mm` with no warnings.

## Bugs found by verification

| Found by | Problem | Fix |
|----------|---------|-----|
| Checking the midnight rollover | At `04:44` the week number ran into the side panel | Label font for the week number, clears by ≥ 3 px at every minute |
| Reading the label font at real size | Malformed 7 px digits (5 → 6, split 4, stray pixels) | Hand-drawn glyphs in the generator |
| Demo comparison | Live complication pushes overwrote demo values between minute refreshes | Demo mode ignores complication callbacks (debug builds only) |
| Simulator settings | The settings editor couldn't find the face's settings | `build.sh run` pushes the settings JSON with `monkeydo -a` |
| Low-power review | `dc.clear()` in the partial update repainted more than needed | Fill exactly the metrics-derived clip |

## What the simulator can't prove

- **`onPowerBudgetExceeded`** is raised only by the real device's budget accounting. The fallback was checked in the
  simulator, but the trigger can only be observed on a watch.
- **The on-watch settings menu** can't be opened from the simulator's watch-face settings. It needs a device check.
- **Sensor history depth** depends on the device. The graph's window-shrinking logic covers the case where it is
  short.
