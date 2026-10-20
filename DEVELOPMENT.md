# Developing Autopost

[![CI](https://github.com/HNagouda/autopost/actions/workflows/ci.yml/badge.svg)](https://github.com/HNagouda/autopost/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)

Autopost is a native SwiftUI app for macOS 14 and later, built with Swift Package Manager. This page covers how it works, how to build it, and how releases happen. The [README](README.md) is the page for people using the app.

## Building and running

You only need the Xcode Command Line Tools (`xcode-select --install`), not Xcode itself.

```sh
git clone https://github.com/HNagouda/autopost.git
cd autopost
./scripts/build-app.sh      # writes build/Autopost.app
./scripts/test.sh           # runs the tests
open build/Autopost.app
```

To try a change without touching your own posts, point the app at a throwaway library:

```sh
AUTOPOST_LIBRARY_DIR=/tmp/autopost-dev build/Autopost.app/Contents/MacOS/Autopost
```

If you ship your own build, set your own bundle identifier, so your Keychain items and settings never mix with anyone else's build:

```sh
BUNDLE_ID=io.github.yourname.autopost ./scripts/build-app.sh
```

With only the Command Line Tools installed, the build pins the macOS 26.5 SDK, because the macOS 27 SDK turns `@State` into a macro whose plugin only ships with Xcode. With Xcode installed, its own SDK is used.

## How the preview stays honest

`FrameLayout` decides where the photo and caption sit on the canvas. The grid, the editor, the phone preview and the exporter all call it with the same settings, so what you see in the app is what gets written. Sizes like the border, shadow and caption are fractions of the canvas width, which is why a frame looks the same at 1080 px and at full resolution.

Text boxes and the caption follow the same rule through `TextBoxRenderer`, and the preview draws them with the exporter's own Core Text code. Text is laid out on a fixed 1000-unit canvas and then scaled. Fonts like SF change shape between sizes, so laying text out at the real size would make the export wider or narrower than the preview.

Exports are sRGB JPEGs, 1080 px wide by default, because Instagram stores feed photos at that width and resamples anything larger itself. Light output sharpening offsets the softening from downscaling, and EXIF is kept with orientation reset and GPS removed unless the user opts out.

## Layout

```
Package.swift                  SwiftPM package, one library and one app target
Sources/AutopostCore/          everything that can run without a window
  AspectRatio.swift            built-in ratios, saved ratios, and the ratios the Instagram feed allows
  FrameSettings.swift          border, background and caption settings, plus per-photo adjustments
  FrameLayout.swift            photo and caption rects on the canvas
  TextBox.swift                text boxes and the Core Text code that lays them out and draws them
  TextSnapping.swift           the grid and guide lines a dragged text box snaps to
  ImageSource.swift            ImageIO decoding (JPEG, HEIC, TIFF, camera RAW) and EXIF
  FrameRenderer.swift          draws the framed image in sRGB with Core Graphics
  PostExporter.swift           numbered JPEGs per post, a few photos in parallel
  Library.swift                posts, photos, presets, export settings, Recently Deleted
  CodableDefaults.swift        lets a library saved by an older version still load
  InstagramAPI.swift           profile, recent posts and token refresh from graph.instagram.com
Sources/Autopost/              the SwiftUI app
  AppIdentity.swift            the bundle identifier that names Keychain items and pasteboard data
  LibraryStore.swift           the library, saved to Application Support/Autopost/library.json
  LibraryBackups.swift         timestamped copies of library.json in the Backups folder next to it
  ThumbnailStore.swift         preview images, decoded once off the main thread
  ExportController.swift       runs exports, then reveals them in Finder or sends them with AirDrop
  PostGridView.swift           the photos of a post, framed, drag to reorder
  InspectorView.swift          frame settings for the selected post
  TextStyleControls.swift      font, size, style and spacing controls shared by text boxes and the caption
  PhotoEditorView.swift        one photo, large, with its text boxes, a filmstrip and keyboard handling
  TextBoxOverlay.swift         selecting, dragging and snapping text boxes on the editor canvas
  PhotoInspector.swift         the open photo's own border and position, and text box styling
  PhonePreviewView.swift       phone mockup window, feed and profile grid, light and dark
  InstagramAccount.swift       the optional Instagram connection, token kept in the Keychain
Tests/AutopostCoreTests/       layout, text, snapping, library loading and Instagram response tests
scripts/build-app.sh           builds build/Autopost.app
scripts/test.sh                runs the tests
scripts/next-version.sh        prints the version the next release on main will get
scripts/make-icon.sh           regenerates Resources/AppIcon.icns
```

The library lives in `~/Library/Application Support/Autopost/library.json`. `LibraryBackups` copies it into `Backups/` next to it at least every 10 minutes and before every delete or restore, keeping the newest 50. New settings must decode with a default (see `CodableDefaults.swift`), so a library saved by an older version always loads.

## Connecting Instagram

The phone preview can show the user's real profile. It uses Instagram's [API with Instagram Login](https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login), which only works for Business and Creator accounts. The older Basic Display API for personal accounts was shut down in December 2024.

1. Switch your Instagram account to a Business or Creator account, if it is not one already.
2. Create an app at [developers.facebook.com](https://developers.facebook.com/apps) and add the Instagram product.
3. Under App roles, add your account as an Instagram tester, then accept the invite in Instagram.
4. In the app dashboard, open Instagram > API setup with Instagram business login and click Generate token next to your account.
5. Paste the token in Autopost under Settings (⌘,) > Instagram and click Connect.

The token is stored in the user's login Keychain under `<bundle identifier>.instagram`, never in `library.json`, and is only sent to `graph.instagram.com`. Dashboard tokens last 60 days, and Autopost asks for a fresh one each time it loads the profile, so the token keeps working as long as the app is opened now and then. Instagram only refreshes tokens that are at least a day old, so the first refresh after pasting a new token fails quietly and the pasted token stays in use.

## Branches and releases

Work happens on feature branches, which merge into `dev` through pull requests. `dev` merges into `main` when it is ready to ship, and `main` only takes pull requests from `dev`.

```
feature/text-shadows ──PR──▶ dev ──PR──▶ main
       CI tests            dev build     release v1.0.N
```

- Every pull request runs the tests and builds the app.
- Every push to `dev` replaces the [dev prerelease](https://github.com/HNagouda/autopost/releases/tag/dev-build) with a fresh `Autopost-dev.zip`, so there is always a build of the latest work to try.
- Every merge into `main` publishes the next release, with notes generated from the merged pull requests.

The `VERSION` file holds the major and minor version, like `1.0`. Each release on `main` takes the next patch number, so releases go `v1.0.0`, `v1.0.1`, and so on. To start `1.1.0` or `2.0.0`, change `VERSION` in the pull request that should carry it. `scripts/next-version.sh` prints the version the next release will get.

Releases are signed ad hoc, not with an Apple Developer ID, so macOS asks users to approve the app once in System Settings → Privacy & Security. Notarizing would remove that step, and needs a paid Apple Developer account.
