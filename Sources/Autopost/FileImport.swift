import AppKit
import AutopostCore
import Foundation

enum FileImport {
    static func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    /// Photos among `urls`, with folders opened up (including subfolders), in Finder's name order.
    static func photoURLs(in urls: [URL]) -> [URL] {
        var photos: [URL] = []
        for url in urls {
            if isFolder(url) {
                photos += photosInFolder(url)
            } else if ImageSource.isSupported(url) {
                photos.append(url)
            }
        }
        return photos
    }

    private static func photosInFolder(_ folder: URL) -> [URL] {
        let files = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        let photos = (files?.allObjects as? [URL] ?? []).filter(ImageSource.isSupported)
        return photos.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    @MainActor
    static func choosePhotos(allowsFolders: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = allowsFolders
        panel.canChooseFiles = !allowsFolders
        panel.allowedContentTypes = [.image]
        panel.prompt = allowsFolders ? "Create Posts" : "Add Photos"
        return panel.runModal() == .OK ? panel.urls : []
    }

    /// One photo picked to stand in for `missing`, starting in the closest folder of its old path that still exists.
    static func chooseReplacement(for missing: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Where is \(missing.lastPathComponent)? Other missing photos in the same folder are found too."
        panel.prompt = "Locate"
        var folder = missing.deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: folder.path), folder.pathComponents.count > 1 {
            folder = folder.deletingLastPathComponent()
        }
        panel.directoryURL = folder
        return panel.runModal() == .OK ? panel.url : nil
    }
}
