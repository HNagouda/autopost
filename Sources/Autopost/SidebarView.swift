import AutopostCore
import SwiftUI

struct SidebarView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(ExportController.self) private var exporter
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @State private var renaming: Post.ID?
    @State private var newName = ""

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedPostID) {
            Section("Posts") {
                ForEach(store.library.posts) { post in
                    PostRow(post: post, progress: exporter.progress[post.id])
                        .tag(post.id)
                        .contextMenu { menu(for: post) }
                        .dropDestination(for: URL.self) { urls, _ in
                            receive(urls, on: post.id)
                        }
                }
                .onMove { store.movePosts(from: $0, to: $1) }
            }
            if !store.library.deletedPosts.isEmpty {
                Section("Recently Deleted") {
                    ForEach(store.library.deletedPosts) { deleted in
                        DeletedPostRow(deleted: deleted)
                    }
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            store.createPosts(from: urls)
            return true
        }
        .amoledBackground(theme)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("New Post", systemImage: "plus") { store.createPost() }
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .alert("Rename Post", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let id = renaming, !newName.isEmpty { store.update(id) { $0.name = newName } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Photos dragged from the open post move here; files from Finder are added.
    private func receive(_ urls: [URL], on target: Post.ID) -> Bool {
        guard let source = store.selectedPost else {
            store.addPhotos(urls, to: target)
            return true
        }
        for url in urls {
            if let photo = source.photos.first(where: { $0.url == url }) {
                if source.id != target { store.movePhoto(photo.id, from: source.id, to: target) }
            } else {
                store.addPhotos([url], to: target)
            }
        }
        return true
    }

    private func exportAsButtons(_ post: Post, _ ratios: [AspectRatio]) -> some View {
        ForEach(ratios) { ratio in
            Button("\(ratio.label)  \(ratio.detail)") { exporter.export(post.id, in: store) { $0.ratio = ratio } }
        }
    }

    @ViewBuilder
    private func menu(for post: Post) -> some View {
        Button("Export Post") { exporter.export(post.id, in: store) }
        Menu("Export Post As") {
            exportAsButtons(post, AspectRatio.portrait + AspectRatio.squareAndOriginal)
            Divider()
            exportAsButtons(post, AspectRatio.landscape)
            if !store.library.savedRatios.isEmpty {
                Divider()
                ForEach(store.library.savedRatios) { saved in
                    Button("\(saved.label)  (saved)") { exporter.export(post.id, in: store) { $0.use(saved) } }
                }
            }
        }
        Button("Export and AirDrop…") { exporter.export(post.id, in: store, sendsViaAirDrop: true) }
        Button("Show Exports in Finder") { exporter.revealExports(of: post, settings: store.library.export) }
        Divider()
        Button("Rename…") {
            newName = post.name
            renaming = post.id
        }
        Button("Duplicate") { store.duplicatePost(post.id) }
        Divider()
        Button("Delete Post", role: .destructive) { store.deletePost(post.id) }
    }
}

private struct PostRow: View {
    let post: Post
    let progress: Double?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let first = post.photos.first {
                    FramedPhotoView(photo: first, frame: post.frame)
                } else {
                    RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                        .aspectRatio(post.frame.ratioValue ?? 0.8, contentMode: .fit)
                }
            }
            .frame(width: 34, height: 42)
            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(post.name).lineLimit(1)
                if let progress {
                    ProgressView(value: progress).controlSize(.small)
                } else {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        var parts = ["\(post.photos.count)", post.frame.ratioLabel]
        if post.lastExportedAt != nil { parts.append("exported") }
        return parts.joined(separator: " · ")
    }
}

/// Not tagged, so it cannot be selected and opened; it can only be restored or removed for good.
private struct DeletedPostRow: View {
    let deleted: DeletedPost

    @Environment(LibraryStore.self) private var store

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(deleted.post.name).lineLimit(1)
                Text(deleted.deletedAt, format: .relative(presentation: .named))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore") { store.restoreDeletedPost(deleted.id) }
                .buttonStyle(.borderless)
        }
        .foregroundStyle(.secondary)
        .contextMenu {
            Button("Restore") { store.restoreDeletedPost(deleted.id) }
            Button("Delete Permanently", role: .destructive) { store.deletePermanently(deleted.id) }
        }
    }
}
