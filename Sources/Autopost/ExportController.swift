import AppKit
import AutopostCore
import Observation

/// Runs post exports in the background and remembers their progress for the sidebar and inspector.
@MainActor @Observable
final class ExportController {
    // Fraction done, 0 to 1, for each post being exported.
    private(set) var progress: [Post.ID: Double] = [:]
    var failure: String?

    func isExporting(_ id: Post.ID) -> Bool {
        progress[id] != nil
    }

    /// Exports with the post's own frame, after `reframe` changes it (to switch the ratio, say) when given.
    func export(_ id: Post.ID, in store: LibraryStore, sendsViaAirDrop: Bool = false, reframe: ((inout FrameSettings) -> Void)? = nil) {
        if let reframe {
            store.update(id) { reframe(&$0.frame) }
        }
        guard let post = store.post(id), !post.photos.isEmpty, !isExporting(id) else { return }

        let settings = store.library.export
        let cameraNames = store.library.cameraNames
        let total = Double(post.photos.count)
        progress[id] = 0

        Task {
            do {
                let files = try await PostExporter.export(post, settings: settings, cameraNames: cameraNames) { done in
                    Task { @MainActor in
                        // A late update must not bring back a finished export.
                        if self.progress[id] != nil { self.progress[id] = Double(done) / total }
                    }
                }
                progress[id] = nil
                store.update(id) { $0.lastExportedAt = Date() }
                deliver(files, settings: settings, sendsViaAirDrop: sendsViaAirDrop)
            } catch {
                progress[id] = nil
                failure = "\(post.name): \(error.localizedDescription)"
                NSLog("Autopost: export of %@ failed: %@", post.name, String(describing: error))
            }
        }
    }

    func revealExports(of post: Post, settings: ExportSettings) {
        let folder = PostExporter.folder(for: post, settings: settings)
        if FileManager.default.fileExists(atPath: folder.path) {
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } else {
            NSWorkspace.shared.open(settings.destination)
        }
    }

    private func deliver(_ files: [URL], settings: ExportSettings, sendsViaAirDrop: Bool) {
        if sendsViaAirDrop, let airDrop = NSSharingService(named: .sendViaAirDrop), airDrop.canPerform(withItems: files) {
            airDrop.perform(withItems: files)
        } else if settings.revealsInFinder {
            NSWorkspace.shared.activateFileViewerSelecting(files)
        }
    }
}
