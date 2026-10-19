import AutopostCore
import SwiftUI

struct ContentView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(ExportController.self) private var exporter
    @Environment(EditorSession.self) private var editor
    @Environment(\.openWindow) private var openWindow
    @AppStorage("tileWidth") private var tileWidth = 240.0
    @State private var isInspectorShown = true

    var body: some View {
        @Bindable var exporter = exporter

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            if let post = store.selectedPost, editor.isOpen {
                PhotoEditorView(postID: post.id)
                    .navigationTitle(post.name)
                    .navigationSubtitle(editorSubtitle(for: post))
            } else if let post = store.selectedPost {
                PostGridView(postID: post.id, tileWidth: tileWidth)
                    .navigationTitle(post.name)
                    .navigationSubtitle(subtitle(for: post))
            } else {
                EmptyLibraryView()
            }
        }
        .inspector(isPresented: $isInspectorShown) {
            if let post = store.selectedPost, let photoID = editor.photoID {
                PhotoInspector(postID: post.id, photoID: photoID)
                    .inspectorColumnWidth(min: 280, ideal: 300, max: 360)
            } else if let post = store.selectedPost {
                InspectorView(postID: post.id)
                    .inspectorColumnWidth(min: 280, ideal: 300, max: 360)
            } else {
                Text("No post selected").foregroundStyle(.secondary)
            }
        }
        .toolbar { toolbar }
        .onChange(of: store.selectedPostID) { editor.close() }
        .alert("Export failed", isPresented: Binding(get: { exporter.failure != nil }, set: { if !$0 { exporter.failure = nil } })) {
            Button("OK") { exporter.failure = nil }
        } message: {
            Text(exporter.failure ?? "")
        }
    }

    private func subtitle(for post: Post) -> String {
        let count = post.photos.count == 1 ? "1 photo" : "\(post.photos.count) photos"
        return "\(count) · \(post.frame.ratioLabel)"
    }

    private func editorSubtitle(for post: Post) -> String {
        let index = post.photos.firstIndex { $0.id == editor.photoID }.map { $0 + 1 } ?? 0
        return "Photo \(index) of \(post.photos.count) · \(post.frame.ratioLabel)"
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if editor.isOpen {
            ToolbarItem(placement: .navigation) {
                Button("Back to Post", systemImage: "chevron.left") { editor.close() }
                    .help("Back to the post (Esc)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Text", systemImage: "textformat") {
                    if let id = store.selectedPostID { editor.addTextBox(in: store, postID: id) }
                }
                .help("Add a text box (⌘T)")
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: Binding(get: { editor.isShowingGrid }, set: { editor.isShowingGrid = $0 })) {
                    Label("Grid", systemImage: "grid")
                }
                .help("Show the snapping grid. Hold Shift while dragging to place text freely.")
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Slider(value: $tileWidth, in: 140...520) {
                    Text("Tile size")
                } minimumValueLabel: {
                    Image(systemName: "square.grid.3x3").imageScale(.small)
                } maximumValueLabel: {
                    Image(systemName: "square").imageScale(.small)
                }
                .frame(width: 140)
                .help("Tile size")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Add Photos", systemImage: "plus") { store.addPhotosToSelectedPost(FileImport.choosePhotos(allowsFolders: false)) }
                .help("Add photos to this post (⌘O)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Phone Preview", systemImage: "iphone") { openWindow(id: WindowID.phone) }
                .help("See the post on a phone (⌥⌘P)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Export", systemImage: "square.and.arrow.up") {
                if let id = store.selectedPostID { exporter.export(id, in: store) }
            }
            .disabled(store.selectedPost?.photos.isEmpty ?? true)
            .help("Export this post (⌘E)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Inspector", systemImage: "sidebar.right") { isInspectorShown.toggle() }
        }
    }
}

struct EmptyLibraryView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("No posts yet", systemImage: "rectangle.portrait.on.rectangle.portrait")
        } description: {
            Text("Drop photos or folders here. Each folder becomes its own post.")
        } actions: {
            Button("New Post") { store.createPost() }
            Button("Create Posts from Folders…") { store.createPosts(from: FileImport.choosePhotos(allowsFolders: true)) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            store.createPosts(from: urls)
            return true
        }
    }
}
