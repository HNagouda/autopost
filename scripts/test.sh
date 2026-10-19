#!/bin/sh
# Runs the tests with only the Command Line Tools installed.
set -eu

CLT="/Library/Developer/CommandLineTools"
# Same SDK pin as build-app.sh. With a non-default SDK, SwiftPM no longer finds the swift-testing macro plugin on its own.
if [ "$(xcode-select -p)" = "$CLT" ] && [ -d "$CLT/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="$CLT/SDKs/MacOSX26.5.sdk"
    exec swift test -Xswiftc -plugin-path -Xswiftc "$CLT/usr/lib/swift/host/plugins/testing" "$@"
fi
exec swift test "$@"
