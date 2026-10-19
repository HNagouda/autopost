import AutopostCore
import SwiftUI

struct ContentView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(ExportController.self) private var exporter
    @Environment(\.openWindow) private var openWindow
    @AppStorage("tileWidth") private var tileWidth = 240.0
    @State private var isInspectorShown = true

    var body: some View {
        @Bindable var exporter = exporter

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            if let post = store.selectedPost {
                PostGridView(postID: post.id, tileWidth: tileWidth)
                    .navigationTitle(post.name)
                    .navigationSubtitle(subtitle(for: post))
            } else {
                EmptyLibraryView()
            }
        }
        .inspector(isPresented: $isInspectorShown) {
            if let post = store.selectedPost {
                InspectorView(postID: post.id)
                    .inspectorColumnWidth(min: 280, ideal: 300, max: 360)
            } else {
                Text("No post selected").foregroundStyle(.secondary)
            }
        }
        .toolbar { toolbar }
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
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
