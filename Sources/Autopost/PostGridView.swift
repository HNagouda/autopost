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
            if let post, let pick = store.pickingLayout {
                LayoutPickingBar(post: post, pick: pick)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let post, !store.selectedPhotoIDs.isEmpty {
                SelectionBar(post: post)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.selectedPhotoIDs.isEmpty)
        .animation(.easeOut(duration: 0.2), value: store.pickingLayout)
        .background(WindowReader { keyboard.window = $0 })
        .onAppear { keyboard.start(store: store, editor: editor) }
        .onDisappear { keyboard.stop() }
    }

    private func tile(_ photo: Photo, index: Int, frame: FrameSettings) -> some View {
        let isSelected = store.selectedPhotoIDs.contains(photo.id)
        return VStack(spacing: 8) {
            FramedPhotoView(photo: photo, frame: frame, showsSeams: true)
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
                .overlay(alignment: .bottom) {
                    if let missing = missingImage(of: photo) {
                        Button("Locate…") { store.locate(missing) }
                            .controlSize(.small)
                            .padding(8)
                            .help("Find where \(missing.lastPathComponent) went. Other missing photos in that folder are found too.")
                    }
                }
                .scaleEffect(isSelected ? 0.97 : 1)
            Text("\(index + 1)  ·  \(Self.tileLabel(photo))")
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

    /// The first photo of the tile whose file could not be opened, for Locate.
    private func missingImage(of photo: Photo) -> URL? {
        photo.images.map(\.url).first { thumbnails.missing.contains($0) }
    }

    /// "DSC01234.jpg", "DSC01234.jpg · 2 slides", "Stack of 3", "Canvas of 5 · 3 slides".
    private static func tileLabel(_ photo: Photo) -> String {
        if photo.isCanvas { return "Canvas of \(photo.images.count) · \(photo.slideCount == 1 ? "1 slide" : "\(photo.slideCount) slides")" }
        if photo.isStack { return "Stack of \(photo.images.count)" }
        if photo.slideCount > 1 { return "\(photo.url.lastPathComponent) · \(photo.slideCount) slides" }
        return photo.url.lastPathComponent
    }

    /// A small copy of the photo, with a count when the drag carries the whole selection. Drawn from the thumbnail
    /// directly, because a drag preview is rendered outside the window and has none of its environment.
    private func dragPreview(_ photo: Photo) -> some View {
        let count = store.selectedPhotoIDs.contains(photo.id) ? store.selectedPhotoIDs.count : 1
        let image = thumbnails.croppedImage(for: photo.url, crop: photo.crop)

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
        if NSEvent.modifierFlags.contains(.command) || store.pickingLayout != nil {
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
        Button(photo.isCanvas ? "Edit Canvas" : "Edit Photo") { editor.open(photo.id) }
        if !photo.isCanvas {
            Button("Crop Photo") { editor.crop(photo.id, in: store, postID: postID) }
        }
        Button("Make First Photo") {
            store.movePhoto(photo.id, in: postID, toPosition: 1)
        }
        Divider()
        if photo.isCanvas {
            Button("Break Canvas Apart") { store.breakCanvasApart(photo.id, in: postID) }
        } else if photo.isStack {
            Button("Unstack") { store.unstackPhoto(photo.id, in: postID) }
            Button("Make Canvas") { if let id = store.makeCanvas(of: targets, in: postID) { editor.open(id) } }
        } else {
            Button("Stack Photos") { store.stackPhotos(targets, in: postID) }
                .disabled(!store.canStack(targets, in: postID))
            Button("Make Canvas") { if let id = store.makeCanvas(of: targets, in: postID) { editor.open(id) } }
            Picker("Split", selection: Binding(get: { photo.slideCount }, set: { store.setSlideCount($0, of: photo.id, in: postID) })) {
                ForEach(1...Photo.maxSlideCount, id: \.self) { Text($0 == 1 ? "1 Slide" : "\($0) Slides").tag($0) }
            }
        }
        Divider()
        Menu("Move to Post") {
            ForEach(store.library.posts.filter { $0.id != postID }) { other in
                Button(other.name) { store.movePhotos(targets, from: postID, to: other.id) }
            }
        }
        if let missing = missingImage(of: photo) {
            Button("Locate…") { store.locate(missing) }
        } else {
            Button("Show Original in Finder") { NSWorkspace.shared.activateFileViewerSelecting([photo.url]) }
        }
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
            if selected.count == 1, selected[0].isCanvas {
                Text("Press 1–9 to move it there")
                    .foregroundStyle(.secondary)
            } else if selected.count == 1 {
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
            if let photo = selected.first, selected.count == 1, !photo.isCanvas {
                Button("Crop", systemImage: "crop") { editor.crop(photo.id, in: store, postID: post.id) }
            }
            // Next to Stack, so both carousel layouts are in sight as soon as a photo is selected.
            if let photo = selected.first, selected.count == 1, !photo.isStack, !photo.isCanvas {
                Picker("Split", selection: Binding(get: { photo.slideCount }, set: { store.setSlideCount($0, of: photo.id, in: post.id) })) {
                    ForEach(1...Photo.maxSlideCount, id: \.self) { Text($0 == 1 ? "1 Slide" : "\($0) Slides").tag($0) }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("Split a wide photo across slides, so it scrolls past as one picture")
            }
            if let photo = selected.first, selected.count == 1, photo.isCanvas {
                Button("Edit Canvas", systemImage: "rectangle.3.group") { editor.open(photo.id) }
                    .help("Move and resize the photos on this canvas")
                Button("Break Apart") { store.breakCanvasApart(photo.id, in: post.id) }
                    .help("Give each photo of the canvas its own slide again")
            } else if let photo = selected.first, selected.count == 1, photo.isStack {
                Button("Unstack", systemImage: "square.stack") { store.unstackPhoto(photo.id, in: post.id) }
                    .help("Give each photo its own slide again (⇧⌘G)")
            } else {
                Button("Canvas", systemImage: "rectangle.3.group") {
                    if let id = store.makeCanvas(of: store.selectedPhotoIDs, in: post.id) { editor.open(id) }
                }
                .help("Place these photos freely across slides, so they can cross from one slide into the next")
                // Shown even when the selection can't be stacked yet, so the layout is in sight from the first click.
                Button("Stack", systemImage: "square.stack") { store.startStacking(in: post.id) }
                    .help("Put two or three photos on one slide, above each other (⌘G)")
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

/// Shown while picking photos for a stack or a canvas: how many are picked, and the button that makes it.
private struct LayoutPickingBar: View {
    let post: Post
    let pick: LayoutPick

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor

    var body: some View {
        let count = post.photos.filter { store.selectedPhotoIDs.contains($0.id) }.count

        HStack(spacing: 14) {
            Text(pick == .stack ? "Click two or three photos to stack on one slide" : "Click the photos to place on a canvas")
                .fontWeight(.medium)
            Text("\(count) picked")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button("Cancel") {
                store.pickingLayout = nil
                store.selectedPhotoIDs = []
            }
            .help("Stop picking photos (Esc)")
            if pick == .stack {
                Button("Stack", systemImage: "square.stack") { store.stackPhotos(store.selectedPhotoIDs, in: post.id) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canStack(store.selectedPhotoIDs, in: post.id))
                    .help("Put the picked photos on one slide, above each other")
            } else {
                Button("Make Canvas", systemImage: "rectangle.3.group") {
                    if let id = store.makeCanvas(of: store.selectedPhotoIDs, in: post.id) { editor.open(id) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(count == 0)
                .help("Open the picked photos on a canvas, where they can be moved and resized")
            }
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
