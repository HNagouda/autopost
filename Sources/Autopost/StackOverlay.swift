import AutopostCore
import SwiftUI

/// Reordering the photos of a stack in the editor: drag one onto another and the two change places. The photos
/// themselves are drawn by FramedPhotoView from the same layout.
struct StackOverlay: View {
    let postID: Post.ID
    let photo: Photo
    let layout: FrameLayout

    private static let space = "stack"
    // A drag shorter than this is a click or the first half of a double-click, not a move.
    private static let dragDistance = 4.0

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    // While dragging, the place the pointer is over, which the dragged photo would swap with.
    @State private var target: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(layout.imageRects.enumerated()), id: \.offset) { index, rect in
                place(rect, index: index)
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
        .coordinateSpace(.named(Self.space))
    }

    private func place(_ rect: CGRect, index: Int) -> some View {
        let isSelected = editor.selectedImageIndex == index

        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .overlay { Rectangle().strokeBorder(Color.accentColor, lineWidth: target == index ? 4 : isSelected ? 2 : 0) }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture(count: 2) { editor.crop(photo.id, in: store, postID: postID, imageIndex: index) }
            .onTapGesture { editor.selectImage(index) }
            .gesture(swapDrag(index))
            .contextMenu { menu(index: index) }
            .help("Click to select: C crops it, Delete takes it out of the stack. Drag onto another photo to swap them.")
    }

    private func swapDrag(_ index: Int) -> some Gesture {
        DragGesture(minimumDistance: Self.dragDistance, coordinateSpace: .named(Self.space))
            .onChanged { value in
                editor.selectImage(index)
                target = layout.imageRects.indices.first { $0 != index && layout.imageRects[$0].contains(value.location) }
            }
            .onEnded { _ in
                if let target { swap(index, target) }
                target = nil
            }
    }

    /// Swaps two photos and keeps the moved one selected at its new place.
    private func swap(_ index: Int, _ other: Int) {
        store.swapStackedPhotos(index, other, of: photo.id, in: postID)
        editor.selectImage(other)
    }

    @ViewBuilder
    private func menu(index: Int) -> some View {
        Button("Move Up") { swap(index, index - 1) }
            .disabled(index == 0)
        Button("Move Down") { swap(index, index + 1) }
            .disabled(index == photo.images.count - 1)
        Divider()
        Button("Crop Photo") { editor.crop(photo.id, in: store, postID: postID, imageIndex: index) }
        Button("Add Text Box") { editor.addTextBox(in: store, postID: postID) }
        Divider()
        Button("Take Out of the Stack", role: .destructive) {
            store.removeStackedPhoto(index, of: photo.id, in: postID)
            editor.selectedImageIndex = nil
        }
    }
}
