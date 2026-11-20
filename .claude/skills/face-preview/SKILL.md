---
name: face-preview
description: Render design proposals for this watch face (fonts, glyph replacements, icons, layouts) as pixel-accurate 260 px previews in the 64 MIP colours, and publish a comparison page for the owner to pick from. Use when the owner asks to see options or proposals before anything is built.
---

# Design previews

The owner picks designs from previews rendered on a real simulator
screenshot. Each option is fitted to the space it would occupy on the watch,
before any Monkey C is written. Tooling and fitting rules:
`tools/preview/README.md`.

## Workflow

1. **Set up once:** create the venv and fetch the fonts (README "Setup"). The
   base image is `store/screenshots/normal.png`, or set `PREVIEW_BASE`.
2. **Fit, don't redesign.** Keep every option inside the box the current
   element uses (for the time: 47 px digits, widest time 127 px, baseline
   141), so nothing else on the face moves. Check the widest case over all
   inputs, such as all 1440 times, not just one sample.
3. **Render honestly.** Use the real pixel size, snap to the 64 MIP colours,
   anti-alias only where the watch would (bitmap fonts with `aa`, and primitives
   with `setAntiAlias`), and use hard edges otherwise.
4. **Look before publishing.** Make a contact sheet and Read it. Drop or fix
   options that are broken, unreadable or too small, and say what you dropped
   and why.
5. **Publish a comparison page** (Artifact): one card per option with an ID, the
   full face, a time or value switcher, and facts (size compared with today,
   memory or "drawn in code", licence). Ask for feedback by ID.
6. **Iterate** on the owner's picks. Keep the chosen geometry in the scripts, so
   the Monkey C port reproduces exactly what was approved.

## Porting to the watch

- Shapes become `fillPolygon`, `fillCircle` and `drawLine` calls. Precompute
  the points in `onLayout()` or on a settings change, and only shift them into
  reused scratch arrays while drawing, so `onUpdate()` never allocates.
- Fonts go through `tools/make_fonts.py` (digits only), with the licence copied
  into `tools/fonts/` and `resources/fonts/`.
- Confirm every API with the `ciq-api-check` skill. Build and measure with the
  `ciq-build` skill.
