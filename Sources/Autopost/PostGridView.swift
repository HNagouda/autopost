import AppKit
import AutopostCore
import SwiftUI

/// How big the grid tiles are. The toolbar slider and ⇧- and ⇧+ both change it.
enum TileSize {
    static let storageKey = "tileWidth"
    static let standard = 240.0
    static let range = 140.0...520.0
    static let step = 40.0

    static func zoom(by change: Double) {
        let current = UserDefaults.standard.object(forKey: storageKey) as? Double ?? standard
        UserDefaults.standard.set(min(max(current + change, range.lowerBound), range.upperBound), forKey: storageKey)
    }
}

/// The photos of one post in carousel order, each shown framed exactly as it will export.
struct PostGridView: View {
    let postID: Post.ID

    // Tiles sit this far apart; the drop marker sits in the middle of the gap.
    private static let spacing = 28.0
    // How photos slide to a new place in the order, here and in the editor's filmstrip.
    static let reorderAnimation = Animation.spring(duration: 0.35, bounce: 0.15)
    // The small copy of a photo that follows the pointer while dragging.
    private static let dragPreviewSize = 96.0

    @Environment(LibraryStore.self) private var store
    @Environment(ThumbnailStore.self) private var thumbnails
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage(TileSize.storageKey) private var tileWidth = TileSize.standard
    @Environment(EditorSession.self) private var editor
    @State private var keyboard = GridKeyboard()
    // The tile a drag is hovering over; dropped photos go in front of it.
    @State private var dropTarget: Photo.ID?
    // The last photo clicked without Shift. Shift-click selects everything from here to the clicked photo.
    @State private var selectionAnchor: Photo.ID?

