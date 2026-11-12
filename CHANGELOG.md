# Changelog

What changed in each version of Autopost, newest first. Every release is on the [releases page](https://github.com/HNagouda/autopost/releases) with the app to download.

## 1.2.0

Version 1.2 adds two carousel layouts that photographers build by hand in other apps: a wide photo spread across slides so it scrolls past as one picture, and two or three photos stacked on one slide.

Libraries saved by 1.2 open in 1.1, but 1.1 doesn't know about stacks, so saving there drops every photo below the top one of a stack. Stay on 1.2 once you've stacked photos, or restore from File > Restore from Backup if it happens.

### Panoramas across slides

- A photo can now span 2 or 3 slides. Select it and pick Split in the bar below the grid, or set Slides in the photo's settings.
- The photo is laid out as one wide canvas and cut into slides, so the border runs around the outside only and the picture lines up exactly where one slide meets the next.
- With a fixed ratio the photo fills the space inside the border and is cropped to it, so the border is equally wide on every side. Crop (C) keeps that shape and picks which part shows.
- Trim White Edges in the crop bar crops off a plain margin baked into the file, like the white border some scanning and editing apps add, which would otherwise show up as extra border on some sides.
- The grid and the editor show a dashed line where the cut falls. The phone preview shows the real slides, so you can page across the seam.
- A caption sits under the part of the photo in the last slide, so a seam never cuts through it. Text boxes keep the size they have on a single slide.
- Export writes one file per slide, and the numbering counts slides, so a two-slide panorama followed by a photo exports as 01, 02 and 03.

### Stacked photos

- Click Stack in the toolbar, then click two or three photos and Stack again, to put them on one slide above each other. With two or three photos already selected, Stack (⌘G) stacks them straight away. ⇧⌘G unstacks them again. These are Lightroom's keys for grouping into a stack.
- With a fixed ratio, every photo in the stack gets the same height and is cropped around its middle to fill it. With the Original ratio each photo keeps its own shape and the slide grows to fit.
- The gap between the photos is the border width, so the stack looks the same as the border around it.
- Cropping a stack (C) lets you pick the top, middle or bottom photo, and keeps the crop at the shape of its place in the stack. All three crops apply or cancel together.
- While cropping a stack or a split photo, the Slides menu changes the post's aspect ratio, since the slides set the shape of the crop.
- Unstacking gives back the photos exactly as they went in, with their own borders, crops and text.

### Layout and photo info in the sidebar

- The right-hand column has a Layout section that follows the grid selection: split one photo across slides, stack two or three, or unstack a stack.
- An open photo shows an Info section at the bottom: resolution and megapixels, aspect ratio, file size, the date and time it was taken, camera, lens and exposure, and the place and location when the file has them, with a button to open the spot in Maps.

### Missing photos

- A photo whose file was moved or renamed shows a Locate… button on its tile and in its right-click menu. Pick the file in its new place, and every other missing photo with a file of the same name in that folder is found too, in Recently Deleted as well. Undo puts the old paths back.

## 1.1.0

Version 1.1 makes Autopost quicker to drive from the keyboard, and adds cropping and editable camera settings. A short tour opens on first launch to show all of it, and you can open it again from Help > Autopost Tour.

Libraries saved by 1.1 still open in 1.0, but 1.0 doesn't know about crops or typed camera settings, so saving there drops them. Stay on 1.1 once you've used them.

### Undo

- ⌘Z undoes the last change and ⇧⌘Z redoes it, back through the last 100 changes. That covers deleting, moving and reordering photos, cropping, renaming, and frame and text changes.
- One slider drag or one typed word undoes as a single step, and a delete or a move is always a step of its own.
- Export settings stay out of undo, so ⌘Z never switches "Remove location" back off.

### Posts

- ⌘N makes a new post with its name already selected, so you can type the name straight away.
- Right-click > Rename edits the name in place, instead of in a pop-up.
- Delete removes the selected photos, or the selected post when the sidebar is focused. ⌘⌫ does the same from anywhere in the main window. Holding the key down never deletes more than one.
- Recently Deleted folds away at the bottom of the sidebar like a Finder section, and shows how many posts are in it.
- P hides or shows the list of posts.

### Selecting and moving photos

- Clicking a photo selects it straight away, and clicking it again deselects it.
- Shift-click selects every photo between the last one clicked and this one, and ⌘-click adds or removes single photos.
- Selected photos show a checkmark, and a small floating bar says how many are selected, with buttons to move, crop or remove them.
- ← and → step through the photos, and a number moves the selected photo to that spot, where it slides into place. Type two digits quickly for 10 and up. Together they put a whole carousel in order from the keyboard.
- Dragging photos onto a post in the sidebar highlights the whole row as the drop target, and dragging one selected photo moves the whole selection.
- Dragging inside the grid shows a marker where the photos will land.
- Moving, removing, adding and deleting show a small note at the bottom of the photo area. After a move or delete it has an Undo button.

### Cropping

- Click a photo and press C, or click Crop in the editor. Drag the corners or edges to resize, or drag inside to move the crop.
- Pick a shape (1:1, 4:5, 3:2 and others) to keep the crop at that shape, or hold Shift while dragging to keep its current one. Return applies the crop and Esc cancels.
- The crop shapes the photo and the post's ratio still shapes the canvas, so a square crop in a 4:5 post gets a taller border instead of changing the post.

### Camera settings text

- Rename a camera once in the post's Caption settings, so `ILCE-6400` prints as Sony a6400 on every photo from it.
- Open a photo to type over its camera, focal length, aperture, shutter and ISO. Film scans with no camera data get their settings this way, and "Use for All Photos" copies them to the rest of the roll.
- Adding a caption no longer moves the photo up. The caption goes in the space under the photo, and the photo only moves if that space is too small.
- The caption sits closer to the photo, less than half as far below it as in 1.0.

### Typing exact values

- The number beside the border, text size and export quality sliders can be clicked and typed into, so 5.5% is a few keys instead of a careful drag. Return or clicking elsewhere applies it.

### Viewing

- The phone preview is a panel between the photos and the settings instead of a separate window, so a border change shows on the phone while you drag the slider. ⇧P or the phone button shows and hides it.
- Scrolling the phone feed with two fingers no longer nudges a carousel to its next photo.
- ⇧- and ⇧+ make the grid's photos smaller or larger.
- In the editor, `/` or the arrow above the filmstrip hides or shows the filmstrip.
- The toolbar takes the photo area's colour instead of sitting in a grey band, and its buttons sit above the post settings, so nothing crowds the photos.

### Privacy

- With "Remove location" on, exports also drop written place names (city, region, country), not only GPS.
- Exports never carry the camera's or lens's serial number, the owner name or the computer name.

## 1.0.2 and earlier

- 1.0.2 (2026-10-21) runs on Intel Macs as well as Apple Silicon.
- 1.0.1 (2026-10-20) rewrote the README for photographers.
- 1.0.0 (2026-10-19) was the first release.
