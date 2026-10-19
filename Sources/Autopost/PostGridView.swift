import AppKit
import AutopostCore
import SwiftUI

/// The photos of one post in carousel order, each shown framed exactly as it will export.
struct PostGridView: View {
    let postID: Post.ID
    let tileWidth: Double

    @Environment(LibraryStore.self) private var store
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @Environment(EditorSession.self) private var editor
    @State private var selection: Set<Photo.ID> = []

    var body: some View {
        let post = store.post(postID)
        let photos = post?.photos ?? []

        ScrollView {
            if photos.isEmpty {
                ContentUnavailableView("Drop photos here", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Or press ⌘O. Drag tiles to reorder the carousel, double-click one to edit it."))
                    .padding(.top, 120)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth, maximum: tileWidth * 1.4), spacing: 28)], spacing: 28) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    tile(photo, index: index, frame: post?.frame ?? FrameSettings())
                }
            }
            .padding(28)
        }
        .background(theme.canvasBackground)
        .contentShape(Rectangle())
        .onTapGesture { selection = [] }
        .dropDestination(for: URL.self) { urls, _ in
            receive(urls, before: nil)
        }
        .onDeleteCommand { store.removePhotos(selection, from: postID) }
        .onChange(of: postID) { selection = [] }
    }

    private func tile(_ photo: Photo, index: Int, frame: FrameSettings) -> some View {
        let isSelected = selection.contains(photo.id)
        return VStack(spacing: 8) {
            FramedPhotoView(photo: photo, frame: frame)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                .overlay {
                    Rectangle().strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                }
            Text("\(index + 1)  ·  \(photo.url.lastPathComponent)")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { editor.open(photo.id) }
        .onTapGesture { select(photo.id) }
        .draggable(photo.url)
        .dropDestination(for: URL.self) { urls, _ in
            receive(urls, before: photo.id)
        }
        .contextMenu { menu(for: photo) }
    }

    /// Command-click adds to the selection, a plain click replaces it.
    private func select(_ id: Photo.ID) {
        if NSEvent.modifierFlags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }

    /// A tile dragged inside the grid is reordered; files from Finder are inserted at the drop point.
    private func receive(_ urls: [URL], before target: Photo.ID?) -> Bool {
        guard let post = store.post(postID) else { return false }
        for url in urls {
            if let photo = post.photos.first(where: { $0.url == url }) {
                store.movePhoto(photo.id, from: postID, to: postID, before: target)
            } else {
                store.addPhotos([url], to: postID, before: target)
            }
        }
        return true
    }

    @ViewBuilder
    private func menu(for photo: Photo) -> some View {
        let targets = selection.contains(photo.id) ? selection : [photo.id]
        Button("Edit Photo") { editor.open(photo.id) }
        Button("Make First Photo") {
            let first = store.post(postID)?.photos.first?.id
            store.movePhoto(photo.id, from: postID, to: postID, before: first)
        }
        Menu("Move to Post") {
            ForEach(store.library.posts.filter { $0.id != postID }) { other in
                Button(other.name) {
                    for id in targets { store.movePhoto(id, from: postID, to: other.id) }
                }
            }
        }
        Button("Show Original in Finder") { NSWorkspace.shared.activateFileViewerSelecting([photo.url]) }
        Divider()
        Button(targets.count > 1 ? "Remove \(targets.count) Photos from Post" : "Remove from Post", role: .destructive) {
            store.removePhotos(targets, from: postID)
            selection.subtract(targets)
        }
    }
}
