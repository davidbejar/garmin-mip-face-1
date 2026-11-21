# Build, debug and release

## Project files

| File | Purpose |
|------|---------|
| `manifest.xml` | App ID, type `watchface`, entry class, the single product `fenix8solar47mm`, `minApiLevel` 4.2.1, three permissions, language. |
| `monkey.jungle` | Build configuration: `project.manifest = manifest.xml`. |
| `resources/` | Fonts (`.fnt` + `.png`), settings (`properties.xml`, `settings.xml`), strings, the launcher icon (SVG). |
| `source/` | 13 Monkey C files. |
| `build.sh` | Wrapper around the SDK's `monkeyc` and `monkeydo`. |

## `build.sh`

```sh
./build.sh          # debug build: bin/WatchFace.prg (memory logging, Demo module)
./build.sh run      # debug build, then load into a running simulator
./build.sh release  # release build (-r): bin/WatchFace-release.prg, debug code stripped
```

- **The signing key never appears in the repository.** Its path is read from a git-ignored `.env`
  (`GARMIN_DEV_KEY`), and `.gitignore` also excludes `*.der`, `*.pem` and `developer_key*` as a second line of
  defence.
- **The SDK is located automatically** from the SDK Manager's `current-sdk.cfg`, or from `$CIQ_SDK`, so the script
  works for whichever SDK version is selected.
- **Warnings are on** (`-w`), and the project rule is that a build with any warning isn't done.
- **`run` also pushes the settings JSON** to the simulator (`-a bin/WatchFace-settings.json:GARMIN/Settings/…`), so
  its settings editor can find the face's settings.
- `set -euo pipefail` stops the script at the first failure.

## Debug and release builds from one source

Monkey C supports **build annotations**. A function or module marked `(:debug)` is compiled only into debug builds,
and one marked `(:release)` only into release builds (`monkeyc -r`). The face uses pairs of implementations with the
same signature:

```js
(:debug)
private function logMemory(tag as String) as Void {
    var stats = System.getSystemStats();
    System.println("mem[" + tag + "] used=" + stats.usedMemory + " free=" + stats.freeMemory + " total=" + stats.totalMemory);
}

(:release)
private function logMemory(tag as String) as Void {
}
```

| Hook | Debug build | Release build |
|------|-------------|---------------|
| `logMemory(tag)` | prints heap usage after layout and every minute | empty |
| `logGraph()` | prints bar count, newest sample, resting HR, all 24 bpm values | empty |
| `applyDemo(dc)` | overrides live data with a mockup state | empty |
| `demoActive()` | `Demo.STATE != 0` | `false` |
| `demoMinute(m)` | `Demo.TIME` if set, else the real minute | the real minute |
| `module Demo` | mockup values, about 1.5 KB | not compiled |

The call sites stay the same in both builds, and the release binary contains no demo data, logging strings or debug
branches.

## Demo mode

`source/Demo.mc` turns the simulator into a test fixture:

```js
const STATE = 0;    // 0 = live data, 1 = normal, 2 = targets met, 3 = running low
const TIME = -1;    // minutes after midnight to show, or -1 for the clock
```

- `STATE` 1–3 feeds the exact values read off the three design mockups (battery, solar, Body Battery, calories,
  steps, distance, heart rate, resting heart rate and all 24 graph bars) through the **real** formatting, layout and
  colour-rule code. The rendering can then be compared against the mockups, and every colour rule can be triggered
  on demand.
- `TIME` pins the displayed hours and minutes, for example `12 * 60 + 25` so that two 2s appear for the rubber duck.
- Both must be committed as `0` and `-1`. The local packaging script refuses to build a store package when
  `STATE ≠ 0`, so a demo build can't be shipped by accident.

## Release and packaging

1. `./build.sh release` builds a release `.prg` to check that it compiles without the debug code.
2. A local, git-ignored packaging script exports the signed `.iq` store package (`monkeyc -e -r -w`). It first
   checks that `Demo.STATE` is `0`.
3. The store version is tagged in git (`v1.0.0`) on the commit whose source matches the uploaded package.

## Simulator workflow

```sh
connectiq &              # start the simulator once
./build.sh run           # build and load; repeat after each change
```

The project's build skill also documents:

- **forcing a setting** (temporarily returning a fixed value from `Settings.timeFont()`) to measure the worst-case
  memory or take a screenshot of a given style, then restoring the file
- **measuring a baseline** by building an earlier commit in a throwaway `git worktree`

Low-power behaviour is tested with the simulator's Always-On display mode (see [Low power](../architecture/low-power.md#verification)).
