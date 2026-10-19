import AutopostCore
import Foundation
import Observation
import SwiftUI

/// The posts, their photos and settings, saved as JSON in Application Support.
@MainActor @Observable
final class LibraryStore {
    // Sliders change the frame many times a second; saving waits for them to settle.
    private static let saveDelay = Duration.milliseconds(400)

    var library: Library {
        didSet { scheduleSave() }
    }
    var selectedPostID: Post.ID?

    // Deleted posts stay restorable this long.
    private static let deletedRetention: TimeInterval = 30 * 24 * 60 * 60

    let backups: LibraryBackups
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Autopost", isDirectory: true)
        fileURL = folder.appendingPathComponent("library.json")
        backups = LibraryBackups(folder: folder.appendingPathComponent("Backups", isDirectory: true))
        library = Self.load(from: fileURL)
        selectedPostID = library.posts.first?.id

        backups.snapshot(fileURL)
        let cutoff = Date().addingTimeInterval(-Self.deletedRetention)
        library.deletedPosts.removeAll { $0.deletedAt < cutoff }
    }

    var selectedPost: Post? {
        selectedPostID.flatMap(post)
    }

    func post(_ id: Post.ID) -> Post? {
        library.posts.first { $0.id == id }
    }

    func frameBinding(for id: Post.ID) -> Binding<FrameSettings> {
        Binding(
            get: { self.post(id)?.frame ?? FrameSettings() },
            set: { frame in self.update(id) { $0.frame = frame } }
        )
    }

    func update(_ id: Post.ID, _ change: (inout Post) -> Void) {
        guard let index = library.posts.firstIndex(where: { $0.id == id }) else { return }
        change(&library.posts[index])
    }

    // * ====================================================================
    // * === posts
    // * ====================================================================

    @discardableResult
    func createPost(named name: String? = nil, photos urls: [URL] = []) -> Post.ID {
        var post = Post(name: name ?? nextPostName(), frame: library.defaultFrame)
        post.photos = urls.map { Photo(url: $0) }
        library.posts.append(post)
        selectedPostID = post.id
        return post.id
    }

    /// Each dropped folder becomes its own post; loose files go together into one new post.
    func createPosts(from urls: [URL]) {
        let folders = urls.filter(FileImport.isFolder)
        for folder in folders {
            createPost(named: folder.lastPathComponent, photos: FileImport.photoURLs(in: [folder]))
        }

        let files = FileImport.photoURLs(in: urls.filter { !FileImport.isFolder($0) })
        if !files.isEmpty {
            createPost(photos: files)
        }
    }

    func duplicatePost(_ id: Post.ID) {
        guard let original = post(id) else { return }
        var copy = Post(name: "\(original.name) copy", frame: original.frame)
        copy.photos = original.photos.map { $0.duplicated() }
        library.posts.insert(copy, at: (library.posts.firstIndex { $0.id == id } ?? 0) + 1)
        selectedPostID = copy.id
    }

    /// Moves the post to Recently Deleted. The library on disk is snapshotted first, in case that is not enough.
    func deletePost(_ id: Post.ID) {
        guard let post = post(id) else { return }
        backups.snapshot(fileURL, force: true)

        library.posts.removeAll { $0.id == id }
        library.deletedPosts.insert(DeletedPost(post: post, deletedAt: Date()), at: 0)
        if selectedPostID == id {
            selectedPostID = library.posts.first?.id
        }
    }

    func restoreDeletedPost(_ id: Post.ID) {
        guard let deleted = library.deletedPosts.first(where: { $0.id == id }) else { return }
        library.deletedPosts.removeAll { $0.id == id }
        library.posts.append(deleted.post)
        selectedPostID = id
    }

    func deletePermanently(_ id: Post.ID) {
        library.deletedPosts.removeAll { $0.id == id }
    }

    /// Replaces the whole library with a backup. The current one is snapshotted first, so this can be undone the same way.
    func restoreBackup(_ backup: LibraryBackups.Backup) throws {
        let restored = try JSONDecoder().decode(Library.self, from: Data(contentsOf: backup.url))
        backups.snapshot(fileURL, force: true)
        library = restored
        selectedPostID = library.posts.first?.id
    }

    func movePosts(from source: IndexSet, to destination: Int) {
        library.posts.move(fromOffsets: source, toOffset: destination)
    }

    /// "Post 1", "Post 2", skipping numbers already taken.
    private func nextPostName() -> String {
        let names = Set(library.posts.map(\.name))
        var number = 1
        while names.contains("Post \(number)") { number += 1 }
        return "Post \(number)"
    }

    // * ====================================================================
    // * === photos
    // * ====================================================================

    func addPhotos(_ urls: [URL], to id: Post.ID, before target: Photo.ID? = nil) {
        let photos = FileImport.photoURLs(in: urls).map { Photo(url: $0) }
        update(id) { post in
            let index = target.flatMap { target in post.photos.firstIndex { $0.id == target } } ?? post.photos.endIndex
            post.photos.insert(contentsOf: photos, at: index)
        }
    }

    func addPhotosToSelectedPost(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if let id = selectedPostID {
            addPhotos(urls, to: id)
        } else {
            createPost(photos: FileImport.photoURLs(in: urls))
        }
    }

    /// Moves a photo within its post, or into another post when `destination` differs from `source`.
    func movePhoto(_ photoID: Photo.ID, from source: Post.ID, to destination: Post.ID, before target: Photo.ID? = nil) {
        guard photoID != target, let photo = post(source)?.photos.first(where: { $0.id == photoID }) else { return }

        update(source) { $0.photos.removeAll { $0.id == photoID } }
        update(destination) { post in
            let index = target.flatMap { target in post.photos.firstIndex { $0.id == target } } ?? post.photos.endIndex
            post.photos.insert(photo, at: index)
        }
    }

    func removePhotos(_ ids: Set<Photo.ID>, from id: Post.ID) {
        update(id) { $0.photos.removeAll { ids.contains($0.id) } }
    }

    // * ====================================================================
    // * === ratios
    // * ====================================================================

    func saveRatio(width: Double, height: Double) {
        guard width > 0, height > 0, !library.savedRatios.contains(where: { $0.width == width && $0.height == height }) else { return }
        library.savedRatios.append(SavedRatio(width: width, height: height))
    }

    func deleteSavedRatio(_ id: SavedRatio.ID) {
        library.savedRatios.removeAll { $0.id == id }
    }

    // * ====================================================================
    // * === presets
    // * ====================================================================

    func savePreset(named name: String, frame: FrameSettings) {
        library.presets.append(FramePreset(name: name, frame: frame))
    }

    func deletePreset(_ id: FramePreset.ID) {
        library.presets.removeAll { $0.id == id }
    }

    // * ====================================================================
    // * === persistence
    // * ====================================================================

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(library).write(to: fileURL, options: .atomic)
            backups.snapshot(fileURL)
        } catch {
            NSLog("Autopost: could not save library to %@: %@", fileURL.path, error.localizedDescription)
        }
    }

    /// A library that no longer decodes is set aside, never overwritten, so nothing is lost.
    private static func load(from url: URL) -> Library {
        guard let data = try? Data(contentsOf: url) else { return Library() }
        do {
            return try JSONDecoder().decode(Library.self, from: data)
        } catch {
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            NSLog("Autopost: library could not be read (%@), moved to %@", error.localizedDescription, backup.path)
            return Library()
        }
    }
}
