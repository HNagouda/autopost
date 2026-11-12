import AutopostCore
import SwiftUI

/// Split and stack for the photos selected in the grid, next to the post's other settings.
struct LayoutInspectorSection: View {
    let postID: Post.ID

    @Environment(LibraryStore.self) private var store

    var body: some View {
        let selected = store.post(postID)?.photos.filter { store.selectedPhotoIDs.contains($0.id) } ?? []

        Section {
            if selected.count == 1, let photo = selected.first, photo.isStack {
                LabeledContent("Stack of \(photo.images.count)") {
                    Button("Unstack") { store.unstackPhoto(photo.id, in: postID) }
                        .help("Give each photo its own slide again (⇧⌘G)")
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
            if !(selected.count == 1 && selected[0].isStack) {
                LabeledContent("Stack") {
                    Button(store.canStack(store.selectedPhotoIDs, in: postID) ? "Stack on One Slide" : "Choose Photos…") {
                        store.startStacking(in: postID)
                    }
                    .disabled((store.post(postID)?.photos.count ?? 0) < 2 || store.isPickingStack)
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
        if store.isPickingStack {
            return "Click two or three photos in the grid, then Stack in the bar below it. Esc cancels."
        } else if selected.isEmpty {
            return "Select a wide photo to split it across slides, or two or three photos to stack them on one slide."
        } else if selected.count == 1 {
            return "A split photo scrolls past as one picture. A stack puts two or three photos on one slide."
        } else if store.canStack(store.selectedPhotoIDs, in: postID) {
            return "Each photo is cropped to fill its place. Press C on the stack to choose the crop."
        }
        return "Stack two or three photos that are not already split or stacked."
    }
}
