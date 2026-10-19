# Autopost

Autopost is a Mac app that puts a white (or any colour) border around photos and exports Instagram-ready JPEGs. It replaces the round trip of editing on the Mac, opening Lightroom mobile, and exporting with a border there.

You group photos into posts, pick an aspect ratio per post, and export the whole post at once. Every photo in a post shares one frame, because Instagram crops every slide of a carousel to the first slide's ratio.

## How the preview stays honest

`FrameLayout` decides where the photo and caption sit on the canvas. The grid, the phone preview and the exporter all call it with the same settings, so what you see in the app is what gets written. Sizes like the border, shadow and caption are fractions of the canvas width, which is why a frame looks the same at 1080 px and at full resolution. Text boxes follow the same rule through `TextBoxRenderer`, which lays text out on a fixed 1000-unit canvas and scales it. Fonts like SF change shape between sizes, so measuring at the real size would make the export wider or narrower than the preview.

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
  LibraryStore.swift           the library, saved to ~/Library/Application Support/Autopost/library.json
  LibraryBackups.swift         timestamped copies of library.json in the Backups folder next to it
  PhotoEditorView.swift        one photo, large, with its text boxes and a filmstrip
  TextBoxOverlay.swift         selecting, dragging and snapping text boxes on the editor canvas
  PhotoInspector.swift         the open photo's own border and position, and text box styling
  ThumbnailStore.swift         preview images, decoded once off the main thread
  ExportController.swift       runs exports, then reveals them in Finder or sends them with AirDrop
  PostGridView.swift           the photos of a post, framed, drag to reorder
  InspectorView.swift          frame settings for the selected post
  PhonePreviewView.swift       phone mockup window, feed and profile grid, light and dark
  InstagramAccount.swift       the optional Instagram connection, token kept in the Keychain
  InstagramSettingsView.swift  Settings tab where the token is pasted
Tests/AutopostCoreTests/       layout, formatting and Instagram response tests
scripts/build-app.sh           builds build/Autopost.app
scripts/make-icon.sh           regenerates Resources/AppIcon.icns
```

## Using it

1. Drop folders onto the sidebar. Each folder becomes a post named after it; loose files become one new post.
2. Pick a ratio and border in the inspector. 4:5 (1080 × 1350) is the safe feed default, and 3:4 (1080 × 1440) matches the profile grid tile.
3. Open the phone preview (⌥⌘P) to swipe through the carousel and see the profile grid crop, in light or dark mode.
4. Double-click a photo to open it in the editor. There you can give that photo its own border and position, and add text boxes (⌘T). Drag a box and it snaps to a 12-column grid, the photo's edges and the middle of the border; hold Shift to place it freely. A new box copies the last one you placed, in the same spot, so repeated text lines up across the carousel. ⌘C and ⌘V copy a box between photos, and "Copy to All Photos" puts it on every slide.
5. Export with ⌘E, or right-click a post and pick "Export Post As" to switch the ratio and export in one step. "Export and AirDrop" sends the files straight to your phone.

Exports go to `~/Pictures/Autopost Exports/<post name>/` as `<post-name>-01.jpg` and onwards. Re-exporting a post replaces its numbered files, so a post that shrank does not leave old slides behind.

Any custom ratio, like 32:9, can be saved with the Save button next to the custom fields, and then shows up in the picker and in "Export Post As". Ratios outside 4:5 to 1.91:1 get a warning, because Instagram crops feed posts to that range.

A deleted post goes to Recently Deleted at the bottom of the sidebar and stays restorable for 30 days. On top of that, Autopost copies `library.json` into `Backups/` at least every 10 minutes while you work and before every delete or restore, keeping the newest 50. File > Restore from Backup lists them.

#! NOTE[raw] : RAW files are decoded with Apple's default processing, not your Lightroom edits

Export an edited JPEG or TIFF from Lightroom first and import that.

## Connecting Instagram

The phone preview can show your real profile, so you see planned posts sitting on top of what is already on your grid. This is optional; without it the preview uses the handle you type and placeholder counts.

It uses Instagram's [API with Instagram Login](https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login), which only works for Business and Creator accounts. The older Basic Display API for personal accounts was shut down in December 2024.

1. Switch your Instagram account to a Business or Creator account in the Instagram app, if it is not one already.
2. Create an app at [developers.facebook.com](https://developers.facebook.com/apps) and add the Instagram product.
3. Under App roles, add your account as an Instagram tester, then accept the invite in Instagram.
4. In the app dashboard, open Instagram > API setup with Instagram business login and click Generate token next to your account.
5. Paste the token in Autopost under Settings (⌘,) > Instagram and click Connect.

The token is kept in your login Keychain under `nl.harsh.autopost.instagram`, never in `library.json`. Dashboard tokens last 60 days. Autopost asks Instagram for a fresh one every time it loads your profile, so the token keeps working as long as you open the app now and then. Instagram only refreshes tokens that are at least a day old, so the first refresh after you paste a new token fails quietly and the token you pasted stays in use.

## Building

Only the Command Line Tools are needed.

```sh
./scripts/build-app.sh         # writes build/Autopost.app
open build/Autopost.app
./scripts/test.sh
```

The build pins the macOS 26.5 SDK because the macOS 27 SDK turns `@State` into a macro whose plugin only ships with Xcode.

CI runs the tests and builds the app on every push to `master` and on pull requests. Pushing a tag like `v1.1` builds the app and attaches `Autopost-v1.1.zip` to a GitHub release. The app is signed ad hoc, so the first launch of a downloaded copy needs right-click → Open.
