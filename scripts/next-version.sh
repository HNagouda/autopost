#!/bin/sh
# Prints the next release version: VERSION holds major.minor (like 1.0), and the patch counts up from the
# highest v1.0.N tag already released. Bump VERSION to start 1.1.0 or 2.0.0.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(tr -d '[:space:]' < "$ROOT/VERSION")"

case "$BASE" in
    *[!0-9.]* | "" | .* | *. ) echo "VERSION must look like 1.0, got '$BASE'" >&2; exit 1 ;;
esac

LAST_PATCH="$(git -C "$ROOT" tag --list "v$BASE.*" | sed "s/^v$BASE\.//" | grep -E '^[0-9]+$' | sort -n | tail -1)"
if [ -z "$LAST_PATCH" ]; then
    echo "$BASE.0"
else
    echo "$BASE.$((LAST_PATCH + 1))"
fi
