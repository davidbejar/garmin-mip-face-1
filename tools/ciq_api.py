#!/usr/bin/env python3
"""Look up a Connect IQ API in the local SDK docs and check device support.

Usage:  python3 tools/ciq_api.py Graphics.Dc setAntiAlias
        python3 tools/ciq_api.py Graphics getVectorFont
        python3 tools/ciq_api.py WatchUi.WatchFace onPartialUpdate

Prints the signature, description, "Since: API Level" and whether the target
device (fēnix 8 Solar 47mm) is in the method's "Supported Devices" list (a
method with no such list is available on every device at that API level).
Reads the SDK selected in the SDK manager (current-sdk.cfg), or $CIQ_SDK.
Standard library only.
"""
import html
import os
import re
import sys

DEVICE_NAME = "fēnix® 8 Solar 47mm"


def sdk_dir():
    env = os.environ.get("CIQ_SDK")
    if env:
        return env
    cfg = os.path.expanduser("~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
    with open(cfg) as f:
        return f.read().strip()


def clean(fragment):
    fragment = re.sub(r"<[^>]+>", " ", fragment)
    return re.sub(r"\s+", " ", html.unescape(fragment)).strip()


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    scope, member = sys.argv[1], sys.argv[2]
    path = os.path.join(sdk_dir(), "doc", "Toybox", *scope.split(".")) + ".html"
    if not os.path.exists(path):
        print(f"No docs page for Toybox.{scope} ({path})")
        return 1
    raw = open(path, encoding="utf-8").read()
    # Detail blocks: <h3 class="signature" id="<name>-instance_function"> ...
    # up to the next method_details block.
    m = re.search(r'id="' + re.escape(member) + r'-\w+"', raw)
    if not m:
        print(f"{member} not found in Toybox.{scope}")
        return 1
    nxt = raw.find('class="method_details', m.end())
    detail = raw[m.start(): nxt if nxt > 0 else len(raw)]
    block = clean(detail.split(">", 1)[1])
    end = re.search(r"Since: API Level [0-9.]+", block)
    if end:
        block = block[: end.end()]
    sig = re.match(r"[^)]*\)\s*as\s*[\w.]+(?:\s+or\s+[\w.]+)*", block)
    print("Toybox." + scope + "." + re.sub(r"\s+([(),<>])", r"\1", sig.group(0) if sig else member))
    desc = block[len(sig.group(0)) if sig else 0:].split("Parameters:")[0].split("Supported Devices:")[0]
    print("  " + desc.strip()[:400])
    print("  " + (end.group(0) if end else "Since: (not stated)"))
    if "Supported Devices:" in block:
        ok = DEVICE_NAME in block
        print(f"  {DEVICE_NAME}: {'SUPPORTED' if ok else 'NOT LISTED'}")
        return 0 if ok else 3
    print(f"  No device list: available on every device at that API level ({DEVICE_NAME} is API 6.0).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
