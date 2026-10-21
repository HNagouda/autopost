#!/bin/sh
# Builds Autopost.app into build/ with only the Command Line Tools installed (no Xcode needed).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Autopost.app"
# CI passes the full release version; local builds use the major.minor from the VERSION file.
VERSION="${VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
# Forks should set their own, e.g. BUNDLE_ID=io.github.yourname.autopost, so their Keychain items and settings are separate.
BUNDLE_ID="${BUNDLE_ID:-io.github.hnagouda.autopost}"

# The macOS 27 SDK turns @State into a macro whose plugin only ships with Xcode; the 26.5 SDK does not.
# Only pinned when it exists, so CI runners with Xcode keep their own SDK.
CLT_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
if [ -z "${SDKROOT:-}" ] && [ -d "$CLT_SDK" ] && [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then
    export SDKROOT="$CLT_SDK"
fi

cd "$ROOT"
# One build per architecture, each in its own folder because both would otherwise write to the same
# output path. lipo then joins them into a universal app that runs natively on Apple Silicon and Intel.
ARCHITECTURES="arm64 x86_64"
for arch in $ARCHITECTURES; do
    swift build -c release --product Autopost --triple "$arch-apple-macosx14.0" --scratch-path ".build/$arch"
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
binaries=""
for arch in $ARCHITECTURES; do
    binaries="$binaries $(swift build -c release --triple "$arch-apple-macosx14.0" --scratch-path ".build/$arch" --show-bin-path)/Autopost"
done
# $binaries is unquoted on purpose, so each path becomes its own argument.
lipo -create $binaries -output "$APP/Contents/MacOS/Autopost"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Autopost</string>
    <key>CFBundleDisplayName</key><string>Autopost</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>Autopost</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.photography</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature so Gatekeeper runs the locally built app without a developer account.
codesign --force --deep --sign - "$APP"
echo "Built $APP"
