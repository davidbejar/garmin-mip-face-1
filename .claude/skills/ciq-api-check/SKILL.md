---
name: ciq-api-check
description: Confirm a Connect IQ (Toybox) API before using it - signature, minimum API level and whether the fēnix 8 Solar 47mm supports it - from the SDK docs installed locally. Use whenever the spec marks an API "(check)", before calling any Toybox method not already used in this codebase, and when unsure of a parameter type.
---

# Check a Connect IQ API

CLAUDE.md: never guess an API. The installed SDK ships the full API docs, so
check there first. No web search is needed.

```sh
python3 tools/ciq_api.py <Module[.Class]> <member>
python3 tools/ciq_api.py Graphics.Dc setAntiAlias
python3 tools/ciq_api.py Graphics getVectorFont
python3 tools/ciq_api.py WatchUi.WatchFace onPartialUpdate
```

It prints the signature, the description, `Since: API Level` and one of:
- `fēnix® 8 Solar 47mm: SUPPORTED`: listed for our device (exit 0).
- `NOT LISTED`: the method has a device list without our watch (exit 3). Don't use it.
- `No device list`: available on every device at that API level (exit 0).

Exit 1 means the page or member wasn't found. Check the spelling and module path
(`Toybox/<Module>/<Class>.html` under the SDK's `doc/` folder).

Notes:
- The manifest's `minApiLevel` is 4.2.1, and the device runs API 6.0.
- For an optional capability, also guard the call at runtime, as the code does
  for anti-aliasing: `dc has :setAntiAlias`.
- Record what you confirmed in the code comment or the commit message
  (method, API level, device support), so the check isn't repeated.
- For complications, also check the `Complications.Type` constant on
  `Toybox/Complications.html`.
