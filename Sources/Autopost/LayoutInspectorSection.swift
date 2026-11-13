import AutopostCore
import SwiftUI

/// Split and stack for the photos selected in the grid, next to the post's other settings.
struct LayoutInspectorSection: View {
    let postID: Post.ID

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor

    var body: some View {
        let selected = store.post(postID)?.photos.filter { store.selectedPhotoIDs.contains($0.id) } ?? []

        Section {
            if selected.count == 1, let photo = selected.first, photo.isStack {
                LabeledContent("Stack of \(photo.images.count)") {
                    Button("Add Photos…") { store.startStacking(in: postID) }
                        .disabled(photo.images.count >= Photo.maxStackSize || store.pickingLayout != nil)
                        .help("Click another photo in the grid to put it on this slide too. A stack holds up to \(Photo.maxStackSize) photos.")
                    Button("Unstack") { store.unstackPhoto(photo.id, in: postID) }
                        .help("Give each photo its own slide again (⇧⌘G)")
                }
            } else if selected.count == 1, let photo = selected.first, photo.isCanvas {
                LabeledContent("Canvas of \(photo.images.count)") {
                    Button("Edit") { editor.open(photo.id) }
                        .help("Move and resize the photos on this canvas")
                    Button("Break Apart") { store.breakCanvasApart(photo.id, in: postID) }
                        .help("Give each photo of the canvas its own slide again")
                }
            } else if selected.count == 1, let photo = selected.first {
                LabeledContent("Split across") {
                    Picker("Split across", selection: Binding(get: { photo.slideCount }, set: { store.setSlideCount($0, of: photo.id, in: postID) })) {
                        ForEach(1...Photo.maxSlideCount, id: \.self) { Text($0 == 1 ? "1 slide" : "\($0) slides").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("Split a wide photo across slides, so it scrolls past as one picture")
                }
            }
            if !(selected.count == 1 && (selected[0].isStack || selected[0].isCanvas)) {
                LabeledContent("Canvas") {
                    Button(selected.isEmpty || store.pickingLayout == .stack ? "Choose Photos…" : "Make Canvas") {
                        if let id = store.startCanvas(in: postID) { editor.open(id) }
                    }
                    .disabled((store.post(postID)?.photos.isEmpty ?? true) || store.pickingLayout != nil)
                    .help("Place photos freely across slides, so they can cross from one slide into the next")
                }
                LabeledContent("Stack") {
                    Button(store.canStack(store.selectedPhotoIDs, in: postID) ? "Stack on One Slide" : "Choose Photos…") {
                        store.startStacking(in: postID)
                    }
                    .disabled((store.post(postID)?.photos.count ?? 0) < 2 || store.pickingLayout != nil)
                    .help("Put two or three photos on one slide, above each other (⌘G)")
                }
            }
        } header: {
            Text("Layout")
        } footer: {
            Text(hint(for: selected))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// What the section can do with the current selection, or how to get to something it can do.
    private func hint(for selected: [Photo]) -> String {
        if let pick = store.pickingLayout {
            return pick == .stack
                ? "Click the photos in the grid, three at most on one slide, then Stack in the bar below it. Esc cancels."
                : "Click the photos in the grid, then Make Canvas in the bar below it. Esc cancels."
        } else if selected.isEmpty {
            return "Split a wide photo across slides, stack two or three photos on one slide, or place any number freely on a canvas."
        } else if selected.count == 1, selected[0].isStack {
            return "Open the stack to swap its photos, crop them, or take one out with Delete."
        } else if selected.count == 1 {
            return "A split photo scrolls past as one picture. A stack puts two or three photos on one slide."
        } else if store.canStack(store.selectedPhotoIDs, in: postID) {
            return "Each photo is cropped to fill its place. Open the stack to swap its photos by dragging, and press C to choose the crop."
        }
        return "A stack holds two or three photos, and none of them can be a canvas."
    }
}
