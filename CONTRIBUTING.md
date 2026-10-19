# Contributing to Autopost

Thanks for helping. Bug reports, ideas and pull requests are all welcome. Issues labelled [good first issue](https://github.com/HNagouda/autopost/labels/good%20first%20issue) are small and self-contained, which makes them a good place to start.

## Getting set up

You need macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`). Xcode itself is optional.

```sh
./scripts/build-app.sh                  # builds build/Autopost.app
./scripts/test.sh                       # runs the tests
AUTOPOST_LIBRARY_DIR=/tmp/autopost-dev build/Autopost.app/Contents/MacOS/Autopost
```

The last line runs your build against a throwaway library, so your own posts stay untouched while you experiment.

## Where code goes

Anything that can run without a window, like layout, rendering, export and the Instagram API, lives in `Sources/AutopostCore` and has tests in `Tests/AutopostCoreTests`. The SwiftUI app lives in `Sources/Autopost`. The README's layout section says what each file holds.

The one rule that matters most is that the preview and the export must match. Both go through `FrameLayout` and `TextBoxRenderer`, so put new drawing there rather than drawing something separately in a SwiftUI view.

## Branches

1. Branch off `dev`, for example `feature/rounded-corners`.
2. Open a pull request into `dev`. CI runs the tests and builds the app.
3. Once merged, the [dev build](https://github.com/HNagouda/autopost/releases/tag/dev-build) updates within a few minutes, so you can try your change as a downloaded app.
4. `dev` is merged into `main` when it is ready to ship, and every merge into `main` becomes a release.

## Style

Code reads top to bottom without tricks. Comments say why, not what. Names are full words. Commit messages are one plain sentence about what changed, without prefixes like `feat:`.
