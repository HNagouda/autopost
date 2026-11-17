<div align="center">

<img src="docs/icon.png" width="128" alt="Autopost icon">

# Autopost

**White borders for Instagram, done properly, on your Mac.**

Drop in your edits, pick a ratio, and get a whole carousel ready to post in one click.

[![Download](https://img.shields.io/github/v/release/HNagouda/autopost?label=download&color=2ea44f)](https://github.com/HNagouda/autopost/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Free and open source](https://img.shields.io/badge/free-open%20source-blue)

<img src="docs/demo.gif" alt="Autopost switching a carousel between ratios, changing the border colour, stacking two photos, laying four photos out on a canvas, and previewing the post on a phone" width="900">

</div>

## Why this exists

Autopost was born out of necessity. I edit in Lightroom on the Mac, and Lightroom on the Mac can't export a photo with a white border. Lightroom mobile can, so every post meant editing on the Mac, opening everything again in Lightroom mobile, and exporting each photo from there with a border. I refused to install Lightroom Classic next to Lightroom just to get borders, and Photoshop would have meant framing every photo one by one. So I built the thing I wanted instead.

You group photos into posts, the way you'd plan a carousel, and pick one shape for the whole post (4:5, 3:4, square and so on). A photo on its own slide is never cropped, only padded with a border. Then you export the whole post at once, or send it straight to your phone with AirDrop.

In full transparency, Autopost is vibe coded. I described what I wanted and [Claude Code](https://claude.com/claude-code) wrote most of the code, while I tested every feature on my own photos and steered it. It's open source, so every line is there to read.

## What it does

- **Every Instagram shape, and your own.** 4:5, 3:4, 1:1, 9:16, 1.91:1, plus wider ones like 3:2 and 16:9. Need something unusual like 32:9? Save it and it sits next to the others.
- **Borders your way.** Any width, white, warm paper, black or any colour you like, or a soft blurred copy of the photo behind it.
- **Crop without losing the border.** Click a photo and press C. The crop shapes the photo, and the post's ratio still decides the border around it.
- **Panoramas across slides.** Spread a wide photo over 2 or 3 slides, so it scrolls past as one picture. The border runs around the outside only, and the photo lines up exactly where one slide meets the next.
- **Stacks.** Put two or three photos above each other on one slide. The gap between them is as wide as the border, so the slide looks like one frame.
- **A canvas for free layouts.** Place any number of photos across up to 20 slides, and let a photo cross from one slide into the next. Blur one as a background, give another a print border, or let Arrange lay them out as an overlay or a grid and press Shuffle until you like it.
- **Camera settings you can edit.** Print what each photo was shot with, rename `ILCE-6400` to Sony a6400 once, or type the settings for a film scan.
- **Text anywhere.** Double-click a photo to add a title, a film stock or a location in any font on your Mac. Text snaps neatly into place, and the next photo's text lands in the same spot, so a whole carousel lines up.
- **A phone preview.** Swipe through the post the way your followers will, in light and dark mode, and see how it crops on your profile grid.
- **Exports Instagram won't mangle.** JPEGs at the size and colour space Instagram expects, so it doesn't squash or shift your colours. Your location is removed from the files by default.
- **Hard to lose work.** Deleted posts wait in Recently Deleted for 30 days, and Autopost keeps backups of your posts as you go. If you move a photo's file, Locate finds it again, along with the other missing photos in that folder.
- **Light, dark and pure black themes.**

<p align="center"><img src="docs/screenshots/canvas-editor.png" alt="The canvas editor with five photos laid out across three slides, one of them selected" width="900"><br>A canvas of five photos across three slides. The dashed lines are where one slide ends and the next begins</p>

<table>
  <tr>
    <td width="62%"><img src="docs/screenshots/editor-grid.png" alt="The photo editor with a title placed on the photo"></td>
    <td><img src="docs/screenshots/phone-feed-light.png" alt="Phone preview showing the first slide of a canvas in a feed"></td>
    <td><img src="docs/screenshots/phone-profile-dark.png" alt="Phone preview showing the profile grid in dark mode"></td>
  </tr>
  <tr>
    <td align="center">Placing text on a photo</td>
    <td align="center">A canvas in a feed</td>
    <td align="center">Your profile grid, in dark mode</td>
  </tr>
</table>

<p align="center"><img src="docs/screenshots/main-amoled.png" alt="Autopost in the pure black theme, with two panoramas among the photos of a post" width="900"><br>The pure black theme, for checking white borders the way an OLED phone shows them. Photos 4 and 6 are panoramas over two slides</p>

## Installing it

1. Download **Autopost-v….zip** from the [latest release](https://github.com/HNagouda/autopost/releases/latest). It's under "Assets" at the bottom of that page.
2. Double-click the zip to unzip it, then drag **Autopost** into your Applications folder.
3. Open Autopost. The first time, macOS says it can't check the app, because it isn't registered with Apple yet. Click Done, then open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the message about Autopost. You only need to do this once.

Autopost needs macOS 14 Sonoma or newer, and runs on both Apple Silicon and Intel Macs.

## Using it

1. **Make a post.** Drag a folder of photos onto the left sidebar. Each folder becomes a post, named after the folder.
2. **Pick a shape and border** on the right. 4:5 is the safe choice for the feed. 3:4 is a little taller and fills the profile grid tile exactly.
3. **Fine-tune single photos.** Double-click a photo to give it its own border or position, or to add text (⌘T).
4. **Lay out the slides.** Select a wide photo and pick Split in the bar below the grid to spread it across 2 or 3 slides. Select two or three photos and press ⌘G to stack them on one slide. Click Canvas in the toolbar to place photos freely across several slides.
5. **Check it on the phone preview** (the phone button above the settings, or ⇧P).
6. **Export.** Press ⌘E, or right-click the post and pick "Export Post As" to choose a shape and export in one go. "Export and AirDrop" sends the photos straight to your phone.

The first time you open Autopost, a short tour shows the shortcuts. Help > Autopost Tour opens it again.

Your exported photos land in **Pictures → Autopost Exports**, in a folder per post, numbered in carousel order.

## Shortcuts

- **⌘Z** undoes the last change, whether that's a delete, a move, a crop or a border tweak. **⇧⌘Z** redoes it.
- **⌘N** makes a new post, with its name ready to type.
- **Delete** removes the selected photos, or the selected post when the sidebar is focused. ⌘⌫ works from anywhere in the main window.
- **← and →** step through the photos, and **1 to 9** moves the selected photo to that spot in the carousel. Type two digits quickly for 10 and up.
- **C** crops the selected or open photo. Hold Shift while dragging to keep the shape, then press Return to apply or Esc to cancel.
- **⌘G** stacks two or three selected photos on one slide, or with fewer selected lets you click the photos to stack, and **⇧⌘G** unstacks them.
- **Canvas** in the toolbar places any number of photos freely across a run of slides. Drag a photo to move it, drag its handles to resize it, and let it cross from one slide into the next.
- **⇧- and ⇧+** make the grid's photos smaller or larger.
- **/** hides or shows the filmstrip in the editor.
- **P** hides or shows the list of posts, and **⇧P** shows or hides the phone preview next to your photos.
- **⌘T** adds text to the open photo, and **⌘E** exports the post.

A tip for RAW files: Autopost can open them, but it won't see your Lightroom edits. Export your edited photos from Lightroom as JPEG or TIFF first, then drop those into Autopost.

## Seeing your real Instagram profile (optional)

The phone preview can show your actual profile, so you can see a new post sitting on top of your existing grid before you post it. This only works with Business or Creator accounts, because that's what Instagram allows apps to read. Switching to a Creator account is free in the Instagram app's settings.

Setting it up takes about ten minutes, because Instagram makes you create a (free) developer app to get a key. The steps are in the [Instagram connection guide](DEVELOPMENT.md#connecting-instagram). Your key stays on your Mac and is only ever sent to Instagram.

## Questions

**Is it really free?** Yes. No subscription, no account, no watermark.

**Does it upload my photos anywhere?** No. Everything happens on your Mac. The only thing that ever talks to the internet is the optional Instagram connection, which reads your profile and never posts anything.

**Found a bug, or have an idea?** [Open an issue](https://github.com/HNagouda/autopost/issues/new/choose) (you'll need a free GitHub account), or say hi in [Discussions](https://github.com/HNagouda/autopost/discussions).

## For developers

Autopost is a native SwiftUI app. [DEVELOPMENT.md](DEVELOPMENT.md) covers how it works, building it yourself, and how releases happen, and [CONTRIBUTING.md](CONTRIBUTING.md) covers pull requests.

## License

Free and open source under the [GNU General Public License v3.0](LICENSE).
