---
name: ciq-build
description: Build this Connect IQ watch face, load it into the simulator and report memory use. Use after every code change (CLAUDE.md requires a warning-free build) and at the end of every milestone (memory must be reported). Also covers forcing a time or a setting for testing, and measuring a baseline from an earlier commit.
---

# Build, run and measure

Target: fēnix 8 Solar 47mm (`fenix8solar47mm`, from `manifest.xml`).

## Build

```sh
./build.sh          # bin/WatchFace.prg, with -w (warnings on)
./build.sh run      # build, then load into a running simulator
./build.sh release  # release build (-r, debug code stripped): bin/WatchFace-release.prg
store/package.sh    # signed store package store/InstrumentPanel.iq (local only, refuses demo values)
```

- `build.sh` reads the developer key path from the git-ignored `.env`
  (`GARMIN_DEV_KEY`). Never read, print, copy or pass the key path yourself.
- The build must end with `BUILD SUCCESSFUL` and no `WARNING` lines. Fix every
  warning before moving on.

## Simulator

Start it once per session (it keeps running in the background):

```sh
"$(cat ~/Library/Application\ Support/Garmin/ConnectIQ/current-sdk.cfg)bin/connectiq" >/dev/null 2>&1 &
```

Then run `./build.sh run` in the background and read its output after
about 12 s. To reload, stop the old `monkeydo` (`pkill -f 'monkeydo bin/WatchFace.prg'`)
and run again.

This session cannot capture the screen or the simulator window: macOS denies
both screen recording and window queries. Don't retry. Ask the owner to look at
the simulator or send a screenshot. When a screenshot arrives, list the
differences from the mockup (`design/v4a-*.png`) or the approved preview before
changing code.

## Memory

Debug builds print `mem[onLayout]` and `mem[minute]` lines
(`used=… free=… total=…`). Report `mem[minute] used` at every milestone, and
the change against the previous commit.

- **Per setting:** temporarily force the value in `source/Settings.mc` (for
  example make `timeFont()` return 2), run, read the log, then restore the file.
  Measure the worst case (for example, rubber duck on).
- **Baseline from the last commit:** build it in a throwaway worktree in the
  scratchpad, copying `.env` in and deleting it afterwards:
  `git worktree add -q <scratch>/base HEAD`, then `cp .env <scratch>/base/`,
  run `./build.sh run` there, read the `mem` lines, then
  `rm <scratch>/base/.env` and `git worktree remove --force <scratch>/base`.

## Forcing data and time (debug builds only)

`source/Demo.mc`:
- `STATE`: 0 for live data, 1 normal, 2 targets met, 3 running low (mockup values).
- `TIME`: minutes after midnight to show (for example `22 * 60 + 22`), or -1 for the clock.

Always restore `STATE = 0` and `TIME = -1` before committing.
`store/package.sh` refuses to package a non-zero STATE.

## Before calling a milestone done

1. The build is warning-free.
2. The simulator runs with no errors in the log.
3. Memory is reported.
4. Stop and let the owner check the simulator. Commit only after they say it
   looks right (CLAUDE.md).
