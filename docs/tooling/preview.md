# Design preview renderer

Changing a watch face's typography is expensive to get wrong: each attempt costs a Monkey C port, a build and a
simulator check, and the result may still not fit. For the time-font and rubber-duck features, candidates were
judged **before** any Monkey C existed, with a Python renderer that shows them as they would appear on the watch.

Source: `tools/preview/` (about 1,100 lines of Python with Pillow and NumPy).

## What "pixel-accurate" means here

| Watch behaviour | How the renderer reproduces it |
|-----------------|--------------------------------|
| 260 × 260 px screen | Renders at 260 px onto a **real simulator screenshot** of the face, so the candidate is seen in context. |
| 64 colours | Every output pixel is snapped to the nearest of `0x00/0x55/0xAA/0xFF` per channel (`snap()`). |
| Anti-aliased bitmap fonts | Coverage blended, then snapped. |
| Hard-edged fonts and shapes | Binary coverage, no blending. |
| `fillCircle` / `fillPolygon` with `setAntiAlias` | Shapes painted at **8× supersampling** and downsampled, then snapped. |
| Exact placement | The current time is erased from the screenshot. The week number and seconds are cut out and re-placed at the position the new style would produce. |

```python
LEVELS = np.array([0, 85, 170, 255])

def snap(rgb):
    return LEVELS[np.abs(rgb[..., None] - LEVELS).argmin(-1)]
```

## Fitting over every minute

Each candidate is **fitted** before it is shown: it is scaled to the largest size whose digits stay within 47 px and
whose widest time over **all 1,440 minutes** stays within 127 px. Testing only `10:08` would miss the times that
break the layout. That depends on each font's digit widths: a font with a wide 0 fails at `00:00`, and one with a
wide 2 at `22:22`.

```python
def all_times():
    return [f"{h:02d}:{m:02d}" for h in range(24) for m in range(60)]
```

The fitted size and the margin to the side panel are reported for each option, and those numbers went straight
into `make_fonts.py` (Saira at 41 px digits, Kalam at 35 px).

## Scripts

| Script | Produces |
|--------|----------|
| `render.py` | Shared library: TTF fitting, 7-segment and dot-matrix drawing, MIP snapping, compositing onto the screenshot. |
| `build.py` | Round 1: every candidate font fitted to the time's box, four sample times each plus its widest time, a memory estimate, a contact sheet. |
| `ghost.py` | Dot-matrix variants with fractional pitch and supersampled round dots. |
| `duck.py` | Rubber-duck designs in each of the five fonts, from shape functions in unit coordinates. |
| `page.py`, `duck_page.py` | Self-contained HTML comparison pages: one card per option with an ID, the full face, a time switcher, and facts such as size compared with today, memory or "drawn in code", and licence. |

## From preview to production

The workflow, recorded as a project skill so it can be repeated:

1. **Fit, don't redesign.** Every option must fit the box the current element uses.
2. **Render honestly.** Use the real pixel size, the 64-colour palette, and anti-aliasing only where the watch would
   use it.
3. **Look before publishing.** Make a contact sheet, and drop options that are broken or illegible.
4. **Publish a comparison page** and ask for feedback by option ID.
5. **Iterate** on the picks.
6. **Port exactly.** The chosen geometry stays in the scripts. `duck.py`'s `tall_neck()` and
   `TimeDisplay.buildDuck()` use the same unit coordinates, so the watch reproduces what was approved.

## Documentation figures

The figures on this site use the same "derive it from the source" approach. `tools/docs/make_assets.py` parses the
constant arrays in `Icons.mc` and `TimeDisplay.mc` and the spec constants in the view, and renders the icon grids,
the 7-segment and dot-matrix glyph sheets, the layout map and the font atlases. If an icon changes in code, running
the script updates the docs.
