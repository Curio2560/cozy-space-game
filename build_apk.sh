#!/usr/bin/env bash
# Exporta o APK debug Android para build/correio-cosmico-debug.apk.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-debug "Android" build/correio-cosmico-debug.apk
