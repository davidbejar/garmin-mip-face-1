#!/usr/bin/env bash
# Build the watch face. Reads GARMIN_DEV_KEY from .env (not committed).
# Usage: ./build.sh            debug build: bin/WatchFace.prg (memory logging, Demo module)
#        ./build.sh run        debug build, then load into a running simulator
#        ./build.sh release    release build (-r): bin/WatchFace-release.prg, debug code stripped
# The store package (.iq) is built by store/package.sh (local only).
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env
: "${GARMIN_DEV_KEY:?Set GARMIN_DEV_KEY in .env}"

DEVICE=fenix8solar47mm
SDK_DIR="${CIQ_SDK:-$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")}"
SDK_BIN="${SDK_DIR%/}/bin"

mkdir -p bin
if [[ "${1:-}" == "release" ]]; then
    "$SDK_BIN/monkeyc" -f monkey.jungle -d "$DEVICE" -o bin/WatchFace-release.prg -y "$GARMIN_DEV_KEY" -w -r
    exit 0
fi
"$SDK_BIN/monkeyc" -f monkey.jungle -d "$DEVICE" -o bin/WatchFace.prg -y "$GARMIN_DEV_KEY" -w

if [[ "${1:-}" == "run" ]]; then
    # Also push the settings definition so the simulator's settings editor
    # (File > Edit Persistent Storage) can find it.
    "$SDK_BIN/monkeydo" bin/WatchFace.prg "$DEVICE" \
        -a "bin/WatchFace-settings.json:GARMIN/Settings/WATCHFACE-settings.json"
fi
