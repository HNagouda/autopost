#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# iconutil requires the directory name to end in .iconset.
swift "$ROOT/scripts/make-icon.swift" "$WORK/AppIcon.iconset"
mkdir -p "$ROOT/Resources"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"
echo "Wrote $ROOT/Resources/AppIcon.icns"
