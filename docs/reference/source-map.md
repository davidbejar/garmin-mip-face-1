# Source map

## Repository layout

```text
.
├── manifest.xml                 app id, watchface type, product, permissions, minApiLevel
├── monkey.jungle                build configuration
├── build.sh                     debug / run / release builds (key path from .env)
├── mkdocs.yml                   this documentation site
├── design/
│   ├── spec.md                  the design spec: coordinates, type, colours, rules, data, power
│   └── v4a-*.png                mockups: normal, targets met, running low
├── source/                      Monkey C (2,488 lines)
├── resources/
│   ├── fonts/                   generated BMFont .fnt + .png, fonts.xml, OFL licences
│   ├── settings/                properties.xml (stored indexes), settings.xml (option lists)
│   ├── strings/strings.xml      app name, settings titles and option names
│   └── drawables/               launcher icon (SVG)
├── tools/
│   ├── make_fonts.py            TTF → bitmap font generator
│   ├── ciq_api.py               local SDK-docs API checker
│   ├── fonts/                   source TTFs and licences
│   ├── preview/                 design preview renderer and comparison pages
│   └── docs/make_assets.py      figures for this site, derived from the source
├── docs/                        this site's Markdown
└── .claude/skills/              versioned workflows: ciq-build, ciq-api-check, face-preview
```

## Monkey C files

| File | Lines | Kind | Contents |
|------|------:|------|----------|
| `InstrumentPanelView.mc` | 1,194 | class | Layout constants, `onLayout`, `onUpdate`, `onPartialUpdate`, refresh functions with change keys, draw functions, complications, debug hooks |
| `TimeDisplay.mc` | 602 | class | Five time styles, 7-segment and dot-matrix geometry, duck construction, polygon offsetting |
| `Icons.mc` | 227 | module | Run-length icon data, `drawRuns`, bolt, moon terminator, battery |
| `SettingsMenu.mc` | 90 | classes | `Menu2` settings, option list delegate |
| `HeartRateGraph.mc` | 77 | class | Sensor-history bucketing into 24 bars |
| `Settings.mc` | 70 | module | Property keys, option tables, validated reads |
| `DateUtil.mc` | 56 | module | ISO weeks, leap years, day of year, weekday of 31 December |
| `MoonPhase.mc` | 40 | module | Phase, percent lit, label |
| `Demo.mc` | 35 | module, debug | Mockup values, pinned time |
| `InstrumentPanelApp.mc` | 32 | class | App entry, settings view, settings-changed hook |
| `ColourRules.mc` | 29 | module | Thresholds and the graph-bar colouring rule |
| `InstrumentPanelDelegate.mc` | 18 | class | Power-budget callback |
| `Palette.mc` | 18 | module | Fixed MIP colours |

## Key functions

| Function | File | Called | Allocates |
|----------|------|--------|-----------|
| `onLayout(dc)` | View | once, and on layout changes | yes: fonts, scaled tables |
| `onUpdate(dc)` | View | every second awake, every minute asleep | only inside refreshes, on change |
| `onPartialUpdate(dc)` | View | every second asleep | no |
| `onComplicationChanged(id)` | View | on system push | no, only stores a value |
| `reloadSettings()` | View | settings change | yes: via `TimeDisplay.configure` |
| `TimeDisplay.configure(...)` | TimeDisplay | layout, settings change | yes: font, polygon templates |
| `TimeDisplay.layout(dc, h, m)` | TimeDisplay | once a minute | no |
| `TimeDisplay.draw(dc, ink)` | TimeDisplay | every frame | no |
| `HeartRateGraph.rebuild(now)` | HeartRateGraph | every 10 minutes | yes: `SensorHistory` iterator |
| `Icons.drawRuns(...)` | Icons | every frame | no |
| `ColourRules.graphBarColours(...)` | ColourRules | after each graph rebuild | no |
| `DateUtil.isoWeek(...)` | DateUtil | once a day | no |
| `MoonPhase.phase(t)` | MoonPhase | once a minute | no |