    var body: some View {
        let post = store.post(postID)
        let photos = post?.photos ?? []

        ScrollViewReader { proxy in
            ScrollView {
                if photos.isEmpty {
                    ContentUnavailableView("Drop photos here", systemImage: "photo.on.rectangle.angled",
                                           description: Text("Or press ⌘O. Drag tiles to reorder the carousel, double-click one to edit it."))
                        .padding(.top, 120)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth, maximum: tileWidth * 1.4), spacing: Self.spacing)], spacing: Self.spacing) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        tile(photo, index: index, frame: post?.frame ?? FrameSettings())
                    }
                }
                .padding(Self.spacing)
                // Photos slide to their new places whenever the order changes, from the number keys, a drag or ⌘Z.
                .animation(Self.reorderAnimation, value: photos.map(\.id))
            }
            // Keeps a photo picked with the arrow keys on screen, and makes it the start of a Shift-click range.
            .onChange(of: store.selectedPhotoIDs) {
                guard store.selectedPhotoIDs.count == 1, let id = store.selectedPhotoIDs.first else { return }
                selectionAnchor = id
                withAnimation { proxy.scrollTo(id) }
            }
        }
        .background(theme.canvasBackground)
        .contentShape(Rectangle())
        .onTapGesture { store.selectedPhotoIDs = [] }
        .dropDestination(for: URL.self) { urls, _ in
            receive(urls, before: nil)
        }
        .safeAreaInset(edge: .bottom) {
            if let post, !store.selectedPhotoIDs.isEmpty {
                SelectionBar(post: post)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.selectedPhotoIDs.isEmpty)
        .background(WindowReader { keyboard.window = $0 })
        .onAppear { keyboard.start(store: store, editor: editor) }
        .onDisappear { keyboard.stop() }
    }

    private func tile(_ photo: Photo, index: Int, frame: FrameSettings) -> some View {
        let isSelected = store.selectedPhotoIDs.contains(photo.id)
        return VStack(spacing: 8) {
            FramedPhotoView(photo: photo, frame: frame)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                .overlay {
                    Rectangle().strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(8)
                    }
                }
                .scaleEffect(isSelected ? 0.97 : 1)
            Text("\(index + 1)  ·  \(photo.url.lastPathComponent)")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .animation(.easeOut(duration: 0.08), value: isSelected)
        .overlay(alignment: .leading) {
            if dropTarget == photo.id {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 4)
                    .offset(x: -Self.spacing / 2 - 2)
            }
        }
        .contentShape(Rectangle())
        // One handler for both clicks. A separate double-click handler makes SwiftUI hold every single click
        // back until the double-click time has passed, which makes selecting feel slow.
        .onTapGesture {
            if NSApp.currentEvent?.clickCount == 2 { editor.open(photo.id) } else { select(photo.id) }
        }
        .draggable(photo.url) { dragPreview(photo) }
        .dropDestination(for: URL.self) { urls, _ in
            receive(urls, before: photo.id)
        } isTargeted: { isTargeted in
            if isTargeted { dropTarget = photo.id } else if dropTarget == photo.id { dropTarget = nil }
        }
        .contextMenu { menu(for: photo) }
    }

    /// A small copy of the photo, with a count when the drag carries the whole selection. Drawn from the thumbnail
    /// directly, because a drag preview is rendered outside the window and has none of its environment.
    private func dragPreview(_ photo: Photo) -> some View {
        let count = store.selectedPhotoIDs.contains(photo.id) ? store.selectedPhotoIDs.count : 1
        let image = thumbnails.thumbnail(for: photo.url).flatMap { $0.image.cropped(to: photo.crop) }

        return ZStack(alignment: .topTrailing) {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.dragPreviewSize, height: Self.dragPreviewSize)
            }
            if count > 1 {
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
                    .offset(x: 8, y: -8)
            }
        }
        .padding(8)
    }

    /// Shift-click selects every photo from the last one clicked to this one. Command-click adds or removes one
    /// photo. A plain click selects only that photo, or deselects it when it was already the only one selected.
    /// Either way the keyboard leaves the sidebar, so Delete then removes photos rather than the post.
    private func select(_ id: Photo.ID) {
        let photos = store.post(postID)?.photos ?? []
        let anchorIndex = selectionAnchor.flatMap { anchor in photos.firstIndex { $0.id == anchor } }
        let clickedIndex = photos.firstIndex { $0.id == id }

        if NSEvent.modifierFlags.contains(.shift), let anchorIndex, let clickedIndex {
            let range = min(anchorIndex, clickedIndex)...max(anchorIndex, clickedIndex)
            store.selectedPhotoIDs = Set(photos[range].map(\.id))
            keyboard.window?.makeFirstResponder(nil)
            return
        }

        selectionAnchor = id
        if NSEvent.modifierFlags.contains(.command) {
            if store.selectedPhotoIDs.contains(id) { store.selectedPhotoIDs.remove(id) } else { store.selectedPhotoIDs.insert(id) }
        } else if store.selectedPhotoIDs == [id] {
            store.selectedPhotoIDs = []
        } else {
            store.selectedPhotoIDs = [id]
        }
        keyboard.window?.makeFirstResponder(nil)
    }

    /// Tiles dragged inside the grid are reordered; files from Finder are inserted at the drop point.
    private func receive(_ urls: [URL], before target: Photo.ID?) -> Bool {
        dropTarget = nil
        guard let post = store.post(postID) else { return false }

        let (moving, newFiles) = store.splitDrop(urls, on: post)
        if !moving.isEmpty { store.reorderPhotos(moving, in: postID, before: target) }
        if !newFiles.isEmpty { store.addPhotos(newFiles, to: postID, before: target) }
        return true
    }

    @ViewBuilder
    private func menu(for photo: Photo) -> some View {
        let targets = store.selectedPhotoIDs.contains(photo.id) ? store.selectedPhotoIDs : [photo.id]
        Button("Edit Photo") { editor.open(photo.id) }
        Button("Crop Photo") { editor.crop(photo.id, in: store, postID: postID) }
        Button("Make First Photo") {
            store.movePhoto(photo.id, in: postID, toPosition: 1)
        }
        Menu("Move to Post") {
            ForEach(store.library.posts.filter { $0.id != postID }) { other in
                Button(other.name) { store.movePhotos(targets, from: postID, to: other.id) }
            }
        }
        Button("Show Original in Finder") { NSWorkspace.shared.activateFileViewerSelecting([photo.url]) }
        Divider()
        Button(targets.count > 1 ? "Remove \(targets.count) Photos from Post" : "Remove from Post", role: .destructive) {
            store.removePhotos(targets, from: postID)
        }
    }
}

/// Shown under the grid while photos are selected: what is selected, and what can be done with it.
private struct SelectionBar: View {
    let post: Post

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor

