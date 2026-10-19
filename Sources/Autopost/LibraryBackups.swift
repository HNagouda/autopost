import AutopostCore
import Foundation

/// Timestamped copies of library.json in Application Support/Autopost/Backups, for when Recently Deleted is not enough.
struct LibraryBackups {
    // Often enough to lose little work, rare enough that 50 copies reach back a good while.
    static let minimumInterval: TimeInterval = 10 * 60
    static let keptBackups = 50
    private static let prefix = "library-"

    struct Backup: Identifiable {
        var url: URL
        var date: Date

        var id: URL { url }
    }

    let folder: URL

    /// Copies the library file unless the newest backup is recent. `force` copies regardless, before anything destructive.
    func snapshot(_ libraryFile: URL, force: Bool = false) {
        guard FileManager.default.fileExists(atPath: libraryFile.path) else { return }
        if !force, let newest = list().first, Date().timeIntervalSince(newest.date) < Self.minimumInterval { return }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = Self.prefix + Self.fileDate.string(from: Date()) + ".json"
            let target = folder.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: libraryFile, to: target)
            try prune()
        } catch {
            NSLog("Autopost: could not back up library to %@: %@", folder.path, error.localizedDescription)
        }
    }

    /// Newest first.
    func list() -> [Backup] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let backups = files.compactMap { url -> Backup? in
            let stamp = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: Self.prefix, with: "")
            return Self.fileDate.date(from: stamp).map { Backup(url: url, date: $0) }
        }
        return backups.sorted { $0.date > $1.date }
    }

    private func prune() throws {
        for backup in list().dropFirst(Self.keptBackups) {
            try FileManager.default.removeItem(at: backup.url)
        }
    }

    // "2026-10-19-161205", sortable and safe in a file name.
    private static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}
