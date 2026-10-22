import AutopostCore
import SwiftUI

struct SidebarView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(ExportController.self) private var exporter
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    // Folded away by default, like a Finder sidebar section, so a long list of deleted posts takes no room.
    @AppStorage("isRecentlyDeletedExpanded") private var isRecentlyDeletedExpanded = false
    // The post a drag is hovering over, to highlight it as the drop target.
    @State private var dropTarget: Post.ID?

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedPostID) {
            Section("Posts") {
                ForEach(store.library.posts) { post in
                    PostRow(post: post, progress: exporter.progress[post.id], isDropTarget: dropTarget == post.id)
                        .tag(post.id)
                        .contextMenu { menu(for: post) }
                        .dropDestination(for: URL.self) { urls, _ in
                            receive(urls, on: post.id)
                        } isTargeted: { isTargeted in
                            if isTargeted { dropTarget = post.id } else if dropTarget == post.id { dropTarget = nil }
                        }
                }
                .onMove { store.movePosts(from: $0, to: $1) }
            }
            if !store.library.deletedPosts.isEmpty {
                Section(isExpanded: $isRecentlyDeletedExpanded) {
                    ForEach(store.library.deletedPosts) { deleted in
                        DeletedPostRow(deleted: deleted)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Recently Deleted")
                        Text("\(store.library.deletedPosts.count)").foregroundStyle(.tertiary)
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
                Button("New Post", systemImage: "plus") { store.createPost(startsRenaming: true) }
                    .help("New post (⌘N)")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }

    /// Photos dragged from the open post move here; files from Finder are added.
    private func receive(_ urls: [URL], on target: Post.ID) -> Bool {
        dropTarget = nil
        guard let source = store.selectedPost else {
            store.addPhotos(urls, to: target)
            return true
        }

        let (moving, newFiles) = store.splitDrop(urls, on: source)
        if !moving.isEmpty { store.movePhotos(moving, from: source.id, to: target) }
        if !newFiles.isEmpty { store.addPhotos(newFiles, to: target) }
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
        Button("Rename") { store.renamingPostID = post.id }
        Button("Duplicate") { store.duplicatePost(post.id) }
        Divider()
        Button("Delete Post", role: .destructive) { store.deletePost(post.id) }
    }
}

private struct PostRow: View {
    let post: Post
    let progress: Double?
    let isDropTarget: Bool

    @Environment(LibraryStore.self) private var store

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
                if store.renamingPostID == post.id {
                    PostNameField(post: post)
                } else {
                    Text(post.name).lineLimit(1)
                }
                if let progress {
                    ProgressView(value: progress).controlSize(.small)
                } else {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        // As wide as the sidebar, so a dragged photo can drop anywhere on the row, not just on the name.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(isDropTarget ? 0.18 : 0))
                .strokeBorder(Color.accentColor, lineWidth: isDropTarget ? 2 : 0)
                .padding(-4)
        }
        .animation(.easeOut(duration: 0.15), value: isDropTarget)
    }

    private var detail: String {
        var parts = ["\(post.photos.count)", post.frame.ratioLabel]
        if post.lastExportedAt != nil { parts.append("exported") }
        return parts.joined(separator: " · ")
    }
}

/// The post's name, typed in place. Return or clicking away keeps it, Escape keeps the old name.
private struct PostNameField: View {
    let post: Post

    @Environment(LibraryStore.self) private var store
    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Name", text: $name)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { finish(saving: true) }
            .onExitCommand { finish(saving: false) }
            .onChange(of: isFocused) {
                if !isFocused { finish(saving: true) }
            }
            .onAppear {
                name = post.name
                // The field has to be on screen before it can take the cursor. Focusing it selects all its text,
                // so typing replaces "Post 3" straight away.
                Task { @MainActor in isFocused = true }
            }
    }

    private func finish(saving: Bool) {
        guard store.renamingPostID == post.id else { return }
        if saving { store.rename(post.id, to: name) }
        store.renamingPostID = nil
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