    var body: some View {
        let selected = post.photos.filter { store.selectedPhotoIDs.contains($0.id) }

        HStack(spacing: 14) {
            Text("\(LibraryStore.photoCount(selected.count)) selected")
                .fontWeight(.medium)
            if selected.count == 1 {
                Text("Press 1–9 to move it there, C to crop")
                    .foregroundStyle(.secondary)
            }
            Menu("Move to Post") {
                ForEach(store.library.posts.filter { $0.id != post.id }) { other in
                    Button(other.name) { store.movePhotos(store.selectedPhotoIDs, from: post.id, to: other.id) }
                }
            }
            .fixedSize()
            .disabled(store.library.posts.count < 2)
            if let photo = selected.first, selected.count == 1 {
                Button("Crop", systemImage: "crop") { editor.crop(photo.id, in: store, postID: post.id) }
            }
            Button("Remove", systemImage: "trash", role: .destructive) {
                store.removePhotos(store.selectedPhotoIDs, from: post.id)
            }
            .help("Remove from this post (Delete)")
            Button("Done") { store.selectedPhotoIDs = [] }
                .help("Deselect (Esc)")
        }
        .controlSize(.small)
        .fixedSize()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.separator, lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .padding(.bottom, 16)
    }
}

/// Keys for the post grid: the arrows pick a photo, Delete removes, the number keys set a photo's position, C crops,
/// and ⇧- and ⇧+ zoom.
@MainActor
final class GridKeyboard {
    weak var window: NSWindow?
    private var monitor: Any?
    private var typedPosition = TypedPosition()

    func start(store: LibraryStore, editor: EditorSession) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            return self.handle(event, store: store, editor: editor) ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// True when the key was used. Typing in a text field and shortcuts with ⌘, ⌥ or ⌃ pass through untouched.
    private func handle(_ event: NSEvent, store: LibraryStore, editor: EditorSession) -> Bool {
        guard KeyCode.hasNoShortcutModifiers(event), !KeyCode.isTyping(in: event.window), let post = store.selectedPost else { return false }
        let selected = post.photos.filter { store.selectedPhotoIDs.contains($0.id) }

        // A plain Delete only takes the whole post while the sidebar has the keyboard, so pressing it after
        // clicking a slider in the inspector never deletes a post. ⌘⌫ is the deliberate version. A held key
        // never repeats a delete.
        if KeyCode.isDelete(event.keyCode) {
            let isSidebarFocused = event.window?.firstResponder is NSTableView
            guard isSidebarFocused || !selected.isEmpty, !event.isARepeat else { return false }
            store.deleteSelection(isSidebarFocused: isSidebarFocused)
            return true
        }
        if let digit = KeyCode.digit(event.keyCode) {
            guard let photo = selected.first, selected.count == 1,
                  let position = typedPosition.type(digit, photoCount: post.photos.count)
            else { return false }
            store.movePhoto(photo.id, in: post.id, toPosition: position)
            return true
        }
        // In the sidebar the arrows belong to the post list.
        if event.keyCode == KeyCode.left || event.keyCode == KeyCode.right, !(event.window?.firstResponder is NSTableView) {
            return step(isForward: event.keyCode == KeyCode.right, in: post, store: store)
        }
        if event.keyCode == KeyCode.escape, !selected.isEmpty {
            store.selectedPhotoIDs = []
            return true
        }

        switch event.charactersIgnoringModifiers {
        case "c":
            guard let photo = selected.first, selected.count == 1 else { return false }
            editor.crop(photo.id, in: store, postID: post.id)
            return true
        // Shift is required so a stray - or = never resizes the grid. With Shift held those keys type _ and +.
        case "_" where event.modifierFlags.contains(.shift):
            TileSize.zoom(by: -TileSize.step)
            return true
        case "+" where event.modifierFlags.contains(.shift):
            TileSize.zoom(by: TileSize.step)
            return true
        default:
            return false
        }
    }

    /// Selects the photo after the selection, or before it. From nothing, forward starts at the first photo and
    /// back at the last, so a whole carousel can be put in order from the keyboard.
    private func step(isForward: Bool, in post: Post, store: LibraryStore) -> Bool {
        guard !post.photos.isEmpty else { return false }
        let first = post.photos.firstIndex { store.selectedPhotoIDs.contains($0.id) }
        let last = post.photos.lastIndex { store.selectedPhotoIDs.contains($0.id) }
        let index = isForward
            ? last.map { min($0 + 1, post.photos.count - 1) } ?? 0
            : first.map { max($0 - 1, 0) } ?? post.photos.count - 1

        store.selectedPhotoIDs = [post.photos[index].id]
        return true
    }
}
