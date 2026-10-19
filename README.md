# Autopost

Autopost is a Mac app that puts a white (or any colour) border around photos and exports Instagram-ready JPEGs. It replaces the round trip of editing on the Mac, opening Lightroom mobile, and exporting with a border there.

You group photos into posts, pick an aspect ratio per post, and export the whole post at once. Every photo in a post shares one frame, because Instagram crops every slide of a carousel to the first slide's ratio.

## How the preview stays honest

`FrameLayout` decides where the photo and caption sit on the canvas. The grid, the phone preview and the exporter all call it with the same settings, so what you see in the app is what gets written. Sizes like the border, shadow and caption are fractions of the canvas width, which is why a frame looks the same at 1080 px and at full resolution.

## Layout

```
Package.swift                  SwiftPM package, one library and one app target
Sources/AutopostCore/          everything that can run without a window
  FrameSettings.swift          aspect ratios, border, background, caption settings
  FrameLayout.swift            photo and caption rects on the canvas
  ImageSource.swift            ImageIO decoding (JPEG, HEIC, TIFF, camera RAW) and EXIF
  FrameRenderer.swift          draws the framed image in sRGB with Core Graphics
  PostExporter.swift           numbered JPEGs per post, a few photos in parallel
  Library.swift                posts, photos, presets, export settings
Sources/Autopost/              the SwiftUI app
  LibraryStore.swift           the library, saved to ~/Library/Application Support/Autopost/library.json
  ThumbnailStore.swift         preview images, decoded once off the main thread
  ExportController.swift       runs exports, then reveals them in Finder or sends them with AirDrop
  PostGridView.swift           the photos of a post, framed, drag to reorder
  InspectorView.swift          frame settings for the selected post
  PhonePreviewView.swift       phone mockup window, feed and profile grid, light and dark
Tests/AutopostCoreTests/       layout and formatting tests
scripts/build-app.sh           builds build/Autopost.app
scripts/make-icon.sh           regenerates Resources/AppIcon.icns
```

## Using it

1. Drop folders onto the sidebar. Each folder becomes a post named after it; loose files become one new post.
2. Pick a ratio and border in the inspector. 4:5 (1080 × 1350) is the safe feed default, and 3:4 (1080 × 1440) matches the profile grid tile.
3. Open the phone preview (⌥⌘P) to swipe through the carousel and see the profile grid crop, in light or dark mode.
4. Export with ⌘E, or right-click a post and pick "Export Post As" to switch the ratio and export in one step. "Export and AirDrop" sends the files straight to your phone.

Exports go to `~/Pictures/Autopost Exports/<post name>/` as `<post-name>-01.jpg` and onwards. Re-exporting a post replaces its numbered files, so a post that shrank does not leave old slides behind.

#! NOTE[raw] : RAW files are decoded with Apple's default processing, not your Lightroom edits

Export an edited JPEG or TIFF from Lightroom first and import that.

## Building

Only the Command Line Tools are needed.

```sh
./scripts/build-app.sh         # writes build/Autopost.app
open build/Autopost.app
./scripts/test.sh
```

The build pins the macOS 26.5 SDK because the macOS 27 SDK turns `@State` into a macro whose plugin only ships with Xcode.

CI runs the tests and builds the app on every push to `master` and on pull requests. Pushing a tag like `v1.1` builds the app and attaches `Autopost-v1.1.zip` to a GitHub release. The app is signed ad hoc, so the first launch of a downloaded copy needs right-click → Open.
