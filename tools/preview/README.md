# Design previews

Renders candidate designs onto a real 260 px simulator screenshot, snapped to
the 64 MIP colours, so they can be compared before any Monkey C is written.
Used for the time-font and rubber-duck rounds of 2026-11-20.

## Setup

```sh
python3 -m venv tools/preview/.venv
tools/preview/.venv/bin/pip install pillow numpy
tools/preview/fetch_fonts.sh          # candidate fonts into cache/ (git-ignored)
```

The base image is `store/screenshots/normal.png` (local only, see
`store/screenshots/README.md` for how it is taken). Point `PREVIEW_BASE` at any
other 260 px screenshot of the normal state to use that instead.

## Scripts

All write to `tools/preview/out/` (git-ignored).

| Script | What it renders |
|---|---|
| `render.py` | Shared library: TTF fitting, 7-segment and dot-matrix drawing, MIP colour snapping, compositing onto the screenshot (erases the time, re-places the week number and seconds). |
| `build.py` | Round 1: every candidate font fitted to today's box (47 px digits, widest time ≤ 127 px), four times each plus its widest time; `meta.json`, `mem.json`, `sheet.png`. |
| `ghost.py` | Dot-matrix variants modelled on the GHOSTLINE reference (C5–C7). |
| `duck.py` | Rubber-duck designs in the five agreed fonts. `tall_neck()` is the shape built in `source/TimeDisplay.mc`. |
| `page.py`, `duck_page.py` | Build the comparison pages (`time-fonts.html`, `rubber-duck.html`) from `template.html` / `duck_template.html`. |

Run in order: `build.py`, `ghost.py`, `page.py`; `duck.py` and `duck_page.py`
need only `build.py` (for the shared base image).

## Fitting rules

Every option must fit the box today's time uses, so nothing else moves:

- digits at most 47 px tall, baseline at y 141, left edge at x 16;
- the widest possible time at most 127 px wide (the week number, 28 px, sits
  3 px to its right and must clear the side panel at x 176).

`render.py` checks the widest time over all 1440 minutes, not just a sample.
