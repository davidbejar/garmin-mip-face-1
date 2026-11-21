# API verification

Connect IQ's API differs by API level **and by device**. A method can exist in the SDK but be missing from a given
watch. Code that guesses an API name or signature may compile and then fail on the device. The project rule is:
**never guess an API**. Any call not already used in the codebase is confirmed first.

## `tools/ciq_api.py`

The SDK ships its full API reference as HTML. A small standard-library script reads it locally, with no network
access:

```console
$ python3 tools/ciq_api.py Graphics.Dc setAntiAlias
Toybox.Graphics.Dc.setAntiAlias(enabled as Lang.Boolean) as Void
  Enable anti-aliased drawing for primitives This method is not supported for a BufferedBitmap that has a palette.
  Since: API Level 3.2.0
  fēnix® 8 Solar 47mm: SUPPORTED
```

It:

1. Finds the SDK the SDK Manager has selected (`current-sdk.cfg`) or `$CIQ_SDK`.
2. Opens `doc/Toybox/<Module>/<Class>.html` and finds the member's detail block by its anchor id.
3. Strips the HTML and extracts the **signature**, the start of the **description** and **Since: API Level**.
4. Checks the **Supported Devices** list, if the method has one, for the target device.

The exit codes make it usable in scripts:

| Exit | Meaning |
|------|---------|
| 0 | Supported, or no device list (available on every device at that API level) |
| 1 | Page or member not found |
| 2 | Usage error |
| 3 | The method has a device list and the target isn't in it. Don't use it. |

## APIs confirmed this way

The spec marked several API names "(check)" because they were written from memory. Among those confirmed before
use:

| API | Result | How it is used |
|-----|--------|----------------|
| `Dc.setAntiAlias` | API 3.2.0, device listed | Guarded with `dc has :setAntiAlias` anyway |
| `Dc.fillPolygon` | the docs give a **64-point limit** | Largest polygon is the 12-point duck body |
| `Dc.fillCircle`, `Dc.drawLine` | available | Dot matrix, duck, wing |
| `Complications` types `BODY_BATTERY`, `SUNRISE`, `SUNSET`, `HEART_RATE` | available | All four live fields |
| `ActivityMonitor.Info.distance` | unit is **centimetres** | Converted to tenths of km or mi |
| `System.Stats.solarIntensity` | `null` without solar, **negative when not charging** | Shown as `0%` |
| `Graphics.getVectorFont :size` | not documented | Measured: it is the full line height, not the em |

The last row shows what the docs can't answer. The meaning of `:size` was determined in the simulator against the
TTF's `hhea` metrics, and the result is recorded next to the constant that depends on it.

## Permissions follow from the APIs

Because each API was checked, the manifest requests only what the code uses: `ComplicationSubscriber`,
`SensorHistory` and `UserProfile`. `Positioning` was avoided by reading sunrise and sunset from complications rather
than computing them from a location.
