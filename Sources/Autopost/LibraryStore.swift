import AppKit
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
        didSet {
            recordUndo(oldValue)
            scheduleSave()
        }
    }
    var selectedPostID: Post.ID? {
        didSet { if oldValue != selectedPostID { selectedPhotoIDs = [] } }
    }
    // The photos selected in the post grid. Delete, the number keys and dragging act on these.
    var selectedPhotoIDs: Set<Photo.ID> = []
    // The post whose name is being typed in the sidebar.
    var renamingPostID: Post.ID?
    // The last change worth confirming on screen; ToastView shows it and clears it.
    var toast: Toast?

    // Deleted posts stay restorable this long.
    private static let deletedRetention: TimeInterval = 30 * 24 * 60 * 60
    // Changes closer together than this undo as one step, so a slider drag or a typed word is a single ⌘Z.
    private static let undoGrouping: TimeInterval = 0.5
    private static let undoLimit = 100

    let backups: LibraryBackups
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    // Earlier and later versions of the library for ⌘Z and ⇧⌘Z, oldest first.
    private var undoStack: [Library] = []
    private var redoStack: [Library] = []
    private var lastChange = Date.distantPast
    private var isRestoring = false

    init() {
        let folder = Self.libraryFolder()
        fileURL = folder.appendingPathComponent("library.json")
        backups = LibraryBackups(folder: folder.appendingPathComponent("Backups", isDirectory: true))
        var loaded = Self.load(from: fileURL)
        let cutoff = Date().addingTimeInterval(-Self.deletedRetention)
        loaded.deletedPosts.removeAll { $0.deletedAt < cutoff }
        library = loaded
        selectedPostID = library.posts.first?.id
        backups.snapshot(fileURL)

        // A change made just before quitting would otherwise still be waiting out the save delay.
        _ = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    /// Application Support/Autopost, or AUTOPOST_LIBRARY_DIR, so a development build can run against a throwaway library.
    private static func libraryFolder() -> URL {
        if let override = ProcessInfo.processInfo.environment["AUTOPOST_LIBRARY_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Autopost", isDirectory: true)
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

    /// `startsRenaming` puts the cursor in the new post's name in the sidebar, with "Post 3" selected to type over.
    @discardableResult
    func createPost(named name: String? = nil, photos urls: [URL] = [], startsRenaming: Bool = false) -> Post.ID {
        var post = Post(name: name ?? nextPostName(), frame: library.defaultFrame)
        post.photos = urls.map { Photo(url: $0) }
        asOneUndoStep { library.posts.append(post) }
        selectedPostID = post.id
        if startsRenaming { renamingPostID = post.id }
        return post.id
    }

    func rename(_ id: Post.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { asOneUndoStep { update(id) { $0.name = trimmed } } }
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
        asOneUndoStep { library.posts.insert(copy, at: (library.posts.firstIndex { $0.id == id } ?? 0) + 1) }
        selectedPostID = copy.id
        toast = Toast(message: "Duplicated “\(original.name)”", systemImage: "plus.square.on.square")
    }

    /// Moves the post to Recently Deleted. The library on disk is snapshotted first, in case that is not enough.
    func deletePost(_ id: Post.ID) {
        guard let post = post(id), let index = library.posts.firstIndex(where: { $0.id == id }) else { return }
        backups.snapshot(fileURL, force: true)

        asOneUndoStep {
            library.posts.removeAll { $0.id == id }
            library.deletedPosts.insert(DeletedPost(post: post, deletedAt: Date()), at: 0)
        }
        if selectedPostID == id {
            selectedPostID = library.posts.indices.contains(index) ? library.posts[index].id : library.posts.last?.id
        }
        toast = Toast(message: "Moved “\(post.name)” to Recently Deleted", systemImage: "trash", undoDepth: undoDepth)
    }

    func restoreDeletedPost(_ id: Post.ID) {
        guard let deleted = library.deletedPosts.first(where: { $0.id == id }) else { return }
        asOneUndoStep {
            library.deletedPosts.removeAll { $0.id == id }
            library.posts.append(deleted.post)
        }
        selectedPostID = id
        toast = Toast(message: "Restored “\(deleted.post.name)”", systemImage: "arrow.uturn.backward")
    }

    func deletePermanently(_ id: Post.ID) {
        asOneUndoStep { library.deletedPosts.removeAll { $0.id == id } }
    }

    /// Replaces the whole library with a backup. The current one is snapshotted first, so this can be undone the same way.
    func restoreBackup(_ backup: LibraryBackups.Backup) throws {
        let restored = try JSONDecoder().decode(Library.self, from: Data(contentsOf: backup.url))
        backups.snapshot(fileURL, force: true)
        asOneUndoStep { library = restored }
        selectedPostID = library.posts.first?.id
    }

    func movePosts(from source: IndexSet, to destination: Int) {
        asOneUndoStep { library.posts.move(fromOffsets: source, toOffset: destination) }
    }

    /// "Post 1", "Post 2", skipping numbers already taken.
    private func nextPostName() -> String {
        let names = Set(library.posts.map(\.name))
        var number = 1
        while names.contains("Post \(number)") { number += 1 }
        return "Post \(number)"
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
    // * === undo
    // * ====================================================================

    /// How many changes ⌘Z can step back through. A toast keeps the depth of its own change, so its Undo button
    /// only shows while that change is still the latest.
    var undoDepth: Int { undoStack.count }

    /// Runs a deliberate action, like a delete or a move, as an undo step of its own, never merged with the
    /// slider drag or typing just before or after it.
    func asOneUndoStep(_ change: () -> Void) {
        lastChange = .distantPast
        change()
        lastChange = .distantPast
    }

    /// Keeps the library as it was before a change. Every edit goes through `library`, so photo, post and frame
    /// changes are all undoable without each one saving its own undo.
    private func recordUndo(_ previous: Library) {
        // Export settings stay out of undo, so ⌘Z can never quietly switch "Remove location" back off.
        var comparable = previous
        comparable.export = library.export
        guard !isRestoring, comparable != library else { return }

        if Date().timeIntervalSince(lastChange) > Self.undoGrouping {
            undoStack.append(comparable)
            if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
        }
        lastChange = Date()
        redoStack = []
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(library)
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(library)
        restore(next)
    }

    /// Puts a version of the library back without recording it, and keeps the selection pointing at things that exist.
    private func restore(_ version: Library) {
        var restored = version
        restored.export = library.export
        isRestoring = true
        library = restored
        isRestoring = false
        lastChange = .distantPast

        if selectedPost == nil { selectedPostID = library.posts.first?.id }
        let photoIDs = Set(selectedPost?.photos.map(\.id) ?? [])
        selectedPhotoIDs.formIntersection(photoIDs)
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
            // Timestamped, so a second unreadable library never replaces the first one set aside.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            NSLog("Autopost: library could not be read (%@), moved to %@", error.localizedDescription, backup.path)
            return Library()
        }
    }
}
